using Autumn
using MacroTools: striplines
using StatsBase
using Random
include("generativemodel.jl")
include("state_construction_utils.jl")
include("construct_observation_data.jl")

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations, user_events, grid_size)
  object_decomposition = parse_and_map_objects(observations, grid_size)
  object_types, object_mapping, background, _ = object_decomposition
  # matrix of update function sets for each object/time pair
  # number of rows = number of objects, number of cols = number of time steps  
  num_objects = length(collect(keys(object_mapping)))
  matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  
  # SEED PREV USED RULES FOR EFFIENCY AT THE MOMENT
  prev_used_rules = ["(= objX objX)",
                    #  "(= objX (moveLeftNoCollision objX))",
                    #  "(= objX (moveLeftNoCollision (moveUpNoCollision objX)))",
                    #  "(= objX (moveLeftNoCollision (moveDownNoCollision objX)))",
                    #  "(= objX (moveRightNoCollision objX))",
                    #  "(= objX (moveRightNoCollision (moveUpNoCollision objX)))",
                    #  "(= objX (moveRightNoCollision (moveDownNoCollision objX)))",
                    #  "(= objX (moveUpNoCollision objX))",
                    #  "(= objX (moveUpNoCollision objX))",
                    #  "(= objX (moveDownNoCollision objX))",
                     "(= objX (moveLeftNoCollision objX))",
                     "(= objX (moveRightNoCollision objX))",
                     "(= objX (nextLiquid objX))",
                     "(= objX (nextSolid objX))",
                    #  "(= objX (moveDown objX))",
                    #  "(= objX (moveLeft objX))",
                    #  "(= objX (moveRight objX))",
                    #  "(= objX (removeObj objX))",
                    #  "(= objX (moveLeft (moveDown objX)))",
                    #  "(= objX (moveRight (moveDown objX)))",
                    ] # prev_used_rules = []

  prev_abstract_positions = []
  
  @show size(matrix)
  # for each subsequent frame, map objects
  for time in 2:length(observations)
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for object_id in 1:num_objects
      update_functions, prev_used_rules, prev_abstract_positions = synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size)
      @show update_functions 
      if length(update_functions) == 0
        println("HOLY SHIT")
      end
      matrix[object_id, time - 1] = update_functions 
    end
  end
  matrix, object_decomposition, prev_used_rules
end

