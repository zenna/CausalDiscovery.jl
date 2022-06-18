

function parse_and_map_objects_multiple_traces(multiple_traces, grid_size=16; singlecell=false, pedro=false)
  object_decomposition_list = []

  for observations in multiple_traces
    object_decomposition = parse_and_map_objects(observations, grid_size, singlecell=singlecell, pedro=pedro)
    push!(object_decomposition_list, object_decomposition)
  end

  # take union of object types across object_decompositions, and reassign object_mapping type_id's accordingly
  object_types, object_mapping, background, grid_size = object_decomposition_list[1]
  for object_decomposition in object_decomposition_list[2:end]
    curr_object_types, curr_object_mapping, _, _ = object_decomposition 
    for type in curr_object_types 
      
      if !((type.shape, type.color) in map(t -> (t.shape, t.color), object_types))
        old_type_id = type.id
        type.id = length(object_types) + 1
        push!(object_types, type)
      end

    end
  end

  # re-assign type id's of objects with type
  for object_decomposition in object_decomposition_list[2:end]
    _, curr_object_mapping, _, _ = object_decomposition
    for id in collect(keys(curr_object_mapping))
      for time in 1:length(curr_object_mapping[id])
        obj = curr_object_mapping[id][time]
        if !isnothing(obj)
          type = filter(t -> (t.shape, t.color) == (obj.type.shape, obj.type.color), object_types)[1]
          curr_object_mapping[id][time].type = type
        end
      end
    end
  end

  # construct full (long) object_mapping by linking existing objects across object_mappings, and creating new id's
  # for added object_id's in traces 2 through (n-1)
  prior_observations_count = length(multiple_traces[1])
  for i in 2:length(object_decomposition_list)
    object_decomposition = object_decomposition_list[i]
    _, curr_object_mapping, _, _ = object_decomposition 
    curr_ids = sort(collect(keys(curr_object_mapping)))
    for id in curr_ids 
      if !isnothing(curr_object_mapping[id][1])
        push!(object_mapping[id], curr_object_mapping[id]...)
      else 
        new_id = length(collect(keys(object_mapping))) + 1 

        for time in 1:length(curr_object_mapping[id])
          if !isnothing(curr_object_mapping[id][time])
            curr_object_mapping[id][time].id = new_id
          end 
        end

        object_mapping[new_id] = vcat([nothing for j in 1:prior_observations_count]..., curr_object_mapping[id]...)
      end
    end
    prior_observations_count += length(multiple_traces[i])
  end

  num_observations = sum(map(x -> length(x), observations))
  for id in keys(object_mapping)
    if length(object_mapping[id]) != num_observations
      for i in (length(object_mapping[id]) + 1):num_observations
        push!(object_mapping[id], nothing)
      end
    end
  end

  object_types, object_mapping, background, grid_size
end


