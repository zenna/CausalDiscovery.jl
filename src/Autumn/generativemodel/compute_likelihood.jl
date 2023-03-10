include("full_synthesis.jl");
using Combinatorics

function compute_likelihood(program, observation_seq)


end

function compute_log_likelihood_cisc(on_clauses, concrete_update_function_matrix, object_decomposition) 
  object_types, object_mapping, background, _ = object_decomposition
  
  log_prob = 0

  # (addObj uniformChoice), (addObj randomPositions)  
  for object_id in size(concrete_update_function_matrix)[1]
    for time in size(concrete_update_function_matrix)[2]
      u = concrete_update_function_matrix[object_id, time]
      if occursin("addObj", u)
        if occursin("randomPositions GRID_SIZE 1", u) 
          log_prob += log2(1/(grid_size * grid_size))
        elseif occursin("randomPositions GRID_SIZE 2") 
          log_prob += log2(2/(grid_size * grid_size))/2
        else # uniformChoice
          list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
          type_id = parse(Int, split(split(list_expr_str, "prev addedObjType")[end], " ")[1])
          # compute number of objects of type type_id at time t 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

          alive_object_ids = filter(id -> !isnothing(object_mapping[id][time]), object_ids_with_type)
          log_prob += log2(1/length(alive_object_ids))
        end
      end
    end
  end

  log_prob
end

function compute_log_likelihood_empa_lower_bound(on_clauses, concrete_update_function_matrix, abstract_update_function_matrix, object_decomposition) 
  object_types, object_mapping, background, _ = object_decomposition
  log_prob = 0

  # new from cisc: non-deterministic events
  # (addObj uniformChoice), (update function uniformChoice), (update function closestRandom)

  # find on-clauses with non-deterministic events 
  on_clauses_with_nondeterministic_events = filter(c -> occursin("uniformChoice", split(c, "\n")[1]), on_clauses)

  for time in size(concrete_update_function_matrix)[2] 
    # check if any update functions triggered by non-deterministic events occurred 
    all_update_funcs = map(u -> join(split(formatted_update_func, "(--> obj")[1:end - 1], "(--> obj"), vcat(concrete_update_function_matrix[:, time]...))
    for on_clause in on_clauses_with_nondeterministic_events 
      formatted_update_func = split(on_clause, "\n")[end]
      update_func = join(split(formatted_update_func, "(--> obj")[1:end - 1], "(--> obj") # get rid of the final lambda argument containing the event 
      if update_func in all_update_funcs 
        log += log2(1/10)
      end
    end

    # check if non-deterministic update functions occurred 
    for object_id in size(concrete_update_function_matrix)[1]
      u = concrete_update_function_matrix[object_id, time]
      if occursin("addObj", u)
        if occursin("uniformChoice", u) 
          list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
          type_id = parse(Int, split(split(list_expr_str, "prev addedObjType")[end], " ")[1])
          # compute number of objects of type type_id at time t 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

          alive_object_ids = filter(id -> !isnothing(object_mapping[id][time]), object_ids_with_type)
          log_prob += log2(1/length(alive_object_ids))
        end
      elseif occursin("uniformChoice", u) # Brownian motion
        # compare concrete and abstract update function matrices 
        list_expr_str = split(u, "uniformChoice ")[end][1:end-2]
        aex = parseau(list_expr_str)
        if occursin("closest", u) 
          log_prob += log2(length(filter(x -> occursin("closest", x) && !occursin("--> obj (prev obj)", x), abstract_update_function_matrix[object_id, time]))/length(aex.args))
        else 
          log_prob += log2(length(filter(x -> !occursin("closest", x) && !occursin("--> obj (prev obj)", x), abstract_update_function_matrix[object_id, time]))/length(aex.args))
        end
      elseif occursin("closestRandom", u)
        # compare concrete and abstract update function matrices 
        num_directions = length(filter(x -> occursin("closest", x), abstract_update_function_matrix[object_id, time]))
        log_prob += log2(num_directions/4)
      end

    end

  end

  log_prob
end

