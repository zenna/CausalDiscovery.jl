using Autumn
using MacroTools: striplines
using StatsBase
using Random
using Pickle
include("generativemodel.jl")
include("state_construction_utils.jl")
include("construct_observation_data.jl")

displacement_dict = Dict((0, 0) => "(= objX objX)", 
                         (0, 1) => "(= objX (moveDown objX))", 
                         (0, -1) => "(= objX (moveUp objX))", 
                         (-1, 0) => "(= objX (moveLeft objX))", 
                         (1, 0) => "(= objX (moveRight objX))", 
                        )

type_displacements = Dict()

function find_global_index(update_function)
  if is_no_change_rule(update_function)
    1
  else
    ordered_rules = ["moveUp", "moveDown", "moveLeft", "moveRight", "moveUpNoCollision", "moveDownNoCollision", "moveLeftNoCollision", "moveRightNoCollision", "nextLiquid", "click", "uniformChoice", "randomPositions"]
    bools = map(r -> occursin(r, update_function), ordered_rules)
    indices = findall(x -> x == 1, bools)
    if indices != []
      indices[1] + 1
    else
      length(ordered_rules) + 2
    end
  end
end

"""Construct matrix of single timestep solutions"""
function singletimestepsolution_matrix(observations, user_events, grid_size; singlecell=false, pedro=false, upd_func_space=1)
  object_decomposition = parse_and_map_objects(observations, grid_size, singlecell=singlecell, pedro=pedro)

  object_types, object_mapping, background, _ = object_decomposition

  for type in object_types 
    type_displacements[type.id] = []
  end
  
  for object_type in object_types 
    type_id = object_type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

    for id in object_ids_with_type 
      for time in 1:(length(object_mapping[id]) - 1)
        if !isnothing(object_mapping[id][time]) && !isnothing(object_mapping[id][time + 1])
          disp = displacement(object_mapping[id][time].position, object_mapping[id][time + 1].position)
          if disp != (0, 0)
            scalars = map(y -> abs(y), filter(x -> x != 0, [disp...]))
            push!(type_displacements[type_id], scalars...)
          end
        end
      end
    end
  end

  for type in object_types 
    type_displacements[type.id] = unique(type_displacements[type.id])
  end

  # @show object_decomposition 

  # matrix of update function sets for each object/time pair
  # number of rows = number of objects, number of cols = number of time steps  
  num_objects = length(collect(keys(object_mapping)))
  matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  unformatted_matrix = [[] for object_id in 1:num_objects, time in 1:(length(observations) - 1)]
  
  # SEED PREV USED RULES FOR EFFIENCY AT THE MOMENT 
  prev_used_rules = [ "(= objX objX)",
                      "(= objX (nextLiquid objX))",
                      "(= objX (moveDown objX))",
                      "(= objX (moveUp objX))",
                      "(= objX (moveLeft objX))",
                      "(= objX (moveRight objX))",
                    ] 

  if upd_func_space == 2 
    prev_used_rules = ["(= objX objX)",
                       "(= objX (moveUpNoCollision objX))",
                       "(= objX (moveDownNoCollision objX))",
                       "(= objX (moveLeftNoCollision objX))",
                       "(= objX (moveRightNoCollision objX))",]
  end

  if upd_func_space == 3 
    prev_used_rules = ["(= objX objX)",
                       "(= objX (nextLiquid objX))",
                       "(= objX (moveUpNoCollision objX))",
                       "(= objX (moveDownNoCollision objX))",
                       "(= objX (moveLeftNoCollision objX))",
                       "(= objX (moveRightNoCollision objX))",
                       ]
  end

  if upd_func_space in [4, 5] 
    prev_used_rules = ["(= objX objX)",
                        "(= objX (moveDown objX))",
                        "(= objX (moveUp objX))",
                        "(= objX (moveLeft objX))",
                        "(= objX (moveRight objX))",
                        "(= objX (moveLeftNoCollision (moveUpNoCollision objX)))",
                        "(= objX (moveLeftNoCollision (moveDownNoCollision objX)))",
                        "(= objX (moveRightNoCollision objX))",
                        "(= objX (moveRightNoCollision (moveUpNoCollision objX)))",
                        "(= objX (moveRightNoCollision (moveDownNoCollision objX)))",
                        "(= objX (moveUpNoCollision objX))",
                        "(= objX (moveDownNoCollision objX))",
                        "(= objX (moveLeftNoCollision objX))",
                        "(= objX (moveRightNoCollision objX))",
                      ]
  end

  if upd_func_space in [6] 
    prev_used_rules = ["(= objX objX)",
                        "(= objX (nextLiquid objX))",
                        "(= objX (moveDown objX))",
                        "(= objX (moveUp objX))",
                        "(= objX (moveLeft objX))",
                        "(= objX (moveRight objX))",
                        "(= objX (moveLeftNoCollision (moveUpNoCollision objX)))",
                        "(= objX (moveLeftNoCollision (moveDownNoCollision objX)))",
                        "(= objX (moveRightNoCollision objX))",
                        "(= objX (moveRightNoCollision (moveUpNoCollision objX)))",
                        "(= objX (moveRightNoCollision (moveDownNoCollision objX)))",
                        "(= objX (moveUpNoCollision objX))",
                        "(= objX (moveDownNoCollision objX))",
                        "(= objX (moveLeftNoCollision objX))",
                        "(= objX (moveRightNoCollision objX))",
                      ]
  end

  max_iters = length(prev_used_rules)

  if upd_func_space in [5] 
    max_iters += 1
  end

  if upd_func_space in [6]
    max_iters += 1
  end
  
  prev_abstract_positions = []
  
  # # # @show size(matrix)
  # for each subsequent frame, map objects
  for time in 2:length(observations)
    println("WOOT")
    @show time 
    # for each object in previous time step, determine a set of update functions  
    # that takes the previous object to the next object
    for object_id in 1:num_objects
      update_functions, unformatted_update_functions, prev_used_rules, prev_abstract_positions = synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size, max_iters, upd_func_space, pedro=pedro)
      # # # @show update_functions 
      if length(update_functions) == 0
        # # println("HOLY SHIT")
      end
      matrix[object_id, time - 1] = update_functions 
      unformatted_matrix[object_id, time - 1] = unformatted_update_functions
    end
  end
  matrix, unformatted_matrix, object_decomposition, prev_used_rules
end

expr = nothing
mod = nothing
global_iters = 0
"""Synthesize a set of update functions that """
function synthesize_update_functions(object_id, time, object_decomposition, user_events, prev_used_rules, prev_abstract_positions, grid_size=16, max_iters=11, upd_func_space=1; pedro=false)
  object_types, object_mapping, background, grid_size = object_decomposition
  type_ids = map(t -> t.id, object_types)
  object_type = filter(o -> !isnothing(o), object_mapping[object_id])[1].type

  if length(unique(map(k -> length(object_mapping[k]), collect(keys(object_mapping))))) != 1 
    # # # @show object_mapping
    # # println("TERRIBLE WHAT")
  end
  
  # # # @show object_id 
  # # # @show time
  prev_object = object_mapping[object_id][time - 1]
  
  next_object = object_mapping[object_id][time]
  ## # # @show object_id 
  ## # # @show time
  ## # # @show prev_object 
  ## # # @show next_object
  # # # # @show isnothing(prev_object) && isnothing(next_object)
  if isnothing(prev_object) && isnothing(next_object)
    [""], [""], prev_used_rules, prev_abstract_positions
  elseif isnothing(prev_object)
    # perform position abstraction step
    start_objects = filter(obj -> !isnothing(obj), [object_mapping[id][1] for id in collect(keys(object_mapping))])
    # prev_objects_maybe_listed = filter(obj -> !isnothing(obj) && !isnothing(object_mapping[obj.id][1]), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    # prev_objects = filter(obj -> (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == obj.type.id, collect(keys(object_mapping))) == 1), prev_objects_maybe_listed)
    
    prev_existing_objects = filter(obj -> !isnothing(obj), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time - 1]) && (unique(object_mapping[id][1:time - 1]) != [nothing]), collect(keys(object_mapping)))
    prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time - 1])[1], prev_removed_object_ids))
    foreach(obj -> obj.position = (-1, -1), prev_removed_objects)

    prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)

    # # println("HELLO")
    # # # @show prev_objects
    prev_objects_not_listed = filter(x -> !isnothing(object_mapping[x.id][1]) && count(k -> filter(y -> !isnothing(y), object_mapping[k])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1, prev_objects)
    abstracted_positions, prev_abstract_positions = abstract_position(next_object.position, prev_abstract_positions, user_events[time - 1], (object_types, sort(prev_objects_not_listed, by = x -> x.id), background, grid_size), object_mapping, time - 1, pedro)
    # abstracted_positions = [abstracted_positions..., "(uniformChoice (randomPositions $(grid_size) 1))"]
    
    # add uniformChoice option
    matching_objects = filter(o -> o.position == next_object.position, prev_existing_objects)

    if (matching_objects != []) && (isnothing(object_mapping[matching_objects[1].id][1]) || !(matching_objects[1].type.id in map(x -> x.id, prev_objects_not_listed))) 
      # matching object is in a list!

      # check if object intersects any other object of other type 
      ## (= addedObjType$()List (addObj addedObjType$()List (map (--> pos (ObjType$() pos)) (intersect () ()))))

      first_matching_object = matching_objects[1]
      push!(abstracted_positions, "(.. (uniformChoice (vcat (prev addedObjType$(first_matching_object.type.id)List) (prev addedObjType$(first_matching_object.type.id)List) (prev addedObjType$(first_matching_object.type.id)List) (prev addedObjType$(first_matching_object.type.id)List) (prev addedObjType$(first_matching_object.type.id)List) (prev addedObjType$(first_matching_object.type.id)List))) origin)")
      for matching_object in matching_objects 
        push!(abstracted_positions, "(uniformChoice (map (--> obj (.. obj origin)) (filter (--> obj (== (.. obj id) $(matching_object.id))) (prev addedObjType$(matching_object.type.id)List))))")
      end      
    end

    if pedro 
      for object_type in object_types 
        
        for scalar in type_displacements[object_type.id]
          prev_existing_objects_of_type = filter(o -> o.type.id == object_type.id, prev_existing_objects)

          pedro_matching_objects = filter(o -> next_object.position in [(o.position[1] + scalar, o.position[2]), 
                                                                        (o.position[1] - scalar, o.position[2]), 
                                                                        (o.position[1], o.position[2] + scalar), 
                                                                        (o.position[1], o.position[2] - scalar),
                                                                        (o.position[1], o.position[2])], prev_existing_objects_of_type)

          if (pedro_matching_objects != []) && (isnothing(object_mapping[pedro_matching_objects[1].id][1]) || !(pedro_matching_objects[1].type.id in map(x -> x.id, prev_objects_not_listed))) 
            # @show scalar 
            # @show time
            # @show pedro_matching_objects 
            first_matching_object = pedro_matching_objects[1]
            disps = map(o -> (next_object.position[1] - o.position[1], next_object.position[2] - o.position[2]), [first_matching_object])      
            abstracted_position = "(.. (uniformChoice $(join(map(disp -> "(map (--> obj (.. (move obj (Position $(disp[1]) $(disp[2]))) origin)) (prev addedObjType$(first_matching_object.type.id)List))", disps), " ")) ) origin)"
            # # println("RANDOM ABSTRACTIONS!")
            # @show abstracted_position 
            push!(abstracted_positions, abstracted_position)

            # disp = (next_object.position[1] - matching_object.position[1], next_object.position[2] - matching_object.position[2]) 
            # pos = "(uniformChoice (map (--> obj (.. (move obj (Position $(disp[1]) $(disp[2]))) origin)) (filter (--> obj (== (.. obj id) $(matching_object.id))) (prev addedObjType$(matching_object.type.id)List))))"
          end
        end

      end
    
    end

    if length(next_object.custom_field_values) > 0
      update_rules = [
        """(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))""",
      ]

      # # add randomPositions option
      # update_rules = vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (map (--> pos (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) pos)) (randomPositions GRID_SIZE 1))))")
      
      # perform string abstraction 
      abstracted_strings = [] # abstract_string(next_object.custom_field_values[1], (object_types, sort(prev_objects_not_listed, by = x -> x.id), background, grid_size))
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
      reverse(update_rules), reverse(update_rules), prev_used_rules, prev_abstract_positions
    else
      update_rules = map(pos -> 
      "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) $(pos))))",
      abstracted_positions)

      # add randomPositions option
      # update_rules = vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (map (--> pos (ObjType$(next_object.type.id) pos)) (randomPositions GRID_SIZE 1))))")
      
      update_rules = vcat(update_rules..., "(= addedObjType$(next_object.type.id)List (addObj addedObjType$(next_object.type.id)List (ObjType$(next_object.type.id) $(join(map(v -> """ "$(v)" """, next_object.custom_field_values), " ")) (Position $(next_object.position[1]) $(next_object.position[2])))))")
      update_rules, update_rules, prev_used_rules, prev_abstract_positions
    end
  elseif isnothing(next_object)
    start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
    contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)

    if contained_in_list # object was added later; contained in addedList
      update_rules = ["(= addedObjType$(prev_object.type.id)List (removeObj addedObjType$(prev_object.type.id)List (--> obj (== (.. obj id) $(object_id)))))"]
      update_rules, update_rules, prev_used_rules, prev_abstract_positions  
    else # object was present at the start of the program
      update_rules = ["(= obj$(object_id) (removeObj (prev obj$(object_id))))"]
      update_rules, update_rules, prev_used_rules, prev_abstract_positions
    end
  else # actual synthesis problem
    type_id = prev_object.type.id 
    prev_used_rules_copy = deepcopy(prev_used_rules)

    # prev_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_existing_objects = filter(obj -> !isnothing(obj) && (obj.id != prev_object.id), [object_mapping[id][time - 1] for id in 1:length(collect(keys(object_mapping)))])
    prev_removed_object_ids = filter(id -> isnothing(object_mapping[id][time - 1]) && (unique(object_mapping[id][1:time - 1]) != [nothing]) && (id != prev_object.id), collect(keys(object_mapping)))
    prev_removed_objects = deepcopy(map(id -> filter(obj -> !isnothing(obj), object_mapping[id][1:time - 1])[1], prev_removed_object_ids))
    foreach(obj -> obj.position = (-1, -1), prev_removed_objects)

    prev_objects = vcat(prev_existing_objects..., prev_removed_objects...)

    ## # # @show prev_objects
    solutions = []
    unformatted_solutions = []
    iters = 0
    prev_used_rules_index = 1
    using_prev = false
    while (iters < max_iters) # && length(solutions) < 1
      dist = distance(prev_object.position, next_object.position)
      # if pedro 
      #   if dist != 0 
      #     x_displacement = next_object.position[1] - prev_object.position[1]
      #     y_displacement = next_object.position[2] - prev_object.position[2]
      #     new_rule = "(= objX (move objX (Position $(x_displacement) $(y_displacement))))" 
      #   else
      #     new_rule = "(= objX objX)"
      #   end
      #   push!(unformatted_solutions, new_rule)
      #   update_rule = replace(new_rule, "objX" => "obj$(object_id)")
      #   contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)
      #   if contained_in_list # object was added later; contained in addedList
      #     update_rule_parts = split(update_rule, " ")
      #     var1 = replace(update_rule_parts[2], "obj$(object_id)" => "obj")
      #     var2 = replace(join(update_rule_parts[3:end], " "), "obj$(object_id)" => "(prev obj)")
      #     map_lambda_func = string("(--> ", var1, " ", var2)
      #     # map_lambda_func = replace(string("(-->", replace(update_rule, "obj$(object_id)" => "obj")[3:end]), "(prev obj)" => "(prev obj)")
      #     push!(solutions, "(= addedObjType$(prev_object.type.id)List (updateObj addedObjType$(prev_object.type.id)List $(map_lambda_func) (--> obj (== (.. obj id) $(object_id)))))")
      #   else # object was present at the start of the program
      #     update_rule_parts = filter(x -> x != "", split(update_rule, " "))
      #     push!(solutions, join([update_rule_parts[1], update_rule_parts[2], replace(join(update_rule_parts[3:end], " "), "obj$(object_id)" => "(prev obj$(object_id))" )], " "))
      #   end

      #   break
      # end

      # update prev_used_rules 
      if !pedro && dist >= 2 
        x_displacement = next_object.position[1] - prev_object.position[1]
        y_displacement = next_object.position[2] - prev_object.position[2]
        displacement = (x_displacement, y_displacement)
        displacement_dict[displacement] = "(= objX (move objX $(x_displacement) $(y_displacement)))"
        if upd_func_space == 1 
          prev_used_rules[1] = "(= objX (move objX $(x_displacement) $(y_displacement)))"
        else
          prev_used_rules[1] = "(= objX (move objX $(x_displacement) $(y_displacement)))"
          prev_used_rules[2] = "(= objX (moveNoCollision objX $(x_displacement) $(y_displacement)))"
        end
      end

      # update prev_used_rules: PEDRO 
      if pedro && iters == 0
        prev_used_rules = [] 
        if object_type.color != "darkgray" 
          x_displacement = next_object.position[1] - prev_object.position[1]
          y_displacement = next_object.position[2] - prev_object.position[2]
          displacement = (x_displacement, y_displacement)
          
          if type_displacements[object_type.id] == [] 
            displacement_dict[displacement] = "(= objX objX)"
            push!(prev_used_rules, "(= objX objX)")            
          else
            if displacement == (0, 0)
              displacement_dict[displacement] = "(= objX objX)"
              push!(prev_used_rules, "(= objX objX)")
              for scalar in type_displacements[type_id]
                disps_to_try = [(0, -scalar), (0, scalar), (scalar, 0), (-scalar, 0)]
                for disp in disps_to_try
                  x, y = disp 
                  push!(prev_used_rules, """(= objX (moveNoCollisionColor objX $(x) $(y) "darkgray"))""")
                end
  
                # add closest-based update functions
                for unit_size in type_displacements[object_type.id] 

                  for desc in ["Left", "Right", "Up", "Down"]
                    other_type_ids = filter(x -> x != type_id, type_ids)
                    for other_type_id_1 in other_type_ids # closest w.r.t. single other type 
                      push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (closest$(desc) objX (list ObjType$(other_type_id_1)) $(unit_size)) "darkgray"))""")
                      for other_type_id_2 in other_type_ids # closest w.r.t. pair of other type's 
                        if other_type_id_1 < other_type_id_2 
                          push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (closest$(desc) objX (list ObjType$(other_type_id_1) ObjType$(other_type_id_2)) $(unit_size)) "darkgray"))""")
                        end
                      end
                    end
                  end
    
                  # # add farthest-based update functions 
                  # for desc in ["Left", "Right", "Up", "Down"]
                  #   other_type_ids = filter(x -> x != type_id, type_ids)
                  #   for other_type_id_1 in other_type_ids # closest w.r.t. single other type 
                  #     push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (farthest$(desc) objX (list ObjType$(other_type_id_1)) $(unit_size)) "darkgray"))""")
                  #   end
                  # end

                end
              end
            else # if observed displacement is nonzero, only need to to try a few options 
              # push!(prev_used_rules, "(= objX (move objX $(x_displacement) $(y_displacement)))") 
              # push!(prev_used_rules, "(= objX (moveNoCollision objX $(x_displacement) $(y_displacement)))")
              push!(prev_used_rules, """(= objX (moveNoCollisionColor objX $(x_displacement) $(y_displacement) "darkgray"))""")
            
              # add closest-based update functions 
              unit_size = filter(x -> x != 0, [x_displacement, y_displacement]) != [] ? abs(filter(x -> x != 0, [x_displacement, y_displacement])[1]) : 1 
              for desc in ["Left", "Right", "Up", "Down"]
                other_type_ids = filter(x -> x != type_id, type_ids)
                for other_type_id_1 in other_type_ids # closest w.r.t. single other type 
                  push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (closest$(desc) objX (list ObjType$(other_type_id_1)) $(unit_size)) "darkgray"))""")
                  for other_type_id_2 in other_type_ids # closest w.r.t. pair of other type's 
                    if other_type_id_1 < other_type_id_2 
                      push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (closest$(desc) objX (list ObjType$(other_type_id_1) ObjType$(other_type_id_2)) $(unit_size)) "darkgray"))""")
                    end
                  end
                end
              end
  
              # # add farthest-based update functions 
              # unit_size = filter(x -> x != 0, [x_displacement, y_displacement]) != [] ? abs(filter(x -> x != 0, [x_displacement, y_displacement])[1]) : 1 
              # for desc in ["Left", "Right", "Up", "Down"]
              #   other_type_ids = filter(x -> x != type_id, type_ids)
              #   for other_type_id_1 in other_type_ids # closest w.r.t. single other type 
              #     push!(prev_used_rules, """(= objX (moveNoCollisionColor objX (farthest$(desc) objX (list ObjType$(other_type_id_1)) $(unit_size)) "darkgray"))""")
              #   end
              # end
  
            end
  
          end

        else # currently using assumption that dark gray blocks never move; this can also be learned by the synthesizer itself
          push!(prev_used_rules, "(= objX objX)")
        end
        max_iters = length(prev_used_rules)
        sort!(prev_used_rules)
        # # println("PEDRO LOOK HERE")
        # @show prev_used_rules 
        # @show max_iters
      end 

      hypothesis_program = program_string_synth_update_rule((object_types, sort([prev_objects..., prev_object], by=(x -> x.id)), background, grid_size))
      if (prev_object.custom_field_values != []) && (next_object.custom_field_values != []) && (prev_object.custom_field_values[1] != next_object.custom_field_values[1])
        update_rule = """(= obj$(object_id) (updateObj obj$(object_id) "color" "$(next_object.custom_field_values[1])"))"""
      elseif prev_used_rules_index <= length(prev_used_rules)
        update_rule = replace(prev_used_rules[prev_used_rules_index], "objX" => "obj$(object_id)")
        # @show update_rule
        using_prev = true
        prev_used_rules_index += 1
        # # # @show prev_used_rules_index
      else
        if pedro 
          break
        end

        using_prev = false
        update_rule = generate_hypothesis_update_rule(prev_object, (object_types, prev_objects, background, grid_size), p=0.0) # "(= obj1 (moveDownNoCollision (moveDownNoCollision (prev obj1))))"
        # # println("IS THIS THE REAL LIFE")
        # # # @show update_rule 
      end 
      # @show time      
      # @show update_rule 
      if occursin("NoCollision", update_rule) || occursin("closest", update_rule) || occursin("farthest", update_rule) || occursin("nextLiquid", update_rule) || occursin("color", update_rule)
        hypothesis_program = string(hypothesis_program[1:end-2], "\n\t (on true\n", update_rule, ")\n)")
        # println("HYPOTHESIS_PROGRAM")
        # println(prev_object)
        # println(hypothesis_program)
        # # # # @show global_iters
        # # # # @show update_rule
  
        expr = parseautumn(hypothesis_program)
        # global expr = striplines(compiletojulia(parseautumn(hypothesis_program)))
        hypothesis_frame_state = interpret_over_time(expr, 1).state
        
        # # # @show hypothesis_frame_state
        hypothesis_object = filter(o -> o.id == object_id, hypothesis_frame_state.scene.objects)[1]
        ## # # @show hypothesis_frame_state.scene.objects
        ## # # @show hypothesis_object
        equals = render_equals(hypothesis_object, next_object)
      else
        # update rule does not need evaluation in Autumn program 
        x_displacement = next_object.position[1] - prev_object.position[1]
        y_displacement = next_object.position[2] - prev_object.position[2]
        displacement = (x_displacement, y_displacement)

        anonymized_update_rule = replace(update_rule, "obj$(object_id)" => "objX")
        if (displacement in keys(displacement_dict)) && displacement_dict[displacement] == anonymized_update_rule
          equals = true
        else
          equals = false
        end        
      end
      # @show equals 
      if equals
        if using_prev
          # # println("HOORAY")
        end
        generic_update_rule = replace(update_rule, "obj$(object_id)" => "objX") 
        push!(unformatted_solutions, generic_update_rule)       
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
          abstracted_strings = [] # abstract_string(next_object.custom_field_values[1], (object_types, curr_objects, background, grid_size))
          
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

          if occursin("closestLeft", update_rule)
            update_rule = replace(update_rule, "closestLeft" => "closestRandom")
          elseif occursin("closestRight", update_rule)
            update_rule = replace(update_rule, "closestRight" => "closestRandom")
          elseif occursin("closestUp", update_rule)
            update_rule = replace(update_rule, "closestUp" => "closestRandom")
          elseif occursin("closestDown", update_rule)
            update_rule = replace(update_rule, "closestDown" => "closestRandom")
          end

          if occursin("farthestLeft", update_rule)
            update_rule = replace(update_rule, "farthestLeft" => "farthestRandom")
          elseif occursin("farthestRight", update_rule)
            update_rule = replace(update_rule, "farthestRight" => "farthestRandom")
          elseif occursin("farthestUp", update_rule)
            update_rule = replace(update_rule, "farthestUp" => "farthestRandom")
          elseif occursin("farthestDown", update_rule)
            update_rule = replace(update_rule, "farthestDown" => "farthestRandom")
          end

          # if !occursin("closestRandom", update_rule) || !occursin("closestRandom", join(solutions, "")) # true
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
          # end
        end
      end
      
      iters += 1
      global global_iters += 1
      
    end
    if (iters == max_iters)
      # # println("FAILURE")
    end
    unique(solutions), unique(unformatted_solutions), prev_used_rules_copy, prev_abstract_positions
  end
