
function find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value) 
  # events = collect(keys(event_vector_dict))
  # matching_events = []
  # for event in events 
  #   event_vector = event_vector_dict[event]
  #   event_times = findall(x -> x == 1, event_vector)
  #   if !(0 in map(time_range -> length(findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times)) > 0, time_ranges))
  #     # co-occurring event found      
  #     # compute number of false positives 
  #     co_occurring_times = [event_times[i] for i in vcat(map(time_range -> findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times), time_ranges)...)]
  #     false_positive_times = [time for time in event_times if !(time in co_occurring_times)]
  #     if length(false_positive_times) == 0
  #       push!(matching_events, (event, co_occurring_times))
  #     end
  #   end
  # end
  # sort(matching_events, by=x -> length(x[1]))

  co_occurring_events = find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value)
  matches = map(x -> (x[1], x[3]), filter(tuple -> tuple[2] == 0, co_occurring_events))
  sort(matches, by=x -> length(x))
end

function find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value)
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
        if time > maximum(map(tuple -> tuple[1], augmented_positive_times))
          desired_end_value = augmented_positive_times[end][2]
          push!(desired_end_values, desired_end_value)
        else
          future_augmented_positive_times = filter(tuple -> tuple[1] >= time, augmented_positive_times)
          closest_future_augmented_time = future_augmented_positive_times[1]
          push!(desired_end_values, closest_future_augmented_time[2])
        end

        # handle start value 
        if time < minimum(map(tuple -> tuple[1], augmented_positive_times))
          desired_start_value = augmented_positive_times[1][2]
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