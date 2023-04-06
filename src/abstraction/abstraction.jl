include("../synthesis/full_synthesis.jl")
include("field_abstraction.jl")
using Combinatorics

function inductive_leap(program, object_decomposition_old, old_global_var_dict, observations, user_events; small=true)
  object_decomposition = deepcopy(object_decomposition_old)
  global_var_dict = deepcopy(old_global_var_dict)
  on_clauses = map(a -> repr(a), filter(line_aex -> line_aex.head == :on, parseautumn(program).args))
  inductive_leap(on_clauses, object_decomposition, global_var_dict, observations, user_events, small=small)
end

function inductive_leap(on_clauses::AbstractArray, object_decomposition, global_var_dict, observations, user_events; small=true)
  object_types, object_mapping, _, _ = object_decomposition
  all_solutions = []

  # split on_clauses into each globalVar's effect/transition on-clauses and each field-based type's effect/transition on_clauses
  effect_on_clauses_dict = Dict("globalVar" => Dict(), "field1" => Dict())
  transition_on_clauses_dict = Dict("globalVar" => Dict(), "field1" => Dict())

  # non state-based on-clauses
  other_on_clauses = filter(oc -> !occursin("field1", oc), on_clauses)

  # identify field-based on-clauses
  for type in object_types 
    if type.custom_fields != [] 
      on_clauses_with_field_and_type = filter(oc -> occursin("= addedObjType$(type.id)List", oc) && occursin("field1", oc), on_clauses)
      transition_on_clauses_dict["field1"][type.id] = filter(oc -> occursin("updateObj obj \"field1\"", replace(oc, "  " => " ")), on_clauses_with_field_and_type)
      effect_on_clauses_with_field = filter(oc -> !occursin("updateObj obj \"field1\"", replace(oc, "  " => " ")), on_clauses_with_field_and_type)
      
      if effect_on_clauses_with_field != [] 
        co_occurring_event = filter(x -> !occursin("field1", repr(x)), parseautumn(effect_on_clauses_with_field[1]).args[2].args[end].args[end].args[end].args)[end]
        on_clauses_with_co_occurring_event = filter(oc -> occursin(co_occurring_event isa Symbol ? "--> obj $(string(co_occurring_event))" : "--> obj $(repr(co_occurring_event))", oc), on_clauses)
        other_on_clauses = filter(x -> !(x in on_clauses_with_co_occurring_event), other_on_clauses)
        max_val = maximum(vcat(map(id -> unique(vcat(map(obj -> obj.custom_field_values, filter(o -> !isnothing(o), object_mapping[id]))...)), collect(keys(object_mapping)))...))
        for oc in on_clauses_with_co_occurring_event
          new_aex = parseautumn(oc) 
          new_aex.args[2].args[end].args[end].args[end] = parseautumn("(& $(co_occurring_event isa Symbol ? string(co_occurring_event) : repr(co_occurring_event)) (== (.. obj field1) $(max_val)))")
          push!(effect_on_clauses_with_field, repr(new_aex))
        end
        effect_on_clauses_dict["field1"][type.id] = effect_on_clauses_with_field
      end
    end
  end

  # iterate through field1-based effect/transition sets and perform abstraction
  for type_id in keys(effect_on_clauses_dict["field1"])
    effect_on_clauses = effect_on_clauses_dict["field1"][type_id]
    transition_on_clauses = transition_on_clauses_dict["field1"][type_id]

    solutions = inductiveleap_field(effect_on_clauses, transition_on_clauses, other_on_clauses, object_decomposition, global_var_dict, observations, user_events, id=type_id, small=false, program=false)  
    if solutions != []
      object_decomposition = solutions[1][2]
      global_var_dict = solutions[1][3]
      push!(all_solutions, map(s -> s[1], solutions))
    end
  end

  if collect(keys(effect_on_clauses_dict["field1"])) != [] && all_solutions == []
    @show effect_on_clauses_dict
    return []
  end

  if all_solutions != [] 
    on_clauses = unique(vcat(all_solutions[1]...))
  end

  all_solutions = []
  # identify globalVar-based on-clauses
  for id in keys(global_var_dict)    
    other_on_clauses = filter(oc -> !occursin("globalVar$(id)", oc), on_clauses)

    on_clauses_with_globalVar = filter(oc -> occursin("globalVar$(id)", oc), on_clauses)
    transition_on_clauses_with_globalVar = filter(oc -> occursin("= globalVar$(id)", oc), on_clauses_with_globalVar)
    effect_on_clauses_with_globalVar = filter(oc -> !occursin("= globalVar$(id)", oc), on_clauses_with_globalVar)

    if effect_on_clauses_with_globalVar != [] 
      co_occurring_event = filter(x -> !occursin("globalVar", repr(x)), parseautumn(effect_on_clauses_with_globalVar[1]).args[1].args)[end]
      on_clauses_with_co_occurring_event = filter(oc -> !occursin("(list (prev obj))", oc) && occursin(co_occurring_event isa Symbol ? "(on $(string(co_occurring_event))" : "on $(repr(co_occurring_event))", oc), on_clauses)
      other_on_clauses = filter(x -> !(x in on_clauses_with_co_occurring_event), other_on_clauses)
      max_val = maximum(global_var_dict[id])
      for oc in on_clauses_with_co_occurring_event
        new_aex = parseautumn(oc)
        
        new_aex.args[1] = parseautumn("(& (== (prev globalVar$(id)) $(max_val)) $(co_occurring_event isa Symbol ? string(co_occurring_event) : repr(co_occurring_event)))")
        push!(effect_on_clauses_with_globalVar, repr(new_aex))
      end

      effect_on_clauses_dict["globalVar"][id] = effect_on_clauses_with_globalVar
      transition_on_clauses_dict["globalVar"][id] = transition_on_clauses_with_globalVar  
    end

    global_var_id = id
    effect_on_clauses = effect_on_clauses_dict["globalVar"][global_var_id]
    transition_on_clauses = transition_on_clauses_dict["globalVar"][global_var_id]

    solutions = inductiveleap(effect_on_clauses, transition_on_clauses, other_on_clauses, object_decomposition, global_var_dict, observations, user_events, id=global_var_id, small=small, program=false)  
    object_decomposition = solutions[1][2]
    global_var_dict = solutions[1][3]
    push!(all_solutions, map(s -> s[1], solutions))

  end
  
  # # iterate through globalVar-based effect/transition sets and perform abstraction
  # for global_var_id in keys(effect_on_clauses_dict["globalVar"])
  # end

  on_clause_sets = all_solutions
  @show on_clause_sets
  on_clause_sets_prod = Iterators.product(on_clause_sets...) |> collect
  programs = []
  for tup in on_clause_sets_prod
    # construct final program with abstracted on-clauses 
    on_clauses = unique([vcat(tup...)...])
    # @show on_clauses 
    # @show tup
    program = full_program_given_on_clauses(on_clauses, object_decomposition, global_var_dict, grid_size, nothing, format=false, arrow=true)
    push!(programs, program)
  end
  programs