end

"""Parse observations into object types and objects, and assign 
   objects in current observed frame to objects in next frame"""
function parse_and_map_objects(observations, gridsize=16; singlecell=false, pedro=false)
  object_mapping = Dict{Int, Array{Union{Nothing, Obj}}}()

  if pedro 
    unitSize = 10 
  else
    unitSize = 1
  end

  # check if observations contains frames with overlapping cells
  overlapping_cells = singlecell # false # foldl(|, map(frame -> has_dups(map(cell -> (cell.position.x, cell.position.y, cell.color), frame)), observations), init=false)
  # # println("OVERLAPPING_CELLS")
  # println(overlapping_cells)
  # construct object_types
  ## initialize object_types based on first observation frame
  if !pedro 
    if overlapping_cells
      object_types, _, background, dim = parsescene_autumn_singlecell(observations[1], "white", gridsize)
    else
      object_types, _, background, dim = parsescene_autumn(observations[1], gridsize)
    end
  
    ## iteratively build object_types through each subsequent observation frame
    for time in 2:length(observations)
      if overlapping_cells
        object_types, _, _, _ = parsescene_autumn_singlecell_given_types(observations[time], object_types, "white", gridsize)
      else
        object_types, _, _, _ = parsescene_autumn_given_types(observations[time], object_types, gridsize)
      end
    end
    # # println("HERE 1")
    # println(object_types)
  
    if overlapping_cells
      _, objects, _, _ = parsescene_autumn_singlecell_given_types(observations[1], object_types, "white", gridsize)
    else
      _, objects, _, _ = parsescene_autumn_given_types(observations[1], object_types, gridsize)
    end
    # # println("HERE 2")
    # println(object_types)  
  else
    if singlecell 
      # compute union of all colors seen across observations
      object_types_list = vcat(map(obs -> parsescene_autumn_pedro(obs, gridsize isa Int ? gridsize : gridsize[1], "white")[1], observations)...)
      all_colors = unique(map(t -> t.color, object_types_list))
      # @show object_types_list 
      shape = filter(t -> t.color != "black", object_types_list)[1].shape
      object_types = "black" in all_colors ? [object_types_list[1]] : []

      colors = unique(map(t -> t.color, filter(t -> t.color != "black", object_types_list)))
      for i in 1:length(colors)
        push!(object_types, ObjType(shape, colors[i], [], "black" in all_colors ? i + 1 : i))
      end

      _, objects, _, _ = parsescene_autumn_pedro_given_types(observations[1], object_types, gridsize, "white")
    else
      object_types, objects, _, _ = parsescene_autumn_pedro_multicell(observations[1], gridsize, "white")
    end
  end

  # reassign id's to objects so that id's within a type form disjoint intervals 
  object_max_id = 0
  for object_type_id in sort(map(t -> t.id, object_types)) 
    objects_of_type = filter(o -> o.type.id == object_type_id, objects)
    for i in 1:length(objects_of_type) 
      objects_of_type[i].id = object_max_id + i
    end
    object_max_id = object_max_id + length(objects_of_type)
  end 

  for object in objects
    object_mapping[object.id] = [object]
  end
  for time in 2:length(observations)
    # # println("HERE 3")
    @show time
    # # println(time)
    # # println(object_types)
    if !pedro 
      if overlapping_cells
        _, next_objects, _, _ = parsescene_autumn_singlecell_given_types(observations[time], deepcopy(object_types), "white", gridsize) # parsescene_autumn_singlecell
      else
        _, next_objects, _, _ = parsescene_autumn_given_types(observations[time], deepcopy(object_types)) # parsescene_autumn_singlecell
      end
  
    else
      if singlecell 
        _, next_objects, _, _ = parsescene_autumn_pedro_given_types(observations[time], deepcopy(object_types), gridsize, "white")
      else
        _, next_objects, _, _ = parsescene_autumn_pedro_multicell_given_types(observations[time], object_types, gridsize, "white")
      end

    end

    if time == 30 
      # # println("------------------- DARN")
      # # # @show filter(o -> o.type.id == 4, objects)
    end
    # construct mapping between objects and next_objects
    for type in object_types


      curr_objects_with_type = filter(o -> o.type.id == type.id, objects)
      next_objects_with_type = filter(o -> o.type.id == type.id, next_objects)
      
      closest_objects = compute_closest_objects(curr_objects_with_type, next_objects_with_type)
      if time == 29 && type.id == 4
        # # # println("-------------- CHECK ME OUT 1")
        # # # @show curr_objects_with_type 
        # # # @show next_objects_with_type
        # # # @show closest_objects
      end
      if time == 30 && type.id == 4
        # # println("-------------- CHECK ME OUT 2")
        # # # @show curr_objects_with_type 
        # # # @show next_objects_with_type
        # # # @show closest_objects
      end
      if !(isempty(curr_objects_with_type) || isempty(next_objects_with_type)) 
        while length(closest_objects) > 0
          # # println("IN WHILE LOOP")
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
            curr_object_color = curr_object.custom_field_values == [] ? curr_object.type. color : curr_object.custom_field_values[1]

            closest_ids = intersect(closest_ids, map(o -> o.id, next_objects_with_type))
            objects_ = map(id -> filter(o -> o.id == id, next_objects_with_type)[1], closest_ids)
            closest_objects_with_same_color = filter(o -> (o.custom_field_values == [] ? o.type.color : o.custom_field_values[1]) == curr_object_color, objects_)
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
          
          if time == 30 
            # # # @show length(object_mapping[22])
          end

          if length(filter(t -> length(intersect(t[2], map(o -> o.id, next_objects_with_type))) >= 1, closest_objects)) == 0
            # every remaining object to be mapped is equidistant to at least two closest objects, or zero objects
            # perform a brute force assignment
            while !isempty(curr_objects_with_type) && !isempty(next_objects_with_type)
              # do something
              object = curr_objects_with_type[1]
              next_object = next_objects_with_type[1]
              # # # # @show curr_objects_with_type
              # # # # @show next_objects_with_type
              curr_objects_with_type = filter(o -> o.id != object.id, curr_objects_with_type)
              if distance(object.position, next_object.position) < 5 * unitSize
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
          closest_objects = compute_closest_objects(curr_objects_with_type, next_objects_with_type)
          # # collect tuples with the same minimum distance 
          # equal_distance_dict = Dict()
          # for y in closest_objects 
          #   x = (y[1], filter(id -> id in map(o -> o.id, next_objects_with_type) , y[2]))
          #   d = x[2] != [] ? distance(filter(o -> o.id == x[1], curr_objects_with_type)[1].position, filter(o -> o.id == x[2][1], next_objects_with_type)[1].position) : 30
          #   if !(d in keys(equal_distance_dict))
          #     equal_distance_dict[d] = [x] 
          #   else
          #     push!(equal_distance_dict[d], x)
          #   end
          # end

          # # sort tuples within each minimum distance by number of corresponding next elements; tuples with fewer next choices 
          # # precede tuples with more next choices
          # for key in collect(keys(equal_distance_dict))
          #   if key == 0 
          #     equal_distance_dict[key] = reverse(sort(equal_distance_dict[key], by=x -> length(x[2])))
          #   else
          #     equal_distance_dict[key] = sort(equal_distance_dict[key], by=x -> length(x[2]))
          #   end
          # end
          # # # # println("TIS I")
          # # # # # @show minimum(collect(keys(equal_distance_dict)))
          # # # # # @show equal_distance_dict[minimum(collect(keys(equal_distance_dict)))][1]
          # closest_objects = vcat(map(key -> equal_distance_dict[key], sort(collect(keys(equal_distance_dict))))...)
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

  # # hack; fix this later 
  # for object_id in collect(keys(object_mapping))
  #   if length(object_mapping[object_id]) != length(observations)
  #     push!(object_mapping[object_id], [nothing for i in (length(object_mapping[object_id]) + 1):length(observations)]...)
  #   end
  # end

  (object_types, object_mapping, "white", gridsize)  
end

function compute_closest_objects(curr_objects, next_objects)
  if length(curr_objects) == 0 || length(next_objects) == 0 
    []
  else 
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
  
    # if object type has a color field, order tuples with a same-color closest next object before those without one
    if length([curr_objects..., next_objects...][1].type.custom_fields) > 0 
      zero_distance_objects_lengths_dict = Dict()
      for tuple in zero_distance_objects 
        num_closest_objects = length(tuple[2])
        if !(num_closest_objects in keys(zero_distance_objects_lengths_dict))
          zero_distance_objects_lengths_dict[num_closest_objects] = [tuple]
        else
          push!(zero_distance_objects_lengths_dict[num_closest_objects], tuple)
        end
      end
      
      zero_distance_objects_new = []
      for len in reverse(sort(collect(keys(zero_distance_objects_lengths_dict))))
        tuples = zero_distance_objects_lengths_dict[len]
        tuples_with_same_color_next = filter(t -> length(filter(next_id -> filter(y -> y.id == next_id, next_objects)[1].custom_field_values[1] == filter(z -> z.id == t[1], curr_objects)[1].custom_field_values[1], t[2])) > 0, tuples)
        tuples_without_same_color_next = filter(t -> length(filter(next_id -> filter(y -> y.id == next_id, next_objects)[1].custom_field_values[1] == filter(z -> z.id == t[1], curr_objects)[1].custom_field_values[1], t[2])) == 0, tuples)
        modified_tuples = vcat(tuples_with_same_color_next, tuples_without_same_color_next)
        push!(zero_distance_objects_new, modified_tuples...)
        zero_distance_objects = zero_distance_objects_new
      end
    else
      zero_distance_objects = reverse(sort(zero_distance_objects, by=x -> length(x[2])))
    end
    
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

    # if the object type has a color field, order tuples with a same-color closest next object before those without one
    if length([curr_objects..., next_objects...][1].type.custom_fields) == 0 # no color field
      closest_objects = vcat(map(key -> equal_distance_dict[key], sort(collect(keys(equal_distance_dict))))...)
    else # color field
      closest_objects = []
      for key in sort(collect(keys(equal_distance_dict)))
        # @show key 
        # @show equal_distance_dict[key]

        equal_distance_dict[key] = sort(equal_distance_dict[key], by=x -> length(x[2]))
        next_objects_length_dict = Dict() 
        
        for tuple in equal_distance_dict[key] 
          num_closest_objects = length(tuple[2])
          if !(num_closest_objects in keys(next_objects_length_dict))
            next_objects_length_dict[num_closest_objects] = [tuple]
          else
            push!(next_objects_length_dict[num_closest_objects], tuple)
          end
        end
  
        for len in sort(collect(keys(next_objects_length_dict)))
          tuples = next_objects_length_dict[len]
          tuples_with_same_color_next = filter(t -> length(filter(next_id -> filter(y -> y.id == next_id, next_objects)[1].custom_field_values[1] == filter(z -> z.id == t[1], curr_objects)[1].custom_field_values[1], t[2])) > 0, tuples)
          tuples_without_same_color_next = filter(t -> length(filter(next_id -> filter(y -> y.id == next_id, next_objects)[1].custom_field_values[1] == filter(z -> z.id == t[1], curr_objects)[1].custom_field_values[1], t[2])) == 0, tuples)
          modified_tuples = vcat(tuples_with_same_color_next, tuples_without_same_color_next)
          push!(closest_objects, modified_tuples...)
        end 
      end

    end

    # closest_objects = sort(closest_objects, by=x -> distance(filter(o -> o.id == x[1], curr_objects)[1].position, filter(o -> o.id == x[2][1], next_objects)[1].position))
    
    # # # @show vcat(zero_distance_objects, closest_objects)
    vcat(zero_distance_objects, closest_objects)  
  end
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
  (sort(translated_hypothesis_object) == sort(translated_actual_object)) && hypothesis_object.alive
end

# function singletimestepsolution_program(observations, user_events, grid_size=16)
  
#   matrix, unformatted_matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size)
#   singletimestepsolution_program_given_matrix(matrix, object_decomposition, grid_size)
# end

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
    # # println("am i working")
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

  matrix_copy = deepcopy(matrix)
  for row in 1:size(matrix_copy)[1]
    for col in 1:size(matrix_copy)[2]
      matrix_copy[row, col] = filter(x -> !occursin("uniformChoice", x) && !occursin("randomPositions", x) && !occursin("Random", x), matrix_copy[row, col])
    end
  end
  
  program_no_update_rules = program_string_synth_standard_groups((object_types, object_mapping, background, grid_size))
  time = """(: time Int)\n  (= time (initnext 0 (+ time 1)))"""
  update_rule_times = filter(time -> join(map(l -> l[1], matrix_copy[:, time]), "") != "", [1:size(matrix_copy)[2]...])
  update_rules = join(map(time -> """(on (== time $(time - 1))\n  (let\n    ($(join(map(id -> !occursin("--> obj (prev obj)", matrix_copy[id, time][1]) ? (occursin("addObj", matrix_copy[id, time][1]) ? format_matrix_function(matrix_copy[id, time][1], object_mapping[id][time + 1]) : matrix_copy[id, time][1]) : "", 
                          collect(1:size(matrix_copy)[1])), "\n    "))))\n  )""", update_rule_times), "\n  ")
                        
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

