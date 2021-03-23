using Autumn

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations)
  # dictionary mapping each time to a dictionary mapping object id's to an update function list 
  time_to_single_object_solutions = Dict{Int, Dict{Int, AbstractArray}}()
  
  # decomposition of initial scene into object types and objects
  prev_decomposition = parse_objects(observations[1])
  
  # for each subsequent frame, map objects  
  for time in 2:length(observations)
    # initialize dictionary of single-object solutions for this time step
    time_to_object_solutions[time - 1] = Dict{Int, AbstractArray}()

    # decomposition of current observation
    curr_observation = observations[time]
    curr_decomposition = parse_objects(curr_observation)
    
    # assign objects from previous time step to objects in current time step
    # object mapping is a dictionary of prev object id's to current object id's
    object_mapping = map_objects(prev_decomposition, curr_decomposition)
    
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

"""Parse observation into object types and objects"""
function parse_objects(observation)
  parsescene_autumn_singlecell(observation)
end

"""Assign objects in current observed frame to objects in next frame"""
function map_objects(prev_decomposition, curr_decomposition)::Dict{Int, Int}

end

"""Synthesize a set of update functions that """
function synthesize_update_functions()::AbstractArray
  
end