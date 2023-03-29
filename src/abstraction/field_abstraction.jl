# TEMP: DELETE LATER AFTER INTEGRATING WITH ABSTRACTION.JL

include("../synthesis/full_synthesis.jl");
using MLStyle
using Combinatorics

function inductiveleap(effect_on_clauses, transition_on_clauses, object_decomposition, global_var_dict, user_events; global_var=true, id=1, small=true)
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
    effect_state_values = finddifference(map(x -> x.args[2].args[end].args[end], effect_on_clause_aexprs))[1] # map(aex -> parse(Int, replace(split(aex.args[1], "== (prev globalVar$(id)) ")[end], ")" => "")), effect_on_clause_aexprs)
    old_to_new_states_map = Dict(zip(effect_state_values, effect_differences))
  
    @show old_to_new_states_map
    ## construct new global_var_dict
    # global_var_dict[1] = map(state -> old_to_new_states_map[state], global_var_dict[1])
    # TODO: update object_decomposition field values
    object_types, object_mapping, background, grid_size = object_decomposition 
    for id in keys(object_mapping)
      for obj in object_mapping[id]
        obj.custom_field_values = [old_to_new_states_map[obj.custom_field_values[1]]]
      end
    end
    object_decomposition = (object_types, object_mapping, background, grid_size)   

    ## construct new effect on-clause
    new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
    new_effect_on_clause_aexpr.args[2].args[end].args[end].args[end] = filter(x -> !occursin("field$(id)", repr(x)), new_effect_on_clause_aexpr.args[2].args[end].args[end].args[end].args)[end] # the co-occurring event only, without the globalVar dependence
    new_effect_on_clause_aexpr.args[2] = parseautumn(replace(repr(new_effect_on_clause_aexpr.args[2]), " $(repr(effect_differences[1]))" => " (.. obj field$(id))"))
  else # if there is only one effect on-clause, no compression with globalVar, but can try performing a permutation (TODO: generalize this appropriately)
    state_value_changes = unique(filter(tup -> tup[1] != tup[2], (zip(global_var_dict[1], [global_var_dict[1][2:end]..., nothing]) |> collect)[1:end-1]))
    nonconsec_changes = filter(tup -> abs(tup[1] - tup[2]) > 1, state_value_changes)
    if nonconsec_changes != [] 
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
        global_var_dict[1] = map(state -> old_to_new_states_map[state], global_var_dict[1])
      end
  
      new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
      event_str = repr(new_effect_on_clause_aexpr.args[1])
      for (old_v, new_v) in old_to_new_states_map
        event_str = replace(event_str, " $(old_v)" => " $(new_v)")
      end
      new_effect_on_clause_aexpr.args[1] = parseautumn(event_str)
    else
      old_to_new_states_map = Dict()
      new_effect_on_clause_aexpr = deepcopy(effect_on_clause_aexprs[1])
    end

  end

  ## construct new transition on-clauses
  new_transition_on_clause_aexprs = []
  for aex in transition_on_clause_aexprs 
    new_str = repr(aex)
    # update transition update
    changed_new_state = nothing
    for (old_v, new_v) in old_to_new_states_map
      if occursin("(updateObj obj  \"field$(id)\"  $(old_v))", new_str) 
        new_str = replace(new_str, "(updateObj obj  \"field$(id)\"  $(old_v))" => """(updateObj obj  \"field1\"  $(new_v isa String ? "\"$(new_v)\"" : new_v))""")
        changed_new_state = new_v
        break
      end
    end

    # update transition event
    for (old_v, new_v) in old_to_new_states_map
      if occursin("(== (.. obj field$(id)) $(old_v))", new_str) 
        new_str = replace(new_str, "(== (.. obj field$(id)) $(old_v))" => """(== (.. obj field$(id)) $(new_v isa String ? "\"$(new_v)\"" : new_v))""")
        break
      end
    end

    # update transition event
    new_aex = parseautumn(new_str)
    event_str = repr(new_aex.args[2].args[end].args[end])
    if !isnothing(changed_new_state) && (1 in keys(global_var_dict)) && length(unique(global_var_dict[1])) == 2
      for (old_v, new_v) in old_to_new_states_map
        if new_v != changed_new_state || old_v == new_v
          event_str = replace(event_str, " $(old_v)" => " (% (- GRID_SIZE (+ 1 (prev globalVar$(id)))) (- GRID_SIZE 1))") # TODO: only perform this if globalVar trajectory allows for it
        end
      end
    end

    if !isnothing(changed_new_state)
      for (old_v, new_v) in old_to_new_states_map
        event_str = replace(event_str, " $(new_v)" => " (.. (prev obj) field$(id))") # TODO: only perform this if globalVar trajectory allows for it
      end
    end
    new_aex.args[2].args[end].args[end] = parseautumn(event_str)
    
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
        if occursin("== (.. obj field$(id))", repr(aex.args[2].args[end].args[end].args[end]))
          event_part_1 = filter(x -> !occursin("== (.. obj field$(id))", repr(x)), aex.args[2].args[end].args[end].args[end].args)[end]
        else
          event_part_1 = aex.args[2].args[end].args[end].args[end]
        end

        if occursin("== (.. obj field$(id))", repr(aex2.args[2].args[end].args[end].args[end]))
          event_part_2 = filter(x -> !occursin("== (.. obj field$(id))", repr(x)), aex2.args[2].args[end].args[end].args[end].args)[end]
        else
          event_part_2 = aex2.args[2].args[end].args[end].args[end]
        end
        difference, _ = finddifference([event_part_1, event_part_2])
        if isnothing(difference[1])
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

  new_transition_on_clause_aexprs_and_domains = map(aexprs -> synthesize_new_transition_update(aexprs, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id), collect(values(transition_clusters)))
  state_domains = map(tup -> tup[2], new_transition_on_clause_aexprs_and_domains)
  @show state_domains

  # Step 5: hallucination -- expand the domain of the globalVar variable based on similarities between elt's of current domain
  # expanded_transition_on_clause_aexprs_and_domains = new_transition_on_clause_aexprs_and_domains # generalize_domain(state_domain, object_decomposition)
  # expanded_transition_on_clause_aexprs, new_effect_on_clause_aexpr = generalize_domain(new_transition_on_clause_aexprs_and_domains, new_effect_on_clause_aexpr, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id)
  expanded_transition_on_clause_aexprs = map(tup -> tup[1], new_transition_on_clause_aexprs_and_domains)

  # (repr(new_effect_on_clause_aexpr), repr(new_transition_update_expr))
  on_clauses = [repr(new_effect_on_clause_aexpr), map(x -> repr(x), expanded_transition_on_clause_aexprs)...]
  # @show on_clauses
  program = full_program_given_on_clauses(on_clauses, object_decomposition, global_var_dict, grid_size, nothing, format=false)
  program
