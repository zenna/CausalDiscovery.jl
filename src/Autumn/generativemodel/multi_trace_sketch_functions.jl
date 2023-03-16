function generate_global_multi_automaton_sketch_multi_trace(run_id, co_occurring_event, times_dict, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, sketch_timeout=0, incremental=false, ordered_update_functions=[], transition_distinct=1, transition_same=1, transition_threshold=1; stop_times=[], linked_ids=Dict())
  println("GENERATE_NEW_STATE_GLOBAL_SKETCH")
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
    if occursin("adj ", e) || !(e in atomic_events) || (!(event_vector_dict[e] isa AbstractArray) && !(e in map(x -> "(clicked (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(x)List)))", map(x -> x.id, object_types))) )
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
   
  augmented_stop_times = []
  stop_var_value = maximum(map(tup -> tup[2], vcat(augmented_true_positive_times..., augmented_false_positive_times...))) + 1
  all_stop_var_values = []
  # for stop_time in stop_times 
  #   push!(augmented_stop_times, (stop_time, stop_var_value))
  #   push!(all_stop_var_values, stop_var_value)
  #   stop_var_value += 1
  # end

  init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times, augmented_stop_times), by=x -> x[1])
  # init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

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

  no_object_times = findall(x -> x == [""] || occursin("addObj", join(x)), object_trajectory)
  num_traces = length(stop_times) + 1
  solutions = []
  for transition_decision_string in transition_decision_strings 
    transition_decision_index = 1
    sketch_event_trajectory_dict = Dict()
    for i in 1:num_traces 
      if i == 1 
        start_time = 0
        end_time = stop_times[i]
      elseif i == num_traces 
        start_time = stop_times[i - 1]
        end_time = length(co_occurring_event_trajectory) + 1
      else
        start_time = stop_times[i - 1]
        end_time = stop_times[i]
      end

      prior_times_count = 0
      if i != 1 
        prior_times_count = stop_times[i - 1]
      end

      co_occurring_event_trajectory_for_trace = co_occurring_event_trajectory[(start_time + 1):(end_time - 1)]
      init_augmented_positive_times_for_trace = sort(filter(tup -> (tup[1] > start_time) && (tup[1] < end_time), init_augmented_positive_times), by=tup -> tup[1])
      # @show i 
      # @show init_augmented_positive_times
      # @show init_augmented_positive_times_for_trace
      sketch_event_trajectory = ["true" for i in 1:length(co_occurring_event_trajectory_for_trace)]
      
      # grouped_ranges = filter(gr -> (gr[1][1][1] > start_time) && (gr[1][2][1] < end_time), init_grouped_ranges)
      
      for grouped_range in grouped_ranges
        range = grouped_range[1]
        start_value = range[1][2]
        end_value = range[2][2]
        # @show range
        time_ranges = map(r -> (r[1][1], r[2][1] - 1), grouped_range)
  
        # construct state update function
        state_update_function = "(= globalVar$(global_var_id) $(end_value))"
  
        # get current maximum value of globalVar
        max_global_var_value = maximum(map(tuple -> tuple[2], init_augmented_positive_times_for_trace))
  

        events_in_range = find_state_update_events(small_event_vector_dict, init_augmented_positive_times_for_trace, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1, no_object_times, all_stop_var_values)
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
            println("HERE 1")
            # @show time 
            if ((time - prior_times_count) <= length(sketch_event_trajectory)) && (time - prior_times_count > 0)
              sketch_event_trajectory[time - prior_times_count] = state_update_event
            end
          end
  
        else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
          # find co-occurring event with fewest false positives 
          false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, init_augmented_positive_times_for_trace, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1, no_object_times, all_stop_var_values)
          false_positive_events_with_state = filter(e -> occursin("globalVar", e[1]), false_positive_events) # no state-based events in sketch-based approach
          
          events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
          if events_without_true != []
            index = min(length(events_without_true), transition_decision_index > num_transition_decisions ? 1 : transition_decision_string[transition_decision_index])            
            false_positive_event, _, true_positive_times, false_positive_times = events_without_true[index] 
            false_positive_event = split(false_positive_event, " (== (prev globalVar")[1][4:end]
            # @show false_positive_event 
  
            for time in vcat(true_positive_times, false_positive_times)
              println("HERE 2")
              # @show time
              if time - prior_times_count <= length(sketch_event_trajectory)
                sketch_event_trajectory[time - prior_times_count] = false_positive_event
              end
            end
          end
        end
        transition_decision_index += 1
      end
      # @show sketch_event_trajectory
      sketch_event_trajectory_dict[i] = sketch_event_trajectory
    end

    # construct sketch event input array
    concat_sketch_event_trajectory = vcat(map(i -> sketch_event_trajectory_dict[i], collect(keys(sketch_event_trajectory_dict)))...)
    distinct_events = sort(unique(concat_sketch_event_trajectory), by=x -> count(y -> y == x, concat_sketch_event_trajectory)) 
    # @show distinct_events 

    if length(distinct_events) > 9
      return [([], [], [], "")]
    end

    true_char = "0"
    if "true" in distinct_events 
      true_char = string(findall(x -> x == "true", distinct_events)[1])
    end

    sketch_program_data = Dict()
    for i in 1:num_traces 
      sketch_event_trajectory = sketch_event_trajectory_dict[i]

      sketch_event_arr = map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)

      # construct sketch update function input array
      prior_times_count = 0
      if i != 1 
        prior_times_count = stop_times[i - 1]
      end
      sketch_update_function_arr = ["0" for i in 1:length(sketch_event_trajectory)]

      # @show sketch_event_trajectory 
      # @show sketch_update_function_arr
      # @show distinct_events 

      for tuple in init_augmented_positive_times 
        time, value = tuple 
        # @show time 
        # @show value 
        # @show prior_times_count
        if (time - prior_times_count) > 0 
          # @show time - prior_times_count
          if ((time - prior_times_count) <= length(sketch_event_trajectory)) && (time - prior_times_count > 0)
            sketch_update_function_arr[time - prior_times_count] = string(value)
          end

        end
      end
  
      # # TRIM sketch_update_function_arr and sketch_event_arr 
      # if true_char != "0"
      #   true_event_times = findall(x -> string(x) == true_char, sketch_event_arr)
      #   sketch_event_arr = filter(x -> string(x) != true_char, sketch_event_arr) # remove all "true" events from event array
  
      #   # remove all update functions corresponding to "true" events from update function array 
      #   sketch_update_function_arr = [sketch_update_function_arr[i] for i in 1:length(sketch_update_function_arr) if !(i in true_event_times)]
      # end
  
      # @show sketch_event_arr 
      # @show sketch_update_function_arr
      sketch_program_data[i] = (sketch_event_arr, sketch_update_function_arr)
    end

    min_states = -1 
    min_transitions = -1
    for i in 1:num_traces 
      sketch_event_arr, sketch_update_function_arr = sketch_program_data[i]
      min_states_for_trace = length(unique(filter(x -> x != "0", sketch_update_function_arr)))
      min_transitions_for_trace = length(unique(filter(x -> (x[1] != x[2]) && x[1] != "0" && x[2] != "0", collect(zip(sketch_update_function_arr, vcat(sketch_update_function_arr[2:end], -1)))))) - 1
      min_states = max(min_states, min_states_for_trace)
      min_transitions = max(min_transitions, min_transitions_for_trace)
    end

    # start_state = sketch_update_function_arr[1]



    sketch_program = """ 
    include "$(local_sketch_directory)string.skh"; 
    include "$(local_sketch_directory)mstatemachine.skh";

    bit recognize([int n], char[n] events, int[n] functions, char true_char, int min_states, int min_transitions, int start){
        return matches(MSM(events, true_char, min_states, min_transitions, start), functions);
    }

    harness void h() {
      int start_state = ??;
    $(join(map(i -> """
      assert recognize( { $(join(map(c -> "'$(c)'", sketch_program_data[i][1]), ", ")) }, 
                        { $(join(sketch_program_data[i][2], ", ")) }, 
                        '$(true_char)',
                        $(min_states),
                        $(min_transitions),
                        start_state);
    """, 1:num_traces), "\n\n"))
    }
    """

    # save sketch program 
    sketch_file_name = "multi_automata_sketch_$(run_id).sk"
    open(sketch_file_name,"w") do io
      println(io, sketch_program)
    end

    unroll_bound = maximum(map(t -> length(t), collect(values(sketch_event_trajectory_dict)))) + 2

    # run Sketch query
    if sketch_timeout == 0 
      command = "$(sketch_directory)sketch --bnd-unroll-amnt $(unroll_bound) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
    else
      if Sys.islinux() 
        command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(unroll_bound) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
      else
        command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(unroll_bound) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
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
      cpp_file_name = "multi_automata_sketch_$(run_id).cpp"
      cpp_out_file_name = "multi_automata_sketch_$(run_id).out"

      f = open(cpp_file_name, "r")
      cpp_content = read(f, String)
      close(f)

      # @show cpp_content 

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
      # @show full_run_output

      output_per_object_id_list = filter(x -> occursin("TRAJECTORY", x), split(full_run_output, "DONE"))

      transitions = []
      final_state_update_on_clauses = []
      final_on_clauses = []
      
      for output_index in 1:length(output_per_object_id_list)
        run_output = output_per_object_id_list[output_index]

        # parse run output to construct on_clauses, state_update_on_clauses, init_state_update_times, and init_global_var_dict
        parts = split(run_output, "STATE TRAJECTORY")
        state_transition_string = parts[1]
        states_and_table_string = parts[2]

        parts = split(states_and_table_string, "TABLE")
        states_string = parts[1]
        table_string = parts[2]

        # parse state trajectory into init_global_var_dict 
        global_var_values = map(s -> parse(Int, s), filter(x -> x != " ", split(states_string, "\n")))

        prior_times_count = 0
        if (output_index > 1)  
          prior_times_count = stop_times[output_index - 1]
        end

        for i in 1:length(global_var_values)
          init_global_var_dict[global_var_id][i + prior_times_count] = global_var_values[i]
        end

        # add in-between global var value at stop time after end of current trace; same value as end of current trace
        if output_index < length(output_per_object_id_list)
          init_global_var_dict[global_var_id][stop_times[output_index]] = init_global_var_dict[global_var_id][stop_times[output_index] - 1]
        end

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

        # @show output_index
        # @show transitions
        # @show init_global_var_dict
        state_update_on_clauses = []
        for time in (prior_times_count + 2):(prior_times_count + length(global_var_values))
          prev_value = init_global_var_dict[global_var_id][time - 1]
          next_value = init_global_var_dict[global_var_id][time]

          # @show time 
          # @show prev_value 
          # @show next_value 

          if prev_value != next_value 
            transition_tuple = filter(t -> t[1] == prev_value && t[2] == next_value, transitions)[1]
            _, _, transition_label = transition_tuple 
            
            state_update_on_clause = "(on (& $(transition_label) (== (prev globalVar$(global_var_id)) $(prev_value)))\n(= globalVar$(global_var_id) $(next_value)))"
            init_state_update_times_dict[global_var_id][time - 1] = state_update_on_clause
            push!(state_update_on_clauses, state_update_on_clause)
          end
        end

        filter!(c -> !occursin("fake_time", c), state_update_on_clauses)
        
        # @show on_clauses 
        # @show state_update_on_clauses 
        # @show init_state_update_times_dict 
        # @show init_global_var_dict
        on_clauses = [on_clauses..., state_update_on_clauses...]
        
      end
     
      for stop_time in stop_times 
        if init_global_var_dict[global_var_id][stop_time] != init_global_var_dict[global_var_id][stop_time + 1]
          println("SOUNDNESS CONDITION FAILURE")
          return [([], [], [], "")]
        end
      end
     
      if incremental # broken in multi-trace case: on_clauses/state_update_on_clauses/init_state_update_times_dict/init_global_var_dict not aggregated across traces; rather last single trace's values are kept
        # println("AM I IN THE RIGHT PLACE?")
        push!(solutions, (on_clauses, init_global_var_dict, init_state_update_times_dict))
      else
        # println("WHERE IS THE OUTPUT??")
        # init_global_var_dict[global_var_id] = [init_global_var_dict[global_var_id][1] for i in 1:length(co_occurring_event_trajectory)]
        # @show [(init_extra_global_var_values, unique(transitions), init_global_var_dict, co_occurring_event)]
        push!(solutions, (init_extra_global_var_values, unique(filter(trans -> !occursin("fake_time", trans[3]), transitions)), init_global_var_dict, co_occurring_event))
      end
    end
  end
  solutions
