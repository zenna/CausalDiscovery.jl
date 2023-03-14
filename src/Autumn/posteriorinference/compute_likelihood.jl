include("../generativemodel/full_synthesis.jl");
using Combinatorics

function compute_log_likelihood(program_, observations, user_events) 
  # @show observations
  log_prob = 0
  aex = parseautumn(replace(program_, "(uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1" => "1 (uniformChoice (range 10))"))
  program = repr(aex)

  aex, _ = start(aex)

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
  init_frame, original_global_env = interpret_over_time_observations_and_env(aex, 0)
  if (!check_observations_equivalence(init_frame, observations[1:1])) 
    return -Inf 
  end

  global_envs = [[original_global_env, 1]]
  new_envs = []
  for time in 1:length(user_events)
    _ = try 
      readchomp(eval(Meta.parse("`rm likelihood_output_1.txt`")))
    catch e 
      e
    end

    # figure out which on-clauses are actually run
    if (time == 1) 
      _ = interpret_over_time(aex, 1, user_events[time:time], show_rules=1)
    end 

    for global_env_tup in global_envs 
      global_env, global_prob_factor = global_env_tup 

      if time != 1
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
        if (!occursin("updateObj", event_update_line) || !occursin("-->", event_update_line)) && (occursin("uniformChoice", event_update_line) || occursin("randomPositions", event_update_line) || occursin("closestRandom", event_update_line))
          push!(on_clauses_with_nondeterminism, lines)      
        elseif occursin("updateObj", event_update_line) && occursin("-->", event_update_line) && (occursin("uniformChoice", event_update_line) || occursin("closestRandom", event_update_line))
          if ("----- updateObj 2 -----" in lines) || (("----- updateObj 3 -----" in lines) && ("object_id" in lines))
            push!(on_clauses_with_nondeterminism, lines)
          end
        end
      end
  
      replacements_per_on_clause = []
      for lines in on_clauses_with_nondeterminism 
        event_update_line = lines[1]
        event, update_ = eval(Meta.parse(event_update_line))
        on_clause_replacements = []
        determ_update_nondeterm_event = false
        event_ = event isa Symbol ? string(event) : event isa String ? event : repr(event))
        if occursin("uniformChoice (range", event_)
          parts = filter(y -> y != "", split(filter(x -> x != "", split(replace(replace(event_, "(" => ""), ")" => ""), "uniformChoice (range "))[end], " "))[1]
          event_prob_factor = 1/parse(Int, parts)
        else
          event_prob_factor = 1
        end
  
        if (!occursin("updateObj", update_) || !occursin("-->", update_)) && (occursin("uniformChoice", update_) || occursin("randomPositions", update_) || occursin("closestRandom", update_)) && occursin("addObj", update_)
          if occursin("randomPositions", update_)
            
            random_positions_params = filter(x -> x != "", split(split(replace(replace(update_, "(" => ""), ")" => ""), "randomPositions")[end], " "))
            num_positions = length(random_positions_params) == 2 ? parse(Int, random_positions_params[2]) : 1
            random_positions_str = "(randomPositions GRID_SIZE $(num_positions))"
  
            possible_positions = map(c -> c.position, observations[time + 1])
            possible_positions_product = combinations(possible_positions, num_positions) |> collect
            for pos_tuple in possible_positions_product 
              new_updates_str = "(let ($(join(map(pos -> replace(update_, random_positions_str => "(list (Position $(pos.x) $(pos.y)))"), pos_tuple), "\n"))))"
              new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_updates_str))"
              push!(on_clause_replacements, new_on_clause_str)
            end
            push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(global_env.current_var_values[:GRID_SIZE]^(2 * num_positions)) for i in 1:length(on_clause_replacements)]])
          elseif occursin("uniformChoice", update_)
            if occursin("addObj", update_) 
              var_to_update = filter(x -> x != "", split(update_[length("( = "):end], " "))[1]
              added_obj_str = replace(update_, "(= $(var_to_update) (addObj $(var_to_update) " => "")[1:end-2]
              a = parseautumn(added_obj_str)
              list_value = interpret(a.args[2].args[2], global_env)[1]
              list_length = length(list_value)
              possible_positions_without_repeats = intersect(list_value, map(c -> c.position, observations[time + 1]))
              possible_positions = []
              for pos in possible_positions_without_repeats
                push!(possible_positions, filter(p -> p == pos, list_value)...)
              end

              for pos in possible_positions 
                new_added_obj_str = replace(added_obj_str, repr(a.args[2].args[2]) => "(list (Position $(pos.x) $(pos.y)))")
                new_update_str = "(= $(var_to_update) (addObj $(var_to_update) $(new_added_obj_str)))"
                new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_update_str))"
                push!(on_clause_replacements, new_on_clause_str)  
              end
              push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(length(list_value)) for i in 1:length(on_clause_replacements)]])
            end
          end
        elseif occursin("updateObj", update_) && occursin("-->", update_) && occursin("uniformChoice", update_)
          # only handle object-specific ones to start
          object_ids = map(x -> parse(Int, lines[x + 1]), findall(x -> x == "object_id", lines))
          list, map_arg, map_body, filter_arg, filter_body = eval(Meta.parse(lines[findall(x -> x == "----- updateObj 3 -----", lines)[1] + 1]))
  
          map_body_aex = parseautumn(map_body)
          uniformChoice_list_aex = map_body_aex.args[end].args
          uniformChoice_list_strings = map(x -> repr(x), uniformChoice_list_aex)
  
          possibility_cross_product = Iterators.product([uniformChoice_list_strings for i in object_ids]...) |> collect
          for possibility in possibility_cross_product       
            new_updates = map(i -> replace(replace(update_, map_body => possibility[i]), "(--> $(string(filter_arg)) $(filter_body))" => "(--> $(string(filter_arg)) (& (== (.. obj id) $(object_ids[i])) $(filter_body)))"), 1:length(object_ids))
            new_updates_str = "(let ($(join(new_updates, "\n"))))"
            new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_updates_str))"
            push!(on_clause_replacements, new_on_clause_str)
          
          end
          push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(length(uniformChoice_list_strings)^(length(object_ids))) for i in 1:length(on_clause_replacements)]])
        elseif occursin("updateObj", update_) && occursin("-->", update_) && occursin("closestRandom", update_)
          object_ids = sort(map(x -> parse(Int, lines[x + 1]), findall(x -> x == "object_id", lines)))
          list, map_arg, map_body, filter_arg, filter_body = eval(Meta.parse(lines[findall(x -> x == "----- updateObj 3 -----", lines)[1] + 1]))
          var_to_update = filter(x -> x != "", split(update_[length("( = "):end], " "))[1]          
          id_to_closest_variants = Dict()
          for id in object_ids
            orig_position = filter(o -> o.id == id, global_env.current_var_values[Symbol(var_to_update)])[1].origin 
            possibilities = []
            for func in ["closestLeft", "closestRight", "closestUp", "closestDown"]
              new_map_body = replace(map_body, "closestRandom" => func)
              new_filter_body = "(& (== (.. obj id) $(id)) $(filter_body))"
              expr_to_eval = parseautumn(replace(replace(update_[length("( = $(var_to_update)"):end - 1], map_body => new_map_body), (filter_body isa Symbol ? string(filter_body) : filter_body) => new_filter_body))
              new_position = interpret(expr_to_eval, deepcopy(global_env))[1][1].origin 
              if new_position != orig_position 
                push!(possibilities, func)
              end
  
              if possibilities != []
                id_to_closest_variants[id] = possibilities
              else 
                id_to_closest_variants[id] = ["closestLeft"]
              end  
            end
          end

          possibility_cross_product = Iterators.product([id_to_closest_variants[id] for id in object_ids]...) |> collect
          for possibility in possibility_cross_product       
            new_updates = map(i -> replace(replace(update_, map_body => replace(map_body, "closestRandom" => possibility[i])), "(--> $(string(filter_arg)) $(filter_body))" => "(--> $(string(filter_arg)) (& (== (.. obj id) $(object_ids[i])) $(filter_body)))"), 1:length(object_ids))
            new_updates_str = "(let ($(join(new_updates, "\n"))))"
            new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_updates_str))"
            push!(on_clause_replacements, new_on_clause_str)
          end
          push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(prod(map(id -> length(id_to_closest_variants[id]), object_ids))) for i in 1:length(on_clause_replacements)]])  

        elseif occursin("uniformChoice", update_)
          var_to_update = filter(x -> x != "", split(update_[length("( = "):end], " "))[1]
          updated_obj_str = replace(update_, "(= $(var_to_update) " => "")[1:end-1]
          a = parseautumn(updated_obj_str)
          list_value = interpret(a.args[2], deepcopy(global_env))[1]
          list_length = length(list_value)
          for obj_expr in a.args[2].args
            new_updates_str = "(= $(var_to_update) $(repr(obj_expr)))"
            new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_updates_str))"
            push!(on_clause_replacements, new_on_clause_str)
          end
          push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(list_length) for i in 1:length(on_clause_replacements)]])
        elseif occursin("closestRandom", update_)
          var_to_update = filter(x -> x != "", split(update_[length("( = "):end], " "))[1]
          updated_obj_str = replace(update_, "(= $(var_to_update) " => "")[1:end-1]
          orig_position = global_env.current_var_values[Symbol(var_to_update)].origin
          possibilities = []
          for func in ["closestLeft", "closestRight", "closestUp", "closestDown"]
            new_update_str = replace(updated_obj_str, "closestRandom" => func)
            expr_to_eval = parseautumn(new_update_str)
            new_position = interpret(expr_to_eval, deepcopy(global_env))[1].origin 
            if new_position != orig_position 
              push!(possibilities, func)
            end
          end

          if possibilities == []
            possibilities = ["closestLeft"]
          end

          for possibility in possibilities 
            new_updates_str = replace(update_, "closestRandom" => possibility)
            new_on_clause_str = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event)))\n$(new_updates_str))"
            push!(on_clause_replacements, new_on_clause_str)
          end
          push!(replacements_per_on_clause, ["(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))", on_clause_replacements, [event_prob_factor/(length(possibilities)) for i in 1:length(on_clause_replacements)]])
        elseif occursin("(uniformChoice (range", event isa Symbol ? string(event) : event) # update is deterministic, but event is not
          true_on_clause = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))"
          false_on_clause = replace(true_on_clause, "range $(parse(Int, 1/event_prob_factor))" => "range 0")
          push!(replacements_per_on_clause, [true_on_clause, [true_on_clause, false_on_clause], [event_prob_factor, 1 - event_prob_factor]])
          determ_update_nondeterm_event = true          
        end

        if !determ_update_nondeterm_event && occursin("(uniformChoice (range", event isa Symbol ? string(event) : event)
          true_on_clause = "(on $(event isa Symbol ? string(event) : (event isa String ? event : repr(event))) $(update_))"
          false_on_clause = replace(true_on_clause, "range $(parse(Int, 1/event_prob_factor))" => "range 0")

          push!(replacements_per_on_clause[end][2], false_on_clause)
          push!(replacements_per_on_clause[end][3], 1 - event_prob_factor)
        end

      end
  
      replacements_per_program = Iterators.product(map(r -> r[2], replacements_per_on_clause)...) |> collect
      probabilities_per_program = Iterators.product(map(r -> r[3], replacements_per_on_clause)...) |> collect

      prob = 0
      for i in 1:length(replacements_per_program) 
        r = replacements_per_program[i]
        new_program = program
        for j in 1:length(r)
          new_program = replace(new_program, replacements_per_on_clause[j][1] => r[j])
        end
        
        if time == 1 
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
          println("woo")
          println(new_program)
          add_prob = prod(probabilities_per_program[i])
          prob += add_prob
          push!(new_envs, (env, add_prob))
        end
      end
      prob = prob * global_prob_factor
      
      if prob == 0 
        return -Inf
      else 
        global_envs = unique_envs(new_envs, prob)
        new_envs = []
      end
  
      log_prob += log2(prob)
      # @show log_prob
    end

  end
  log_prob
end

function unique_envs(new_envs, total_prob) 
  envs_dict = Dict()
  for tup in new_envs 
    env, prob = tup
    objects = env.state.scene.objects 
    key = Tuple(map(o -> (o.id, length(keys(o.custom_fields)) != 0 ? Tuple(map(f -> o.custom_fields[f], sort(collect(keys(o.custom_fields))))) : ()), sort(objects, by=o -> o.id)))
    if key in keys(envs_dict )
      envs_dict[key][2] += prob
    else 
      envs_dict[key] = [env, prob]
    end
  end
  for k in keys(envs_dict) 
    envs_dict[k][2] = envs_dict[k][2]/total_prob
  end
  collect(values(envs_dict))
end

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