function abstract_position(position, prev_abstract_positions, user_event, object_decomposition, object_mapping, time, pedro=false, max_iters=100)
  # # println("ABSTRACT POSITION")
  # # @show position 
  # # @show prev_abstract_positions 
  # # @show user_event 
  # # # @show object_decomposition 

  object_types, prev_objects, _, _ = object_decomposition
  solutions = []
  iters = 0
  prev_used_index = 1
  using_prev = false

  hypothesis_positions = generate_hypothesis_positions(position, vcat(prev_objects, user_event), object_types, pedro)
  for hypothesis_position in hypothesis_positions 
    # hypothesis_position_program = generate_hypothesis_position_program(hypothesis_position, position, object_decomposition)
    hypothesis_position_program = program_string_synth_update_rule(object_decomposition)
    hypothesis_position_program = string(hypothesis_position_program[1:end-2], 
                                "\n",
                                """
                                (: matches Bool)
                                (= matches (initnext false (prev matches)))

                                (on (== $(hypothesis_position) (Position $(position[1]) $(position[2]))) (= matches true)) 
                                """, "\n",
                              ")")

    # # println("HYPOTHESIS PROGRAM")
    # println(hypothesis_position_program)
    expr = parseautumn(hypothesis_position_program)
    # global expr = striplines(compiletojulia(parseautumn(hypothesis_position_program)))
    # ## # # @show expr
    # module_name = Symbol("CompiledProgram$(global_iters)")
    # global expr.args[1].args[2] = module_name
    # # # # # @show expr.args[1].args[2]
    # global mod = @eval $(expr)
    # # # # # @show repr(mod)
    # @show user_event
    if !isnothing(user_event) && occursin("click", split(user_event, " ")[1])
      global x = parse(Int, split(user_event, " ")[2])
      global y = parse(Int, split(user_event, " ")[3])
      hypothesis_frame_state = interpret_over_time(expr, 1, [(click=AutumnStandardLibrary.Click(x, y),)]).state
    else
      hypothesis_frame_state = interpret_over_time(expr, 1).state
    end

    hypothesis_matches = hypothesis_frame_state.matchesHistory[1]
    if hypothesis_matches
      # success 
      # # println("SUCCESS")
      push!(solutions, hypothesis_position)
      if !(hypothesis_position in prev_abstract_positions)
        push!(prev_abstract_positions, hypothesis_position)
      end
    end

    iters += 1
    global global_iters += 1
  end

  # manually-checked abstract positions 
  start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
  potential_object_types = filter(t -> t.color != "darkgray", object_types)
  for object_type_1 in potential_object_types 
    ids_with_type_1 = filter(id -> !isnothing(object_mapping[id][time]) && object_mapping[id][time].type.id == object_type_1.id, collect(keys(object_mapping)))
    for object_type_2 in potential_object_types 
      if object_type_1.id != object_type_2.id
        ids_with_type_2 = filter(id -> !isnothing(object_mapping[id][time]) && object_mapping[id][time].type.id == object_type_2.id, collect(keys(object_mapping))) 
        # check exact position matches 
        type_2_objects_matching_ids = filter(id -> object_mapping[id][time].position == position &&
                                                   filter(d -> abs(d[1]) + abs(d[2]) <= 20, map(id1 -> displacement(position, object_mapping[id1][time].position), ids_with_type_1)) != [], 
                                             ids_with_type_2)

        for id2 in type_2_objects_matching_ids 
          contained_in_list = isnothing(object_mapping[ids_with_type_1[1]][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[ids_with_type_1[1]][1].type.id, collect(keys(object_mapping))) > 1)
          contained_in_list_id2 = isnothing(object_mapping[id2][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[id2][1].type.id, collect(keys(object_mapping))) > 1)
          if contained_in_list_id2 
            if contained_in_list 
              abstracted_expr = "(firstWithDefault (map (--> obj (.. obj origin)) (filter (--> obj (<= (distance (prev obj) (prev addedObjType$(object_type_1.id)List)) 20)) (prev addedObjType$(object_type_2.id)List))))"          
            else
              abstracted_expr = "(firstWithDefault (map (--> obj (.. obj origin)) (filter (--> obj (<= (distance (prev obj) (prev obj$(ids_with_type_1[1]))) 20)) (prev addedObjType$(object_type_2.id)List))))"
            end
          else
            abstracted_expr = "(.. (prev obj$(ids_with_type_2[1])) origin)"
          end
          push!(solutions, abstracted_expr)
        end
 
        # check approximate position matches 
        type_2_objects_matching_ids_prox = []
        for scalar in type_displacements[object_type_2.id]
          disps = [(0, scalar), (0, -scalar), (scalar, 0), (-scalar, 0)]
          matches = filter(id -> displacement(object_mapping[id][time].position, position) in disps &&
                                 filter(d -> abs(d[1]) + abs(d[2]) <= 20, map(id1 -> displacement(position, object_mapping[id1][time].position), ids_with_type_1)) != [], 
                           ids_with_type_2)
          push!(type_2_objects_matching_ids_prox, matches...)
        end

        for id2 in type_2_objects_matching_ids_prox
          scalar = abs(sum([displacement(position, object_mapping[id2][time].position)...]))
          contained_in_list = isnothing(object_mapping[ids_with_type_1[1]][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[ids_with_type_1[1]][1].type.id, collect(keys(object_mapping))) > 1)
          contained_in_list_id2 = isnothing(object_mapping[id2][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[id2][1].type.id, collect(keys(object_mapping))) > 1)

          if contained_in_list_id2 
            if contained_in_list 
              abstracted_expr = "(firstWithDefault (map (--> obj (.. obj origin)) (filter (--> obj (<= (distance (prev obj) (prev addedObjType$(object_type_1.id)List)) 20)) (prev addedObjType$(object_type_2.id)List))))"          
            else
              abstracted_expr = "(firstWithDefault (map (--> obj (.. obj origin)) (filter (--> obj (<= (distance (prev obj) (prev obj$(ids_with_type_1[1]))) 20)) (prev addedObjType$(object_type_2.id)List))))"
            end
          else
            abstracted_expr = "(.. (prev obj$(ids_with_type_2[1])) origin)"
          end
          push!(solutions, "(move $(abstracted_expr) (uniformChoice (list (Position 0 $(scalar)) (Position 0 -$(scalar)) (Position $(scalar) 0) (Position -$(scalar) 0))))")
        end

      end
    end
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
      # # println("HYPOTHESIS PROGRAM")
      # println(hypothesis_string_program)
      expr = parseautumn(hypothesis_string_program)
      # global expr = striplines(compiletojulia(parseautumn(hypothesis_string_program)))
      ## # # @show expr
      # module_name = Symbol("CompiledProgram$(global_iters)")
      # global expr.args[1].args[2] = module_name
      # # # # # @show expr.args[1].args[2]
      # global mod = @eval $(expr)
      # # # # @show repr(mod)
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

function generate_on_clauses(matrix, unformatted_matrix, object_decomposition, user_events, global_event_vector_dict, redundant_events_set, grid_size=16, desired_solution_count=1, desired_per_matrix_solution_count=1, interval_painting_param=false, z3_option="none", time_based=true, z3_timeout=0, sketch_timeout=0)
  object_types, object_mapping, background, dim = object_decomposition
  solutions = []

  # pre_filtered_matrix = pre_filter_with_direction_biases(matrix, user_events, object_decomposition) 
  # filtered_matrix = filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition)[1]
  
  filtered_matrices = []

  # pre-filter by removing NoCollision update functions 

  pre_filtered_matrix_1 = pre_filter_remove_NoCollision(matrix)
  if pre_filtered_matrix_1 != false 
    pre_filtered_non_random_matrix_1 = deepcopy(matrix)
    for row in 1:size(pre_filtered_non_random_matrix_1)[1]
      for col in 1:size(pre_filtered_non_random_matrix_1)[2]
        pre_filtered_non_random_matrix_1[row, col] = filter(x -> !occursin("randomPositions", x), pre_filtered_non_random_matrix_1[row, col])
      end
    end
    filtered_non_random_matrices = filter_update_function_matrix_multiple(pre_filtered_non_random_matrix_1, object_decomposition, multiple=true)
    push!(filtered_matrices, filtered_non_random_matrices...)
  end

  # pre filter by removing non-NoCollision update functions 
  pre_filtered_matrix_1 = pre_filter_remove_non_NoCollision(matrix)
  if pre_filtered_matrix_1 != false 
    pre_filtered_non_random_matrix_1 = deepcopy(matrix)
    for row in 1:size(pre_filtered_non_random_matrix_1)[1]
      for col in 1:size(pre_filtered_non_random_matrix_1)[2]
        pre_filtered_non_random_matrix_1[row, col] = filter(x -> !occursin("randomPositions", x), pre_filtered_non_random_matrix_1[row, col])
      end
    end
    filtered_non_random_matrices = filter_update_function_matrix_multiple(pre_filtered_non_random_matrix_1, object_decomposition, multiple=true)
    push!(filtered_matrices, filtered_non_random_matrices...)
  end

  # add non-random filtered matrices to filtered_matrices
  non_random_matrix = deepcopy(matrix)
  for row in 1:size(non_random_matrix)[1]
    for col in 1:size(non_random_matrix)[2]
      non_random_matrix[row, col] = filter(x -> !occursin("randomPositions", x), non_random_matrix[row, col])
    end
  end
  filtered_non_random_matrices = filter_update_function_matrix_multiple(non_random_matrix, object_decomposition, multiple=true)
  # filtered_non_random_matrices = filtered_non_random_matrices[1:min(4, length(filtered_non_random_matrices))]
  push!(filtered_matrices, filtered_non_random_matrices...)
  

  # add direction-bias-filtered matrix to filtered_matrices 
  pre_filtered_matrix = pre_filter_with_direction_biases(deepcopy(matrix), user_events, object_decomposition) 
  push!(filtered_matrices, filter_update_function_matrix_multiple(pre_filtered_matrix, object_decomposition, multiple=false)...)

  # add random filtered matrices to filtered_matrices 
  random_matrix = deepcopy(matrix)
  for row in 1:size(random_matrix)[1]
    for col in 1:size(random_matrix)[2]
      if filter(x -> occursin("uniformChoice", x) || occursin("randomPositions", x), random_matrix[row, col]) != []
        random_matrix[row, col] = filter(x -> occursin("uniformChoice", x) || occursin("randomPositions", x), random_matrix[row, col])
      end
    end
  end
  filtered_random_matrices = filter_update_function_matrix_multiple(random_matrix, object_decomposition, multiple=true)
  filtered_random_matrices = filtered_random_matrices[1:min(4, length(filtered_random_matrices))]
  push!(filtered_matrices, filtered_random_matrices...)

  # # add "chaos" solution to filtered_matrices 
  filtered_unformatted_matrix = filter_update_function_matrix_multiple(unformatted_matrix, object_decomposition, multiple=false)[1]
  push!(filtered_matrices, filter_update_function_matrix_multiple(construct_chaos_matrix(filtered_unformatted_matrix, object_decomposition), object_decomposition, multiple=false)...)

  unique!(filtered_matrices)
  # # @show length(filtered_matrices)

  for filtered_matrix_index in 1:length(filtered_matrices)
    # @show filtered_matrix_index
    # # @show length(filtered_matrices)
    # # @show solutions
    filtered_matrix = filtered_matrices[filtered_matrix_index]

    if (length(filter(x -> x[1] != [], solutions)) >= desired_solution_count) # || ((length(filter(x -> x[1] != [], solutions)) > 0) && length(filter(x -> occursin("randomPositions", x), vcat(vcat(filtered_matrix...)...))) > 0) 
      # if we have reached a sufficient solution count or have found a solution before trying random solutions, exit
      # # println("BREAKING")
      # # @show length(solutions)
      break
    end

    problem_contexts = []
    solutions_per_matrix_count = 0
    init_on_clauses = []
    init_global_var_dict = Dict()

    anonymized_filtered_matrix = deepcopy(filtered_matrix)
    for i in 1:size(matrix)[1]
      for j in 1:size(matrix)[2]
        anonymized_filtered_matrix[i,j] = [replace(filtered_matrix[i, j][1], "id) $(i)" => "id) x")]
      end
    end
    
    init_global_object_decomposition = object_decomposition
    init_global_state_update_times_dict = Dict(1 => ["" for x in 1:length(user_events)])
    init_object_specific_state_update_times_dict = Dict()
  
    init_global_state_update_on_clauses = []
    init_object_specific_state_update_on_clauses = []
    init_state_update_on_clauses = []
    
    push!(problem_contexts, (1, 1, deepcopy(init_on_clauses),
                                   deepcopy(init_global_var_dict),
                                   deepcopy(init_global_object_decomposition), 
                                   deepcopy(init_global_state_update_times_dict),
                                   deepcopy(init_object_specific_state_update_times_dict),
                                   deepcopy(init_global_state_update_on_clauses),
                                   deepcopy(init_object_specific_state_update_on_clauses),
                                   deepcopy(init_state_update_on_clauses) ))

    while length(problem_contexts) > 0 && solutions_per_matrix_count < desired_per_matrix_solution_count
      # # println("NEW PROBLEM CONTEXT")
      failed = false
      problem_context = problem_contexts[1]
      problem_contexts = problem_contexts[2:end]

      # extract context variables
      context_object_type_index, 
      context_update_rule_index, 
      on_clauses,
      global_var_dict,
      global_object_decomposition,
      global_state_update_times_dict,
      object_specific_state_update_times_dict,
      global_state_update_on_clauses,
      object_specific_state_update_on_clauses,
      state_update_on_clauses = problem_context 

      # reset global_event_vector_dict and redundant_events_set for each new context:
      # remove events dealing with global or object-specific state
      for event in keys(global_event_vector_dict)
        if occursin("globalVar", event) || occursin("field1", event)
          delete!(global_event_vector_dict, event)
        end
      end

      for event in redundant_events_set 
        if occursin("globalVar", event) || occursin("field1", event)
          delete!(redundant_events_set, event)
        end
      end

      for type_index in context_object_type_index:length(object_types)
        object_type = object_types[type_index]

        type_id = object_type.id
        object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == object_type.id, collect(keys(object_mapping))))
    
        all_update_rules = filter(rule -> rule != "", unique(vcat(vec(anonymized_filtered_matrix[object_ids, :])...)))
    
        update_rule_set = vcat(filter(r -> r != "", vcat(map(id -> map(x -> replace(x[1], "obj id) $(id)" => "obj id) x"), filtered_matrix[id, :]), object_ids)...))...)
    
        addObj_rules = filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...))
        unique_addObj_rules = unique(filter(rule -> occursin("addObj", rule), vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids)...)))
        addObj_times_dict = Dict()
    
        for rule in unique_addObj_rules 
          addObj_times_dict[rule] = sort(unique(vcat(map(id -> findall(r -> r == rule, vcat(filtered_matrix[id, :]...)), object_ids)...)))
        end
        
        group_addObj_rules = false
        addObj_count = 0
        if length(unique(collect(values(addObj_times_dict)))) == 1
          group_addObj_rules = true
          all_update_rules = filter(r -> !(r in addObj_rules), all_update_rules)
          push!(all_update_rules, addObj_rules[1]) 
          addObj_count = count(r -> occursin("addObj", r), vcat(filtered_matrix[:, collect(values(addObj_times_dict))[1][1]]...))
        end
        
        no_change_rules = filter(x -> is_no_change_rule(x), unique(all_update_rules))
        all_update_rules = reverse(sort(filter(x -> !is_no_change_rule(x), all_update_rules), by=x -> count(y -> y == x, update_rule_set)))
        all_update_rules = unique(all_update_rules)

        # all_update_rules = filter(x -> !is_no_change_rule(x), unique(all_update_rules))

        # # sort all_update_rules 
        # freq_dict = Dict()
        # for u in all_update_rules 
        #   c = count(x -> x == u, update_rule_set)
        #   if c in keys(freq_dict) 
        #     push!(freq_dict[c], u) 
        #   else
        #     freq_dict[c] = [u]
        #   end
        # end

        # for freq in collect(keys(freq_dict))
        #   freq_dict[freq] = sort(freq_dict[freq], by=u -> sort(findall(x -> x == [u], anonymized_filtered_matrix), by=y -> y[2])[1][2])
        # end
        # all_update_rules = vcat(map(freq -> freq_dict[freq], reverse(sort(collect(keys(freq_dict)))))...)

        all_update_rules = [no_change_rules..., all_update_rules...]
  
        # @show type_id 
        # @show all_update_rules
        for update_rule_index in context_update_rule_index:length(all_update_rules)
          # # @show update_rule_index 
          # # @show length(all_update_rules)
          update_rule = all_update_rules[update_rule_index]
          # # # @show global_object_decomposition
          if update_rule != "" && !is_no_change_rule(update_rule)
            # # println("UPDATE_RULEEE")
            # println(update_rule)
            events, event_is_globals, event_vector_dict, observation_data_dict = generate_event(update_rule, all_update_rules, object_ids[1], object_ids, matrix, filtered_matrix, global_object_decomposition, user_events, state_update_on_clauses, global_var_dict, global_event_vector_dict, grid_size, redundant_events_set, 1, 400, z3_option, time_based, z3_timeout, sketch_timeout)
            global_event_vector_dict = event_vector_dict
            # # println("EVENTS")
            # println(events)
            # # # @show event_vector_dict
            # # # @show observation_data_dict
            if events != []
              event = events[1]
              event_is_global = event_is_globals[1]
              on_clause = format_on_clause(replace(update_rule, ".. obj id) x" => ".. obj id) $(object_ids[1])"), replace(event, ".. obj id) x" => ".. obj id) $(object_ids[1])"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, event_is_global, grid_size, addObj_count)
              push!(on_clauses, on_clause)
              on_clauses = unique(on_clauses)
              # # println("ADDING EVENT WITHOUT NEW STATE")
              # @show event 
              # @show update_rule
              # @show on_clause
              # @show length(on_clauses)
              # @show on_clauses
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
                  true_times = unique(vcat(map(trajectory -> findall(rule -> rule == update_rule, vcat(trajectory...)), object_trajectories)...))
                  object_trajectory = []
                else 
                  ids_with_rule = map(idx -> object_ids[idx], findall(idx_set -> idx_set != [], map(id -> findall(rule -> rule[1] == update_rule, anonymized_filtered_matrix[id, :]), object_ids)))
                  trajectory_lengths = map(id -> length(unique(filter(x -> x != "", anonymized_filtered_matrix[id, :]))), ids_with_rule)
                  max_index = findall(x -> x == maximum(trajectory_lengths) , trajectory_lengths)[1]
                  object_id = ids_with_rule[max_index]
                  object_trajectory = anonymized_filtered_matrix[object_id, :]
                  true_times = unique(findall(rule -> rule == update_rule, vcat(object_trajectory...)))
                end
      
                state_solutions = generate_new_state(update_rule, true_times, global_event_vector_dict, object_trajectory, global_var_dict, global_state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, interval_painting_param)
                # @show state_solutions 
                
                # # # @show on_clause 
                # # # @show new_state_update_times_dict 
                # # # @show new_global_var_dict 
  
                if length(filter(sol -> sol[1] != "", state_solutions)) == 0 # failure 
                  failed = true 
                  # # println("STATE SEARCH FAILURE")
                  break 
                else
                  state_solutions = filter(sol -> sol[1] != "", state_solutions)
                  on_clause, new_global_var_dict, new_state_update_times_dict = state_solutions[1]

                  # old values 
                  old_on_clauses = deepcopy(on_clauses)
                  old_global_object_decomposition = deepcopy(global_object_decomposition)
                  old_global_state_update_times_dict = deepcopy(global_state_update_times_dict)
                  old_object_specific_state_update_times_dict = deepcopy(object_specific_state_update_times_dict)
                  old_global_state_update_on_clauses = deepcopy(global_state_update_on_clauses)
                  old_object_specific_state_update_on_clauses = deepcopy(object_specific_state_update_on_clauses)
                  old_state_update_on_clauses = deepcopy(state_update_on_clauses)

                  on_clause = format_on_clause(split(replace(on_clause, ".. obj id) x" => ".. obj id) $(object_ids[1])"), "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), ".. obj id) x" => ".. obj id) $(object_ids[1])"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, true, grid_size, addObj_count)
                  push!(on_clauses, on_clause)
                  global_var_dict = deepcopy(new_global_var_dict) 
                  global_state_update_on_clauses = vcat(map(k -> filter(x -> x != "", new_state_update_times_dict[k]), collect(keys(new_state_update_times_dict)))...) # vcat(state_update_on_clauses..., filter(x -> x != "", new_state_update_times)...)
                  state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
                  global_state_update_times_dict = new_state_update_times_dict
  
                  state_update_on_clauses = unique(state_update_on_clauses)
                  on_clauses = unique(on_clauses)

                  # # println("ADDING EVENT WITH NEW STATE")
                  # @show update_rule
                  # @show on_clause
                  # @show length(on_clauses)
                  # @show on_clauses    
                  
                  # # # @show global_var_dict 
                  # # # @show state_update_on_clauses 
                  # # # @show global_state_update_times_dict
                  # # # @show object_specific_state_update_times_dict

                  # if there are other state solutions, add them as new problem contexts!
                  for sol_index in 2:length(state_solutions) 
                    new_context_on_clause, new_context_new_global_var_dict, new_context_new_state_update_times_dict = state_solutions[sol_index]

                    new_context_on_clauses = deepcopy(old_on_clauses)
                    new_context_global_object_decomposition = deepcopy(old_global_object_decomposition)
                    new_context_global_state_update_times_dict = deepcopy(old_global_state_update_times_dict)
                    new_context_object_specific_state_update_times_dict = deepcopy(old_object_specific_state_update_times_dict)
                    new_context_global_state_update_on_clauses = deepcopy(old_global_state_update_on_clauses)
                    new_context_object_specific_state_update_on_clauses = deepcopy(old_object_specific_state_update_on_clauses)
                    new_context_state_update_on_clauses = deepcopy(old_state_update_on_clauses)

                    new_context_on_clause = format_on_clause(split(replace(new_context_on_clause, ".. obj id) x" => ".. obj id) $(object_ids[1])"), "\n")[2][1:end-1], replace(replace(split(new_context_on_clause, "\n")[1], "(on " => ""), ".. obj id) x" => ".. obj id) $(object_ids[1])"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, true, grid_size, addObj_count)
                    push!(new_context_on_clauses, new_context_on_clause)
                    new_context_global_var_dict = new_context_new_global_var_dict
                    new_context_global_state_update_on_clauses = vcat(map(k -> filter(x -> x != "", new_context_new_state_update_times_dict[k]), collect(keys(new_context_new_state_update_times_dict)))...) # vcat(state_update_on_clauses..., filter(x -> x != "", new_state_update_times)...)
                    new_context_state_update_on_clauses = vcat(new_context_global_state_update_on_clauses, new_context_object_specific_state_update_on_clauses)
                    new_context_global_state_update_times_dict = new_context_new_state_update_times_dict
    
                    new_context_state_update_on_clauses = unique(new_context_state_update_on_clauses)
                    new_context_on_clauses = unique(new_context_on_clauses)

                    problem_context = (type_index, update_rule_index + 1, new_context_on_clauses,
                                                                          new_context_global_var_dict,
                                                                          new_context_global_object_decomposition, 
                                                                          new_context_global_state_update_times_dict,
                                                                          new_context_object_specific_state_update_times_dict,
                                                                          new_context_global_state_update_on_clauses,
                                                                          new_context_object_specific_state_update_on_clauses,
                                                                          new_context_state_update_on_clauses )

                    push!(problem_contexts, problem_context)
                  end
      
                  for event in collect(keys(global_event_vector_dict))
                    if occursin("globalVar", event)
                      delete!(global_event_vector_dict, event)
                    end
                  end
  
                end   
              else # search for object-specific state
                update_function_times_dict = Dict()
                for object_id in object_ids 
                  update_function_times_dict[object_id] = findall(x -> x == 1, observation_data_dict[object_id])
                end
                on_clause, new_state_update_on_clauses, new_object_decomposition, new_object_specific_state_update_times_dict = generate_new_object_specific_state(update_rule, update_function_times_dict, event_vector_dict, type_id, global_object_decomposition, object_specific_state_update_times_dict, global_var_dict)            
                
                if on_clause == "" 
                  failed = true 
                  break
                else
                  # # # @show new_object_specific_state_update_times_dict
                  object_specific_state_update_times_dict = new_object_specific_state_update_times_dict
      
                  # on_clause = format_on_clause(split(on_clause, "\n")[2][1:end-1], replace(replace(split(on_clause, "\n")[1], "(on " => ""), "(== (.. obj id) x)" => "(== (.. obj id) $(object_ids[1]))"), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false)
                  push!(on_clauses, on_clause)
      
                  global_object_decomposition = new_object_decomposition
                  object_types, object_mapping, background, dim = global_object_decomposition
                  
                  # # println("UPDATEEE")
                  # # # @show global_object_decomposition
      
                  # new_state_update_on_clauses = map(x -> format_on_clause(split(x, "\n")[2][1:end-1], replace(split(x, "\n")[1], "(on " => ""), object_ids[1], object_ids, object_type, group_addObj_rules, addObj_rules, object_mapping, false), new_state_update_on_clauses)
                  object_specific_state_update_on_clauses = unique(vcat(object_specific_state_update_on_clauses..., new_state_update_on_clauses...))
                  state_update_on_clauses = vcat(global_state_update_on_clauses, object_specific_state_update_on_clauses)
                  for event in collect(keys(global_event_vector_dict))
                    if occursin("field1", event)
                      delete!(global_event_vector_dict, event)
                    end
                  end
  
                  state_update_on_clauses = unique(state_update_on_clauses)
                  on_clauses = unique(on_clauses)
  
    
                end
    
              end
    
            end
    
          end

        end
        if failed 
          break
        end
      end

      if failed 
        push!(solutions, ([], [], [], Dict()))
      else
        # @show filtered_matrix_index
        push!(solutions, ([deepcopy(on_clauses)..., deepcopy(state_update_on_clauses)...], deepcopy(global_object_decomposition), deepcopy(global_var_dict)))
        # save("solution_$(Dates.now()).jld", "solution", solutions[end])
        solutions_per_matrix_count += 1 
      end
    end
  end
  # @show solutions 
  solutions 
end

function format_on_clause(update_rule, event, object_id, object_ids, type_id, group_addObj_rules, addObj_rules, object_mapping, event_is_global, grid_size, addObj_count)
  if occursin("addObj", update_rule) # handle addition of object rules 
    if group_addObj_rules # several objects are added simultaneously
      # # println("DID I MAKE IT")
      if occursin("randomPositions", addObj_rules[1])
        # # println("DID I MAKE IT 2")
        on_clause = "(on $(event)\n$(replace(replace(addObj_rules[1], "randomPositions $(grid_size) 1" => "randomPositions $(grid_size) $(addObj_count)"), "randomPositions GRID_SIZE 1" => "randomPositions GRID_SIZE $(addObj_count)")))"
      elseif occursin("uniformChoice", addObj_rules[1])
        if addObj_count isa AbstractArray 
          on_clause = "(on $(event)\n$(addObj_rules[1][1:end-2]) (uniformChoice (list $(join(collect(addObj_count[1]:addObj_count[2]), " ")))))))"
        else
          on_clause = "(on $(event)\n$(addObj_rules[1][1:end-2]) $(addObj_count))))"
        end
      else
        on_clause = "(on $(event)\n(let ($(join(unique(addObj_rules), "\n")))))"
      end
    else # addition of just one object
      on_clause = "(on $(event)\n$(update_rule))"
    end
  else # handle other update rules
    if event_is_global 
      if occursin("(--> obj (== (.. obj id) $(object_id)))", update_rule) 
        # event is global, but objects in update rule are in list  
        reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj true)")
        on_clause = "(on $(event)\n$(reformatted_rule))"
      else # event is global and object in update rule is not in a list
        on_clause = "(on $(event)\n$(update_rule))"
      end
    else # event is object-specific
      if occursin("(--> obj (== (.. obj id) $(object_id)))", update_rule) # update rule is object-specific
        reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
        reformatted_rule = replace(update_rule, "(--> obj (== (.. obj id) $(object_id)))" => "(--> obj $(reformatted_event))")
        
        # second_reformatted_event = replace(event, "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(object_type.id)List))" => "(prev addedObjType$(object_type.id)List)")
        
        on_clause = "(on true\n$(reformatted_rule))"
      else
        on_clause = "(on $(event)\n$(update_rule))"
      end
    end
  end
  on_clause 
end

function check_matrix_complete(matrix)
  complete = true
  for row in 1:size(matrix)[1]
    for col in 1:size(matrix)[2]
      if length(matrix[row, col]) == 0 
        complete = false 
        break
      end
    end
  end
  complete
end

"Select one update function from each matrix cell's update function set, which may contain multiple update functions"
function filter_update_function_matrix_multiple(matrix, object_decomposition; multiple = true, base = 2)
  object_types, object_mapping, _, _ = object_decomposition

  matrix_complete = check_matrix_complete(matrix)
  if !matrix_complete 
    return []
  end

  new_matrices = []
  type_id_and_colors = []
  # # @show object_types 
  # # # @show object_decomposition 
  for type in object_types 
    if length(type.custom_fields) == 0
      push!(type_id_and_colors, (type.id, nothing))
    else
      for color in type.custom_fields[1][3]
        push!(type_id_and_colors, (type.id, color))
      end
      # push!(type_id_and_colors, (type.id, nothing))
    end
  end

  num_permutations = multiple ? (base^(length(type_id_and_colors)) - 1) : 0
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
      # # # # # @show same_type_update_function_sets 
      for other_object_id in 1:size(matrix)[1]

        other_object_type = filter(object -> !isnothing(object), object_mapping[other_object_id])[1].type
        
        if other_object_type.id == type.id
          # # # # # @show other_object_id

          for time in 1:size(matrix)[2]
            if !isnothing(object_mapping[other_object_id][time])
              color = object_mapping[other_object_id][time].custom_field_values[1]
              # # # # # @show color

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

  global_sorted_update_functions_dict = Dict()
  for object_type in object_types 
    type_id = object_type.id 
    if length(object_type.custom_fields) == 0 
      same_type_update_function_set = same_type_update_function_sets_dict[type_id]

      # perform filtering 
      global_sorted_update_functions = reverse(sort(filter(z -> z != "", unique(same_type_update_function_set)), by=x -> count(y -> y == x, same_type_update_function_set)))
      global_sorted_frequencies = map(x -> count(y -> y == x, same_type_update_function_set), global_sorted_update_functions)
      
      # sort most-frequent update functions (top functions) by their original order in matrix
      top_indices = findall(x -> x == maximum(global_sorted_frequencies), global_sorted_frequencies)
      sorted_top_indices = sort(top_indices, by=i -> find_global_index(global_sorted_update_functions[i])) 
      top_functions = map(i -> global_sorted_update_functions[i], sorted_top_indices)
      
      non_top_functions = filter(x -> !(x in top_functions), global_sorted_update_functions)
      global_sorted_update_functions = vcat(top_functions, non_top_functions)
      global_sorted_update_functions_dict[type_id] = global_sorted_update_functions
    else
      global_sorted_update_functions_dict[type_id] = Dict()
      for color in [object_type.custom_fields[1][3]..., nothing]

        global_sorted_update_functions = reverse(sort(filter(x -> x != "", unique(same_type_update_function_sets_dict[object_type.id][color])), by=x -> count(y -> y == x, same_type_update_function_sets_dict[object_type.id][color])))
        global_sorted_frequencies = map(x -> count(y -> y == x, same_type_update_function_sets_dict[object_type.id][color]), global_sorted_update_functions)
        
        # sort most-frequent update functions (top functions) by their original order in matrix
        top_indices = findall(x -> x == maximum(global_sorted_frequencies), global_sorted_frequencies)
        sorted_top_indices = sort(top_indices, by=i -> find_global_index(global_sorted_update_functions[i])) 
        top_functions = map(i -> global_sorted_update_functions[i], sorted_top_indices)
        
        non_top_functions = filter(x -> !(x in top_functions), global_sorted_update_functions)
        global_sorted_update_functions = vcat(top_functions, non_top_functions)
        global_sorted_update_functions_dict[type_id][color] = global_sorted_update_functions
      end
    end
  end

  for perm in 0:num_permutations
    @show perm
    # bits = reverse(bitstring(perm))
    bits = join(Base.digits(perm, base = base, pad = 64), "")
    new_matrix = deepcopy(matrix)

    # for each row (trajectory) in the update function matrix, filter down its update function sets
    for object_id in 1:size(matrix)[1] 
      object_type = filter(object -> !isnothing(object), object_mapping[object_id])[1].type
      
      if length(object_type.custom_fields) == 0 # type has no color field
        global_sorted_update_functions = global_sorted_update_functions_dict[object_type.id]

        # multiplicity handling: if bit_value == 1, then consider second-most frequent update function instead of first
        type_index = findall(x -> x[1] == object_type.id, type_id_and_colors)[1]
        bit_value = parse(Int, bits[type_index])
        for time in 1:size(matrix)[2]
          update_functions = unique(map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time]))
          if length(update_functions) > 1 
            update_functions = filter(x -> x != "", update_functions)

            sorted_local_update_functions = sort(update_functions, by=x -> findall(y -> y == x, global_sorted_update_functions)[1])
            if bit_value >= length(sorted_local_update_functions) 
              top_function = sorted_local_update_functions[end]
            else
              top_function = sorted_local_update_functions[bit_value + 1]
            end

            new_matrix[object_id, time] = [top_function]
          end
        end

      else # type has color field 

        # perform filtering
        for time in 1:size(matrix)[2]
          update_functions = unique(map(s -> replace(s, "id) $(object_id)" => "id) x"), matrix[object_id, time]))
          if length(update_functions) > 1
            # println("HERE?")
            update_functions = filter(x -> x != "", update_functions)
            object = object_mapping[object_id][time]
            if !isnothing(object)
              color = object.custom_field_values[1]
            else
              color = nothing
            end

            # multiplicity handling: if bit_value == 1, then consider second-most frequent update function instead of first
            type_index = isnothing(color) ? (length(type_id_and_colors)) + 1 : findall(x -> x[1] == object_type.id && x[2] == color, type_id_and_colors)[1]
            bit_value = parse(Int, bits[type_index])

            global_sorted_update_functions = global_sorted_update_functions_dict[object_type.id][color]
            
            sorted_local_update_functions = sort(update_functions, by=x -> findall(y -> y == x, global_sorted_update_functions)[1])
            if bit_value >= length(sorted_local_update_functions) 
              top_function = sorted_local_update_functions[end]
            else
              top_function = sorted_local_update_functions[bit_value + 1]
            end

            new_matrix[object_id, time] = [top_function]
          end
        end

      end

    end

    for row in 1:size(new_matrix)[1]
      for col in 1:size(new_matrix)[2]
          if length(new_matrix[row, col]) == 0 
              # # # # @show row
              # # # # @show col
          end
      end
    end
 
    for object_id in 1:size(new_matrix)[1]
      # # # # @show object_id 
      # # # # @show new_matrix[object_id, :]
      new_matrix[object_id, :] = map(list -> [replace(list[1], " id) $(object_id)" => " id) x")], new_matrix[object_id, :])
    end
    push!(new_matrices, deepcopy(new_matrix))
    
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
  # # # # @show length(new_matrices)
  # # # # @show length(unique(new_matrices))

  unique(new_matrices)
