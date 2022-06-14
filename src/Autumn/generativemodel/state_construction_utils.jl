function find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value, no_object_times, all_stop_var_values, object_specific=false, type=nothing) 
  co_occurring_events = find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value, no_object_times, all_stop_var_values, object_specific, type)
  matches = map(x -> (x[1], x[3]), filter(tuple -> tuple[2] == 0, co_occurring_events))
  sort(matches, by=x -> length(x))
end

function find_state_update_events_false_positives(orig_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value, no_object_times, all_stop_var_values, object_specific=false, type=nothing)
  # @show global_var_dict

  if object_specific
    event_vector_dict = orig_event_vector_dict
  else
    event_vector_dict = Dict()

    for event in filter(e -> (orig_event_vector_dict[e] isa Array) && !occursin("globalVar", e), collect(keys(orig_event_vector_dict)))
      event_vector_dict[event] = orig_event_vector_dict[event]
    end
  
    for event in filter(e -> !(orig_event_vector_dict[e] isa Array) && !occursin("globalVar", e) && occursin("id) x", e), collect(keys(orig_event_vector_dict)))
      for i in keys(orig_event_vector_dict[event])  
        event_vector_dict[replace(event, "id) x" => "id) $(i)")] = orig_event_vector_dict[event][i]
      end
    end
  end

  co_occurring_events = []
  # @show collect(keys(event_vector_dict))
  # @show time_ranges 
  # @show augmented_positive_times 
  for event in sort(collect(keys(event_vector_dict)), by=length) 
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if augmented_positive_times == [] # time_ranges == [] # 
      push!(co_occurring_events, (event, 0, [], []))
      if object_specific 
        push!(co_occurring_events, ("(& $(event) (intersects (list $(start_value)) (map (--> obj (.. obj field1)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type.id)List)))))", 0, [], []))
      else
        push!(co_occurring_events, ("(& $(event) (== globalVar$(global_var_id) $(start_value)))", 0, [], []))
      end
      # if event_times == [] || augmented_positive_times == [] || (end_value == augmented_positive_times[1][2])
      #   push!(co_occurring_events, (event, 0, [], []))
      #   if object_specific 
      #     push!(co_occurring_events, ("(& $(event) (intersects (list $(start_value)) (map (--> obj (.. obj field1)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type.id)List)))))", 0, [], []))
      #   else
      #     push!(co_occurring_events, ("(& $(event) (== globalVar$(global_var_id) $(start_value)))", 0, [], []))
      #   end
      # elseif start_value != augmented_positive_times[1][2]
      #   if object_specific 
      #     push!(co_occurring_events, ("(& $(event) (intersects (list $(start_value)) (map (--> obj (.. obj field1)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type.id)List)))))", 0, [], []))
      #   else
      #     push!(co_occurring_events, ("(& $(event) (== globalVar$(global_var_id) $(start_value)))", 0, [], []))
      #   end
      # end
      # push!(co_occurring_events, (event, 0, [], []))
    else
      if !(0 in map(time_range -> length(findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times)) > 0, time_ranges))
        # @show event
        # co-occurring event found      
        # compute number of false positives 
        co_occurring_times = [event_times[i] for i in vcat(map(time_range -> findall(time -> ((time >= time_range[1]) && (time <= time_range[2])), event_times), time_ranges)...)]
        false_positive_times = [time for time in event_times if !(time in co_occurring_times) && !(time in no_object_times)]
  
        # find closest event in the future; if value matches end_value, not a false_positive event!
        desired_end_values = []
        desired_start_values = []
        for time in false_positive_times 
          # handle end value
          if (((time == length(global_var_dict[global_var_id])) && (global_var_dict[global_var_id][time] < global_var_value)) || ((time < length(global_var_dict[global_var_id])) && (global_var_dict[global_var_id][time + 1] < global_var_value)))
            desired_end_value = ((time + 1) > length(global_var_dict[global_var_id])) ? global_var_dict[global_var_id][time] : global_var_dict[global_var_id][time + 1]
            if !(desired_end_value in all_stop_var_values)
              push!(desired_end_values, desired_end_value)
            else
              push!(desired_end_values, -1)
            end
          elseif (time >= maximum(map(tuple -> tuple[1], augmented_positive_times)))
            desired_end_value = -1 # augmented_positive_times[end][2]
            push!(desired_end_values, desired_end_value)
          else
            future_augmented_positive_times = filter(tuple -> tuple[1] > time, augmented_positive_times)
            closest_future_augmented_time = future_augmented_positive_times[1]
            desired_end_value = closest_future_augmented_time[2]
            if !(desired_end_value in all_stop_var_values)
              push!(desired_end_values, closest_future_augmented_time[2])
            else
              push!(desired_end_values, -1)
            end
          end
  
          # handle start value 
          if (time < minimum(map(tuple -> tuple[1], augmented_positive_times))) && (time <= length(global_var_dict[global_var_id])) && global_var_dict[global_var_id][time] < global_var_value 
            desired_start_value = global_var_dict[global_var_id][time]
            if !(desired_start_value in all_stop_var_values)
              push!(desired_start_values, desired_start_value)
            end
          elseif (time < minimum(map(tuple -> tuple[1], augmented_positive_times)))
            desired_start_value = augmented_positive_times[1][2] # -1
            if !(desired_start_value in all_stop_var_values)
              push!(desired_start_values, desired_start_value)
            else # case made while sleepy (same as below)
              future_augmented_positive_times = filter(tuple -> tuple[1] > time, augmented_positive_times)
              closest_future_augmented_time = future_augmented_positive_times[1]
              if !(closest_future_augmented_time in all_stop_var_values)
                push!(desired_start_values, closest_future_augmented_time[2])
              else
                push!(desired_start_values, -1)
              end
            end
          else
            earlier_augmented_positive_times = filter(tuple -> tuple[1] <= time, augmented_positive_times)
            closest_earlier_augmented_time = earlier_augmented_positive_times[end]
            desired_start_value = closest_earlier_augmented_time[2]
            if !(desired_start_value in all_stop_var_values)
              push!(desired_start_values, closest_earlier_augmented_time[2])
            else # case made while sleepy
              future_augmented_positive_times = filter(tuple -> tuple[1] > time, augmented_positive_times)
              closest_future_augmented_time = future_augmented_positive_times[1]
              if !(closest_future_augmented_time in all_stop_var_values)
                push!(desired_start_values, closest_future_augmented_time[2])
              else
                push!(desired_start_values, -1)
              end

            end
          end
  
        end
        num_false_positives_with_effects = count(x -> x != end_value && x != -1, desired_end_values)
        false_positive_with_effects_times = [false_positive_times[i] for i in findall(v -> v != end_value && v != -1, desired_end_values)]
        no_effect_times = [false_positive_times[i] for i in findall(v -> v == end_value || v == -1, desired_end_values)] # || v == -1
        push!(co_occurring_events, (event, 
                                    num_false_positives_with_effects, 
                                    [co_occurring_times..., no_effect_times...], 
                                    false_positive_with_effects_times))
        # (tuple structure: (event, # of false positives, list of correct event times, list of false positive event times ))
        
        zipped_values = [(desired_start_values[i], desired_end_values[i]) for i in 1:length(desired_end_values)]
        num_false_positives_with_effects_state = count(x -> !(x[2] in [end_value, -1]) && (x[1] == start_value), zipped_values)
        false_positives_with_effects_state_times = [false_positive_times[i] for i in findall(x -> !(x[2] in [end_value, -1]) && (x[1] == start_value), zipped_values)]
        if object_specific 
          push!(co_occurring_events, ("(& $(event) (intersects (list $(start_value)) (map (--> obj (.. obj field1)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type.id)List)))))", 
          num_false_positives_with_effects_state, 
          [co_occurring_times..., [false_positive_times[i] for i in findall(x -> (x[2] in [end_value, -1]) && (x[1] == start_value), zipped_values)]...], # [end_value, -1]
          false_positives_with_effects_state_times))
        else
          push!(co_occurring_events, ("(& $(event) (== (prev globalVar$(global_var_id)) $(start_value)))", 
          num_false_positives_with_effects_state, 
          [co_occurring_times..., [false_positive_times[i] for i in findall(x -> (x[2] in [end_value, -1]) && (x[1] == start_value), zipped_values)]...], # [end_value, -1]
          false_positives_with_effects_state_times))
        end
      end  
    end
  end
  # @show co_occurring_events
  co_occurring_events = sort(co_occurring_events, by=x->x[2])

  # among events with minimum # of false positives, sort by length of event (i.e. so "left" appears before "& left (== globalVar1 1)")
  if co_occurring_events == [] 
    []
  else
    min_false_positives = co_occurring_events[1][2]
    min_false_positive_events = sort(filter(e -> e[2] == min_false_positives, co_occurring_events), by=x->length(x[1]))
    other_events = filter(e -> e[2] != min_false_positives, co_occurring_events)
    co_occurring_events = vcat(min_false_positive_events, other_events)
  end
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

  grouped_ranges = sort(map(k -> dict[k], collect(keys(dict))), by=group->minimum(map(r -> r[1][1], group))) # sort by first start time in each group
  grouped_ranges 
