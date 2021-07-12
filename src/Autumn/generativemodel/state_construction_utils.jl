function find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict) 
  co_occurring_events = find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict)
  matches = map(x -> (x[1], x[3]), filter(tuple -> tuple[2] == 0, co_occurring_events))
  sort(matches, by=x -> length(x))
end

function find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict)
  events = filter(e -> !occursin("globalVar1", e), collect(keys(event_vector_dict)))
  co_occurring_events = []
  for event in events 
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if !(0 in map(time_range -> length(findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times)) > 0, time_ranges))
      # co-occurring event found      
      # compute number of false positives 
      co_occurring_times = [event_times[i] for i in vcat(map(time_range -> findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times), time_ranges)...)]
      false_positive_times = [time for time in event_times if !(time in co_occurring_times)]

      # find closest event in the future; if value matches end_value, not a false_positive event!
      desired_end_values = []
      desired_start_values = []
      for time in false_positive_times 
        # handle end value
        if (time >= maximum(map(tuple -> tuple[1], augmented_positive_times))) || (time < minimum(map(tuple -> tuple[1], augmented_positive_times)) - 1)
          desired_end_value = ((time + 1) > length(global_var_dict[1])) ? global_var_dict[1][time] : global_var_dict[1][time + 1]
          push!(desired_end_values, desired_end_value)
        else
          future_augmented_positive_times = filter(tuple -> tuple[1] > time, augmented_positive_times)
          closest_future_augmented_time = future_augmented_positive_times[1]
          push!(desired_end_values, closest_future_augmented_time[2])
        end

        # handle start value 
        if (time < minimum(map(tuple -> tuple[1], augmented_positive_times))) || (time > maximum(map(tuple -> tuple[1], augmented_positive_times)))
          desired_start_value = global_var_dict[1][time]
          push!(desired_start_values, desired_start_value)
        else
          earlier_augmented_positive_times = filter(tuple -> tuple[1] <= time, augmented_positive_times)
          closest_earlier_augmented_time = earlier_augmented_positive_times[end]
          push!(desired_start_values, closest_earlier_augmented_time[2])
        end

      end
      num_false_positives_with_effects = count(x -> x != end_value, desired_end_values)
      false_positive_with_effects_times = [false_positive_times[i] for i in findall(v -> v != end_value, desired_end_values)]
      push!(co_occurring_events, (event, 
                                  num_false_positives_with_effects, 
                                  co_occurring_times, 
                                  false_positive_with_effects_times))
      # (tuple structure: (event, # of false positives, list of correct event times, list of false positive event times ))
      
      zipped_values = [(desired_start_values[i], desired_end_values[i]) for i in 1:length(desired_end_values)]
      num_false_positives_with_effects_state = count(x -> (x[2] != end_value) && (x[1] == start_value), zipped_values)
      false_positives_with_effects_state_times = [false_positive_times[i] for i in findall(x -> (x[2] != end_value) && (x[1] == start_value), zipped_values)]
      push!(co_occurring_events, ("(& $(event) (== (prev globalVar1) $(start_value)))", 
                                  num_false_positives_with_effects_state, 
                                  co_occurring_times, 
                                  false_positives_with_effects_state_times))
    end
  end
  co_occurring_events = sort(co_occurring_events, by=x->x[2])

  # among events with minimum # of false positives, sort by length of event (i.e. so "left" appears before "& left (== globalVar1 1)")
  min_false_positives = co_occurring_events[1][2]
  min_false_positive_events = sort(filter(e -> e[2] == min_false_positives, co_occurring_events), by=x->length(x[1]))
  other_events = filter(e -> e[2] != min_false_positives, co_occurring_events)
  co_occurring_events = vcat(min_false_positive_events, other_events)
end

function group_ranges(ranges)
  dict = Dict()

  for range in ranges
    start_time = range[1][1]
    start_value = range[1][2]

    end_time = range[2][1] - 1
    end_value = range[2][2]

    if !((start_value, end_value) in keys(dict))
      dict[(start_value, end_value)] = [range] 
    else
      push!(dict[(start_value, end_value)], range)
    end
  end

  grouped_ranges = sort(map(k -> dict[k], collect(keys(dict))), by=group->group[1][1][1]) # sort by first start time in each group
  grouped_ranges 
end

function is_co_occurring(event, event_vector, update_function_times)  
  event_times = findall(x -> x == 1, event_vector)
  if repr(sort(intersect(event_times, update_function_times))) == repr(sort(update_function_times))
    push!(co_occurring_events, (event, length([time for time in event_times if !(time in update_function_times)])))
  end
end

function num_false_positives(event_vector, update_function_times)
  event_times = findall(x -> x == 1, event_vector)
  length([ time for time in event_times if !(time in update_function_times) ])
end

function find_state_update_events_object_specific(event_vector_dict, augmented_positive_times_dict, grouped_ranges, start_value, end_value)
  # collect object-specific events 
  events = filter(e -> occursin(") x", e), collect(keys(event_vector_dict)))
  
end