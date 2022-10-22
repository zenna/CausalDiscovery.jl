if Sys.islinux() 
  sketch_directory = "/scratch/riadas/sketch-1.7.6/sketch-frontend/"
  temp_directory = "/scratch/riadas/.sketch/tmp"
  local_sketch_directory = "src/Autumn/generativemodel/sketch/"
else
  sketch_directory = "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/"
  temp_directory = "/Users/riadas/Documents/urop/.sketch/tmp"
  local_sketch_directory = "src/Autumn/generativemodel/sketch/"
end


function generate_on_clauses_SKETCH_SINGLE(run_id, matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, z3_option="full", time_based=false, z3_timeout=0, sketch_timeout=0, co_occurring_param=false, transition_param=false, co_occurring_distinct=2, co_occurring_same=1, co_occurring_threshold=1, transition_distinct=1, transition_same=1, transition_threshold=1; symmetry=false, stop_times=[])   
  println("generate_on_clauses_SKETCH_SINGLE")
  @show symmetry
  start_time = Dates.now()
  object_types, object_mapping, background, dim = object_decomposition
  solutions = []

  # construct type_displacements
  type_displacements = Dict()
  for type in object_types 
    type_displacements[type.id] = []
  end
  
  for object_type in object_types 
    type_id = object_type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

    for id in object_ids_with_type 
      for time in 1:(length(object_mapping[id]) - 1)
        if !isnothing(object_mapping[id][time]) && !isnothing(object_mapping[id][time + 1])
          disp = displacement(object_mapping[id][time].position, object_mapping[id][time + 1].position)
          if disp != (0, 0)
            scalars = map(y -> abs(y), filter(x -> x != 0, [disp...]))
            push!(type_displacements[type_id], scalars...)
          end
        end
      end
    end
  end

  for type in object_types 
    type_displacements[type.id] = unique(type_displacements[type.id])
  end    

  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  # filtered_matrix = filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition)[1]
  
  if !check_matrix_complete(matrix)
    return solutions
  end

  filtered_matrices = construct_filtered_matrices_pedro(matrix, object_decomposition, user_events, symmetry)
  # filtered_matrices = filtered_matrices[1:1]

  for filtered_matrix_index in 1:length(filtered_matrices)
    @show filtered_matrix_index
    failed = false
    # @show length(filtered_matrices)
    # @show solutions
    filtered_matrix = filtered_matrices[filtered_matrix_index]

    interval_offsets = compute_regularity_interval_sizes(filtered_matrix, object_decomposition)
    source_exists_events_dict = compute_source_objects(filtered_matrix, object_decomposition)
    
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

    @show desired_solution_count 
    @show length(filter(x -> x[1] != [], solutions))
    @show solutions
    if (length(filter(x -> x[1] != [], solutions)) >= desired_solution_count) || Dates.value(Dates.now() - start_time) > 3600 * 2 * 1000 # || ((length(filter(x -> x[1] != [], solutions)) > 0) && length(filter(x -> occursin("randomPositions", x), vcat(vcat(filtered_matrix...)...))) > 0) 
      # if we have reached a sufficient solution count or have found a solution before trying random solutions, exit
      # println("BREAKING")
      # println("elapsed time: $(Dates.value(Dates.now() - start_time))")
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
    new_on_clauses, state_based_update_functions_dict, observation_vectors_dict, addObj_params_dict, global_event_vector_dict, ordered_update_functions_dict = generate_stateless_on_clauses(run_id, type_displacements, interval_offsets, source_exists_events_dict, update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set, z3_option, time_based, z3_timeout, sketch_timeout, symmetry, stop_times=stop_times)
    
    println("I AM HERE NOW")
    @show new_on_clauses
    @show state_based_update_functions_dict
    @show ordered_update_functions_dict
    push!(on_clauses, new_on_clauses...)
    @show observation_vectors_dict

    addObj_based_list = filter(x -> occursin("addObj", x) && !(occursin("(move (.. (prev obj", x) && !occursin("uniformChoice", x)), vcat(collect(values(state_based_update_functions_dict))...))
    @show addObj_based_list
    # for type_id in keys(state_based_update_functions_dict) 
    #   state_based_update_functions_dict[type_id] = filter(u -> !(u in addObj_based_list), state_based_update_functions_dict[type_id])
    # end

    double_removeObj_update_functions = compute_double_removeObj_objects(vcat(collect(values(state_based_update_functions_dict))...), 
                                                                         observation_vectors_dict, 
                                                                         filtered_matrix)
 
    # check if all update functions were solved; if not, proceed with state generation procedure
    if length(collect(keys(state_based_update_functions_dict))) == 0 
      # re-order on_clauses
      ordered_on_clauses = re_order_on_clauses(on_clauses, ordered_update_functions_dict)
      
      @show ordered_on_clauses 
      push!(solutions, ([deepcopy(ordered_on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
      @show solutions
    else # GENERATE NEW STATE 

      # ----- START: SPECIAL ADDOBJ HANDLING: PART 1 -----
      all_state_based_update_functions = vcat(collect(values(state_based_update_functions_dict))...)

      # triple-linked update functions
      triple_linked_type_ids_dict = compute_source_objects_triple_linked(filtered_matrix, object_decomposition)
      triple_linked_update_functions = []
      for addObj_type_id in keys(triple_linked_type_ids_dict)
        source1_type_id, source2_type_id = triple_linked_type_ids_dict[addObj_type_id]
        addObj_update_functions = filter(u -> occursin("addObj", u) && occursin("addedObjType$(addObj_type_id)List", u), all_state_based_update_functions)
        source1_update_functions = filter(u -> occursin("removeObj", u) && occursin("addedObjType$(source1_type_id)List", u), all_state_based_update_functions)
        source2_update_functions = filter(u -> occursin("removeObj", u) && occursin("addedObjType$(source2_type_id)List", u), all_state_based_update_functions)
        if addObj_update_functions != [] && source1_update_functions != [] && source2_update_functions != []
          # TODO: override addObj so it refers to both source1 and source2 type id's
          push!(triple_linked_update_functions, [addObj_update_functions[1], source1_update_functions[1], source2_update_functions[1]]...)
        end
      end

      @show triple_linked_update_functions 

      linked_removeObj_update_functions = []
      for addObj_removeObj_pair in keys(source_exists_events_dict)
        addObj_type_id, removeObj_type_id = addObj_removeObj_pair
        source_exists_event, state_based = source_exists_events_dict[addObj_removeObj_pair]
        addObj_update_functions = filter(u -> occursin("addObj addedObjType$(addObj_type_id)List", u), all_state_based_update_functions)
        if addObj_update_functions != []
          ids_with_removeObj_type_id = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == removeObj_type_id, collect(keys(object_mapping)))
          removeObj_update_functions = filter(u -> occursin("removeObj addedObjType$(removeObj_type_id)List", u) || occursin("removeObj (prev obj$(ids_with_removeObj_type_id[1]))", u), all_state_based_update_functions)
          push!(linked_removeObj_update_functions, removeObj_update_functions...)
        end
      end

      for pair in double_removeObj_update_functions 
        push!(linked_removeObj_update_functions, pair[2])
      end

      linked_removeObj_update_functions = filter(u -> !(u in triple_linked_update_functions), linked_removeObj_update_functions)

      @show linked_removeObj_update_functions
      @show double_removeObj_update_functions

      # ----- END: SPECIAL ADDOBJ HANDLING: PART 2 -----


      global_state_solutions_dict = Dict()
      object_specific_state_solutions_dict = Dict()

      # for each update function 
      type_ids = collect(keys(state_based_update_functions_dict))
      update_functions = vcat(values(state_based_update_functions_dict)...)      

      global_update_functions_dict = Dict()
      object_specific_update_functions_dict = Dict()

      for type_id in type_ids 
        @show type_id
        object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
        for update_function in state_based_update_functions_dict[type_id] 
          @show update_function
          # determine if state is global or object-specific 
          state_is_global = true 
          if length(object_ids_with_type) == 1 || occursin("addObj", update_function)
            state_is_global = true
          else
            state_is_global = false
            # for time in 1:length(user_events)
            #   observation_values = map(id -> observation_vectors_dict[update_function][id][time], object_ids_with_type)
            #   if (0 in observation_values) && (1 in observation_values)
            #     @show update_function 
            #     @show time 
            #     state_is_global = false
            #     break
            #   end
            # end
          end

          if state_is_global 
            if type_id in keys(global_update_functions_dict)
              push!(global_update_functions_dict[type_id], update_function)
            else
              global_update_functions_dict[type_id] = [update_function]
            end
          else
            if type_id in keys(object_specific_update_functions_dict)
              push!(object_specific_update_functions_dict[type_id], update_function)
            else
              object_specific_update_functions_dict[type_id] = [update_function]
            end
          end
        end
      end

      println("DEBUGGING HERE NOW")
      @show global_update_functions_dict
      @show object_specific_update_functions_dict
      # @show type_id 
      @show object_mapping 
      @show anonymized_filtered_matrix

      # GLOBAL STATE HANDLING
      if length(collect(keys(global_update_functions_dict))) > 0 
        global_update_function_type_ids = sort(vcat(collect(keys(global_update_functions_dict))...))
        # construct update_function_times_dict for this type_id/co_occurring_event pair 
        for type_id in global_update_function_type_ids
          global_update_functions = global_update_functions_dict[type_id]
          for update_function in global_update_functions 
            times_dict = Dict() # form: update function => object_id => times when update function occurred for object_id
            object_ids_with_type = filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping)))
            for u in global_update_functions 
              times_dict[update_function] = Dict(map(id -> id => findall(r -> r == u, vcat(anonymized_filtered_matrix[id, :]...)), object_ids_with_type))
            end
      
            if occursin("addObj", update_function)
              object_trajectories = map(id -> anonymized_filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == type_id, collect(keys(object_mapping))))
              true_times = unique(vcat(map(trajectory -> findall(rule -> rule == update_function, vcat(trajectory...)), object_trajectories)...))
              object_trajectory = []
              ordered_update_functions = []
            else 
              ids_with_rule = map(idx -> object_ids_with_type[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] == update_function, anonymized_filtered_matrix[id, :]), object_ids_with_type)))
              trajectory_lengths = map(id -> length(filter(x -> x != [""], anonymized_filtered_matrix[id, :])), ids_with_rule)
              max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
              object_id = ids_with_rule[max_index]
              object_trajectory = anonymized_filtered_matrix[object_id, :]
              true_times = unique(findall(rule -> rule == update_function, vcat(object_trajectory...)))
              ordered_update_functions = ordered_update_functions_dict[type_id]
            end
            state_solutions = generate_global_automaton_sketch(run_id, update_function, true_times, global_event_vector_dict, object_trajectory, Dict(), global_state_update_times_dict, global_object_decomposition, type_id, type_displacements, interval_offsets, source_exists_events_dict, filtered_matrix, desired_per_matrix_solution_count, interval_painting_param, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, sketch_timeout, ordered_update_functions, global_update_functions, co_occurring_param, co_occurring_distinct, co_occurring_same, co_occurring_threshold, transition_distinct, transition_same, transition_threshold, stop_times=stop_times)
            if state_solutions == [] 
              failed = true 
              break
            elseif state_solutions[1] == "special"
              push!(on_clauses, state_solutions[2:end]...)
            else
              global_state_solutions_dict[update_function] = state_solutions 
            end
          end

          if failed 
            break
          end

        end

        if !failed && collect(keys(global_state_solutions_dict)) != []
          # GLOBAL AUTOMATON CONSTRUCTION 
          @show global_state_solutions_dict
          global_update_functions = sort(vcat(collect(keys(global_state_solutions_dict))...))
    
          # compute products of component automata to find simplest 
          println("PRE-GENERALIZATION (GLOBAL)")
          @show global_state_solutions_dict
          global_state_solutions_dict = generalize_all_automata(global_state_solutions_dict, user_events, global_event_vector_dict, global_aut=true)
          println("POST-GENERALIZATION (GLOBAL)")
          @show global_state_solutions_dict

          product_automata = compute_all_products(global_state_solutions_dict, global_aut=true, generalized=true)
          best_automaton = optimal_automaton(product_automata)
          best_prod_states, best_prod_transitions, best_start_state, best_accept_states, best_co_occurring_events = best_automaton 
    
          # re-label product states (tuples) to integers
          old_to_new_state_values = Dict(map(tup -> tup => findall(x -> x == tup, sort(best_prod_states))[1], sort(best_prod_states)))
    
          # construct product transitions under relabeling 
          new_transitions = map(old_trans -> (old_to_new_state_values[old_trans[1]], old_to_new_state_values[old_trans[2]], old_trans[3]), best_prod_transitions)
    
          # construct accept states for each update function under relabeling
          new_accept_state_dict = Dict()
          for update_function_index in 1:length(global_update_functions)
            update_function = global_update_functions[update_function_index]
            orig_accept_states = best_accept_states[update_function_index]
            prod_accept_states = filter(tup -> tup[update_function_index] in orig_accept_states, best_prod_states)
            final_accept_states = map(tup -> old_to_new_state_values[tup], prod_accept_states)
            new_accept_state_dict[update_function] = final_accept_states
          end 
    
          # construct start state under relabeling 
          new_start_state = old_to_new_state_values[best_start_state]
    
          state_based_update_func_on_clauses = map(idx -> ("(on (& $(best_co_occurring_events[idx]) (in (prev globalVar1) (list $(join(new_accept_state_dict[global_update_functions[idx]], " ")))))\n$(replace(global_update_functions[idx], "(--> obj (== (.. obj id) x))" => "(--> obj true)")))", global_update_functions[idx]), collect(1:length(global_update_functions)))
          # state_transition_on_clauses = map(trans -> "(on (& $(trans[3]) (== (prev globalVar1) $(trans[1])))\n(= globalVar1 $(trans[2])))", new_transitions)
          state_transition_on_clauses = format_state_transition_functions(new_transitions, collect(values(old_to_new_state_values)), global_var_id=1)
          fake_global_var_dict = Dict(1 => [new_start_state for i in 1:length(user_events)])
          global_var_dict = fake_global_var_dict
          push!(on_clauses, state_based_update_func_on_clauses...)
          push!(on_clauses, state_transition_on_clauses...)  
        end
      end

      println("OH BOY")
      @show object_specific_update_functions_dict
      update_functions_dict = object_specific_update_functions_dict 

      @show update_functions_dict
      @show global_state_update_on_clauses

      new_on_clauses, state_based_update_functions_dict, _, _, global_event_vector_dict, _ = generate_stateless_on_clauses(run_id, type_displacements, interval_offsets, source_exists_events_dict, update_functions_dict, matrix, filtered_matrix, anonymized_filtered_matrix, global_object_decomposition, user_events, global_state_update_on_clauses, global_var_dict, global_event_vector_dict, redundant_events_set, z3_option, time_based, z3_timeout, sketch_timeout, symmetry, stop_times=stop_times)          
      println("WHATS GOING ON NOW")
      @show new_on_clauses 
      @show state_based_update_functions_dict

      println("NOW HERE 2")
      @show length(on_clauses)
      @show on_clauses

      @show collect(keys(object_specific_update_functions_dict))
      @show object_specific_update_functions_dict
      
      # if some other update functions are solved, add their on-clauses + remove them from object_specific_update_functions_dict 
      if new_on_clauses != [] 
        push!(on_clauses, new_on_clauses...)
        # update object_specific_update_functions_dict by removing newly solved update functions
        for t_id in collect(keys(object_specific_update_functions_dict)) 
          if !(t_id in keys(state_based_update_functions_dict)) 
            delete!(object_specific_update_functions_dict, t_id)
          else
            for u in object_specific_update_functions_dict[t_id]
              if !(u in state_based_update_functions_dict[t_id]) # if u is not in the new state_based_update_functions_dict, then it has already been solved!
                filter!(x -> x != u, object_specific_update_functions_dict[t_id])
              end
            end

            if object_specific_update_functions_dict[t_id] == []
              delete!(object_specific_update_functions_dict, t_id)
            end
          end
        end

      end
      println("WBU")
      @show on_clauses
      @show collect(keys(object_specific_update_functions_dict))
      @show object_specific_update_functions_dict




      # OBJECT-SPECIFIC STATE HANDLING 
      @show object_specific_update_functions_dict
      @show observation_vectors_dict
      if length(collect(keys(object_specific_update_functions_dict))) > 0 
        for type_id in collect(keys(object_specific_update_functions_dict)) 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
          object_specific_update_functions = object_specific_update_functions_dict[type_id]
          for update_function in object_specific_update_functions 
            update_function_times_dict = Dict()
            for object_id in object_ids_with_type 
              update_function_times_dict[object_id] = findall(x -> x == 1, observation_vectors_dict[update_function][object_id])
            end

            state_solutions = generate_object_specific_automaton_sketch(run_id, update_function, update_function_times_dict, global_event_vector_dict, type_id, filtered_matrix, global_object_decomposition, object_specific_state_update_times_dict, global_var_dict, type_displacements, interval_offsets, source_exists_events_dict, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, sketch_timeout, co_occurring_param, co_occurring_distinct, co_occurring_same, co_occurring_threshold, transition_distinct, transition_same, transition_threshold, stop_times=stop_times)            
            # println("OUTPUT??")
            @show state_solutions
            if state_solutions == [] 
              # println("SKETCH AUTOMATA SEARCH FAILED")
              failed = true 
              break
            elseif state_solutions[1] == "special"
              push!(on_clauses, state_solutions[2:end]...)
            else
              object_specific_state_solutions_dict[update_function] = state_solutions
            end
          end

          if failed 
            break 
          end
        end

        if !failed && collect(keys(object_specific_state_solutions_dict)) != []
          @show object_specific_state_solutions_dict

          object_specific_state_solutions_dict_full = deepcopy(object_specific_state_solutions_dict)

          new_object_types = deepcopy(object_types)
          new_object_mapping = deepcopy(object_mapping)

          for type_id in collect(keys(object_specific_update_functions_dict))
            object_ids = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
  
            # OBJECT-SPECIFIC AUTOMATON CONSTRUCTION 
            object_specific_update_functions = sort(object_specific_update_functions_dict[type_id])
            # object_specific_update_functions = sort(vcat(collect(keys(object_specific_state_solutions_dict))...))
    
            # compute products of component automata to find simplest 
            # # # # # println("PRE-GENERALIZATION (OBJECT-SPECIFIC)")
            object_specific_state_solutions_dict = Dict(map(u -> u => object_specific_state_solutions_dict_full[u], object_specific_update_functions))
            # @show object_specific_state_solutions_dict
            object_specific_state_solutions_dict = generalize_all_automata(object_specific_state_solutions_dict, user_events, global_event_vector_dict, global_aut=false)
            # # # # # println("POST-GENERALIZATION (OBJECT-SPECIFIC)")
            # @show object_specific_state_solutions_dict 
    
            product_automata = compute_all_products(object_specific_state_solutions_dict, global_aut=false, generalized=true)
            best_automaton = optimal_automaton(product_automata)
            best_prod_states, best_prod_transitions, best_start_state, best_accept_states, best_co_occurring_event = best_automaton 
    
            # @show best_prod_states 
            # @show best_prod_transitions 
            # @show best_start_state 
            # @show best_accept_states 
            # @show best_co_occurring_event 
    
            # re-label product states (tuples) to integers
            old_to_new_state_values = Dict(map(tup -> tup => findall(x -> x == tup, sort(best_prod_states))[1], sort(best_prod_states)))
    
            # construct product transitions under relabeling 
            new_transitions = map(old_trans -> (old_to_new_state_values[old_trans[1]], old_to_new_state_values[old_trans[2]], old_trans[3]), best_prod_transitions)
    
            # construct accept states for each update function under relabeling
            new_accept_state_dict = Dict()
            for update_function_index in 1:length(object_specific_update_functions)
              update_function = object_specific_update_functions[update_function_index]
              orig_accept_states = best_accept_states[update_function_index]
              prod_accept_states = filter(tup -> tup[update_function_index] in orig_accept_states, best_prod_states)
              final_accept_states = map(tup -> old_to_new_state_values[tup], prod_accept_states)
              new_accept_state_dict[update_function] = final_accept_states
            end 
    
            # construct start state under relabeling 
            orig_start_states = best_start_state
            new_start_states = map(tup -> old_to_new_state_values[tup], orig_start_states)
          
            # TODO: something generalization-based needs to happen here 
            state_based_update_func_on_clauses = map(idx -> ("(on true\n$(replace(object_specific_update_functions[idx], "(== (.. obj id) x)" => "(& $(best_co_occurring_event[idx]) (in (.. (prev obj) field1) (list $(join(new_accept_state_dict[object_specific_update_functions[idx]], " ")))))")))", object_specific_update_functions[idx]), 1:length(object_specific_update_functions))
            new_transitions = map(trans -> (trans[1], trans[2], replace(trans[3], "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")), new_transitions)
            # state_transition_on_clauses = map(trans -> """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(trans[2]))) (--> obj $(trans[3])))))""", new_transitions)
            state_transition_on_clauses = map(x -> replace(x, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))" ), format_state_transition_functions(new_transitions, collect(values(old_to_new_state_values)), type_id=type_id))
    
            fake_object_field_values = Dict(map(idx -> sort(object_ids)[idx] => [new_start_states[idx] for i in 1:length(object_mapping[object_ids[1]])], 1:length(object_ids)))    
            new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
            if !("field1" in map(field_tuple -> field_tuple[1], new_object_type.custom_fields))
              push!(new_object_type.custom_fields, ("field1", "Int", collect(values(old_to_new_state_values))))
            else
              custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
              new_object_type.custom_fields[custom_field_index][3] = sort(unique(vcat(new_object_type.custom_fields[custom_field_index][3], collect(values(old_to_new_state_values)))))
            end
            
            ## modify objects in object_mapping
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
            
            # TODO: formatting
            push!(on_clauses, state_based_update_func_on_clauses...)
            push!(on_clauses, reverse(state_transition_on_clauses)...)
  
          end
          object_decomposition = (new_object_types, new_object_mapping, background, grid_size)
        end
      end

      if !failed 
        @show on_clauses 
        @show ordered_update_functions_dict
        ordered_on_clauses = re_order_on_clauses(on_clauses, ordered_update_functions_dict)
  
        push!(solutions, (ordered_on_clauses, object_decomposition, global_var_dict))
      else 
        push!(solutions, ([], [], [], Dict()))  
      end
    end
  end
  solutions