end

function group_ranges(ranges_dict::Dict)
  ranges = vcat(filter(x -> length(x) > 0, vcat(map(id -> map(range -> ((range[1][1], range[1][2], id), (range[2][1], range[2][2], id)), ranges_dict[id]), collect(keys(ranges_dict)))))...)
  group_ranges(ranges)
end

function find_state_update_events_object_specific(event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, max_state_value, all_stop_var_values)
  events_with_false_positives = find_state_update_events_object_specific_false_positives(event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, max_state_value, all_stop_var_values)
  matches = map(x -> (x[1], x[3]), filter(tuple -> tuple[2] == 0, events_with_false_positives))
  sort(matches, by=x -> length(x))
end

function find_state_update_events_object_specific_false_positives(event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, max_state_value, all_stop_var_values)
  # extract object-specific events 
  events = filter(e -> e == "true" || !occursin("field1", e) && !(event_vector_dict[e] isa AbstractArray) && sort(collect(keys(event_vector_dict[e]))) == sort(object_ids), collect(keys(event_vector_dict))) 
  global_events = filter(e -> event_vector_dict[e] isa Array, collect(keys(event_vector_dict)))
  object_type = filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type

  # println("ONCE AGAIN")
  # @show events 

  update_events_dict = Dict()
  for object_id in object_ids 
    # @show object_id
    object_mapping_row = findall(time -> isnothing(object_mapping[object_id][time]), 1:length(object_mapping[object_id]))
    object_event_vector_dict = Dict()
    for event in events 
      if event == "true"
        object_event_vector_dict[event] = event_vector_dict[event]
      else
        object_event_vector_dict[event] = event_vector_dict[event][object_id]
      end
    end

    augmented_positive_times = augmented_positive_times_dict[object_id]

    time_ranges = map(range -> (range[1][1], range[2][1] - 1), filter(r -> r[1][3] == object_id, grouped_range))

    start_value = grouped_range[1][1][2]
    end_value = grouped_range[1][2][2]

    if "field1" in map(x -> x[1], filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.custom_fields)
      custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
      object_var_dict = Dict(1 => map(obj -> isnothing(obj) ? -1 : obj.custom_field_values[custom_field_index], object_mapping[object_id])[1:end-1])
    else
      object_var_dict = Dict(1 => ones(Int, length(event_vector_dict[global_events[1]])))
    end
    object_var_value = max_state_value
    
    # # @show object_id
    # # @show object_event_vector_dict
    # # @show augmented_positive_times 
    # # @show time_ranges 
    # # @show start_value 
    # # @show end_value 
    update_events = find_state_update_events_false_positives(object_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, object_var_dict, 1, object_var_value, object_mapping_row, all_stop_var_values, true, object_type)
    
    update_events_dict[object_id] = update_events
  end
  # @show update_events_dict
  common_events = intersect(map(id -> map(x -> x[1], update_events_dict[id]), object_ids)...)
  if common_events == [] 
    # FAILURE CASE
    []
  else
    solutions = []
    for common_event in common_events 
      true_times = []
      false_times = []
      num_false_positives_ = 0
      for object_id in object_ids
        event_tuple = filter(event_tuple -> event_tuple[1] == common_event, update_events_dict[object_id])[1] 
        object_false_positives = event_tuple[2]
        object_true_times = event_tuple[3]
        object_false_times = event_tuple[4]
        augmented_true_times = map(time -> (time, object_id), object_true_times)
        augmented_false_times = map(time -> (time, object_id), object_false_times)
        true_times = vcat(true_times..., augmented_true_times...)
        false_times = vcat(false_times..., augmented_false_times...)
        num_false_positives_ = num_false_positives_ + object_false_positives
      end
      push!(solutions, (common_event, num_false_positives_, true_times, false_times))  
    end
    # common_event = common_events[1]
    # [(common_event, event_times)]
    sort(solutions, by=s -> s[2])  
  end