end

# helper functions
function generalize_domain(new_transition_on_clause_aexprs_and_domains, new_effect_on_clause_aexpr, object_decomposition, global_var_dict, user_events; global_var=true, id=1)
  generalized_transitions = []
  generalized_effect_on_clause_aexpr = deepcopy(new_effect_on_clause_aexpr)

  for tup in new_transition_on_clause_aexprs_and_domains
    transition_aexpr, domain = tup 
    if domain[1] isa Int || domain[1] isa BigInt # generalizing over integers
      min_val = minimum(domain) 
      if min_val == 1 
        state_dependence = filter(x -> occursin("field$(id)", repr(x)), transition_aexpr.args[2].args[end].args[end].args[end].args)[end]
        transition_aexpr.args[2].args[end].args[end].args[end] = filter(x -> !occursin("field$(id)", repr(x)), transition_aexpr.args[2].args[end].args[end].args[end].args)[end]
        push!(generalized_transitions, transition_aexpr)
        if occursin(repr(state_dependence), repr(generalized_effect_on_clause_aexpr))
          generalized_effect_on_clause_aexpr.args[2].args[end].args[end].args[end] = filter(x -> !occursin("field$(id)", repr(x)), generalized_effect_on_clause_aexpr.args[2].args[end].args[end].args[end].args)[end]
        end
      else
        old_state_dependence = "(in (.. obj field$(id)) (list $(join(map(x -> "$(x)", domain)," "))))"
        new_state_dependence = "(!= (.. obj field$(id)) 1)"
        transition_aexpr_str = replace(repr(transition_aexpr), old_state_dependence => new_state_dependence)
        push!(generalized_transitions, parseautumn(transition_aexpr_str))
        generalized_effect_on_clause_aexpr = parseautumn(replace(repr(generalized_effect_on_clause_aexpr), old_state_dependence => new_state_dependence))        
      end
    elseif domain[1] isa AExpr 
      if occursin("Position", repr(domain[1])) # generalizing over positions
        new_state_dependence = "(!= arrow (Position 0 0))"
        transition_aexpr_str = replace(repr(transition_aexpr), repr(transition_aexpr.args[2].args[end].args[end].args[end]) => repr(new_state_dependence))
        push!(generalized_transitions, parseautumn(transition_aexpr_str))
      else # generalizing over objects
        clicked_aex = findnode(transition_aexpr, :clicked)
        object_expr = clicked_aex.args[end]
        transition_aexpr_str = replace(repr(transition_aexpr), repr(object_expr) => "(filter (--> obj (== (.. (.. obj origin) y) 0)) addedObjType1List)")
        push!(generalized_transitions, parseautumn(transition_aexpr_str))
      end
    else
      push!(generalized_transitions, tup[1])
    end
  end
  (generalized_transitions, generalized_effect_on_clause_aexpr)