expr = nothing
mod = nothing
global_iters = 0
"""Synthesize a set of update functions that """
function synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size=16, max_iters=5)
  object_types, object_mapping, background, grid_size = object_decomposition
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
    [""], prev_used_rules, prev_abstract_positions
  elseif isnothing(prev_object)
    # perform position abstraction step
    start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
    prev_objects_maybe_listed = filter(obj -> !isnothing(obj) && !isnothing(object_mapping[obj.id][1]), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_objects = filter(obj -> (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == obj.type.id, collect(keys(object_mapping))) == 1), prev_objects_maybe_listed)
    println("HELLO")
    @show prev_objects
    abstracted_positions, prev_abstract_positions = abstract_position(next_object.position, prev_abstract_positions, user_events[time - 1], (object_types, prev_objects, background, grid_size))
    # abstracted_positions = ["(uniformChoice (randomPositions $(grid_size) 1))", abstracted_positions...]
    
    # add uniformChoice option
    matching_objects = filter(o -> o.position == next_object.position, prev_objects_maybe_listed)
    if (matching_objects != []) && (isnothing(object_mapping[matching_objects[1].id][1]) || (count(x -> x.type.id == matching_objects[1].type.id, start_objects) > 1)) 
      matching_object = matching_objects[1]
      push!(abstracted_positions , "(.. (uniformChoice (prev addedObjType$(matching_object.type.id)List)) origin)")
    end

    if length(next_object.custom_field_values) > 0
      update_rules = [
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))""",
      ]
      
      # perform string abstraction 
      abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, prev_objects, background, grid_size))
      if abstracted_strings != []
        abstracted_string = abstracted_strings[1]
        update_rules = vcat(update_rules..., """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) (Position $(next_object.position[1]) $(next_object.position[2])))))""")
      end
      
      if length(abstracted_positions) != 0
        for abstracted_position in abstracted_positions 
          update_rules = vcat(update_rules..., 
            """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(abstracted_position))))""",
          )
          if abstracted_strings != []
            update_rules = vcat(update_rules..., 
                                """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(abstracted_string) $(abstracted_position))))""",
                               )
          end
        end
      end
      reverse(update_rules), prev_used_rules, prev_abstract_positions
    else
      update_rules = map(pos -> 
      "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(pos))))",
      abstracted_positions)
      vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))"), prev_used_rules, prev_abstract_positions
    end
  elseif isnothing(next_object)
    start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
    contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)

    if contained_in_list # object was added later; contained in addedList
      ["(= addedObjType$(prev_object.type.id)List (removeObj addedObjType$(prev_object.type.id)List (--> obj (== (.. obj id) $(object_id)))))"], prev_used_rules, prev_abstract_positions
    else # object was present at the start of the program
      ["(= obj$(object_id) (removeObj (prev obj$(object_id))))"], prev_used_rules, prev_abstract_positions
    end
  else # actual synthesis problem
    # prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_existing_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time - 1]) && (unique(object_mapping[id][1:time - 1]) != [nothing]) && (id != prev_object.id), collect(keys(object_mapping)))
    prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time - 1])[1], prev_removed_object_ids))
    foreach(obj -> obj.position = (-1, -1), prev_removed_objects)

    prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)

    #@show prev_objects
    solutions = []
    iters = 0
    prev_used_rules_index = 1
    using_prev = false
    while (iters < max_iters) # length(solutions) < 3 && 
      hypothesis_program = program_string_synth_update_rule((object_types, sort([prev_objects..., prev_object], by=(x -> x.id)), background, grid_size))
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

      expr = parseautumn(hypothesis_program)
      # global expr = striplines(compiletojulia(parseautumn(hypothesis_program)))
      hypothesis_frame_state = interpret_over_time(expr, 1).state
      
      @show hypothesis_frame_state
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

        start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
        contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)

        if occursin("color", update_rule) 
          global global_iters += 1
          start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
          prev_objects_maybe_listed = filter(obj -> !isnothing(obj) && !isnothing(object_mapping[obj.id][1]), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
          curr_objects = filter(obj -> (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == obj.type.id, collect(keys(object_mapping))) == 1), prev_objects_maybe_listed)      
          abstracted_strings = abstract_string(next_object.custom_field_values[1], (object_types, curr_objects, background, grid_size))
          
          if abstracted_strings != []
            abstracted_string = abstracted_strings[1]
            if contained_in_list # object was added later; contained in addedList
              push!(solutions, """(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List (--> obj (updateObj (prev obj) "color" $(abstracted_string))) (--> obj (== (.. obj id) $(object_id)))))""")
            else # object was present at the start of the program
              push!(solutions, """(= obj$(object_id) (updateObj (prev obj$(object_id)) "color" $(abstracted_string)))""")
            end  
          end

          if contained_in_list # object was added later; contained in addedList
            push!(solutions, """(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List (--> obj (updateObj (prev obj) "color" "$(next_object.custom_field_values[1])")) (--> obj (== (.. obj id) $(object_id)))))""")
          else # object was present at the start of the program
            push!(solutions, """(= obj$(object_id) (updateObj (prev obj$(object_id)) "color" "$(next_object.custom_field_values[1])"))""")
          end

        else
          if contained_in_list # object was added later; contained in addedList
            update_rule_parts = split(update_rule, " ")
            var1 = replace(update_rule_parts[2], "obj$(object_id)" => "obj")
            var2 = replace(join(update_rule_parts[3:end], " "), "obj$(object_id)" => "(prev obj)")
            map_lambda_func = string("(--> ", var1, " ", var2)
            # map_lambda_func = replace(string("(-->", replace(update_rule, "obj$(object_id)" => "obj")[3:end]), "(prev obj)" => "(prev obj)")
            push!(solutions, "(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List $(map_lambda_func) (--> obj (== (.. obj id) $(object_id)))))")
          else # object was present at the start of the program
            update_rule_parts = filter(x -> x != "", split(update_rule, " "))
            push!(solutions, join([update_rule_parts[1], update_rule_parts[2], replace(join(update_rule_parts[3:end], " "), "obj$(object_id)" => "(prev obj$(object_id))" )], " "))
          end
        end
      end
      
      iters += 1
      global global_iters += 1
      
    end
    if (iters == max_iters)
      println("FAILURE")
    end
    solutions, prev_used_rules, prev_abstract_positions
  end
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(observations, gridsize=16)
  object_mapping = Dict{Int, Array{Union{Nothing, Obj}}}()

  # check if observations contains frames with overlapping cells
  overlapping_cells = false # foldl(|, map(frame -> has_dups(map(cell -> (cell.position.x, cell.position.y, cell.color), frame)), observations), init=false)
  println("OVERLAPPING_CELLS")
  println(overlapping_cells)
  # construct object_types
  ## initialize object_types based on first observation frame
  if overlapping_cells
    object_types, _, background, dim = parsescene_autumn_singlecell(observations[1], gridsize)
  else
    object_types, _, background, dim = parsescene_autumn(observations[1], gridsize)
  end

  ## iteratively build object_types through each subsequent observation frame
  for time in 2:length(observations)
    if overlapping_cells
      object_types, _, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types, gridsize)
    else
      object_types, _, _, _ = parsescene_autumn_given_types(observations[time], object_types, gridsize)
    end
  end
  println("HERE 1")
  println(object_types)

  if overlapping_cells
    _, objects, _, _ = parsescene_autumn_singlecell_given_types(observations[1], object_types, gridsize)
  else
    _, objects, _, _ = parsescene_autumn_given_types(observations[1], object_types, gridsize)
  end
  println("HERE 2")
  println(object_types)

  for object in objects
    object_mapping[object.id] = [object]
  end
  for time in 2:length(observations)
    println("HERE 3")
    println(time)
    println(object_types)
    if overlapping_cells
      _, next_objects, _, _ = parsescene_autumn_singlecell_given_types(observations[time], deepcopy(object_types)) # parsescene_autumn_singlecell
    else
      _, next_objects, _, _ = parsescene_autumn_given_types(observations[time], deepcopy(object_types)) # parsescene_autumn_singlecell
    end
    # construct mapping between objects and next_objects
    for type in object_types
      curr_objects_with_type = filter(o -> o.type.id == type.id, objects)
      next_objects_with_type = filter(o -> o.type.id == type.id, next_objects)
      
      closest_objects = compute_closest_objects(curr_objects_with_type, next_objects_with_type)
      if !(isempty(curr_objects_with_type) || isempty(next_objects_with_type)) 
        while length(closest_objects) > 0
          object_id, closest_ids = closest_objects[1]
          if length(intersect(closest_ids, map(o -> o.id, next_objects_with_type))) == 1
            closest_id = intersect(closest_ids, map(o -> o.id, next_objects_with_type))[1] 
            next_object = filter(o -> o.id == closest_id, next_objects_with_type)[1]

            # remove curr and next objects from respective lists
            filter!(o -> o.id != object_id, curr_objects_with_type)
            filter!(o -> o.id != closest_id, next_objects_with_type)
            filter!(t -> t[1] != object_id, closest_objects)
            
            # add next object to mapping
            next_object.id = object_id
            push!(object_mapping[object_id], next_object)

          elseif length(intersect(closest_ids, map(o -> o.id, next_objects_with_type))) > 1
            # if there is an object with the same color as the current object among the closest objects, choose that one
            curr_object = filter(o -> o.id == object_id, curr_objects_with_type)[1]
            curr_object_color = curr_object.custom_field_values == [] ? curr_object.color : curr_object.custom_field_values[1]

            closest_ids = intersect(closest_ids, map(o -> o.id, next_objects_with_type))
            objects = map(id -> filter(o -> o.id == id, next_objects_with_type)[1], closest_ids)
            closest_objects_with_same_color = filter(o -> (o.custom_field_values == [] ? o.color : o.custom_field_values[1]) == curr_object_color, objects)
            if closest_objects_with_same_color != [] 
              closest_id = closest_objects_with_same_color[1].id 
            else
              closest_id = closest_ids[1]
            end
            next_object = filter(o -> o.id == closest_id, next_objects_with_type)[1]

            # remove curr and next objects from respective lists
            filter!(o -> o.id != object_id, curr_objects_with_type)
            filter!(o -> o.id != closest_id, next_objects_with_type)
            filter!(t -> t[1] != object_id, closest_objects)
            
            # add next object to mapping
            next_object.id = object_id
            push!(object_mapping[object_id], next_object)

          end

          if length(filter(t -> length(intersect(t[2], map(o -> o.id, next_objects_with_type))) == 1, closest_objects)) == 0
            # every remaining object to be mapped is equidistant to at least two closest objects, or zero objects
            # perform a brute force assignment
            while !isempty(curr_objects_with_type) && !isempty(next_objects_with_type)
              # do something
              object = curr_objects_with_type[1]
              next_object = next_objects_with_type[1]
              # @show curr_objects_with_type
              # @show next_objects_with_type
              curr_objects_with_type = filter(o -> o.id != object.id, curr_objects_with_type)
              if distance(object.position, next_object.position) < 5
                next_objects_with_type = filter(o -> o.id != next_object.id, next_objects_with_type)
                next_object.id = object.id
                push!(object_mapping[object.id], next_object)
              else
                push!(object_mapping[object.id], [nothing for i in time:length(observations)]...)
              end
              filter!(t -> t[1] != object.id, closest_objects)
            end
            break
          end

          # reorder closest_objects
          # collect tuples with the same minimum distance 
          equal_distance_dict = Dict()
          for y in closest_objects 
            x = (y[1], filter(id -> id in map(o -> o.id, next_objects_with_type) , y[2]))
            d = x[2] != [] ? distance(filter(o -> o.id == x[1], curr_objects_with_type)[1].position, filter(o -> o.id == x[2][1], next_objects_with_type)[1].position) : 30
            if !(d in keys(equal_distance_dict))
              equal_distance_dict[d] = [x] 
            else
              push!(equal_distance_dict[d], x)
            end
          end

          # sort tuples within each minimum distance by number of corresponding next elements; tuples with fewer next choices 
          # precede tuples with more next choices
          for key in collect(keys(equal_distance_dict))
            if key == 0 
              equal_distance_dict[key] = reverse(sort(equal_distance_dict[key], by=x -> length(x[2])))
            else
              equal_distance_dict[key] = sort(equal_distance_dict[key], by=x -> length(x[2]))
            end
          end
          # println("TIS I")
          # @show minimum(collect(keys(equal_distance_dict)))
          # @show equal_distance_dict[minimum(collect(keys(equal_distance_dict)))][1]
          closest_objects = vcat(map(key -> equal_distance_dict[key], sort(collect(keys(equal_distance_dict))))...)
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
  zero_distance_objects = []
  closest_objects = []
  for object in curr_objects
    distances = map(o -> distance(object.position, o.position), next_objects)
    if length(next_objects) != 0
      if minimum(distances) == 0
        push!(zero_distance_objects, (object.id, map(obj -> obj.id, filter(o -> distance(object.position, o.position) == minimum(distances), next_objects))))
      else
        push!(closest_objects, (object.id, map(obj -> obj.id, filter(o -> distance(object.position, o.position) == minimum(distances), next_objects))))
      end 
    end
  end
  zero_distance_objects = reverse(sort(zero_distance_objects, by=x -> length(x[2])))
  
  # collect tuples with the same minimum distance 
  equal_distance_dict = Dict()
  for x in closest_objects 
    d = distance(filter(o -> o.id == x[1], curr_objects)[1].position, filter(o -> o.id == x[2][1], next_objects)[1].position)
    if !(d in keys(equal_distance_dict))
      equal_distance_dict[d] = [x] 
    else
      push!(equal_distance_dict[d], x)
    end
  end

  # sort tuples within each minimum distance by number of corresponding next elements; tuples with fewer next choices 
  # precede tuples with more next choices
  for key in collect(keys(equal_distance_dict))
    equal_distance_dict[key] = sort(equal_distance_dict[key], by=x -> length(x[2]))
  end
  closest_objects = vcat(map(key -> equal_distance_dict[key], sort(collect(keys(equal_distance_dict))))...)
  
  # closest_objects = sort(closest_objects, by=x -> distance(filter(o -> o.id == x[1], curr_objects)[1].position, filter(o -> o.id == x[2][1], next_objects)[1].position))
  
  @show vcat(zero_distance_objects, closest_objects)
  vcat(zero_distance_objects, closest_objects)
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
  (translated_hypothesis_object == translated_actual_object) && hypothesis_object.alive
end

function singletimestepsolution_program(observations, user_events, grid_size=16)
  
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)
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
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(filter(rule -> !occursin("--> obj (prev obj)", rule), map(l -> l[1], matrix[:, time])), "\n    "))))\n  )""", update_rule_times), "\n  ")
  
  string(program_no_update_rules[1:end-2], 
        "\n\n  $(list_variables)",
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function format_matrix_function(rule, object)
  if occursin("addObj", rule) && !isnothing(object) && (filter(x -> x isa Int, object.custom_field_values) != [])
    println("am i working")
    # perform formatting 
    suffix = split(rule, "(= addedObjType$(object.type.id)List (addObj addedObjType$(object.type.id)List (ObjType$(object.type.id) ")[end]
    parts = filter(x -> x != "", split(suffix, " "))
    if "color" in map(x -> x[1], object.type.custom_fields)
      positionParts = parts[2:end]
    else
      positionParts = parts
    end
    new_rule = join(["(= addedObjType$(object.type.id)List (addObj addedObjType$(object.type.id)List (ObjType$(object.type.id)", 
                     map(x -> x isa String ? """ \"$(x)\" """ : x, object.custom_field_values)..., 
                     positionParts...], " ")
    new_rule
  else
    rule
  end
end

function singletimestepsolution_program_given_matrix_NEW(matrix, object_decomposition, grid_size=16)  
  object_types, object_mapping, background, _ = object_decomposition
  
  program_no_update_rules = program_string_synth_standard_groups((object_types, object_mapping, background, grid_size))
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""
  update_rule_times = filter(time -> join(map(l -> l[1], matrix[:, time]), "") != "", [1:size(matrix)[2]...])
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(map(id -> !occursin("--> obj (prev obj)", matrix[id, time][1]) ? (occursin("addObj", matrix[id, time][1]) ? format_matrix_function(matrix[id, time][1], object_mapping[id][time + 1]) : matrix[id, time][1]) : "", 
                          collect(1:size(matrix)[1])), "\n    "))))\n  )""", update_rule_times), "\n  ")
                        
  for type in object_types
    update_rules = replace(update_rules, "(prev addedObjType$(type.id)List)" => "addedObjType$(type.id)List")
  end

  string(program_no_update_rules[1:end-2], 
        "\n\n  $(time)", 
        "\n\n  $(update_rules)", 
        ")")
end

function has_dups(list::AbstractArray)
  length(unique(list)) != length(list) 
end

function abstract_position(position, prev_abstract_positions, user_event, object_decomposition, max_iters=50)
  object_types, prev_objects, _, _ = object_decomposition
  solutions = []
  iters = 0
  prev_used_index = 1
  using_prev = false
  while length(solutions) < 1 && iters < max_iters  
    
    if prev_used_index <= length(prev_abstract_positions)
      hypothesis_position = prev_abstract_positions[prev_used_index]
      using_prev = true
      prev_used_index += 1
    else
      using_prev = false
      hypothesis_position = generate_hypothesis_position(position, vcat(prev_objects, user_event))
      if hypothesis_position == ""
        break
      end
    end
    hypothesis_position_program = generate_hypothesis_position_program(hypothesis_position, position, object_decomposition)
    println("HYPOTHESIS PROGRAM")
    println(hypothesis_position_program)
    expr = parseautumn(hypothesis_position_program)
    # global expr = striplines(compiletojulia(parseautumn(hypothesis_position_program)))
    # #@show expr
    # module_name = Symbol("CompiledProgram$(global_iters)")
    # global expr.args[1].args[2] = module_name
    # # @show expr.args[1].args[2]
    # global mod = @eval $(expr)
    # # @show repr(mod)
    if !isnothing(user_event) && occursin("click",split(user_event, " ")[1])
      global x = parse(Int, split(user_event, " ")[2])
      global y = parse(Int, split(user_event, " ")[3])
      hypothesis_frame_state = interpret_over_time(expr, 1, [(click=AutumnStandardLibrary.Click(x, y),)]).state
    else
      hypothesis_frame_state = interpret_over_time(expr, 1).state
    end

    hypothesis_matches = hypothesis_frame_state.matchesHistory[1]
    if hypothesis_matches
      # success 
      println("SUCCESS")
      push!(solutions, hypothesis_position)
      if !(hypothesis_position in prev_abstract_positions)
        push!(prev_abstract_positions, hypothesis_position)
      end
    end

    iters += 1
    global global_iters += 1
  end
  solutions, prev_abstract_positions
end

function abstract_string(string, object_decomposition, max_iters=25)
  object_types, environment_vars, _, _ = object_decomposition
  solutions = []
  iters = 0
  if length(filter(x -> (x isa Obj) && length(x.type.custom_fields) > 0, environment_vars)) != 0
    while length(solutions) != 1 && iters < max_iters  
      hypothesis_string = generate_hypothesis_string(string, environment_vars, object_types)
      hypothesis_string_program = generate_hypothesis_string_program(hypothesis_string, string, object_decomposition)
      println("HYPOTHESIS PROGRAM")
      println(hypothesis_string_program)
      expr = parseautumn(hypothesis_string_program)
      # global expr = striplines(compiletojulia(parseautumn(hypothesis_string_program)))
      #@show expr
      # module_name = Symbol("CompiledProgram$(global_iters)")
      # global expr.args[1].args[2] = module_name
      # # @show expr.args[1].args[2]
      # global mod = @eval $(expr)
      # @show repr(mod)
      hypothesis_frame_state = interpret_over_time(expr, 1).state
      hypothesis_matches = hypothesis_frame_state.matchesHistory[1]
      if hypothesis_matches
        # success 
        push!(solutions, hypothesis_string)
      end

      iters += 1
      global global_iters += 1
    end
  end
  solutions
end

function generate_on_clauses(matrix, object_decomposition, user_events, grid_size=16)
  on_clauses = []
  global_var_dict = Dict()
  object_types, object_mapping, background, dim = object_decomposition

  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  # filtered_matrix = filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition)[1]
  
  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  filtered_matrix = filter_update_function_matrix_multiple(deepcopy(matrix), object_decomposition)[1]

  anonymized_filtered_matrix = deepcopy(filtered_matrix)
  for i in 1:size(matrix)[1]
    for j in 1:size(matrix)[2]
      anonymized_filtered_matrix[i,j] = [replace(filtered_matrix[i, j][1], "id) $(i)" => "id) x")]
    end
  end
  
  global_object_decomposition = object_decomposition
  global_state_update_times_dict = Dict(1 => ["" for x in 1:length(user_events)])
  object_specific_state_update_times_dict = Dict()

  global_state_update_on_clauses = []
  object_specific_state_update_on_clauses = []
  state_update_on_clauses = []
  
  global_event_vector_dict = Dict()

  for object_type in object_types
    type_id = object_type.id
    object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == object_type.id, collect(keys(object_mapping))))

    all_update_rules = filter(rule -> rule != "", unique(vcat(vec(anonymized_filtered_matrix[object_ids, :])...)))

    update_rule_set = vcat(filter(r -> r != "", vcat(map(id -> map(x -> replace(x[1], "obj id) $(id)" => "obj id) x"), filtered_matrix[id, :]), object_ids)...))...)

    addObj_rules = unique(filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...)))
    addObj_times_dict = Dict()

    for rule in addObj_rules 
      addObj_times_dict[rule] = sort(unique(vcat(map(id -> findall(r -> r == rule, vcat(filtered_matrix[id, :]...)), object_ids)...)))
    end
    
    group_addObj_rules = false
    if length(unique(collect(values(addObj_times_dict)))) == 1
      group_addObj_rules = true
      all_update_rules = filter(r -> !(r in addObj_rules), all_update_rules)
      push!(all_update_rules, addObj_rules[1])
    end

    all_update_rules = reverse(sort(all_update_rules, by=x -> count(y -> y == x, update_rule_set)))
    for update_rule in all_update_rules 
      @show global_object_decomposition
      if update_rule != "" && !is_no_change_rule(update_rule)
        println("UPDATE_RULEEE")
        println(update_rule)
        events, event_is_globals, event_vector_dict, observation_data_dict = generate_event(update_rule, object_ids[1], object_ids, matrix, filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, grid_size)
        global_event_vector_dict = event_vector_dict
        println("EVENTS")
        println(events)
        @show event_vector_dict
        @show observation_data_dict
        if events != []
          event = events[1]
          event_is_global = event_is_globals[1]
          on_clause = format_on_clause(replace(update_rule, ".. obj id) x" => ".. obj id) $(object_ids[1])"), event, object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, event_is_global)
          push!(on_clauses, on_clause)
        else # handle construction of new state

          # determine whether to search for new global state or new object-specific state
          search_for_global_state = true
          for time in 1:length(user_events)
            observation_values = map(id -> observation_data_dict[id][time], object_ids)
            if (0 in observation_values) && (1 in observation_values)
              search_for_global_state = false
            end
          end

          if search_for_global_state # search for global state
            if occursin("addObj", update_rule)
              object_trajectories = map(id -> anonymized_filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.id, collect(keys(object_mapping))))
              true_times = vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...)
              object_trajectory = []
            else 
              ids_with_rule = map(idx -> object_ids[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] == update_rule, anonymized_filtered_matrix[id, :]), object_ids)))
              trajectory_lengths = map(id -> length(unique(filter(x -> x != "", anonymized_filtered_matrix[id, :]))), ids_with_rule)
              max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
              object_id = ids_with_rule[max_index]
              object_trajectory = anonymized_filtered_matrix[object_id, :]
              true_times = findall(rule -> rule == update_rule, vcat(object_trajectory...))
            end
  
            on_clause, new_global_var_dict, new_state_update_times_dict = generate_new_state(update_rule, true_times, global_event_vector_dict, object_trajectory, global_var_dict, global_state_update_times_dict)
            @show on_clause 
            @show new_state_update_times_dict 
            @show new_global_var_dict 
  
            on_clause = format_on_clause(split(replace(on_clause, ".. obj id) x" => ".. obj id) $(object_ids[1])"), "\n")[2][1:end-1], replace(split(on_clause, "\n")[1], "(on " => ""), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, true)
            push!(on_clauses, on_clause)
            global_var_dict = new_global_var_dict 
            global_state_update_on_clauses = vcat(map(k -> filter(x -> x != "", new_state_update_times_dict[k]), collect(keys(new_state_update_times_dict)))...) # vcat(state_update_on_clauses..., filter(x -> x != "", new_state_update_times)...)
            state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
            global_state_update_times_dict = new_state_update_times_dict
            
            @show global_var_dict 
            @show state_update_on_clauses 
            @show global_state_update_times_dict
            @show object_specific_state_update_times_dict

            for event in collect(keys(global_event_vector_dict))
              if occursin("globalVar", event)
                delete!(global_event_vector_dict, event)
              end
            end
  
          else # search for object-specific state
            update_function_times_dict = Dict()
            for object_id in object_ids 
              update_function_times_dict[object_id] = findall(x -> x == 1, observation_data_dict[object_id])
            end
            on_clause, new_state_update_on_clauses, new_object_decomposition, new_object_specific_state_update_times_dict = generate_new_object_specific_state(update_rule, update_function_times_dict, event_vector_dict, type_id, global_object_decomposition, object_specific_state_update_times_dict)            
            
            @show new_object_specific_state_update_times_dict
            object_specific_state_update_times_dict = new_object_specific_state_update_times_dict

            # on_clause = format_on_clause(split(on_clause, "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), "(== (.. obj id) x)" => "(== (.. obj id) $(object_ids[1]))"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false)
            push!(on_clauses, on_clause)

            global_object_decomposition = new_object_decomposition
            object_types, object_mapping, background, dim = global_object_decomposition
            
            println("UPDATEEE")
            @show global_object_decomposition

            # new_state_update_on_clauses = map(x -> format_on_clause(split(x, "\n")[2][1:end-1], replace(split(x, "\n")[1], "(on " => ""), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false), new_state_update_on_clauses)
            object_specific_state_update_on_clauses = unique(vcat(object_specific_state_update_on_clauses..., new_state_update_on_clauses...))
            state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
            for event in collect(keys(global_event_vector_dict))
              if occursin("field1", event)
                delete!(global_event_vector_dict, event)
              end
            end

          end

        end

      end

    end
  end
  [on_clauses..., state_update_on_clauses...], global_object_decomposition, global_var_dict 
end

function format_on_clause(update_rule, event, object_id, object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, event_is_global)
  if occursin("addObj", update_rule) # handle addition of object rules 
    if group_addObj_rules # several objects are added simultaneously
      on_clause = "(on $(event) (let ($(join(addObj_rules, "\n")))))"
    else # addition of just one object
      on_clause = "(on $(event) $(update_rule))"
    end
  else # handle other update rules
    if event_is_global 
      if occursin("(--> obj (== (.. obj id) $(object_id)))", update_rule) 
        # event is global, but objects in update rule are in list  
        reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj true)")
        on_clause = "(on $(event) $(reformatted_rule))"
      else # event is global and object in update rule is not in a list
        on_clause = "(on $(event) $(update_rule))"
      end
    else # event is object-specific
      if occursin("(--> obj (== (.. obj id) $(object_id)))", update_rule) # update rule is object-specific
        reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
        reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj $(reformatted_event))")
        
        second_reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))" => "(prev addedObjType$(type_id)List)")
        
        on_clause = "(on $(second_reformatted_event) $(reformatted_rule))"
      else
        on_clause = "(on $(event) $(update_rule))"
      end
    end
  end
  on_clause 
end

"Select one update function from each matrix cell's update function set, which may contain multiple update functions"
function filter_update_function_matrix_multiple(matrix, object_decomposition; multiple = true)
  object_types, object_mapping, _, _ = object_decomposition

  new_matrices = []
  type_id_and_colors = []
  for type in object_types 
    if length(type.custom_fields) == 0
      push!(type_id_and_colors, (type.id, nothing))
    else
      for color in type.custom_fields[1][3]
        push!(type_id_and_colors, (type.id, color))
      end
    end
  end

  num_permutations = multiple ? (2^(length(type_id_and_colors)) - 1) : 0
  standard_update_function_lengths_dict = Dict()
  
  # construct same_type_update_function_sets_dict: 
  # count frequency of an update function across a type if the type has no color state,
  # and within the same color state of a type otherwise
  same_type_update_function_sets_dict = Dict()
  for type in object_types 
    type_id = type.id
      
    if length(type.custom_fields) == 0 # object has no color field
      same_type_update_function_set = []
      for other_object_id in 1:size(matrix)[1] 
        other_object_type = filter(object -> !isnothing(object), object_mapping[other_object_id])[1].type
        if other_object_type.id == type_id 
          update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), vcat(matrix[other_object_id, :]...))
          same_type_update_function_set = vcat(same_type_update_function_set..., update_rules...)
        end
      end
      same_type_update_function_sets_dict[type_id] = same_type_update_function_set
    else # object has color field; split by color
      same_type_update_function_sets = Dict()
      for color in type.custom_fields[1][3] 
        same_type_update_function_sets[color] = []
      end
      same_type_update_function_sets[nothing] = []
      @show same_type_update_function_sets 
      for other_object_id in 1:size(matrix)[1]

        other_object_type = filter(object -> !isnothing(object), object_mapping[other_object_id])[1].type
        
        if other_object_type.id == type.id
          @show other_object_id

          for time in 1:size(matrix)[2]
            if !isnothing(object_mapping[other_object_id][time])
              color = object_mapping[other_object_id][time].custom_field_values[1]
              @show color

              if !isnothing(object_mapping[other_object_id][time + 1]) && (object_mapping[other_object_id][time + 1].custom_field_values[1] != color)
                # color change update rules are placed in the `nothing` category
                update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
                same_type_update_function_sets[nothing] = vcat(same_type_update_function_sets[nothing]..., update_rules...)
              else
                update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
                same_type_update_function_sets[color] = vcat(same_type_update_function_sets[color]..., update_rules...)
              end

            elseif !isnothing(object_mapping[other_object_id][time + 1])
              # object was just added; update functions are addObj 
              update_rules = map(s -> replace(s, "id) $(other_object_id)" => "id) x"), matrix[other_object_id, time])
              same_type_update_function_sets[nothing] = vcat(same_type_update_function_sets[nothing]..., update_rules...)
            end
          end
        end
      end      
      same_type_update_function_sets_dict[type_id] = same_type_update_function_sets
    end
  end



  for perm in 0:num_permutations
    bits = reverse(bitstring(perm))
    new_matrix = deepcopy(matrix)

    # for each row (trajectory) in the update function matrix, filter down its update function sets
    for object_id in 1:size(matrix)[1] 
      object_type = filter(object -> !isnothing(object), object_mapping[object_id])[1].type
      
      if length(object_type.custom_fields) == 0 # type has no color field
        same_type_update_function_set = same_type_update_function_sets_dict[object_type.id]

        # perform filtering 

        # multiplicity handling: if bit_value == 1, then consider second-most frequent update function instead of first
        type_index = findall(x -> x[1] == object_type.id, type_id_and_colors)[1]
        bit_value = parse(Int, bits[type_index])

        for time in 1:size(matrix)[2]
          update_functions = unique(map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time]))
          if length(update_functions) > 1 
            update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_set), update_functions)

            if length(unique(map(x -> count(y -> y == x, same_type_update_function_set), update_functions))) == 1 
              global_sorted_update_functions = update_functions
            else
              global_sorted_update_functions = reverse(sort(unique(same_type_update_function_set), by=x -> count(y -> y == x, same_type_update_function_set)))
            end
            
            if (bit_value == 1) && length(global_sorted_update_functions) > 1
              # swap first and second elements of global_sorted_update_functions
              temp = global_sorted_update_functions[2]
              global_sorted_update_functions[2] = global_sorted_update_functions[1]
              global_sorted_update_functions[1] = temp 
            end

            top_function = global_sorted_update_functions[1]
            if top_function in update_functions 
              max_id = findall(x -> x == top_function, update_functions)[1]
            else
              max_id = findall(x -> x == maximum(update_function_frequencies), update_function_frequencies)[1]
            end

            new_matrix[object_id, time] = [update_functions[max_id]]
          end
        end

      else # type has color field 
        same_type_update_function_sets = same_type_update_function_sets_dict[object_type.id]
        # perform filtering
        for time in 1:size(matrix)[2]
            update_functions = unique(map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time]))
          if length(update_functions) > 1
            object = object_mapping[object_id][time]
            if !isnothing(object)
              color = object.custom_field_values[1]

              # multiplicity handling: if bit_value == 1, then consider second-most frequent update function instead of first
              type_index = findall(x -> x[1] == object_type.id && x[2] == color, type_id_and_colors)[1]
              bit_value = parse(Int, bits[type_index])

              update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_sets[color]), update_functions)
              if length(unique(map(x -> count(y -> y == x, same_type_update_function_sets_dict[object_type.id][color]), update_functions))) == 1 
                global_sorted_update_functions = update_functions
              else
                global_sorted_update_functions = reverse(sort(unique(same_type_update_function_sets_dict[object_type.id][color]), by=x -> count(y -> y == x, same_type_update_function_sets_dict[object_type.id][color])))
              end
              
              if (bit_value == 1) && length(global_sorted_update_functions) > 1
                # swap first and second elements of global_sorted_update_functions
                temp = global_sorted_update_functions[2]
                global_sorted_update_functions[2] = global_sorted_update_functions[1]
                global_sorted_update_functions[1] = temp 
              end

              top_function = global_sorted_update_functions[1]
              if top_function in update_functions 
                max_id = findall(x -> x == top_function, update_functions)[1]
              else
                max_id = findall(x -> x == maximum(update_function_frequencies), update_function_frequencies)[1]
              end

            else
              update_function_frequencies = map(func -> count(x -> x == func, same_type_update_function_sets[nothing]), update_functions)
              max_id = findall(x -> x == maximum(update_function_frequencies), update_function_frequencies)[1]
            end
            new_matrix[object_id, time] = [update_functions[max_id]]
          end
        end

      end

    end

    for object_id in 1:size(new_matrix)[1]
      new_matrix[object_id, :] = map(list -> [replace(list[1], " id) $(object_id)" => " id) x")], new_matrix[object_id, :])
    end
    push!(new_matrices, new_matrix)
    
    # construct standard_update_function_lengths_dict (used to determine if 2nd-most-frequent update functions should be tried)
    if length(new_matrices) == 1
      standard_matrix = new_matrices[1] 
      for type_id_and_color in type_id_and_colors 
        # count all matrix cells with this type and check if they all have the same update function 
        # (except for adding, removing, and color change); if not, then use 2nd most-frequent update rule   
        type_id, color = type_id_and_color 
        if isnothing(color) 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(1:size(matrix)[1]))
          standard_update_functions = unique(filter(f -> (f != "") && !occursin("addObj", f) && !occursin("removeObj", f), vcat(vcat(map(id -> standard_matrix[id, :], object_ids_with_type)...)...)))
        else 
          object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(1:size(matrix)[1]))
          standard_update_functions = vcat(map(obj_id -> vcat(map(filtered_t -> standard_matrix[obj_id, filtered_t], filter(t -> !isnothing(object_mapping[obj_id][t]) && object_mapping[obj_id][t].custom_field_values[1] == color, collect(1:size(matrix)[2])))...), object_ids_with_type)...)
          standard_update_functions = unique(filter(f -> (f != "") && !occursin("addObj", f) && !occursin("removeObj", f) && !occursin("color", f), standard_update_functions))
        end
        standard_update_function_lengths_dict[type_id_and_color] = length(standard_update_functions)
      end
    end
  end
  
  for new_matrix in new_matrices 
    for object_id in 1:size(new_matrix)[1]
      new_matrix[object_id, :] = map(list -> [replace(list[1], " id) x" => " id) $(object_id)")], new_matrix[object_id, :])
    end  
  end
  @show same_type_update_function_sets_dict
  unique(new_matrices)
end

function pre_filter_with_direction_biases(matrix, user_events, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition 

  new_matrix = deepcopy(matrix)

  for direction in ["left", "right", "up", "down"]
    event_times = findall(event -> event == direction, user_events)
    for object_id in 1:size(matrix)[1]
      type_id = filter(x -> !isnothing(x), object_mapping[object_id])[1].type.id
      other_object_ids = sort(filter(id -> (id != object_id) && filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping))))
      
      trajectory = matrix[object_id, :]
      direction_update_at_every_time = foldl(&, map(list -> occursin(string("move", uppercasefirst(direction), "NoCollision"), join(list, "")), trajectory), init=true)
      for event_time in event_times 
        direction_update_at_event_time = occursin(string("move", uppercasefirst(direction), "NoCollision"), join(trajectory[event_time], ""))

        deltas = [(!isnothing(object_mapping[id][event_time]) && 
                   !isnothing(object_mapping[id][event_time + 1]) &&
                   (object_mapping[id][event_time].position != object_mapping[id][event_time + 1].position)) 
                   for id in other_object_ids]

        if direction_update_at_event_time && !direction_update_at_every_time && !(1 in deltas)
          new_matrix[object_id, event_time] = filter(rule -> occursin(string("move", uppercasefirst(direction)), rule), trajectory[event_time])
        end
      end
    end
  end

  deepcopy(new_matrix)
end

# generate_event, generate_hypothesis_position, generate_hypothesis_position_program 
## tricky things: add user events, and fix environment 
global hypothesis_state = nothing
function generate_event(anonymized_update_rule, object_id, object_ids, matrix, filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, event_vector_dict, grid_size, min_events=1, max_iters=400)
  println("GENERATE EVENT")
  @show object_decomposition
  object_types, object_mapping, background, dim = object_decomposition 
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  #println("WHAT 1")
  #@show length(vcat(object_trajectory...))

  # construct observed update function times (observation_data)
  observation_data_dict = Dict()

  # construct sorted distinct_update_rules 
  all_update_rules = vcat(filter(r -> r != "", vcat(map(id -> map(x -> replace(x[1], "obj id) $(id)" => "obj id) x"), filtered_matrix[id, :]), object_ids)...))...)
  distinct_update_rules = unique(all_update_rules)
  distinct_update_rules = reverse(sort(distinct_update_rules, by=x -> count(y -> y == x, all_update_rules)))

  for object_id in object_ids 
    object_trajectory = filtered_matrix[object_id, :]
  
    # de-anonymize update_rule 
    # update_rule = replace(replace(anonymized_update_rule, "id) x" => "id) $(object_id)"), "objX" => "obj$(object_id)")
    update_rule = replace(anonymized_update_rule, "id) x" => "id) $(object_id)")

    if occursin("addObj", update_rule)
      object_trajectories = map(id -> filtered_matrix[id, :], filter(k -> filter(obj -> !isnothing(obj), object_mapping[k])[1].type.id == filter(obj -> !isnothing(obj), object_mapping[object_id])[1].type.id, collect(keys(object_mapping))))
      true_times = vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...)
    else
      true_times = findall(rule -> rule == update_rule, vcat(object_trajectory...))
    end
    @show true_times 
    @show user_events
    true_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], true_times)
    false_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], findall(rule -> rule != update_rule, vcat(object_trajectory...)))
  
    observation_data = map(time -> time in true_times ? 1 : 0, collect(1:length(user_events)))
    update_rule_index = findall(rule -> replace(rule, "obj id) x" => "obj id) $(object_id)") == update_rule, distinct_update_rules) == [] ? -1 : findall(rule -> replace(rule, "obj id) x" => "obj id) $(object_id)") == update_rule, distinct_update_rules)[1]
    #println("WHAT 3")
  
    if !occursin("addObj", update_rule)
      for time in 1:length(object_trajectory)
        rule = object_trajectory[time][1]
        #@show rule
        #@show distinct_update_rules
        if (rule == "") || (findall(r -> replace(r, "obj id) x" => "obj id) $(object_id)") == rule, distinct_update_rules)[1] > update_rule_index) 
          observation_data[time] = -1
        elseif (findall(r -> replace(r, "obj id) x" => "obj id) $(object_id)") == rule, distinct_update_rules)[1] < update_rule_index)
          observation_data[time] = 0
        end
  
        if occursin("\"color\" \"", update_rule)
          if !isnothing(object_mapping[object_id][time + 1]) && occursin(object_mapping[object_id][time + 1].custom_field_values[1], update_rule) && observation_data[time] != 1 # is_no_change_rule(rule)
            observation_data[time] = -1
          end
        end
      end
    end
    observation_data_dict[object_id] = observation_data
  end

  println("----------------> LOOK AT ME")
  @show object_decomposition

  tried_compound_events = false 

  found_events = []
  final_event_globals = []
  events_to_try = unique(vcat(gen_event_bool(object_decomposition, "x", filter(e -> e != "", unique(user_events)), global_var_dict), collect(keys(event_vector_dict))))
  while true
    for event in events_to_try 
      event_is_global = !occursin(".. obj id)", event)
      anonymized_event = event # replace(event, ".. obj id) $(object_ids[1])" => ".. obj id) x")
      if !(anonymized_event in keys(event_vector_dict)) || !(event_vector_dict[anonymized_event] isa AbstractArray) && intersect(object_ids, collect(keys(event_vector_dict[anonymized_event]))) == [] # event values are not stored
        
        if event_is_global # if the event is global, only need to evaluate the event on one object_id 
          event_object_ids = object_ids[1]
        else # otherwise, need to evaluate the event on all object_ids
          event_object_ids = collect(keys(object_mapping)) # object_ids; evaluate even for ids not with the current rule's type, for uniformity!!
          event_vector_dict[anonymized_event] = Dict()
        end
  
        for object_id in event_object_ids 
          formatted_event = replace(event, ".. obj id) x" => ".. obj id) $(object_id)")
          program_str = singletimestepsolution_program_given_matrix_NEW(matrix, object_decomposition, grid_size) # CHANGE BACK TO DIM LATER
          program_tokens = split(program_str, """(: time Int)\n  (= time (initnext 0 (+ time 1)))""")
  
          # elements to insert between program_tokens[1] and program_tokens[2]
          insertions = ["""(: time Int)\n  (= time (initnext 0 (+ time 1)))""", "\n\t (: event Bool) \n\t (= event (initnext false $(formatted_event)))\n"]
  
          # insert globalVar initialization
          inits = []
          for key in collect(keys(global_var_dict))
            global_var_init_val = global_var_dict[key][1]
            push!(inits, """\n\t (: globalVar$(key) Int)\n\t (= globalVar$(key) (initnext $(global_var_init_val) (prev globalVar$(key))))""")
          end
          insertions = [insertions[1], inits..., insertions[2]]
  
          program_str = string(program_tokens[1], insertions..., program_tokens[2])
  
          # insert state update on_clauses 
          if (state_update_on_clauses != [])
            state_update_on_clauses_str = join(reverse(state_update_on_clauses), "\n  ")
            program_str = string(program_str[1:end-1], state_update_on_clauses_str, ")")
          end
                    
          println(program_str)
          global expr = parseautumn(program_str)
          # global expr = striplines(compiletojulia(parseautumn(program_str)))
          # #@show expr
          # module_name = Symbol("CompiledProgram$(global_iters)")
          # global expr.args[1].args[2] = module_name
          # # @show expr.args[1].args[2]
          # global mod = @eval $(expr)
          # # @show repr(mod)
    
          user_events_for_interpreter = []
          for e in user_events 
            if isnothing(e) || e == "nothing"
              push!(user_events_for_interpreter, Dict())
            elseif e == "left"
              push!(user_events_for_interpreter, Dict(:left => true))
            elseif e == "right"
              push!(user_events_for_interpreter, Dict(:right => true))
            elseif e == "up"
              push!(user_events_for_interpreter, Dict(:up => true))
            elseif e == "down"
              push!(user_events_for_interpreter, Dict(:down => true))
            else
              global x = parse(Int, split(e, " ")[2])
              global y = parse(Int, split(e, " ")[3])
              push!(user_events_for_interpreter, Dict(:click => AutumnStandardLibrary.Click(x, y)))
            end
          end
          hypothesis_state = interpret_over_time(expr, length(user_events), user_events_for_interpreter).state
    
          # global hypothesis_state = @eval mod.init(nothing, nothing, nothing, nothing, nothing)
          # @show hypothesis_state
          # for time in 1:length(user_events)
          #   @show time
          #   if user_events[time] != nothing && (split(user_events[time], " ")[1] in ["click", "clicked"])
          #     global x = parse(Int, split(user_events[time], " ")[2])
          #     global y = parse(Int, split(user_events[time], " ")[3])
    
          #     global hypothesis_state = @eval mod.next(hypothesis_state, mod.Click(x, y), nothing, nothing, nothing, nothing)
          #   elseif user_events[time] == "left"
          #     global hypothesis_state = @eval mod.next(hypothesis_state, nothing, mod.Left(), nothing, nothing, nothing)
          #   elseif user_events[time] == "right"
          #     global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, mod.Right(), nothing, nothing)
          #   elseif user_events[time] == "up"
          #     global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, mod.Up(), nothing)
          #   elseif user_events[time] == "down"
          #     global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, nothing, mod.Down())
          #   else
          #     global hypothesis_state = @eval mod.next(hypothesis_state, nothing, nothing, nothing, nothing, nothing)
          #   end
          # end
          event_values = map(key -> hypothesis_state.eventHistory[key], sort(collect(keys(hypothesis_state.eventHistory))))[2:end]
  
          # update event_vector_dict 
          if event_is_global 
            event_vector_dict[anonymized_event] = event_values
          else
            event_vector_dict[anonymized_event][object_id] = event_values
          end
        end
      end
      event_values_dicts = []
      if event_vector_dict[anonymized_event] isa AbstractArray 
        event_values_dict = Dict()
        for object_id in object_ids 
          event_values_dict[object_id] = event_vector_dict[anonymized_event]
        end
        push!(event_values_dicts, (event, event_values_dict))
      else
        # add object-specific event values
        event_values_dict = Dict() 
        for object_id in object_ids 
          event_values_dict[object_id] = event_vector_dict[anonymized_event][object_id]
        end
        push!(event_values_dicts, (event, event_values_dict))
        
        for object_id in object_ids 
          # these object-specific events may be treated as global events; each mapping in object_specific dictionary contains same array
          object_specific_event = replace(event, "obj id) x" => "obj id) $(object_id)")
          object_specific_event_values_dict = Dict() 
          for object_id_2 in object_ids 
            object_specific_event_values_dict[object_id_2] = event_values_dict[object_id] # array 
          end
          push!(event_values_dicts, (object_specific_event, object_specific_event_values_dict))
        end
      end
  
      # check if event_values match true_times/false_times 
      @show observation_data_dict
      @show event_values_dicts
      
      equals = true
      for tuple in event_values_dicts 
        e, event_values_dict = tuple
        for object_id in object_ids 
          observation_data = observation_data_dict[object_id]
          event_values = event_values_dict[object_id]  
          for time in 1:length(observation_data)
            if (observation_data[time] != event_values[time]) && (observation_data[time] != -1)
              equals = false
              println("NO SUCCESS")
              break
            end
          end
          if !equals # if the event fails for one of the object_ids, no need to check other object_ids
            break
          end
        end
        if equals # if the event works for all of the object_ids, no need to check other events  
          event = e 
          break
        end
      end
  
      if equals
        push!(found_events, event)
        println("SUCCESS")
        if occursin("obj id) x", event)
          push!(final_event_globals, false)
        else
          push!(final_event_globals, true)
        end
        break
      end
    end

    if length(found_events) < min_events && !tried_compound_events
      events_to_try = construct_compound_events(event_vector_dict)
      tried_compound_events = true
    else
      break
    end
  end
  @show found_events
  found_events, final_event_globals, event_vector_dict, observation_data_dict    
end

# generation of new global state 
function generate_new_state(update_rule, update_function_times, event_vector_dict, object_trajectory, global_var_dict, state_update_times_dict)
  println("GENERATE_NEW_STATE")
  @show update_rule 
  @show update_function_times
  @show event_vector_dict 
  @show object_trajectory 
  @show global_var_dict 
  @show state_update_times_dict   
  new_state_update_times_dict = deepcopy(state_update_times_dict)

  events = filter(e -> event_vector_dict[e] isa Array, collect(keys(event_vector_dict)))

  # compute best co-occurring event (i.e. event with fewest false positives)
  co_occurring_events = []
  for event in events
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if repr(sort(intersect(event_times, update_function_times))) == repr(sort(update_function_times))
      push!(co_occurring_events, (event, length([time for time in event_times if !(time in update_function_times)])))
    end 
  end
  co_occurring_event = sort(co_occurring_events, by=x->x[2])[1][1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  # initialize global_var_dict and get global_var_value
  if length(collect(keys(global_var_dict))) == 0 
    global_var_dict[1] = ones(Int, length(state_update_times_dict[1]))
    global_var_value = 1
    global_var_id = 1
  else # check if all update function times match with one value of global_var_dict 
    global_var_id = -1
    for key in collect(keys(global_var_dict))
      values = global_var_dict[key]
      if length(unique(map(t -> values[t], update_function_times))) == 1
        global_var_id = key
        break
      end
    end
  
    if global_var_id == -1 # update function times crosses state lines 
      # initialize new global var 
      max_key = maximum(collect(keys(global_var_dict)))
      global_var_dict[max_key + 1] = ones(Int, length(state_update_times_dict[1]))
      global_var_id = max_key + 1 

      new_state_update_times_dict[global_var_id] = ["" for i in 1:length(global_var_dict[max_key])]
    end
    global_var_value = maximum(global_var_dict[global_var_id])  
  end

  true_positive_times = update_function_times # times when co_occurring_event happened and update_rule happened 
  false_positive_times = [] # times when user_event happened and update_rule didn't happen

  # construct true_positive_times and false_positive_times 
  for time in 1:length(user_events)
    if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
      if occursin("addObj", update_rule)
        push!(false_positive_times, time)
      elseif (object_trajectory[time][1] != "") && !(occursin("addObj", object_trajectory[time][1]))
        push!(false_positive_times, time)
      end     
    end
  end

  # compute ranges in which to search for events 
  ranges = []
  augmented_true_positive_times = map(t -> (t, global_var_value), true_positive_times)
  augmented_false_positive_times = map(t -> (t, global_var_value + 1), false_positive_times)
  augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

  for i in 1:(length(augmented_positive_times)-1)
    prev_time, prev_value = augmented_positive_times[i]
    next_time, next_value = augmented_positive_times[i + 1]
    if prev_value != next_value
      push!(ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
    end
  end

  # add ranges that interface between global_var_value and lower values
  if global_var_value > 1
    for time in 1:(length(state_update_times_dict[global_var_id]) - 1)
      if length(intersect(map(t -> t[1], augmented_positive_times), [time, time + 1])) == 1
        prev_val = global_var_dict[global_var_id][time]
        next_val = global_var_dict[global_var_id][time + 1]

        if (prev_val < global_var_value) && (next_val == global_var_value)
          if (filter(t -> t[1] == time + 1, augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, augmented_positive_times)[1][2] != global_var_value)
            new_value = filter(t -> t[1] == time + 1, augmented_positive_times)[1][2]
            push!(ranges, ((time, prev_val), (time + 1, new_value)))        
          else
            push!(ranges, ((time, prev_val), (time + 1, next_val)))        
          end

        elseif (prev_val == global_var_value) && (next_val < global_var_value)
          if (filter(t -> t[1] == time, augmented_positive_times) != []) && (filter(t -> t[1] == time, augmented_positive_times)[1][2] != global_var_value)
            new_value = filter(t -> t[1] == time, augmented_positive_times)[1][2]
            push!(ranges, ((time, new_value), (time + 1, next_val)))        
          else
            push!(ranges, ((time, prev_val), (time + 1, next_val)))        
          end
        end
      end
    end
  end

  # filter ranges where both the range's start and end times are already included
  new_ranges = []
  for range in ranges
    start_tuples = map(range -> range[1], filter(r -> r != range, ranges))
    end_tuples = map(range -> range[2], filter(r -> r != range, ranges))
    if !((range[1] in start_tuples) && (range[2] in end_tuples))
      push!(new_ranges, range)      
    end
  end

  grouped_ranges = group_ranges(new_ranges)

  # while there are ranges that need to be explained, search for explaining events within them
  while length(grouped_ranges) > 0 
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
    events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value)
    if events_in_range != [] # event with zero false positives found
      if filter(tuple -> !occursin("true", tuple[1]), events_in_range) != []
        state_update_event, event_times = filter(tuple -> !occursin("true", tuple[1]), events_in_range)[1]
      else
        state_update_event, event_times = events_in_range[1]
      end

      # construct state update on-clause
      state_update_on_clause = "(on $(state_update_event)\n$(state_update_function))"
      
      # add to state_update_times 
      @show event_times
      @show state_update_on_clause  
      for time in event_times 
        new_state_update_times_dict[global_var_id][time] = state_update_on_clause
      end

    else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
      # find co-occurring event with fewest false positives 
      false_positive_events = find_state_update_events_false_positives(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value)
      false_positive_events_with_state = filter(e -> occursin("globalVar$(global_var_id)", e[1]), false_positive_events) # want the most specific events in the false positive case
      
      events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
      if events_without_true != []
        false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
      else
        false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1] 
      end

      # construct state update on-clause
      state_update_on_clause = "(on $(false_positive_event)\n$(state_update_function))"
      
      # add to state_update_times
      for time in true_positive_times 
        new_state_update_times_dict[global_var_id][time] = state_update_on_clause            
      end
      
      augmented_positive_times_labeled = map(tuple -> (tuple[1], tuple[2], "update_function"), augmented_positive_times) 
      for time in false_positive_times  
        push!(augmented_positive_times_labeled, (time, max_global_var_value + 1, "event"))
      end
      same_time_tuples = Dict()
      for tuple in augmented_positive_times_labeled
        time = tuple[1] 
        if time in collect(keys((same_time_tuples))) 
          push!(same_time_tuples[time], tuple)
        else
          same_time_tuples[time] = [tuple]
        end
      end

      for time in collect(keys((same_time_tuples))) 
        same_time_tuples[time] = reverse(sort(same_time_tuples[time], by=x -> length(x[3]))) # ensure all event tuples come *after* the update_function tuples
      end
      augmented_positive_times_labeled = vcat(map(t -> same_time_tuples[t], sort(collect(keys(same_time_tuples))))...)
      # augmented_positive_times_labeled = sort(augmented_positive_times_labeled, by=x->x[1])

      # relabel false positive times 
      # based on relabeling, relabel other existing labels if necessary 
      for tuple_index in 1:length(augmented_positive_times_labeled)
        tuple = augmented_positive_times_labeled[tuple_index]
        if tuple[3] == "event"
          for prev_index in (tuple_index-1):-1:1
            prev_tuple = augmented_positive_times_labeled[prev_index]

            if prev_tuple[2] == global_var_value 
              break
            end

            if (prev_tuple[2] > global_var_value) && (prev_tuple[3] == "update_function")
              augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
            end
          end
        end
      end
      augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))      

      # compute new ranges and find state update events
      new_ranges = [] 
      for i in 1:(length(augmented_positive_times)-1)
        prev_time, prev_value = augmented_positive_times[i]
        next_time, next_value = augmented_positive_times[i + 1]
        if prev_value != next_value
          if length(unique(new_state_update_times_dict[global_var_id][prev_time:next_time-1])) == 1 && unique(new_state_update_times_dict[global_var_id][prev_time:next_time-1])[1] == ""
            # if there are no state update functions within this range, add it to new_ranges
            push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
          elseif intersect(true_positive_times, collect(prev_time:next_time-1)) == []
            # if the state_update_function in this range is not among those just added (which are correct), add range to new_ranges
            @show prev_time 
            @show prev_value 
            @show next_time 
            @show next_value 
            
            on_clause_index = findall(x -> x != "", new_state_update_times_dict[global_var_id][prev_time:next_time-1])[1]
            # on_clause = new_state_update_times[prev_time:next_time-1][on_clause_index]
            
            # on_clause_event = split(on_clause, "\n")[1]
            # on_clause_function = split(on_clause, "\n")[2]

            # if occursin("(== (prev globalVar1) ", on_clause_event)
            #   on_clause_segments = split(on_clause_event, "(== (prev globalVar1) ")
            #   on_clause_event = string(on_clause_segments[1], "(== (prev globalVar1) ", prev_value, on_clause_segments[2][2:end])
            # end

            # on_clause_function = "(= globalVar1 $(next_value)))"
            new_state_update_times_dict[global_var_id][on_clause_index + prev_time - 1] = ""
            push!(new_ranges, (augmented_positive_times[i], augmented_positive_times[i + 1]))
          end
        end
      end

      # add ranges that interface between global_var_value and lower values to new_ranges 
      if global_var_value > 1
        for time in 1:(length(state_update_times_dict[global_var_id]) - 1)
          prev_val = global_var_dict[global_var_id][time]
          next_val = global_var_dict[global_var_id][time + 1]

          if ((prev_val < global_var_value) && (next_val == global_var_value) || (prev_val == global_var_value) && (next_val < global_var_value))
            if intersect([time], true_positive_times) == [] 
              push!(new_ranges, ((time, prev_val), (time + 1, next_val)))
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

      grouped_ranges = group_ranges(filtered_ranges) 
    end
  end

  # update global_var_dict
  _, init_value = augmented_positive_times[1]                                   
  for time in 1:length(global_var_dict[global_var_id]) 
    if global_var_dict[global_var_id][time] >= global_var_value 
      global_var_dict[global_var_id][time] = init_value
    end
  end

  curr_value = -1
  for time in 1:length(global_var_dict[global_var_id])
    if curr_value != -1 
      global_var_dict[global_var_id][time] = curr_value
    end
    if new_state_update_times_dict[global_var_id][time] != ""
      curr_value = parse(Int, split(split(new_state_update_times_dict[global_var_id][time], "\n")[2], "(= globalVar$(global_var_id) ")[2][1])
    end
  end

  on_clause = "(on $(occursin("globalVar$(global_var_id)", co_occurring_event) ? co_occurring_event : "(& (== (prev globalVar$(global_var_id)) $(global_var_value)) $(co_occurring_event))")\n$(update_rule))"
  
  on_clause, global_var_dict, new_state_update_times_dict
end

function generate_new_object_specific_state(update_rule, update_function_times_dict, event_vector_dict, type_id, object_decomposition, state_update_times)
  println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  @show update_rule
  @show update_function_times_dict
  @show event_vector_dict
  @show type_id 
  @show object_decomposition
  @show state_update_times  
  
  object_types, object_mapping, background, grid_size = object_decomposition 
  object_ids = sort(collect(keys(update_function_times_dict)))

  # initialize state_update_times
  if length(collect(keys(state_update_times))) == 0
    for id in collect(keys(update_function_times_dict)) 
      state_update_times[id] = [("", -1) for i in 1:(length(object_mapping[object_ids[1]])-1)]
    end
    max_state_value = 1
  else
    max_state_value = maximum(vcat(map(id -> map(x -> x[2], state_update_times[id]), object_ids)...))
  end

  # compute co-occurring event 
  # events = filter(k -> event_vector_dict[k] isa Array, collect(keys(event_vector_dict))) 
  events = collect(keys(event_vector_dict))
  co_occurring_events = []
  for event in events
    if event_vector_dict[event] isa Array
      event_vector = event_vector_dict[event]
      co_occurring = foldl(&, map(update_function_times -> is_co_occurring(event, event_vector, update_function_times), collect(values(update_function_times_dict))), init=true)      
    
      if co_occurring
        false_positive_count = foldl(+, map(update_function_times -> num_false_positives(event_vector, update_function_times), collect(values(update_function_times_dict))), init=0)
        push!(co_occurring_events, (event, false_positive_count))
      end
    else
      event_vector = event_vector_dict[event]
      co_occurring = foldl(&, map(id -> is_co_occurring(event, event_vector[id], update_function_times_dict[id]), collect(keys(update_function_times_dict))), init=true)
      
      if co_occurring
        false_positive_count = foldl(+, map(id -> num_false_positives(event_vector[id], update_function_times_dict[id]), collect(keys(update_function_times_dict))), init=0)
        push!(co_occurring_events, (event, false_positive_count))
      end
    end
  end
  co_occurring_event = sort(co_occurring_events, by=(x -> x[2]))[1][1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  augmented_positive_times_dict = Dict()
  for object_id in object_ids
    true_positive_times = update_function_times_dict[object_id] # times when co_occurring_event happened and update_rule happened 
    false_positive_times = [] # times when user_event happened and update_rule didn't happen
    
    # construct false_positive_times 
    for time in 1:(length(object_mapping[object_ids[1]])-1)
      if co_occurring_event_trajectory isa Array
        if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times)
          push!(false_positive_times, time)
        end
      else 
        if co_occurring_event_trajectory[object_id][time] == 1 && !(time in true_positive_times)
          push!(false_positive_times, time)
        end
      end
    end

    # construct positive times list augmented by true/false value 
    augmented_true_positive_times = map(t -> (t, max_state_value), true_positive_times)
    augmented_false_positive_times = map(t -> (t, max_state_value + 1), false_positive_times)
    augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])  

    augmented_positive_times_dict[object_id] = augmented_positive_times 
  end

  # compute ranges 
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
  if max_state_value > 1
    custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
    for object_id in object_ids
      augmented_positive_times = augmented_positive_times_dict[object_id]
      for time in 1:(length(object_mapping[object_ids[1]])-1)
        if (length(intersect(map(t -> t[1], augmented_positive_times), [time, time + 1])) == 1) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          prev_val = object_mapping[object_id][time].custom_field_values[custom_field_index]
          next_val = object_mapping[object_id][time + 1].custom_field_values[custom_field_index]
          
          if (prev_val < max_state_value) && (next_val == max_state_value)
            if (filter(t -> t[1] == time + 1, augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, augmented_positive_times)[1][2] != max_state_value)
              new_value = filter(t -> t[1] == time + 1, augmented_positive_times)[1][2]
              push!(ranges_dict[object_id], ((time, prev_val), (time + 1, new_value)))        
            else
              push!(ranges_dict[object_id], ((time, prev_val), (time + 1, next_val)))        
            end
  
          elseif (prev_val == max_state_value) && (next_val < max_state_value)
            if (filter(t -> t[1] == time, augmented_positive_times) != []) && (filter(t -> t[1] == time, augmented_positive_times)[1][2] != max_state_value)
              new_value = filter(t -> t[1] == time, augmented_positive_times)[1][2]
              push!(ranges[object_id], ((time, new_value), (time + 1, next_val)))        
            else
              push!(ranges[object_id], ((time, prev_val), (time + 1, next_val)))        
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

  while length(grouped_ranges) > 0
    grouped_range = grouped_ranges[1]
    grouped_ranges = grouped_ranges[2:end]

    range = grouped_range[1]
    start_value = range[1][2]
    end_value = range[2][2]

    # TODO: try global events too  
    events_in_range = []
    if events_in_range == [] # if no global events are found, try object-specific events 
      # do something
      # events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_value)
      events_in_range = find_state_update_events_object_specific(event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, max_state_value)
    end
    
    if length(events_in_range) > 0 # only handling perfect matches currently 
      event, event_times = events_in_range[1]
      formatted_event = replace(event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
      # construct state_update_function
      if occursin("clicked", formatted_event)
        state_update_function = """(on clicked\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      else
        state_update_function = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      end
      println(state_update_function)
      for id in collect(keys(state_update_times))
        object_event_times = map(t -> t[1], filter(time -> time[2] == id, event_times))
        for time in object_event_times
          println(id)
          println(time)
          println(end_value) 
          state_update_times[id][time] = (state_update_function, end_value)
        end
      end
    end
  end

  # construct field values for each object 
  object_field_values = Dict()
  for object_id in object_ids
    init_value = length(augmented_positive_times_dict[object_id]) == 0 ? (max_state_value + 1) : augmented_positive_times_dict[object_id][1][2]
    object_field_values[object_id] = [init_value for i in 1:(length(state_update_times[object_id]) + 1)]
    
    curr_value = -1
    for time in 1:length(state_update_times[object_id])
      if curr_value != -1
        object_field_values[object_id][time] = curr_value
      end
      
      if state_update_times[object_id][time] != ("", -1)
        curr_value = state_update_times[object_id][time][2]
      end
    end
    object_field_values[object_id][length(object_field_values[object_id])] = curr_value != -1 ? curr_value : init_value
  end

  # construct new object decomposition
  ## add field to correct ObjType in object_types
  new_object_types = deepcopy(object_types)
  new_object_type = filter(type -> type.id == type_id, new_object_types)[1]
  if !("field1" in map(field_tuple -> field_tuple[1], new_object_type.custom_fields))
    push!(new_object_type.custom_fields, ("field1", "Int", [1, 2]))
  else
    custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
    push!(new_object_type.custom_fields[custom_field_index][3], max_state_value + 1)
  end
  
  ## modify objects in object_mapping
  new_object_mapping = deepcopy(object_mapping)
  for id in collect(keys(new_object_mapping))
    if id in collect(keys(update_function_times_dict))
      for time in 1:length(new_object_mapping[id])
        if !isnothing(object_mapping[id][time])
          values = new_object_mapping[id][time].custom_field_values
          if !((values != []) && (values[end] isa Int) && (values[end] < max_state_value))
            new_object_mapping[id][time].type = new_object_type
            if (values != []) && (values[end] isa Int)
              new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values[1:end-1], object_field_values[id][time])
            else
              new_object_mapping[id][time].custom_field_values = vcat(new_object_mapping[id][time].custom_field_values, object_field_values[id][time])
            end
          end
        end
      end
    end
  end
  new_object_decomposition = new_object_types, new_object_mapping, background, grid_size

  formatted_co_occurring_event = replace(co_occurring_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
  on_clause = "(on true\n$(replace(update_rule, "(== (.. obj id) x)" => "(& $(formatted_co_occurring_event) (== (.. obj field1) $(max_state_value)))")))"
  state_update_on_clauses = map(x -> x[1], unique(filter(r -> r != ("", -1), vcat([state_update_times[k] for k in collect(keys(state_update_times))]...))))
  on_clause, state_update_on_clauses, new_object_decomposition, state_update_times  
end

function is_no_change_rule(update_rule)
  update_functions = ["moveLeft", "moveRight", "moveUp", "moveDown", "nextSolid", "nextLiquid", "color", "addObj", "move"]
  !foldl(|, map(x -> occursin(x, update_rule), update_functions))
end 

function full_program(observations, user_events, grid_size=16)
  matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)

  object_types, object_mapping, background, _ = object_decomposition
  
  new_matrix = [[] for i in 1:size(matrix)[1], j in 1:size(matrix)[2]]
  for i in 1:size(new_matrix)[1]
    for j in 1:size(new_matrix)[2]
      new_matrix[i, j] = unique(matrix[i, j]) 
    end 
  end
  matrix = new_matrix

  on_clauses, new_object_decomposition, global_var_dict, filtered_matrix = generate_on_clauses(matrix, object_decomposition, user_events, grid_size)
  object_types, object_mapping, background, _ = new_object_decomposition

  # for object_id in object_ids
  #   for time in 1:size(filtered_matrix)[2]
  #     update_rule = filtered_matrix[object_id, time][1]
  #     if occursin("addObj", update_rule)
  #       object = object_mapping[object_id][time + 1]
  #       new_rule = format_matrix_function(update_rule, object)
  #       filtered_matrix[object_id, time] = [new_rule]
  #     end
  #   end
  # end

  on_clauses = unique(on_clauses)
  true_on_clauses = filter(on_clause -> occursin("on true", on_clause), on_clauses)
  user_event_on_clauses = filter(on_clause -> !(on_clause in true_on_clauses) && foldl(|, map(event -> occursin(event, on_clause) , ["clicked", "left", "right", "down", "up"])), on_clauses)
  other_on_clauses = filter(on_clause -> !((on_clause in true_on_clauses) || (on_clause in user_event_on_clauses)), on_clauses)
  
  on_clauses = vcat(true_on_clauses, other_on_clauses..., user_event_on_clauses...)
  
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  
  program_no_update_rules = program_string_synth_standard_groups((object_types, object_mapping, background, grid_size))
  
  inits = []
  for key in collect(keys(global_var_dict))
    global_var_init_val = global_var_dict[key][1]
    push!(inits, """\n\t (: globalVar$(key) Int)\n\t (= globalVar$(key) (initnext $(global_var_init_val) (prev globalVar$(key))))""")
  end
  program_no_update_rules = string(program_no_update_rules[1:end-2], inits..., ")")
  
  t = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""

  update_rules = join(on_clauses, "\n  ")
  
  string(program_no_update_rules[1:end-1], 
        "\n\n  $(t)", 
        "\n\n  $(update_rules)", 
        ")")
end