end


function is_co_occurring(event, event_vector, update_function_times)  
  event_times = findall(x -> x == 1, event_vector)
  if repr(sort(intersect(event_times, update_function_times))) == repr(sort(update_function_times))
    true
  else
    false
  end
end

function num_false_positives(event_vector, update_function_times, object_trajectory)
  event_times = findall(x -> x == 1, event_vector)
  length([ time for time in event_times if !(time in update_function_times) && !isnothing(object_trajectory[time]) && !isnothing(object_trajectory[time + 1]) ])
end

function recompute_ranges(augmented_positive_times, new_state_update_times_dict, global_var_id, global_var_value, global_var_dict, true_positive_times, extra_global_var_values, global_heuristic=false) 
  # println("RECOMPUTE RANGES")
  # @show augmented_positive_times 
  # @show new_state_update_times_dict 
  # @show global_var_id 
  # @show global_var_value 
  # @show global_var_dict 
  # @show true_positive_times 
  # @show extra_global_var_values
  # compute new ranges and find state update events
  new_ranges = [] 
  for i in 1:(length(augmented_positive_times)-1)
    prev_time, prev_value = augmented_positive_times[i]
    next_time, next_value = augmented_positive_times[i + 1]
    # @show prev_time 
    # @show next_time
    if prev_value != next_value
      if length(unique(new_state_update_times_dict[global_var_id][prev_time:next_time-1])) == 1 && unique(new_state_update_times_dict[global_var_id][prev_time:next_time-1])[1] == ""
        # if there are no state update functions within this range, add it to new_ranges
        push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
      elseif intersect(true_positive_times, collect(prev_time:next_time-1)) == []
        # if the state_update_function in this range is not among those just added (which are correct), add range to new_ranges
        # # @show prev_time 
        # # @show prev_value 
        # # @show next_time 
        # # @show next_value 
        
        on_clause_index = findall(x -> x != "", new_state_update_times_dict[global_var_id][prev_time:next_time-1])[1]
        new_state_update_times_dict[global_var_id][on_clause_index + prev_time - 1] = ""
        push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
      end
    end
  end

  if !global_heuristic
    # add ranges that interface between global_var_value and lower values to new_ranges 
    if global_var_value > 1
      for time in 1:(length(new_state_update_times_dict[global_var_id]) - 1)
        prev_val = global_var_dict[global_var_id][time]
        next_val = global_var_dict[global_var_id][time + 1]

        if ((prev_val < global_var_value) && (next_val == global_var_value) || (prev_val == global_var_value) && (next_val < global_var_value))
          if intersect([time], true_positive_times) == [] 
            push!(new_ranges, ((time, prev_val), (time + 1, next_val)))
          end
        end
      end
    end
  end

  # filter ranges where both the range's start and end times are already included
  filtered_ranges = []
  for range in new_ranges
    start_tuples = map(range -> range[1], filter(r -> r != range, new_ranges))
    end_tuples = map(range -> range[2], filter(r -> r != range, new_ranges))
    if !((range[1] in start_tuples) && (range[2] in end_tuples))
      push!(filtered_ranges, range)      
    end
  end

  # reset any functions inside these new ranges in new_state_update_times
  for range in filtered_ranges 
    start_time = range[1][1]
    end_time = range[2][1] - 1

    for t in start_time:end_time
      new_state_update_times_dict[global_var_id][t] = ""
    end
  end

  grouped_ranges = group_ranges(filtered_ranges)

  deepcopy(grouped_ranges), deepcopy(augmented_positive_times), deepcopy(new_state_update_times_dict)