end

function pre_filter_remove_NoCollision(matrix)
  new_matrix = deepcopy(matrix)
  new_matrix = map(cell -> filter(x -> !occursin("NoCollision", x) && !occursin("unitVector", x) && !occursin("nextLiquid", x), cell), new_matrix)
  if findall(cell -> cell == [], new_matrix) != []
    false 
  else
    new_matrix 
  end
end 

function pre_filter_remove_non_NoCollision(matrix) 
  new_matrix = deepcopy(matrix) 
  new_matrix = map(cell -> filter(x -> !(occursin("moveLeft", x) && !occursin("moveLeftNoCollision", x) ||
                                         occursin("moveRight", x) && !occursin("moveRightNoCollision", x) ||
                                         occursin("moveUp", x) && !occursin("moveUpNoCollision", x) ||
                                         occursin("moveDown", x) && !occursin("moveDownNoCollision", x)),
   cell), new_matrix) 
  if findall(cell -> cell == [], new_matrix) != []
    false  
  else
    new_matrix 
  end
end

function pre_filter_with_direction_biases(matrix, user_events, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition 

  new_matrices = []
  for type in object_types 
    new_matrix = deepcopy(matrix)
    type_id = type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
    if length(object_ids_with_type) == 1
      changed = false
      imperfect = false
      for direction in ["left", "right", "up", "down"]
        event_times = findall(event -> event == direction, user_events)
        for object_id in object_ids_with_type
          other_object_ids = filter(id -> id != object_id, object_ids_with_type)
    
          scalars = type_id in keys(type_displacements) ? type_displacements[type_id] : []
          if scalars != []
            scalar = abs(scalars[1]) 
            if direction == "left"
              x, y = (-scalar, 0)
            elseif direction == "right"
              x, y = (scalar, 0)
            elseif direction == "up"
              x, y = (0, -scalar)
            else
              x, y = (0, scalar)
            end
      
            trajectory = matrix[object_id, :]
            direction_update_at_every_time = foldl(&, map(list -> occursin("""$(x) $(y) "darkgray")""", join(list, "")), trajectory), init=true)
            for event_time in event_times 
              direction_update_at_event_time = occursin("""$(x) $(y) "darkgray")""", join(trajectory[event_time], ""))
      
              deltas = [(!isnothing(object_mapping[id][event_time]) && 
                         !isnothing(object_mapping[id][event_time + 1]) &&
                         (object_mapping[id][event_time].position != object_mapping[id][event_time + 1].position)) 
                         for id in other_object_ids]
      
              if direction_update_at_event_time && !direction_update_at_every_time && !(1 in deltas)
                new_matrix[object_id, event_time] = filter(rule -> occursin("""$(x) $(y) "darkgray")""", rule), trajectory[event_time])
                changed = true 
              else 
                imperfect = true
              end
            end
          end
        end
      end

      if changed 
        for object_id in object_ids_with_type 
          for time in 1:(length(object_mapping[object_id]) - 1)
            if !(user_events[time] in ["left", "right", "up", "down"]) && ("(= obj$(object_id) (prev obj$(object_id)))" in new_matrix[object_id, time])
              new_matrix[object_id, time] = ["(= obj$(object_id) (prev obj$(object_id)))"]
            end
          end
        end
        if imperfect 
          println("IMPERFECT!")
          wall_types = filter(t -> t.color == "darkgray", object_types)
          if wall_types == [] 
            wall_positions = []
          else
            wall_type = wall_types[1]
            wall_ids = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == wall_type.id, collect(keys(object_mapping)))
            wall_positions = vcat(map(id -> map(p -> (object_mapping[id][1].position[1] + p[1], object_mapping[id][1].position[2] + p[2]), wall_type.shape), wall_ids)...)  
          end

          # change matrix cells corresponding to times moving into walls to "prev" instead of "moveNoCollision"
          for object_id in object_ids_with_type 
            for time in 1:(length(object_mapping[object_id]) - 1)
              direction_event = user_events[time]
              if !isnothing(object_mapping[object_id]) && ("(= obj$(object_id) (prev obj$(object_id)))" in matrix[object_id, time])
                if direction_event == "left" && ((object_mapping[object_id][time].position[1] - 10, object_mapping[object_id][time].position[2]) in wall_positions)
                  new_matrix[object_id, time] = ["(= obj$(object_id) (prev obj$(object_id)))"]
                elseif direction_event == "right" && ((object_mapping[object_id][time].position[1] + 10, object_mapping[object_id][time].position[2]) in wall_positions)
                  new_matrix[object_id, time] = ["(= obj$(object_id) (prev obj$(object_id)))"]
                elseif direction_event == "up" && ((object_mapping[object_id][time].position[1], object_mapping[object_id][time].position[2] - 10) in wall_positions)
                  new_matrix[object_id, time] = ["(= obj$(object_id) (prev obj$(object_id)))"]
                elseif direction_event == "down" && ((object_mapping[object_id][time].position[1], object_mapping[object_id][time].position[2] + 10) in wall_positions) 
                  new_matrix[object_id, time] = ["(= obj$(object_id) (prev obj$(object_id)))"]
                end
              end
            end
          end
        end
      end

      push!(new_matrices, new_matrix)
    end
  end
  new_matrices
end

function construct_chaos_matrix(unformatted_matrix, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition 

  chaos_matrix = deepcopy(unformatted_matrix)
  for object_type in object_types 
    object_ids = sort(filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == object_type.id, collect(keys(object_mapping))))
    generic_update_rules = unique(filter(x -> occursin("objX", x) && !occursin("\"color\"", x), vcat([unformatted_matrix[row, col] for row in object_ids for col in 1:size(unformatted_matrix)[2]]...)))
    stripped_generic_update_rules = map(r -> replace(r, "(= objX " => "")[1:end-1], generic_update_rules)  
    # construct chaos update function (i.e. update function that is uniformChoice of all non-addObj/non-removeObj options)
    if length(object_ids) == 1
      update_rule = "(= obj$(object_ids[1]) (uniformChoice (list $(join(stripped_generic_update_rules, " ")))))"
      update_rule = replace(update_rule, "objX" => "(prev obj$(object_ids[1]))")
    else
      update_rule = "(= addedObjType$(object_type.id)List (updateObj addedObjType$(object_type.id)List (--> obj (uniformChoice (list $(join(stripped_generic_update_rules, " ")))))))"
      update_rule = replace(update_rule, "objX" => "(prev obj)")
    end

    for row in object_ids
      for col in 1:size(chaos_matrix)[2]
        if filter(x -> occursin("objX", x), chaos_matrix[row, col]) != []
          chaos_matrix[row, col] = [update_rule]
        end
      end
    end
  end
  chaos_matrix
end

function construct_brownian_motion_matrix(matrix, unformatted_matrix, object_decomposition, regularity_types)
  object_types, object_mapping, _, _ = object_decomposition 
  new_matrix = deepcopy(matrix)
  filtered_unformatted_matrix = construct_filtered_matrices(unformatted_matrix, object_decomposition, user_events)[1]

  for type in regularity_types
    type_id = type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

    choices = map(rule -> replace(rule, "(= objX" => "")[1:end-1], filter(r -> !occursin("addObj", r) && !occursin("removeObj", r), unique(vcat(map(id -> vcat(filtered_unformatted_matrix[id, :]...), object_ids_with_type)...))))
    formatted_choices = map(c -> "$(replace(c, "objX" => "(prev objX)"))", choices)
    formatted_random_choice = "(uniformChoice (list $(join(formatted_choices, " "))))"
  
    object_id = object_ids_with_type[1]
    start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
    non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
    contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)
  
    for id in object_ids_with_type 
      for time in 1:length(matrix[id, :])
        if contained_in_list && new_matrix[id, time][1] != "" && !occursin("addObj", new_matrix[id, time][1]) && !occursin("removeObj", new_matrix[id, time][1])
          new_matrix[id, time] = ["(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj $(formatted_random_choice))) (--> obj (== (.. obj id) $(id))))"]
        elseif !contained_in_list && new_matrix[id, time][1] != "" && !occursin("addObj", new_matrix[id, time][1]) && !occursin("removeObj", new_matrix[id, time][1])
          new_matrix[id, time] = ["(= obj$(object_ids_with_type[1]) $(formatted_random_choice))"]
        end
      end
    end
  end
  new_matrix
end

