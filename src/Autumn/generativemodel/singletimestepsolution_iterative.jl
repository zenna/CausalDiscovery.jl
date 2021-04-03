using Autumn

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations)
  # dictionary mapping each time to a dictionary mapping object id's to an update function list 
  time_to_single_object_solutions = Dict{Int, Dict{Int, AbstractArray}}()
    
  # for each subsequent frame, map objects  
  for time in 2:length(observations)
    # initialize dictionary of single-object solutions for this time step
    time_to_object_solutions[time - 1] = Dict{Int, AbstractArray}()

    # get previous and current observed frames
    prev_observation = observations[time - 1]
    curr_observation = observations[time]
    
    # assign objects from previous time step to objects in current time step
    # object mapping is a dictionary of prev object id's to current object id's
    prev_object_decomposition, curr_object_decomposition, object_mapping = parse_and_map_objects(prev_observation, curr_observation)
    
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for prev_object_id in keys(object_mapping)
      next_object_id = object_mapping[prev_object_id]
      update_functions = synthesize_update_functions(prev_decomposition, curr_decomposition, prev_object_id, next_object_id)
      time_to_object_solutions[time - 1][prev_object_id] = update_functions
    end
  end
  
  # convert solutions dictionary into matrix form

  num_objects = maximum(map(time -> maximum(collect(keys(time_to_object_solutions[time]))), collect(keys(time_to_object_solutions))))
  matrix = []

  matrix
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(prev_observation, curr_observation)::Dict{Int, Int}

end



"""Synthesize a set of update functions that """
function synthesize_update_functions()::AbstractArray

end