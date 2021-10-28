"""On-clause generation, where we collect all unsolved (latent state dependent) on-clauses at the end"""
function generate_on_clauses_GLOBAL(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, sketch=false) 
  object_types, object_mapping, background, dim = object_decomposition
  solutions = []

  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  # filtered_matrix = filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition)[1]
  
  filtered_matrices = []

  # add non-random filtered matrices to filtered_matrices
  non_random_matrix = deepcopy(matrix)
  for row in 1:size(non_random_matrix)[1]
    for col in 1:size(non_random_matrix)[2]
      non_random_matrix[row, col] = filter(x -> !occursin("randomPositions", x), non_random_matrix[row, col])
    end
  end
  filtered_non_random_matrices = filter_update_function_matrix_multiple(non_random_matrix, object_decomposition, multiple=true)
  # filtered_non_random_matrices = filtered_non_random_matrices[1:min(4, length(filtered_non_random_matrices))]
  push!(filtered_matrices, filtered_non_random_matrices...)
  

  # add direction-bias-filtered matrix to filtered_matrices 
  pre_filtered_matrix = pre_filter_with_direction_biases(deepcopy(matrix), user_events, object_decomposition) 
  push!(filtered_matrices, filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition, multiple=false)...)

  # add random filtered matrices to filtered_matrices 
  random_matrix = deepcopy(matrix)
  for row in 1:size(random_matrix)[1]
    for col in 1:size(random_matrix)[2]
      if filter(x -> occursin("uniformChoice", x) || occursin("randomPositions", x), random_matrix[row, col]) != []
        random_matrix[row, col] = filter(x -> occursin("uniformChoice", x) || occursin("randomPositions", x), random_matrix[row, col])
      end
    end
  end
  filtered_random_matrices = filter_update_function_matrix_multiple(random_matrix, object_decomposition, multiple=true)
  filtered_random_matrices = filtered_random_matrices[1:min(4, length(filtered_random_matrices))]
  push!(filtered_matrices, filtered_random_matrices...)

  # add "chaos" solution to filtered_matrices 
  filtered_unformatted_matrix = filter_update_function_matrix_multiple(unformatted_matrix, object_decomposition, multiple=false)[1]
  push!(filtered_matrices, filter_update_function_matrix_multiple(construct_chaos_matrix(filtered_unformatted_matrix, object_decomposition), object_decomposition, multiple=false)...)

  filtered_matrices = filtered_matrices[1:1]

  for filtered_matrix_index in 1:length(filtered_matrices)
    # @show filtered_matrix_index
    # @show length(filtered_matrices)
    # @show solutions
    filtered_matrix = filtered_matrices[filtered_matrix_index]

    if (length(filter(x -> x[1] != [], solutions)) >= desired_solution_count) # || ((length(filter(x -> x[1] != [], solutions)) > 0) && length(filter(x -> occursin("randomPositions", x), vcat(vcat(filtered_matrix...)...))) > 0) 
      # if we have reached a sufficient solution count or have found a solution before trying random solutions, exit
      println("BREAKING")
      # @show length(solutions)
      break
    end

    # initialize variables
    on_clauses = []
    global_var_dict = Dict()    
    global_object_decomposition = deepcopy(object_decomposition)
    global_state_update_times_dict = Dict(1 => ["" for x in 1:length(user_events)])
    object_specific_state_update_times_dict = Dict()
  
    global_state_update_on_clauses = []
    object_specific_state_update_on_clauses = []
    state_update_on_clauses = []

    # construct anonymized_filtered_matrix
    anonymized_filtered_matrix = deepcopy(filtered_matrix)
    for i in 1:size(matrix)[1]
      for j in 1:size(matrix)[2]
        anonymized_filtered_matrix[i,j] = [replace(filtered_matrix[i, j][1], "id) $(i)" => "id) x")]
      end
    end

    # construct dictionary mapping type id to unsolved update functions (at initialization, all update functions)
    update_functions_dict = Dict()
    type_ids = sort(map(t -> t.id, object_types))
    for type_id in type_ids 
      object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
      if object_ids_with_type != [] 
        update_functions_dict[type_id] = unique(filter(r -> r != "", vcat(map(id -> vcat(anonymized_filtered_matrix[id, :]...), object_ids_with_type)...)))
      end
    end

    # return values: state_based_update_functions_dict has form type_id => [unsolved update functions]
    new_on_clauses, state_based_update_functions_dict, observation_vectors_dict, addObj_params_dict, global_event_vector_dict, ordered_update_functions_dict = generate_stateless_on_clauses(update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set)
    push!(on_clauses, new_on_clauses...)
 
    # check if all update functions were solved; if not, proceed with state generation procedure
    if length(collect(keys(state_based_update_functions_dict))) == 0 
      push!(solutions, ([deepcopy(on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
    else # GENERATE NEW STATE 
      type_ids = collect(keys(state_based_update_functions_dict))

      # compute co-occurring event for each state-based update function 
      co_occurring_events_dict = Dict() # keys are tuples (type_id, co-occurring event), values are lists of update_functions with that co-occurring event
      events = collect(keys(global_event_vector_dict)) # ["left", "right", "up", "down", "clicked", "true"]
      for type_id in type_ids 
        for update_function in state_based_update_functions_dict[type_id]
          # compute co-occurring event 
          object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
          update_function_times_dict = Dict(map(obj_id -> obj_id => findall(r -> r == [update_function], anonymized_filtered_matrix[obj_id, :]), object_ids_with_type))
          co_occurring_events = []
          for event in events
            if global_event_vector_dict[event] isa AbstractArray
              event_vector = global_event_vector_dict[event]
              co_occurring = foldl(&, map(update_function_times -> is_co_occurring(event, event_vector, update_function_times), collect(values(update_function_times_dict))), init=true)      
            
              if co_occurring
                false_positive_count = foldl(+, map(k -> num_false_positives(event_vector, update_function_times_dict[k], object_mapping[k]), collect(keys(update_function_times_dict))), init=0)
                push!(co_occurring_events, (event, false_positive_count))
              end
            elseif (Set(collect(keys(global_event_vector_dict[event]))) == Set(collect(keys(update_function_times_dict))))
              event_vector = global_event_vector_dict[event]
              co_occurring = foldl(&, map(id -> is_co_occurring(event, event_vector[id], update_function_times_dict[id]), collect(keys(update_function_times_dict))), init=true)
              
              if co_occurring
                false_positive_count = foldl(+, map(id -> num_false_positives(event_vector[id], update_function_times_dict[id], object_mapping[id]), collect(keys(update_function_times_dict))), init=0)
                push!(co_occurring_events, (event, false_positive_count))
              end
            end
          end
          co_occurring_events = sort(filter(x -> !occursin("|", x[1]), co_occurring_events), by=x -> x[2]) # [1][1]
          @show co_occurring_events
          if filter(x -> !occursin("globalVar", x[1]), co_occurring_events) != []
            co_occurring_events = filter(x -> !occursin("globalVar", x[1]), co_occurring_events)
          end
          best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
          # # @show best_co_occurring_events
          co_occurring_event = best_co_occurring_events[1][1]        

          if (type_id, co_occurring_event) in keys(co_occurring_events_dict)
            push!(co_occurring_events_dict[(type_id, co_occurring_event)], update_function)
          else
            co_occurring_events_dict[(type_id, co_occurring_event)] = [update_function]
          end
        end
      end

      @show co_occurring_events_dict

      # initialize problem contexts 
      problem_contexts = []
      solutions_per_matrix_count = 0 

      problem_context = (co_occurring_events_dict, 
                         on_clauses,
                         global_var_dict,
                         global_object_decomposition, 
                         global_state_update_times_dict,
                         object_specific_state_update_times_dict,
                         global_state_update_on_clauses,
                         object_specific_state_update_on_clauses,
                         state_update_on_clauses)

      push!(problem_contexts, problem_context)
      first_context = true
      failed = false
      while problem_contexts != [] && solutions_per_matrix_count < desired_per_matrix_solution_count
        co_occurring_events_dict, 
        on_clauses,
        global_var_dict,
        global_object_decomposition, 
        global_state_update_times_dict,
        object_specific_state_update_times_dict,
        global_state_update_on_clauses,
        object_specific_state_update_on_clauses,
        state_update_on_clauses = problem_contexts[1]

        problem_contexts = problem_contexts[2:end]
        
        # generate new state until all unmatched update functions are matched 
        while length(collect(keys(co_occurring_events_dict))) != 0
          type_id, co_occurring_event = sort(collect(keys(co_occurring_events_dict)), by=tuple -> length(tuple[2]))[1]
          object_type = filter(t -> t.id == type_id, object_types)
          
          all_update_functions = co_occurring_events_dict[(type_id, co_occurring_event)]
          if foldl(|, map(u -> occursin("addObj", u), all_update_functions))
            update_functions = filter(u -> occursin("addObj", u), all_update_functions)
            filter!(u -> !occursin("addObj", u), all_update_functions)
            if all_update_functions == [] 
              delete!(co_occurring_events_dict, (type_id, co_occurring_event))              
            end
          else
            update_functions = all_update_functions 
            delete!(co_occurring_events_dict, (type_id, co_occurring_event))
          end

          # construct update_function_times_dict for this type_id/co_occurring_event pair 
          times_dict = Dict() # form: update function => object_id => times when update function occurred for object_id
          object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
          for update_function in update_functions 
            times_dict[update_function] = Dict(map(id -> id => findall(r -> r == update_function, vcat(anonymized_filtered_matrix[id, :]...)), object_ids_with_type))
          end

          # determine if state is global or object-specific 
          state_is_global = true 
          if foldl(&, map(u -> occursin("addObj", u), update_functions), init=true) || length(object_ids_with_type) == 1
            state_is_global = true
          else
            for update_function in update_functions 
              for time in 1:length(user_events)
                observation_values = map(id -> observation_vectors_dict[update_function][id][time], object_ids_with_type)
                if (0 in observation_values) && (1 in observation_values)
                  @show update_function 
                  @show time 
                  state_is_global = false
                  break
                end
              end
              if !state_is_global
                break
              end
            end
          end

          if state_is_global 
            # construct new global state 
            if foldl(&, map(update_rule -> occursin("addObj", update_rule), update_functions))
              object_trajectories = map(id -> anonymized_filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_ids_with_type[1]])[1].type.id, collect(keys(object_mapping))))
              true_times = unique(vcat(map(trajectory -> findall(rule -> rule in update_functions, vcat(trajectory...)), object_trajectories)...))
              object_trajectory = []
            else 
              ids_with_rule = map(idx -> object_ids_with_type[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] in update_functions, anonymized_filtered_matrix[id, :]), object_ids_with_type)))
              trajectory_lengths = map(id -> length(unique(filter(x -> x != "", anonymized_filtered_matrix[id, :]))), ids_with_rule)
              max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
              object_id = ids_with_rule[max_index]
              object_trajectory = anonymized_filtered_matrix[object_id, :]
              true_times = unique(findall(rule -> rule in update_functions, vcat(object_trajectory...)))
            end

            if sketch 
              state_solutions = generate_global_multi_automaton_sketch(co_occurring_event, times_dict, global_event_vector_dict, object_trajectory, global_var_dict, global_state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, interval_painting_param, true)
            else
              state_solutions = generate_new_state_GLOBAL(co_occurring_event, times_dict, global_event_vector_dict, object_trajectory, global_var_dict, global_state_update_times_dict, object_decomposition, type_id, user_events, desired_per_matrix_solution_count)
            end

            if length(filter(sol -> sol[1] != "", state_solutions)) == 0 # failure 
              failed = true 
              println("STATE SEARCH FAILURE")
              break 
            else
              state_solutions = filter(sol -> sol[1] != "", state_solutions) 

              # old values 
              old_on_clauses = deepcopy(on_clauses)
              old_global_object_decomposition = deepcopy(global_object_decomposition)
              old_global_state_update_times_dict = deepcopy(global_state_update_times_dict)
              old_object_specific_state_update_times_dict = deepcopy(object_specific_state_update_times_dict)
              old_global_state_update_on_clauses = deepcopy(global_state_update_on_clauses)
              old_object_specific_state_update_on_clauses = deepcopy(object_specific_state_update_on_clauses)
              old_state_update_on_clauses = deepcopy(state_update_on_clauses)

              # update current problem context with state solution 
              curr_state_solution = state_solutions[1]
              new_on_clauses, new_global_var_dict, new_state_update_times_dict = curr_state_solution 
              println("GLOBAL STATE SOLUTION")
              @show new_on_clauses 
              @show new_global_var_dict 
              @show new_state_update_times_dict
              
              # formatting 
              group_addObj_rules, addObj_rules, addObj_count = addObj_params_dict[type_id]
              formatted_on_clauses = map(on_clause -> format_on_clause(split(replace(on_clause, ".. obj id) x" => ".. obj id) $(object_ids_with_type[1])"), "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), ".. obj id) x" => ".. obj id) $(object_ids_with_type[1])"), object_ids_with_type[1], object_ids_with_type, object_type, group_addObj_rules, addObj_rules, object_mapping, true, grid_size, addObj_count), new_on_clauses)
              push!(on_clauses, formatted_on_clauses...)
              
              global_var_dict = deepcopy(new_global_var_dict) 
              global_state_update_on_clauses = vcat(map(k -> filter(x -> x != "", new_state_update_times_dict[k]), collect(keys(new_state_update_times_dict)))...) # vcat(state_update_on_clauses..., filter(x -> x != "", new_state_update_times)...)
              state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
              global_state_update_times_dict = new_state_update_times_dict

              state_update_on_clauses = unique(state_update_on_clauses)
              on_clauses = unique(on_clauses)

              println("ADDING EVENT WITH NEW STATE")
              # @show update_rule
              @show new_on_clauses
              @show length(on_clauses)
              @show on_clauses

              for state_solution in state_solutions[2:end]
                # add new problem contexts 
                new_context_on_clauses, new_context_new_global_var_dict, new_context_new_state_update_times_dict = state_solution

                new_context_on_clauses = vcat(new_context_on_clauses..., deepcopy(old_on_clauses)...)
                new_context_global_object_decomposition = deepcopy(old_global_object_decomposition)
                new_context_global_state_update_times_dict = deepcopy(old_global_state_update_times_dict)
                new_context_object_specific_state_update_times_dict = deepcopy(old_object_specific_state_update_times_dict)
                new_context_global_state_update_on_clauses = deepcopy(old_global_state_update_on_clauses)
                new_context_object_specific_state_update_on_clauses = deepcopy(old_object_specific_state_update_on_clauses)
                new_context_state_update_on_clauses = deepcopy(old_state_update_on_clauses)

                formatted_new_context_on_clauses = map(on_clause -> format_on_clause(split(replace(on_clause, ".. obj id) x" => ".. obj id) $(object_ids_with_type[1])"), "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), ".. obj id) x" => ".. obj id) $(object_ids_with_type[1])"), object_ids_with_type[1], object_ids_with_type, object_type, group_addObj_rules, addObj_rules, object_mapping, true, grid_size, addObj_count), new_context_on_clauses)
                push!(new_context_on_clauses, formatted_new_context_on_clauses...)
                new_context_global_var_dict = new_context_new_global_var_dict
                new_context_global_state_update_on_clauses = vcat(map(k -> filter(x -> x != "", new_context_new_state_update_times_dict[k]), collect(keys(new_context_new_state_update_times_dict)))...) # vcat(state_update_on_clauses..., filter(x -> x != "", new_state_update_times)...)
                new_context_state_update_on_clauses = vcat(new_context_global_state_update_on_clauses, new_context_object_specific_state_update_on_clauses)
                new_context_global_state_update_times_dict = new_context_new_state_update_times_dict

                new_context_state_update_on_clauses = unique(new_context_state_update_on_clauses)
                new_context_on_clauses = unique(new_context_on_clauses)

                problem_context = (deepcopy(co_occurring_events_dict), 
                                   new_context_on_clauses,
                                   new_context_global_var_dict,
                                   new_context_global_object_decomposition, 
                                   new_context_global_state_update_times_dict,
                                   new_context_object_specific_state_update_times_dict,
                                   new_context_global_state_update_on_clauses,
                                   new_context_object_specific_state_update_on_clauses,
                                   new_context_state_update_on_clauses )

                push!(problem_contexts, problem_context)

              end
            end
          else 

            # construct new object-specific state
            if sketch 
              new_on_clauses, new_state_update_on_clauses, new_object_decomposition, new_object_specific_state_update_times_dict = generate_object_specific_multi_automaton_sketch(co_occurring_event, update_functions, times_dict, global_event_vector_dict, type_id, global_object_decomposition, object_specific_state_update_times_dict, global_var_dict, true)
            else
              new_on_clauses, new_state_update_on_clauses, new_object_decomposition, new_object_specific_state_update_times_dict = generate_new_object_specific_state_GLOBAL(co_occurring_event, update_functions, times_dict, global_event_vector_dict, type_id, global_object_decomposition, object_specific_state_update_times_dict, global_var_dict)
            end
            if new_on_clauses == []
              failed = true 
              break
            else
              # # @show new_object_specific_state_update_times_dict
              object_specific_state_update_times_dict = new_object_specific_state_update_times_dict
  
              # on_clause = format_on_clause(split(on_clause, "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), "(== (.. obj id) x)" => "(== (.. obj id) $(object_ids[1]))"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false)
              push!(on_clauses, new_on_clauses...)
  
              global_object_decomposition = new_object_decomposition
              object_types, object_mapping, background, dim = global_object_decomposition
              
              println("UPDATEEE")
              # # @show global_object_decomposition
  
              # new_state_update_on_clauses = map(x -> format_on_clause(split(x, "\n")[2][1:end-1], replace(split(x, "\n")[1], "(on " => ""), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false), new_state_update_on_clauses)
              object_specific_state_update_on_clauses = unique(vcat(object_specific_state_update_on_clauses..., new_state_update_on_clauses...))
              state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
              for event in collect(keys(global_event_vector_dict))
                if occursin("field1", event)
                  delete!(global_event_vector_dict, event)
                end
              end

              state_update_on_clauses = unique(state_update_on_clauses)
              on_clauses = unique(on_clauses)  
            end
          end

          # check if some update functions are actually solved by previously generated new state 
          # construct new update_functions_dict from co_occurring_events_dict 
          update_functions_dict = Dict() 
          for key in keys(co_occurring_events_dict)
            type_id, _ = key 
            update_functions = co_occurring_events_dict[key]
            if type_id in keys(update_functions_dict)
              push!(update_functions_dict[type_id], update_functions...)
            else
              update_functions_dict[type_id] = update_functions
            end
          end

          new_on_clauses, state_based_update_functions_dict, _, _, global_event_vector_dict = generate_stateless_on_clauses(update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set)          
          # if some other update functions are solved, add their on-clauses + remove them from co_occurring_events_dict 
          if new_on_clauses != [] 
            push!(on_clauses, new_on_clauses...)
            # update co_occurring_events_dict by removing 
            co_occurring_events_dict = update_co_occurring_events_dict(co_occurring_events_dict, state_based_update_functions_dict)
          end

        end

        if failed
          # move to new problem context because appropriate state was not found  
          push!(solutions, ([], [], [], Dict()))
        else
          @show filtered_matrix_index
          println("HERE I AM")
          @show on_clauses 
          @show state_update_on_clauses
          push!(solutions, ([deepcopy(on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
          # save("solution_$(Dates.now()).jld", "solution", solutions[end])
          solutions_per_matrix_count += 1 
        end

      end
    end 
  end
  @show solutions 
  solutions 
end

function update_co_occurring_events_dict(co_occurring_events_dict, state_based_update_functions_dict) 
  # remove solved update functions from co_occurring_events_dict
  for tuple in keys(co_occurring_events_dict) 
    co_occurring_events_dict[tuple] = filter(upd_func -> (tuple[1] in keys(state_based_update_functions_dict))
                                                          && (upd_func in state_based_update_functions_dict[tuple[1]]), 
                                             co_occurring_events_dict[tuple])
  end

  # remove co-occurring events associated with no update functions 
  co_occurring_tuples = deepcopy(collect(keys(co_occurring_events_dict)))
  for tuple in co_occurring_tuples
    if length(co_occurring_events_dict[tuple]) == 0 
      delete!(co_occurring_events_dict, tuple)
    end
  end
  co_occurring_events_dict
end

function generate_new_state_GLOBAL(co_occurring_event, times_dict, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, user_events, desired_per_matrix_solution_count, interval_painting_param=false) 
  println("GENERATE_NEW_STATE_GLOBAL")
  @show co_occurring_event
  @show times_dict 
  @show event_vector_dict 
  @show object_trajectory    
  @show init_global_var_dict 
  @show state_update_times_dict  
  @show object_decomposition 
  @show type_id
  @show desired_per_matrix_solution_count 
  @show interval_painting_param 
  init_state_update_times_dict = deepcopy(state_update_times_dict)
  update_functions = collect(keys(times_dict))
  failed = false
  solutions = []

  events = filter(e -> event_vector_dict[e] isa AbstractArray, collect(keys(event_vector_dict)))
  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id, ["nothing"], init_global_var_dict, collect(keys(times_dict))[1])
  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if !(e in atomic_events) || !(event_vector_dict[e] isa AbstractArray)
      delete!(small_event_vector_dict, e)
    end
  end

  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  # initialize global_var_dict
  if length(collect(keys(init_global_var_dict))) == 0 
    init_global_var_dict[1] = ones(Int, length(init_state_update_times_dict[1]))
    global_var_id = 1
  else # check if all update function times match with one value of init_global_var_dict
    global_var_id = maximum(collect(keys(init_global_var_dict))) + 1 
    init_global_var_dict[global_var_id] = ones(Int, length(init_state_update_times_dict[1]))
  end

  true_positive_times = unique(vcat(map(u -> vcat(map(id -> times_dict[u][id], collect(keys(times_dict[u])))...), update_functions)...)) # times when co_occurring_event happened and update_rule happened 
  false_positive_times = [] # times when user_event happened and update_rule didn't happen

  @show true_positive_times 
  @show false_positive_times

  # construct true_positive_times and false_positive_times 
  # # @show length(user_events)
  # # @show length(co_occurring_event_trajectory)
  for time in 1:length(co_occurring_event_trajectory)
    if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
      if foldl(&, map(update_rule -> occursin("addObj", update_rule), collect(keys(times_dict))))
        push!(false_positive_times, time)
      elseif (object_trajectory[time][1] != "")
        push!(false_positive_times, time)
      end     
    end
  end

  # compute ranges in which to search for events 
  ranges = []

  update_functions = collect(keys(times_dict))
  update_function_indices = Dict(map(u -> u => findall(x -> x == u, update_functions)[1], update_functions))
  global_var_value = length(update_functions)

  # construct augmented true positive times 
  augmented_true_positive_times_dict = Dict(map(u -> u => vcat(map(id -> map(t -> (t, update_function_indices[u]), times_dict[u][id]), collect(keys(times_dict[u])))...), update_functions))
  augmented_true_positive_times = vcat(collect(values(augmented_true_positive_times_dict))...)  

  augmented_false_positive_times = map(t -> (t, global_var_value + 1), false_positive_times)
  init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

  for i in 1:(length(init_augmented_positive_times)-1)
    prev_time, prev_value = init_augmented_positive_times[i]
    next_time, next_value = init_augmented_positive_times[i + 1]
    if prev_value != next_value
      push!(ranges, (init_augmented_positive_times[i], init_augmented_positive_times[i + 1]))
    end
  end
  println("WHY THO")
  # @show init_state_update_times_dict 

  # filter ranges where both the range's start and end times are already included
  ranges = unique(ranges)
  new_ranges = []
  for range in ranges
    start_tuples = map(range -> range[1], filter(r -> r != range, ranges))
    end_tuples = map(range -> range[2], filter(r -> r != range, ranges))
    if !((range[1] in start_tuples) && (range[2] in end_tuples))
      push!(new_ranges, range)      
    end
  end

  init_grouped_ranges = group_ranges(new_ranges)
  # @show init_grouped_ranges

  init_extra_global_var_values = Dict(map(u -> update_function_indices[u] => [], update_functions))

  problem_contexts = [(deepcopy(init_grouped_ranges), deepcopy(init_augmented_positive_times), deepcopy(init_state_update_times_dict), deepcopy(init_global_var_dict), deepcopy(init_extra_global_var_values))]
  split_orders = []
  old_augmented_positive_times = []
  while (length(problem_contexts) > 0) && length(solutions) < desired_per_matrix_solution_count 
    grouped_ranges, augmented_positive_times, new_state_update_times_dict, global_var_dict, extra_global_var_values = problem_contexts[1]
    problem_contexts = problem_contexts[2:end]
    failed = false
    println("STARTING NEW PROBLEM CONTEXT")
    @show length(solutions)
    @show extra_global_var_values

    # curr_max_grouped_ranges = deepcopy(grouped_ranges)
    # curr_max_augmented_positive_times = deepcopy(augmented_positive_times)
    # curr_max_new_state_update_times_dict = deepcopy(new_state_update_times_dict)
    # curr_max_global_var_dict = deepcopy(global_var_dict)

    # while there are ranges that need to be explained, search for explaining events within them
    iters = 0
    while (length(grouped_ranges) > 0) && (iters < 500)
      iters += 1
      # if Set([grouped_ranges..., curr_max_grouped_ranges...]) != Set(curr_max_grouped_ranges)
      #   curr_max_grouped_ranges = deepcopy(grouped_ranges)
      #   curr_max_augmented_positive_times = deepcopy(augmented_positive_times)
      #   curr_max_new_state_update_times_dict = deepcopy(new_state_update_times_dict)
      #   curr_max_global_var_dict = deepcopy(global_var_dict)
      # end

      grouped_range = grouped_ranges[1]
      grouped_ranges = grouped_ranges[2:end] # remove first range from ranges 
  
      range = grouped_range[1]
      start_value = range[1][2]
      end_value = range[2][2]
  
      time_ranges = map(r -> (r[1][1], r[2][1] - 1), grouped_range)
  
      # construct state update function
      state_update_function = "(= globalVar$(global_var_id) $(end_value))"
  
      # get current maximum value of globalVar
      max_global_var_value = maximum(map(tuple -> tuple[2], augmented_positive_times))
  
      # search for events within range
      events_in_range = find_state_update_events(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, 1)
      if events_in_range != [] # event with zero false positives found
        println("PLS WORK 2")
        # # @show event_vector_dict
        # @show events_in_range 
        if filter(tuple -> !occursin("true", tuple[1]), events_in_range) != []
          if filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range) != []
            state_update_event, event_times = filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range)[1]
          else
            state_update_event, event_times = filter(tuple -> !occursin("true", tuple[1]), events_in_range)[1]
          end
        else 
          # FAILURE CASE 
          state_update_event, event_times = events_in_range[1]
        end
  
        # construct state update on-clause
        state_update_on_clause = "(on $(state_update_event)\n$(state_update_function))"
        
        # add to state_update_times 
        # # @show event_times
        # # @show state_update_on_clause  
        for time in event_times 
          new_state_update_times_dict[global_var_id][time] = state_update_on_clause
        end
  
      else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
        # find co-occurring event with fewest false positives 
        false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, 1)
        false_positive_events_with_state = filter(e -> occursin("globalVar$(global_var_id)", e[1]), false_positive_events) # want the most specific events in the false positive case
        
        events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
        if events_without_true != []
          false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
        else
          # FAILURE CASE: only separating event with false positives is true-based 
          # false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1]
          failed = true 
          break  
        end

        # if the selected false positive event falls into a different transition range, create a new problem context with
        # the order of those ranges switched
        matching_grouped_ranges = filter(grouped_range -> intersect(vcat(map(r -> collect(r[1][1]:(r[2][1] - 1)), grouped_range)...), false_positive_times) != [], grouped_ranges) 

        # @show length(matching_grouped_ranges)
        if length(matching_grouped_ranges) > 0 
          println("WOAHHH")
          if length(matching_grouped_ranges[1]) > 0 
            println("WOAHHH 2")
          end
        end
        
        if false # length(matching_grouped_ranges) == 1 && length(matching_grouped_ranges[1]) == 1
          matching_grouped_range = matching_grouped_ranges[1]
          matching_range = matching_grouped_range[1]
          matching_values = (matching_range[1][2], matching_range[2][2])
          current_values = (start_value, end_value)

          # @show matching_grouped_range
          # @show matching_range
          # @show matching_values
          # @show current_values

          # check that we haven't previously considered this reordering
          if !((current_values, matching_values) in split_orders) # && !((matching_values, current_values) in split_orders)
            push!(split_orders, (current_values, matching_values))

            # create new problem context
            new_context_grouped_ranges, new_context_augmented_positive_times, new_context_new_state_update_times_dict = recompute_ranges(deepcopy(augmented_positive_times), 
                                                                                                                                         deepcopy(new_state_update_times_dict),
                                                                                                                                         global_var_id, 
                                                                                                                                         global_var_value,
                                                                                                                                         deepcopy(global_var_dict),
                                                                                                                                         deepcopy(true_positive_times), 
                                                                                                                                         deepcopy(extra_global_var_values),
                                                                                                                                         true)
            # new_context_grouped_ranges = deepcopy(curr_max_grouped_ranges)
            # @show grouped_ranges
            # @show new_context_grouped_ranges
            matching_idx = findall(r -> r[1][1][2] == matching_values[1] && r[1][2][2] == matching_values[2], new_context_grouped_ranges)[1]
            curr_idx = findall(r -> r[1][1][2] == current_values[1] && r[1][2][2] == current_values[2], new_context_grouped_ranges)[1]
            
            new_context_grouped_ranges[curr_idx] = deepcopy(matching_grouped_range) 
            new_context_grouped_ranges[matching_idx] = deepcopy(grouped_range)

            # new_context_augmented_positive_times = deepcopy(curr_max_augmented_positive_times)
            # new_context_new_state_update_times_dict = deepcopy(curr_max_new_state_update_times_dict) 
            # new_context_curr_max_global_var_dict = deepcopy(curr_max_global_var_dict)

            # if the false positive intersection with a different range has size greater than 1, try allowing the first false
            # positive event in that other range to take place, instead of specializing its value
            intersecting_times = intersect(collect(matching_range[1][1]:(matching_range[2][1] - 1)), false_positive_times)
            if length(intersecting_times) > 1
              # update new_context_augmented_positive_times 
              first_intersecting_time = intersecting_times[1]
              push!(new_context_augmented_positive_times, (first_intersecting_time + 1, end_value))
              sort!(new_context_augmented_positive_times, by=x -> x[1])
              # recompute ranges + state_update_times_dict
              new_context_grouped_ranges, new_context_augmented_positive_times, new_context_new_state_update_times_dict = recompute_ranges(new_context_augmented_positive_times, 
                                                                                                                                           deepcopy(init_state_update_times_dict),
                                                                                                                                           global_var_id, 
                                                                                                                                           global_var_value,
                                                                                                                                           deepcopy(global_var_dict),
                                                                                                                                           true_positive_times, 
                                                                                                                                           extra_global_var_values,
                                                                                                                                           true)
            end

            push!(problem_contexts, (new_context_grouped_ranges, new_context_augmented_positive_times, deepcopy(init_state_update_times_dict), deepcopy(global_var_dict), deepcopy(extra_global_var_values)))
          end
        end
  
        # construct state update on-clause
        state_update_on_clause = "(on $(false_positive_event)\n$(state_update_function))"
        
        # add to state_update_times
        for time in true_positive_times 
          new_state_update_times_dict[global_var_id][time] = state_update_on_clause            
        end
        
        augmented_positive_times_labeled = map(tuple -> (tuple[1], tuple[2], "update_function"), augmented_positive_times) 
        for time in false_positive_times  
          push!(augmented_positive_times_labeled, (time, max_global_var_value + 1, "event"))
        end
        same_time_tuples = Dict()
        for tuple in augmented_positive_times_labeled
          time = tuple[1] 
          if time in collect(keys((same_time_tuples))) 
            push!(same_time_tuples[time], tuple)
          else
            same_time_tuples[time] = [tuple]
          end
        end
  
        for time in collect(keys((same_time_tuples))) 
          same_time_tuples[time] = reverse(sort(same_time_tuples[time], by=x -> length(x[3]))) # ensure all event tuples come *after* the update_function tuples
        end
        augmented_positive_times_labeled = vcat(map(t -> same_time_tuples[t], sort(collect(keys(same_time_tuples))))...)
        # augmented_positive_times_labeled = sort(augmented_positive_times_labeled, by=x->x[1])

        println("INTERVAL PAINTING DEBUGGING")
        @show augmented_positive_times_labeled
        @show false_positive_times 
        @show user_events 
        @show max_global_var_value
        @show global_var_value 
        @show times_dict 
        @show extra_global_var_values
  
        possible_interval_painting_stop_points_dict = Dict()
        for false_positive_time in false_positive_times 
          possible_interval_painting_stop_points_dict[false_positive_time] = []
          tuple_index = findall(tup -> tup[1] == false_positive_time && tup[3] == "event", augmented_positive_times_labeled)[1]
          same_time_values = filter(tup -> tup[1] == false_positive_time && tup[3] != "event", augmented_positive_times_labeled)
          if same_time_values != [] 
            same_time_value = same_time_values[1][2]
            
            for prev_index in (tuple_index-2):-1:1 
              prev_tuple = augmented_positive_times_labeled[prev_index]
              @show prev_tuple 
              @show same_time_value 
              if !(prev_tuple[2] in [same_time_value]) || prev_tuple[3] == "event"
                println("huh?")
                push!(possible_interval_painting_stop_points_dict[false_positive_time], prev_tuple[1])
                break
              else
                println("huh 2?")
                prev_time = prev_tuple[1]
                if !isnothing(user_events[prev_time]) && user_events[prev_time] != "nothing"
                  # possible stopping time! 
                  push!(possible_interval_painting_stop_points_dict[false_positive_time], prev_time)
                end
              end
            end
          end
        end

        curr_interval_painting_stop_points_dict = Dict(map(t -> t => [], false_positive_times))
        
        if count(x -> x > 1, map(v -> length(v), collect(values(possible_interval_painting_stop_points_dict)))) > 0 
          # multiplicity handling: add new problem context corresponding to alternative interval painting options 
          for false_positive_time in false_positive_times 
            stop_points = possible_interval_painting_stop_points_dict[false_positive_time]
            if stop_points != []
              if length(stop_points) >= 2 
                curr_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points)[1:2]               
              else 
                curr_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points)[1:1]
              end
              # if length(stop_points) >= 2 
              #   curr_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points)[2:2]               
              # else 
              #   curr_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points)[1:1]
              # end
              
              # curr_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points)[1:1]
              possible_interval_painting_stop_points_dict[false_positive_time] = reverse(stop_points) # [2:end] 
            end
          end
          
          # construct new problem_contexts 
          for false_positive_time in false_positive_times 
            if possible_interval_painting_stop_points_dict[false_positive_time] == [] 
              delete!(possible_interval_painting_stop_points_dict, false_positive_time)
            end
          end

          sorted_times = sort(collect(keys(possible_interval_painting_stop_points_dict)))
          orig_stop_times = map(t -> possible_interval_painting_stop_points_dict[t], sorted_times)

          # temporary debugging hack 
          # for i in 1:length(orig_stop_times) 
          #   l = orig_stop_times[i]
          #   if length(l) > 1 
          #     orig_stop_times[i] = vcat(l[2], l[1], l[3:end])
          #   end
          # end

          stop_times = vec(collect(Base.product(orig_stop_times...)))[2:end] # first stop time tuple is used in current thread 
          for stop_time in stop_times 
            new_context_stop_points_dict = Dict()
            for time_index in 1:length(sorted_times)
              time = sorted_times[time_index] 
              new_context_stop_points_dict[time] = [stop_time[time_index]]
            end

            new_context_augmented_positive_times, new_context_extra_global_var_values = relabel_via_interval_painting(deepcopy(augmented_positive_times_labeled), global_var_value, max_global_var_value, deepcopy(extra_global_var_values), times_dict, new_context_stop_points_dict, false_positive_times, update_function_indices)
            
            new_context_grouped_ranges, new_context_augmented_positive_times, new_context_new_state_update_times_dict = recompute_ranges(new_context_augmented_positive_times, 
                                                                                                                                         deepcopy(init_state_update_times_dict),
                                                                                                                                         global_var_id, 
                                                                                                                                         global_var_value,
                                                                                                                                         deepcopy(global_var_dict),
                                                                                                                                         true_positive_times, 
                                                                                                                                         new_context_extra_global_var_values,
                                                                                                                                         true)
            println("WHATS GOING ON")
            if !(new_context_augmented_positive_times in old_augmented_positive_times)
              push!(old_augmented_positive_times, deepcopy(new_context_augmented_positive_times))
              @show new_context_extra_global_var_values
              push!(problem_contexts, (new_context_grouped_ranges, new_context_augmented_positive_times, deepcopy(init_state_update_times_dict), deepcopy(global_var_dict), deepcopy(new_context_extra_global_var_values)))  
            end
          end
        end

        augmented_positive_times, extra_global_var_values = relabel_via_interval_painting(augmented_positive_times_labeled, global_var_value, max_global_var_value, extra_global_var_values, times_dict, curr_interval_painting_stop_points_dict, false_positive_times, update_function_indices)
  
        # compute new ranges and find state update events
        grouped_ranges, augmented_positive_times, new_state_update_times_dict = recompute_ranges(augmented_positive_times, new_state_update_times_dict, global_var_id, global_var_value, global_var_dict, true_positive_times, extra_global_var_values, true)
      end      
    end
    sort!(problem_contexts, by=pc -> length(unique(map(x -> x[2], pc[2]))))

    if failed || (iters == 500)
      solution = ("", global_var_dict, new_state_update_times_dict)
      push!(solutions, solution)
    else
      # update global_var_dict
      _, init_value = augmented_positive_times[1]                                   
      for time in 1:length(global_var_dict[global_var_id]) 
        if global_var_dict[global_var_id][time] >= 1 # global_var_value 
          global_var_dict[global_var_id][time] = init_value
        end
      end
  
      curr_value = -1
      for time in 1:length(global_var_dict[global_var_id])
        if curr_value != -1 
          global_var_dict[global_var_id][time] = curr_value
        end
        if new_state_update_times_dict[global_var_id][time] != ""
          curr_value = parse(Int, split(split(new_state_update_times_dict[global_var_id][time], "\n")[2], "(= globalVar$(global_var_id) ")[2][1])
        end
      end
      
      on_clauses = []
      for update_function in update_functions 
        update_function_index = update_function_indices[update_function]
        if extra_global_var_values[update_function_index] == [] 
          on_clause = "(on $(occursin("globalVar$(global_var_id)", co_occurring_event) ? co_occurring_event : "(& (== (prev globalVar$(global_var_id)) $(update_function_index)) $(co_occurring_event))")\n$(update_function))"
        else 
          on_clause = "(on (& (in (prev globalVar$(global_var_id)) (list $(join([update_function_index, extra_global_var_values[update_function_index]...], " ")))) $(occursin("globalVar$(global_var_id)", co_occurring_event) ? replace(replace(co_occurring_event, "(== globalVar$(global_var_id) $(update_function_index))" => ""), "(&" => "")[1:end-1] : co_occurring_event))\n$(update_function))"
        end
        push!(on_clauses, on_clause)
      end

      println("LOOK AT ME")
      @show on_clauses
      solution = (on_clauses, global_var_dict, new_state_update_times_dict)
      push!(solutions, solution)
    end
  end
  @show solutions
  sort(solutions, by=sol -> length(unique(sol[2][1])))
end

function relabel_via_interval_painting(augmented_positive_times_labeled, global_var_value, max_global_var_value, extra_global_var_values, times_dict, curr_interval_painting_stop_points_dict, false_positive_times, update_function_indices)
  println("RELABEL_VIA_INTERVAL_PAINTING")
  # relabel false positive times 
  # based on relabeling, relabel other existing labels if necessary 
  later_adds = []
  for tuple_index in 1:length(augmented_positive_times_labeled)
    tuple = augmented_positive_times_labeled[tuple_index]
    if tuple[3] == "event"
      if curr_interval_painting_stop_points_dict[tuple[1]] != [] 
        stop_time = curr_interval_painting_stop_points_dict[tuple[1]][1]
        for prev_index in (tuple_index-1):-1:1 
          prev_tuple = augmented_positive_times_labeled[prev_index]
          prev_time, prev_val, prev_label = prev_tuple
          if prev_time > stop_time 
            augmented_positive_times_labeled[prev_index] = (prev_time, max_global_var_value + 1, prev_label)
            @show update_function_indices
            @show prev_time 
            @show times_dict
            @show augmented_positive_times_labeled
            update_functions = filter(k -> prev_time in vcat(collect(values(times_dict[k]))...), collect(keys(times_dict)))
            if update_functions != [] # if empty, this is a new state value for the no-update-function state
              update_function = update_functions[1]
              update_function_index = update_function_indices[update_function]

              push!(extra_global_var_values[update_function_index], max_global_var_value + 1)
              unique!(extra_global_var_values[update_function_index])
            end

          elseif prev_time == stop_time
            next_time_list = filter(tup -> tup[1] == stop_time + 1, augmented_positive_times_labeled)
            if next_time_list == [] 
              push!(later_adds, (stop_time + 1, max_global_var_value + 1))

              update_functions = filter(k -> prev_time in vcat(collect(values(times_dict[k]))...), collect(keys(times_dict)))
              if update_functions != [] # if empty, this is a new state value for the no-update-function state
                update_function = update_functions[1]
                update_function_index = update_function_indices[update_function]

                push!(extra_global_var_values[update_function_index], max_global_var_value + 1)
                unique!(extra_global_var_values[update_function_index])
              end
  
            end
            break
          else
            break
          end
        end
      else # standard interval painting
        for prev_index in (tuple_index-1):-1:1
          prev_tuple = augmented_positive_times_labeled[prev_index]
          
          # stop condition
          if prev_tuple[2] <= global_var_value || prev_tuple[2] in vcat(collect(values(extra_global_var_values))...)
            println("HERE 2")
            @show prev_tuple 
            @show tuple
            if prev_tuple[1] == tuple[1] && !(prev_tuple[2] in vcat(collect(values(extra_global_var_values))...)) # if the false positive time is the same as the global_var_value time, change the value
              println("HERE")
  
              augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
              # find update function index that contains this time 
              update_function = filter(k -> prev_tuple[1] in vcat(collect(values(times_dict[k]))...), collect(keys(times_dict)))[1]
              update_function_index = update_function_indices[update_function]
  
              push!(extra_global_var_values[update_function_index], max_global_var_value + 1)
              break
            else # if the two times are different, stop the relabeling process w.r.t. to this false positive tuple 
              break
            end
          end
          
          if (prev_tuple[2] > global_var_value) && !(prev_tuple[2] in vcat(collect(values(extra_global_var_values))...)) && (prev_tuple[3] == "update_function")
            augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
          end
        end

      end
    end
  end
  augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))   
  push!(augmented_positive_times, later_adds...)
  sort!(augmented_positive_times, by=tup->tup[1])
  (augmented_positive_times, extra_global_var_values)