function construct_filtered_matrices_pedro(old_matrix, object_decomposition, user_events)
  object_types, object_mapping, _, grid_size = object_decomposition 
  
  # construct type_displacements
  for type in object_types 
    type_displacements[type.id] = []
  end
  
  for object_type in object_types 
    type_id = object_type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))

    for id in object_ids_with_type 
      for time in 1:(length(object_mapping[id]) - 1)
        if !isnothing(object_mapping[id][time]) && !isnothing(object_mapping[id][time + 1])
          disp = displacement(object_mapping[id][time].position, object_mapping[id][time + 1].position)
          if disp != (0, 0)
            scalars = map(y -> abs(y), filter(x -> x != 0, [disp...]))
            push!(type_displacements[type_id], scalars...)
          end
        end
      end
    end
  end

  for type in object_types 
    type_displacements[type.id] = unique(type_displacements[type.id])
  end

  # # set update function trajectory for all id's that never move to a constant (prev) vector 
  matrix = deepcopy(old_matrix)
  # for id in collect(keys(object_mapping))
  #   positions = unique(filter(pos -> !isnothing(pos), map(obj -> isnothing(obj) ? nothing : obj.position, object_mapping[id])))
  #   if length(positions) == 1 
  #     for time in 1:size(matrix)[2]
  #       if matrix[id, time] != [""] && !occursin("addObj", join(matrix[id, time], "")) && !occursin("removeObj", join(matrix[id, time], ""))
  #         matrix[id, time] = filter(r -> occursin("(--> obj (prev obj))", r) || occursin("(= obj$(id) (prev obj$(id)))", r), matrix[id, time])
  #       end
  #     end
  #   end
  # end

  # use only bare-bones options for agent object ("darkblue")
  agent_type = filter(t -> t.color == "darkblue", object_types)[1]
  agent_id = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == agent_type.id, collect(keys(object_mapping)))[1]
  for time in 1:size(matrix)[2]
    matrix[agent_id, time] = filter(r -> !occursin("closest", r) && !occursin("farthest", r), matrix[agent_id, time])
  end

  # initialize return value 
  filtered_matrices = []

  # add direction-bias-filtered matrix to filtered_matrices 
  pre_filtered_matrices = pre_filter_with_direction_biases(deepcopy(matrix), user_events, object_decomposition)
  for m in pre_filtered_matrices
    push!(filtered_matrices, filter_update_function_matrix_multiple(m, object_decomposition, multiple=false)...)
  end
  
  # regularity matrices: non-random and random (type-level)
  ## collect types that might behave with regularity
  potential_regularity_types = []
  for type in object_types 
    if !(type.color in ["darkgray", "darkblue"])
      ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type.id, collect(keys(object_mapping)))
      object_positions = unique(vcat(map(id -> map(o -> o.position, filter(obj -> !isnothing(obj), object_mapping[id])), ids_with_type)...))
      # @show type.id
      # @show object_positions 
      if length(object_positions) > length(ids_with_type)
        push!(potential_regularity_types, type)
      end
    end
  end

  if potential_regularity_types != []
    for adjacency_barred in [true, false]
      regularity_matrix, regularity_unformatted_matrix = construct_regularity_matrix(matrix, unformatted_matrix, object_decomposition, potential_regularity_types, adjacency_barred)
      @show regularity_matrix
      if !isnothing(regularity_matrix)
        # non-random 
        non_random_regularity_matrices = construct_filtered_matrices(regularity_matrix, object_decomposition, user_events)
        if non_random_regularity_matrices != []
          push!(filtered_matrices, non_random_regularity_matrices[1])
        end  
  
        # random 
        random_regularity_matrix_unfiltered = construct_random_regularity_matrix(regularity_matrix, regularity_unformatted_matrix, object_decomposition, potential_regularity_types)
        # @show random_regularity_matrix_unfiltered
        random_regularity_matrices = construct_filtered_matrices(random_regularity_matrix_unfiltered, object_decomposition, user_events)
        if random_regularity_matrices != []
          push!(filtered_matrices, random_regularity_matrices[1])
        end
      end

    end
  end
  
  # bare-bones non-random matrix 
  bare_bones_matrix_unfiltered = deepcopy(matrix)
  for id in 1:size(matrix)[1]
    for time in 1:size(matrix)[2]
      bare_bones_matrix_unfiltered[id, time] = filter(rule -> !occursin("closest", rule) && !occursin("farthest", rule), bare_bones_matrix_unfiltered[id, time]) != [] ? filter(rule -> !occursin("closest", rule) && !occursin("farthest", rule), bare_bones_matrix_unfiltered[id, time]) : bare_bones_matrix_unfiltered[id, time] 
    end
  end
  bare_bones_matrix = construct_filtered_matrices(bare_bones_matrix_unfiltered, object_decomposition, user_events)[1]
  push!(filtered_matrices, bare_bones_matrix)

  # standard top non-random matrix
  standard_non_random_matrix = construct_filtered_matrices(matrix, object_decomposition, user_events)[1]
  push!(filtered_matrices, standard_non_random_matrix)

  # sort update functions before adding brownian-motion-style matrices 
  filtered_matrices = sort_update_function_matrices(filtered_matrices, object_decomposition)

  # fully random (type-level)
  ## collect types that seem to behave according to brownian motion
  potential_brownian_motion_types = []
  for type in object_types 
    if !(type.color in ["darkgray", "darkblue"])
      ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type.id, collect(keys(object_mapping)))
      object_positions = unique(vcat(map(id -> map(o -> o.position, filter(obj -> !isnothing(obj), object_mapping[id])), ids_with_type)...))
      if length(object_positions) > length(ids_with_type)
        push!(potential_brownian_motion_types, type)
      end
    end
  end

  if potential_brownian_motion_types != [] 
    brownian_matrix_unfiltered = construct_brownian_motion_matrix(matrix, unformatted_matrix, object_decomposition, potential_brownian_motion_types)
    brownian_matrix = construct_filtered_matrices(brownian_matrix_unfiltered, object_decomposition, user_events)[1]
    push!(filtered_matrices, brownian_matrix)
  end

  unique!(filtered_matrices)
  filtered_matrices
end

function identify_agent_type(object_decomposition, user_events)
  object_types, object_mapping, _, grid_size = object_decomposition 

  left_times = findall(e -> e == "left", user_events)
  right_times = findall(e -> e == "right", user_events)
  up_times = findall(e -> e == "up", user_events)
  down_times = findall(e -> e == "down", user_events)



end

function identify_brownian_types(object_decomposition, user_events)
  
end

function construct_random_regularity_matrix(regularity_matrix, regularity_unformatted_matrix, object_decomposition, regularity_types)
  object_types, object_mapping, _, grid_size = object_decomposition
  new_matrix = deepcopy(regularity_matrix)
 
  for type in regularity_types
    type_id = type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
    choices = filter(rule -> !occursin("objX objX", rule) && !occursin("closest", rule) && !occursin("farthest", rule) && !occursin("addObj", rule) && !occursin("removeObj", rule), unique(vcat(vcat(map(id -> regularity_unformatted_matrix[id, :], object_ids_with_type)...)...)))
    formatted_choices = map(c -> replace(c, "(= objX " => "")[1:end - 1], choices)
    formatted_random_choice = """(uniformChoice (list $(join(map(c -> "$(replace(c, "objX" => "(prev obj)"))", formatted_choices), " "))))"""
  
    object_id = object_ids_with_type[1]
    start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
    contained_in_list = isnothing(object_mapping[object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[object_id][1].type.id, collect(keys(object_mapping))) > 1)
  
    for id in object_ids_with_type 
      for time in 1:length(matrix[id, :])
        if contained_in_list && !occursin("--> obj (prev obj)", new_matrix[id, time][1]) && new_matrix[id, time][1] != "" && !occursin("addObj", new_matrix[id, time][1]) && !occursin("removeObj", new_matrix[id, time][1])  
          new_matrix[id, time] = ["(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj $(formatted_random_choice))) (--> obj (== (.. obj id) $(id))))"]
        elseif !contained_in_list && !occursin("", new_matrix[id, time][1]) && new_matrix[id, time][1] != "" && !occursin("addObj", new_matrix[id, time][1]) && !occursin("removeObj", new_matrix[id, time][1])  
          new_matrix[id, time] = ["(= obj$(object_ids_with_type[1]) $(formatted_random_choice))"]
        end
      end
    end
  end
  new_matrix
end

function construct_regularity_matrix(matrix, unformatted_matrix, object_decomposition, regularity_types, adjacency_barred) 
  object_types, object_mapping, _, grid_size = object_decomposition 

  new_matrix = deepcopy(matrix) 
  new_unformatted_matrix = deepcopy(unformatted_matrix)

  # identify wall positions
  wall_types = filter(t -> t.color == "darkgray", object_types)
  if wall_types == [] 
    wall_positions = []
  else
    wall_type = wall_types[1]
    wall_ids = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == wall_type.id, collect(keys(object_mapping)))
    wall_positions = vcat(map(id -> map(p -> (object_mapping[id][1].position[1] + p[1], object_mapping[id][1].position[2] + p[2]), wall_type.shape), wall_ids)...)  
  end  
  changed = false
  for type in regularity_types 
    type_id = type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
  
    continuous_segments_dict = Dict()
    for id in object_ids_with_type
      @show id 
      object_values = object_mapping[id]
      boundary_positions = findall(t -> isnothing(object_values[t]) || is_on_boundary(object_values[t], grid_size) || (adjacency_barred ? adjacent_to_other_objects(object_values[t], t, object_types, object_mapping) : false), 1:length(object_values))
      @show boundary_positions
      continuous_segments_dict[id] = getindex.(Ref(object_values), UnitRange.([1; boundary_positions .+ 1], [boundary_positions .- 1; length(object_values)]))
      continuous_segments_dict[id] = filter(arr -> length(arr) > 0, continuous_segments_dict[id])
    end
    sorted_segments = reverse(sort(vcat(map(id -> continuous_segments_dict[id], object_ids_with_type)...), by=arr -> length(arr)))
    @show sorted_segments 
    if sorted_segments != []
      longest_segment = sorted_segments[1]
      displacements = [displacement(longest_segment[i].position, longest_segment[i + 1].position) for i in 1:(length(longest_segment) - 1)]
      nonzero_displacement_locations = findall(d -> d != (0, 0), displacements)
      zero_displacement_segments = getindex.(Ref(displacements), UnitRange.([1; nonzero_displacement_locations .+ 1], [nonzero_displacement_locations .- 1; length(displacements)]))
      interval_sizes = unique(map(s -> length(s), zero_displacement_segments[2:end-1]))
      exact_intervals = (length(interval_sizes) == 1) && interval_sizes[1] != 0 
      inexact_intervals = false
      if !exact_intervals && length(interval_sizes) > 1
        interval_size = minimum(interval_sizes)
        other_interval_sizes = filter(i -> i != interval_size, interval_sizes)
        if filter(x -> x != 0, unique(map(i -> (i + 1) % (interval_size + 1), other_interval_sizes))) == []
          inexact_intervals = true
        end
      end

      if exact_intervals || inexact_intervals 
        # regularity observed!
        changed = true
        interval_size = minimum(interval_sizes) + 1
        @show interval_size
        
        all_nonzero_disp_times_across_ids = []
        for id in object_ids_with_type 
          first_nonzero_disp_times = filter(t -> !isnothing(object_mapping[id][t]) && !isnothing(object_mapping[id][t + 1]) && displacement(object_mapping[id][t].position, object_mapping[id][t + 1].position) != (0, 0),  collect(1:(length(object_mapping[id]) - 1)))
          if first_nonzero_disp_times != [] 
            nonzero_disp_time = first_nonzero_disp_times[1]
            all_nonzero_disp_times = filter(t -> t != 0, collect((nonzero_disp_time % interval_size):interval_size:(length(object_mapping[id]) - 1)))
            push!(all_nonzero_disp_times_across_ids, all_nonzero_disp_times...)
          end
        end
        unique!(all_nonzero_disp_times_across_ids)
        @show all_nonzero_disp_times_across_ids
        for id in object_ids_with_type 
          @show id 
          nonzero_disp_time = filter(t -> !isnothing(object_mapping[id][t]) && !isnothing(object_mapping[id][t + 1]) && displacement(object_mapping[id][t].position, object_mapping[id][t + 1].position) != (0, 0),  collect(1:(length(object_mapping[id]) - 1)))
          if nonzero_disp_time == [] 
            nonzero_disp_time = all_nonzero_disp_times_across_ids[1]
          else
            nonzero_disp_time = nonzero_disp_time[1]
          end
          all_nonzero_disp_times = filter(t -> t != 0, collect((nonzero_disp_time % interval_size):interval_size:(length(object_mapping[id]) - 1)))
          @show all_nonzero_disp_times
          for time in 1:(length(object_mapping[id]) - 1)
            if (new_matrix[id, time] != [""])
              if !(time in all_nonzero_disp_times)
                new_matrix[id, time] = filter(r -> !occursin("NoCollision", r) && !occursin("closest", r) && !occursin("farthest", r), new_matrix[id, time]) # keep only the no-change rule 
                new_unformatted_matrix[id, time] = filter(r -> !occursin("NoCollision", r) && !occursin("closest", r) && !occursin("farthest", r), new_unformatted_matrix[id, time]) # keep only the no-change rule  
              elseif length(new_matrix[id, time]) > 1
                new_matrix[id, time] = filter(r -> !occursin("--> obj (prev obj)", r) && !occursin("= obj$(id) (prev obj$(id))", r), new_matrix[id, time]) # keep only the no-change rule 
                new_unformatted_matrix[id, time] = filter(r -> !occursin("--> obj (prev obj)", r) && !occursin("= obj$(id) (prev obj$(id))", r), new_unformatted_matrix[id, time]) # keep only the no-change rule  
              end
            end
          end
        end
      end
    end
  end
  if changed 
    new_matrix, new_unformatted_matrix
  else 
    nothing, nothing
  end
end

function compute_regularity_interval_sizes(original_filtered_matrix, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition 
  interval_sizes = []

  filtered_matrix = deepcopy(original_filtered_matrix)
  for i in 1:size(filtered_matrix)[1]
    for j in 1:size(filtered_matrix)[2]
      filtered_matrix[i,j] = [replace(original_filtered_matrix[i, j][1], "id) $(i)" => "id) x")]
    end
  end

  # standard regularity intervals 
  for object_type in object_types 
    type_id = object_type.id
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
    all_update_functions = filter(r -> r != "", unique(vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids_with_type)...)))
    if length(all_update_functions) > 1 
      # @show type_id 
      # @show object_ids_with_type
      non_prev_times = sort(unique(vcat(map(id -> findall(rule -> rule != [""] && !occursin("addObj",rule[1]) && !occursin("removeObj",rule[1]) && !occursin("= obj$(object_ids_with_type[1]) (prev obj$(object_ids_with_type[1]))", rule[1]) && !occursin("--> obj (prev obj)", rule[1]), filtered_matrix[id, :]), object_ids_with_type)...)))
      # @show non_prev_times 
      intervals = unique([non_prev_times[i + 1] - non_prev_times[i] for i in 2:(length(non_prev_times) - 2)])
      if length(intervals) == 1 && intervals[1] != 1
        push!(interval_sizes, ((non_prev_times[1] - 1) % intervals[1], intervals[1]))
      end

      # addObj-regularity intervals 
      addObj_times = sort(unique(vcat(map(id -> findall(rule -> occursin("addObj", rule[1]), filtered_matrix[id, :]), object_ids_with_type)...)))
      if length(addObj_times) > 2 
        intervals = unique([addObj_times[i + 1] - addObj_times[i] for i in 1:(length(addObj_times) - 1)])
        if length(intervals) == 1 
          push!(interval_sizes, (addObj_times[1] - 1, intervals[1]))
        else 
          distinct_sizes = unique(intervals)
          unit_size = gcd(distinct_sizes)
          if unit_size != 1 && unit_size in distinct_sizes
            # imperfect addObj-regularity intervals
            push!(interval_sizes, (unit_size - 1, unit_size)) 
          end
        end
      end 

    end
  end

  # unique!(filter(x -> x != (0, 5), interval_sizes)) # TEMP HACK FOR ALIENS
  interval_sizes 
end

function compute_source_objects_old(object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition
  start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))

  source_objects_dict = Dict()

  for object_type in object_types 
    type_id = object_type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
    addObj_times = vcat(map(id -> findall(t -> isnothing(object_mapping[id][t - 1]) && !isnothing(object_mapping[id][t]), 2:length(object_mapping[id])), object_ids_with_type)...)
    addObj_times = map(t -> t + 1, addObj_times) # first non-nothing time for object_id's
    addObj_positions = unique(vcat(map(id -> map(mt -> object_mapping[id][mt + 1].position, findall(t -> isnothing(object_mapping[id][t - 1]) && !isnothing(object_mapping[id][t]), 2:length(object_mapping[id]))), object_ids_with_type)...))
    removeObj_ids = filter(id -> findall(t -> (t - 1) > 0 && 
                                               !isnothing(object_mapping[id][t - 1]) && 
                                               isnothing(object_mapping[id][t]) && 
                                               object_mapping[id][t - 1].position in addObj_positions, 
                                          addObj_times) != [], collect(keys(object_mapping)))

    if removeObj_ids != [] 
      source_object_id = removeObj_ids[1]
      source_type_id = filter(obj -> !isnothing(obj), object_mapping[source_object_id])[1].type.id
      contained_in_list = isnothing(object_mapping[source_object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[source_object_id][1].type.id, collect(keys(object_mapping))) > 1)

      @show type_id 
      @show source_object_id 
      @show source_type_id
      @show addObj_positions 
      @show contained_in_list

      removeObj_to_addObj_dict = Dict()

      for r_id in removeObj_ids
        r_position = filter(obj -> !isnothing(obj), object_mapping[r_id])[end].position
        a_ids = findall(source_id -> filter(obj -> !isnothing(obj), object_mapping[source_id])[1].position == r_position, object_ids_with_type)

      end


      if contained_in_list 
        if length(removeObj_ids) > 1 
          source_objects_dict[type_id] = (source_type_id, "(!= (prev addedObjType$(source_type_id)List) (list))")
        else
          source_objects_dict[type_id] = (source_type_id, "(!= (map (--> obj (== (.. obj id) $(source_object_id))) (prev addedObjType$(source_type_id)List)) (list))")
        end
      else
        source_objects_dict[type_id] = (source_type_id, "(.. (prev obj$(source_object_id)) alive)")
      end
    end
  end
  source_objects_dict
end

function compute_double_removeObj_objects(all_update_functions, observation_vectors_dict, filtered_matrix)
  removeObj_update_functions = filter(u -> occursin("removeObj", u), all_update_functions)
  times_to_update_functions_dict = Dict()
  for update_function in removeObj_update_functions
    observation_values = observation_vectors_dict[update_function] 
    if observation_values isa AbstractArray 
      occurrence_times = findall(x -> x == 1, observation_values)
    else
      occurrence_times = unique(vcat(map(id -> findall(x -> x == 1, observation_values[id]), collect(keys(observation_values)))...))
    end

    if (length(occurrence_times) == 1) && occurrence_times[1] == size(filtered_matrix)[2]
      time = occurrence_times[1]
      if time in keys(times_to_update_functions_dict)
        push!(times_to_update_functions_dict[time], update_function)
      else
        times_to_update_functions_dict[time] = [update_function]
      end
    end
  end

  pairs = map(k -> times_to_update_functions_dict[k], filter(t -> length(times_to_update_functions_dict[t]) == 2, collect(keys(times_to_update_functions_dict))))
  filter(p -> object_type_is_brownian(p[1], filtered_matrix, object_decomposition) || object_type_is_brownian(p[2], filtered_matrix, object_decomposition), pairs)
end

function compute_source_objects(filtered_matrix, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition
  start_objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))

  addObj_removeObj_data_dict = Dict() 
  # structure of addObj_removeObj_data_dict: 
  # keys are pairs of the form (addObj_type_id, removeObj_type_id) for corresponding bullet-source types
  # values: tuples of the form (source_exists_event, state-based bool, formatted addObj rule, formatted removeObj rule) 
  for object_type in object_types 
    type_id = object_type.id 
    object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
    addObj_times = vcat(map(id -> findall(t -> isnothing(object_mapping[id][t - 1]) && !isnothing(object_mapping[id][t]), 2:length(object_mapping[id])), object_ids_with_type)...)
    addObj_times = map(t -> t + 1, addObj_times) # first non-nothing time for object_id's
    addObj_positions = unique(vcat(map(id -> map(mt -> object_mapping[id][mt + 1].position, findall(t -> isnothing(object_mapping[id][t - 1]) && !isnothing(object_mapping[id][t]), 2:length(object_mapping[id]))), object_ids_with_type)...))
    removeObj_ids = filter(id -> findall(t -> (t - 1) > 0 && 
                                               !isnothing(object_mapping[id][t - 1]) && 
                                               isnothing(object_mapping[id][t]) && 
                                               object_mapping[id][t - 1].position in addObj_positions, 
                                          addObj_times) != [], collect(keys(object_mapping)))

    removeObj_ids_prox = filter(id -> findall(t -> (t - 1) > 0 && 
                                                   !isnothing(object_mapping[id][t - 1]) && 
                                                   isnothing(object_mapping[id][t]) && 
                                                   !(object_mapping[id][t - 1].position in addObj_positions) && 
                                                   filter(scalar -> scalar <= 120, map(disp -> abs(disp[1]) + abs(disp[2]), map(p -> [displacement(p, object_mapping[id][t - 1].position)...], addObj_positions))) != [], 
                                addObj_times) != [], collect(keys(object_mapping)))    


    if removeObj_ids != [] 
      source_object_id = removeObj_ids[1]
      source_type_id = filter(obj -> !isnothing(obj), object_mapping[source_object_id])[1].type.id
      contained_in_list = isnothing(object_mapping[source_object_id][1]) || (count(id -> (filter(x -> !isnothing(x), object_mapping[id]))[1].type.id == object_mapping[source_object_id][1].type.id, collect(keys(object_mapping))) > 1)

      @show type_id 
      @show source_object_id 
      @show source_type_id
      @show addObj_positions 
      @show contained_in_list

      removeObj_to_addObj_dict = Dict()

      # compute state_based value 
      state_based = false
      for r_id in removeObj_ids
        r_position = filter(obj -> !isnothing(obj), object_mapping[r_id])[end].position
        # below: id's of all added objects that were added to r_position
        a_ids = findall(source_id -> filter(obj -> !isnothing(obj), object_mapping[source_id])[1].position == r_position, object_ids_with_type)
        if length(a_ids) > 1
          state_based = true
          break
        end
      end

      # compute source_exists_event
      if contained_in_list # if the source is in a list
        if filter(t -> t.id == source_type_id, object_types)[1].color == "darkgray"
          source_exists_event = "(!= (filter (--> obj (== (.. obj id) $(removeObj_ids[1]))) (prev addedObjType$(source_type_id)List)) (list))"
        else
          if length(removeObj_ids) > 1 
            source_exists_event = "(!= (prev addedObjType$(source_type_id)List) (list))"
          else
            source_exists_event = "(!= (map (--> obj (== (.. obj id) $(source_object_id))) (prev addedObjType$(source_type_id)List)) (list))"
          end
        end
      else
        source_exists_event = "(.. (prev obj$(source_object_id)) alive)"
      end
      addObj_removeObj_data_dict[(type_id, source_type_id)] = (source_exists_event, state_based)
    end
    
    if removeObj_ids_prox != []
      source_object_id = removeObj_ids_prox[1]
      source_type_id = filter(obj -> !isnothing(obj), object_mapping[source_object_id])[1].type.id

      source_exists_event = "true" 
      if object_type_is_brownian(type_id, filtered_matrix, object_decomposition) || object_type_is_brownian(source_type_id, filtered_matrix, object_decomposition)
        addObj_removeObj_data_dict[(type_id, source_type_id)] = (source_exists_event, false)
      end

    end
  
  end
  addObj_removeObj_data_dict
