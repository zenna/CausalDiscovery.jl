const sketch_directory = "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/"

function generate_global_automaton_sketch(small_event_vector_dict, augmented_positive_times, grouped_ranges, global_var_dict, global_var_id, global_var_value)
  failed = false

  # ----- STEP 1: construct input string of which to take prefixes -----  
  event_string = map(x -> "true", zeros(length(collect(values(small_event_vector_dict))[1])))

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
    events_in_range = find_state_update_events(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value)
    if events_in_range != [] 
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

      for time in event_times
        event_string[time] = occursin("globalVar", state_update_event) ? replace(state_update_event[4:end], " (== (prev globalVar$(global_var_id)) $(start_value)))" => "") : state_update_event
      end

    else 
      false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value)
      false_positive_events_without_state = filter(e -> !occursin("globalVar$(global_var_id)", e[1]), false_positive_events) # want the most specific events in the false positive case
      
      events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_without_state)), false_positive_events_without_state)
      if events_without_true != []
        false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
      else
        # FAILURE CASE: only separating event with false positives is true-based 
        # false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1]
        failed = true 
        break
      end

      for time in vcat(true_positive_times, false_positive_times)
        event_string[time] = false_positive_event
      end
    end
  end

  # TODO: add user events to event string if they do not overlap with existing events from time range analysis 

  # ----- STEP 2: construct positive and negative prefixes 

  positive_prefixes = []
  negative_prefixes = []

  for tuple in augmented_positive_times 
    time, value = tuple 

    if value == 1 
      push!(positive_prefixes, event_string[1:time])
    else
      push!(negative_prefixes, event_string[1:time])
    end
  end
  
  # ----- STEP 3: generate sketch program 
  distinct_events = sort(unique(event_string))
  sketch_positive_prefixes = map(prefix -> string(map(c -> string(findall(e -> e == c, distinct_events)[1]), prefix[1:end-1])...), positive_prefixes)
  sketch_negative_prefixes = map(prefix -> string(map(c -> string(findall(e -> e == c, distinct_events)[1]), prefix[1:end-1])...), negative_prefixes)

  sketch_program = """include "/Users/riadas/Documents/urop/sketch-1.7.6/sketch-frontend/test/sk/numerical/statemachine.skh";

                      bit recognize([int n], char[n] p){
                          generator int nxt(int i){ return i+1; }
                          generator char state(int i){ return p[i]; }
                          generator bit more(int i){ return i<n; }
                          return SM((int)0, nxt, state, more);
                      }
                        
                      harness void main(){
                        $(join(map(prefix -> """assert recognize("$(prefix)");\n  """, sketch_positive_prefixes), ""))
                        $(join(map(prefix -> """assert !recognize("$(prefix)");\n  """, sketch_negative_prefixes), ""))
                        // assert recognize("abab");
                        // assert recognize("a");
                        // assert recognize("aa");
                        // assert !recognize("bbb");
                      }
                      """
  # ----- STEP 4: run sketch program
  ## save sketch program as file 
  open("automata_sketch.sk","w") do io
    println(io, sketch_program)
  end

  ## run sketch on file 
  command = "$(sketch_directory)sketch automata_sketch.sk"
  sketch_output = readchomp(eval(Meta.parse("`$(command)`")))

  # ----- STEP 5: parse output of sketch program

end

function generate_object_specific_automaton_sketch(event_vector_dict, augmented_positive_times_dict, grouped_ranges)

end