function compute_log_likelihood_empa(program_, observations, user_events) 
  # @show observations
  log_prob = 0
  aex = parseautumn(program_)
  program = repr(aex)

  user_events_for_interpreter = []

  if user_events != [] && (user_events[1] isa NamedTuple || user_events[1] isa Tuple)
    user_events_for_interpreter = user_events
  else
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
  end
  
  # check initial frame match 
  init_frame = interpret_over_time_observations(aex, 0)[1]
  if (!check_observations_equivalence([init_frame], observations[1:1])) 
    return -Inf 
  end

  global_env = nothing
  original_global_env = nothing
  new_env = nothing
  for time in 1:length(user_events)
    _ = try 
      readchomp(eval(Meta.parse("`rm likelihood_output_1.txt`")))
    catch e 
      e
    end

    # figure out which on-clauses are actually run
    # TODO: make nondeterministic events deterministic
    if (time == 1) 
      original_global_env = interpret_over_time(aex, 1, user_events[time:time], show_rules=1)
      global_env = deepcopy(original_global_env)
    else
      global_env.on_clauses = original_global_env.on_clauses
      global_env.show_rules = 1
      _ = Autumn.Interpret.step(aex, deepcopy(global_env), user_events[time])
      global_env.show_rules = -1
    end

    triggered_on_clauses_output = open("likelihood_output_1.txt", "r") do io
                                    read(io, String)
                                  end

    global_splits = filter(x -> x != "", split(triggered_on_clauses_output, "----- global -----"))
    on_clauses_with_nondeterminism = [] 
    for str in global_splits 
      lines = filter(x -> x != "", split(str, "\n"))
      event_update_line = lines[1]
      if (!occursin("updateObj", event_update_line) || !occursin("-->", event_update_line)) && (occursin("uniformChoice", event_update_line) || occursin("randomPositions", event_update_line))
        push!(on_clauses_with_nondeterminism, lines)      
      elseif occursin("updateObj", event_update_line) && occursin("-->", event_update_line) && occursin("uniformChoice", event_update_line)
        if ("----- updateObj 2 -----" in lines) || (("----- updateObj 3 -----" in lines) && ("object_id" in lines))
          push!(on_clauses_with_nondeterminism, lines)      
        end
      end
    end

    replacements_per_on_clause = []
    for lines in on_clauses_with_nondeterminism 
      event_update_line = lines[1]
      on_clause_replacements = []
      if (!occursin("updateObj", event_update_line) || !occursin("-->", event_update_line)) && (occursin("uniformChoice", event_update_line) || occursin("randomPositions", event_update_line)) 
        if occursin("randomPositions", event_update_line)
          event, update_ = eval(Meta.parse(event_update_line))
          random_positions_params = filter(x -> x != "", split(split(replace(replace(update_, "(" => ""), ")" => ""), "randomPositions")[end], " "))
          num_positions = length(random_positions_params) == 2 ? parse(Int, random_positions_params[2]) : 1
          random_positions_str = "(randomPositions GRID_SIZE $(num_positions))"

          possible_positions = map(c -> c.position, observations[time + 1])
          possible_positions_product = combinations(possible_positions, num_positions) |> collect
          for pos_tuple in possible_positions_product 
            new_updates_str = "(let ($(join(map(pos -> replace(update_, random_positions_str => "(list (Position $(pos.x) $(pos.y)))"), pos_tuple), "\n"))))"
            new_on_clause_str = "(on $(event isa Symbol ? string(event) : repr(event))\n$(new_updates_str))"
            push!(on_clause_replacements, new_on_clause_str)
          end
          push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : repr(event)) $(update_))", on_clause_replacements, global_env.current_var_values[:GRID_SIZE]^(num_positions)])
        elseif occursin("uniformChoice", event_update_line)
          if occursin("addObj", event_update_line) 
            event, update_ = eval(Meta.parse(event_update_line))
            var_to_update = filter(x -> x != "", split(update_[length("( = "):end], " "))[1]
            added_obj_str = replace(update_, "(= $(var_to_update) (addObj $(var_to_update) " => "")[1:end-2]
            a = parseautumn(added_obj_str)
            list_value = interpret(a.args[2].args[2], global_env)[1]
            list_length = length(list_value)
            possible_positions = intersect(list_value, map(c -> c.position, observations[time + 1]))
            for pos in possible_positions 
              new_added_obj_str = replace(added_obj_str, repr(a.args[2].args[2]) => "(list (Position $(pos.x) $(pos.y)))")
              new_update_str = "(= $(var_to_update) (addObj $(var_to_update) $(new_added_obj_str)))"
              new_on_clause_str = "(on $(event isa Symbol ? string(event) : repr(event))\n$(new_update_str))"
              push!(on_clause_replacements, new_on_clause_str)  
            end
            push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : repr(event)) $(update_))", on_clause_replacements, length(list_value)])
          else
            # TODO

          end
        end
      elseif occursin("updateObj", event_update_line) && occursin("-->", event_update_line) && occursin("uniformChoice", event_update_line)
        # only handle object-specific ones to start
        object_ids = map(x -> parse(Int, lines[x + 1]), findall(x -> x == "object_id", lines))
        list, map_arg, map_body, filter_arg, filter_body = eval(Meta.parse(lines[findall(x -> x == "----- updateObj 3 -----", lines)[1] + 1]))
        event, update_ = eval(Meta.parse(event_update_line))

        map_body_aex = parseautumn(map_body)
        uniformChoice_list_aex = map_body_aex.args[end].args
        uniformChoice_list_strings = map(x -> repr(x), uniformChoice_list_aex)

        possibility_cross_product = Iterators.product([uniformChoice_list_strings for i in object_ids]...) |> collect
        for possibility in possibility_cross_product       
          new_updates = map(i -> replace(replace(update_, map_body => possibility[i]), "(--> $(string(filter_arg)) $(filter_body))" => "(--> $(string(filter_arg)) (& (== (.. obj id) $(object_ids[i])) $(filter_body)))"), 1:length(object_ids))
          new_updates_str = "(let ($(join(new_updates, "\n"))))"
          new_on_clause_str = "(on $(event isa Symbol ? string(event) : repr(event))\n$(new_updates_str))"
          push!(on_clause_replacements, new_on_clause_str)
        
        end
        push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : repr(event)) $(update_))", on_clause_replacements, length(uniformChoice_list_strings)^(length(object_ids))])
      end
    end

    replacements_per_program = Iterators.product(map(r -> r[2], replacements_per_on_clause)...) |> collect

    prob = 0
    for i in 1:length(replacements_per_program) 
      r = replacements_per_program[i]
      new_program = program
      for j in 1:length(r)
        new_program = replace(new_program, replacements_per_on_clause[j][1] => r[j])
      end
      
      if time == 1 
        # @show new_program
        deterministic_observations, env = interpret_over_time_observations_and_env(parseautumn(new_program), 1, user_events[time:time])
        deterministic_observations = deterministic_observations[end]
      else 
        aex_, env = start(parseautumn(new_program)) # initialize new environment with new on_clauses
        env_copy = deepcopy(global_env) 
        env_copy.on_clauses = env.on_clauses
        env = Autumn.Interpret.step(aex_, env_copy, user_events[time]) # evaluate new on-clauses in environment
        deterministic_observations = AutumnStandardLibrary.renderScene(env.state.scene, env.state)
      end
      
      if check_observations_equivalence([deterministic_observations], observations[time + 1:time + 1])
        new_env = env
        prob += prod(map(i -> 1/replacements_per_on_clause[i][3], 1:length(replacements_per_on_clause)))
      end
    end
    
    if prob == 0 
      return -Inf
    else 
      global_env = new_env
    end

    log_prob += log2(prob)
    # @show log_prob
  end
  log_prob