end

function synthesize_new_transition_update(new_transition_on_clause_aexprs, object_decomposition, global_var_dict, user_events; global_var=true, id=1) 
  object_types, object_mapping, _, _ = object_decomposition
  consec_state_value_tuples = vcat(map(id -> (zip(map(obj -> obj.custom_field_values[1], object_mapping[id]), [map(obj -> obj.custom_field_values[1], object_mapping[id])[2:end]..., nothing]) |> collect)[1:end-1], collect(keys(object_mapping)))...)
  consec_state_value_tuples = filter(tup -> tup[1] != tup[2], consec_state_value_tuples)

  new_state_values = map(oc -> oc.args[end].args[end].args[end - 1].args[end].args[end], new_transition_on_clause_aexprs)
  environments = []
  for aex in new_transition_on_clause_aexprs 
    env = Dict()
    event_str = repr(aex.args[2].args[end].args[end].args[end])

    if occursin("== (.. obj field$(id))", event_str)
      global_var_value = parseautumn(event_str).args[end].args[end]
      env["field$(id)"] = global_var_value
    end

    @show aex
    new_state_value = aex.args[2].args[end].args[end - 1].args[end].args[end]
    @show new_state_value
    init_state_values = unique(filter(tup -> (repr(tup[2]) == repr(new_state_value)) && tup[1] != tup[2], consec_state_value_tuples))
    if length(init_state_values) == 1
      env["field$(id)"] = init_state_values[1][1]
    end

    # if occursin("clicked (prev", event_str) || occursin("clicked (filter", event_str)
    #   clicked_aex = findnode(event_aex, :clicked)
    #   object_expr = clicked_aex.args[end]
    #   env["objects"] = [object_expr]
    # end

    # if occursin("== arrow", event_str)
    #   arrow_aex = findnode(event_aex, :arrow)
    #   arrow_val = arrow_aex.args[end]
    #   env["arrow"] = arrow_val
    # end
    push!(environments, env)
  end
  @show environments
  new_state_expr = synthesize_state_expr(new_transition_on_clause_aexprs, environments, new_state_values, object_decomposition, global_var_dict, user_events, global_var=global_var, id=id)

  if isnothing(new_state_expr)
    return (nothing, nothing)
  end

  # STOPPED HERE
  # new_transition_on_clause_str = replace(replace(repr(new_transition_on_clause_aexprs[1]), "  " => " "), "= globalVar$(id) $(repr(new_transition_on_clause_aexprs[1].args[end].args[end]))" => "= globalVar$(id) $(new_state_expr)")
  # if occursin("objClicked", new_transition_on_clause_str)
  #   state_domain = union(map(env -> env["objects"], environments)...)
  #   new_event = "(clicked (vcat $(join(map(obj -> repr(obj), state_domain), " "))))"
  #   new_transition_on_clause_aex = parseautumn(new_transition_on_clause_str)
  #   new_transition_on_clause_aex.args[1] = parseautumn(new_event)
  #   new_transition_on_clause_str = repr(new_transition_on_clause_aex)
  # elseif occursin("arrow", new_transition_on_clause_str)
  #   state_domain = union(map(env -> env["arrow"], environments)...)
  # else
  #   state_domain = union(map(env -> env["globalVar$(id)"], environments)...)
  #   new_event_state_dependence = parseautumn("(in (prev globalVar$(id)) (list $(join(state_domain, " "))))")
  #   if foldl(&, map(aex -> occursin("== (prev globalVar$(id))", repr(aex.args[1])), new_transition_on_clause_aexprs), init=true)
  #     old_state_dependence = filter(x -> occursin("== (prev globalVar$(id))", repr(x)), new_transition_on_clause_aexprs[1].args[1].args)[end]
  #     new_transition_on_clause_aex = parseautumn(new_transition_on_clause_str)
  #     new_transition_on_clause_aex.args[1] = parseautumn(replace(repr(new_transition_on_clause_aexprs[1].args[1]), repr(old_state_dependence) => repr(new_event_state_dependence)))
  #     new_transition_on_clause_str = repr(new_transition_on_clause_aex)
  #   end
  # end
  new_transition_on_clause_str = replace(replace(repr(new_transition_on_clause_aexprs[1]), "  " => " "), "(--> obj (updateObj obj \"field1\" $(new_state_values[1])))" => "(--> obj (updateObj obj \"field1\" $(new_state_expr)))")
  state_domain = vcat(map(id -> unique(map(obj -> obj.custom_field_values[1], object_mapping[id])), collect(keys(object_mapping)))...)

  parseautumn(new_transition_on_clause_str), state_domain