end

function object_type_is_brownian(type_id, filtered_matrix, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition

  object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
  occursin("(uniformChoice (list", join(vcat(map(id -> vcat(filtered_matrix[id, :]...), object_ids_with_type)...), ""))
end

function is_on_boundary(object, grid_size)  
  position = object.position
  shape = object.type.shape

  max_shape_x = sort(shape, by=pos -> pos[1])[end][1]
  min_shape_x = sort(shape, by=pos -> pos[1])[1][1]

  max_shape_y = sort(shape, by=pos -> pos[2])[end][2]
  min_shape_y = sort(shape, by=pos -> pos[2])[1][2]

  if !(grid_size isa AbstractArray)
    dimensions = [grid_size, grid_size]
  else
    dimensions = grid_size
  end

  (position[1] + max_shape_x >= dimensions[1] - 1) || (position[1] + min_shape_x <= 0) || (position[2] + max_shape_y >= dimensions[2] - 1) || (position[2] + min_shape_y <= 0) 
end

function adjacent_to_other_objects(object, time, object_types, object_mapping)
  origin = object.position
  shape = object.type.shape

  # compute smallest and largest x- and y-positions in shape
  max_shape_x = sort(shape, by=pos -> pos[1])[end][1]
  min_shape_x = sort(shape, by=pos -> pos[1])[1][1]

  max_shape_y = sort(shape, by=pos -> pos[2])[end][2]
  min_shape_y = sort(shape, by=pos -> pos[2])[1][2]

  # compute positions just outside boundary of shape (not including corners)
  adjacent_positions_to_shape = [map(p -> (p[1], p[2] + 1), filter(pos -> pos[2] == max_shape_y, shape))...,
                                  map(p -> (p[1], p[2] - 1), filter(pos -> pos[2] == min_shape_y, shape))...]

  if filter(t -> length(t.shape) > 100, object_types) == []
    push!(adjacent_positions_to_shape, [map(p -> (p[1] + 1, p[2]), filter(pos -> pos[1] == max_shape_x, shape))..., 
                                        map(p -> (p[1] - 1, p[2]), filter(pos -> pos[1] == min_shape_x, shape))...]...)
  end

  # translate shape adjacent positions by object origin
  adjacent_positions_to_object = map(pos -> (origin[1] + pos[1], origin[2] + pos[2]), adjacent_positions_to_shape)
  object_positions = map(p -> (p[1] + origin[1], p[2] + origin[2]), shape)
  all_object_positions = unique([adjacent_positions_to_object..., object_positions...])

  other_object_positions = vcat(map(object_id -> 
                                isnothing(object_mapping[object_id][time]) ? 
                                [] : 
                                map(p -> (p[1] + object_mapping[object_id][time].position[1], p[2] + object_mapping[object_id][time].position[2]), object_mapping[object_id][time].type.shape), 
                              filter(id -> id != object.id, collect(keys(object_mapping))))...)

  # if object-adjacent positions and wall positions intersect, then object is adjacent to wall
  ret_val = intersect(all_object_positions, other_object_positions) != []
  if ret_val
    println("WOAH THERE")
    ret_val
  else
    ret_val
  end
end

function displacement(position1, position2)
  (position2[1] - position1[1], position2[2] - position1[2])
end

function construct_filtered_matrices(matrix, object_decomposition, user_events, random=false, base=2)
  filtered_matrices = []

  if !random 

    # add non-random filtered matrices to filtered_matrices
    non_random_matrix = deepcopy(matrix)
    filtered_non_random_matrices = filter_update_function_matrix_multiple(non_random_matrix, object_decomposition, multiple=true, base=base)
    # filtered_non_random_matrices = filtered_non_random_matrices[1:min(4, length(filtered_non_random_matrices))]
    push!(filtered_matrices, filtered_non_random_matrices...)

    # NEW: removing nextLiquid/closest options!
    # add non-random filtered matrices to filtered_matrices
    non_random_matrix = deepcopy(matrix)
    for row in 1:size(non_random_matrix)[1]
      for col in 1:size(non_random_matrix)[2]
        non_random_matrix[row, col] = filter(x -> !occursin("closest", x) && !occursin("farthest", x), non_random_matrix[row, col])
      end
    end
    filtered_non_random_matrices = filter_update_function_matrix_multiple(non_random_matrix, object_decomposition, multiple=true)
    # filtered_non_random_matrices = filtered_non_random_matrices[1:min(4, length(filtered_non_random_matrices))]
    push!(filtered_matrices, filtered_non_random_matrices...)


    # add direction-bias-filtered matrix to filtered_matrices 
    pre_filtered_matrices = pre_filter_with_direction_biases(deepcopy(non_random_matrix), user_events, object_decomposition)
    for m in pre_filtered_matrices
      push!(filtered_matrices, filter_update_function_matrix_multiple(m, object_decomposition, multiple=false)...)
    end

    unique!(filtered_matrices)
    filtered_matrices = sort_update_function_matrices(filtered_matrices, object_decomposition)
    
    # @show length(filtered_matrices)

    if length(filtered_matrices) > 5 
      filtered_matrices = filtered_matrices[1:5]
    end
    
  else

    # BEGIN RANDOM 
    # add random filtered matrices to filtered_matrices 
    random_matrix = deepcopy(matrix)
    is_random = false
    for row in 1:size(random_matrix)[1]
      for col in 1:size(random_matrix)[2]
        if filter(x -> (occursin("uniformChoice", x) && !occursin("uniformChoice (map", x)) || occursin("randomPositions", x), random_matrix[row, col]) != []
          random_matrix[row, col] = filter(x -> occursin("uniformChoice", x) || occursin("randomPositions", x), random_matrix[row, col])
          is_random = true
        end
      end
    end

    if is_random 
      filtered_random_matrices = filter_update_function_matrix_multiple(random_matrix, object_decomposition, multiple=true, base=base)
      filtered_random_matrices = filtered_random_matrices[1:min(4, length(filtered_random_matrices))]
      push!(filtered_matrices, filtered_random_matrices...)
  
      # add "chaos" solution to filtered_matrices 
      filtered_unformatted_matrix = filter_update_function_matrix_multiple(unformatted_matrix, object_decomposition, multiple=false, base=base)[1]
      push!(filtered_matrices, filter_update_function_matrix_multiple(construct_chaos_matrix(filtered_unformatted_matrix, object_decomposition), object_decomposition, multiple=false, base=base)...)
    end

  end

  unique!(filtered_matrices)

  # filtered_matrices 
  sort_update_function_matrices(filtered_matrices, object_decomposition) 
end


function sort_update_function_matrices(matrices, object_decomposition)
  object_types, object_mapping, _, _ = object_decomposition
  counts = [] 
  for matrix in matrices 
    type_level_counts = []
    for type in object_types 
      ids_with_type = filter(id -> filter(o -> !isnothing(o), object_mapping[id])[1].type.id == type.id, collect(keys(object_mapping)))
      
      custom_field_names = map(x -> x[1], type.custom_fields)
      if "color" in custom_field_names 
        colors = filter(x -> x[1] == "color", type.custom_fields)[1][3]
        color_functions_dict = Dict(map(c -> c => [], colors))
        
        for id in ids_with_type 
          for time in 1:length(matrix[1, :])
            if !isnothing(object_mapping[id][time])
              color = object_mapping[id][time].custom_field_values[end]
              update_function = matrix[id, time][1]
              push!(color_functions_dict[color], replace(update_function, "(.. obj id) $(id)" => "(.. obj id) x"))
            end
          end
        end
        count = sum(map(c -> length(unique(color_functions_dict[c])), colors))
        push!(type_level_counts, count)
      else 
        distinct_update_functions = unique(vcat(vcat(map(id -> map(x -> [replace(x[1], "(.. obj id) $(id)" => "(.. obj id) x")], matrix[id, :]), ids_with_type)...)...))
        push!(type_level_counts, length(distinct_update_functions))
      end
    end
    push!(counts, sum(type_level_counts))
  end
  # @show length(matrices)
  # @show length(counts)

  # @show matrices 
  @show counts
  count_dict = Dict()
  for i in 1:length(counts)
    matrix = matrices[i]
    count = counts[i]
    if count in keys(count_dict)
      push!(count_dict[count], matrix)
    else
      count_dict[count] = [matrix]
    end
  end

  vcat(map(count -> sort(count_dict[count], by=m -> length(join(vcat(vcat(m...)...))) ), sort(collect(keys(count_dict))))...)
end

# generate_event, generate_hypothesis_position, generate_hypothesis_position_program 
## tricky things: add user events, and fix environment 
global hypothesis_state = nothing
function generate_event(run_id, interval_offsets, source_exists_events_dict, anonymized_update_rule, distinct_update_rules, object_id, object_ids, matrix, filtered_matrix, object_decomposition, user_events, state_update_on_clauses, global_var_dict, event_vector_dict, grid_size, redundant_events_set, min_events=1, max_iters=400, z3_option = "none", time_based=true, z3_timeout=0, sketch_timeout=0)
  # # # println("GENERATE EVENT")
  # # # # # # @show object_decomposition
  object_types, object_mapping, background, dim = object_decomposition 
  # @show object_mapping 
  objects = sort(filter(obj -> obj != nothing, [object_mapping[i][1] for i in 1:length(collect(keys(object_mapping)))]), by=(x -> x.id))
  type_id = filter(x -> !isnothing(x), object_mapping[object_ids[1]])[1].type.id
  ## # println("WHAT 1")
  ## # # # # @show length(vcat(object_trajectory...))

  # construct observed update function times (observation_data)
  observation_data_dict = Dict()

  # construct sorted distinct_update_rules   
  all_update_rules = vcat(filter(r -> r != "", vcat(map(id -> map(x -> replace(x[1], "obj id) $(id)" => "obj id) x"), filtered_matrix[id, :]), object_ids)...))...)
  distinct_update_rules = unique(all_update_rules)
  no_change_rules = filter(x -> is_no_change_rule(x), distinct_update_rules)
  distinct_update_rules = reverse(sort(filter(x -> !is_no_change_rule(x), distinct_update_rules), by=x -> count(y -> y == x, all_update_rules)))
  distinct_update_rules = [no_change_rules..., distinct_update_rules...]

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
    # # # # # @show true_times 
    # # # # # @show user_events
    true_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], true_times)
    false_time_events = map(time -> isnothing(user_events[time]) ? user_events[time] : split(user_events[time], " ")[1], findall(rule -> rule != update_rule, vcat(object_trajectory...)))
  
    observation_data = map(time -> time in true_times ? 1 : 0, collect(1:length(user_events)))
    update_rule_index = findall(rule -> replace(rule, "obj id) x" => "obj id) $(object_id)") == update_rule, distinct_update_rules) == [] ? -1 : findall(rule -> replace(rule, "obj id) x" => "obj id) $(object_id)") == update_rule, distinct_update_rules)[1]
    ## # println("WHAT 3")
  
    if !occursin("addObj", update_rule)
      for time in 1:length(object_trajectory)
        rule = object_trajectory[time][1]
        # # # @show rule
        # # # @show distinct_update_rules
        if (rule == "") || (findall(r -> replace(r, "obj id) x" => "obj id) $(object_id)") == rule, distinct_update_rules)[1] > update_rule_index) # || occursin("addObj", rule) #
          observation_data[time] = -1
        elseif (findall(r -> replace(r, "obj id) x" => "obj id) $(object_id)") == rule, distinct_update_rules)[1] < update_rule_index)
          observation_data[time] = 0
        end
  
        if occursin("\"color\" \"", update_rule)
          if !isnothing(object_mapping[object_id][time + 1]) && occursin(object_mapping[object_id][time + 1].custom_field_values[1], update_rule) && observation_data[time] != 1 && (time == length(object_trajectory) || is_no_change_rule(object_trajectory[time + 1][1])) # is_no_change_rule(rule)
            observation_data[time] = -1
          end
        end
      end
    end
    observation_data_dict[object_id] = observation_data
  end

  # # # println("----------------> LOOK AT ME")
  # # # # # # @show object_decomposition
  # # # @show observation_data_dict 
  # # # @show distinct_update_rules 

  tried_compound_events = false 

  found_events = []
  final_event_globals = []
  choices = gen_event_bool(object_decomposition, "x", type_id, anonymized_update_rule, filter(e -> e != "", unique(user_events)), global_var_dict, type_displacements, interval_offsets, source_exists_events_dict, time_based)
  # # println("WHAT ABOUT HERE")
  # @show choices
  # @show redundant_events_set 
  new_choices = filter(e -> !(e in redundant_events_set), choices)
  # # println("STRANGE BEHAVIOR")
  # # # @show time_based 
  # @show new_choices
  # @show length(new_choices)
  # # # @show length(collect(keys(event_vector_dict)))
  # # # @show length(collect(redundant_events_set))
  # # # @show redundant_events_set
  events_to_try = sort(unique(vcat(new_choices, collect(keys(event_vector_dict)))), by=length)
  # @show length(events_to_try)
  while true
    for event in events_to_try 
      event_is_global = !occursin(".. obj id) x", event)
      anonymized_event = event # replace(event, ".. obj id) $(object_ids[1])" => ".. obj id) x")
      @show event 
      # @show anonymized_event
      # # # @show type_id
      is_event_object_specific_with_correct_type = event_is_global || parse(Int, split(match(r".. obj id x prev addedObjType\dList", replace(replace(anonymized_event, ")" => ""), "(" => "")).match, "addedObjType")[2][1]) == type_id
      # # # @show is_event_object_specific_with_correct_type
      # # # @show object_ids
      # !(occursin("first", anonymized_event) && (nothing in vcat(map(k -> object_mapping[k], collect(keys(object_mapping)))...))) && is_event_object_specific_with_correct_type
      if is_event_object_specific_with_correct_type
        
        if !(anonymized_event in keys(event_vector_dict)) # || !(event_vector_dict[anonymized_event] isa AbstractArray) && intersect(object_ids, collect(keys(event_vector_dict[anonymized_event]))) == [] # event values are not stored
          @show anonymized_event 
          if event_is_global # if the event is global, only need to evaluate the event on one object_id 
            event_object_ids = object_ids[1]
          else # otherwise, need to evaluate the event on all object_ids
            event_object_ids = object_ids # collect(keys(object_mapping)) # object_ids; evaluate even for ids not with the current rule's type, for uniformity!!
            event_vector_dict[anonymized_event] = Dict()
          end
          
          # # # @show event_object_ids
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
                      
            # println(program_str)
            global expr = parseautumn(program_str)
            # global expr = striplines(compiletojulia(parseautumn(program_str)))
            # ## # # # # @show expr
            # module_name = Symbol("CompiledProgram$(global_iters)")
            # global expr.args[1].args[2] = module_name
            # # # # # # # @show expr.args[1].args[2]
            # global mod = @eval $(expr)
            # # # # # # # @show repr(mod)
      
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
            # try 
            #   hypothesis_state = interpret_over_time(expr, length(user_events), user_events_for_interpreter).state
            # catch e 
            #   hypothesis_state = nothing
            # end
            # hypothesis_state = interpret_over_time(expr, length(user_events), user_events_for_interpreter).state
      
            # global hypothesis_state = @eval mod.init(nothing, nothing, nothing, nothing, nothing)
            # # # # # # @show hypothesis_state
            # for time in 1:length(user_events)
            #   # # # # # @show time
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
            if !isnothing(hypothesis_state)
              event_values = map(key -> hypothesis_state.eventHistory[key], sort(collect(keys(hypothesis_state.eventHistory))))[2:end]
    
              # update event_vector_dict 
              if event_is_global 
                event_vector_dict[anonymized_event] = event_values
              else
                event_vector_dict[anonymized_event][object_id] = event_values
              end
            end
          end
        end
      end
      if (anonymized_event in keys(event_vector_dict)) && is_event_object_specific_with_correct_type
        # if this is not true, then there was a failure above (the event contained "first" but had nothing's in object_mapping),
        # or the event is object-specific with the wrong type 
        event_values_dicts = []
        if event_vector_dict[anonymized_event] isa AbstractArray 
          event_values_dict = Dict()
          for object_id in object_ids 
            event_values_dict[object_id] = event_vector_dict[anonymized_event]
          end
          push!(event_values_dicts, (event, event_values_dict))
        else
          # add object-specific event values
          # # # @show collect(keys(event_vector_dict[anonymized_event]))
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
        # # # println("INSIDE GENERATE_EVENT")
        # # # # @show anonymized_event
        # # # # @show observation_data_dict
        # # # # @show event_values_dicts
        # # # # @show event_vector_dict
        
        equals = true
        for tuple in event_values_dicts 
          e, event_values_dict = tuple
          for object_id in object_ids 
            observation_data = observation_data_dict[object_id]
            event_values = event_values_dict[object_id]  
            for time in 1:length(observation_data)
              if (observation_data[time] != event_values[time]) && (observation_data[time] != -1)
                equals = false
                # # # println("NO SUCCESS")
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
          # # # println("SUCCESS")
          if occursin("obj id) x", event)
            push!(final_event_globals, false)
          else
            push!(final_event_globals, true)
          end
          break
        end
      end
  
    end

    # remove duplicate events that are observationally equivalent
    # # println("PRE PRUNING")
    # @show length(collect(keys(event_vector_dict)))
    # @show event_vector_dict

    event_vector_dict, redundant_events_set = prune_by_observational_equivalence(event_vector_dict, redundant_events_set)

    # # # println("POST PRUNING")
    # # # @show length(collect(keys(event_vector_dict)))

    if z3_option in ["none"] # , "partial"
      if length(found_events) < min_events && !tried_compound_events
        # # # println("entered here")
        events_to_try = sort(unique(construct_compound_events(collect(keys(event_vector_dict)), event_vector_dict, redundant_events_set, object_decomposition)), by=length)
        # # # println("exited here")
        tried_compound_events = true
      else
        if (z3_option == "partial") && length(found_events) < min_events

          # ensure that event_vector_dict does not contain BitArray type
          for event in keys(event_vector_dict)
            event_values = event_vector_dict[event]
            if event_values isa AbstractArray 
              if event_values isa BitArray 
                event_vector_dict[event] = Array{Int}(event_values)
              end
            else
              for object_id in keys(event_values)
                if event_values[object_id] isa BitArray 
                  event_vector_dict[event][object_id] = Array{Int}(event_values[object_id])
                end
              end
            end
          end

          solution_event = z3_event_search_partial(observation_data_dict, event_vector_dict, z3_timeout)
          if solution_event != "" 
            push!(found_events, solution_event)
            if occursin("obj id) x", solution_event)
              push!(final_event_globals, false)
            else
              push!(final_event_globals, true)
            end
  
          end
        end

        break
      end
    elseif z3_option in ["full", "partial"]

      # ensure that event_vector_dict does not contain BitArray type
      for event in keys(event_vector_dict)
        event_values = event_vector_dict[event]
        if event_values isa AbstractArray 
          if event_values isa BitArray 
            event_vector_dict[event] = Array{Int}(event_values)
          end
        else
          for object_id in keys(event_values)
            if event_values[object_id] isa BitArray 
              event_vector_dict[event][object_id] = Array{Int}(event_values[object_id])
            end
          end
        end
      end

      # create event_vector_dict copy for Z3, which is missing compound events 
      z3_event_vector_dict = deepcopy(event_vector_dict)
      for event in collect(keys(z3_event_vector_dict))
        if !(event in new_choices)
          delete!(z3_event_vector_dict, event)
        end
      end

      # # # @show anonymized_update_rule
      # # # @show observation_data_dict
      if length(found_events) < min_events 
        partial_param = (z3_option == "partial")
        @show anonymized_update_rule 
        solution_event = z3_event_search_full(run_id, observation_data_dict, z3_event_vector_dict, redundant_events_set, partial_param, z3_timeout)
        if solution_event != "" 
          push!(found_events, solution_event)
          if occursin("obj id) x", solution_event)
            push!(final_event_globals, false)
          else
            push!(final_event_globals, true)
          end
        else
          # _ = construct_compound_events(new_choices, event_vector_dict, redundant_events_set, object_decomposition)
        end
      end
      break
    end
  end
  # # # # # @show found_events
  found_events, final_event_globals, event_vector_dict, observation_data_dict    