end

function generate_global_automaton_sketch(run_id, update_rule, update_function_times, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, type_displacements, interval_offsets, source_exists_events_dict, filtered_matrix, desired_per_matrix_solution_count, interval_painting_param, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, sketch_timeout=0, ordered_update_functions=[], global_update_functions = [], co_occurring_param=false, co_occurring_distinct=1, co_occurring_same=1, co_occurring_threshold=1, transition_distinct=1, transition_same=1, transition_threshold=1; stop_times=[])
  println("GENERATE_NEW_STATE_SKETCH")
  @show update_rule 
  @show update_function_times
  @show event_vector_dict 
  @show object_trajectory    
  @show init_global_var_dict 
  @show state_update_times_dict 
  @show object_decomposition
  @show type_id 
  @show desired_per_matrix_solution_count
  @show interval_painting_param
  @show ordered_update_functions 
  @show global_update_functions
  
  @show sketch_timeout
  @show ordered_update_functions
  @show global_update_functions
  @show co_occurring_param
  @show co_occurring_distinct
  @show co_occurring_same
  @show co_occurring_threshold
  @show transition_distinct
  @show transition_same
  @show transition_threshold

  # if co_occurring_event == "(== 1 1)"
  #   co_occurring_event = "true"
  # end

  init_state_update_times_dict = deepcopy(state_update_times_dict)
  failed = false
  solutions = []
  object_types, object_mapping, _, _ = object_decomposition

  events = filter(e -> event_vector_dict[e] isa AbstractArray, collect(keys(event_vector_dict)))
  @show events 
  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id isa Tuple ? type_id[1] : type_id, ["nothing"], init_global_var_dict, update_rule, type_displacements, interval_offsets, source_exists_events_dict)
  @show atomic_events 
  small_event_vector_dict = deepcopy(event_vector_dict)    
  deleted = []
  for e in keys(event_vector_dict)
    if occursin("globalVar", e) || occursin("field", e) || occursin("adj", e) || !(e in atomic_events) || (!(event_vector_dict[e] isa AbstractArray) && !(e in map(x -> "(clicked (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(x)List)))", map(x -> x.id, object_types))) )
      push!(deleted, e)
      delete!(small_event_vector_dict, e)    
    end
  end

  # compute best co-occurring event (i.e. event with fewest false positives)
  co_occurring_events = []
  for event in events
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if is_co_occurring(event, event_vector, update_function_times)
      push!(co_occurring_events, (event, num_false_positives(event_vector, update_function_times, object_trajectory, addObj=occursin("addObj", update_rule))))
    end 
  end
  # @show co_occurring_events
  # co_occurring_events = sort(filter(x -> !occursin("|", x[1]) && (!occursin("&", x[1]) || occursin("click", x[1])), co_occurring_events), by=x->x[2]) # [1][1]
  
  if co_occurring_param 
    co_occurring_events = sort(filter(x -> !occursin("(list)", x[1]) && !occursin("(move ", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("adj", x[1]) && !occursin("pushConfiguration", x[1]) && (!occursin("intersects (list", x[1]) || occursin("(.. obj id) x", x[1])) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))") && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
  else
    co_occurring_events = sort(filter(x -> !occursin("(filter (--> obj (.. obj alive))", x[1]) && (!occursin("(list)", x[1]) || occursin("distance", x[1]) || occursin("addObj", update_rule)) && !occursin("adj ", x[1]) && !occursin("pushConfiguration", x[1]) && !occursin("|", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("objClicked", x[1]) && !occursin("intersects (list", x[1]) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))")  && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
  end

  specially_handled_on_clauses = special_addObj_removeObj_handling(update_rule, filtered_matrix, co_occurring_events, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, source_exists_events_dict, object_decomposition)
  if specially_handled_on_clauses != []
    return vcat("special", specially_handled_on_clauses...)
  end

  false_positive_counts = sort(unique(map(x -> x[2], co_occurring_events)))
  false_positive_counts = false_positive_counts[1:min(length(false_positive_counts), co_occurring_distinct)]
  optimal_co_occurring_events = []
  for false_positive_count in false_positive_counts 
    events_with_count = map(e -> e[1], sort(filter(tup -> tup[2] == false_positive_count, co_occurring_events), by=t -> length(t[1])))
    push!(optimal_co_occurring_events, events_with_count[1:min(length(events_with_count), co_occurring_same)]...)
  end

  optimal_co_occurring_events = optimal_co_occurring_events[1:min(length(optimal_co_occurring_events), co_occurring_threshold)]

  # best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
  # # @show best_co_occurring_events
  # co_occurring_event = best_co_occurring_events[1][1]
  # co_occurring_event_trajectory = event_vector_dict[co_occurring_event]
  # @show co_occurring_event 
  # @show co_occurring_event_trajectory

  for co_occurring_event in optimal_co_occurring_events
    co_occurring_event_trajectory = event_vector_dict[co_occurring_event]
    @show co_occurring_event 
    @show co_occurring_event_trajectory

    # initialize global_var_dict and get global_var_value
    if length(collect(keys(init_global_var_dict))) == 0 
      init_global_var_dict[1] = ones(Int, length(init_state_update_times_dict[1]))
      global_var_value = 1
      global_var_id = 1
    else # check if all update function times match with one value of init_global_var_dict 
      global_var_id = -1
      for key in collect(keys(init_global_var_dict))
        values = init_global_var_dict[key]
        if length(unique(map(t -> values[t], update_function_times))) == 1
          global_var_id = key
          break
        end
      end
    
      if global_var_id == -1 # update function times crosses state lines 
        # initialize new global var 
        max_key = maximum(collect(keys(init_global_var_dict)))
        init_global_var_dict[max_key + 1] = ones(Int, length(init_state_update_times_dict[1]))
        global_var_id = max_key + 1 

        init_state_update_times_dict[global_var_id] = ["" for i in 1:length(init_global_var_dict[max_key])]
      end
      global_var_value = maximum(init_global_var_dict[global_var_id])  
    end

    true_positive_times = update_function_times # times when co_occurring_event happened and update_rule happened 
    false_positive_times = [] # times when user_event happened and update_rule didn't happen

    # construct true_positive_times and false_positive_times 
    # # @show length(user_events)
    # # @show length(co_occurring_event_trajectory)
    for time in 1:length(co_occurring_event_trajectory)
      if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
        if occursin("addObj", update_rule)
          push!(false_positive_times, time)
        elseif (object_trajectory[time][1] != "") # && !(occursin("addObj", object_trajectory[time][1]))
                  
          rule = object_trajectory[time][1]
          min_index = minimum(findall(r -> r == update_rule, ordered_update_functions))

          @show time 
          @show rule 
          @show min_index 
          @show findall(r -> r == rule, ordered_update_functions) 

          if is_no_change_rule(rule) || findall(r -> r == rule, ordered_update_functions)[1] < min_index || rule in global_update_functions
            push!(false_positive_times, time)
          end

        end     
      end
    end

    # compute ranges in which to search for events 
    ranges = []
    augmented_true_positive_times = map(t -> (t, global_var_value), true_positive_times)
    augmented_false_positive_times = map(t -> (t, global_var_value + 1), false_positive_times)

    augmented_stop_times = []
    stop_var_value = maximum(map(tup -> tup[2], vcat(augmented_true_positive_times..., augmented_false_positive_times...))) + 1
    all_stop_var_values = []
    for stop_time in stop_times 
      push!(augmented_stop_times, (stop_time, stop_var_value))
      push!(all_stop_var_values, stop_var_value)
      stop_var_value += 1
    end

    init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

    for i in 1:(length(init_augmented_positive_times)-1)
      prev_time, prev_value = init_augmented_positive_times[i]
      next_time, next_value = init_augmented_positive_times[i + 1]
      if prev_value != next_value
        push!(ranges, (init_augmented_positive_times[i], init_augmented_positive_times[i + 1]))
      end
    end

    # add ranges that interface between global_var_value and lower values
    if global_var_value > 1
      for time in 1:(length(init_state_update_times_dict[global_var_id]) - 1)
        prev_val = init_global_var_dict[global_var_id][time]
        next_val = init_global_var_dict[global_var_id][time + 1]
        # println("HELLO 1")
        # @show prev_val 
        # @show next_val 
        if (prev_val < global_var_value) && (next_val == global_var_value)
          if (filter(t -> t[1] == time + 1, init_augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, init_augmented_positive_times)[1][2] != global_var_value)
            new_value = filter(t -> t[1] == time + 1, init_augmented_positive_times)[1][2]
            push!(ranges, ((time, prev_val), (time + 1, new_value)))        
          else
            push!(ranges, ((time, prev_val), (time + 1, next_val)))        
          end
          # println("IT'S ME 1")
          # clear state update functions within this range; will find new ones later
          state_update_func = init_state_update_times_dict[global_var_id][time]
          if state_update_func != "" 
            for time in 1:length(init_state_update_times_dict[global_var_id])
              if init_state_update_times_dict[global_var_id][time] == state_update_func
                init_state_update_times_dict[global_var_id][time] = ""
              end
            end
          end

        elseif (prev_val == global_var_value) && (next_val < global_var_value)
          if (filter(t -> t[1] == time, init_augmented_positive_times) != []) && (filter(t -> t[1] == time, init_augmented_positive_times)[1][2] != global_var_value)
            new_value = filter(t -> t[1] == time, init_augmented_positive_times)[1][2]
            push!(ranges, ((time, new_value), (time + 1, next_val)))        
          else
            push!(ranges, ((time, prev_val), (time + 1, next_val)))        
          end
          # println("IT'S ME 2")
          # clear state update functions within this range; will find new ones later
          state_update_func = init_state_update_times_dict[global_var_id][time]
          if state_update_func != "" 
            for time in 1:length(init_state_update_times_dict[global_var_id])
              if init_state_update_times_dict[global_var_id][time] == state_update_func
                init_state_update_times_dict[global_var_id][time] = ""
              end
            end
          end
        end
      end
    end
    # println("WHY THO")
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

    init_extra_global_var_values = []

    grouped_ranges = deepcopy(init_grouped_ranges)
    augmented_positive_times = deepcopy(init_augmented_positive_times)
    state_update_times_dict = deepcopy(init_state_update_times_dict)
    
    # println("HERE WE GO")
    # @show update_rule 
    @show augmented_positive_times

    num_transition_decisions = length(init_grouped_ranges)
    transition_decision_strings = sort(vec(collect(Base.product([1:(transition_distinct * transition_same) for i in 1:length(init_grouped_ranges)]...))), by=tup -> sum(collect(tup)))
    transition_decision_strings = transition_decision_strings[1:min(length(transition_decision_strings), transition_threshold)]
  
    no_object_times = findall(x -> x == [""] || occursin("addObj", join(x)), object_trajectory)

    for transition_decision_string in transition_decision_strings 
      transition_decision_index = 1

      # ----- STEP 1: construct input string of which to take prefixes -----  
      sketch_event_trajectory = map(x -> "true", zeros(length(collect(values(small_event_vector_dict))[1])))

      for grouped_range in grouped_ranges 
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
        if (start_value in all_stop_var_values)
          events_in_range = [("(== (prev fake_time) $(time_ranges[1][1]))", [time_ranges[1][1]])]
        elseif (end_value in all_stop_var_values)
          events_in_range = [("(== (prev fake_time) $(time_ranges[1][2]))", [time_ranges[1][2]])]
        else
          events_in_range = find_state_update_events(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, global_var_value, no_object_times, all_stop_var_values)
        end
        events_in_range = filter(tup -> !occursin("field1", tup[1]), events_in_range)
        
        # println("PRE PRUNING: EVENTS IN RANGE")

        @show events_in_range
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
        
        if events_in_range != [] 
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

            if occursin("globalVar", state_update_event)
              state_update_event = split(state_update_event, " (== (prev globalVar")[1][4:end]
              event_times = findall(x -> x == 1, event_vector_dict[state_update_event])
            end
          
            for time in event_times 
              sketch_event_trajectory[time] = state_update_event
            end
          end

        else 
          false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, init_augmented_positive_times, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1, no_object_times, all_stop_var_values)
          false_positive_events_with_state = filter(e -> !occursin("globalVar", e[1]), false_positive_events) # no state-based events in sketch-based approach
          
          events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
          if events_without_true != []
            index = min(length(events_without_true), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            

            false_positive_event, _, true_positive_times, false_positive_times = events_without_true[index] 
            
            for time in vcat(true_positive_times, false_positive_times)
              sketch_event_trajectory[time] = false_positive_event
            end
          end

        end
        transition_decision_index += 1
      end
      
      # TODO: add user events to event string if they do not overlap with existing events from time range analysis 

      # ----- STEP 2: construct positive and negative prefixes 

      distinct_events = sort(unique(sketch_event_trajectory))

      # println("SEE ME")
      @show distinct_events
      @show (length(intersect(["left", "right", "up", "down", "true"], distinct_events)) == 5)
      if length(distinct_events) > 9 
        return solutions
      elseif distinct_events == ["true"] || length(intersect(["left", "right", "up", "down", "true"], distinct_events)) > 1
        for event in ["left", "right", "up", "down", "clicked"]
          if event in keys(event_vector_dict)
            @show event
            event_values = event_vector_dict[event]
            event_times = findall(x -> x == 1, event_values)
            @show event_times
            for time in event_times 
              sketch_event_trajectory[time] = event
            end
          end
        end
      end

      distinct_events = sort(unique(sketch_event_trajectory))

      sketch_event_arr = map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)

      true_char = "0"
      # if "true" in distinct_events 
      #   true_char = string(findall(x -> x == "true", distinct_events)[1])
      # end

      # construct sketch update function input array
      sketch_update_function_arr = ["0" for i in 1:length(sketch_event_trajectory)]
      for tuple in augmented_positive_times 
        time, value = tuple 
        sketch_update_function_arr[time] = string(value)
      end

      @show distinct_events 
      @show sketch_event_arr 
      @show sketch_update_function_arr

      min_states = length(unique(filter(x -> x != "0", sketch_update_function_arr)))
      min_transitions = length(unique(filter(x -> (x[1] != x[2]) && (x[1] != "0") && (x[2] != "0"), collect(zip(sketch_update_function_arr, vcat(sketch_update_function_arr[2:end], -1)))))) - 1
      start = sketch_update_function_arr[1]

      if stop_times != [] 
        stop_times_for_sketch = map(t -> t - 1, stop_times)
        min_stop_val = minimum(all_stop_var_values) 
        desired_out = map(x -> parse(Int, x), sketch_update_function_arr)  
      else
        stop_times_for_sketch = []
        min_stop_val = -1 
        desired_out = []
      end

      solutions = []
      for i in 1:1
        # println("BEGIN HERE")
        @show i
        if stop_times == [] 
          sketch_program = """ 
          include "$(local_sketch_directory)string.skh"; 
          include "$(local_sketch_directory)mstatemachine.skh";
        
          bit recognize([int n], char[n] events, int[n] functions, char true_char, int min_states, int min_transitions, int start){
              return matches(MSM(events, true_char, min_states, min_transitions, start), functions);
          }
        
          harness void h() {
            assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                              { $(join(sketch_update_function_arr, ", ")) }, 
                              '$(true_char)', 
                              $(min_states), 
                              $(min_transitions),
                              $(start));
          }
          """
        else
          sketch_program = """ 
          include "$(local_sketch_directory)string.skh"; 
          include "$(local_sketch_directory)mstatemachine_stops.skh";
        
          bit recognize([int n, int p], char[n] events, int[n] functions, char true_char, int min_states, int min_transitions, int start, int[p] stop_times, int min_stop_val, int[n] desired_out){
            return matches(MSM(events, true_char, min_states, min_transitions, start, stop_times, min_stop_val, desired_out), functions);
          }  
        
          harness void h() {
            assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                              { $(join(sketch_update_function_arr, ", ")) }, 
                              '$(true_char)', 
                              $(min_states), 
                              $(min_transitions),
                              $(start),
                              { $(join(stop_times_for_sketch, ", ")) },
                              $(min_stop_val),
                              { $(join(desired_out, ", ")) });
          }
          """
        end

        ## save sketch program as file 
        open("automata_sketch_$(run_id).sk","w") do io
          println(io, sketch_program)
        end

        first_automaton = true 
        min_state_count = -1 
        curr_state_count = -1
        curr_solution = nothing
        old_state_seqs = []
      
        while first_automaton || ((curr_state_count == min_state_count) && (length(solutions) < 8))
          # println("INSIDE AUTOMATA FINDING ENUMERATIVE LOOP")
          @show length(solutions)
          @show curr_solution
          if !first_automaton 
            # add automaton to solutions list 
            push!(solutions, curr_solution)
      
            # add state_seq to old_state_seqs 
            push!(old_state_seqs, curr_solution[3][global_var_id])
            @show old_state_seqs
      
            # construct new Sketch query
            if stop_times == [] 
              sketch_program = """
              include "$(local_sketch_directory)string.skh"; 
              include "$(local_sketch_directory)mstatemachine.skh";
        
              bit recognize([int n, int m], char[n] events, int[n] functions, int[n][m] old_state_seqs, char true_char, int min_states, int min_transitions, int start) {
                  return matches(MSM_unique(events, old_state_seqs, true_char, min_states, min_transitions, start), functions);
              }
        
              harness void h() {
                assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                                  { $(join(sketch_update_function_arr, ", ")) },
                                  { $(join(map(old_seq -> "{ $(join(old_seq, ", ")) }", old_state_seqs), ", \n")) }, 
                                  '$(true_char)',
                                  $(min_states),
                                  $(min_transitions),
                                  $(start));
              }
              """
  
            else
              sketch_program = """ 
              include "$(local_sketch_directory)string.skh"; 
              include "$(local_sketch_directory)mstatemachine_stops.skh";
            
              bit recognize([int n, int m, int p], char[n] events, int[n] functions, it[n][m] old_state_seqs, char true_char, int min_states, int min_transitions, int start, int[p] stop_times, int min_stop_val, int[n] desired_out){
                return matches(MSM_unique(events, old_state_seqs, true_char, min_states, min_transitions, start, stop_times, min_stop_val, desired_out), functions);
              }  
            
              harness void h() {
                assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                                  { $(join(sketch_update_function_arr, ", ")) },
                                  { $(join(map(old_seq -> "{ $(join(old_seq, ", ")) }", old_state_seqs), ", \n")) }, 
                                  '$(true_char)', 
                                  $(min_states), 
                                  $(min_transitions),
                                  $(start),
                                  { $(join(stop_times_for_sketch, ", ")) },
                                  $(min_stop_val),
                                  { $(join(desired_out, ", ")) });
              }
              """
            end
      
            ## save sketch program as file 
            open("automata_sketch_$(run_id).sk","w") do io
              println(io, sketch_program)
            end
          end
      
          # copy init_global_var_dict and init_extra_global_var_values for each Sketch automaton search 
          global_var_dict = deepcopy(init_global_var_dict)
          extra_global_var_values = deepcopy(init_extra_global_var_values)
      
          # run Sketch query
          if sketch_timeout == 0 
            command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
          else
            if Sys.islinux() 
              command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
            else
              command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_trajectory) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
            end
          end
          
          sketch_output = try 
                            readchomp(eval(Meta.parse("`$(command)`")))
                          catch e
                            ""
                          end

          @show sketch_output
          if sketch_output == "" || occursin("The sketch could not be resolved.", sketch_output)
            break
          else
            # # # println("SKETCH SUCCESS!")
            # update intAsChar and add main function to output cpp file 
            cpp_file_name = "automata_sketch_$(run_id).cpp"
            cpp_out_file_name = "automata_sketch_$(run_id).out"
            f = open(cpp_file_name, "r")
            cpp_content = read(f, String)
            close(f)
      
            if first_automaton 
              modified_cpp_content = string(split(cpp_content, "void intAsChar")[1], """void intAsChar(int x, char& _out) {
                _out = static_cast<char>(x % 10);
                _out = printf("%d", _out);
              }

              void distinct_state_count(int N, int* state_seq/* len = N */, int& _out) {
                int _tt31[10] = {1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000};
                int*  distinct_states= new int [10]; CopyArr<int >(distinct_states,_tt31, 10, 10);
                for (int  i=0;(i) < (N);i = i + 1){
                  int  state=0;
                  state = (state_seq[i]);
                  int  j=0;
                  bool  added=0;
                  while (!(added) && ((j) < (10))) {
                    if ((state) == ((distinct_states[j]))) {
                      added = 1;
                    }
                    if (!(added) && (((distinct_states[j])) == (1000))) {
                      (distinct_states[j]) = state;
                      added = 1;
                    }
                    j = j + 1;
                  }
                }
                if (((distinct_states[9])) != (1000)) {
                  _out = 10;
                delete[] distinct_states;
                  return;
                }
                int  distinct_state_count=0;
                for (int  i_0=0;(i_0) < (10);i_0 = i_0 + 1){
                  if (((distinct_states[i_0])) != (1000)) {
                    distinct_state_count = distinct_state_count + 1;
                  }
                }
                _out = distinct_state_count;
                delete[] distinct_states;
                return;
              }
              
              }
              
              int main() {
                ANONYMOUS::h();
                return 0;
              }
              """)    
            else 
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
                ANONYMOUS::h();
                return 0;
              }
              """)
            end
      
            open(cpp_file_name, "w+") do io
              println(io, modified_cpp_content)
            end
      
            # compile modified cpp program 
            command = "g++ -o $(cpp_out_file_name) $(cpp_file_name)"
            compile_output = readchomp(eval(Meta.parse("`$(command)`"))) 
      
            # run compiled cpp program 
            command = "./$(cpp_out_file_name)"
            run_output = readchomp(eval(Meta.parse("`$(command)`")))  
            run_output = replace(run_output, "\x01" => "")
      
            parts = split(run_output, "STATE TRAJECTORY")
            state_transition_string = parts[1]
            states_and_table_string = parts[2]
      
            parts = split(states_and_table_string, "TABLE")
            states_string = parts[1]
            table_string = parts[2]
      
            # parse state trajectory into init_global_var_dict 
            global_var_values = map(s -> parse(Int, s), filter(x -> x != " ", split(states_string, "\n")))
            global_var_dict[global_var_id] = global_var_values
      
            @show global_var_values
      
            # construct init_extra_global_var_values from table and on_clauses 
            state_to_update_function_index_arr = map(s -> parse(Int, s), filter(x -> x != " ", split(table_string, "\n")))
            distinct_states = unique(global_var_values)
      
            if first_automaton 
              min_state_count = length(distinct_states)
            end
            curr_state_count = length(distinct_states)
      
            update_function_index = 1
            corresponding_states = map(i -> i - 1, findall(x -> x == update_function_index, state_to_update_function_index_arr))
            corresponding_states = intersect(corresponding_states, distinct_states) # don't count extraneous indices from table
            extra_global_var_values = corresponding_states 
            
            on_clause = "(on (& $(co_occurring_event) (in (prev globalVar$(global_var_id)) (list $(join(extra_global_var_values, " ")))))\n$(update_rule))"
      
            # parse state transitions string to construct state_update_on_clauses and state_update_times 
            lines = filter(l -> l != " ", split(state_transition_string, "\n"))
            grouped_transitions = collect(Iterators.partition(lines, 6))
            transitions = []
            for grouped_transition in grouped_transitions 
              start_state = parse(Int, grouped_transition[2])
              transition_label = distinct_events[parse(Int, grouped_transition[4])]
              end_state = parse(Int, grouped_transition[6])
              push!(transitions, (start_state, end_state, transition_label))
            end
      
            state_update_on_clauses = []
            for time in 2:length(global_var_dict[global_var_id])
              prev_value = global_var_dict[global_var_id][time - 1]
              next_value = global_var_dict[global_var_id][time]
      
              if prev_value != next_value 
                transition_tuple = filter(t -> t[1] == prev_value && t[2] == next_value, transitions)[1]
                _, _, transition_label = transition_tuple 
                
                state_update_on_clause = "(on (& $(transition_label) (== (prev globalVar$(global_var_id)) $(prev_value)))\n(= globalVar$(global_var_id) $(next_value)))"
                state_update_times_dict[global_var_id][time - 1] = state_update_on_clause
                push!(state_update_on_clauses, state_update_on_clause)
              end
            end
            curr_solution = (extra_global_var_values, unique(transitions), global_var_dict, co_occurring_event)
          end
          first_automaton = false  
        end
      end
      @show solutions

      # some solution count breaking threshold 
      if length(solutions) >= 8 
        break
      end

    end # end transition decision string loop 

    if length(solutions) >= 8 
      break
    end

  end # end co-occurring event loop
 
  solutions
  # transition_dict = Dict(map(s -> Tuple(map(t -> t[3], s[2])) => s, solutions))
  # map(t -> transition_dict[t], unique(collect(keys(transition_dict))))
end

function format_state_transition_functions(transitions, distinct_states; global_var_id=nothing, type_id=nothing) 
  formatted_transitions = []

  # group transitions by same target and label 
  # transition = (start, target, label)
  transition_and_label_pairs = unique(map(trans -> (trans[2], trans[3]), transitions))
  for transition_and_label in transition_and_label_pairs
    target, label = transition_and_label
    starts = unique(map(t -> t[1], filter(trans -> (trans[2], trans[3]) == transition_and_label, transitions)))
    
    # check if the self-loop transition is also valid 
    other_pairs_with_same_label = filter(tup -> tup[2] == label, transition_and_label_pairs)
    other_pairs_starts = map(t -> t[1], filter(trans -> (trans[2], trans[3]) == transition_and_label, transitions))
    if !(target in other_pairs_starts)
      push!(starts, target)
    end

    if !isnothing(global_var_id) # state variable is global
      
      if length(starts) == length(distinct_states) # from any state, this label causes a transition to the target!
        push!(formatted_transitions, "(on $(label)\n(= globalVar$(global_var_id) $(target)))")
      else 
        push!(formatted_transitions, "(on (& $(label) (in (prev globalVar$(global_var_id)) (list $(join(filter(s -> s != target, starts), " ")))))\n(= globalVar$(global_var_id) $(target)))")
      end

    else # state variable is object-specific
      
      if length(starts) == length(distinct_states) # from any state, this label causes a transition to the target!
        push!(formatted_transitions, """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(target))) (--> obj $(label)))))""")
      else 
        push!(formatted_transitions, """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(target))) (--> obj (& $(label) (in (.. (prev obj) field1) (list $(join(filter(s -> s != target, starts), " ")))))))))""")
      end

    end
  end
  formatted_transitions
end

function compute_all_products(state_solutions; global_aut=true, generalized=false)
  update_functions = sort(collect(keys(state_solutions)), by=x -> x isa Tuple ? length(x) : x)
  product_automata = [] 
  for update_function_index in 1:length(update_functions)
    @show update_function_index
    update_function = update_functions[update_function_index]     
    component_automata_full = state_solutions[update_function]
    
    # (states, transitions, start state, accept states, co_occurring_event)
    if !generalized 
      if global_aut 
        component_automata = map(a -> (unique(a[3][1]), a[2], a[3][1][1], a[1], a[4]), component_automata_full)
      else # start state is represented differently in object-specific case: list of start states for each object_id in order
        # [(unique(accept_values), object_field_values, transitions, co_occurring_event)]
        component_automata = map(a -> (unique(vcat(collect(values(a[2]))...)), a[3], map(id -> a[2][id][1], sort(collect(keys(a[2])))), a[1], a[4]), component_automata_full)
      end
    else 
      if global_aut 
        component_automata = map(x -> (unique(x[1]), x[2], x[3], x[4], x[5]), component_automata_full)  
      else 
        component_automata = map(x -> (unique(vcat(collect(values(x[1]))...)), x[2], x[3], x[4], x[5]), component_automata_full)  
      end
    end
    if product_automata == []
      product_automata = component_automata 
    else # take product between product_automata list and component_automata list 
      new_product_automata = []
      for old_product_automaton in product_automata 
        for component_automaton in component_automata 
          prod = automata_product2(old_product_automaton, component_automaton, global_aut=global_aut)
          push!(new_product_automata, prod)
        end 
      end
      product_automata = new_product_automata
    end
  end
  product_automata
end

"""Input: list of product automata, each in the form (states (list of Int), transitions (list of Int-tuples))"""
function optimal_automaton(product_automata) 
  # Algorithm: Construct Autumn description of each automaton, and take the shortest string 
  automata_string_dict = Dict()
  for automaton in product_automata 
    states, transitions, _, _, _ = automaton 
    grouped_transitions_dict = Dict()
    for trans in transitions 
      start, target, label = trans 
      if (target, label) in keys(grouped_transitions_dict)
        push!(grouped_transitions_dict[(target, label)], start)
      else
        grouped_transitions_dict[(target, label)] = [start]
      end
    end
    automaton_string = join(map(x -> "(on (& $(x[2]) (! (in (prev globalVar1) (list $(join(filter(y -> !(y in grouped_transitions_dict[x]), states), " "))))))\n(= globalVar1 $(x[1])))", collect(keys(grouped_transitions_dict))), "\n")
    automata_string_dict[automaton] = automaton_string
  end

  shortest_string = sort(collect(values(automata_string_dict)), by=length)[1]
  best_automaton = filter(k -> length(automata_string_dict[k]) == length(shortest_string), collect(keys(automata_string_dict)))[1]
end

function automata_product(aut1, aut2; global_aut::Bool=true)
  state_seq1, transitions1, start_state1, accept_states1, co_occurring_event1 = aut1
  state_seq2, transitions2, start_state2, accept_states2, co_occurring_event2 = aut2

  distinct_states1 = unique(state_seq1)
  distinct_states2 = unique(state_seq2)

  unlabeled_transitions1 = map(tup -> (tup[1], tup[2]), transitions1)
  unlabeled_transitions2 = map(tup -> (tup[1], tup[2]), transitions2)

  product_states = [(s1, s2) for s1 in distinct_states1 for s2 in distinct_states2]
  product_transitions = [] 
  for product_state_1 in product_states 
    for product_state_2 in product_states 
      if product_state_1 != product_state_2 

        start_1, start_2 = product_state_1 
        target_1, target_2 = product_state_2 

        unlabeled_transition1 = (start_1, target_1)
        unlabeled_transition2 = (start_2, target_2)

        @show product_state_1 
        @show product_state_2
        @show unlabeled_transition1 
        @show unlabeled_transition2

        if length(unique(unlabeled_transition1)) == 1 # self-loop in 1st automaton in product
          matching_transitions = filter(tup -> (tup[1], tup[2]) == unlabeled_transition2, transitions2)
          if matching_transitions != [] 
            for matching_transition in matching_transitions 
              _, _, label2 = matching_transition

              # check that aut1 does not change state on event `label2` when in state unlabeled_transition1[1]
              unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (unlabeled_transition1[1], label2), transitions1)
              if unwanted_transitions == [] 
                push!(product_transitions, (product_state_1, product_state_2, label2))
              end
            end
          end

        elseif length(unique(unlabeled_transition2)) == 1 # self-loop in 2nd automaton in product
          matching_transitions = filter(tup -> (tup[1], tup[2]) == unlabeled_transition1, transitions1)
          if matching_transitions != [] 
            for matching_transition in matching_transitions 
              _, _, label1 = matching_transition

              # check that aut2 does not change state on event `label1` when in state unlabeled_transition2[1]
              unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (unlabeled_transition2[1], label1), transitions2)
              if unwanted_transitions == [] 
                push!(product_transitions, (product_state_1, product_state_2, label1))
              end
            end
          end

        elseif (unlabeled_transition1 in unlabeled_transitions1) && (unlabeled_transition2 in unlabeled_transitions2)
          matching_transitions1 = filter(tup -> (tup[1], tup[2]) == unlabeled_transition1, transitions1)
          matching_transitions2 = filter(tup -> (tup[1], tup[2]) == unlabeled_transition2, transitions2)
          if matching_transitions1 != [] && matching_transitions2 != [] 
            for matching_transition1 in matching_transitions1 
              for matching_transition2 in matching_transitions2 

                _, _, label1 = matching_transition1
                _, _, label2 = matching_transition2
    
                if label1 == label2 
                  push!(product_transitions, (product_state_1, product_state_2, label1))
                end

              end
            end

          end
        end
      end
    end
  end

  # remove all unreachable states 
  # equivalent to computing largest connected component starting from start state: perform BFS 
  visited_states = []
  @show global_aut
  if global_aut 
    queue = Queue{Any}()
    enqueue!(queue, (start_state1, start_state2))
    while !isempty(queue)
      prod_state = dequeue!(queue)
      push!(visited_states, prod_state)
      # neighbors == target states of transitions emitting from prod_state
      neighbors_ = map(t -> t[2], filter(trans -> trans[1] == prod_state, product_transitions))
      # @show prod_state
      # @show neighbors_ 
      # @show visited_states
      for n in neighbors_
        if !(n in visited_states) 
          enqueue!(queue, n)
        end
      end
    end
  else # object-specific case
    for id_index in 1:length(start_state1)
      @show id_index
      object_specific_visited_states = []
      local queue = Queue{Any}()
      enqueue!(queue, (start_state1[id_index], start_state2[id_index]))
      while !isempty(queue)
        prod_state = dequeue!(queue)
        push!(object_specific_visited_states, prod_state)
        # neighbors == target states of transitions emitting from prod_state
        neighbors_ = map(t -> t[2], filter(trans -> trans[1] == prod_state, product_transitions))
        # @show prod_state 
        # @show neighbors_
        # @show visited_states
        for n in neighbors_
          if !(n in object_specific_visited_states) 
            enqueue!(queue, n)
          end
        end
      end
      push!(visited_states, object_specific_visited_states...)
    end
  end

  final_states = unique(visited_states) 
  final_transitions = filter(trans -> (trans[1] in visited_states) && (trans[2] in visited_states), product_transitions)
  final_start_state = global_aut ? (start_state1, start_state2) : Tuple(collect(zip(start_state1, start_state2)))
  final_accept_states = accept_states1 isa Tuple ? (accept_states1..., accept_states2) : (accept_states1, accept_states2)
  final_co_occurring_events = co_occurring_event1 isa Tuple ? (co_occurring_event1..., co_occurring_event2) : (co_occurring_event1, co_occurring_event2)

  # reformat: convert nested tuple structure to flattened tuple 
  final_states = map(s -> Tuple(collect(Iterators.flatten(s))), final_states)
  final_transitions = map(trans -> (Tuple(collect(Iterators.flatten(trans[1]))), Tuple(collect(Iterators.flatten(trans[2]))), trans[3]), final_transitions)
  final_start_state = global_aut ? Tuple(collect(Iterators.flatten(final_start_state))) : map(tup -> Tuple(collect(Iterators.flatten(tup))), final_start_state)

  (final_states, final_transitions, final_start_state, final_accept_states, final_co_occurring_events)
end

function automata_product2(aut1, aut2; global_aut::Bool=true)
  state_seq1, transitions1, start_state1, accept_states1, co_occurring_event1 = aut1
  state_seq2, transitions2, start_state2, accept_states2, co_occurring_event2 = aut2

  distinct_states1 = unique(state_seq1)
  distinct_states2 = unique(state_seq2)

  unlabeled_transitions1 = map(tup -> (tup[1], tup[2]), transitions1)
  unlabeled_transitions2 = map(tup -> (tup[1], tup[2]), transitions2)

  product_states = Set()
  product_transitions = Set()
  if global_aut 
    queue = Queue{Any}()
    enqueue!(queue, (start_state1, start_state2))
    while !isempty(queue)
      prod_state = dequeue!(queue)
      prod_1, prod_2 = prod_state
      push!(product_states, prod_state)
      # neighbors == target states of transitions emitting from prod_state
      neighbors_and_transitions = []
      trans_1 = filter(trans -> trans[1] == prod_1, transitions1)
      trans_2 = filter(trans -> trans[1] == prod_2, transitions2)
      
      for t1 in trans_1 
        t1_start, t1_end, t1_label = t1
        
        # try adding destination states where second state in product doesn't change 
        unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (prod_2, t1_label), transitions2)
        if unwanted_transitions == [] 
          destination_state = (t1_end, prod_2)
          push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t1_label)))
        end
      end

      for t2 in trans_2 
        t2_start, t2_end, t2_label = t2 

        # try adding destination states where first state in product doesn't change 
        unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (prod_1, t2_label), transitions1)
        if unwanted_transitions == [] 
          destination_state = (prod_1, t2_end)
          push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t2_label)))
        end
      end

      for t1 in trans_1 
        for t2 in trans_2 
          t1_start, t1_end, t1_label = t1
          t2_start, t2_end, t2_label = t2 

          if t1_label == t2_label 
            destination_state = (t1_end, t2_end)
            push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t1_label)))
          end

        end
      end

      for nt in neighbors_and_transitions
        neighbor, transition = nt
        push!(product_transitions, transition) 
        if !(neighbor in product_states) 
          enqueue!(queue, neighbor)
        end
      end
    end
  else 
    for id_index in 1:length(start_state1)
      @show id_index
      object_specific_visited_states = Set()
      local queue = Queue{Any}()
      enqueue!(queue, (start_state1[id_index], start_state2[id_index]))
      while !isempty(queue)
        prod_state = dequeue!(queue)
        prod_1, prod_2 = prod_state
        push!(object_specific_visited_states, prod_state)
        # neighbors == target states of transitions emitting from prod_state
        neighbors_and_transitions = []
        trans_1 = filter(trans -> trans[1] == prod_1, transitions1)
        trans_2 = filter(trans -> trans[1] == prod_2, transitions2)
        
        for t1 in trans_1 
          t1_start, t1_end, t1_label = t1
          
          # try adding destination states where second state in product doesn't change 
          unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (prod_2, t1_label), transitions2)
          if unwanted_transitions == [] 
            destination_state = (t1_end, prod_2)
            push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t1_label)))
          end
        end
  
        for t2 in trans_2 
          t2_start, t2_end, t2_label = t2 
  
          # try adding destination states where first state in product doesn't change 
          unwanted_transitions = filter(tup -> (tup[1], tup[3]) == (prod_1, t2_label), transitions1)
          if unwanted_transitions == [] 
            destination_state = (prod_1, t2_end)
            push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t2_label)))
          end
        end
  
        for t1 in trans_1 
          for t2 in trans_2 
            t1_start, t1_end, t1_label = t1
            t2_start, t2_end, t2_label = t2 
  
            if t1_label == t2_label 
              destination_state = (t1_end, t2_end)
              push!(neighbors_and_transitions, (destination_state, (prod_state, destination_state, t1_label)))
            end
  
          end
        end
  
        for nt in neighbors_and_transitions
          neighbor, transition = nt
          push!(product_transitions, transition) 
          if !(neighbor in object_specific_visited_states) 
            enqueue!(queue, neighbor)
          end
        end
      end
  
      push!(product_states, object_specific_visited_states...)
    end
  end

  final_states = collect(product_states) 
  final_transitions = collect(product_transitions)
  final_start_state = global_aut ? (start_state1, start_state2) : Tuple(collect(zip(start_state1, start_state2)))
  final_accept_states = accept_states1 isa Tuple ? (accept_states1..., accept_states2) : (accept_states1, accept_states2)
  final_co_occurring_events = co_occurring_event1 isa Tuple ? (co_occurring_event1..., co_occurring_event2) : (co_occurring_event1, co_occurring_event2)

  # reformat: convert nested tuple structure to flattened tuple 
  final_states = map(s -> Tuple(collect(Iterators.flatten(s))), final_states)
  final_transitions = map(trans -> (Tuple(collect(Iterators.flatten(trans[1]))), Tuple(collect(Iterators.flatten(trans[2]))), trans[3]), final_transitions)
  final_start_state = global_aut ? Tuple(collect(Iterators.flatten(final_start_state))) : map(tup -> Tuple(collect(Iterators.flatten(tup))), final_start_state)

  (final_states, final_transitions, final_start_state, final_accept_states, final_co_occurring_events)
end



function generalize_all_automata(state_solutions, user_events, event_vector_dict; global_aut=true)
  @show global_aut
  update_functions = sort(collect(keys(state_solutions)), by= x -> x isa Tuple ? length(x) : x)
  new_state_solutions = Dict()
  for update_function in update_functions 
    component_automata_full = state_solutions[update_function]

    # (states, transitions, start state, accept states, co_occurring_event)
    # NOTE: passing in state *sequence* instead of set of distinct states as first tuple element; this differs from product-taking, 
    # where the first tuple element is the distinct state set
    if global_aut 
      component_automata = map(a -> (a[3][1], a[2], a[3][1][1], a[1], a[4]), component_automata_full)
    else # start state is represented differently in object-specific case: list of start states for each object_id in order
      # a format: 
      # [(unique(accept_values), object_field_values, transitions, co_occurring_event)]
      component_automata = map(a -> (a[2], a[3], map(id -> a[2][id][1], sort(collect(keys(a[2])))), a[1], a[4]), component_automata_full)
    end

    if update_function isa String # single-automaton case: compute all labels from other single update function automata with same co-occurring event
      if global_aut 
        all_labels = unique(vcat(map(x -> map(trans -> trans[3], x[2]), filter(s -> s[end] in map(z -> z[end], component_automata), vcat(collect(values(state_solutions))...)))...))
      else
        all_labels = unique(vcat(map(x -> map(trans -> trans[3], x[3]), filter(s -> s[end] in map(z -> z[end], component_automata), vcat(collect(values(state_solutions))...)))...))
      end
    else # multi-automaton case: compute all labels from other automata with ths same co-occurring event/type id pair
      all_labels = vcat(map(a -> map(x -> x[3], a[2]), component_automata)...)
    end

    new_state_solutions[update_function] = map(aut -> generalize_automaton(aut, user_events, event_vector_dict, all_labels), component_automata)
  end
  new_state_solutions
end

function generalize_automaton(aut, user_events, event_vector_dict, all_labels) 
  state_seq, transitions, start_state, accept_states, co_occurring_event = aut
  is_global = state_seq isa AbstractArray 

  @show state_seq 
  @show transitions 
  @show start_state 
  @show accept_states 
  @show co_occurring_event 
  @show is_global

  distinct_states = is_global ? unique(state_seq) : unique(vcat(collect(values(state_seq))...))

  # construct dictionary mapping (target, label) to list of start states  
  # transitions = (start, target, label)
  target_and_label_to_starts = Dict()
  target_and_label_list = unique(map(trans -> (trans[2], trans[3]), transitions))
  for target_and_label in target_and_label_list 
    target_and_label_to_starts[target_and_label] = map(t -> t[1], filter(trans -> (trans[2], trans[3]) == target_and_label, transitions))
  end
  
  # add observed self-loops
  for label in all_labels 
    if label in keys(event_vector_dict)
      event_values = event_vector_dict[label]
    else # label was made global from originally object-specific event by specifying object_id
      @show label
      @show collect(keys(event_vector_dict))
      object_id = parse(Int, split(split(label, "(== (.. obj id) ")[2], ")")[1])
      anonymized_label = replace(label, " $(object_id)" => " x")
      event_values = event_vector_dict[anonymized_label][object_id]
    end

    if event_values isa AbstractArray
      event_times = filter(t -> t < length(state_seq), findall(x -> x == 1, event_values)) 
      if is_global 
        state_seq_tuples = unique(map(t -> (state_seq[t], state_seq[t + 1]), event_times))
      else 
        state_seq_tuples = unique((vcat(map(id -> map(t -> (state_seq[id][t], state_seq[id][t + 1]), event_times), collect(keys(state_seq)))...)))
      end
      self_loop_states = unique(map(x -> x[1], filter(tup -> tup[1] == tup[2], state_seq_tuples)))
    else # event is object-specific; state is necessarily object-specific   
      event_times_dict = Dict(map(id -> id => filter(t -> t < length(state_seq), findall(x -> x == 1, event_values[id])), collect(keys(event_values))))
      
      @show state_seq
      @show event_values 
      @show event_times_dict
      state_seq_tuples = unique(vcat(map(id -> map(t -> (state_seq[id][t], state_seq[id][t + 1]), event_times_dict[id]), collect(keys(state_seq)))...))
      self_loop_states = unique(map(x -> x[1], filter(tup -> tup[1] == tup[2], state_seq_tuples)))
    end

    for self_loop_state in self_loop_states 
      if (self_loop_state, label) in keys(target_and_label_to_starts)
        push!(target_and_label_to_starts[(self_loop_state, label)], self_loop_state)
      else
        target_and_label_to_starts[(self_loop_state, label)] = [self_loop_state]
      end
    end

  end

  labels = unique(map(trans -> trans[3], transitions))  
  # if key presses form some of the transition labels, consider the effects of other key presses involved in self-loops
  key_presses = ["left", "right", "up", "down"]
  if !(length(intersect(labels, key_presses)) in [0, 4])
    other_key_presses = filter(k -> !(k in labels), key_presses)
    for other_press in other_key_presses 
      if other_press in user_events 
        times = findall(e -> e == other_press, user_events)
         
        self_loop_states = is_global ? unique(map(t -> state_seq[t], times)) : unique(vcat(map(id -> map(t -> state_seq[id][t], times), collect(keys(state_seq)))...))
        for self_loop_state in self_loop_states 
          target_and_label_to_starts[(self_loop_state, other_press)] = [self_loop_state]
        end
        
      end
    end
  end

  # construct set of possible new start states for each target/label pair 
  target_and_label_to_starts_POSSIBLE = Dict()
  for target_and_label in collect(keys(target_and_label_to_starts))
    target, label = target_and_label
    observed_starts = target_and_label_to_starts[target_and_label]
    possible_other_starts = filter(s -> !(s in observed_starts), distinct_states)

    other_tuples_with_same_label = filter(t -> (t != target_and_label) && (t[2] == label), collect(keys(target_and_label_to_starts)))
    for start in possible_other_starts 
      if !(start in vcat(map(x -> target_and_label_to_starts[x], other_tuples_with_same_label)...))
        if target_and_label in keys(target_and_label_to_starts_POSSIBLE)
          push!(target_and_label_to_starts_POSSIBLE[target_and_label], start)
        else  
          target_and_label_to_starts_POSSIBLE[target_and_label] = [start]
        end
      end
    end
  end 

  # eliminate possible new start states with conflicts 
  target_and_label_to_starts_NEW = Dict()
  for target_and_label in keys(target_and_label_to_starts_POSSIBLE)
    target, label = target_and_label
    possible_starts = target_and_label_to_starts_POSSIBLE[target_and_label]
    conflict_tuples = filter(tup -> (tup[2] == label) && (tup != target_and_label), collect(keys(target_and_label_to_starts_POSSIBLE)))
    conflict_starts = unique(vcat(map(tup -> target_and_label_to_starts_POSSIBLE[tup], conflict_tuples)...))
    for start in possible_starts 
      if !(start in conflict_starts)
        if target_and_label in keys(target_and_label_to_starts_NEW)
          push!(target_and_label_to_starts_NEW[target_and_label], start)
        else
          target_and_label_to_starts_NEW[target_and_label] = [start]
        end
      end
    end
  end

  # construct new transitions 
  new_transitions = []
  for target_and_label in collect(keys(target_and_label_to_starts_NEW))
    target, label = target_and_label

    # filter out self-loops (start is same as target)
    target_and_label_to_starts_NEW[target_and_label] = filter(s -> s != target, target_and_label_to_starts_NEW[target_and_label])
    push!(new_transitions, map(start -> (start, target, label), target_and_label_to_starts_NEW[target_and_label])...)
  end
  final_transitions = vcat(transitions..., new_transitions...)

  state_seq, final_transitions, start_state, accept_states, co_occurring_event
end

function generate_object_specific_automaton_sketch(run_id, update_rule, update_function_times_dict, event_vector_dict, type_id, filtered_matrix, object_decomposition, init_state_update_times, global_var_dict, type_displacements, interval_offsets, source_exists_events_dict, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, sketch_timeout, co_occurring_param=false, co_occurring_distinct=1, co_occurring_same=1, co_occurring_threshold=1, transition_distinct=1, transition_same=1, transition_threshold=1; stop_times=[])
  println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  @show update_rule
  @show update_function_times_dict
  @show event_vector_dict
  @show type_id 
  @show object_decomposition
  @show init_state_update_times
  state_update_times = deepcopy(init_state_update_times)  
  failed = false
  object_types, object_mapping, background, grid_size = object_decomposition 
  object_ids = sort(collect(keys(update_function_times_dict)))
  @show object_ids

  @show run_id
  @show update_rule
  @show update_function_times_dict
  @show event_vector_dict
  @show type_id
  @show filtered_matrix
  @show object_decomposition
  @show init_state_update_times 
  @show global_var_dict
  @show type_displacements
  @show interval_offsets
  @show source_exists_events_dict
  @show addObj_based_list
  @show double_removeObj_update_functions
  @show linked_removeObj_update_functions
  @show sketch_timeout
  @show co_occurring_param
  @show co_occurring_distinct 
  @show co_occurring_same 
  @show co_occurring_threshold
  @show transition_distinct
  @show transition_same
  @show transition_threshold
  @show stop_times

  object_types, object_mapping, _, _ = object_decomposition

  start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
  non_list_object_ids = map(obj -> obj.id, non_list_objects)

  # ----- START: construct small_event_vector_dict
  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id, ["nothing"], global_var_dict, update_rule, type_displacements, interval_offsets, source_exists_events_dict)

  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if occursin("adj", e) || !(e in atomic_events) && e != "true" # && foldl(|, map(x -> occursin(x, e), atomic_events))
      delete!(small_event_vector_dict, e)
    else
      object_specific_event_with_wrong_type = !(event_vector_dict[e] isa AbstractArray) && (Set(collect(keys(event_vector_dict[e]))) != Set(object_ids))
      if object_specific_event_with_wrong_type 
        delete!(small_event_vector_dict, e)
      end
    end
  end

  displacement_dict = Dict(map(id -> id => [displacement(object_mapping[id][t].position, object_mapping[id][t + 1].position) 
                                            for t in 1:length(user_events) 
                                            if !isnothing(object_mapping[id][t]) && !isnothing(object_mapping[id][t + 1])], 
                               object_ids)) 
  
  all_displacements = vcat(collect(values(displacement_dict))...)
  unique_displacements = reverse(sort(unique(all_displacements), by=tup -> count(x -> x == tup, all_displacements)))
  extra_transition_substrings = []
  for disp in unique_displacements[1:min(2, length(unique_displacements))]
    x, y = disp 
    push!(extra_transition_substrings, "$(x) $(y)")
    if x != 0 
      push!(extra_transition_substrings, ["$(2*x) $(y)", "$(-2*x) $(y)", "$(-1*x) $(y)"]...)
    end

    if y != 0 
      push!(extra_transition_substrings, ["$(x) $(2*y)", "$(x) $(-2*y)", "$(x) $(-1*y)"]...)
    end
  end
  unique!(extra_transition_substrings)

  for e in keys(event_vector_dict)
    if !(e in ["true", "left", "right", "up", "down"] || foldl(|, map(id -> occursin("(move (prev obj$(id)", e), non_list_object_ids), init=false) || foldl(|, map(str -> occursin(str, e), extra_transition_substrings), init=false) )
      delete!(small_event_vector_dict, e)
    end
  end

  start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
  non_list_object_ids = map(obj -> obj.id, non_list_objects)
  
  # ----- END: construct small_event_vector_dict

  @show small_event_vector_dict

  # initialize state_update_times
  if length(collect(keys(state_update_times))) == 0 || length(intersect(collect(keys(update_function_times_dict)), collect(keys(state_update_times)))) == 0
    for id in collect(keys(update_function_times_dict)) 
      state_update_times[id] = [("", -1) for i in 1:(length(object_mapping[object_ids[1]])-1)]
    end
    curr_state_value = 1
  else
    # check if update function times occur during a single field1 value 
    curr_state_value = maximum(vcat(map(id -> map(x -> x.custom_field_values[end], filter(y -> !isnothing(y), object_mapping[id])), object_ids)...)) # maximum(vcat(map(id -> map(x -> x[2], state_update_times[id]), object_ids)...)) 

    unique_state_values = unique(vcat(map(id -> map(t -> object_mapping[id][t].custom_field_values[end], update_function_times_dict[id]), object_ids)...))
    if unique_state_values != [curr_state_value]
      return []  
    end
  end

  # compute co-occurring event 
  # events = filter(k -> event_vector_dict[k] isa Array, collect(keys(event_vector_dict))) 
  events =  collect(keys(event_vector_dict)) # ["left", "right", "up", "down"]
  co_occurring_events = []
  for event in events
    @show event 
    if global_event_vector_dict[event] isa AbstractArray
      if occursin("addObj", update_rule)
        addObj_times = unique(vcat(collect(values(update_function_times_dict))...))

        event_vector = global_event_vector_dict[event]
        co_occurring = is_co_occurring(event, event_vector, addObj_times)   

        if co_occurring
          false_positive_count = num_false_positives(event_vector, addObj_times, [1 for i in 1:length(object_mapping[1])], addObj=true)
          push!(co_occurring_events, (event, false_positive_count))
        end

      else
        event_vector = global_event_vector_dict[event]
        co_occurring = foldl(&, map(update_function_times -> is_co_occurring(event, event_vector, update_function_times), collect(values(update_function_times_dict))), init=true)      
      
        if co_occurring
          false_positive_count = foldl(+, map(k -> num_false_positives(event_vector, update_function_times_dict[k], object_mapping[k]), collect(keys(update_function_times_dict))), init=0)
          push!(co_occurring_events, (event, false_positive_count))
        end
      end

    elseif (Set(collect(keys(global_event_vector_dict[event]))) == Set(collect(keys(update_function_times_dict))))
      if !occursin("addObj", update_rule) # disallowing object-specific events to cause object additions 

        event_vector = global_event_vector_dict[event]
        co_occurring = foldl(&, map(id -> is_co_occurring(event, event_vector[id], update_function_times_dict[id]), collect(keys(update_function_times_dict))), init=true)
        
        if co_occurring
          false_positive_count = foldl(+, map(id -> num_false_positives(event_vector[id], update_function_times_dict[id], object_mapping[id]), collect(keys(update_function_times_dict))), init=0)
          push!(co_occurring_events, (event, false_positive_count))
        end
      
      end

    end
  end
  # co_occurring_events = sort(filter(x -> !occursin("|", x[1]), co_occurring_events), by=x -> x[2]) # [1][1]
  if co_occurring_param 
    co_occurring_events = sort(filter(x -> !occursin("(list)", x[1]) && !occursin("(move ", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("adj", x[1]) && !occursin("pushConfiguration", x[1]) && (!occursin("intersects (list", x[1]) || occursin("(.. obj id) x", x[1])) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))") && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
  else
    co_occurring_events = sort(filter(x -> !occursin("(filter (--> obj (.. obj alive))", x[1]) && (!occursin("(list)", x[1]) || occursin("distance", x[1]) || occursin("addObj", update_rule)) && !occursin("adj ", x[1]) && !occursin("pushConfiguration", x[1]) && !occursin("|", x[1]) && !occursin("(== (prev addedObjType", x[1]) && !occursin("objClicked", x[1]) && !occursin("intersects (list", x[1]) && (!occursin("&", x[1]) || x[1] == "(& clicked (isFree click))")  && !(occursin("(! (in (objClicked click (prev addedObjType3List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType3List))))", x[1])), co_occurring_events), by=x -> x[2]) # [1][1]
  end

  # co_occurring_events = sort(co_occurring_events, by=x -> x[2]) # [1][1]
  if filter(x -> !occursin("globalVar", x[1]), co_occurring_events) != []
    co_occurring_events = filter(x -> !occursin("globalVar", x[1]), co_occurring_events)
  end

  specially_handled_on_clauses = special_addObj_removeObj_handling(update_rule, filtered_matrix, co_occurring_events, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, source_exists_events_dict, object_decomposition)
  if specially_handled_on_clauses != []
    return vcat("special", specially_handled_on_clauses...)
  end

  false_positive_counts = sort(unique(map(x -> x[2], co_occurring_events)))
  false_positive_counts = false_positive_counts[1:min(length(false_positive_counts), co_occurring_distinct)]
  optimal_co_occurring_events = []
  for false_positive_count in false_positive_counts 
    events_with_count = map(e -> e[1], sort(filter(tup -> tup[2] == false_positive_count, co_occurring_events), by=t -> length(t[1])))
    push!(optimal_co_occurring_events, events_with_count[1:min(length(events_with_count), co_occurring_same)]...)
  end

  optimal_co_occurring_events = optimal_co_occurring_events[1:min(length(optimal_co_occurring_events), co_occurring_threshold)]

  # best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
  # # # @show best_co_occurring_events
  # co_occurring_event = best_co_occurring_events[1][1]
  # co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  solutions = []
  for co_occurring_event in optimal_co_occurring_events
    co_occurring_event_trajectory = event_vector_dict[co_occurring_event]
    @show co_occurring_event 
    @show co_occurring_event_trajectory

    max_v = -1
    augmented_positive_times_dict = Dict()
    for object_id in object_ids
      true_positive_times = update_function_times_dict[object_id] # times when co_occurring_event happened and update_rule happened 
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
  
      # construct positive times list augmented by true/false value 
      augmented_true_positive_times = map(t -> (t, curr_state_value), true_positive_times)
      augmented_false_positive_times = map(t -> (t, curr_state_value + 1), false_positive_times)
      augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])  
  
      max_v = maximum(vcat(map(tup -> tup[2], augmented_positive_times)..., max_v))
      augmented_positive_times_dict[object_id] = augmented_positive_times 
    end

    augmented_stop_times = []
    all_stop_var_values = []
    for object_id in object_ids 
      augmented_positive_times = augmented_positive_times_dict[object_id]
      stop_var_value = max_v + 1
      all_stop_var_values = []
      for stop_time in stop_times
        if !isnothing(object_mapping[object_id][stop_time]) && !isnothing(object_mapping[object_id][stop_time + 1])
          push!(augmented_stop_times, (stop_time, stop_var_value))
          push!(all_stop_var_values, stop_var_value)
        end
        stop_var_value += 1
      end
      augmented_positive_times = sort(vcat(augmented_positive_times..., augmented_stop_times), by=x -> x[1])
      augmented_positive_times_dict[object_id] = augmented_positive_times
    end
    unique!(all_stop_var_values)
  
    @show augmented_positive_times_dict


    # compute ranges 
    init_grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, curr_state_value, object_mapping, object_ids)
    
    num_transition_decisions = length(init_grouped_ranges)
    transition_decision_strings = sort(vec(collect(Base.product([1:(transition_distinct * transition_same) for i in 1:length(init_grouped_ranges)]...))), by=tup -> sum(collect(tup)))
    transition_decision_strings = transition_decision_strings[1:min(length(transition_decision_strings), transition_threshold)]



    for transition_decision_string in transition_decision_strings
      transition_decision_index = 1
      grouped_ranges = deepcopy(init_grouped_ranges)
      max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...))  
      sketch_event_arrs_dict = Dict(map(id -> id => ["true" for i in 1:length(object_mapping[object_ids[1]])], object_ids))
    
      @show grouped_ranges

      while length(grouped_ranges) > 0
        grouped_range = grouped_ranges[1]
        grouped_ranges = grouped_ranges[2:end]
    
        @show grouped_range

        range = grouped_range[1]
        start_value = range[1][2]
        end_value = range[2][2]
    
        max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...))
    
        # TODO: try global events too  
        events_in_range = []
        if events_in_range == [] # if no global events are found, try object-specific events 
          # events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_value)
          if (start_value in all_stop_var_values)
            events_in_range = [("(== (prev fake_time) $(time_ranges[1][1] - 1))", [(time_ranges[1][1], id) for id in object_ids])]
          elseif (end_value in all_stop_var_values)
            events_in_range = [("(== (prev fake_time) $(time_ranges[1][2]))", [(time_ranges[1][2], id) for id in object_ids])]
          else
            events_in_range = find_state_update_events_object_specific(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value, all_stop_var_values)
          end
        end
        @show events_in_range
        events_in_range = filter(e -> !occursin("globalVar1", e[1]), events_in_range)
        if length(events_in_range) > 0 # only handling perfect matches currently 

          if filter(x -> !occursin("field1", x[1]), events_in_range) != []
            events_in_range = filter(x -> !occursin("field1", x[1]), events_in_range)
          end
  
          index = min(length(events_in_range), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])
          event, event_times = events_in_range[index]

          if occursin("(intersects (list $(start_value)) (map (--> obj (.. obj field1)", event)
            event = split(event, " (intersects (list $(start_value)) (map (--> obj (.. obj field1)")[1][4:end]
            event_times = vcat(map(id -> map(t -> (t, id), findall(x -> x == 1, event_vector_dict[event][id])),  object_ids)...)
          end
  
          for id in object_ids # collect(keys(state_update_times))
            object_event_times = map(t -> t[1], filter(time -> time[2] == id, event_times))
            for time in object_event_times
              sketch_event_arrs_dict[id][time] = event
            end
          end
          
        else
          false_positive_events = find_state_update_events_object_specific_false_positives(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value, all_stop_var_values)      
          false_positive_events_with_state = filter(e -> !occursin("field1", e[1]) && !occursin("globalVar1", e[1]), false_positive_events)
          @show false_positive_events
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
    
      @show sketch_event_arrs_dict

      distinct_events = sort(unique(vcat(collect(values(sketch_event_arrs_dict))...)))  
      
      if length(distinct_events) > 9 
        return solutions
      end

      @show distinct_events
    
      sketch_event_arrs_dict_formatted = Dict(map(id -> id => map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_arrs_dict[id]) , collect(keys(sketch_event_arrs_dict)))) # map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)
      
      true_char = "0"
      # if "true" in distinct_events 
      #   true_char = string(findall(x -> x == "true", distinct_events)[1])
      # end
    
      # construct sketch update function input array
      sketch_update_function_arr = Dict(map(id -> id => ["0" for i in 1:length(sketch_event_arrs_dict_formatted[object_ids[1]])], object_ids))
      for id in object_ids 
        augmented_positive_times = augmented_positive_times_dict[id]
        for tuple in augmented_positive_times 
          time, value = tuple 
          sketch_update_function_arr[id][time] = string(value)
        end
      end
    
      @show sketch_update_function_arr

      min_states_dict = Dict(map(id -> id => length(unique(filter(x -> x != "0", sketch_update_function_arr[id]))), object_ids))
      min_transitions_dict = Dict(map(id -> id => length(unique(filter(x -> (x[1] != x[2]) && (x[1] != "0") && (x[2] != "0"), collect(zip(sketch_update_function_arr[id], vcat(sketch_update_function_arr[id][2:end], -1)))))) - 1, object_ids))
      start_state_dict = Dict(map(id -> id => vcat(filter(x -> x != "0", sketch_update_function_arr[id]), "-1")[1], object_ids))  
    
      @show min_states_dict 
      @show min_transitions_dict
      @show start_state_dict

      if stop_times == [] 
        sketch_program = """ 
        include "$(local_sketch_directory)string.skh"; 
        include "$(local_sketch_directory)mstatemachine.skh";
        
        bit recognize_obj_specific([int n], char[n] events, int[n] functions, int start, char true_char, int min_states, int min_transitions) {
            return matches(MSM_obj_specific(events, start, true_char, min_states, min_transitions), functions);
        }
      
        $(join(map(i -> """harness void h$(i)() {
                              int start = ??;
                              assert recognize_obj_specific({ $(join(map(c -> "'$(c)'", sketch_event_arrs_dict_formatted[object_ids[i]]), ", ")) }, 
                                                            { $(join(sketch_update_function_arr[object_ids[i]], ", ")) }, 
                                                            start, 
                                                            '$(true_char)',
                                                            $(min_states_dict[object_ids[i]]),
                                                            $(min_transitions_dict[object_ids[i]]));
                            }""", collect(1:length(object_ids))), "\n\n"))
        """
      else
        stop_times_for_sketch = map(t -> t - 1, stop_times)
        min_stop_val = minimum(all_stop_var_values) 
        desired_out_dict = Dict(map(id -> map(x -> parse(Int, x), sketch_update_function_arr[id]), object_ids))
  
        @show stop_times_for_sketch 
        @show min_stop_val 
        @show desired_out_dict
  
        
        sketch_program = """ 
        include "$(local_sketch_directory)string.skh"; 
        include "$(local_sketch_directory)mstatemachine_stops.skh";
        
        bit recognize_obj_specific([int n], char[n] events, int[n] functions, int start, char true_char, int min_states, int min_transitions, int[p] stop_times, int min_stop_val, int[n] desired_out) {
          return matches(MSM_obj_specific(events, start, true_char, min_states, min_transitions, stop_times, min_stop_val, desired_out), functions);
        }

        $(join(map(i -> """harness void h$(i)() {
                              int start = ??;
                              assert recognize_obj_specific({ $(join(map(c -> "'$(c)'", sketch_event_arrs_dict_formatted[object_ids[i]]), ", ")) }, 
                                                            { $(join(sketch_update_function_arr[object_ids[i]], ", ")) }, 
                                                            start, 
                                                            '$(true_char)',
                                                            $(min_states_dict[object_ids[i]]),
                                                            $(min_transitions_dict[object_ids[i]]),
                                                            { $(join(stop_times_for_sketch, ", ")) },
                                                            $(min_stop_val),
                                                            { $(join(desired_out_dict[i], ", ")) });
                            }""", collect(1:length(object_ids))), "\n\n"))
        """
      end

      ## save sketch program as file 
      open("automata_sketch_$(run_id).sk","w") do io
        println(io, sketch_program)
      end
    
      # run Sketch query
      if sketch_timeout == 0 
        command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_update_function_arr[object_ids[1]]) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
      else
        if Sys.islinux() 
          command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_update_function_arr[object_ids[1]]) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
        else
          command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_update_function_arr[object_ids[1]]) + 2) --fe-tempdir $(temp_directory) --fe-output-code automata_sketch_$(run_id).sk"
        end
      end
    
        sketch_output = try 
                        readchomp(eval(Meta.parse("`$(command)`")))
                      catch e
                        ""
                      end
    
    
      if !occursin("The sketch could not be resolved.", sketch_output) && sketch_output != ""
        # update intAsChar and add main function to output cpp file 
        cpp_file_name = "automata_sketch_$(run_id).cpp"
        cpp_out_file_name = "automata_sketch_$(run_id).out" 

        f = open(cpp_file_name, "r")
        cpp_content = read(f, String)
        close(f)

        # # println("LOOK HERE NOW")
        @show cpp_content
    
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

        open(cpp_file_name, "w+") do io
          println(io, modified_cpp_content)
        end
    
        # compile modified cpp program 
        command = "g++ -o $(cpp_out_file_name) $(cpp_file_name)"
        compile_output = readchomp(eval(Meta.parse("`$(command)`"))) 
    
        # run compiled cpp program 
        command = "./$(cpp_out_file_name)"
        full_run_output = readchomp(eval(Meta.parse("`$(command)`")))  
        full_run_output = replace(full_run_output, "\x01" => "")
        
        output_per_object_id_list = filter(x -> occursin("TRAJECTORY", x), split(full_run_output, "DONE"))
    
        object_field_values = Dict()
        accept_values = []
        transitions = []
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
    
          # construct init_accept_values from table and on_clauses 
          state_to_update_function_index_arr = map(s -> parse(Int, s), filter(x -> x != " ", split(table_string, "\n")))
          distinct_states = unique(field_values)
    
          update_function_index = 1
          corresponding_states = map(i -> i - 1, findall(x -> x == update_function_index, state_to_update_function_index_arr))
          corresponding_states = intersect(corresponding_states, distinct_states) # don't count extraneous indices from table
          push!(accept_values, corresponding_states...) 
          
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
          
          end
        end
        # # # println("OUTPUT?")
        @show [(unique(accept_values), object_field_values, unique(transitions), co_occurring_event)]
        push!(solutions, (unique(accept_values), object_field_values, unique(transitions), co_occurring_event))
      end
  
      if length(solutions) >= 8 
        break
      end 
  
    end # end of transition decision string loop 

    if length(solutions) >= 8 
      break
    end 

  end # end of co-occurring loop
  solutions 

end

function special_addObj_removeObj_handling(update_function, filtered_matrix, co_occurring_events, addObj_based_list, double_removeObj_update_functions, linked_removeObj_update_functions, source_exists_events_dict, object_decomposition)
  println("SPECIAL_ADDOBJ_REMOVEOBJ_HANDLING")
  @show update_function 
  @show filtered_matrix 
  @show co_occurring_events 
  @show addObj_based_list 
  @show double_removeObj_update_functions 
  @show linked_removeObj_update_functions 
  @show source_exists_events_dict 
  # @show object_decomposition
  
  object_types, object_mapping, _, _ = object_decomposition
  
  on_clauses = []
  
  if update_function in addObj_based_list
    println("SPECIAL ADDOBJ HANDLING")
    @show update_function 
    addObj_type_id = parse(Int, split(split(update_function, "addObj addedObjType")[2], "List")[1])
    matching_add_remove_pairs = filter(p -> p[1] == addObj_type_id, collect(keys(source_exists_events_dict)))
    if matching_add_remove_pairs != [] 
      addObj_removeObj_pair = length(matching_add_remove_pairs) == 1 ? matching_add_remove_pairs[1] : matching_add_remove_pairs 
      removeObj_type_id = length(matching_add_remove_pairs) == 1 ? matching_add_remove_pairs[1][2] : map(x -> x[2], matching_add_remove_pairs)
    else
      addObj_removeObj_pair = nothing
      removeObj_type_id = nothing
    end

    # if there is no associated removeObj rule or the pair of addObj/removeObj is not state-based, 
    # construct appropriate random trigger event 
    # if isnothing(addObj_removeObj_pair) || !source_exists_events_dict[addObj_removeObj_pair][2]
    time_based_co_occurring_events = filter(e -> occursin("(prev time)", e), map(x -> x[1], co_occurring_events))
    if !isnothing(addObj_removeObj_pair)
      
      exists_events = map(x -> source_exists_events_dict[x][1], addObj_removeObj_pair isa AbstractArray ? addObj_removeObj_pair : [addObj_removeObj_pair])
      source_exists_co_occurring_events = []
      for exists_event in exists_events 
        
        if exists_event != "true"
          push!(source_exists_co_occurring_events, filter(e -> e == exists_event, map(x -> x[1], co_occurring_events))...)
        else
          push!(source_exists_co_occurring_events, filter(e -> occursin("<= (distance", e), map(x -> x[1], co_occurring_events))...)
        end

      end
    else
      source_exists_co_occurring_events = []
    end

    if !isnothing(addObj_removeObj_pair)
      e, c = addObj_removeObj_pair isa AbstractArray ? ("true", 0) : source_exists_events_dict[addObj_removeObj_pair]

      ids_with_removeObj_type_id = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id in (removeObj_type_id isa AbstractArray ? removeObj_type_id : [removeObj_type_id]), collect(keys(object_mapping)))
      if removeObj_type_id isa AbstractArray 
        removeObj_update_function = filter(u -> foldl(|, map(x -> occursin("removeObj addedObjType$(x)List", u), removeObj_type_id)) || occursin("removeObj (prev obj$(ids_with_removeObj_type_id[1]))", u), linked_removeObj_update_functions)
        removeObj_update_function = join(removeObj_update_function, "\t")
      else
        removeObj_update_functions = filter(u -> occursin("removeObj addedObjType$(removeObj_type_id)List", u) || occursin("removeObj (prev obj$(ids_with_removeObj_type_id[1]))", u), linked_removeObj_update_functions)
        if removeObj_update_functions != []
          removeObj_update_function = removeObj_update_functions[1]
        else
          removeObj_update_function = ""
        end
      end
      
      if removeObj_update_function == "" 
        if time_based_co_occurring_events != [] && source_exists_co_occurring_events == []
          addObj_on_clause = "(on (& (& $(time_based_co_occurring_events[1]) $(source_exists_co_occurring_events[1])) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function))"
        elseif time_based_co_occurring_events != []
          addObj_on_clause = "(on (& $(time_based_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function))"
        elseif source_exists_co_occurring_events != []
          addObj_on_clause = "(on (& $(source_exists_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function))"
        else
          addObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n$(update_function))"
        end
        push!(on_clauses, (addObj_on_clause, update_function))
      else

        if c > 2
          source_exists_co_occurring_events = [e]
          old_removeObj_update_function = removeObj_update_function
          removeObj_update_function = replace(removeObj_update_function, "(--> obj (== (.. obj id) x))" => "(uniformChoice (prev addedObjType$(removeObj_type_id)List))")
          if time_based_co_occurring_events != [] && source_exists_co_occurring_events != []
            addObj_on_clause = "(on (& (& $(time_based_co_occurring_events[1]) $(source_exists_co_occurring_events[1])) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n(let ($(update_function) $(removeObj_update_function))))"
          elseif time_based_co_occurring_events != []
            addObj_on_clause = "(on (& $(time_based_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n(let ($(update_function) $(removeObj_update_function))))"
          elseif source_exists_co_occurring_events != []
            addObj_on_clause = "(on (& $(source_exists_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n(let ($(update_function) $(removeObj_update_function))))"
          else
            addObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n(let ($(update_function) $(removeObj_update_function))))"
          end

          push!(on_clauses, (addObj_on_clause, update_function))
  
          addObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n$(removeObj_update_function))"
          push!(on_clauses, (addObj_on_clause, old_removeObj_update_function))
        else
  
          if time_based_co_occurring_events != [] && source_exists_co_occurring_events != [] 
            addObj_on_clause = "(on (& $(time_based_co_occurring_events[1]) (& $(source_exists_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)))\n(let ($(update_function) $(removeObj_update_function))))"
          elseif time_based_co_occurring_events != [] && source_exists_co_occurring_events == []
            addObj_on_clause = "(on (& $(time_based_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n(let ($(update_function) $(removeObj_update_function))))"
          elseif time_based_co_occurring_events == [] && source_exists_co_occurring_events != []
            addObj_on_clause = "(on (& $(source_exists_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n(let ($(update_function) $(removeObj_update_function))))"
          else
            addObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n(let ($(update_function) $(removeObj_update_function))))"
          end
    
          println("LOOK AT ME HERE")
          @show co_occurring_events 
          proximity_based_co_occurring_events = filter(e -> occursin("(<= (distance", e), map(x -> x[1], co_occurring_events))
    
          # only consider proximity events where at least one involved type is brownian 
          brownian_type_ids = []
          for t in object_types 
            object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == t.id, collect(keys(object_mapping)))
            if filter(r -> occursin("uniformChoice", r) && !occursin("addObj", r), vcat(vcat(map(id -> filtered_matrix[id, :], object_ids_with_type)...)...)) != []
              push!(brownian_type_ids, t.id)
            end
          end
    
          proximity_based_co_occurring_events_new = []
          for option in proximity_based_co_occurring_events 
            if occursin(".. obj id) x", option)
              option_first_half = split(replace(replace(option, "(" => ""), ")" => ""), "obj id) x")[1]
              option_second_half = split(replace(replace(option, "(" => ""), ")" => ""), "obj id) x")[2]
    
              first_type_id = parse(Int, split(match(r"distance prev obj prev addedObjType\d+", option_first_half).match, "addedObjType")[end])
              second_type_id = parse(Int, split(match(r"20 prev addedObjType\d+", option_second_half).match, "addedObjType")[end])
      
              if (first_type_id in brownian_type_ids) || (second_type_id in brownian_type_ids)
                push!(proximity_based_co_occurring_events_new, option)
              end
      
            elseif occursin("(list)", option)
              option_first_half = split(replace(replace(option, "(" => ""), ")" => ""), "20")[1]
              option_second_half = split(replace(replace(option, "(" => ""), ")" => ""), "20")[2]
    
              first_type_id = parse(Int, split(match(r"distance prev obj prev addedObjType\d+", option_first_half).match, "addedObjType")[end])
              second_type_id = parse(Int, split(match(r"prev addedObjType\d+", option_second_half).match, "addedObjType")[end])
      
              if (first_type_id in brownian_type_ids) || (second_type_id in brownian_type_ids)
                push!(proximity_based_co_occurring_events_new, option)
              end
    
            else
              first_object_id = parse(Int, split(match(r"distance prev obj\d+", replace(replace(option, "(" => ""), ")" => "")).match, "prev obj")[end])
              first_type_id = filter(o -> !isnothing(o), object_mapping[first_object_id])[1].type.id
              second_type_id = parse(Int, split(match(r"addedObjType\d+", replace(replace(option, "(" => ""), ")" => "")).match, "addedObjType")[end])
      
              if (first_type_id in brownian_type_ids) || (second_type_id in brownian_type_ids)
                push!(proximity_based_co_occurring_events_new, option)
              end
            end
          end
          proximity_based_co_occurring_events = proximity_based_co_occurring_events_new
    
          if proximity_based_co_occurring_events != [] # occursin("firstWithDefault", addObj_on_clause) && 
            parts = split(addObj_on_clause, "\n")
            original_event = replace(parts[1], "(on " => "")
            new_event = "(& $(original_event) $(proximity_based_co_occurring_events[1]))"
            addObj_on_clause = "(on $(new_event)\n$(parts[2])"          
          end
    
          if occursin("\t", removeObj_update_function)
            funcs = split(removeObj_update_function, "\t")
            for f in funcs 
              push!(on_clauses, (addObj_on_clause, f))
            end
          else
            push!(on_clauses, (addObj_on_clause, removeObj_update_function))
          end
          push!(on_clauses, (addObj_on_clause, update_function))
        end  
      end

    else
      if time_based_co_occurring_events != [] && source_exists_co_occurring_events == []
        addObj_on_clause = "(on (& $(time_based_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function))"
      else
        addObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n$(update_function))"
      end
      push!(on_clauses, (addObj_on_clause, update_function))
    end
    println("WOOT YAY")
    @show addObj_on_clause 
    @show on_clauses 
    handled_via_special_addObj_rules = true             
  elseif update_function in vcat(double_removeObj_update_functions...)
    proximity_based_co_occurring_events = filter(e -> occursin("(<= (distance", e), map(x -> x[1], co_occurring_events)) 
    linked_update_function = filter(x -> x[1] == update_function, double_removeObj_update_functions)[2]
    if proximity_based_co_occurring_events != [] 
      removeObj_on_clause = "(on (& $(proximity_based_co_occurring_events[1]) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function) $(linked_update_function))" 
    else
      removeObj_on_clause = "(on (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1)\n$(update_function) $(linked_update_function))"
    end
    push!(on_clauses, (removeObj_on_clause, update_function))
    push!(on_clauses, (removeObj_on_clause, other_update_function))
  else
    
    special_handling = false
    if occursin("removeObj", update_function) && filter(e -> occursin("(<= (distance", e), map(x -> x[1], co_occurring_events)) != []
      proximity_event = filter(e -> occursin("(<= (distance", e), map(x -> x[1], co_occurring_events))[1]
      involved_types = []
      
      # search for substrings of the form "addedObjType$(type_id)List"
      parts = filter(x -> x != "", split(proximity_event, "addedObjType"))
      if parts != []
        for part_index in 2:2:length(parts)
          proximity_id = parse(Int, split(parts[part_index], "List")[1]) 
          push!(involved_types, proximity_id)
        end
      end

      # search for substrings of the form "obj$(id)"
      singleton_object_match = match(r"obj\d+", proximity_event)
      if !isnothing(singleton_object_match)
        singleton_object_id = parse(Int, replace(singleton_object_match.match, "obj" => ""))
        singleton_object_type_id = filter(obj -> !isnothing(obj), object_mapping[singleton_object_id])[1].type.id
        push!(involved_types, singleton_object_type_id)
      end

      if filter(type_id -> object_type_is_brownian(type_id, filtered_matrix, object_decomposition), involved_types) != [] 
        removeObj_on_clause = "(on (& $(proximity_event) (== (uniformChoice (list 1 2 3 4 5 6 7 8 9 10)) 1))\n$(update_function))"
        push!(on_clauses, (removeObj_on_clause, update_function))
        special_handling = true
      end
    end    
  end
  on_clauses
end