end

function inductiveleap(effect_on_clauses, transition_on_clauses, other_on_clauses, object_decomposition, global_var_dict, observations, user_events; global_var=true, id=1, small=true, program=true)
  @show effect_on_clauses 
  @show transition_on_clauses 
  @show small

  if effect_on_clauses == [] || transition_on_clauses == []
    return []
  end

  effect_on_clause_aexprs = map(oc -> parseautumn(oc), effect_on_clauses)
  transition_on_clause_aexprs = map(oc -> parseautumn(oc), transition_on_clauses)

  # Step 1: rewrite left/right/up/down and moveLeft/Right/Up/Down with definitions
  effect_on_clause_aexprs = map(defaultsub, effect_on_clause_aexprs)
  transition_on_clause_aexprs = map(defaultsub, transition_on_clause_aexprs)

  # Step 2: find differences across effect on-clause assignments
  effect_differences = finddifference(map(x -> x.args[end], effect_on_clause_aexprs))[small ? 1 : 2]

  # Step 3: construct mapping between old state values and new state values and perform 
  # replacement in effect and transition on-clauses
  if length(effect_on_clause_aexprs) > 1 
    effect_state_values = finddifference(map(x -> x.args[1], effect_on_clause_aexprs))[1] # map(aex -> parse(Int, replace(split(aex.args[1], "== (prev globalVar$(id)) ")[end], ")" => "")), effect_on_clause_aexprs)
    old_to_new_states_map = Dict(zip(effect_state_values, effect_differences))
  
    @show old_to_new_states_map
    ## construct new global_var_dict
    global_var_dict[id] = map(state -> state in keys(old_to_new_states_map) ? old_to_new_states_map[state] : state, global_var_dict[id])
  
    ## construct new effect on-clause
    new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
    new_effect_on_clause_aexpr.args[1] = filter(x -> !occursin("globalVar$(id)", repr(x)), new_effect_on_clause_aexpr.args[1].args)[end] # the co-occurring event only, without the globalVar dependence
    new_effect_on_clause_aexpr.args[2] = parseautumn(replace(repr(new_effect_on_clause_aexpr.args[2]), " $(repr(effect_differences[1]))" => " (prev globalVar$(id))"))
  else # if there is only one effect on-clause, no compression with globalVar, but can try performing a permutation (TODO: generalize this appropriately)
    state_value_changes = unique(filter(tup -> tup[1] != tup[2], (zip(global_var_dict[id], [global_var_dict[id][2:end]..., nothing]) |> collect)[1:end-1]))
    nonconsec_changes = filter(tup -> abs(tup[1] - tup[2]) > 1, state_value_changes)
    flattened_vals =  collect(Iterators.flatten(nonconsec_changes))
    min_val = minimum(flattened_vals)
    max_val = maximum(flattened_vals)
    init = collect(min_val:max_val)
    perms = collect(permutations(init))
    old_to_new_states_map = Dict()
    for perm in perms 
      if perm != init 
        mapping = Dict(zip(init, perm))
        permuted_nonconsec_changes = map(tup -> (mapping[tup[1]], mapping[tup[2]]), state_value_changes)
        if filter(tup -> abs(tup[1] - tup[2]) > 1, permuted_nonconsec_changes) == []
          old_to_new_states_map = mapping
          break
        end
      end
    end

    if length(collect(keys(old_to_new_states_map))) != 0
      global_var_dict[id] = map(state -> old_to_new_states_map[state], global_var_dict[id])
    end

    new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
    event_str = repr(new_effect_on_clause_aexpr.args[1])
    for (old_v, new_v) in old_to_new_states_map
      event_str = replace(event_str, " $(old_v)" => " $(new_v)")
    end
    new_effect_on_clause_aexpr.args[1] = parseautumn(event_str)
  end

  ## construct new transition on-clauses
  new_transition_on_clause_aexprs = []
  for aex in transition_on_clause_aexprs 
    new_str = repr(aex)
    # update transition update
    changed_new_state = nothing
    for (old_v, new_v) in old_to_new_states_map
      if occursin("(= globalVar$(id) $(old_v))", new_str) 
        new_str = replace(new_str, "(= globalVar$(id) $(old_v))" => """(= globalVar$(id) $(new_v isa String ? "\"$(new_v)\"" : new_v))""")
        changed_new_state = new_v
        break
      end
    end

    # update transition event
    for (old_v, new_v) in old_to_new_states_map
      if occursin("(== (prev globalVar$(id)) $(old_v))", new_str) 
        new_str = replace(new_str, "(== (prev globalVar$(id)) $(old_v))" => """(== (prev globalVar$(id)) $(new_v isa String ? "\"$(new_v)\"" : new_v))""")
        break
      end
    end

    # update transition event
    new_aex = parseautumn(new_str)
    event_str = repr(new_aex.args[1])
    if !isnothing(changed_new_state) && length(unique(global_var_dict[id])) == 2
      for (old_v, new_v) in old_to_new_states_map
        if new_v != changed_new_state || old_v == new_v
          event_str = replace(event_str, " $(old_v)" => " (% (- GRID_SIZE (+ 1 (prev globalVar$(id)))) (- GRID_SIZE 1))") # TODO: only perform this if globalVar trajectory allows for it
        end
      end
    end
    new_aex.args[1] = parseautumn(event_str)
    
    push!(new_transition_on_clause_aexprs, new_aex)
  end

  # Step 4: synthesize relationship between transition events and transition updates
  ## cluster transition on-clauses based on event similarities first 
  transition_clusters = Dict()
  for aex in new_transition_on_clause_aexprs 
    if length(keys(transition_clusters)) == 0 
      transition_clusters[1] = [aex]
    else
      assigned = false
      for k in keys(transition_clusters)
        aex2 = transition_clusters[k][1]
        if occursin("== (prev globalVar$(id))", repr(aex.args[1]))
          event_part_1 = filter(x -> !occursin("== (prev globalVar$(id))", repr(x)), aex.args[1].args)[end]
        else
          event_part_1 = aex.args[1]
        end

        if occursin("== (prev globalVar$(id))", repr(aex2.args[1]))
          event_part_2 = filter(x -> !occursin("== (prev globalVar$(id))", repr(x)), aex2.args[1].args)[end]
        else
          event_part_2 = aex2.args[1]
        end
        difference, parent = finddifference([event_part_1, event_part_2])
        # @show event_part_1 
        # @show event_part_2 
        # @show difference 
        # @show parent
        if isnothing(difference[1]) || !isnothing(parent[1])
          push!(transition_clusters[k], aex)
          assigned = true 
          break
        end
      end

      if !assigned
        new_k = maximum(collect(keys(transition_clusters))) + 1 
        transition_clusters[new_k] = [aex]
      end

    end
  end

  @show new_transition_on_clause_aexprs
  @show transition_clusters

  new_transition_on_clause_aexprs_and_domains = map(aexprs -> synthesize_new_transition_update(aexprs, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id), collect(values(transition_clusters)))
  state_domains = map(tup -> tup[2], new_transition_on_clause_aexprs_and_domains)
  @show state_domains

  # Step 5: hallucination -- expand the domain of the globalVar variable based on similarities between elt's of current domain
  # expanded_transition_on_clause_aexprs_and_domains = new_transition_on_clause_aexprs_and_domains # generalize_domain(state_domain, object_decomposition)
  expanded_transition_on_clause_possibilities, new_effect_on_clause_aexpr = generalize_domain(new_transition_on_clause_aexprs_and_domains, new_effect_on_clause_aexpr, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id)
  possible_transitions_product = Iterators.product(expanded_transition_on_clause_possibilities...) |> collect
  solutions = []

  @show length(possible_transitions_product)

  for tup in possible_transitions_product 
    expanded_transition_on_clause_aexprs = [tup...]
    on_clauses = [other_on_clauses..., map(x -> repr(x), expanded_transition_on_clause_aexprs)..., repr(new_effect_on_clause_aexpr)]
    @show on_clauses
    prog = full_program_given_on_clauses(on_clauses, object_decomposition, global_var_dict, grid_size, nothing, format=false, arrow=true)

    println(prog)

    # check if prog reproduces observations
    user_events_for_interpreter = format_user_events(user_events)
    new_observations = interpret_over_time_observations(parseautumn(prog), length(user_events), user_events_for_interpreter)
    if check_observations_equivalence(observations, new_observations)
      if program 
        prog = full_program_given_on_clauses(on_clauses, object_decomposition, global_var_dict, grid_size, nothing, format=false, arrow=true)
        push!(solutions, prog)
      else
        push!(solutions, (on_clauses, object_decomposition, global_var_dict))
      end
    end
  end

  @show length(solutions)
  solutions