end

function z3_event_search_partial(observed_data_dict, event_vector_dict, timeout=0)
  # # # println("Z3_EVENT_SEARCH_PARTIAL")
  Pickle.store("./observed_data_dict.pkl", observed_data_dict)
  Pickle.store("./event_vector_dict.pkl", event_vector_dict)
  # # # @show observed_data_dict 
  # # # @show event_vector_dict

  # activate autumn environment containing z3
  # command = "conda activate autumn"
  # output = readchomp(eval(Meta.parse("`$(command)`")))
  event = ""
  # run python command for z3 event search 
  for option in [1, 2]
    if timeout == 0 
      command = "python3 z3_event_search.py $(option)"
    else
      if Sys.islinux() 
        command = "gtimeout $(timeout) python3 z3_event_search.py $(option)"
      else
        command = "timeout $(timeout) python3 z3_event_search.py $(option)"
      end
    end
    z3_output = try 
                  readchomp(eval(Meta.parse("`$(command)`")))
                catch e 
                  ""
                end

    # parse output 
    if z3_output != "" 
      lines = split(z3_output, "\n")
      if lines[1] == "sat"
        event_1 = lines[3]
        event_2 = lines[4]
        # check which of four possible event combinations matches observed_data_dict 
        if option == 1
          event = "(& $(event_1) $(event_2))"
        elseif option == 2 
          event = "(| $(event_1) $(event_2))"
        end
        break
      end
    end
  end
  event
end

function z3_event_search_full(run_id, observed_data_dict, event_vector_dict, redundant_events_set, partial=false, timeout=0)
  println("Z3_EVENT_SEARCH_FULL")
  @show length(collect(keys(event_vector_dict)))
  @show observed_data_dict 
  # @show event_vector_dict
  Pickle.store("./observed_data_dict_$(run_id).pkl", observed_data_dict)
  Pickle.store("./event_vector_dict_$(run_id).pkl", event_vector_dict)
  Pickle.store("./redundant_events_set_$(run_id).pkl", redundant_events_set)

  # activate autumn environment containing z3
  # command = "conda activate autumn"
  # output = readchomp(eval(Meta.parse("`$(command)`")))
  events = [""]
  # run python command for z3 event search 
  options = partial ? [1, 2] : collect(1:14)
  for option in options
    shortest_length = 0
    if timeout == 0 
      command = "python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
    else
      if Sys.islinux() 
        command = "gtimeout $(timeout) python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
      else
        command = "timeout $(timeout) python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
      end
    end
    z3_output = try 
                  readchomp(eval(Meta.parse("`$(command)`")))
                catch e 
                  ""
                end
  
    # parse output
    @show command  
    @show option
    @show z3_output

    while z3_output != "" && split(z3_output, "\n")[1] == "sat"
      # # # println("INSIDE MINIMIZATION WHILE LOOP")
      # # # @show events

      lines = split(z3_output, "\n")
      event = ""

      if option in [1, 2]
        event_1 = lines[3]
        event_2 = lines[4]
        if option == 1
          event = "(& $(event_1) $(event_2))"
        elseif option == 2 
          event = "(| $(event_1) $(event_2))"
        end
        shortest_length = length(event_1) + length(event_2)
      elseif option in [3, 4, 5, 11]
        event_1 = lines[3]
        event_2 = lines[4]
        event_3 = lines[5]
        if option == 3
          event = "(& (& $(event_1) $(event_2)) $(event_3))"
        elseif option == 4 
          event = "(| (& $(event_1) $(event_2)) $(event_3))"
        elseif option == 5 
          event = "(| (| $(event_1) $(event_2)) $(event_3))"
        elseif option == 11 
          event = "(& $(event_1) (| $(event_2) $(event_3)))"
        end
        shortest_length = length(event_1) + length(event_2) + length(event_3)
      elseif option in [6, 7, 8, 9, 10, 12, 13, 14]    
        event_1 = lines[3]
        event_2 = lines[4]
        event_3 = lines[5]
        event_4 = lines[6]
        if option == 6
          event = "(& (& $(event_1) $(event_2)) (& $(event_3) $(event_4)))"
        elseif option == 7 
          event = "(| (& (& $(event_1) $(event_2)) $(event_3)) $(event_4))"
        elseif option == 8 
          event = "(| (& $(event_1) $(event_2)) (| $(event_3) $(event_4)))"
        elseif option == 9 
          event = "(| (& $(event_1) $(event_2)) (& $(event_3) $(event_4)))" # "(& $(event_1) (| $(event_2) (& $(event_3) $(event_4))))" # 
        elseif option == 10 
          event = "(| (| $(event_1) $(event_2)) (| $(event_3) $(event_4)))"
        elseif option == 12 
          event = "(& $(event_1) (& $(event_2) (| $(event_3) $(event_4))))"
        elseif option == 14 
          event = "(& $(event_1) (| $(event_2) (| $(event_3) $(event_4))))"
        elseif option == 13 
          event = "(& $(event_1) (| $(event_2) (& $(event_3) $(event_4)) ))"
        end
        shortest_length = length(event_1) + length(event_2) + length(event_3) + length(event_4)
      end
      # # # @show event 
      # # # @show shortest_length 
      # # # @show option 

      push!(events, event)

      # if option in [1, 2]
      #   break
      # end

      # re-run Z3 search with shortest length, for all options > 2
      if timeout == 0 
        command = "python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
      else
        if Sys.islinux() 
          command = "gtimeout $(timeout) python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
        else
          command = "timeout $(timeout) python3 z3_event_search_full.py $(option) $(run_id) $(shortest_length)"
        end
      end
      z3_output = try 
                    readchomp(eval(Meta.parse("`$(command)`")))
                  catch e 
                    ""
                  end
    
    end

    if length(events) > 1 
      break
    end
  end
  println("HERES AN EVENT!")
  @show events[end]
  @show events 
  events[end]
end