end

function recompute_ranges_object_specific(augmented_positive_times_dict, curr_state_value, object_mapping, object_ids)
  ranges_dict = Dict()
  for object_id in object_ids
    ranges = []
    augmented_positive_times = augmented_positive_times_dict[object_id]
    for i in 1:(length(augmented_positive_times)-1)
      prev_time, prev_value = augmented_positive_times[i]
      next_time, next_value = augmented_positive_times[i + 1]
      if prev_value != next_value
        push!(ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
      end
    end
    ranges_dict[object_id] = ranges
  end
  # add ranges that interface between global_var_value and lower values
  if curr_state_value > 1
    custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
    for object_id in object_ids
      augmented_positive_times = augmented_positive_times_dict[object_id]
      for time in 1:(length(object_mapping[object_ids[1]])-1)
        if (length(intersect(map(t -> t[1], augmented_positive_times), [time, time + 1])) == 1) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          prev_val = object_mapping[object_id][time].custom_field_values[custom_field_index]
          next_val = object_mapping[object_id][time + 1].custom_field_values[custom_field_index]

          if (prev_val < curr_state_value) && (next_val == curr_state_value)
            if (filter(t -> t[1] == time + 1, augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, augmented_positive_times)[1][2] != curr_state_value)
              new_value = filter(t -> t[1] == time + 1, augmented_positive_times)[1][2]
              push!(ranges_dict[object_id], ((time, prev_val), (time + 1, new_value)))        
            else
              push!(ranges_dict[object_id], ((time, prev_val), (time + 1, next_val)))        
            end
  
          elseif (prev_val == curr_state_value) && (next_val < curr_state_value)
            if (filter(t -> t[1] == time, augmented_positive_times) != []) && (filter(t -> t[1] == time, augmented_positive_times)[1][2] != curr_state_value)
              new_value = filter(t -> t[1] == time, augmented_positive_times)[1][2]
              push!(ranges_dict[object_id], ((time, new_value), (time + 1, next_val)))        
            else
              push!(ranges_dict[object_id], ((time, prev_val), (time + 1, next_val)))        
            end
          end
        end
      end
    end
  end

  # filter ranges where both the range's start and end times are already included
  new_ranges_dict = Dict()
  for object_id in object_ids
    new_ranges_dict[object_id] = []
    ranges = ranges_dict[object_id]
    for range in ranges
      start_tuples = map(range -> range[1], filter(r -> r != range, ranges))
      end_tuples = map(range -> range[2], filter(r -> r != range, ranges))
      if !((range[1] in start_tuples) && (range[2] in end_tuples))
        push!(new_ranges_dict[object_id], range)      
      end
    end
  end

  grouped_ranges = group_ranges(new_ranges_dict)
  grouped_ranges
end