end

function synthesize_state_expr(new_transition_on_clause_aexprs, environments, new_state_values, object_decomposition, global_var_dict, user_events; global_var=true, id=1)
  object_types, object_mapping, background, _ = object_decomposition

  possible_expressions = []
  objects = union(map(env -> "objects" in keys(env) ? env["objects"] : [], environments)...)

  # @show environments
  # @show objects
  if new_state_values[1] isa Int || new_state_values[1] isa BigInt
    push!(possible_expressions, ["(- 0 (.. obj field$(id)))", "(- (.. obj field$(id)) 1)", "(+ (.. obj field$(id)) 1)"]...) #
  elseif new_state_values[1] isa String
    push!(possible_expressions, "(.. (objClicked click (vcat $(join(map(obj -> repr(obj), objects), " ")))) color)")
  elseif new_state_values[1] isa AExpr # AutumnStandardLibrary.Position 
    push!(possible_expressions, "(scalarMult (.. obj field1) -1)")
  end

  # consec_state_value_tuples = (zip(global_var_dict[1], [global_var_dict[1][2:end]..., nothing]) |> collect)[1:end-1]
  consec_state_value_tuples = Dict(map(id -> id => (zip(map(obj -> obj.custom_field_values[1], object_mapping[id]), [map(obj -> obj.custom_field_values[1], object_mapping[id])[2:end]..., nothing]) |> collect)[1:end-1], collect(keys(object_mapping))))

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
      x = parse(Int, split(e, " ")[2])
      y = parse(Int, split(e, " ")[3])
      push!(user_events_for_interpreter, Dict(:click => AutumnStandardLibrary.Click(x, y)))
    end
  end
  
  # @show possible_expressions
  for new_state_expr in possible_expressions 
    correct = true
    for i in 1:length(new_state_values)
      state_val = new_state_values[i]
      # event_expr = "(== $(new_state_expr) $(state_val isa String ? "\"$(state_val)\"" : state_val))"
      # event_expr = "()"
      # @show event_expr
      times_and_ids = unique(vcat(map(id -> map(t -> (t, id), findall(tup -> repr(tup[1]) != repr(state_val) && repr(tup[2]) == repr(state_val), consec_state_value_tuples[id])), collect(keys(consec_state_value_tuples)))...))
      # @show times
      for time_and_id in times_and_ids
        time_, object_id = time_and_id
        if !("field$(id)" in keys(environments[i]))
          init_state_val, _ = consec_state_value_tuples[object_id][time_]
        else
          init_state_val = environments[i]["field$(id)"]
        end
        # prev_existing_objects = filter(obj -> !isnothing(obj), [object_mapping[id][time_ - 1] for id in 1:length(collect(keys(object_mapping)))])
        # prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time_ - 1]) && (unique(object_mapping[id][1:time_ - 1]) != [nothing]), collect(keys(object_mapping)))
        # prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time_ - 1])[1], prev_removed_object_ids))
        # foreach(obj -> obj.position = (-1, -1), prev_removed_objects)
    
        # prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)
        
        hypothesis_program = program_string_synth_standard_groups(object_decomposition)
        global_var_string = "" # "\n\t (: globalVar$(id) Int) \n\t (= globalVar$(id) (initnext $(init_state_val isa String ? "\"$(init_state_val)\"" : init_state_val) (prev globalVar$(id))))\n" 

        arrow = occursin("click", user_events[time_]) ? AutumnStandardLibrary.Position(0, 0) : user_events_to_arrow[user_events[time_]] 
        arrow_string = "\n\t (: arrow Position) \n\t (= arrow (initnext (Position $(arrow.x) $(arrow.y)) (prev arrow)))\n"

        event_expr = "(in $(repr(state_val)) (map (--> obj $(new_state_expr)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType1List))))"
        event_string = "\n\t (: event Bool) \n\t (= event (initnext false $(event_expr)))\n"

        hypothesis_program = string(hypothesis_program[1:end-2], global_var_string, arrow_string, event_string, "\n)")

        # println(hypothesis_program)

        hypothesis_frame_state = interpret_over_time(parseautumn(hypothesis_program), 1, user_events_for_interpreter[time_:time_]).state
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