# generation of new global state 
function generate_new_state(update_rule, update_function_times, event_vector_dict, object_trajectory, init_global_var_dict, state_update_times_dict, object_decomposition, type_id, desired_per_matrix_solution_count, interval_painting_param)
  # # println("GENERATE_NEW_STATE")
  # @show update_rule 
  # @show update_function_times
  # @show event_vector_dict 
  # @show object_trajectory    
  # @show init_global_var_dict 
  # @show state_update_times_dict 
  # # @show object_decomposition   
  init_state_update_times_dict = deepcopy(state_update_times_dict)
  failed = false
  solutions = []

  events = filter(e -> event_vector_dict[e] isa AbstractArray, collect(keys(event_vector_dict)))
  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id, ["nothing"], init_global_var_dict, update_rule, type_displacements)
  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if !(e in atomic_events) || !(event_vector_dict[e] isa AbstractArray)
      delete!(small_event_vector_dict, e)
    end
  end

  # compute best co-occurring event (i.e. event with fewest false positives)
  co_occurring_events = []
  for event in events
    event_vector = event_vector_dict[event]
    event_times = findall(x -> x == 1, event_vector)
    if repr(sort(intersect(event_times, update_function_times))) == repr(sort(update_function_times))
      push!(co_occurring_events, (event, length([time for time in event_times if !(time in update_function_times)])))
    end 
  end
  # # @show co_occurring_events
  # co_occurring_events = sort(filter(x -> !occursin("|", x[1]) && (!occursin("&", x[1]) || occursin("click", x[1])), co_occurring_events), by=x->x[2]) # [1][1]
  co_occurring_events = sort(filter(x -> !occursin("|", x[1]), co_occurring_events), by=x->x[2]) # [1][1]
  best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
  # # @show best_co_occurring_events
  co_occurring_event = best_co_occurring_events[1][1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]
  # # @show co_occurring_event 
  # # @show co_occurring_event_trajectory

  # initialize global_var_dict and get global_var_value
  if length(collect(keys(init_global_var_dict))) == 0 
    init_global_var_dict[1] = ones(Int, length(init_state_update_times_dict[1]))
    global_var_value = 1
    global_var_id = 1
  else # check if all update function times match with one value of init_global_var_dict 
    global_var_id = -1
    for key in collect(keys(init_global_var_dict))
      values = init_global_var_dict[key]
      if length(unique(map(t -> values[t], update_function_times))) == 1
        global_var_id = key
        break
      end
    end
  
    if global_var_id == -1 # update function times crosses state lines 
      # initialize new global var 
      max_key = maximum(collect(keys(init_global_var_dict)))
      init_global_var_dict[max_key + 1] = ones(Int, length(init_state_update_times_dict[1]))
      global_var_id = max_key + 1 

      init_state_update_times_dict[global_var_id] = ["" for i in 1:length(init_global_var_dict[max_key])]
    end
    global_var_value = maximum(init_global_var_dict[global_var_id])  
  end

  true_positive_times = update_function_times # times when co_occurring_event happened and update_rule happened 
  false_positive_times = [] # times when user_event happened and update_rule didn't happen

  # construct true_positive_times and false_positive_times 
  # # # @show length(user_events)
  # # # @show length(co_occurring_event_trajectory)
  for time in 1:length(co_occurring_event_trajectory)
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
  init_augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])

  for i in 1:(length(init_augmented_positive_times)-1)
    prev_time, prev_value = init_augmented_positive_times[i]
    next_time, next_value = init_augmented_positive_times[i + 1]
    if prev_value != next_value
      push!(ranges, (init_augmented_positive_times[i], init_augmented_positive_times[i + 1]))
    end
  end

  # add ranges that interface between global_var_value and lower values
  if global_var_value > 1
    for time in 1:(length(init_state_update_times_dict[global_var_id]) - 1)
      prev_val = init_global_var_dict[global_var_id][time]
      next_val = init_global_var_dict[global_var_id][time + 1]
      # # println("HELLO 1")
      # # @show prev_val 
      # # @show next_val 
      if (prev_val < global_var_value) && (next_val == global_var_value)
        if (filter(t -> t[1] == time + 1, init_augmented_positive_times) != []) && (filter(t -> t[1] == time + 1, init_augmented_positive_times)[1][2] != global_var_value)
          new_value = filter(t -> t[1] == time + 1, init_augmented_positive_times)[1][2]
          push!(ranges, ((time, prev_val), (time + 1, new_value)))        
        else
          push!(ranges, ((time, prev_val), (time + 1, next_val)))        
        end
        # # println("IT'S ME 1")
        # clear state update functions within this range; will find new ones later
        state_update_func = init_state_update_times_dict[global_var_id][time]
        if state_update_func != "" 
          for time in 1:length(init_state_update_times_dict[global_var_id])
            if init_state_update_times_dict[global_var_id][time] == state_update_func
              init_state_update_times_dict[global_var_id][time] = ""
            end
          end
        end

      elseif (prev_val == global_var_value) && (next_val < global_var_value)
        if (filter(t -> t[1] == time, init_augmented_positive_times) != []) && (filter(t -> t[1] == time, init_augmented_positive_times)[1][2] != global_var_value)
          new_value = filter(t -> t[1] == time, init_augmented_positive_times)[1][2]
          push!(ranges, ((time, new_value), (time + 1, next_val)))        
        else
          push!(ranges, ((time, prev_val), (time + 1, next_val)))        
        end
        # # println("IT'S ME 2")
        # clear state update functions within this range; will find new ones later
        state_update_func = init_state_update_times_dict[global_var_id][time]
        if state_update_func != "" 
          for time in 1:length(init_state_update_times_dict[global_var_id])
            if init_state_update_times_dict[global_var_id][time] == state_update_func
              init_state_update_times_dict[global_var_id][time] = ""
            end
          end
        end
      end
    end
  end
  # # println("WHY THO")
  # # @show init_state_update_times_dict 

  # filter ranges where both the range's start and end times are already included
  ranges = unique(ranges)
  new_ranges = []
  for range in ranges
    start_tuples = map(range -> range[1], filter(r -> r != range, ranges))
    end_tuples = map(range -> range[2], filter(r -> r != range, ranges))
    if !((range[1] in start_tuples) && (range[2] in end_tuples))
      push!(new_ranges, range)      
    end
  end

  init_grouped_ranges = group_ranges(new_ranges)
  # # @show init_grouped_ranges

  init_extra_global_var_values = []

  problem_contexts = [(deepcopy(init_grouped_ranges), deepcopy(init_augmented_positive_times), deepcopy(init_state_update_times_dict), deepcopy(init_global_var_dict), deepcopy(init_extra_global_var_values))]
  split_orders = []
  while (length(problem_contexts) > 0) && length(solutions) < desired_per_matrix_solution_count 
    grouped_ranges, augmented_positive_times, new_state_update_times_dict, global_var_dict, extra_global_var_values = problem_contexts[1]
    problem_contexts = problem_contexts[2:end]

    # curr_max_grouped_ranges = deepcopy(grouped_ranges)
    # curr_max_augmented_positive_times = deepcopy(augmented_positive_times)
    # curr_max_new_state_update_times_dict = deepcopy(new_state_update_times_dict)
    # curr_max_global_var_dict = deepcopy(global_var_dict)

    # while there are ranges that need to be explained, search for explaining events within them
    while length(grouped_ranges) > 0
      # if Set([grouped_ranges..., curr_max_grouped_ranges...]) != Set(curr_max_grouped_ranges)
      #   curr_max_grouped_ranges = deepcopy(grouped_ranges)
      #   curr_max_augmented_positive_times = deepcopy(augmented_positive_times)
      #   curr_max_new_state_update_times_dict = deepcopy(new_state_update_times_dict)
      #   curr_max_global_var_dict = deepcopy(global_var_dict)
      # end

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
      if events_in_range != [] # event with zero false positives found
        # # println("PLS WORK 2")
        # @show events_in_range
        # # # @show event_vector_dict
        # # @show events_in_range 
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
  
        # construct state update on-clause
        state_update_on_clause = "(on $(state_update_event)\n$(state_update_function))"
        
        # add to state_update_times 
        # # # @show event_times
        # # # @show state_update_on_clause  
        for time in event_times 
          new_state_update_times_dict[global_var_id][time] = state_update_on_clause
        end
  
      else # no event with zero false positives found; use best false-positive event and specialize globalVar values (i.e. add new value)
        # find co-occurring event with fewest false positives 
        
        false_positive_events = find_state_update_events_false_positives(small_event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_id, global_var_value)
        false_positive_events_with_state = filter(e -> occursin("globalVar$(global_var_id)", e[1]), false_positive_events) # want the most specific events in the false positive case
        # @show false_positive_events
        events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
        if events_without_true != []
            false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
        else
          # FAILURE CASE: only separating event with false positives is true-based 
          # false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1]
          failed = true 
          break  
        end

        # if the selected false positive event falls into a different transition range, create a new problem context with
        # the order of those ranges switched
        matching_grouped_ranges = filter(grouped_range -> intersect(vcat(map(r -> collect(r[1][1]:(r[2][1] - 1)), grouped_range)...), false_positive_times) != [], grouped_ranges) 

        # # @show length(matching_grouped_ranges)
        if length(matching_grouped_ranges) > 0 
          # # println("WOAHHH")
          if length(matching_grouped_ranges[1]) > 0 
            # # println("WOAHHH 2")
          end
        end
        
        if length(matching_grouped_ranges) == 1 && length(matching_grouped_ranges[1]) == 1 && desired_per_matrix_solution_count > 1
          matching_grouped_range = matching_grouped_ranges[1]
          matching_range = matching_grouped_range[1]
          matching_values = (matching_range[1][2], matching_range[2][2])
          current_values = (start_value, end_value)

          # # @show matching_grouped_range
          # # @show matching_range
          # # @show matching_values
          # # @show current_values

          # check that we haven't previously considered this reordering
          if !((current_values, matching_values) in split_orders) # && !((matching_values, current_values) in split_orders)
            push!(split_orders, (current_values, matching_values))

            # create new problem context
            new_context_grouped_ranges, new_context_augmented_positive_times, new_context_new_state_update_times_dict = recompute_ranges(deepcopy(augmented_positive_times), 
                                                                                                                                         deepcopy(new_state_update_times_dict),
                                                                                                                                         global_var_id, 
                                                                                                                                         global_var_value,
                                                                                                                                         deepcopy(global_var_dict),
                                                                                                                                         deepcopy(true_positive_times), 
                                                                                                                                         deepcopy(extra_global_var_values))
            # flip order of matching_range and grouped_range
            matching_idx = findall(r -> r[1][1][2] == matching_values[1] && r[1][2][2] == matching_values[2], new_context_grouped_ranges)[1]
            curr_idx = findall(r -> r[1][1][2] == current_values[1] && r[1][2][2] == current_values[2], new_context_grouped_ranges)[1]
            
            new_context_grouped_ranges[curr_idx] = deepcopy(matching_grouped_range) 
            new_context_grouped_ranges[matching_idx] = deepcopy(grouped_range)

            # new_context_augmented_positive_times = deepcopy(curr_max_augmented_positive_times)
            # new_context_new_state_update_times_dict = deepcopy(curr_max_new_state_update_times_dict) 
            # new_context_curr_max_global_var_dict = deepcopy(curr_max_global_var_dict)

            # if the false positive intersection with a different range has size greater than 1, try allowing the first false
            # positive event in that other range to take place, instead of specializing its value
            intersecting_times = intersect(collect(matching_range[1][1]:(matching_range[2][1] - 1)), false_positive_times)
            if length(intersecting_times) > 1
              # update new_context_augmented_positive_times 
              first_intersecting_time = intersecting_times[1]
              push!(new_context_augmented_positive_times, (first_intersecting_time + 1, end_value))
              sort!(new_context_augmented_positive_times, by=x -> x[1])
              # recompute ranges + state_update_times_dict
              new_context_grouped_ranges, new_context_augmented_positive_times, new_context_new_state_update_times_dict = recompute_ranges(new_context_augmented_positive_times, 
                                                                                                                                           deepcopy(init_state_update_times_dict),
                                                                                                                                           global_var_id, 
                                                                                                                                           global_var_value,
                                                                                                                                           deepcopy(global_var_dict),
                                                                                                                                           true_positive_times, 
                                                                                                                                           extra_global_var_values)
            end

            push!(problem_contexts, (new_context_grouped_ranges, new_context_augmented_positive_times, deepcopy(init_state_update_times_dict), deepcopy(global_var_dict), deepcopy(extra_global_var_values)))
          end
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
  
              # if we have reached a prev_tuple with global_var_value or extra value, then we stop the relabeling based on this event tuple
              if prev_tuple[2] == global_var_value || prev_tuple[2] in extra_global_var_values
                # # println("HERE 2")
                # @show prev_tuple 
                # @show tuple
                if prev_tuple[1] == tuple[1] && !(prev_tuple[2] in extra_global_var_values) # if the false positive time is the same as the global_var_value time, change the value
                  # # println("HERE")

                  augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                  push!(extra_global_var_values, max_global_var_value + 1)
                  break
                else # if the two times are different, stop the relabeling process w.r.t. to this false positive tuple 
                  break
                end
              end
              
              # relabel update function prev_tuple with label greater than global_var_value and not an extra value 
              if (prev_tuple[2] > global_var_value) && !(prev_tuple[2] in extra_global_var_values) && (prev_tuple[3] == "update_function")
                if interval_painting_param 
                  # # println("HERE 3")
                  # before relabeling, check if there is a transition event between this prev_tuple's and tuple's time
                  tuple_time = tuple[1]
                  prev_tuple_time = prev_tuple[1]
                  range_times = collect(prev_tuple_time:(tuple_time-1))
                  events_in_range = find_matching_global_event(range_times, small_event_vector_dict)

                  # @show tuple_time 
                  # @show prev_tuple_time 
                  # @show range_times
                  if events_in_range == [] 
                    augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                  else # exists such an in-between explaining event
                    # stop relabeling, as in-between explaining transition event has been found 
                    break
                  end
                else
                  augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                end
              end
            end
          end
        end
        augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))      
  
        # compute new ranges and find state update events
        grouped_ranges, augmented_positive_times, new_state_update_times_dict = recompute_ranges(augmented_positive_times, new_state_update_times_dict, global_var_id, global_var_value, global_var_dict, true_positive_times, extra_global_var_values)
      end
    end
  
    if failed 
      solution = ("", global_var_dict, new_state_update_times_dict)
      push!(solutions, solution)
    else
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
          # @show new_state_update_times_dict[global_var_id][time]
          curr_value = parse(Int, split(split(new_state_update_times_dict[global_var_id][time], "\n")[2], "(= globalVar$(global_var_id) ")[2][1])
        end
      end
      
      if extra_global_var_values == [] 
        on_clause = "(on $(occursin("globalVar$(global_var_id)", co_occurring_event) ? co_occurring_event : "(& (== (prev globalVar$(global_var_id)) $(global_var_value)) $(co_occurring_event))")\n$(update_rule))"
      else 
        on_clause = "(on (& (in (prev globalVar$(global_var_id)) (list $(join([global_var_value, extra_global_var_values...], " ")))) $(occursin("globalVar$(global_var_id)", co_occurring_event) ? replace(replace("(== globalVar$(global_var_id) $(global_var_value))" => ""), "(&" => "")[1:end-1] : co_occurring_event))\n$(update_rule))"
      end
      
      solution = (on_clause, global_var_dict, new_state_update_times_dict)
      push!(solutions, solution)
    end
  end
  sort(solutions, by=sol -> length(unique(sol[2][1])))
end

function find_matching_global_event(times, event_vector_dict) 
  events = filter(e -> e != "true" && event_vector_dict[e] isa AbstractArray, collect(keys(event_vector_dict)))
  matching_events = [] 
  for event in events 
    if intersect(findall(v -> v == 1, event_vector_dict[event]), times) != []
      # @show event
      push!(matching_events, event)
    end
  end
  matching_events 
end

function generate_new_object_specific_state(update_rule, update_function_times_dict, event_vector_dict, type_id, object_decomposition, init_state_update_times, global_var_dict)
  # # println("GENERATE_NEW_OBJECT_SPECIFIC_STATE")
  # @show update_rule
  # @show update_function_times_dict
  # @show event_vector_dict
  # @show type_id 
  # # @show object_decomposition
  # @show init_state_update_times
  state_update_times = deepcopy(init_state_update_times)  
  failed = false
  object_types, object_mapping, background, grid_size = object_decomposition 
  object_ids = sort(collect(keys(update_function_times_dict)))
  # # @show object_ids

  atomic_events = gen_event_bool_human_prior(object_decomposition, "x", type_id, ["nothing"], global_var_dict, update_rule, type_displacements)
  # compound_atomic_events = 

  small_event_vector_dict = deepcopy(event_vector_dict)    
  for e in keys(event_vector_dict)
    if !(e in atomic_events) # && foldl(|, map(x -> occursin(x, e), atomic_events))
      delete!(small_event_vector_dict, e)
    else
      object_specific_event_with_wrong_type = !(event_vector_dict[e] isa AbstractArray) && (Set(collect(keys(event_vector_dict[e]))) != Set(collect(keys(update_function_times_dict))))
      if object_specific_event_with_wrong_type 
        delete!(small_event_vector_dict, e)
      end
    end
  end
  for e in keys(event_vector_dict)
    if occursin("|", e) && e in keys(small_event_vector_dict)
      delete!(small_event_vector_dict, e)
    end
  end
  # choices, event_vector_dict, redundant_events_set, object_decomposition
  small_events = construct_compound_events(collect(keys(small_event_vector_dict)), small_event_vector_dict, Set(), object_decomposition)
  for e in keys(event_vector_dict)
    if (occursin("true", e) || occursin("|", e)) && e in keys(small_event_vector_dict)
      delete!(small_event_vector_dict, e)
    end
  end

  # x =  "(& clicked (& true (! (in (objClicked click (prev addedObjType1List)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType1List))))))"
  # small_event_vector_dict[x] = event_vector_dict[x]

  # @show length(collect(keys(event_vector_dict)))
  # @show length(collect(keys(small_event_vector_dict)))

  # initialize state_update_times
  if length(collect(keys(state_update_times))) == 0 || length(intersect(collect(keys(update_function_times_dict)), collect(keys(state_update_times)))) == 0
    for id in collect(keys(update_function_times_dict)) 
      state_update_times[id] = [("", -1) for i in 1:(length(object_mapping[object_ids[1]])-1)]
    end
    curr_state_value = 1
  else
    # check if update function times occur during a single field1 value 
    curr_state_value = maximum(vcat(map(id -> map(x -> x.custom_field_values[end], filter(y -> !isnothing(y), object_mapping[id])), object_ids)...)) # maximum(vcat(map(id -> map(x -> x[2], state_update_times[id]), object_ids)...)) 

    unique_state_values = unique(vcat(map(id -> map(t -> object_mapping[id][t].custom_field_values[end], update_function_times_dict[id]), object_ids)...))
    if unique_state_values != [curr_state_value]
      return ("", [], object_decomposition, state_update_times)  
    end
  end

  # compute co-occurring event 
  # events = filter(k -> event_vector_dict[k] isa Array, collect(keys(event_vector_dict))) 
  events = collect(keys(event_vector_dict))
  co_occurring_events = []
  for event in events
    if event_vector_dict[event] isa AbstractArray
      event_vector = event_vector_dict[event]
      co_occurring = foldl(&, map(update_function_times -> is_co_occurring(event, event_vector, update_function_times), collect(values(update_function_times_dict))), init=true)      
    
      if co_occurring
        false_positive_count = foldl(+, map(k -> num_false_positives(event_vector, update_function_times_dict[k], object_mapping[k]), collect(keys(update_function_times_dict))), init=0)
        push!(co_occurring_events, (event, false_positive_count))
      end
    elseif (Set(collect(keys(event_vector_dict[event]))) == Set(collect(keys(update_function_times_dict))))
      event_vector = event_vector_dict[event]
      co_occurring = foldl(&, map(id -> is_co_occurring(event, event_vector[id], update_function_times_dict[id]), collect(keys(update_function_times_dict))), init=true)
      
      if co_occurring
        false_positive_count = foldl(+, map(id -> num_false_positives(event_vector[id], update_function_times_dict[id], object_mapping[id]), collect(keys(update_function_times_dict))), init=0)
        push!(co_occurring_events, (event, false_positive_count))
      end
    end
  end
  co_occurring_events = sort(filter(x -> !occursin("|", x[1]), co_occurring_events), by=x -> x[2]) # [1][1]
  # co_occurring_events = sort(co_occurring_events, by=x -> x[2]) # [1][1]
  if filter(x -> !occursin("globalVar", x[1]), co_occurring_events) != []
    co_occurring_events = filter(x -> !occursin("globalVar", x[1]), co_occurring_events)
  end
  best_co_occurring_events = sort(filter(e -> e[2] == minimum(map(x -> x[2], co_occurring_events)), co_occurring_events), by=z -> length(z[1]))
  # # # @show best_co_occurring_events
  co_occurring_event = best_co_occurring_events[1][1]
  co_occurring_event_trajectory = event_vector_dict[co_occurring_event]

  augmented_positive_times_dict = Dict()
  for object_id in object_ids
    true_positive_times = update_function_times_dict[object_id] # times when co_occurring_event happened and update_rule happened 
    false_positive_times = [] # times when user_event happened and update_rule didn't happen
    
    # construct false_positive_times 
    for time in 1:(length(object_mapping[object_ids[1]])-1)
      if co_occurring_event_trajectory isa AbstractArray
        if co_occurring_event_trajectory[time] == 1 && !(time in true_positive_times) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          push!(false_positive_times, time)
        end
      else 
        if co_occurring_event_trajectory[object_id][time] == 1 && !(time in true_positive_times) && !isnothing(object_mapping[object_id][time]) && !isnothing(object_mapping[object_id][time + 1])
          push!(false_positive_times, time)
        end
      end
    end

    # construct positive times list augmented by true/false value 
    augmented_true_positive_times = map(t -> (t, curr_state_value), true_positive_times)
    augmented_false_positive_times = map(t -> (t, curr_state_value + 1), false_positive_times)
    augmented_positive_times = sort(vcat(augmented_true_positive_times, augmented_false_positive_times), by=x -> x[1])  

    augmented_positive_times_dict[object_id] = augmented_positive_times 
  end

  # compute ranges 
  grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, curr_state_value, object_mapping, object_ids)
  max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...))

  while length(grouped_ranges) > 0
    grouped_range = grouped_ranges[1]
    grouped_ranges = grouped_ranges[2:end]

    range = grouped_range[1]
    start_value = range[1][2]
    end_value = range[2][2]

    max_state_value = maximum(vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...))

    # TODO: try global events too  
    events_in_range = []
    if events_in_range == [] # if no global events are found, try object-specific events 
      # events_in_range = find_state_update_events(event_vector_dict, augmented_positive_times, time_ranges, start_value, end_value, global_var_dict, global_var_value)
      events_in_range = find_state_update_events_object_specific(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value)
    end
    # @show events_in_range
    if length(events_in_range) > 0 # only handling perfect matches currently 
      event, event_times = events_in_range[1]
      formatted_event = replace(event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
      # construct state_update_function
      if occursin("clicked", formatted_event)
        state_update_function = """(on clicked\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      else
        state_update_function = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      end
      # println(state_update_function)
      for id in object_ids # collect(keys(state_update_times))
        object_event_times = map(t -> t[1], filter(time -> time[2] == id, event_times))
        for time in object_event_times
          # println(id)
          # println(time)
          # println(end_value)
          state_update_times[id][time] = (state_update_function, end_value)
        end
      end
    else
      false_positive_events = find_state_update_events_object_specific_false_positives(small_event_vector_dict, augmented_positive_times_dict, grouped_range, object_ids, object_mapping, curr_state_value)      
      false_positive_events_with_state = filter(e -> occursin("field1", e[1]), false_positive_events) # want the most specific events in the false positive case
      # @show false_positive_events
      events_without_true = filter(tuple -> !occursin("true", tuple[1]) && tuple[2] == minimum(map(t -> t[2], false_positive_events_with_state)), false_positive_events_with_state)
      if events_without_true != []
          false_positive_event, _, true_positive_times, false_positive_times = events_without_true[1] 
      else
        # FAILURE CASE: only separating event with false positives is true-based 
        # false_positive_event, _, true_positive_times, false_positive_times = false_positive_events_with_state[1]
        failed = true 
        break  
      end

      # construct state update on-clause
      formatted_event = replace(false_positive_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
      if occursin("clicked", formatted_event)
        state_update_on_clause = """(on clicked\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      else
        state_update_on_clause = """(on true\n(= addedObjType$(type_id)List (updateObj addedObjType$(type_id)List (--> obj (updateObj obj "field1" $(end_value))) (--> obj $(formatted_event)) )))"""
      end

      # add to state_update_times
      for tuple in true_positive_times 
        time, id = tuple
        state_update_times[id][time] = (state_update_function, end_value)
      end
      
      augmented_positive_times_dict_labeled = Dict(map(id -> id => map(tuple -> (tuple[1], tuple[2], "update_function"), augmented_positive_times_dict[id]), collect(keys(object_ids))))
      for tuple in false_positive_times
        time, id = tuple  
        push!(augmented_positive_times_dict_labeled[id], (time, max_state_value + 1, "event"))
      end
      same_time_tuples = Dict()
      for id in collect(keys(augmented_positive_times_dict_labeled))
        same_time_tuples[id] = Dict()
        for tuple in augmented_positive_times_dict_labeled[id]
          time = tuple[1] 
          if time in collect(keys((same_time_tuples[id]))) 
            push!(same_time_tuples[id][time], tuple)
          else
            same_time_tuples[id][time] = [tuple]
          end
        end
      end

      for id in collect(keys(same_time_tuples_dict))
        for time in collect(keys((same_time_tuples[id]))) 
          same_time_tuples[id][time] = reverse(sort(same_time_tuples[id][time], by=x -> length(x[3]))) # ensure all event tuples come *after* the update_function tuples
        end
        augmented_positive_times_dict_labeled[id] = vcat(map(t -> same_time_tuples[id][t], sort(collect(keys(same_time_tuples[id]))))...)
      end
      # augmented_positive_times_labeled = sort(augmented_positive_times_labeled, by=x->x[1])

      # relabel false positive times 
      # based on relabeling, relabel other existing labels if necessary 
      augmented_positive_times_dict = Dict()
      for id in collect(keys(augmented_positive_times_dict_labeled))
        augmented_positive_times_labeled = augmented_positive_times_dict_labeled[id]
        for tuple_index in 1:length(augmented_positive_times_labeled)
          tuple = augmented_positive_times_labeled[tuple_index]
          if tuple[3] == "event"
            for prev_index in (tuple_index-1):-1:1
              prev_tuple = augmented_positive_times_labeled[prev_index]
  
              # if we have reached a prev_tuple with global_var_value or extra value, then we stop the relabeling based on this event tuple
              if prev_tuple[2] == curr_state_value # || prev_tuple[2] in extra_global_var_values
                break
                # # # println("HERE 2")
                # # @show prev_tuple 
                # # @show tuple
                # if prev_tuple[1] == tuple[1] # && !(prev_tuple[2] in extra_global_var_values) # if the false positive time is the same as the global_var_value time, change the value
                #   # # println("HERE")
  
                #   augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                #   push!(extra_global_var_values, max_global_var_value + 1)
                #   break
                # else # if the two times are different, stop the relabeling process w.r.t. to this false positive tuple 
                #   break
                # end
              end
              
              # relabel update function prev_tuple with label greater than global_var_value and not an extra value 
              if (prev_tuple[2] > curr_state_value) && (prev_tuple[3] == "update_function") #  && !(prev_tuple[2] in extra_global_var_values)
                # if interval_painting_param 
                #   # before relabeling, check if there is a transition event between this prev_tuple's and tuple's time
                #   tuple_time = tuple[1]
                #   prev_tuple_time = prev_tuple[1]
                #   range_times = collect(prev_tuple_time:(tuple_time-1))
                #   events_in_range = find_matching_global_event(range_times, small_event_vector_dict)
  
                #   # @show tuple_time 
                #   # @show prev_tuple_time 
                #   # @show range_times
                #   if events_in_range == [] 
                #     augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                #   else # exists such an in-between explaining event
                #     # stop relabeling, as in-between explaining transition event has been found 
                #     break
                #   end
                # else
                  augmented_positive_times_labeled[prev_index] = (prev_tuple[1], max_global_var_value + 1, prev_tuple[3])
                # end
              end
            end
          end
        end
        augmented_positive_times = map(t -> (t[1], t[2]), filter(tuple -> tuple[3] == "update_function", augmented_positive_times_labeled))      
        augmented_positive_times_dict[id] = augmented_positive_times
      end

      # compute new ranges 
      grouped_ranges = recompute_ranges_object_specific(augmented_positive_times_dict, curr_state_value, object_mapping, object_ids)
      state_update_times = init_state_update_times
    end
  end

  if failed 
    "", [], object_decomposition, state_update_times  
  else
    # construct field values for each object 
      object_field_values = Dict()
      for object_id in object_ids
        if length(augmented_positive_times_dict[object_id]) != 0 
          init_value = augmented_positive_times_dict[object_id][1][2]
        else
          # @show state_update_times
          no_state_updates = length(unique(collect(Base.values(state_update_times)))) == 1
          # @show no_state_updates 
          # @show state_update_times
          # @show augmented_positive_times_dict 
          # @show type_id 
          if no_state_updates 
            values = vcat(map(id -> map(tuple -> tuple[2], augmented_positive_times_dict[id]), collect(keys(augmented_positive_times_dict)))...)
            mode = reverse(sort(unique(values), by=x -> count(y -> y == x, values)))[1]
            init_value = mode
            # @show mode
          else 
            init_value = curr_state_value + 1
          end
        end
        # init_value = length(augmented_positive_times_dict[object_id]) == 0 ? (max_state_value + 1) : augmented_positive_times_dict[object_id][1][2]
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
      push!(new_object_type.custom_fields, ("field1", "Int", collect(1:max_state_value)))
    else
      custom_field_index = findall(field_tuple -> field_tuple[1] == "field1", filter(obj -> !isnothing(obj), object_mapping[object_ids[1]])[1].type.custom_fields)[1]
      new_object_type.custom_fields[custom_field_index][3] = sort(unique(vcat(new_object_type.custom_fields[custom_field_index][3], collect(1:max_state_value))))
    end
    
    ## modify objects in object_mapping
    new_object_mapping = deepcopy(object_mapping)
    for id in collect(keys(new_object_mapping))
      if id in object_ids
        for time in 1:length(new_object_mapping[id])
          if !isnothing(object_mapping[id][time])
            values = new_object_mapping[id][time].custom_field_values
            if !((values != []) && (values[end] isa Int) && (values[end] < curr_state_value))
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

    # @show new_object_decomposition

    formatted_co_occurring_event = replace(co_occurring_event, "(filter (--> obj (== (.. obj id) x)) (prev addedObjType$(type_id)List))" => "(list (prev obj))")
    if !occursin("field1", formatted_co_occurring_event)
      on_clause = "(on true\n$(replace(update_rule, "(== (.. obj id) x)" => "(& $(formatted_co_occurring_event) (== (.. obj field1) $(curr_state_value)))")))"
    else
      on_clause = "(on true\n$(replace(update_rule, "(== (.. obj id) x)" => formatted_co_occurring_event)))"
    end
    
    state_update_on_clauses = map(x -> x[1], unique(filter(r -> r != ("", -1), vcat([state_update_times[k] for k in collect(keys(state_update_times))]...))))
    on_clause, state_update_on_clauses, new_object_decomposition, state_update_times  
  end
end

function is_no_change_rule(update_rule)
  update_functions = ["moveLeft", "moveRight", "moveUp", "moveDown", "nextSolid", "nextLiquid", "color", "addObj", "move"]
  !foldl(|, map(x -> occursin(x, update_rule), update_functions))
end 

function full_program(observations, user_events, matrix, grid_size=16; singlecell=false, pedro=false, upd_func_space=1)
  matrix, unformatted_matrix, object_decomposition, _ = singletimestepsolution_matrix(observations, user_events, grid_size, singlecell=singlecell, pedro=pedro, upd_func_space=upd_func_space)

  object_types, object_mapping, background, _ = object_decomposition
  
  new_matrix = [[] for i in 1:size(matrix)[1], j in 1:size(matrix)[2]]
  for i in 1:size(new_matrix)[1]
    for j in 1:size(new_matrix)[2]
      new_matrix[i, j] = unique(matrix[i, j]) 
    end 
  end
  matrix = new_matrix

  on_clauses, new_object_decomposition, global_var_dict = generate_on_clauses(matrix, unformatted_matrix, object_decomposition, user_events, grid_size)[1]
  s = full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
end

function format_on_clause_full_program(on_clause, object_decomposition, matrix)
   
  @show on_clause 
  object_types, object_mapping, background, _ = object_decomposition
  update_function = split(on_clause, "\n")[2][1:end-1]
  has_let = occursin("let", update_function)

  if has_let 
    update_function = replace(update_function[1:end-2], "(let (" => "")
  end

  if occursin("addObj", on_clause)
    # determine object type 
    type_id = parse(Int, split(split(split(on_clause, "(= addedObjType")[2], "(ObjType")[2], " ")[1])
    object_type = filter(t -> t.id == type_id, object_types)[1]
    if "field1" in map(tuple -> tuple[1], object_type.custom_fields)
      object_ids_with_type = filter(id -> filter(obj -> !isnothing(obj), object_mapping[id])[1].type.id == type_id, collect(keys(object_mapping)))
      if length(filter(x -> x != "", split(update_function, " (="))) > 1
        corresponding_object_ids = filter(id -> split(update_function, " (=")[1] in vcat(matrix[id, :]...), object_ids_with_type)
      else
        corresponding_object_ids = filter(id -> update_function in vcat(matrix[id, :]...), object_ids_with_type)
      end

      field_values = map(i -> filter(obj -> !isnothing(obj), object_mapping[i])[1].custom_field_values[end], filter(id -> isnothing(object_mapping[id][1]), corresponding_object_ids))
      field_value = field_values[1]
      replace(on_clause, "(ObjType$(type_id)" => "(ObjType$(type_id) $(field_value)")
    else
      on_clause
    end
  else
    on_clause
  end
end

function full_program_given_on_clauses(on_clauses, new_object_decomposition, global_var_dict, grid_size, matrix)
  # @show new_object_decomposition
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

  # format on_clauses with fields
  on_clauses = map(c -> format_on_clause_full_program(c, new_object_decomposition, matrix), on_clauses)

  # true_on_clauses = filter(on_clause -> occursin("on true", on_clause), on_clauses)
  # user_event_on_clauses = filter(on_clause -> !(on_clause in true_on_clauses) && foldl(|, map(event -> occursin(event, on_clause) , ["clicked", "left", "right", "down", "up"])), on_clauses)
  # other_on_clauses = filter(on_clause -> !((on_clause in true_on_clauses) || (on_clause in user_event_on_clauses)), on_clauses)
  
  # on_clauses = vcat(true_on_clauses, other_on_clauses..., user_event_on_clauses...)
  
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