end

"""
- function indicating which on-clauses are run when interpreting a program 
-- easy for global events 
-- for object-specific events: check inside updateObj 
-- can make this a boolean flag in the interpreter: can print out the on-clause AExpr or something?

once we've detected which on-clauses are true/run, then we can perform various modifications: 
- convert each one into a deterministic version:
-- global events: turn the random part of the on-clause event to true 
-- uniformChoice in update function: pick one of the options 
-- closestRandom in update function: pick one of the options (what the options are must be computed)
(-- have to break up the object-specific events into their individual id's)
basically, we can perform these modifications fairly easily at the level of the AST/AExpr, rather than the string level (obviously, I guess)

once we've done this, we can add the part where we keep track of object decompositions with 
different latent states, and propogate that through the program. 

"""

function check_observations_equivalence(observations1, observations2)
  for i in 1:length(observations1) 
    obs1 = observations1[i]
    obs2 = observations2[i]
    obs1_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs1), by=x -> repr(x))
    obs2_tuples = sort(map(cell -> (cell.position.x, cell.position.y, cell.color), obs2), by=x -> repr(x))
  
    # # @show obs1_tuples 
    # # @show obs2_tuples

    if obs1_tuples != obs2_tuples
      # @show i
      # @show obs1_tuples 
      # @show obs2_tuples
      return false
    end
  end
  true
end