user_events_to_arrow = Dict(["nothing" => AutumnStandardLibrary.Position(0, 0), 
                             "left" => AutumnStandardLibrary.Position(-1, 0),
                             "right" => AutumnStandardLibrary.Position(1, 0),
                             "up" => AutumnStandardLibrary.Position(0, -1),
                             "down" => AutumnStandardLibrary.Position(0, 1),
])

function findnode(aex::AExpr, subaex, parent=nothing)
  if repr(aex) == repr(subaex)
    return parent
  else
    for i in 1:length(aex.args)
      soln = findnode(aex.args[i], subaex, aex)
      if !isnothing(soln)
        return soln
      end
    end
  end
  return nothing
end

function findnode(aex, subaex, parent=nothing)
  if repr(aex) == repr(subaex)
    parent
  else
    nothing
  end
end

function finddifference(aexs::Array{AExpr}, parents=nothing) 
  if length(unique(map(x -> repr(x), aexs))) == 1 
    return ([nothing for i in aexs], !isnothing(parents) ? parents : [nothing for i in aexs])
  elseif !(length(unique(map(x -> x.head, aexs))) == 1 && length(unique(map(x -> length(x.args), aexs))) == 1)
    return (aexs, !isnothing(parents) ? parents : [nothing for i in aexs])
  else
    for i in 1:length(aexs[1].args)
      ith_args = map(x -> x.args[i], aexs)
      arg_difference = finddifference(ith_args, aexs)
      if !isnothing(arg_difference[1][1])
        return arg_difference
      end
    end
  end
