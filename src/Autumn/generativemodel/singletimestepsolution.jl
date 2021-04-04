using Autumn
using Revise
using Distributed
include("generativemodel.jl")

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations)
  object_decomposition = parse_and_map_objects(observations)
  object_types, object_mapping, background, dim = object_decomposition
  # matrix of update function sets for each object/time pair
  # number of rows = number of objects, number of cols = number of time steps  
  num_objects = length(collect(keys(object_mapping)))
  matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  @show size(matrix)
  # for each subsequent frame, map objects  
  for time in 2:length(observations)
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for object_id in keys(object_mapping)
      update_functions = synthesize_update_functions(object_id, time, object_decomposition)
      @show update_functions 
      @show object_id 
      @show time
      matrix[object_id, time - 1] = update_functions
    end
  end
  matrix
end

"""Synthesize a set of update functions that """
function synthesize_update_functions(object_id, time, object_decomposition, max_iters=100)::AbstractArray
  object_types, object_mapping, background, dim = object_decomposition
  prev_object = object_mapping[object_id][time - 1]
  next_object = object_mapping[object_id][time]

  @show prev_object 
  @show next_object
  @show isnothing(prev_object) && isnothing(next_object)
  if isnothing(prev_object) && isnothing(next_object)
    [""]
  elseif isnothing(prev_object)
    ["(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) (Position $(next_object.position[1]) $(next_object.position[2])))))"]
  elseif isnothing(next_object)
    if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
      ["(= addedObjType$(prev_object.type.id)List (removeObj addedObjType$(prev_object.type.id)List (--> obj (== (.. obj id) $(object_id)))))"]
    else # object was present at the start of the program
      ["(= obj$(object_id) (removeObj obj$(object_id)))"]
    end
  else # actual synthesis problem
    prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    @show prev_objects
    solutions = []
    iters = 0
    while length(solutions) != 1 && iters < max_iters
      hypothesis_program = program_string_synth((object_types, [prev_objects..., prev_object], background, dim))
      update_rule = generate_hypothesis_update_rule(prev_object, (object_types, prev_objects, background, dim)) # "(on true (= obj1 (moveDownNoCollision (moveDownNoCollision (prev obj1)))))"
      hypothesis_program = string(hypothesis_program[1:end-2], "\n\t", update_rule, "\n)")
      println(hypothesis_program)

      # add new process
      procs = addprocs(1)

      expr = compiletojulia(parseautumn(hypothesis_program))
      @show expr

      Distributed.remotecall_eval(Main, procs, expr)
      # @eval @everywhere using Main.CompiledProgram
      callexpr = :(CompiledProgram.next(CompiledProgram.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing))
      hypothesis_frame_state = Distributed.remotecall_eval(Main, procs..., callexpr)
      @show hypothesis_frame_state.scene.objects
      
      # delete process
      rmprocs(procs...)
      
      hypothesis_object = filter(o -> o.id == object_id, hypothesis_frame_state.scene.objects)[1]
      @show hypothesis_object

      if render_equals(hypothesis_object, next_object)
        push!(solutions, update_rule)
      end
    end
    solutions
  end
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(observations)
  object_mapping = Dict{Int, AbstractArray}()

  # initialize object mapping with object_decomposition from first observation
  object_types, objects, background, dim = parsescene_autumn_singlecell(observations[1])
  for object in objects
    object_mapping[object.id] = [object]
  end

  for time in 2:length(observations)
    next_object_types, next_objects, _, _ = parsescene_autumn_singlecell(observations[time])  

    # update object_types with new elements in next_object_types 
    new_object_types = filter(type -> !(type.color in map(t -> t.color, object_types)), next_object_types)
    if length(new_object_types) != 0
      for i in 1:length(new_object_types)
        new_type = new_object_types[i]
        new_type.id = length(object_types) + i
        push!(object_types, new_type)
      end
    end

    # reassign type ids in next_objects according to global type set (object_types)
    for object in next_objects
      object.type = filter(type -> type.color == object.type.color, object_types)[1]
    end

    # construct mapping between objects and next_objects
    for type in object_types
      curr_objects_with_type = filter(o -> o.type.id == type.id, objects)
      next_objects_with_type = filter(o -> o.type.id == type.id, next_objects)
      
      closest_objects = compute_closest_objects(curr_objects_with_type, next_objects_with_type)
      while !(isempty(curr_objects_with_type) || isempty(next_objects_with_type)) 
        for (object_id, closest_ids) in closest_objects
          if length(intersect(closest_ids, map(o -> o.id, next_objects_with_type))) == 1
            closest_id = intersect(closest_ids, map(o -> o.id, next_objects_with_type))[1]
            next_object = filter(o -> o.id == closest_id, next_objects_with_type)[1]

            # remove curr and next objects from respective lists
            filter!(o -> o.id != object_id, curr_objects_with_type)
            filter!(o -> o.id != closest_id, next_objects_with_type)
            delete!(closest_objects, object_id)
            
            # add next object to mapping
            next_object.id = object_id
            push!(object_mapping[object_id], next_object)
          end

          if length(collect(keys(filter(pair -> length(intersect(last(pair), map(o -> o.id, next_objects_with_type))) == 1, closest_objects)))) == 0
            # every remaining object to be mapped is equidistant to at least two closest objects, or zero objects
            # perform a brute force assignment
            while !isempty(curr_objects_with_type) && !isempty(next_objects_with_type)
              # do something
              object = curr_objects_with_type[1]
              next_object = next_objects_with_type[1]
              
              filter!(o -> o.id == object.id, curr_objects_with_type)
              filter!(o -> o.id == next_object.id, next_objects_with_type)
              
              next_object.id = object.id
              push!(object_mapping[object.id], next_object)
            end
            break
          end
        end
      end

      max_id = length(collect(keys(object_mapping)))
      if isempty(curr_objects_with_type) && !(isempty(next_objects_with_type))
        # handle addition of objects
        for i in 1:length(next_objects_with_type)
          next_object = next_objects_with_type[i]
          next_object.id = max_id + i
          object_mapping[next_object.id] = [[nothing for i in 1:(time - 1)]..., next_object]
        end
      elseif !(isempty(curr_objects_with_type)) && isempty(next_objects_with_type)
        # handle removal of objects
        for object in curr_objects_with_type
          push!(object_mapping[object.id], nothing)
        end
      end
    end

    objects = next_objects

  end
  (object_types, object_mapping, background, dim)  
end

function compute_closest_objects(curr_objects, next_objects)
  closest_objects = Dict{Int, AbstractArray}()
  for object in curr_objects
    distances = map(o -> distance(object.position, o.position), next_objects)
    closest_objects[object.id] = map(obj -> obj.id, filter(o -> distance(object.position, o.position) == minimum(distances), next_objects))
  end
  closest_objects
end

function distance(pos1, pos2)
  pos1_x, pos1_y = pos1
  pos2_x, pos2_y = pos2
  # sqrt(Float((pos1_x - pos2_x)^2 + (pos1_y - pos2_y)^2))
  abs(pos1_x - pos2_x) + abs(pos1_y - pos2_y)
end

function render_equals(hypothesis_object, actual_object)
  translated_hypothesis_object = map(cell -> (cell.position.x + hypothesis_object.origin.x, cell.position.y + hypothesis_object.origin.y), hypothesis_object.render)
  translated_actual_object = map(pos -> (pos[1] + actual_object.position[1], pos[2] + actual_object.position[2]), actual_object.type.shape)
  translated_hypothesis_object == translated_actual_object
end