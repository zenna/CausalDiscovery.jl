using Autumn
using MacroTools: striplines
include("generativemodel.jl")

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations, grid_size)
  object_decomposition = parse_and_map_objects(observations)
  object_types, object_mapping, background, _ = object_decomposition
  # matrix of update function sets for each object/time pair
  # number of rows = number of objects, number of cols = number of time steps  
  num_objects = length(collect(keys(object_mapping)))
  matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  
  # SEED PREV USED RULES FOR EFFIENCY AT THE MOMENT
  prev_used_rules = ["(= objX (prev objX))",
                     "(= objX (moveLeftNoCollision (prev objX)))",
                     "(= objX (moveRightNoCollision (prev objX)))",
                     "(= objX (moveUpNoCollision (prev objX)))",
                     "(= objX (moveDownNoCollision (prev objX)))",
                     "(= objX (nextLiquid (prev objX)))",
                     "(= objX (nextSolid (prev objX)))",] # prev_used_rules = []
  
  @show size(matrix)
  # for each subsequent frame, map objects
  for time in 2:length(observations)
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for object_id in 1:num_objects
      update_functions, prev_used_rules = synthesize_update_functions(object_id, time, object_decomposition, prev_used_rules, grid_size)
      @show update_functions 
      matrix[object_id, time - 1] = update_functions 
    end
  end
  matrix, object_decomposition, prev_used_rules
end

expr = nothing
mod = nothing
global_iters = 0
"""Synthesize a set of update functions that """
function synthesize_update_functions(object_id, time, object_decomposition, prev_used_rules, grid_size=16, max_iters=10)
  object_types, object_mapping, background, _ = object_decomposition
  @show object_id 
  @show time
  prev_object = object_mapping[object_id][time - 1]
  
  next_object = object_mapping[object_id][time]
  #@show object_id 
  #@show time
  #@show prev_object 
  #@show next_object
  # @show isnothing(prev_object) && isnothing(next_object)
  if isnothing(prev_object) && isnothing(next_object)
    [""], prev_used_rules
  elseif isnothing(prev_object)
    ["(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))"], prev_used_rules
  elseif isnothing(next_object)
    if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
      ["(= addedObjType$(prev_object.type.id)List (removeObj addedObjType$(prev_object.type.id)List (--> obj (== (.. obj id) $(object_id)))))"], prev_used_rules
    else # object was present at the start of the program
      ["(= obj$(object_id) (removeObj obj$(object_id)))"], prev_used_rules
    end
  else # actual synthesis problem
    prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    #@show prev_objects
    solutions = []
    iters = 0
    prev_used_rules_index = 1
    using_prev = false
    while length(solutions) != 1 && iters < max_iters
      hypothesis_program = program_string_synth((object_types, sort([prev_objects..., prev_object], by=(x -> x.id)), background, grid_size))
      if (prev_object.custom_field_values != []) && (next_object.custom_field_values != []) && (prev_object.custom_field_values[1] != next_object.custom_field_values[1])
        update_rule = """(= obj$(object_id) (updateObj obj$(object_id) "color" "$(next_object.custom_field_values[1])"))"""
      elseif prev_used_rules_index <= length(prev_used_rules)
        update_rule = replace(prev_used_rules[prev_used_rules_index], "objX" => "obj$(object_id)")
        using_prev = true
        prev_used_rules_index += 1
      else
        using_prev = false
        update_rule = generate_hypothesis_update_rule(prev_object, (object_types, prev_objects, background, grid_size), p=0.2) # "(= obj1 (moveDownNoCollision (moveDownNoCollision (prev obj1))))"
      end      
      
      hypothesis_program = string(hypothesis_program[1:end-2], "\n\t (on true ", update_rule, ")\n)")
      println("HYPOTHESIS_PROGRAM")
      println(prev_object)
      println(hypothesis_program)
      # @show global_iters
      # @show update_rule

      global expr = striplines(compiletojulia(parseautumn(hypothesis_program)))
      #@show expr
      module_name = Symbol("CompiledProgram$(global_iters)")
      global expr.args[1].args[2] = module_name
      # @show expr.args[1].args[2]
      global mod = @eval $(expr)
      # @show repr(mod)
      hypothesis_frame_state = @eval mod.next(mod.init(nothing, nothing, nothing, nothing, nothing), nothing, nothing, nothing, nothing, nothing)
      
      hypothesis_object = filter(o -> o.id == object_id, hypothesis_frame_state.scene.objects)[1]
      #@show hypothesis_frame_state.scene.objects
      #@show hypothesis_object

      if render_equals(hypothesis_object, next_object)
        if using_prev
          println("HOORAY")
        end
        generic_update_rule = replace(update_rule, "obj$(object_id)" => "objX")
        if !(generic_update_rule in prev_used_rules) && !(occursin("color", generic_update_rule))
          push!(prev_used_rules, generic_update_rule)
        end

        if object_mapping[object_id][1] == nothing # object was added later; contained in addedList
          map_lambda_func = replace(string("(-->", replace(update_rule, "obj$(object_id)" => "obj")[3:end]), "(prev obj)" => "obj")
          push!(solutions, "(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List $(map_lambda_func) (--> obj (== (.. obj id) $(object_id)))))")
        else # object was present at the start of the program
          push!(solutions, update_rule)
        end
      end
      
      iters += 1
      global global_iters += 1
      
    end
    if (iters == max_iters)
      println("FAILURE")
    end
    solutions, prev_used_rules
  end
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(observations)
  object_mapping = Dict{Int, Array{Union{Nothing, Obj}}}()

  # check if observations contains frames with overlapping cells
  overlapping_cells = foldl(|, map(frame -> has_dups(map(cell -> (cell.position.x, cell.position.y), frame)), observations), init=false)
  println("OVERLAPPING_CELLS")
  println(overlapping_cells)
  # construct object_types
  ## initialize object_types based on first observation frame
  if overlapping_cells
    object_types, _, background, dim = parsescene_autumn_singlecell(observations[1])
  else
    object_types, _, background, dim = parsescene_autumn(observations[1])
  end

  ## iteratively build object_types through each subsequent observation frame
  for time in 2:length(observations)
    if overlapping_cells
      object_types, _, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types)
    else
      object_types, _, _, _ = parsescene_autumn_given_types(observations[time], object_types)
    end
  end

  if overlapping_cells
    _, objects, _, _ = parsescene_autumn_singlecell_given_types(observations[1], object_types)
  else
    _, objects, _, _ = parsescene_autumn_given_types(observations[1], object_types)
  end

  for object in objects
    object_mapping[object.id] = [object]
  end

  for time in 2:length(observations)
    if overlapping_cells
      _, next_objects, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types) # parsescene_autumn_singlecell
    else
      _, next_objects, _, _ = parsescene_autumn_given_types(observations[time], object_types) # parsescene_autumn_singlecell
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
              @show curr_objects_with_type
              @show next_objects_with_type
              curr_objects_with_type = filter(o -> o.id != object.id, curr_objects_with_type)
              next_objects_with_type = filter(o -> o.id != next_object.id, next_objects_with_type)
              
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
          push!(object_mapping[object.id], [nothing for i in time:length(observations)]...)
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