end

# helper functions
function generalize_domain(new_transition_on_clause_aexprs_and_domains, new_effect_on_clause_aexpr, object_decomposition, global_var_dict, user_events; global_var=true, id=1)
  generalized_transitions = []
  generalized_effect_on_clause_aexpr = deepcopy(new_effect_on_clause_aexpr)

  println("sad")
  @show new_transition_on_clause_aexprs_and_domains
  for tup in new_transition_on_clause_aexprs_and_domains
    transition_aexpr, domain = tup 

    if transition_aexpr isa AbstractArray 
      push!(generalized_transitions, map(x -> [x], transition_aexpr)...)
    else 

      @show domain 
      possibilities = []
      if domain[1] isa Int || domain[1] isa BigInt # generalizing over integers
        min_val = minimum(domain) 
        if min_val == 1 
          state_dependence = filter(x -> occursin("globalVar$(id)", repr(x)), transition_aexpr.args[1].args)[end]
          transition_aexpr.args[1] = filter(x -> !occursin("globalVar$(id)", repr(x)), transition_aexpr.args[1].args)[end]
          if occursin(repr(state_dependence), repr(generalized_effect_on_clause_aexpr))
            generalized_effect_on_clause_aexpr.args[1] = filter(x -> !occursin("globalVar$(id)", repr(x)), generalized_effect_on_clause_aexpr.args[1].args)[end]
          end
          push!(possibilities, transition_aexpr)
        else
          old_state_dependence = "(in (prev globalVar$(id)) (list $(join(map(x -> "$(x)", domain)," "))))"
          new_state_dependence = "(!= (prev globalVar$(id)) 1)"
          transition_aexpr_str = replace(repr(transition_aexpr), old_state_dependence => new_state_dependence)
          push!(possibilities, parseautumn(transition_aexpr_str))
          generalized_effect_on_clause_aexpr = parseautumn(replace(repr(generalized_effect_on_clause_aexpr), old_state_dependence => new_state_dependence))        
        end
        push!(generalized_transitions, possibilities)
      elseif domain[1] isa AExpr 
        if occursin("Position", repr(domain[1])) # generalizing over positions
          new_state_dependence = "(!= arrow (Position 0 0))"
          transition_aexpr_str = replace(repr(transition_aexpr), repr(transition_aexpr.args[1]) => new_state_dependence)
          push!(possibilities, parseautumn(transition_aexpr_str))
          push!(generalized_transitions, possibilities)
          generalized_effect_on_clause_aexpr.args[1] = parseautumn("(& $(generalized_effect_on_clause_aexpr.args[1] isa AExpr ? repr(generalized_effect_on_clause_aexpr.args[1]) : generalized_effect_on_clause_aexpr.args[1]) (!= (prev globalVar$(id)) (Position 0 0)))")
        else # generalizing over objects
          clicked_aex = findnode(transition_aexpr, :clicked)
          object_expr = clicked_aex.args[end]
  
          # evaluate object_expr 
          hypothesis_program = program_string_synth_standard_groups(object_decomposition)
          event_string = "\n\t (= event (initnext (list) $(repr(object_expr))))\n"
          hypothesis_program = string(hypothesis_program[1:end-2], event_string, "\n)")
          hypothesis_frame_state = interpret_over_time(parseautumn(hypothesis_program), 1, user_events_for_interpreter[time:time]).state
          event_value = map(key -> hypothesis_frame_state.histories[:event][key], sort(collect(keys(hypothesis_frame_state.histories[:event]))))[end]
  
          object_ids = map(obj -> obj.id, event_value)
          possible_domain_expansions = [
                                        "(filter (--> obj (== (.. (.. obj origin) y) 0)) (prev addedObjType1List))",
                                        "(filter (--> obj (in (.. obj color) (map (--> obj2 (.. obj2 color)) $(repr(object_expr))))) (prev addedObjType1List))",
                                       ]
  
          for possible_expr in possible_domain_expansions 
            hypothesis_program = program_string_synth_standard_groups(object_decomposition)
            event_string = "\n\t (= event (initnext (list) $(possible_expr)))\n"
            hypothesis_program = string(hypothesis_program[1:end-2], event_string, "\n)")
            hypothesis_frame_state = interpret_over_time(parseautumn(hypothesis_program), 1, user_events_for_interpreter[time:time]).state
            event_value = map(key -> hypothesis_frame_state.histories[:event][key], sort(collect(keys(hypothesis_frame_state.histories[:event]))))[end]          
            new_object_ids = map(obj -> obj.id, event_value)
            if Set(intersect(new_object_ids, object_ids)) == Set(object_ids)
              push!(possibilities, replace(repr(transition_aexpr), repr(object_expr) => possible_expr))
              bare_bones_possible_expr = "(filter (--> obj (in (.. obj id) (list $(join(new_object_ids, " "))))) (prev addedObjType1List))"
              push!(possibilities, replace(repr(transition_aexpr), repr(object_expr) => bare_bones_possible_expr))
            end
          end
  
          # transition_aexpr_str = replace(repr(transition_aexpr), repr(object_expr) => "(filter (--> obj (== (.. (.. obj origin) y) 0)) addedObjType1List)")
          # push!(generalized_transitions, parseautumn(transition_aexpr_str))
          push!(generalized_transitions, map(x -> parseautumn(x), possibilities))
        end
      else
        push!(generalized_transitions, [tup[1]])
      end
    end
  end

  generalized_transitions, generalized_effect_on_clause_aexpr
