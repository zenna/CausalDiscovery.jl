const sketch_directory = "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/"

function generate_global_multi_automaton_sketch(co_occurring_event, times_dict, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, interval_painting_param=false)
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
    if !(e in atomic_events) || !(event_vector_dict[e] isa AbstractArray) || occursin("globalVar", e)
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
  augmented_true_positive_times = unique(vcat(collect(values(augmented_true_positive_times_dict))...))  

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
      
        for time in event_times 
          sketch_event_trajectory[time] = state_update_event
        end
      end

    else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
      # find co-occurring event with fewest false positives 
      false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, init_augmented_positive_times, time_ranges, start_value, end_value, init_global_var_dict, global_var_id, 1)
      false_positive_events_with_state = filter(e -> !occursin("globalVar$(global_var_id)", e[1]), false_positive_events) # no state-based events in sketch-based approach
      
      events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
      if events_without_true != []
        false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
        
        for time in vcat(true_positive_times, false_positive_times)
          sketch_event_trajectory[time] = false_positive_event
        end
      end
    end

  end

  # construct sketch event input array
  distinct_events = sort(unique(sketch_event_trajectory))
  sketch_event_arr = map(e -> findall(x -> x == e, distinct_events)[1], sketch_event_trajectory)

  # construct sketch update function input array
  sketch_update_function_arr = ["0" for i in 1:length(sketch_event_trajectory)]
  for tuple in init_augmented_positive_times 
    time, value = tuple 
    sketch_update_function_arr[time] = string(value)
  end

  sketch_program = """ 
  include "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/sketchlib/string.skh"; 
  include "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/test/sk/numerical/mstatemachine.skh";

  bit recognize([int n], char[n] events, int[n] functions){
      return matches(MSM(events), functions);
  }

  harness void h() {
    assert recognize( { $(join(map(c -> "'$(c)'", sketch_event_arr), ", ")) }, 
                      { $(join(sketch_update_function_arr, ", ")) });
  }
  """

  # save sketch program 
  open("multi_automata_sketch.sk","w") do io
    println(io, sketch_program)
  end

  # run sketch on file 
  command = "$(sketch_directory)sketch --bnd-unroll-amnt $(length(sketch_event_arr) + 2) --fe-output-code multi_automata_sketch.sk"
  sketch_output = readchomp(eval(Meta.parse("`$(command)`")))

  if occursin("The sketch could not be resolved.", sketch_output)
    ([], [], [], init_global_var_dict)
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
      
      on_clause = "(on (& $(co_occurring_event) (in globalVar$(global_var_id) (list $(join(corresponding_states, " ")))))\n$(update_function))"
      push!(on_clauses, on_clause)
    end 

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
    for time in 2:length(init_global_var_dict[global_var_id])
      prev_value = init_global_var_dict[global_var_id][time - 1]
      next_value = init_global_var_dict[global_var_id][time]

      if prev_value != next_value 
        transition_tuple = filter(t -> t[1] == prev_value && t[2] == next_value, transitions)[1]
        _, _, transition_label = transition_tuple 
        
        state_update_on_clause = "(on (& $(transition_label) (== globalVar$(global_var_id) $(prev_value)))\n(= globalVar$(global_var_id) $(next_value)))"
        init_state_update_times_dict[global_var_id][time - 1] = state_update_on_clause
        push!(state_update_on_clauses, state_update_on_clause)
      end
    end

    (on_clauses, state_update_on_clauses, init_state_update_times_dict, init_global_var_dict)
  end

end