function generate_observations(m::Module)
  state = m.init(nothing, nothing, nothing, nothing, nothing)
  observations = []
  for i in 0:10
    if i % 5 == 2
      # state = m.next(state, nothing, nothing, nothing, nothing, nothing)
      state = m.next(state, nothing, nothing, nothing, nothing, mod.Down())
    elseif i == 5
      state = m.next(state, mod.Click(rand(1:10),rand(1:10)), nothing, nothing, nothing, nothing)
    else
      state = m.next(state, nothing, nothing, nothing, nothing, nothing)
    end
    push!(observations, m.render(state.scene))
  end
  observations
end

function singletimestepsolution_program(observations, grid_size=16)
  
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, grid_size)
  singletimestepsolution_program_given_matrix(matrix, object_decomposition, grid_size)
end

function singletimestepsolution_program_given_matrix(matrix, object_decomposition, grid_size=16)
  object_types, object_mapping, background, _ = object_decomposition
  
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  program_no_update_rules = program_string_synth((object_types, objects, background, grid_size))
  
  list_variables = join(map(type -> 
  """(: addedObjType$(type.id)List (List ObjType$(type.id)))\n  (= addedObjType$(type.id)List (initnext (list) (prev addedObjType$(type.id)List)))\n""", 
  object_types),"\n  ")
  
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""

  update_rule_times = filter(time -> join(map(l -> l[1], matrix[:, time]), "") != "", [1:size(matrix)[2]...])
  update_rules = join(map(time -> """(on (== time $(time))\n  (let\n    ($(join(map(l -> l[1], matrix[:, time]), "\n    "))))\n  )""", update_rule_times), "\n  ")
  
  string(program_no_update_rules[1:end-2], 
        "\n\n  $(list_variables)",
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function has_dups(list::AbstractArray)
  length(unique(list)) != length(list) 
end