end

function synthesize_new_transition_update(new_transition_on_clause_aexprs, object_decomposition, global_var_dict, user_events; global_var=true, id=1) 
  @show id
  consec_state_value_tuples = (zip(global_var_dict[id], [global_var_dict[id][2:end]..., nothing]) |> collect)[1:end-1]

  @show consec_state_value_tuples

  new_state_values = map(oc -> oc.args[end].args[end], new_transition_on_clause_aexprs)
  environments = []
  for aex in new_transition_on_clause_aexprs 
    env = Dict()
    event_aex, update_aex = aex.args 
    event_str = repr(event_aex)

    if occursin("== (prev globalVar$(id))", event_str)
      global_var_value = event_aex.args[end].args[end]
      env["globalVar$(id)"] = global_var_value
    end

    new_state_value = update_aex.args[end]
    @show new_state_value
    init_state_values = unique(filter(tup -> (tup[2] == new_state_value) && tup[1] != tup[2], consec_state_value_tuples))
    @show init_state_values
    if length(init_state_values) == 1
      env["globalVar$(id)"] = init_state_values[1][1]
    end

    if occursin("clicked (prev", event_str) || occursin("clicked (filter", event_str)
      clicked_aex = findnode(event_aex, :clicked)
      object_expr = clicked_aex.args[end]
      env["objects"] = [object_expr]
    end

    if occursin("== arrow", event_str)
      arrow_aex = findnode(event_aex, :arrow)
      arrow_val = arrow_aex.args[end]
      env["arrow"] = arrow_val
    end
    push!(environments, env)
  end
  @show environments
  new_state_expr = synthesize_state_expr(new_transition_on_clause_aexprs, environments, new_state_values, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id)
  @show new_state_expr
  if isnothing(new_state_expr)
    return (map(aex -> repr(aex), new_transition_on_clause_aexprs), unique(collect(Iterators.flatten(consec_state_value_tuples))))
  end

  new_transition_on_clause_str = replace(replace(repr(new_transition_on_clause_aexprs[1]), "  " => " "), "= globalVar$(id) $(repr(new_transition_on_clause_aexprs[1].args[end].args[end]))" => "= globalVar$(id) $(new_state_expr)")
  if occursin("objClicked", new_transition_on_clause_str)
    state_domain = union(map(env -> env["objects"], environments)...)
    new_event = "(clicked (vcat $(join(map(obj -> repr(obj), state_domain), " "))))"
    new_transition_on_clause_aex = parseautumn(new_transition_on_clause_str)
    new_transition_on_clause_aex.args[1] = parseautumn(new_event)
    new_transition_on_clause_str = repr(new_transition_on_clause_aex)
  elseif occursin("arrow", new_transition_on_clause_str)
    state_domain = union(map(env -> env["arrow"], environments))
    global_var_dict[id][1] = parseautumn("(Position 0 0)")
  else
    state_domain = union(map(env -> env["globalVar$(id)"], environments)...)
    new_event_state_dependence = parseautumn("(in (prev globalVar$(id)) (list $(join(state_domain, " "))))")
    if foldl(&, map(aex -> occursin("== (prev globalVar$(id))", repr(aex.args[1])), new_transition_on_clause_aexprs), init=true)
      old_state_dependence = filter(x -> occursin("== (prev globalVar$(id))", repr(x)), new_transition_on_clause_aexprs[1].args[1].args)[end]
      new_transition_on_clause_aex = parseautumn(new_transition_on_clause_str)
      new_transition_on_clause_aex.args[1] = parseautumn(replace(repr(new_transition_on_clause_aexprs[1].args[1]), repr(old_state_dependence) => repr(new_event_state_dependence)))
      new_transition_on_clause_str = repr(new_transition_on_clause_aex)
    end
  end 

  parseautumn(new_transition_on_clause_str), state_domain