end

function finddifference(aexs, parents=nothing)
  if length(unique(map(x -> repr(x), aexs))) == 1 
    return ([nothing for i in aexs], !isnothing(parents) ? parents : [nothing for i in aexs])
  else
    return (aexs, !isnothing(parents) ? parents : [nothing for i in aexs])
  end
end

function defaultsub(aex::AExpr) 
  new_aex = deepcopy(aex)
  for x in [:moveLeft, :moveRight, :moveUp, :moveDown, :left, :right, :up, :down]
    new_aex = defaultsub(new_aex, x)    
  end
  new_aex
end

function defaultsub(aex::AExpr, x::Symbol)
  if x == :moveLeft 
    sub(aex, (x, function lam1(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position -1 0)"))
                    a
                  end))
  elseif x == :moveRight 
    sub(aex, (x, function lam2(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position 1 0)"))
                    a
                  end))
  elseif x == :moveUp 
    sub(aex, (x, function lam3(a)
                    a.args[1] = :move 
                    push!(a.args, parseautumn("(Position 0 -1)"))
                    a
                  end))
  elseif x == :moveDown 
    sub(aex, (x, function lam4(a)
                    a.args[1] = :move                   
                    push!(a.args, parseautumn("(Position 0 1)"))
                    a
                  end))
  elseif x == :left 
    sub(aex, x => parseautumn("(== arrow (Position -1 0))"))
  elseif x == :right 
    sub(aex, x => parseautumn("(== arrow (Position 1 0))"))
  elseif x == :up 
    sub(aex, x => parseautumn("(== arrow (Position 0 -1))"))
  elseif x == :down
    sub(aex, x => parseautumn("(== arrow (Position 0 1))"))
  else 
    error("Could not defaultsub $(aex)")
  end
end

function sub(aex::AExpr, (x, v))
  # println("sub 1")
  # @show aex 
  # @show x

  if (aex.args != [] && aex.args[1] == x) && (occursin("var", repr(typeof(v))) || occursin("typeof", repr(typeof(v)))) # v is a lambda function taking x as input
    new_arg = sub(aex.args[2], (x, v))
    # @show new_arg
    aex.args[2] = new_arg
    # println("here")
    # @show aex
    return v(aex)
  end

  arr = [aex.head, aex.args...]
  if (x isa AExpr) && ([x.head, x.args...] == arr)  
    v
  else
    MLStyle.@match arr begin
      [:fn, args, body]                                       => AExpr(:fn, args, sub(body, x => v))
      [:if, c, t, e]                                          => AExpr(:if, sub(c, x => v), sub(t, x => v), sub(e, x => v))
      [:assign, a1, a2]                                       => AExpr(:assign, a1, sub(a2, x => v))
      [:list, args...]                                        => AExpr(:list, map(arg -> sub(arg, x => v), args)...)
      [:typedecl, args...]                                    => AExpr(:typedecl, args...)
      [:let, args...]                                         => AExpr(:let, map(arg -> sub(arg, x => v), args)...)      
      [:lambda, args, body]                                   => AExpr(:lambda, args, sub(body, x => v))
      [:call, f, args...]                                     => AExpr(:call, f, map(arg -> sub(arg, x => v) , args)...)      
      [:field, o, fieldname]                                  => AExpr(:field, sub(o, x => v), fieldname)
      [:object, args...]                                      => AExpr(:object, args...)
      [:on, event, update]                                    => AExpr(:on, sub(event, x => v), sub(update, x => v))
      [args...]                                               => error(string("Invalid AExpr Head: ", new_state_expr.head))
      _                                                       => error("Could not sub $arr")
    end
  end
end

function sub(aex, (x, v))
  if (aex == x) && !(occursin("var", repr(typeof(v))) || occursin("typeof", repr(typeof(v))))
    v
  else
    aex
  end
end