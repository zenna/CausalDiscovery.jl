if Sys.islinux() 
  sketch_directory = "/scratch/riadas/sketch-1.7.6/sketch-frontend/"
else
  sketch_directory = "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/"
end

function generate_on_clauses_SKETCH_MULTI(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, z3_option="none", time_based=false, z3_timeout=0, sketch_timeout=0, co_occurring_param=false, transition_param=false, co_occurring_distinct=1, co_occurring_same=1, co_occurring_threshold=1, transition_distinct=1, transition_same=1, transition_threshold=1)
  start_time = Dates.now()
  
  object_types, object_mapping, background, dim = object_decomposition
  solutions = []

  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  # filtered_matrix = filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition)[1]
  
  filtered_matrices = []

  pre_filtered_matrix_1 = pre_filter_remove_NoCollision(matrix)
  if pre_filtered_matrix_1 != false 
    pre_filtered_non_random_matrix_1 = deepcopy(pre_filtered_matrix_1)
    for row in 1:size(pre_filtered_non_random_matrix_1)[1]
      for col in 1:size(pre_filtered_non_random_matrix_1)[2]
        pre_filtered_non_random_matrix_1[row, col] = filter(x -> !occursin("randomPositions", x), pre_filtered_non_random_matrix_1[row, col])
      end
    end
    filtered_non_random_matrices = filter_update_function_matrix_multiple(pre_filtered_non_random_matrix_1, object_decomposition, multiple=true)
    push!(filtered_matrices, filtered_non_random_matrices...)
  end

  # pre filter by removing non-NoCollision update functions 
  pre_filtered_matrix_1 = pre_filter_remove_non_NoCollision(matrix)
  if pre_filtered_matrix_1 != false 
    pre_filtered_non_random_matrix_1 = deepcopy(pre_filtered_matrix_1)
    for row in 1:size(pre_filtered_non_random_matrix_1)[1]
      for col in 1:size(pre_filtered_non_random_matrix_1)[2]
        pre_filtered_non_random_matrix_1[row, col] = filter(x -> !occursin("randomPositions", x), pre_filtered_non_random_matrix_1[row, col])
      end
    end
    filtered_non_random_matrices = filter_update_function_matrix_multiple(pre_filtered_non_random_matrix_1, object_decomposition, multiple=true)
    push!(filtered_matrices, filtered_non_random_matrices...)
  end


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
  # filtered_unformatted_matrix = filter_update_function_matrix_multiple(unformatted_matrix, object_decomposition, multiple=false)[1]
  # push!(filtered_matrices, filter_update_function_matrix_multiple(construct_chaos_matrix(filtered_unformatted_matrix, object_decomposition), object_decomposition, multiple=false)...)

  unique!(filtered_matrices)
  # filtered_matrices = filtered_matrices[22:22]
  # filtered_matrices = filtered_matrices[5:5]
  # filtered_matrices = filtered_matrices[2:2]
  # filtered_matrices = filtered_matrices[1:1] # gravity

  # @show length(filtered_matrices)

  if length(filtered_matrices) > 25 
    filtered_matrices = filtered_matrices[1:25]
  end 

  # @show length(filtered_matrices)

  for filtered_matrix_index in 1:length(filtered_matrices)
    # @show filtered_matrix_index
    # # @show length(filtered_matrices)
    # # @show solutions
    filtered_matrix = filtered_matrices[filtered_matrix_index]
    
    # reset global_event_vector_dict and redundant_events_set for each new context:
    # remove events dealing with global or object-specific state
    for event in keys(global_event_vector_dict)
      if occursin("globalVar", event) || occursin("field1", event)
        delete!(global_event_vector_dict, event)
      end
    end

    for event in redundant_events_set 
      if occursin("globalVar", event) || occursin("field1", event)
        delete!(redundant_events_set, event)
      end
    end


    if (length(filter(x -> x[1] != [], solutions)) >= desired_solution_count) || Dates.value(Dates.now() - start_time) > 3600 * 2 * 1000 # || ((length(filter(x -> x[1] != [], solutions)) > 0) && length(filter(x -> occursin("randomPositions", x), vcat(vcat(filtered_matrix...)...))) > 0) 
      # if we have reached a sufficient solution count or have found a solution before trying random solutions, exit
      # println("BREAKING")
      # println("elapsed time: $(Dates.value(Dates.now() - start_time) > 3600 * 2 * 1000)")
      # # @show length(solutions)
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
    new_on_clauses, state_based_update_functions_dict, observation_vectors_dict, addObj_params_dict, global_event_vector_dict, ordered_update_functions_dict = generate_stateless_on_clauses(update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set, z3_option, time_based, z3_timeout, sketch_timeout)
    
    # println("I AM HERE NOW")
    # @show new_on_clauses
    # @show state_based_update_functions_dict
    # @show ordered_update_functions_dict
    push!(on_clauses, new_on_clauses...)
    # @show observation_vectors_dict
    # # @show redundant_events_set
    # # @show global_event_vector_dict
 
    # check if all update functions were solved; if not, proceed with state generation procedure
    if length(collect(keys(state_based_update_functions_dict))) == 0 

      # re-order on_clauses
      ordered_on_clauses = re_order_on_clauses(on_clauses, ordered_update_functions_dict)

      push!(solutions, ([deepcopy(ordered_on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
    else # GENERATE NEW STATE 
      type_ids = collect(keys(state_based_update_functions_dict))

      # pull out "addObj" update rules into their own key/value pair within state_based_update_functions_dict
      addObj_tuples = vcat(map(t -> map(u -> (t, u), filter(r -> occursin("addObj", r), state_based_update_functions_dict[t])), collect(keys(state_based_update_functions_dict)))...)
      addObj_types = unique(map(tup -> tup[1], addObj_tuples))
      addObj_update_functions = map(tup -> tup[2], addObj_tuples)
      state_based_update_functions_dict[Tuple(sort(addObj_types))] = addObj_update_functions
      # remove addObj update functions from original locations 
      for t in collect(keys(state_based_update_functions_dict))
        if !(t isa Tuple)
          state_based_update_functions_dict[t] = filter(x -> !occursin("addObj", x), state_based_update_functions_dict[t])
        end
      end

      # compute co-occurring event for each state-based update function 
      # co_occurring_events_dict = Dict() # keys are tuples (type_id, co-occurring event), values are lists of update_functions with that co-occurring event
      optimal_event_lists_dict = Dict()
      events = collect(keys(global_event_vector_dict)) # ["left", "right", "up", "down", "clicked", "true"]
      # @show events 
      # @show global_event_vector_dict
      for type_id in collect(keys(state_based_update_functions_dict))
        update_functions = state_based_update_functions_dict[type_id]
        for update_function in update_functions 
          if type_id isa Tuple 
            object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id in collect(type_id), collect(keys(object_mapping)))
          else 
            object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
          end
  
          state_is_global = true 
          if occursin("addObj", update_function) || length(object_ids_with_type) == 1
            state_is_global = true
          else
            for time in 1:length(user_events)
              observation_values = map(id -> observation_vectors_dict[update_function][id][time], object_ids_with_type)
              if (0 in observation_values) && (1 in observation_values)
                # @show update_function 
                # @show time 
                state_is_global = false
                break
              end
            end
          end
  
          # compute co-occurring event 
          update_function_times_dict = Dict(map(obj_id -> obj_id => findall(r -> r == [update_function], anonymized_filtered_matrix[obj_id, :]), object_ids_with_type))
          co_occurring_events = []
          for event in events
            # @show event 
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
          # println("BEFORE")
          # @show co_occurring_events
          if co_occurring_param 
            co_occurring_events = sort(filter(x -> !occursin("(list)", x[1]) && !occursin("(move ", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("objClicked", x[1]) && !occursin("intersects (list", x[1]) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))") && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
          else
            co_occurring_events = sort(filter(x -> !occursin("(list)", x[1]) && !occursin("|", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("objClicked", x[1]) && !occursin("(move ", x[1]) && !occursin("intersects (list", x[1]) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))")  && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
          end
  
          if state_is_global 
            co_occurring_events = filter(x -> !occursin("obj id) x)", x[1]) || occursin("(clicked (filter (--> obj (== (.. obj id)", x[1]), co_occurring_events)
          end 
  
          # println("THIS IS WEIRD HUH")
          # @show type_id 
          # @show update_function
          # @show co_occurring_events
          if filter(x -> !occursin("globalVar", x[1]), co_occurring_events) != []
            co_occurring_events = filter(x -> !occursin("globalVar", x[1]), co_occurring_events)
          end

          false_positive_counts = sort(unique(map(x -> x[2], co_occurring_events)))
          false_positive_counts = false_positive_counts[1:min(length(false_positive_counts), co_occurring_distinct)]
          optimal_events = []
          for false_positive_count in false_positive_counts 
            events_with_count = map(e -> e[1], sort(filter(tup -> tup[2] == false_positive_count, co_occurring_events), by=t -> length(t[1])))
            push!(optimal_events, events_with_count[1:min(length(events_with_count), co_occurring_same)]...)
          end

          if type_id in keys(optimal_event_lists_dict) 
            push!(optimal_event_lists_dict[type_id], (update_function, optimal_events))
          else 
            optimal_event_lists_dict[type_id] = [(update_function, optimal_events)]
          end

          # best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
          # # # # @show best_co_occurring_events
          # co_occurring_event = best_co_occurring_events[1][1]        
  
          # if (type_id, co_occurring_event) in keys(co_occurring_events_dict)
          #   push!(co_occurring_events_dict[(type_id, co_occurring_event)], update_function)
          # else
          #   co_occurring_events_dict[(type_id, co_occurring_event)] = [update_function]
          # end
  
        end
      end

      # @show optimal_event_lists_dict

      # convert optimal_event_lists_dict to co_occurring_event_lists_dict 
      co_occurring_events_dict_list = []
      total_update_functions = [] 
      total_optimal_events_lists = []

      # construct parallel lists of distinct update functions and their co-occurring event lists 
      for type_id in keys(optimal_event_lists_dict)
        tuples = optimal_event_lists_dict[type_id]
        update_functions = map(x -> (x[1], type_id), sort(tuples))
        optimal_events_lists = map(x -> x[2], sort(tuples))

        push!(total_update_functions, update_functions...)
        push!(total_optimal_events_lists, optimal_events_lists...)

      end

      event_combinations = vec(collect(Base.product(total_optimal_events_lists...)))      
      for event_comb in event_combinations
        # construct co_occurring_event_dict corresponding to each event_comb 
        co_occurring_events_dict = Dict() 
        for update_function_tup_index in 1:length(total_update_functions)
          update_function_tup = total_update_functions[update_function_tup_index] 
          update_function, type_id = update_function_tup 
          co_occurring_event = event_comb[update_function_tup_index]

          if (type_id, co_occurring_event) in keys(co_occurring_events_dict)
            push!(co_occurring_events_dict[(type_id, co_occurring_event)], update_function)
          else
            co_occurring_events_dict[(type_id, co_occurring_event)] = [update_function]
          end
        end

        push!(co_occurring_events_dict_list, co_occurring_events_dict)
      end

      co_occurring_events_dict_list = co_occurring_events_dict_list[1:min(co_occurring_threshold, length(co_occurring_events_dict_list))]

      # @show length(co_occurring_events_dict_list)
      for co_occurring_index in 1:length(co_occurring_events_dict_list)
        co_occurring_events_dict = co_occurring_events_dict_list[co_occurring_index]

        # initialize problem contexts 
        problem_contexts = []
        solutions_per_matrix_count = 0 

        problem_context = (deepcopy(co_occurring_events_dict), 
                          deepcopy(on_clauses),
                          deepcopy(global_var_dict),
                          deepcopy(global_object_decomposition), 
                          deepcopy(global_state_update_times_dict),
                          deepcopy(object_specific_state_update_times_dict),
                          deepcopy(global_state_update_on_clauses),
                          deepcopy(object_specific_state_update_on_clauses),
                          deepcopy(state_update_on_clauses))

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

          failed = false

          problem_contexts = problem_contexts[2:end]

          global_update_functions_dict = Dict()
          object_specific_update_functions_dict = Dict()

          global_state_solutions_dict = Dict()
          object_specific_state_solutions_dict = Dict()  
          
          # sort (type_id, co_occurring_event) pairs into global-state-requiring and object-specific-state-requiring
          for tuple in collect(keys(co_occurring_events_dict))
            type_id, co_occurring_event = tuple
            
            update_functions = co_occurring_events_dict[(type_id, co_occurring_event)]
            if type_id isa Tuple 
              object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id in collect(type_id), collect(keys(object_mapping)))            
            else
              object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
            end

            # determine if state is global or object-specific 
            state_is_global = true 
            if length(object_ids_with_type) == 1 || foldl(&, map(u -> occursin("addObj", u), update_functions), init=true)
              state_is_global = true
            else
              for update_function in update_functions 
                for time in 1:length(user_events)
                  observation_values = map(id -> observation_vectors_dict[update_function][id][time], object_ids_with_type)
                  if (0 in observation_values) && (1 in observation_values)
                    # @show update_function 
                    # @show time 
                    state_is_global = false
                    break
                  end
                end
                if !state_is_global
                  break
                end
              end
            end

            if foldl(&, map(u -> occursin("addObj", u), update_functions), init=true) && !state_is_global 
              failed = true
              break
            end

            if state_is_global 
              global_update_functions_dict[(type_id, co_occurring_event)] = update_functions
            else
              object_specific_update_functions_dict[(type_id, co_occurring_event)] = update_functions
            end
          end

          # @show global_update_functions_dict 
          # @show object_specific_update_functions_dict 

          if length(collect(keys(global_update_functions_dict))) > 0 
            for tuple in collect(keys(global_update_functions_dict))
              type_id, co_occurring_event = tuple 
              update_functions = global_update_functions_dict[tuple]

              if type_id isa Tuple 
                object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id in collect(type_id), collect(keys(object_mapping)))            
              else
                object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
              end
    
              # construct update_function_times_dict for this type_id/co_occurring_event pair 
              times_dict = Dict() # form: update function => object_id => times when update function occurred for object_id
              for update_function in update_functions 
                times_dict[update_function] = Dict(map(id -> id => findall(r -> r == update_function, vcat(anonymized_filtered_matrix[id, :]...)), object_ids_with_type))
              end

              if foldl(&, map(update_rule -> occursin("addObj", update_rule), update_functions))
                object_trajectories = map(id -> anonymized_filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id in collect(type_id), collect(keys(object_mapping))))
                true_times = unique(vcat(map(trajectory -> findall(rule -> rule in update_functions, vcat(trajectory...)), object_trajectories)...))
                object_trajectory = []
                ordered_update_functions = []
              else 
                ids_with_rule = map(idx -> object_ids_with_type[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] in update_functions, anonymized_filtered_matrix[id, :]), object_ids_with_type)))
                trajectory_lengths = map(id -> length(filter(x -> x != [""], anonymized_filtered_matrix[id, :])), ids_with_rule)
                max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
                object_id = ids_with_rule[max_index]
                object_trajectory = anonymized_filtered_matrix[object_id, :]
                true_times = unique(findall(rule -> rule in update_functions, vcat(object_trajectory...)))
                ordered_update_functions = ordered_update_functions_dict[type_id]
              end

              state_solutions = generate_global_multi_automaton_sketch(co_occurring_event, times_dict, global_event_vector_dict, object_trajectory, Dict(), Dict(1 => ["" for x in 1:length(user_events)]), object_decomposition, type_id, desired_per_matrix_solution_count, sketch_timeout, false, ordered_update_functions, transition_distinct, transition_same, transition_threshold)
              # @show state_solutions 
              if state_solutions[1][1] == []
                # println("MULTI-AUTOMATA SKETCH FAILURE")
                failed = true
                break
              else
                # println("IS THE OUTPUT HERE?")
                # @show state_solutions
                global_state_solutions_dict[tuple] = state_solutions
              end
            end

            if failed 
              # println("MULTI-AUTOMATA SKETCH BREAKING OUT OF WHILE")
              push!(solutions, ([], [], [], Dict()))
              break 
            end

            # GLOBAL AUTOMATON CONSTRUCTION 
            # @show global_state_solutions_dict
            global_update_function_tuples = sort(vcat(collect(keys(global_state_solutions_dict))...), by=x -> x isa Tuple ? length(x) : x)
      
            # compute products of component automata to find simplest 
            # println("PRE-GENERALIZATION (GLOBAL)")
            # @show global_state_solutions_dict
            global_state_solutions_dict = generalize_all_automata(global_state_solutions_dict, user_events, global_event_vector_dict, global_aut=true)
            # println("POST-GENERALIZATION (GLOBAL)")
            # @show global_state_solutions_dict

            product_automata = compute_all_products(global_state_solutions_dict, global_aut=true, generalized=true)
            best_automaton = optimal_automaton(product_automata)
            best_prod_states, best_prod_transitions, best_start_state, best_accept_states, best_co_occurring_events = best_automaton 
            
            if !(best_accept_states isa Tuple)
              best_accept_states = (best_accept_states,)
              best_co_occurring_events = (best_co_occurring_events,)
            end

            # re-label product states (tuples) to integers
            old_to_new_state_values = Dict(map(tup -> tup => findall(x -> x == tup, sort(best_prod_states))[1], sort(best_prod_states)))
      
            # construct product transitions under relabeling 
            new_transitions = map(old_trans -> (old_to_new_state_values[old_trans[1]], old_to_new_state_values[old_trans[2]], old_trans[3]), best_prod_transitions)
      
            # construct accept states for each update function under relabeling
            new_accept_state_dict = Dict()
            for tuple_index in 1:length(global_update_function_tuples)
              tuple = global_update_function_tuples[tuple_index]
              global_update_functions = sort(global_update_functions_dict[tuple])

              new_accept_state_dict[tuple_index] = Dict()

              for update_function_index in 1:length(global_update_functions)
                update_function = global_update_functions[update_function_index]
                orig_accept_states = best_accept_states[tuple_index][update_function_index]
                prod_accept_states = filter(tup -> tup[tuple_index] in orig_accept_states, best_prod_states)
                final_accept_states = map(tup -> old_to_new_state_values[tup], prod_accept_states)
                new_accept_state_dict[tuple_index][update_function] = final_accept_states
              end
            end 
      
            # construct start state under relabeling 
            new_start_state = old_to_new_state_values[best_start_state]
      
            state_based_update_func_on_clauses = vcat(map(tuple_idx -> map(upd_func -> ("(on (& $(best_co_occurring_events[tuple_idx]) (in (prev globalVar1) (list $(join(unique(new_accept_state_dict[tuple_idx][upd_func]), " ")))))\n$(replace(upd_func, "(--> obj (== (.. obj id) x))" => "(--> obj true)")))", upd_func), global_update_functions_dict[global_update_function_tuples[tuple_idx]]), collect(1:length(global_update_function_tuples)))...)
            new_transitions = map(trans -> (trans[1], trans[2], replace(trans[3], "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")), new_transitions)
            # @show new_transitions 
            state_transition_on_clauses = format_state_transition_functions(new_transitions, collect(values(old_to_new_state_values)), global_var_id=1)
            fake_global_var_dict = Dict(1 => [new_start_state for i in 1:length(user_events)])
            global_var_dict = fake_global_var_dict

            # format on_clauses 
            state_based_update_func_on_clauses = map(tup -> (replace(tup[1], "(--> obj (== (.. obj id) x))" => "(--> obj true)"), tup[2]), state_based_update_func_on_clauses)

            push!(on_clauses, state_based_update_func_on_clauses...)
            push!(on_clauses, state_transition_on_clauses...)

          end

          # OBJECT-SPECIFIC STATE HANDLING 
          # @show object_specific_update_functions_dict
          # @show observation_vectors_dict
          if length(collect(keys(object_specific_update_functions_dict))) > 0 
            for tuple in collect(keys(object_specific_update_functions_dict)) 
              type_id, co_occurring_event = tuple
              object_specific_update_functions = object_specific_update_functions_dict[tuple]

              times_dict = Dict() # form: update function => object_id => times when update function occurred for object_id
              if type_id isa Tuple 
                object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id in collect(type_id), collect(keys(object_mapping)))            
              else
                object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
              end

              for update_function in object_specific_update_functions 
                times_dict[update_function] = Dict(map(id -> id => findall(r -> r == update_function, vcat(anonymized_filtered_matrix[id, :]...)), object_ids_with_type))
              end

              state_solutions = generate_object_specific_multi_automaton_sketch(co_occurring_event, object_specific_update_functions, times_dict, global_event_vector_dict, type_id, global_object_decomposition, object_specific_state_update_times_dict, global_var_dict, sketch_timeout, false, transition_param, transition_distinct, transition_same, transition_threshold)            
              if state_solutions == [] 
                # println("MULTI-AUTOMATA SKETCH FAILURE")
                failed = true 
                break
              else
                object_specific_state_solutions_dict[tuple] = state_solutions
              end
            end

            if failed 
              push!(solutions, ([], [], [], Dict()))
              break
            end
    
            # @show object_specific_state_solutions_dict

            # OBJECT-SPECIFIC AUTOMATON CONSTRUCTION 
            object_specific_update_function_tuples = sort(vcat(collect(keys(object_specific_state_solutions_dict))...), by= x -> x isa Tuple ? length(x) : x)
          
            
            type_id = map(t -> t[1], object_specific_update_function_tuples)[1]
            object_ids = sort(filter(id -> filter(x -> !isnothing(x), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping))))

            # compute products of component automata to find simplest 
            # println("PRE-GENERALIZATION (OBJECT-SPECIFIC)")
            # @show object_specific_state_solutions_dict
            object_specific_state_solutions_dict = generalize_all_automata(object_specific_state_solutions_dict, user_events, global_event_vector_dict, global_aut=false)
            # println("POST-GENERALIZATION (OBJECT-SPECIFIC)")
            # @show object_specific_state_solutions_dict 

            product_automata = compute_all_products(object_specific_state_solutions_dict, global_aut=false, generalized=true)
            best_automaton = optimal_automaton(product_automata)
            best_prod_states, best_prod_transitions, best_start_state, best_accept_states, best_co_occurring_event = best_automaton 
    
            if !(best_accept_states isa Tuple)
              best_accept_states = (best_accept_states,)
              best_co_occurring_event = (best_co_occurring_event,)
            end

            # re-label product states (tuples) to integers
            old_to_new_state_values = Dict(map(tup -> tup => findall(x -> x == tup, sort(best_prod_states))[1], sort(best_prod_states)))
    
            # construct product transitions under relabeling 
            new_transitions = map(old_trans -> (old_to_new_state_values[old_trans[1]], old_to_new_state_values[old_trans[2]], old_trans[3]), best_prod_transitions)
    
            # construct accept states for each update function under relabeling
            new_accept_state_dict = Dict()
            for tuple_index in 1:length(object_specific_update_function_tuples)
              tuple = object_specific_update_function_tuples[tuple_index]
              update_functions = sort(object_specific_update_functions_dict[tuple])
              new_accept_state_dict[tuple_index] = Dict()
              for update_function_index in 1:length(update_functions) 
                update_function = update_functions[update_function_index]
                orig_accept_states = best_accept_states[tuple_index][update_function_index]
                prod_accept_states = filter(tup -> tup[tuple_index] in orig_accept_states, best_prod_states)
                final_accept_states = map(tup -> old_to_new_state_values[tup], prod_accept_states)
                new_accept_state_dict[tuple_index][update_function] = final_accept_states
              end 
            end 
    
            # construct start state under relabeling 
            orig_start_states = best_start_state
            new_start_states = map(tup -> old_to_new_state_values[tup], orig_start_states)
    
            # TODO: something generalization-based needs to happen here 
            state_based_update_func_on_clauses = vcat(map(tuple_idx -> map(upd_func -> ("(on true\n$(replace(upd_func, "(== (.. obj id) x)" => "(& $(best_co_occurring_event[tuple_idx]) (in (.. (prev obj) field1) (list $(join(new_accept_state_dict[tuple_idx][upd_func], " ")))))")))", upd_func), object_specific_update_functions_dict[object_specific_update_function_tuples[tuple_idx]]), 1:length(object_specific_update_function_tuples))...)
            # state_transition_on_clauses = map(trans -> """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(trans[2]))) (--> obj $(trans[3])))))""", new_transitions)
            state_transition_on_clauses = map(x -> replace(x, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))"), format_state_transition_functions(new_transitions, collect(values(old_to_new_state_values)), type_id=type_id))


            fake_object_field_values = Dict(map(idx -> object_ids[idx] => [new_start_states[idx] for i in 1:length(object_mapping[object_ids[1]])], 1:length(object_ids)))

            new_object_types = deepcopy(object_types)
            new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
            if !("field1" in map(field_tuple -> field_tuple[1], new_object_type.custom_fields))
              push!(new_object_type.custom_fields, ("field1", "Int", collect(values(old_to_new_state_values))))
            else
              custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
              new_object_type.custom_fields[custom_field_index][3] = sort(unique(vcat(new_object_type.custom_fields[custom_field_index][3], collect(values(old_to_new_state_values)))))
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
                        new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values[1:end-1], fake_object_field_values[id][time])
                      else
                        new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values, fake_object_field_values[id][time])
                      end
                    end
                  end
                end
              end
            end
            object_decomposition = (new_object_types, new_object_mapping, background, grid_size)
            global_object_decomposition = object_decomposition 

            # TODO: formatting
            push!(on_clauses, state_based_update_func_on_clauses...)
            push!(on_clauses, reverse(state_transition_on_clauses)...)
          end

          if failed
            # move to new problem context because appropriate state was not found  
            push!(solutions, ([], [], [], Dict()))
          else
            # @show filtered_matrix_index

            # re-order on_clauses
            ordered_on_clauses = re_order_on_clauses(on_clauses, ordered_update_functions_dict)
            
            push!(solutions, ([deepcopy(ordered_on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
            # save("solution_$(Dates.now()).jld", "solution", solutions[end])
            solutions_per_matrix_count += 1 
          end

        end


      end

      # println("MULTI-AUTOMATA SKETCH BREAK?")
    end 
  end
  # @show solutions 
  solutions 

end

function generate_global_multi_automaton_sketch(co_occurring_event, times_dict, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, sketch_timeout=0, incremental=false, ordered_update_functions=[], transition_distinct=1, transition_same=1, transition_threshold=1)
  # println("GENERATE_NEW_STATE_GLOBAL_SKETCH")
  # @show co_occurring_event
  # @show times_dict 
  # @show event_vector_dict 
  # @show object_trajectory    
  # @show init_global_var_dict 
  # @show state_update_times_dict  
  # # @show object_decomposition 
  # @show type_id
  # @show desired_per_matrix_solution_count 
  init_state_update_times_dict = deepcopy(state_update_times_dict)
  update_functions = collect(keys(times_dict))
  failed = false
  solutions = []
  object_types, object_mapping, _, _ = object_decomposition

  events = filter(e -> event_vector_dict[e] isa AbstractArray, collect(keys(event_vector_dict)))
  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id isa Tuple ? type_id[1] : type_id, ["nothing"], init_global_var_dict, collect(keys(times_dict))[1])
  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if !(e in atomic_events) || (!(event_vector_dict[e] isa AbstractArray) && !(e in map(x -> "(clicked (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(x)List)))", map(x -> x.id, object_types))) )
      delete!(small_event_vector_dict, e)
    end
  end

  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]
  # @show co_occurring_event_trajectory

  # initialize global_var_dict
  if length(collect(keys(init_global_var_dict))) == 0 
    init_global_var_dict[1] = ones(Int, length(init_state_update_times_dict[1]))
    global_var_id = 1
  else # check if all update function times match with one value of init_global_var_dict
    global_var_id = maximum(collect(keys(init_global_var_dict))) + 1 
    init_global_var_dict[global_var_id] = ones(Int, length(init_state_update_times_dict[1]))
    init_state_update_times_dict[global_var_id] = ["" for i in 1:length(init_state_update_times_dict[1])]
  end

  true_positive_times = unique(vcat(map(u -> vcat(map(id -> times_dict[u][id], collect(keys(times_dict[u])))...), update_functions)...)) # times when co_occurring_event happened and update_rule happened 
  false_positive_times = [] # times when user_event happened and update_rule didn't happen

  # @show true_positive_times 
  # @show false_positive_times

  # construct true_positive_times and false_positive_times 
  # # # @show length(user_events)
  # # # @show length(co_occurring_event_trajectory)
  for time in 1:length(co_occurring_event_trajectory)
    if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
      if foldl(&, map(update_rule -> occursin("addObj", update_rule), collect(keys(times_dict))))
        push!(false_positive_times, time)
      elseif (object_trajectory[time][1] != "") # && !(occursin("removeObj", object_trajectory[time][1]))
        
        rule = object_trajectory[time][1]
        min_index = minimum(findall(r -> r in update_functions, ordered_update_functions))

        # @show time 
        # @show rule 
        # @show min_index
        # @show findall(r -> r == rule, ordered_update_functions) 

        if is_no_change_rule(rule) || findall(r -> r == rule, ordered_update_functions)[1] < min_index 
          push!(false_positive_times, time)
        end
      end     
    end
  end

  # compute ranges in which to search for events 
  ranges = []

  update_functions = sort(collect(keys(times_dict)))
  update_function_indices = Dict(map(u -> u => findall(x -> x == u, update_functions)[1], update_functions))
  global_var_value = length(update_functions)

  # @show update_function_indices

  # construct augmented true positive times 
  augmented_true_positive_times_dict = Dict(map(u -> u => vcat(map(id -> map(t -> (t, update_function_indices[u]), times_dict[u][id]), collect(keys(times_dict[u])))...), update_functions))
  augmented_true_positive_times = unique(vcat(collect(values(augmented_true_positive_times_dict))...))  

  augmented_false_positive_times = map(t -> (t, global_var_value + 1), false_positive_times)
  init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

  # check if there is at most one label for every time; if not, failure
  if length(unique(map(x -> x[1], init_augmented_positive_times))) != length(init_augmented_positive_times)
    failed = true
    return [([], [], [], "")]
  end

  for i in 1:(length(init_augmented_positive_times)-1)
    prev_time, prev_value = init_augmented_positive_times[i]
    next_time, next_value = init_augmented_positive_times[i + 1]
    if prev_value != next_value
      push!(ranges, (init_augmented_positive_times[i], init_augmented_positive_times[i + 1]))
    end
  end
  # println("WHY THO")
  # # @show init_state_update_times_dict 

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
  # # @show init_grouped_ranges

  init_extra_global_var_values = Dict(map(u -> update_function_indices[u] => [], update_functions))

  problem_contexts = [(deepcopy(init_grouped_ranges), deepcopy(init_augmented_positive_times), deepcopy(init_state_update_times_dict), deepcopy(init_global_var_dict), deepcopy(init_extra_global_var_values))]
  split_orders = []
  old_augmented_positive_times = []
  
  # @show problem_contexts 
  # @show split_orders 
  # @show old_augmented_positive_times
  # @show global_var_id 
  # @show small_event_vector_dict 

  # @show init_augmented_positive_times

  num_transition_decisions = length(init_grouped_ranges)
  transition_decision_strings = sort(vec(collect(Base.product([1:(transition_distinct * transition_same) for i in 1:length(init_grouped_ranges)]...))), by=tup -> sum(collect(tup)))
  transition_decision_strings = transition_decision_strings[1:min(length(transition_decision_strings), transition_threshold)]
  # @show transition_decision_strings 

  solutions = []
  for transition_decision_string in transition_decision_strings 
    transition_decision_index = 1
    sketch_event_trajectory = ["true" for i in 1:length(co_occurring_event_trajectory)]
    for grouped_range in init_grouped_ranges
      range = grouped_range[1]
      start_value = range[1][2]
      end_value = range[2][2]

      time_ranges = map(r -> (r[1][1], r[2][1] - 1), grouped_range)

      # construct state update function
      state_update_function = "(= globalVar$(global_var_id) $(end_value))"

      # get current maximum value of globalVar
      max_global_var_value = maximum(map(tuple -> tuple[2], init_augmented_positive_times))

      # search for events within range
      events_in_range = find_state_update_events(small_event_vector_dict, init_augmented_positive_times, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1)
      events_in_range = filter(tuple -> !occursin("globalVar", tuple[1]), events_in_range)
      
      # println("PRE PRUNING: EVENTS IN RANGE")

      # @show events_in_range
      events_to_remove = []

      for tuple in events_in_range 
        if occursin("(clicked (filter (--> obj (== (.. obj id) ", tuple[1])
          id = parse(Int, split(split(tuple[1], "(clicked (filter (--> obj (== (.. obj id) ")[2], ")")[1])
          if nothing in object_mapping[id]
            push!(events_to_remove, tuple)
          end
        end
      end

      events_in_range = filter(tuple -> !(tuple in events_to_remove), events_in_range)
      # println("POST PRUNING: EVENTS IN RANGE")    
      # @show events_in_range
      if events_in_range != [] # event with zero false positives found
        # println("PLS WORK 2")
        # # # @show event_vector_dict
        # # @show events_in_range 
        state_update_event, event_times = events_in_range[1]
        
        if filter(tuple -> !occursin("true", tuple[1]), events_in_range) != []
          if filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range) != []
            min_times = minimum(map(tup -> length(tup[2]), filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range)))
            events_with_min_times = filter(tup -> length(tup[2]) == min_times, filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range))
            
            index = min(length(events_with_min_times), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            
            state_update_event, event_times = sort(events_with_min_times, by=x -> length(x[1]))[index] # sort(filter(tuple -> !occursin("globalVar", tuple[1]) && !occursin("true", tuple[1]), events_in_range), by=x -> length(x[2]))[1]
          else
            min_times = minimum(map(tup -> length(tup[2]), filter(tuple -> !occursin("true", tuple[1]), events_in_range)))
            events_with_min_times = filter(tup -> length(tup[2]) == min_times, filter(tuple -> !occursin("true", tuple[1]), events_in_range))
            
            index = min(length(events_with_min_times), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            
            state_update_event, event_times = sort(events_with_min_times, by=x -> length(x[1]))[index] # sort(filter(tuple -> !occursin("true", tuple[1]), events_in_range), by=x -> length(x[2]))[1]
          end
        else 
          # FAILURE CASE 
          index = min(length(events_in_range), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            

          state_update_event, event_times = events_in_range[index]
        end

        # @show state_update_event 
        # @show transition_decision_index 
        ## @show transition_decision_strings[transition_decision_index]

        for time in event_times 
          sketch_event_trajectory[time] = state_update_event
        end

      else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
        # find co-occurring event with fewest false positives 
        false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, init_augmented_positive_times, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1)
        false_positive_events_with_state = filter(e -> !occursin("globalVar", e[1]), false_positive_events) # no state-based events in sketch-based approach
        
        events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
        if events_without_true != []
          index = min(length(events_without_true), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            
          false_positive_event, _, true_positive_times, false_positive_times = events_without_true[index] 
          
          # @show false_positive_event 

          for time in vcat(true_positive_times, false_positive_times)
            sketch_event_trajectory[time] = false_positive_event
          end
        end
      end
      transition_decision_index += 1
    end
    # @show sketch_event_trajectory

    # construct sketch event input array
    distinct_events = sort(unique(sketch_event_trajectory), by=x -> count(y -> y == x, sketch_event_trajectory))
    # @show distinct_events 

    if length(distinct_events) > 9
      return [([], [], [], "")]
    end

    sketch_event_arr = map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)
    true_char = "0"
    if "true" in distinct_events 
      true_char = string(findall(x -> x == "true", distinct_events)[1])
    end

    # construct sketch update function input array
    sketch_update_function_arr = ["0" for i in 1:length(sketch_event_trajectory)]
    for tuple in init_augmented_positive_times 
      time, value = tuple 
      sketch_update_function_arr[time] = string(value)
    end

    # @show sketch_event_arr 
    # @show sketch_update_function_arr

    sketch_program = """ 
    include "$(sketch_directory)sketchlib/string.skh"; 
    include "$(sketch_directory)test/sk/numerical/mstatemachine.skh";

    bit recognize([int n], char[n] events, int[n] functions, char true_char){
        return matches(MSM(events, true_char), functions);
    }

    harness void h() {
      assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                        { $(join(sketch_update_function_arr, ", ")) }, 
                        '$(true_char)');
    }
    """

    # save sketch program 
    open("multi_automata_sketch.sk","w") do io
      println(io, sketch_program)
    end

    # run Sketch query
    if sketch_timeout == 0 
      command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-output-code multi_automata_sketch.sk"
    else
      if Sys.islinux() 
        command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-output-code multi_automata_sketch.sk"
      else
        command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-output-code multi_automata_sketch.sk"
      end
    end
    
    # @show command 

    sketch_output = try 
                      readchomp(eval(Meta.parse("`$(command)`")))
                    catch e
                      ""
                    end

    # @show sketch_output
    if sketch_output == "" || occursin("The sketch could not be resolved.", sketch_output)
      [([], [], [], init_global_var_dict)]
    else
      # update intAsChar and add main function to output cpp file 
      f = open("multi_automata_sketch.cpp", "r")
      cpp_content = read(f, String)
      close(f)

      modified_cpp_content = string(split(cpp_content, "void intAsChar")[1], """void intAsChar(int x, char& _out) {
        _out = static_cast<char>(x % 10);
        _out = printf("%d", _out);
      }
      
      }
      
      int main() {
        ANONYMOUS::h();
        return 0;
      }
      """)

      open("multi_automata_sketch.cpp", "w+") do io
        println(io, modified_cpp_content)
      end

      # compile modified cpp program 
      command = "g++ -o multi_automata_sketch.out multi_automata_sketch.cpp"
      compile_output = readchomp(eval(Meta.parse("`$(command)`"))) 

      # run compiled cpp program 
      command = "./multi_automata_sketch.out"
      run_output = readchomp(eval(Meta.parse("`$(command)`")))  
      run_output = replace(run_output, "\x01" => "")
      # @show run_output

      # parse run output to construct on_clauses, state_update_on_clauses, init_state_update_times, and init_global_var_dict
      parts = split(run_output, "STATE TRAJECTORY")
      state_transition_string = parts[1]
      states_and_table_string = parts[2]

      parts = split(states_and_table_string, "TABLE")
      states_string = parts[1]
      table_string = parts[2]

      # parse state trajectory into init_global_var_dict 
      global_var_values = map(s -> parse(Int, s), filter(x -> x != " ", split(states_string, "\n")))
      init_global_var_dict[global_var_id] = global_var_values

      # construct init_extra_global_var_values from table and on_clauses 
      state_to_update_function_index_arr = map(s -> parse(Int, s), filter(x -> x != " ", split(table_string, "\n")))
      distinct_states = unique(global_var_values)

      on_clauses = []
      for update_function in update_functions 
        update_function_index = update_function_indices[update_function]
        # collect all 0-based indices of state_to_update_function_index_arr with update_function_index as value 
        # these are all the state values corresponding to update_function_index 
        corresponding_states = map(i -> i - 1, findall(x -> x == update_function_index, state_to_update_function_index_arr))
        corresponding_states = intersect(corresponding_states, distinct_states) # don't count extraneous indices from table
        init_extra_global_var_values[update_function_index] = corresponding_states 
        
        on_clause = "(on (& $(co_occurring_event) (in (prev globalVar$(global_var_id)) (list $(join(corresponding_states, " ")))))\n$(update_function))"
        push!(on_clauses, (on_clause, update_function))
      end 

      # parse state transitions string to construct state_update_on_clauses and state_update_times 
      lines = filter(l -> l != " ", split(state_transition_string, "\n"))
      grouped_transitions = collect(Iterators.partition(lines, 6))
      transitions = []
      # @show grouped_transitions
      if grouped_transitions != [[""]]
        for grouped_transition in grouped_transitions 
          if grouped_transition != [""]
            start_state = parse(Int, grouped_transition[2])
            transition_label = distinct_events[parse(Int, grouped_transition[4])]
            end_state = parse(Int, grouped_transition[6])
            push!(transitions, (start_state, end_state, transition_label))
          end
        end
    
      end

      state_update_on_clauses = []
      for time in 2:length(init_global_var_dict[global_var_id])
        prev_value = init_global_var_dict[global_var_id][time - 1]
        next_value = init_global_var_dict[global_var_id][time]

        if prev_value != next_value 
          transition_tuple = filter(t -> t[1] == prev_value && t[2] == next_value, transitions)[1]
          _, _, transition_label = transition_tuple 
          
          state_update_on_clause = "(on (& $(transition_label) (== (prev globalVar$(global_var_id)) $(prev_value)))\n(= globalVar$(global_var_id) $(next_value)))"
          init_state_update_times_dict[global_var_id][time - 1] = state_update_on_clause
          push!(state_update_on_clauses, state_update_on_clause)
        end
      end
      
      # @show on_clauses 
      # @show state_update_on_clauses 
      # @show init_state_update_times_dict 
      # @show init_global_var_dict
      on_clauses = [on_clauses..., state_update_on_clauses...]
      if incremental 
        # println("AM I IN THE RIGHT PLACE?")
        push!(solutions, (on_clauses, init_global_var_dict, init_state_update_times_dict))
      else
        # println("WHERE IS THE OUTPUT??")
        # @show [(init_extra_global_var_values, unique(transitions), init_global_var_dict, co_occurring_event)]
        push!(solutions, (init_extra_global_var_values, unique(transitions), init_global_var_dict, co_occurring_event))
      end
    end
  end
  solutions
end

function generate_object_specific_multi_automaton_sketch(co_occurring_event, update_functions, times_dict, event_vector_dict, type_id, object_decomposition, init_state_update_times, global_var_dict, sketch_timeout=0, incremental=false, transition_param=false, transition_distinct=1, transition_same=1, transition_threshold=1) 
  # println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  # @show co_occurring_event
  # @show update_functions 
  # @show times_dict
  # @show event_vector_dict
  # @show type_id 
  # # @show object_decomposition
  # @show init_state_update_times
  state_update_times = deepcopy(init_state_update_times)  
  failed = false
  object_types, object_mapping, background, grid_size = object_decomposition 
  object_ids = sort(filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping))))

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
  # println("LETS GO NOW")
  # @show small_event_vector_dict 
  # choices, event_vector_dict, redundant_events_set, object_decomposition
  
  for e in keys(event_vector_dict)
    if (occursin("true", e) || occursin("|", e)) && e in keys(small_event_vector_dict)
      delete!(small_event_vector_dict, e)
    end
  end

  if transition_param 
    small_events = construct_compound_events(collect(keys(small_event_vector_dict)), small_event_vector_dict, Set(), object_decomposition)

    # x =  "(& clicked (! (in (objClicked click (prev addedObjType1List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType1List)))))"
    # if x in keys(event_vector_dict)
    #   small_event_vector_dict[x] = event_vector_dict[x]
    # end

    small_events = collect(keys(small_event_vector_dict))
    for e in small_events
      if (occursin("true", e) || occursin("|", e))
        delete!(small_event_vector_dict, e)
      end
    end
  end


  # @show length(collect(keys(event_vector_dict)))
  # @show length(collect(keys(small_event_vector_dict)))
  # @show small_event_vector_dict

  # initialize state_update_times
  curr_state_value = -1
  # @show state_update_times 
  # @show object_ids
  if length(collect(keys(state_update_times))) == 0 || length(intersect(object_ids, collect(keys(state_update_times)))) == 0
    for id in object_ids
      state_update_times[id] = [("", -1) for i in 1:(length(object_mapping[object_ids[1]])-1)]
    end
    curr_state_value = 1
  else
    # println("WEIRD")
    return ([], [], object_decomposition, state_update_times)
  end
  # println("# check state_update_times again 3")
  # @show state_update_times 
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  update_functions = sort(update_functions)
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
  # println("# check state_update_times again 4")
  # @show state_update_times 
  # compute ranges 
  init_grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, 1, object_mapping, object_ids)

  # println("# check state_update_times again 5")
  # @show state_update_times 
  iters = 0

  num_transition_decisions = length(init_grouped_ranges)
  transition_decision_strings = sort(vec(collect(Base.product([1:(transition_distinct * transition_same) for i in 1:length(init_grouped_ranges)]...))), by=tup -> sum(collect(tup)))
  transition_decision_strings = transition_decision_strings[1:min(length(transition_decision_strings), transition_threshold)]

  solutions = []
  for transition_decision_string in transition_decision_strings 
    transition_decision_index = 1
    grouped_ranges = deepcopy(init_grouped_ranges)

    # construct event array to feed into Sketch (post-formatting)
    sketch_event_arrs_dict = Dict(map(id -> id => ["true" for i in 1:length(object_mapping[object_ids[1]])], object_ids))

    while length(grouped_ranges) > 0 && (iters < 50)
      iters += 1
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
      # @show events_in_range
      events_in_range = filter(tup -> !occursin("field1", tup[1]) && !occursin("globalVar1", tup[1]), events_in_range)
      if length(events_in_range) > 0 # only handling perfect matches currently 
        index = min(length(events_in_range), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])
        event, event_times = events_in_range[index]
        # formatted_event = replace(event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")

        for id in object_ids # collect(keys(state_update_times))
          object_event_times = map(t -> t[1], filter(time -> time[2] == id, event_times))
          for time in object_event_times
            sketch_event_arrs_dict[id][time] = event
          end
        end

      else
        false_positive_events = find_state_update_events_object_specific_false_positives(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value)      
        false_positive_events_with_state = filter(e -> !occursin("field1", e[1]) && !occursin("globalVar1", e[1]), false_positive_events)
        # @show false_positive_events
        events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
        if events_without_true != []
          index = min(length(events_without_true), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])
          false_positive_event, _, true_positive_times, false_positive_times = events_without_true[index] 
        
          # construct state update on-clause
          # formatted_event = replace(false_positive_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
          
          for id in object_ids # collect(keys(state_update_times))
            object_event_times = map(t -> t[1], filter(time -> time[2] == id, vcat(true_positive_times, false_positive_times)))
            for time in object_event_times
              sketch_event_arrs_dict[id][time] = false_positive_event
            end
          end
            
        end
      end
      transition_decision_index += 1  
    end

    distinct_events = sort(unique(vcat(collect(values(sketch_event_arrs_dict))...)))  
    sketch_event_arrs_dict_formatted = Dict(map(id -> id => map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_arrs_dict[id]) , collect(keys(sketch_event_arrs_dict)))) # map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)
    
    if length(distinct_events) > 9
      return [([], [], [], "")]
    end

    true_char = "0"
    if "true" in distinct_events 
      true_char = string(findall(x -> x == "true", distinct_events)[1])
    end

    # construct sketch update function input array
    sketch_update_function_arr = Dict(map(id -> id => ["0" for i in 1:length(sketch_event_arrs_dict_formatted[object_ids[1]])], object_ids))
    for id in object_ids 
      augmented_positive_times = augmented_positive_times_dict[id]
      for tuple in augmented_positive_times 
        time, value = tuple 
        sketch_update_function_arr[id][time] = string(value)
      end
    end

    sketch_program = """ 
    include "$(sketch_directory)sketchlib/string.skh"; 
    include "$(sketch_directory)test/sk/numerical/mstatemachine.skh";
    
    bit recognize_obj_specific([int n], char[n] events, int[n] functions, int start, char true_char) {
        return matches(MSM_obj_specific(events, start, true_char), functions);
    }

    $(join(map(i -> """harness void h$(i)() {
                          int start = ??;
                          assert recognize_obj_specific({ $(join(map(c -> "'$(c)'", sketch_event_arrs_dict_formatted[object_ids[i]]), ", ")) }, 
                                                        { $(join(sketch_update_function_arr[object_ids[i]], ", ")) }, 
                                                        start, 
                                                        '$(true_char)');
                        }""", collect(1:length(object_ids))), "\n\n"))
    """

    ## save sketch program as file 
    open("multi_automata_sketch.sk","w") do io
      println(io, sketch_program)
    end

    # run Sketch query
    if sketch_timeout == 0 
      command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code multi_automata_sketch.sk"
    else
      if Sys.islinux() 
        command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code multi_automata_sketch.sk"
      else
        command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code multi_automata_sketch.sk"
      end
    end
    
    # @show command 

    sketch_output = try 
                      readchomp(eval(Meta.parse("`$(command)`")))
                    catch e
                      ""
                    end

    if !occursin("The sketch could not be resolved.", sketch_output) && sketch_output != ""
      # update intAsChar and add main function to output cpp file 
      f = open("multi_automata_sketch.cpp", "r")
      cpp_content = read(f, String)
      close(f)

      modified_cpp_content = string(replace(cpp_content, """void intAsChar(int x, char& _out) {
        _out = x % 10;
        return;
      }""" => "")[1:end-3],
        """void intAsChar(int x, char& _out) {
        _out = static_cast<char>(x % 10);
        _out = printf("%d", _out);
      }
      
      }
      int main() {
        $(join(map(i -> "ANONYMOUS::h$(i)();", collect(1:length(object_ids))), "\n  "))
      
        return 0;
      }
      """)

      open("multi_automata_sketch.cpp", "w+") do io
        println(io, modified_cpp_content)
      end

      # compile modified cpp program 
      command = "g++ -o multi_automata_sketch.out multi_automata_sketch.cpp"
      compile_output = readchomp(eval(Meta.parse("`$(command)`"))) 

      # run compiled cpp program 
      command = "./multi_automata_sketch.out"
      full_run_output = readchomp(eval(Meta.parse("`$(command)`")))  
      full_run_output = replace(full_run_output, "\x01" => "")
      
      output_per_object_id_list = filter(x -> occursin("TRAJECTORY", x), split(full_run_output, "DONE"))

      object_field_values = Dict()
      accept_values = Dict(map(i -> i => [], collect(values(update_function_indices))))
      transitions = []
      state_update_on_clauses = []
      for output_index in 1:length(output_per_object_id_list)
        run_output = output_per_object_id_list[output_index]

        parts = split(run_output, "STATE TRAJECTORY")
        state_transition_string = parts[1]
        states_and_table_string = parts[2]

        parts = split(states_and_table_string, "TABLE")
        states_string = parts[1]
        table_string = parts[2]

        # parse state trajectory into init_global_var_dict 
        field_values = map(s -> parse(Int, s), filter(x -> x != " ", split(states_string, "\n")))
        object_field_values[object_ids[output_index]] = field_values

        # construct accept_values from table and on_clauses 
        state_to_update_function_index_arr = map(s -> parse(Int, s), filter(x -> x != " ", split(table_string, "\n")))
        distinct_states = unique(field_values)

        for update_function_index in collect(values(update_function_indices))
          corresponding_states = map(i -> i - 1, findall(x -> x == update_function_index, state_to_update_function_index_arr))
          corresponding_states = intersect(corresponding_states, distinct_states) # don't count extraneous indices from table
          push!(accept_values[update_function_index], corresponding_states...)   
        end
        
        # parse state transitions string to construct state_update_on_clauses and state_update_times 
        if state_transition_string != "" 
          lines = filter(l -> l != " ", split(state_transition_string, "\n"))
          grouped_transitions = collect(Iterators.partition(lines, 6))  
          for grouped_transition in grouped_transitions 
            start_state = parse(Int, grouped_transition[2])
            transition_label = distinct_events[parse(Int, grouped_transition[4])]
            end_state = parse(Int, grouped_transition[6])
            push!(transitions, (start_state, end_state, transition_label))
          end

          for time in 2:length(field_values)
            prev_state = field_values[time - 1]
            next_state = field_values[time]

            if prev_state != next_state 
              _, _, transition_label = filter(trans -> (trans[1] == prev_state) && (trans[2] == next_state), transitions)[1]
              state_update_on_clause = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(next_state))) (--> obj (& $(co_occurring_event) (== (.. (prev obj) field1) $(prev_state)))))))"""
              push!(state_update_on_clauses, state_update_on_clause)
              state_update_times[object_ids[output_index]][time - 1] = (state_update_on_clause, next_state)
            end

          end

        end
      end

      for key in collect(keys(accept_values))
        accept_values[key] = unique(accept_values[key])
      end

      on_clauses = []
      for update_function_index in collect(keys(accept_values))
        update_function = update_functions[update_function_index]
        accept_states = accept_values[update_function_index]
        on_clause = "(on true\n$(replace(update_function, "(== (.. obj id) x)" => "(& $(co_occurring_event) (in (.. (prev obj) field1) (list $(join(accept_states, " ")))))")))"
        push!(on_clauses, (on_clause, update_function))
      end

      # construct new_object_decomposition 
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
      new_object_decomposition = (new_object_types, new_object_mapping, background, grid_size)

      # [(unique(accept_values), object_field_values, transitions, co_occurring_event)]
      if incremental 
        return [unique(on_clauses), unique(state_update_on_clauses), new_object_decomposition, state_update_times]  
      else
        push!(solutions, [(accept_values, object_field_values, unique(transitions), co_occurring_event)])
      end
    end
  end 
  solutions
end