end

function synthesize_state_expr(new_transition_on_clause_aexprs, environments, new_state_values, object_decomposition, global_var_dict, user_events; global_var=true, id=1)
  object_types, object_mapping, background, _ = object_decomposition

  possible_expressions = []
  objects = union(map(env -> "objects" in keys(env) ? env["objects"] : [], environments)...)

  @show new_state_values
  # @show environments
  # @show objects
  if new_state_values[1] isa Int || new_state_values[1] isa BigInt
    push!(possible_expressions, ["(- 0 (prev globalVar$(id)))", "(- (prev globalVar$(id)) 1)", "(+ (prev globalVar$(id)) 1)"]...) #
  elseif new_state_values[1] isa String
    push!(possible_expressions, "(.. (objClicked click (vcat $(join(map(obj -> repr(obj), objects), " ")))) color)")
  elseif new_state_values[1] isa AExpr && occursin("Position", repr(new_state_values[1]))
    push!(possible_expressions, "arrow")
  end

  consec_state_value_tuples = (zip(global_var_dict[id], [global_var_dict[id][2:end]..., nothing]) |> collect)[1:end-1]

  user_events_for_interpreter = []
  for e in user_events 
    if isnothing(e) || e == "nothing"
      push!(user_events_for_interpreter, Dict())
    elseif e == "left"
      push!(user_events_for_interpreter, Dict(:left => true))
    elseif e == "right"
      push!(user_events_for_interpreter, Dict(:right => true))
    elseif e == "up"
      push!(user_events_for_interpreter, Dict(:up => true))
    elseif e == "down"
      push!(user_events_for_interpreter, Dict(:down => true))
    else
      global x = parse(Int, split(e, " ")[2])
      global y = parse(Int, split(e, " ")[3])
      push!(user_events_for_interpreter, Dict(:click => AutumnStandardLibrary.Click(x, y)))
    end
  end
  
  # @show possible_expressions
  for new_state_expr in possible_expressions 
    correct = true
    for i in 1:length(new_state_values)
      state_val = new_state_values[i]
      event_expr = "(== $(new_state_expr) $(state_val isa String ? "\"$(state_val)\"" : state_val))"
      # @show event_expr
      times = findall(tup -> tup[1] != state_val && tup[2] == state_val, consec_state_value_tuples)
      # @show times
      for time in times
        if !("globalVar$(id)" in keys(environments[i]))
          init_state_val, _ = consec_state_value_tuples[time] 
        else
          init_state_val = environments[i]["globalVar$(id)"]
        end
        # prev_existing_objects = filter(obj -> !isnothing(obj), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
        # prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time - 1]) && (unique(object_mapping[id][1:time - 1]) != [nothing]), collect(keys(object_mapping)))
        # prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time - 1])[1], prev_removed_object_ids))
        # foreach(obj -> obj.position = (-1, -1), prev_removed_objects)
    
        # prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)
        
        hypothesis_program = program_string_synth_standard_groups(object_decomposition)
        global_var_string = "\n\t (: globalVar$(id) Int) \n\t (= globalVar$(id) (initnext $(init_state_val isa String ? "\"$(init_state_val)\"" : init_state_val) (prev globalVar$(id))))\n" 

        arrow = occursin("click", user_events[time]) ? AutumnStandardLibrary.Position(0, 0) : user_events_to_arrow[user_events[time]] 
        arrow_string = "\n\t (: arrow Position) \n\t (= arrow (initnext (Position $(arrow.x) $(arrow.y)) (prev arrow)))\n"

        event_string = "\n\t (: event Bool) \n\t (= event (initnext false $(event_expr)))\n"

        hypothesis_program = string(hypothesis_program[1:end-2], global_var_string, arrow_string, event_string, "\n)")

        # println(hypothesis_program)

        hypothesis_frame_state = interpret_over_time(parseautumn(hypothesis_program), 1, user_events_for_interpreter[time:time]).state
        event_value = map(key -> hypothesis_frame_state.histories[:event][key], sort(collect(keys(hypothesis_frame_state.histories[:event]))))[end]
        # @show event_value
        if !event_value 
          # @show time
          correct = false 
          break
        end
      end

      if !correct 
        break
      end

    end
    
    if correct 
      return new_state_expr
    end

  end

  return nothing
end