end

function generate_stateless_on_clauses(update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set)
  object_types, object_mapping, background, grid_size = global_object_decomposition
  new_on_clauses = []
  observation_vectors_dict = Dict() 
  addObj_params_dict = Dict()
  state_based_update_functions_dict = Dict()
  ordered_update_functions_dict = Dict()
  
  type_ids = sort(collect(keys(update_functions_dict)))
  for type_id in type_ids
    object_type = filter(t -> t.id == type_id, object_types)[1]
    object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping))))

    all_update_rules = filter(rule -> rule != "", unique(vcat(vec(anonymized_filtered_matrix[object_ids, :])...)))

    update_rule_set = vcat(filter(r -> r != "", vcat(map(id -> map(x -> replace(x[1], "obj id) $(id)" => "obj id) x"), filtered_matrix[id, :]), object_ids)...))...)

    addObj_rules = filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...))
    unique_addObj_rules = unique(filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...)))
    addObj_times_dict = Dict()

    for rule in unique_addObj_rules 
      addObj_times_dict[rule] = sort(unique(vcat(map(id -> findall(r -> r == rule, vcat(filtered_matrix[id, :]...)), object_ids)...)))
    end
    
    group_addObj_rules = false
    addObj_count = 0
    if length(unique(collect(values(addObj_times_dict)))) == 1
      group_addObj_rules = true
      all_update_rules = filter(r -> !(r in addObj_rules), all_update_rules)
      push!(all_update_rules, addObj_rules[1]) 
      addObj_count = count(r -> occursin("addObj", r), vcat(filtered_matrix[:, collect(values(addObj_times_dict))[1][1]]...))
    end

    # construct addObj_params_dict
    addObj_params_dict[type_id] = (group_addObj_rules, addObj_rules, addObj_count)
    
    no_change_rules = filter(x -> is_no_change_rule(x), unique(all_update_rules))
    all_update_rules = reverse(sort(filter(x -> !is_no_change_rule(x), unique(all_update_rules)), by=x -> count(y -> y == x, update_rule_set)))

    ordered_update_functions_dict[type_id] = all_update_rules

    all_update_rules = [no_change_rules..., all_update_rules...]

    update_functions = update_functions_dict[type_id]
    for update_rule in update_functions
      # @show update_rule_index 
      # @show length(all_update_rules)
      # update_rule = all_update_rules[update_rule_index]
      # # @show global_object_decomposition
      if update_rule != "" && !is_no_change_rule(update_rule)
        println("UPDATE_RULEEE")
        println(update_rule)
        events, event_is_globals, event_vector_dict, observation_data_dict = generate_event(update_rule, all_update_rules, object_ids[1], object_ids, matrix, filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, grid_size, redundant_events_set)
        global_event_vector_dict = event_vector_dict
        observation_vectors_dict[update_rule] = observation_data_dict

        println("EVENTS")
        println(events)
        # # @show event_vector_dict
        # # @show observation_data_dict
        if events != []
          event = events[1]
          event_is_global = event_is_globals[1]
          on_clause = format_on_clause(replace(update_rule, ".. obj id) x" => ".. obj id) $(object_ids[1])"), replace(event, ".. obj id) x" => ".. obj id) $(object_ids[1])"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, event_is_global, grid_size, addObj_count)
          push!(new_on_clauses, on_clause)
          new_on_clauses = unique(new_on_clauses)
          println("ADDING EVENT WITHOUT NEW STATE")
          @show event 
          @show update_rule
          @show on_clause
          @show length(new_on_clauses)
          @show new_on_clauses
        else # collect update functions for later state generation
          if type_id in keys(state_based_update_functions_dict)
            push!(state_based_update_functions_dict[type_id], update_rule)
          else
            state_based_update_functions_dict[type_id] = [update_rule] 
          end
        end 

      end

    end
  end

  new_on_clauses, state_based_update_functions_dict, observation_vectors_dict, addObj_params_dict, global_event_vector_dict, ordered_update_functions_dict 
end

function generate_new_object_specific_state_GLOBAL(co_occurring_event, update_functions, times_dict, event_vector_dict, type_id, object_decomposition, init_state_update_times, global_var_dict)
  println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  @show co_occurring_event
  @show update_functions 
  @show times_dict
  @show event_vector_dict
  @show type_id 
  @show object_decomposition
  @show init_state_update_times
  state_update_times = deepcopy(init_state_update_times)  
  failed = false
  object_types, object_mapping, background, grid_size = object_decomposition 
  object_ids = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))

  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id, ["nothing"], global_var_dict, update_functions[1])

  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if !(e in atomic_events) # && foldl(|, map(x -> occursin(x, e), atomic_events))
      delete!(small_event_vector_dict, e)
    else
      object_specific_event_with_wrong_type = !(event_vector_dict[e] isa AbstractArray) && (Set(collect(keys(event_vector_dict[e]))) != Set(object_ids))
      if object_specific_event_with_wrong_type 
        delete!(small_event_vector_dict, e)
      end
    end
  end
  # for e in keys(event_vector_dict)
  #   if occursin("|", e) && e in keys(small_event_vector_dict)
  #     delete!(small_event_vector_dict, e)
  #   end
  # end
  # # choices, event_vector_dict, redundant_events_set, object_decomposition
  # small_events = construct_compound_events(collect(keys(small_event_vector_dict)), small_event_vector_dict, Set(), object_decomposition)
  # for e in keys(event_vector_dict)
  #   if (occursin("true", e) || occursin("|", e)) && e in keys(small_event_vector_dict)
  #     delete!(small_event_vector_dict, e)
  #   end
  # end

  x =  "(& clicked (& true (! (in (objClicked click (prev addedObjType1List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType1List))))))"
  small_event_vector_dict[x] = event_vector_dict[x]

  @show length(collect(keys(event_vector_dict)))
  @show length(collect(keys(small_event_vector_dict)))
  @show small_event_vector_dict

  # initialize state_update_times
  curr_state_value = -1
  @show state_update_times 
  @show object_ids
  if length(collect(keys(state_update_times))) == 0 || length(intersect(object_ids, collect(keys(state_update_times)))) == 0
    for id in object_ids
      state_update_times[id] = [("", -1) for i in 1:(length(object_mapping[object_ids[1]])-1)]
    end
    curr_state_value = 1
  else
    println("WEIRD")
    return ("", [], object_decomposition, state_update_times)  
  end

  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  update_function_indices = Dict(map(u -> u => findall(x -> x == u, update_functions)[1], update_functions))
  max_state_value = length(update_functions)

  # construct augmented true positive times 
  augmented_positive_times_dict = Dict()
  for object_id in object_ids
    augmented_true_positive_times_dict = Dict(map(u -> u => map(t -> (t, update_function_indices[u]), times_dict[u][object_id]), update_functions))
    augmented_true_positive_times = vcat(collect(values(augmented_true_positive_times_dict))...)
    true_positive_times = map(tuple -> tuple[1], augmented_true_positive_times)  
  
    false_positive_times = [] # times when user_event happened and update_rule didn't happen
    # construct false_positive_times 
    for time in 1:(length(object_mapping[object_ids[1]])-1)
      if co_occurring_event_trajectory isa AbstractArray
        if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          push!(false_positive_times, time)
        end
      else 
        if co_occurring_event_trajectory[object_id][time] == 1 && !(time in true_positive_times) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          push!(false_positive_times, time)
        end
      end
    end

    augmented_false_positive_times = map(t -> (t, max_state_value + 1), false_positive_times)
    augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])  

    augmented_positive_times_dict[object_id] = augmented_positive_times 
  end

  # compute ranges 
  grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, 1, object_mapping, object_ids)

  while length(grouped_ranges) > 0
    grouped_range = grouped_ranges[1]
    grouped_ranges = grouped_ranges[2:end]

    range = grouped_range[1]
    start_value = range[1][2]
    end_value = range[2][2]

    max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...))

    # TODO: try global events too  
    events_in_range = []
    if events_in_range == [] # if no global events are found, try object-specific events 
      # events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_value)
      events_in_range = find_state_update_events_object_specific(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value)
    end
    @show events_in_range
    if length(events_in_range) > 0 # only handling perfect matches currently 
      event, event_times = events_in_range[1]
      formatted_event = replace(event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
      # construct state_update_function
      if occursin("clicked", formatted_event)
        state_update_function = """(on clicked\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      else
        state_update_function = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      end
      println(state_update_function)
      for id in object_ids # collect(keys(state_update_times))
        object_event_times = map(t -> t[1], filter(time -> time[2] == id, event_times))
        for time in object_event_times
          println(id)
          println(time)
          println(end_value)
          state_update_times[id][time] = (state_update_function, end_value)
        end
      end
    else
      false_positive_events = find_state_update_events_object_specific_false_positives(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value)      
      false_positive_events_with_state = filter(e -> occursin("field1", e[1]), false_positive_events) # want the most specific events in the false positive case
      @show false_positive_events
      events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
      if events_without_true != []
          false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
      else
        # FAILURE CASE: only separating event with false positives is true-based 
        # false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1]
        failed = true 
        break  
      end

      # construct state update on-clause
      formatted_event = replace(false_positive_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
      if occursin("clicked", formatted_event)
        state_update_on_clause = """(on clicked\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      else
        state_update_on_clause = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      end

      # add to state_update_times
      for tuple in true_positive_times 
        time, id = tuple
        state_update_times[id][time] = (state_update_function, end_value)
      end
      
      augmented_positive_times_dict_labeled = Dict(id -> (map(tuple -> (tuple[1], tuple[2], "update_function"), augmented_positive_times_dict[id]), collect(keys(object_ids)))) 
      for tuple in false_positive_times
        time, id = tuple  
        push!(augmented_positive_times_dict_labeled[id], (time, max_state_value + 1, "event"))
      end
      same_time_tuples = Dict()
      for id in collect(keys(augmented_positive_times_dict_labeled))
        same_time_tuples[id] = Dict()
        for tuple in augmented_positive_times_dict_labeled[id]
          time = tuple[1] 
          if time in collect(keys((same_time_tuples[id]))) 
            push!(same_time_tuples[id][time], tuple)
          else
            same_time_tuples[id][time] = [tuple]
          end
        end
      end

      for id in collect(keys(same_time_tuples_dict))
        for time in collect(keys((same_time_tuples[id]))) 
          same_time_tuples[id][time] = reverse(sort(same_time_tuples[id][time], by=x -> length(x[3]))) # ensure all event tuples come *after* the update_function tuples
        end
        augmented_positive_times_dict_labeled[id] = vcat(map(t -> same_time_tuples[id][t], sort(collect(keys(same_time_tuples[id]))))...)
      end
      # augmented_positive_times_labeled = sort(augmented_positive_times_labeled, by=x->x[1])

      # relabel false positive times 
      # based on relabeling, relabel other existing labels if necessary 
      augmented_positive_times_dict = Dict()
      for id in collect(keys(augmented_positive_times_dict_labeled))
        augmented_positive_times_labeled = augmented_positive_times_dict_labeled[id]
        for tuple_index in 1:length(augmented_positive_times_labeled)
          tuple = augmented_positive_times_labeled[tuple_index]
          if tuple[3] == "event"
            for prev_index in (tuple_index-1):-1:1
              prev_tuple = augmented_positive_times_labeled[prev_index]
  
              # if we have reached a prev_tuple with global_var_value or extra value, then we stop the relabeling based on this event tuple
              if prev_tuple[2] == curr_state_value # || prev_tuple[2] in extra_global_var_values
                break
                # println("HERE 2")
                # @show prev_tuple 
                # @show tuple
                # if prev_tuple[1] == tuple[1] && !(prev_tuple[2] in extra_global_var_values) # if the false positive time is the same as the global_var_value time, change the value
                #   println("HERE")
  
                #   augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_state_value + 1, prev_tuple[3])
                #   push!(extra_global_var_values, max_state_value + 1)
                #   break
                # else # if the two times are different, stop the relabeling process w.r.t. to this false positive tuple 
                #   break
                # end
              end
              
              # relabel update function prev_tuple with label greater than global_var_value and not an extra value 
              if (prev_tuple[2] > curr_state_value) && (prev_tuple[3] == "update_function") # && !(prev_tuple[2] in extra_global_var_values)
                augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_state_value + 1, prev_tuple[3])
              end
            end
          end
        end
        augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))      
        augmented_positive_times_dict[id] = augmented_positive_times
      end

      # compute new ranges 
      grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, curr_state_value, object_mapping, object_ids)
      state_update_times = init_state_update_times
    end
  end

  if failed 
    [], [], object_decomposition, state_update_times  
  else
    # construct field values for each object 
      object_field_values = Dict()
      for object_id in object_ids
        if length(augmented_positive_times_dict[object_id]) != 0 
          init_value = augmented_positive_times_dict[object_id][1][2]
        else
          @show state_update_times
          no_state_updates = length(unique(collect(Base.values(state_update_times)))) == 1
          @show no_state_updates 
          @show state_update_times
          @show augmented_positive_times_dict 
          @show type_id 
          if no_state_updates 
            values = vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...)
            mode = reverse(sort(unique(values), by=x -> count(y -> y == x, values)))[1]
            init_value = mode
            @show mode
          else 
            init_value = curr_state_value + 1
          end
        end
        # init_value = length(augmented_positive_times_dict[object_id]) == 0 ? (max_state_value + 1) : augmented_positive_times_dict[object_id][1][2]
        object_field_values[object_id] = [init_value for i in 1:(length(state_update_times[object_id]) + 1)]
        
        curr_value = -1
        for time in 1:length(state_update_times[object_id])
          if curr_value != -1
            object_field_values[object_id][time] = curr_value
          end
          
          if state_update_times[object_id][time] != ("", -1)
            curr_value = state_update_times[object_id][time][2]
          end
        end
        object_field_values[object_id][length(object_field_values[object_id])] = curr_value != -1 ? curr_value : init_value
      end

    # construct new object decomposition
    ## add field to correct ObjType in object_types
    new_object_types = deepcopy(object_types)
    new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
    if !("field1" in map(field_tuple -> field_tuple[1], new_object_type.custom_fields))
      push!(new_object_type.custom_fields, ("field1", "Int", collect(1:max_state_value)))
    else
      custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
      new_object_type.custom_fields[custom_field_index][3] = sort(unique(vcat(new_object_type.custom_fields[custom_field_index][3], collect(1:max_state_value))))
    end
    
    ## modify objects in object_mapping
    new_object_mapping = deepcopy(object_mapping)
    for id in collect(keys(new_object_mapping))
      if id in object_ids
        for time in 1:length(new_object_mapping[id])
          if !isnothing(object_mapping[id][time])
            values = new_object_mapping[id][time].custom_field_values
            if !((values != []) && (values[end] isa Int) && (values[end] < curr_state_value))
              new_object_mapping[id][time].type = new_object_type
              if (values != []) && (values[end] isa Int)
                new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values[1:end-1], object_field_values[id][time])
              else
                new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values, object_field_values[id][time])
              end
            end
          end
        end
      end
    end
    new_object_decomposition = new_object_types, new_object_mapping, background, grid_size

    @show new_object_decomposition

    on_clauses = []
    formatted_co_occurring_event = replace(co_occurring_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
    for update_function in update_functions 
      update_function_index = update_function_indices[update_function]
      if !occursin("field1", formatted_co_occurring_event)
        on_clause = "(on true\n$(replace(update_function, "(== (.. obj id) x)" => "(& $(formatted_co_occurring_event) (== (.. obj field1) $(update_function_index)))")))"
      else
        on_clause = "(on true\n$(replace(update_function, "(== (.. obj id) x)" => formatted_co_occurring_event)))"
      end
      push!(on_clauses, on_clause)
    end    
    state_update_on_clauses = map(x -> x[1], unique(filter(r -> r != ("", -1), vcat([state_update_times[k] for k in collect(keys(state_update_times))]...))))
    on_clauses, state_update_on_clauses, new_object_decomposition, state_update_times  
  end  
end