end

function generate_object_specific_multi_automaton_sketch(run_id, co_occurring_event, update_functions, times_dict, event_vector_dict, type_id, object_decomposition, init_state_update_times, global_var_dict, sketch_timeout=0, incremental=false, transition_param=false, transition_distinct=1, transition_same=1, transition_threshold=1; stop_times=[]) 
  println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  # @show co_occurring_event
  # @show update_functions 
  # @show times_dict
  # @show event_vector_dict
  # @show type_id 
  # @show object_decomposition
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
  max_v = -1
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

    max_v = maximum(vcat(max_v, map(tup -> tup[2], augmented_positive_times)...))
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

  num_traces = length(stop_times) + 1
  solutions = []
  for transition_decision_string in transition_decision_strings 
    transition_decision_index = 1
    grouped_ranges = deepcopy(init_grouped_ranges)

    # construct event array to feed into Sketch (post-formatting)
    sketch_event_trajectories_dict = Dict()
    for i in 1:size(num_traces)
      sketch_event_arrs_dict = Dict(map(id -> id => ["true" for i in 1:length(object_mapping[object_ids[1]])], object_ids))
      if i == 1 
        start_time = 1 
        end_time = stop_times[i]
      elseif i == num_traces 
        start_time = stop_times[i - 1]
        end_time = length(co_occurring_event_trajectory isa AbstractArray ? co_occurring_event_trajectory : co_occurring_event_trajectory[object_ids[1]])
      else
        start_time = stop_times[i - 1]
        end_time = stop_times[i]
      end

      augmented_positive_times_dict_for_trace = Dict()
      for id in object_ids
        augmented_positive_times_dict_for_trace[id] = filter(tup -> (tup[1] > start_time) && (tup[2] < end_time), augmented_positive_times_dict[id])             
      end

      while length(grouped_ranges) > 0 && (iters < 50)
        iters += 1
        grouped_range = grouped_ranges[1]
        grouped_ranges = grouped_ranges[2:end]
        # @show grouped_range
        time_ranges = map(r -> (r[1][1], r[2][1] - 1), grouped_range)
  
        range = grouped_range[1]
        start_value = range[1][2]
        end_value = range[2][2]
  
        max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict_for_trace[id]), collect(keys(augmented_positive_times_dict_for_trace)))...))
  
        # TODO: try global events too  
        events_in_range = []
        if events_in_range == [] # if no global events are found, try object-specific events 
          if (start_value in all_stop_var_values)
            events_in_range = [("(== (prev fake_time) $(time_ranges[1][1] - 1))", [(time_ranges[1][1], id) for id in object_ids])]
          elseif (end_value in all_stop_var_values)
            events_in_range = [("(== (prev fake_time) $(time_ranges[1][2]))", [(time_ranges[1][2], id) for id in object_ids])]
          else
            events_in_range = find_state_update_events_object_specific(small_event_vector_dict, augmented_positive_times_dict_for_trace, grouped_range, object_ids, object_mapping, curr_state_value, all_stop_var_values)
          end        
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
          false_positive_events = find_state_update_events_object_specific_false_positives(small_event_vector_dict, augmented_positive_times_dict_for_trace, grouped_range, object_ids, object_mapping, curr_state_value, all_stop_var_values)      
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
      sketch_event_trajectories_dict[i] = sketch_event_arrs_dict
    end

    distinct_events = sort(unique(vcat(map(d -> collect(values(d)), map(i -> collect(values(sketch_event_trajectories_dict[i])), 1:num_traces))...))) # sort(unique(vcat(collect(values(sketch_event_arrs_dict))...)))  
    
    if length(distinct_events) > 9
      return [([], [], [], "")]
    end

    sketch_event_trajectories_dict_formatted = Dict()
    for i in 1:num_traces 
      sketch_event_arrs_dict = sketch_event_trajectories_dict[i]
      sketch_event_arrs_dict_formatted = Dict(map(id -> id => map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_arrs_dict[id]) , collect(keys(sketch_event_arrs_dict)))) # map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)

      sketch_event_trajectories_dict_formatted[i] = sketch_event_arrs_dict_formatted
    end
    
    true_char = "0"
    if "true" in distinct_events 
      true_char = string(findall(x -> x == "true", distinct_events)[1])
    end

    # construct sketch update function input array
    sketch_update_function_trajectories_dict = Dict()
    for i in 1:num_traces 
      if i == 1 
        start_time = 1 
        end_time = stop_times[i]
      elseif i == num_traces 
        start_time = stop_times[i - 1]
        end_time = length(co_occurring_event_trajectory isa AbstractArray ? co_occurring_event_trajectory : co_occurring_event_trajectory[object_ids[1]])
      else
        start_time = stop_times[i - 1]
        end_time = stop_times[i]
      end

      sketch_update_function_arr = Dict(map(id -> id => ["0" for i in 1:length(sketch_event_trajectories_dict_formatted[i][object_ids[1]])], object_ids))
      for id in object_ids 
        augmented_positive_times = filter(tup -> (tup[1] > start_time) && (tup[2] < end_time), augmented_positive_times_dict[id])
        for tuple in augmented_positive_times 
          time, value = tuple 
          sketch_update_function_arr[id][time] = string(value)
        end
      end
      sketch_update_function_trajectories_dict[i] = sketch_update_function_arr
    end


    # # TRIM sketch_update_function_arr and sketch_event_arr 
    # if true_char != "0"
    #   for id in object_ids 
    #     true_event_times = filter(y -> y != length(sketch_event_arr[id]), findall(x -> string(x) == true_char, sketch_event_arr[id]))
    #     sketch_event_arr[id] = filter(x -> string(x) != true_char, sketch_event_arr[id]) # remove all "true" events from event array
  
    #     # remove all update functions corresponding to "true" events from update function array 
    #     sketch_update_function_arr[id] = [sketch_update_function_arr[id][i] for i in 1:length(sketch_update_function_arr[id]) if !(i in true_event_times)]
    #   end
    # end

    # construct array of linked ids across traces 
    linked_ids_array = []
    links = filter(id -> id in object_ids, collect(keys(linked_ids))) # only concerned with id's of the same type
    while !isempty(links)
      link = links[1]
      links = links[2:end]

      new_id = linked_ids[link]
      arr = [link, new_id] 
      while new_id in keys(linked_ids)
        link = links[1]
        links = links[2:end]

        new_id = linked_ids[link]
        arr = [arr..., link, new_id]
      end
      push!(linked_ids_array, arr)
    end
    flattened_linked_ids = map(tup -> tup[1], vcat(linked_ids_array...))
    for id in object_ids 
      if !(id in flattened_linked_ids)
        for i in 1:num_traces 
          push!(linked_ids_array, [(id, i)])
        end
      end
    end

    new_linked_ids_array = []
    for arr in linked_ids_array 
      ids = map(tup -> tup[1], arr)
      new_arr = vcat(map(id -> map(i -> (id, i), 1:num_traces), ids)...)
      push!(new_linked_ids_array, new_arr)
    end
    
    # sort object_ids according to the order in flattened_linked_ids 
    flattened_linked_ids = map(tup -> tup[1], vcat(linked_ids_array...))
    object_ids = flattened_linked_ids

    min_states_dict = Dict(map(i -> Dict(map(id -> id => -1, object_ids)), 1:num_traces))
    min_transitions_dict = Dict(map(i -> Dict(map(id -> id => -1, object_ids)), 1:num_traces))
    for linked_ids in linked_ids_array
      min_states = map(tup -> length(unique(filter(x -> x != "0", sketch_update_function_trajectories_dict[tup[2]][tup[1]]))), linked_ids)
      min_transitions = map( tup -> length(unique(filter(x -> (x[1] != x[2]) && (x[1] != "0") && (x[2] != "0"), collect(zip(sketch_update_function_trajectories_dict[tup[2]][tup[1]], vcat(sketch_update_function_trajectories_dict[tup[2]][tup[1]][2:end], -1)))))) - 1, linked_ids)
      
      min_state = maximum(min_states)
      min_transition = maximum(min_transitions)
      for tup in linked_ids 
        min_states_dict[tup[2]][tup[1]] = min_state
        min_transitions_dict[tup[2]][tup[1]] = min_transition
      end
    end

    # start_state_dict = Dict(map(id -> id => sketch_update_function_arr[id][1], object_ids))

    # # @show start_state_dict 
    # @show min_transitions_dict
    # @show min_states_dict
    # @show sketch_update_function_trajectories_dict 
    # @show distinct_events 
    # @show sketch_event_arrs_dict_formatted

    sketch_program = """ 
    include "$(local_sketch_directory)string.skh"; 
    include "$(local_sketch_directory)mstatemachine.skh";
    
    bit recognize_obj_specific([int n], char[n] events, int[n] functions, int start, char true_char, int min_states, int min_transitions) {
        return matches(MSM_obj_specific(events, start, true_char, min_states, min_transitions), functions);
    }

    $(join(map(i -> """harness void h$(i)() {
                          int start = ??;
                          $(join(map(tup -> """assert recognize_obj_specific({ $(join(map(c -> "'$(c)'", sketch_event_arrs_dict_formatted[tup[2]][tup[1]]), ", ")) }, 
                                                                             { $(join(sketch_update_function_trajectories_dict[tup[2]][tup[1]], ", ")) }, 
                                                                             start, 
                                                                             '$(true_char)',
                                                                             $(min_states_dict[tup[2]][tup[1]]),
                                                                             $(min_transitions_dict[tup[2]][tup[1]]));""", linked_ids_array[i]), "\n"))
                        }""", collect(1:length(linked_ids_array))), "\n\n"))
    """

    ## save sketch program as file 
    sketch_file_name = "multi_automata_sketch_$(run_id).sk"
    open(sketch_file_name,"w") do io
      println(io, sketch_program)
    end

    # run Sketch query
    if sketch_timeout == 0 
      command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
    else
      if Sys.islinux() 
        command = "timeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
      else
        command = "gtimeout $(sketch_timeout) $(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arrs_dict_formatted[object_ids[1]]) + 2) --fe-output-code --bnd-mbits 6 --fe-tempdir $(temp_directory) $(sketch_file_name)"
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
      cpp_file_name = "multi_automata_sketch_$(run_id).cpp"
      cpp_out_file_name = "multi_automata_sketch_$(run_id).out"
      f = open(cpp_file_name, "r")
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
      accept_values = Dict(map(i -> i => [], collect(values(update_function_indices))))
      transitions = []
      state_update_on_clauses = []
      for output_index in 1:length(output_per_object_id_list)
        object_id, trace_index = flattened_linked_ids[output_index]
        
        run_output = output_per_object_id_list[output_index]

        parts = split(run_output, "STATE TRAJECTORY")
        state_transition_string = parts[1]
        states_and_table_string = parts[2]

        parts = split(states_and_table_string, "TABLE")
        states_string = parts[1]
        table_string = parts[2]

        # parse state trajectory into init_global_var_dict 
        field_values = map(s -> parse(Int, s), filter(x -> x != " ", split(states_string, "\n")))
        if !(object_id in object_field_values) 
          push!(object_field_values[object_id], field_values)
        else
          object_field_values[object_id] = field_values
        end
       
        if trace_index != num_traces 
          push!(object_field_values[object_id], object_field_values[object_id][end])
        end

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

          prior_times_count = 0
          if trace_index != 1 
            prior_times_count = stop_times[trace_index - 1]
          end
          for time in 2:length(field_values)
            prev_state = field_values[time - 1]
            next_state = field_values[time]

            if prev_state != next_state 
              _, _, transition_label = filter(trans -> (trans[1] == prev_state) && (trans[2] == next_state), transitions)[1]
              state_update_on_clause = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj (prev obj) "field1" $(next_state))) (--> obj (& $(co_occurring_event) (== (.. (prev obj) field1) $(prev_state)))))))"""
              push!(state_update_on_clauses, state_update_on_clause)
              state_update_times[object_id][prior_times_count + time - 1] = (state_update_on_clause, next_state)
            end

          end

          filter!(c -> !occursin("fake_time", c), state_update_on_clauses)

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
        push!(solutions, [(accept_values, object_field_values, unique(filter(trans -> !occursin("fake_time", trans[3]), transitions)), co_occurring_event)]...)
      end
    end
  end 
  solutions
end