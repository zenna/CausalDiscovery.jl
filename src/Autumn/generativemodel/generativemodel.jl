include("scene.jl")
include("dynamics.jl")

"""Generate program"""
function generateprogram(rng=Random.GLOBAL_RNG; gridsize::Int=16, group::Bool=false)
  # generate objects and types 
  types_and_objects = generatescene_objects(rng, gridsize=gridsize)
  generateprogram_given_objects(types_and_objects, rng, gridsize=gridsize, group=group)
end

"""Generate program given object decomposition (types and objects)"""
function generateprogram_given_objects(types_and_objects, rng=Random.GLOBAL_RNG; gridsize::Int=16, group::Bool=false)
  # generate objects and types 
  types, objects, background, _ = types_and_objects

  non_object_global_vars = []
  num_non_object_global_vars = rand(0:0)

  for i in 1:num_non_object_global_vars
    type = rand(["Bool", "Int"])
    if type == "Bool"
      push!(non_object_global_vars, (type, rand(["true", "false"]), i))
    else
      push!(non_object_global_vars, (type, rand(1:3), i))
    end
  end

  if (!group)
    # construct environment object
    environment = Dict(["custom_types" => Dict(
                                              map(t -> "Object_ObjType$(t.id)" => t.custom_fields, types) 
                                              ),
                        "variables" => Dict(
                                            vcat(
                                            map(obj -> "obj$(obj.id)" => "Object_ObjType$(obj.type.id)", objects)...,                    
                                            map(tuple -> "globalVar$(tuple[3])" => tuple[1], non_object_global_vars)...
                                            )
                                           )])
    
    # generate next values for each object
    next_vals = map(obj -> genObjectUpdateRule("obj$(obj.id)", environment), objects)
    objects = [(objects[i], next_vals[i]) for i in 1:length(objects)]

    # generate on-clauses for each object
    on_clause_object_ids = rand(1:length(objects), rand(1:length(objects)))
    on_clauses = map(i -> (genBool(environment), genUpdateRule("obj$(i)", environment, p=0.5), i), on_clause_object_ids)

    # generate on-clauses for each non-object global variable
    # generate next values for each non-object global variable
    if length(non_object_global_vars) != 0
      non_object_nexts = map(tuple -> genUpdateRule("globalVar$(tuple[3])", environment), non_object_global_vars)
      non_object_on_clause_ids = rand(1:length(non_object_global_vars), rand(0:length(non_object_global_vars)))
      non_object_on_clauses = map(i -> (genBool(environment), genUpdateRule("globalVar$(i)", environment), i), non_object_on_clause_ids)
    else
      non_object_nexts = []
      non_object_on_clauses = []
    end

    """
    (program
      (= GRID_SIZE $(gridsize))
      (= background "$(background)")
      $(join(map(t -> "(object ObjType$(t.id) $(join(map(field -> "(: $(field[1]) $(field[2]))", t.custom_fields), " ")) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

      $(join(map(tuple -> "(: globalVar$(tuple[3]) $(tuple[1]))", non_object_global_vars), "\n  "))

      $(join(map(tuple -> "(= globalVar$(tuple[3]) (initnext $(tuple[2]) $(non_object_nexts[tuple[3]])))", non_object_global_vars), "\n  "))

      $((join(map(obj -> """(: obj$(obj[1].id) ObjType$(obj[1].type.id))""", objects), "\n  "))...)

      $((join(map(obj -> 
      """(= obj$(obj[1].id) (initnext (ObjType$(obj[1].type.id) $(join(obj[1].custom_field_values, " ")) (Position $(obj[1].position[1] - 1) $(obj[1].position[2] - 1))) $(obj[2])))""", objects), "\n  ")))

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= obj$(tuple[3]) $(tuple[2])))""", on_clauses), "\n  "))...)

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= globalVar$(tuple[3]) $(tuple[2])))""", non_object_on_clauses), "\n  "))...)
    )
    """
  else
    # group objects of the same type into lists
    type_ids = unique(map(obj -> obj.type.id, objects))
    list_type_ids = filter(id -> count(obj -> obj.type.id == id, objects) > 1, type_ids)
    constant_type_ids = filter(id -> count(obj -> obj.type.id == id, objects) == 1, type_ids)

    # # println(length(types))
    # # println(length(objects))

    environment = Dict(["custom_types" => Dict(
                                map(t -> "Object_ObjType$(t.id)" => t.custom_fields, types) 
                                ),
                        "variables" => Dict(
                              vcat(
                                map(id -> "objList$(findall(x -> x == id, list_type_ids)[1])" => "ObjectList_ObjType$(id)", list_type_ids)...,
                                map(id -> "obj$(findall(x -> x == id, constant_type_ids)[1])" => "Object_ObjType$(id)", constant_type_ids)...,
                                map(tuple -> "globalVar$(tuple[3])" => tuple[1], non_object_global_vars)...       
                              )             
                            )])

    # generate next values and on-clauses for each object
    # lists
    if length(list_type_ids) != 0
      next_list_vals = map(id -> genUpdateRule("objList$(findall(x -> x == id, list_type_ids)[1])", environment), list_type_ids)

      on_clause_list_ids = rand(list_type_ids, rand(1:length(list_type_ids)))
      on_clauses_list = map(id -> (genBool(environment), genUpdateRule("objList$(findall(x -> x == id, list_type_ids)[1])", environment, p=0.5), findall(x -> x == id, list_type_ids)[1]), on_clause_list_ids)
    else
      next_list_vals = []
      on_clauses_list = []
    end

    # constants
    if length(constant_type_ids) != 0
      next_constant_vals = map(id -> genUpdateRule("obj$(findall(x -> x == id, constant_type_ids)[1])", environment), constant_type_ids)
      
      on_clauses_constant_ids = rand(constant_type_ids, rand(1:length(constant_type_ids)))
      on_clauses_constant = map(id -> (genBool(environment), genUpdateRule("obj$(findall(x -> x == id, constant_type_ids)[1])", environment, p=0.5), findall(x -> x == id, constant_type_ids)[1]), on_clauses_constant_ids)
    else
      next_constant_vals = []
      on_clauses_constant = []
    end

    # generate next values and on-clauses for each non-object variable
    if length(non_object_global_vars) != 0
      non_object_nexts = map(tuple -> genUpdateRule("globalVar$(tuple[3])", environment), non_object_global_vars)
      non_object_on_clause_ids = rand(1:length(non_object_global_vars), rand(0:length(non_object_global_vars)))
      non_object_on_clauses = map(i -> (genBool(environment), genUpdateRule("globalVar$(i)", environment), i), non_object_on_clause_ids)
    else
      non_object_nexts = []
      non_object_on_clauses = []
    end
    """
    (program
      (= GRID_SIZE $(gridsize))
      (= background "$(background)")
      $(join(map(t -> "(object ObjType$(t.id) $(join(map(field -> "(: $(field[1]) $(field[2]))", t.custom_fields), " ")) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

      $(join(map(tuple -> "(: globalVar$(tuple[3]) $(tuple[1]))", non_object_global_vars), "\n  "))

      $(join(map(tuple -> "(= globalVar$(tuple[3]) (initnext $(tuple[2]) $(non_object_nexts[tuple[3]])))", non_object_global_vars), "\n  "))

      $((join(map(id -> """(: objList$(findall(x -> x == id, list_type_ids)[1]) (List ObjType$(id)))""", list_type_ids), "\n  "))...)
      $((join(map(id -> """(: obj$(findall(x -> x == id, constant_type_ids)[1]) ObjType$(id))""", constant_type_ids), "\n  "))...)

      $((join(map(id -> 
      """(= objList$(findall(x -> x == id, list_type_ids)[1]) (initnext (list $(join(map(obj -> "(ObjType$(obj.type.id) $(join(obj.custom_field_values, " ")) (Position $(obj.position[1] - 1) $(obj.position[2] - 1)))", filter(o -> o.type.id == id, objects)), " "))) $(next_list_vals[findall(y -> y == id, list_type_ids)[1]])))""", list_type_ids), "\n  ")))

      $((join(map(id -> 
      """(= obj$(findall(x -> x == id, constant_type_ids)[1]) (initnext $(join(map(obj -> "(ObjType$(obj.type.id) $(join(obj.custom_field_values, " ")) (Position $(obj.position[1] - 1) $(obj.position[2] - 1)))", filter(o -> o.type.id == id, objects)))) $(next_constant_vals[findall(y -> y == id, constant_type_ids)[1]])))""", constant_type_ids), "\n  ")))

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= objList$(tuple[3]) $(tuple[2])))""", on_clauses_list), "\n  "))...)

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= obj$(tuple[3]) $(tuple[2])))""", on_clauses_constant), "\n  "))...)

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= globalVar$(tuple[3]) $(tuple[2])))""", non_object_on_clauses), "\n  "))...)
    )
    """
  end
end

function generate_hypothesis_update_rule(object, object_decomposition; p=0.0)
  types, objects, background, gridsize = object_decomposition
  objects = [object, filter(o -> o.position != (-1, -1), objects)...]
  # construct environment 
  environment = Dict(["custom_types" => Dict(map(t -> "Object_ObjType$(t.id)" => t.custom_fields, types) 
                          ),
                      "variables" => Dict(map(obj -> "obj$(obj.id)" => "Object_ObjType$(obj.type.id)", objects)
                      )])
 
  # generate update rule 
  """(= obj$(object.id) $(genObjectUpdateRule("obj$(object.id)", environment, p=p)))"""
end

function generate_hypothesis_position(position, environment_vars, pedro)
  # # println("GENERATE_HYPOTHESIS_POSITION")
  objects = map(obj -> "obj$(obj.id)", filter(x -> x isa Obj, environment_vars))
  user_event = filter(x -> !(x isa Obj), environment_vars)[1]
  # # @show environment_vars
  choices = []
  # # @show length(objects)
  if length(objects) != 0
    if !pedro 
      push!(choices, ["(.. (prev $(rand(objects))) origin)",
      "(move (.. (prev $(rand(objects))) origin) (Position $(rand(-1:1)) $(rand(-1:1))))"]...)
    else
      push!(choices, ["(.. $(rand(objects)) origin)",
      "(move (.. (prev $(rand(objects))) origin) (Position $(rand(-30:30)) $(rand(-30:30))))"]...)
    end
  end

  if !isnothing(user_event) && (user_event != "nothing") && (occursin("click", split(user_event, " ")[1])) 
    push!(choices, "(Position (.. click x) (.. click y))")
  end

  if choices == []
    ""
  else
    choices[rand(1:length(choices))]
  end
end

function generate_hypothesis_position_program(hypothesis_position, actual_position, object_decomposition)
  program_no_update_rules = program_string_synth(object_decomposition)

  program = string(program_no_update_rules[1:end-2], "\n",
                    """
                    (: matches Bool)
                    (= matches (initnext false (prev matches)))
                
                    (on (== $(hypothesis_position) (Position $(actual_position[1]) $(actual_position[2]))) (= matches true)) 
                    """, "\n",
                   ")")

end

function generate_hypothesis_string(string, environment_vars, object_types)
  objects = filter(x -> (x isa Obj) && length(x.type.custom_fields) > 0, environment_vars)
  object = rand(objects)
  # # @show string
  # # @show objects
  x = filter(type -> length(type.custom_fields) > 0 && string in type.custom_fields[1][3], object_types)
  # # @show x
  pair_string = filter(s -> s != string, map(type -> type.custom_fields[1][3], filter(type -> length(type.custom_fields) > 0 && string in type.custom_fields[1][3], object_types))[1])[1]

  first_string, second_string = rand() > 0.5 ? (string, pair_string) : (pair_string, string)
  """(if (== (.. (prev obj$(object.id)) color) "$(object.type.custom_fields[1][3][1])") then "$(first_string)" else "$(second_string)")"""
end

function generate_hypothesis_string_program(hypothesis_string, actual_string, object_decomposition)
  program_no_update_rules = program_string_synth(object_decomposition)

  program = string(program_no_update_rules[1:end-2], "\n",
                    """
                    (: matches Bool)
                    (= matches (initnext false (prev matches)))
                
                    (on (== $(hypothesis_string) "$(actual_string)") (= matches true)) 
                    """, "\n",
                   ")")
end

function gen_event_bool_human_prior(object_decomposition, object_id, type_id, user_events, global_var_dict, update_rule) 
  object_types, object_mapping, _, grid_size = object_decomposition
  start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
  if type_id in map(o -> o.type.id, non_list_objects)
    in_a_list = false
  else
    in_a_list = true
  end
  user_events = filter(e -> (e != "") && (e != "nothing") && !isnothing(e), user_events)

  object_color = ""
  if occursin("addObj", update_rule) && ("color" in map(x -> x[1], filter(t -> t.id == type_id, object_types)[1].custom_fields))
    update_rule_parts = split(update_rule, "\"")
    object_color = strip(update_rule_parts[2])
  end

  # USER EVENTS
  choices = ["true", "up", "down", "left", "right", "clicked", "(& clicked (isFree click))"] # "clicked"


  # globalVar-related
  if length(collect(keys(global_var_dict))) > 0 
    for key in collect(keys(global_var_dict))
      values = unique(global_var_dict[key])
      for value in values 
        push!(choices, "(== (prev globalVar$(key)) $(value))")
      end
    end
  end


  # OBJECT CONTACT: INTERSECTING OBJECTS + ADJACENT OBJECTS 
  if length(non_list_objects) > 0 
    for object_1 in non_list_objects

      # ----- TEMP ADDITION: REMOVE LATER ----- #
      ## used in Grow example
      # push!(choices, unique(map(obj -> "(== (.. (.. (prev obj$(object_1.id)) origin) x) $(obj.position[1]))", filter(x -> !isnothing(x), object_mapping[object_1.id])))...)
      # --------------------------------------- #      

      for object_2 in non_list_objects 
        if object_1.id != object_2.id 
          push!(choices, [
            "(! (intersects (prev obj$(object_1.id)) (prev obj$(object_2.id))))",
            "(intersects (adjacentObjs (prev obj$(object_1.id)) 1) (prev obj$(object_2.id)))",
            # "(adj (prev obj$(object_1.id)) (prev obj$(object_2.id)) 1)",
          ]...)
        end
      end
    end
  end

  if non_list_objects != [] 
    for object in non_list_objects 
      push!(choices, "(clicked (prev obj$(object.id)))")

      push!(choices, vcat(map(pos -> [ "(== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1]))",
                                    #  "(== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2]))",
                                    #  "(& (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2])))",
                                    #  "(& (.. (prev obj$(object.id)) alive) (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])))",
                                    #  "(& (.. (prev obj$(object.id)) alive) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2])))",
                                    #  "(& (.. (prev obj$(object.id)) alive) (& (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2]))))"
                                    ], 
                          map(obj -> obj.position, filter(x -> !isnothing(x) && (abs(x.position[1]) <= 3 || abs(x.position[1] - (grid_size isa Int ? grid_size : grid_size[1])) <= 3), object_mapping[object.id])))...)...)
      
      displacements = []
      for x in -3:3 
        for y in -3:3
          if abs(x) + abs(y) < 3 && (x == 0 || y == 0) 
            push!(displacements, "(move (prev obj$(object.id)) $(x) $(y))")
            # push!(displacements, "(move (prev obj$(object.id)) $(x * 30) $(y * 30))")
          end
        end
      end

      for disp in displacements 
        push!(choices, "(! (isWithinBounds $(disp)))")
      end
                  
      # push!(choices, ["(! (isWithinBounds (moveLeft  (prev obj$(object.id)))))",
      #                 "(! (isWithinBounds (moveRight  (prev obj$(object.id)))))",
      #                 "(! (isWithinBounds (moveUp  (prev obj$(object.id)))))",
      #                 "(! (isWithinBounds (moveDown  (prev obj$(object.id)))))",
      #                 "(! (isWithinBounds (move  (prev obj$(object.id)) -2 0)))",
      #                 "(! (isWithinBounds (move  (prev obj$(object.id)) 2 0)))",
      #                 "(! (isWithinBounds (move  (prev obj$(object.id)) 0 2)))",
      #                 "(! (isWithinBounds (move  (prev obj$(object.id)) 0 -2)))",
      #                 ]...)

      for type in object_types 
        push!(choices, [
          "(intersects (prev obj$(object.id)) (prev addedObjType$(type.id)List))",
          "(intersects (adjacentObjs (prev obj$(object.id)) 1) (prev addedObjType$(type.id)List))", # can add things with `.. id)` x here
          # "(adj (prev obj$(object.id)) (prev addedObjType$(type.id)List) 1)",
          "(intersects (prev obj$(object.id)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))",
          ]...)
        for object2 in non_list_objects 
          if object.id != object2.id 
            push!(choices, "(intersects (prev obj$(object.id)) (prev obj$(object2.id)))")
            push!(choices, "(! (intersects (prev obj$(object.id)) (prev obj$(object2.id))))")
          end    
        end
      end
    end
  end
  

  for type in object_types 
    # push!(choices, "(clicked (prev addedObjType$(type.id)List))")
    
    # color-related events 
    if (length(type.custom_fields) > 0) && type.custom_fields[1][1] == "color" 
      color_values = filter(x -> x != object_color, type.custom_fields[1][3])
      for color in color_values 
        push!(choices, """(clicked (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")

        for color2 in color_values 
          if color != color2 
            push!(choices, """(intersects (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color2)")) (prev addedObjType$(type.id)List)))""")
          end
        end

        # object_id-based: this causes Mario to break, but is necessary for Sand
        # push!(choices, """(intersects (unfold (map (--> obj (adjacentObjs obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")  
      end
    end
    # more object_id-based  
    push!(choices, "(in (objClicked click (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))")
    push!(choices, "(! (in (objClicked click (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")  
    push!(choices, "(& clicked (! (in (objClicked click (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")  

    push!(choices, "(clicked (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))")

    for type2 in object_types 
      if type2.id != type.id 
        # push!(choices, "(intersects (prev addedObjType$(type.id)List) (prev addedObjType$(type2.id)List))")
        push!(choices, "(intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (prev addedObjType$(type2.id)List))")
      end
    end
  end

  sort(unique(choices), by=length) 
end

function gen_event_bool(object_decomposition, object_id, type_id, update_rule, user_events, global_var_dict, time_based=true, symmetry=false)
  object_types, object_mapping, _, grid_size = object_decomposition
  start_objects = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> (count(y -> y.type.id == x.type.id, start_objects) == 1) && (count(obj_id -> filter(z -> !isnothing(z), object_mapping[obj_id])[1].type.id == x.type.id, collect(keys(object_mapping))) == 1), start_objects)
  user_events = filter(e -> (e != "") && (e != "nothing") && !isnothing(e), user_events)

  # ----- add global events, unrelated to objects -----
  choices = gen_event_bool_human_prior(object_decomposition, object_id, type_id, user_events, global_var_dict, update_rule)

  ## time-related
  if time_based 
    push!(choices, "(== (% (prev time) 10) 5)")
    push!(choices, "(== (% (prev time) 10) 0)")  
    push!(choices, "(== (% (prev time) 5) 2)")
    push!(choices, "(== (% (prev time) 4) 2)") 
    push!(choices, "(== (% (prev time) 16) 0)") 
    # push!(choices, "(== (% (prev time) 16) 1)") 
  end

  # ----- add events dealing with constant objects (i.e. objects not contained in a list) -----
  if non_list_objects != [] 
    for object in non_list_objects 
      # NEW SYMMETRIZATION
      if symmetry 
        push!(choices, "(isFree (.. (move (prev obj$(object.id)) arrow) origin))")
      end


      push!(choices, ["(.. (prev obj$(object.id)) alive)", 
                      "(clicked (prev obj$(object.id)))",
                      vcat(map(pos -> [ "(== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1]))",
                                        # "(== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2]))",
                                      #  "(& (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2])))",
                                      #  "(& (.. (prev obj$(object.id)) alive) (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])))",
                                      #  "(& (.. (prev obj$(object.id)) alive) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2])))",
                                      #  "(& (.. (prev obj$(object.id)) alive) (& (== (.. (.. (prev obj$(object.id)) origin) x) $(pos[1])) (== (.. (.. (prev obj$(object.id)) origin) y) $(pos[2]))))"
                                      ], 
                           map(obj -> obj.position, filter(x -> !isnothing(x) && (abs(x.position[1]) <= 3 || abs(x.position[1] - (grid_size isa Int ? grid_size : grid_size[1])) <= 3), object_mapping[object.id])))...)...,
      ]...)

      if object.type.custom_fields != [] && object.type.custom_fields[1][1] == "color"
        color_values = object.type.custom_fields[1][3]
        for color in color_values 
          push!(choices, """(== (.. (prev obj$(object.id)) color) "$(color)")""")
        end
      end

      for type in object_types
        
        push!(choices, [
          "(intersects (prev obj$(object.id)) (prev addedObjType$(type.id)List))",
          "(! (intersects (prev obj$(object.id)) (prev addedObjType$(type.id)List)))",
          "(intersects (adjacentObjs (prev obj$(object.id)) 1) (prev addedObjType$(type.id)List))", # can add things with `.. id)` x here
          # "(adj (prev obj$(object.id)) (prev addedObjType$(type.id)List) 1)",
          "(intersects (prev obj$(object.id)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))",
          
          # TWO BELOW: SOKOBAN
          # "(& (isWithinBounds (moveLeft (prev obj$(object.id)))) (| (! (intersects (moveLeft (prev obj$(object.id))) (prev addedObjType$(type.id)List))) (& (! (intersects (move (prev obj$(object.id)) (Position -2 0)) (prev addedObjType$(type.id)List))) (isWithinBounds (move (prev obj$(object.id)) (Position -2 0))))))",
          # "(& (isWithinBounds (moveUp (prev obj$(object.id)))) (| (! (intersects (moveUp (prev obj$(object.id))) (prev addedObjType$(type.id)List))) (& (! (intersects (move (prev obj$(object.id)) (Position 0 -2)) (prev addedObjType$(type.id)List))) (isWithinBounds (move (prev obj$(object.id)) (Position 0 -2))))))",
          ]...)

        displacements = []
        for x in -3:3 
          for y in -3:3
             if abs(x) + abs(y) < 5 
              push!(displacements, "(move (prev obj$(object.id)) $(x) $(y))")
             end
          end
        end

        filtered_list = "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))"
        for disp in displacements 
          push!(choices, "(intersects $(disp) (prev addedObjType$(type.id)List))")
          push!(choices, "(! (intersects $(disp) (prev addedObjType$(type.id)List)))")
          push!(choices, "(isWithinBounds $(disp))")
          push!(choices, "(! (isWithinBounds $(disp)))")
        end

        for x in -3:3 
          for y in -3:3 
            if abs(x) + abs(y) < 5 
              push!(choices, "(in (Position $(x) $(y)) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) $(filtered_list)))")
              push!(choices, "(in true (map (--> obj (isWithinBounds obj)) (map (--> obj (move obj $(x) $(y))) $(filtered_list))))")
              push!(choices, "(in true (map (--> obj (isFree (.. obj origin))) (map (--> obj (move obj $(x) $(y))) $(filtered_list))))")   
              for dir in ["left", "right", "up", "down"] 
                push!(choices, "(& $(dir) (in (Position $(x) $(y)) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) $(filtered_list))))")
              end

            end
          end
        end

        if object.type.id != type.id 
          # NEW SYMMETRIZATION
          if symmetry 
            push!(choices, "(moveIntersects arrow (prev obj$(object.id)) $(filtered_list))")
            push!(choices, "(moveIntersects arrow (prev obj$(object.id)) (prev addedObjType$(type.id)List))")
            push!(choices, "(pushConfiguration arrow (prev obj$(object.id)) $(filtered_list))")
            push!(choices, "(pushConfiguration arrow (prev obj$(object.id)) (prev addedObjType$(type.id)List))")    
          end
          push!(choices, "(adj (prev obj$(object.id)) $(filtered_list) 1)")
          push!(choices, "(adj (prev obj$(object.id)) (prev addedObjType$(type.id)List) 1)")
        end

        #   (& left 
        #  (| (! (intersects (moveLeft (prev obj1)) (prev addedObjType2List))) 
     		# (& (! (intersects (move (prev obj1) (Position -2 0)) (prev addedObjType2List))) 
        # 	   (isWithinBounds (move (prev obj1) (Position -2 0))))))
        
        # (& left 
        #         (& (in true (map (--> obj (& (isWithinBounds obj) 
        #                                      (isFree (.. obj origin)))) 
				# 			     (map (--> obj (moveLeft obj)) (list (prev obj))))) 
        #    (in (Position 1 0) (map (--> obj (displacement (.. obj origin) (.. (prev obj1) origin))) (list (prev obj))))))))))
        
        # (& up 
        #   (& (intersects (prev obj5) (map (--> obj (moveUp obj)) (list (prev obj)))) 
        #       (in (Position 0 1) (map (--> obj (displacement (.. obj origin) (.. (prev obj1) origin))) (list (prev obj)))))))))))

        for object2 in non_list_objects 
          if object.id != object2.id 
            push!(choices, "(intersects (prev obj$(object.id)) (prev obj$(object2.id)))")
            push!(choices, "(! (intersects (prev obj$(object.id)) (prev obj$(object2.id))))")


            # NEW SYMMETRIZATION
            if symmetry 
              push!(choices, "(moveIntersects arrow (prev obj$(object.id)) (prev obj$(object_2.id)))")
              push!(choices, "(adj (prev obj$(object.id)) (prev obj$(object_2.id)) 1)")
              push!(choices, "(! (adj (prev obj$(object.id)) (prev obj$(object_2.id)) 1))")
              push!(choices, "(pushConfiguration arrow (prev obj$(object.id)) (prev obj$(object_2.id)))") 
            end

            # sokoban
            ## left 
            # push!(choices, "(& (in true (map (--> obj (& (isWithinBounds obj) (isFree (.. obj origin)))) (map (--> obj (moveLeft obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (in (Position 1 0) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
            # push!(choices, "(& (intersects (prev obj$(object2.id)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (in (Position 1 0) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
            


            # OLD: TWO BELOW, BUT THE SECOND CAUSES A BREAK IN SOMETHING ELSE
            # push!(choices, "(& left (& (in true (map (--> obj (& (isWithinBounds obj) (isFree (.. obj origin)))) (map (--> obj (moveLeft obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (in (Position 1 0) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")
            # push!(choices, "(& left (& (intersects (prev obj$(object2.id)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (in (Position 1 0) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")

            ## up
            # OLD: TWO BELOW
            #push!(choices, "(& up (& (intersects (prev obj$(object2.id)) (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (in (Position 0 1) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")
            # push!(choices, "(& up (& (in true (map (--> obj (& (isWithinBounds obj) (isFree (.. obj origin)))) (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (in (Position 0 1) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")
            # push!(choices, "(& (intersects (prev obj$(object2.id)) (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (in (Position 0 1) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
            # push!(choices, "(& (in true (map (--> obj (& (isWithinBounds obj) (isFree (.. obj origin)))) (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (in (Position 0 1) (map (--> obj (displacement (.. obj origin) (.. (prev obj$(object.id)) origin))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
          end    
        end
      end
    end
  end

  # # ----- add events dealing with objects contained in a list -----
  for type in object_types 
    push!(choices, "(clicked (prev addedObjType$(type.id)List))")
    # push!(choices, "(== (prev addedObjType$(type.id)List) (list))")
    # push!(choices, "(!= (prev addedObjType$(type.id)List) (list))")    

  #   # out-of-bounds handling 
    displacements = ["(moveUp obj)", "(moveDown obj)", "(moveLeft obj)", "(moveRight obj)", "(move obj -1 1)", "(move obj 1 1)"]
    for disp1 in displacements 
      push!(choices, "(in true       (map (--> obj (! (isWithinBounds $(disp1)))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
      # for disp2 in displacements 
      #   if disp1 != disp2 
      #     push!(choices, "(in true (map (--> obj (| (! (isWithinBounds $(disp1))) (! (isWithinBounds $(disp2))))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
      #   end
      # end
    end

    filtered_list = "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))" 
    for dir in ["Left", "Right", "Up", "Down"]
      push!(choices, "(! (intersects (map (--> obj (.. (move$(dir)NoCollision (prev obj)) origin)) $(filtered_list)) (map (--> obj (.. (prev obj) origin)) $(filtered_list))))")
    end

    # for type2 in object_types
    #   for type3 in object_types 
    #     if length(unique([type, type2, type3])) == 3 
    #       push!(choices, "(& (intersects (prev addedObjType$(type2.id)List) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (intersects (prev addedObjType$(type3.id)List) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    #     end
    #   end
    # end

    # color-related events 
    if (length(type.custom_fields) > 0) && type.custom_fields[1][1] == "color" 
      color_values = type.custom_fields[1][3]
      for color in color_values

        for color2 in color_values 
          for xCoord in -4:4 
            for yCoord in -4:4
              
              if abs(xCoord) + abs(yCoord) < 5 
                filtered_list = "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))" 
                # # push!(choices, """(& (intersects (list "$(color2)") (map (--> obj2 (.. obj2 color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (! (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List)))))))""")
                # # push!(choices, """(& (intersects (list "$(color2)") (map (--> obj2 (.. obj2 color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List))))))""")
                # # for user_event in ["left", "right", "up", "down"]
                # #   push!(choices, """(& $(user_event) (& (intersects (list "$(color2)") (map (--> obj2 (.. obj2 color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (! (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List))))))))""")
                # #   push!(choices, """(& $(user_event) (& (intersects (list "$(color2)") (map (--> obj2 (.. obj2 color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List)))))))""")
                # # end
  
                push!(choices, """(in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (if (== 0 (length $(filtered_list))) then (Position -10 -10) else (.. (first $(filtered_list)) origin)))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List))))""")
                push!(choices, """(! (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (if (== 0 (length $(filtered_list))) then (Position -10 -10) else (.. (first $(filtered_list)) origin)))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List)))))""")
                
                for dir in ["left", "right", "up", "down"]
                  push!(choices, """(& $(dir) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (if (== 0 (length $(filtered_list))) then (Position -10 -10) else (.. (first $(filtered_list)) origin)))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List)))))""")
                  push!(choices, """(& $(dir) (! (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (if (== 0 (length $(filtered_list))) then (Position -10 -10) else (.. (first $(filtered_list)) origin)))) (filter (--> obj2 (== (.. obj2 color) "$(color)")) (prev addedObjType$(type.id)List))))))""")
                end
              
              end

            end
          end  
        end
    

        # ------- MARIO ADDS ------- # 
        push!(choices, """(intersects (map (--> obj (.. (moveDownNoCollision obj) origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (map (--> obj (.. obj origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))""")
        push!(choices, """(intersects (map (--> obj (.. (moveUpNoCollision obj) origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (map (--> obj (.. obj origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))""")
        push!(choices, """(intersects (map (--> obj (.. (moveLeftNoCollision obj) origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (map (--> obj (.. obj origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))""")
        push!(choices, """(intersects (map (--> obj (.. (moveRightNoCollision obj) origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (map (--> obj (.. obj origin)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))""")


        push!(choices, """(intersects (map (--> obj (moveDown obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")
        push!(choices, """(intersects (map (--> obj (moveLeft obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")        
        push!(choices, """(intersects (map (--> obj (moveRight obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")                
        push!(choices, """(intersects (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")                

        push!(choices, """(! (intersects (map (--> obj (moveDown obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List))))""")
        push!(choices, """(! (intersects (map (--> obj (moveLeft obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List))))""")        
        push!(choices, """(! (intersects (map (--> obj (moveRight obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List))))""")                
        push!(choices, """(! (intersects (map (--> obj (moveUp obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List))))""")                


        push!(choices, """(clicked (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")
        
        # BELOW LINE OCCASIONALLY CAUSES PROBLEMS
        # push!(choices, """(intersects (list "$(color)") (map (--> obj (.. obj color)) (prev addedObjType$(type.id)List)))""")
        push!(choices, """(clicked (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")

        # object_id-based
        # push!(choices, """(intersects (list "$(color)") (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))""")
        push!(choices, """(intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))""")
        push!(choices, """(intersects (unfold (map (--> obj (adjacentObjs obj 1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")  
        # push!(choices, """(adj (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)) 1)""")
        push!(choices, """(intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color)")) (prev addedObjType$(type.id)List)))""")
        for color2 in color_values 
          if color != color2  
            # GROW
            # push!(choices, """(& (intersects (filter (--> obj (== (.. obj color) "$(color2)")) (prev addedObjType$(type.id)List)) (map (--> obj (moveDown obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))""")
            # push!(choices, """(& (intersects (filter (--> obj (& (== (.. (.. obj origin) y) 5) (== (.. obj color) "$(color2)"))) (prev addedObjType$(type.id)List)) (map (--> obj (moveDown obj)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))""")
          
            # ------- MARIO ADDS ------- #
            for color3 in color_values 
              if !(color3 in [color, color2])
                # push!(choices, """(| (& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (prev obj8)) (intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color2)")) (prev addedObjType$(type.id)List))) (intersects (list "$(color3)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))""")                
                if non_list_objects != [] 
                  non_list_object = non_list_objects[1]
                  # push!(choices, """(& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (prev obj$(non_list_object.id))) (intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))""")
                end
                # push!(choices, """(& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color2)")) (prev addedObjType$(type.id)List))) (intersects (list "$(color3)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))""")
              end
            end
      
          end
        end
      end
    end

    # (| (& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (prev obj8)) 
    #       (intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) 
    #    (& (intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj color) "$(color2)")) (prev addedObjType$(type.id)List))) 
    #       (intersects (list $(color3)) (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))

    # more object_id-based  
    push!(choices, "(& true (in (objClicked click (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    push!(choices, "(& true (! (in (objClicked click (prev addedObjType$(type.id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")  
    push!(choices, "(clicked (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))")
    push!(choices, "(in true (map (--> obj (== (.. obj id) $(object_id))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    push!(choices, "(in false (map (--> obj (== (.. obj id) $(object_id))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    
    push!(choices, "(in true (map (--> obj (isFree (adjPositions (.. (prev obj) origin)))) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    
    for i in 0:3
      # for i2 in 0:3 
      #   push!(choices, "(| (& (== (% (prev time) 10) 5) (in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (& (== (% (prev time) 10) 0) (in $(i2) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")
    #     push!(choices, "(| (& (== (% (prev time) 10) 5) (in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))) (& (== (% (prev time) 10) 0) (in $(i2) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))))")
        
    #     push!(choices, "(& (== (% (prev time) 10) 5) (in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
    #     push!(choices, "(& (== (% (prev time) 10) 0) (in $(i2) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")

    #     # ONLY NEED TWO BELOW WITH Z3 PARTIAL!
    #     push!(choices, "(in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    #     push!(choices, "(in $(i2) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")

    #   end
      push!(choices, "(in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    #   push!(choices, "(& (== (% (prev time) 10) 5) (in $(i) (map (--> obj (.. (.. obj origin) y)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))))")
    end

    # for type2 in object_types 
    #   for type3 in object_types 
    #     if length(unique([type.id, type2.id, type3.id])) == 3 
    #       push!(choices, "(| (intersects (prev addedObjType$(type2.id)List) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))) (intersects (prev addedObjType$(type3.id)List) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
    #     end
    #   end
    # end

    # (& $(user_event) 
    #     (! (& (!= (length $(filtered_list)) 0) 
    #           (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 color) $(color))) (prev addedObjType$(type.id)List)))))))

    # object-specific field-based
    object_specific_fields = filter(t -> occursin("field", t[1]), type.custom_fields) 
    if object_specific_fields != []
      field_values = object_specific_fields[1][3]
      for value in field_values
        value2 = filter(v -> v != value, field_values)[1] 
        push!(choices, "(intersects (list $(value)) (map (--> obj (.. obj field1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))))")
      
        # for xCoord in -3:3 
        #   for yCoord in -3:3
        #     filtered_list = "(filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List))" 
        #     push!(choices, "(& (intersects (list $(value2)) (map (--> obj2 (.. obj2 field1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (! (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 field1) $(value))) (prev addedObjType$(type.id)List)))))))")
        #     push!(choices, "(& (intersects (list $(value2)) (map (--> obj2 (.. obj2 field1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 field1) $(value))) (prev addedObjType$(type.id)List))))))")
        #     for user_event in ["left", "right", "up", "down"]
        #       push!(choices, "(& $(user_event) (& (intersects (list $(value2)) (map (--> obj2 (.. obj2 field1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (! (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 field1) $(value))) (prev addedObjType$(type.id)List))))))))")
        #       push!(choices, "(& $(user_event) (& (intersects (list $(value2)) (map (--> obj2 (.. obj2 field1)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)))) (& (!= (length $(filtered_list)) 0) (in (Position $(xCoord) $(yCoord)) (map (--> obj2 (displacement (.. obj2 origin) (.. (first $(filtered_list)) origin))) (filter (--> obj2 (== (.. obj2 field1) $(value))) (prev addedObjType$(type.id)List)))))))")
        #     end          
        #   end
        # end
      end
    end

    for type2 in object_types 
      if type2.id != type.id 
        push!(choices, "(intersects (prev addedObjType$(type.id)List) (prev addedObjType$(type2.id)List))")
        push!(choices, "(intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type.id)List)) (prev addedObjType$(type2.id)List))")

        # NEW SYMMETRIZATION 
        push!(choices, "(adj $(filtered_list) (prev addedObjType$(type2.id)List) 1)")
        push!(choices, "(! (adj $(filtered_list) (prev addedObjType$(type2.id)List) 1))")

      end
    end
  end
  
  events_to_remove = [
    """(& left (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position 0 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "blue")) (prev addedObjType1List)))))))""",
    """(& right (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (! (& (!= (length (list (prev obj))) 0) (in (Position -2 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "red")) (prev addedObjType1List))))))))""",
    """(& down (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position 0 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "blue")) (prev addedObjType1List)))))))""",
    """(& up (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position 0 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "blue")) (prev addedObjType1List)))))))""",
    """(& down (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position -2 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "red")) (prev addedObjType1List)))))))""",
    """(& up (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position -2 0) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "red")) (prev addedObjType1List)))))))""",
    
    """(& right (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position -3 1) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "red")) (prev addedObjType1List)))))))""",
    """(& right (& (intersects (list "blue") (map (--> obj2 (.. obj2 color)) (list (prev obj)))) (& (!= (length (list (prev obj))) 0) (in (Position -3 -1) (map (--> obj2 (displacement (.. obj2 origin) (.. (first (list (prev obj))) origin))) (filter (--> obj2 (== (.. obj2 color) "red")) (prev addedObjType1List)))))))"""
    ]

  choices = filter(x -> !(x in events_to_remove), choices)

  # println("XYZ")
  # # @show choices
  # # @show length(choices)
  # choices = gen_event_bool_human_prior(object_decomposition, object_id, type_id, user_events, global_var_dict, update_rule)
  
  # if time_based 
  #   push!(choices, "(== (% (prev time) 10) 5)")
  #   push!(choices, "(== (% (prev time) 10) 0)")  
  #   push!(choices, "(== (% (prev time) 5) 2)")
  #   push!(choices, "(== (% (prev time) 4) 2)") 
  #   push!(choices, "(== (% (prev time) 16) 0)") 
  #   push!(choices, "(== (% (prev time) 16) 1)") 
  # end
  
  sort(unique(choices), by=length)
end

function construct_compound_events(choices, event_vector_dict, redundant_events_set, object_decomposition)
  # # println("START construct_compound_events")
  # # @show event_vector_dict
  object_specific_events = filter(k -> (k in keys(event_vector_dict)) && !(event_vector_dict[k] isa AbstractArray), choices)
  global_events = filter(k ->  (k in keys(event_vector_dict)) && event_vector_dict[k] isa AbstractArray, choices)

  nonzero_object_specific_events = filter(e -> unique(vcat(collect(values(event_vector_dict[e]))...)) != [0], object_specific_events) 
  nonzero_global_events = filter(e -> unique(event_vector_dict[e]) != [0], global_events)

  compound_events = []

  filter!(e -> occursin("clicked", e), nonzero_global_events)
  filter!(e -> occursin("clicked", e), nonzero_object_specific_events)

  # construct global/global compound events and global/object-specific compound events 
  # # @show length(nonzero_global_events)
  # # @show length(nonzero_object_specific_events)
  nonzero_global_events = sort(nonzero_global_events, by=length)
  # # # @show nonzero_global_events 
  for i in 1:length(nonzero_global_events) 
    # # @show i
    event_i = nonzero_global_events[i]
    # # @show event_i
    for j in (i+1):length(nonzero_global_events)
      event_j = nonzero_global_events[j]
      and_event = "(& $(event_i) $(event_j))"
      or_event = "(| $(event_i) $(event_j))"
      if !occursin(event_i, event_j) && !occursin(event_j, event_i)
        and_value = event_vector_dict[event_i] .& event_vector_dict[event_j] 
        or_value = event_vector_dict[event_i] .| event_vector_dict[event_j]
        
        if unique(and_value) != [0]
          push!(compound_events, and_event)
          event_vector_dict[and_event] = and_value
        end

        if unique(or_value) != [0]
          push!(compound_events, or_event)
          event_vector_dict[or_event] = or_value
        end

      end
    end 

    for k in 1:length(nonzero_object_specific_events) 
      event_k = nonzero_object_specific_events[k]
      and_event = "(& $(event_i) $(event_k))"
      or_event = "(| $(event_i) $(event_k))"
      and_event_values = Dict()
      or_event_values = Dict()
      object_ids = collect(keys(event_vector_dict[event_k]))
      for object_id in object_ids
        and_value = event_vector_dict[event_i] .& event_vector_dict[event_k][object_id]
        or_value = event_vector_dict[event_i] .| event_vector_dict[event_k][object_id]
        
        and_event_values[object_id] = and_value 
        or_event_values[object_id] = or_value
      end

      if unique(vcat(map(id -> and_event_values[id], object_ids)...)) != [0]
        push!(compound_events, and_event)
        event_vector_dict[and_event] = and_event_values
      end

      if unique(vcat(map(id -> or_event_values[id], object_ids)...)) != [0]
        push!(compound_events, or_event)
        event_vector_dict[or_event] = or_event_values
      end

    end

  end

  # # @show length(nonzero_object_specific_events)
  for i in 1:length(nonzero_object_specific_events)
    # # @show i 
    # # # @show event_i
    event_i = nonzero_object_specific_events[i]
    object_ids_i = collect(keys(event_vector_dict[event_i]))
    for j in (i+1):length(nonzero_object_specific_events)
      event_j = nonzero_object_specific_events[j] 
      object_ids_j = collect(keys(event_vector_dict[event_j]))

      if Set(object_ids_i) == Set(object_ids_j)
        object_ids = object_ids_i
        and_event = "(& $(event_i) $(event_j))"
        or_event = "(| $(event_i) $(event_j))"
        and_event_values = Dict()
        or_event_values = Dict()
  
        for object_id in object_ids 
          and_value = event_vector_dict[event_i][object_id] .& event_vector_dict[event_j][object_id]
          or_value = event_vector_dict[event_i][object_id] .| event_vector_dict[event_j][object_id]
          
          and_event_values[object_id] = and_value 
          or_event_values[object_id] = or_value
        end
  
        if unique(vcat(map(id -> and_event_values[id], object_ids)...)) != [0]
          push!(compound_events, and_event)
          event_vector_dict[and_event] = and_event_values
        end
  
        if unique(vcat(map(id -> or_event_values[id], object_ids)...)) != [0]
          push!(compound_events, or_event)
          event_vector_dict[or_event] = or_event_values
        end
      end
    end
  end

  # # compute depth-3 events just with color selector events, to get around limitation of parsing (i.e. in non-singlecell mode, objects with same shape
  # # but different colors are the same type, even though we may like them to be different types)
  # object_types, _, _, _ = object_decomposition 
  # object_types_with_color = filter(t -> t.custom_fields != [] && t.custom_fields[1][1] == "color", object_types)
  # color_selector_events = vcat(map(t -> map(color -> """(intersects (list "$(color)") (map (--> obj (.. obj color)) (filter (--> obj (== (.. obj id) x)) (prev addedObjType$(t.id)List))))""", 
  #                                           filter(f -> f[1] == "color", t.custom_fields)[1][3]), 
  #                                  object_types_with_color)...) 

  # color_compound_events = []
  # for color_event in color_selector_events
  #   color_event_values = event_vector_dict[color_event]
  #   object_ids = collect(keys(color_event_values))
  #   for compound_event in compound_events 
  #     if event_vector_dict[compound_event] isa AbstractArray 
  #       compound_event_value = event_vector_dict[compound_event] 
  
  #       and_event = "(& $(color_event) $(compound_event))" 
  #       or_event = "(| $(color_event) $(compound_event))"
  
  #       and_values = Dict()
  #       or_values = Dict() 
        
  #       for object_id in object_ids
  #         and_values[object_id] = compound_event_value .& color_event_values[object_id]
  #         or_values[object_id] = compound_event_value .| color_event_values[object_id]
  #       end  
  #     else 
  #       compound_event_values = event_vector_dict[compound_event] 
  
  #       and_event = "(& $(color_event) $(compound_event))" 
  #       or_event = "(| $(color_event) $(compound_event))"
  
  #       and_values = Dict()
  #       or_values = Dict() 
        
  #       for object_id in object_ids
  #         and_values[object_id] = compound_event_values[object_id] .& color_event_values[object_id]
  #         or_values[object_id] = compound_event_values[object_id] .| color_event_values[object_id]
  #       end  
  #     end

  #     if unique(vcat(map(id -> and_values[id], object_ids)...)) != [0]
  #       push!(color_compound_events, and_event)
  #       event_vector_dict[and_event] = and_values
  #     end

  #     if unique(vcat(map(id -> or_values[id], object_ids)...)) != [0]
  #       push!(color_compound_events, or_event)
  #       event_vector_dict[or_event] = or_values
  #     end

  #   end
  # end
  # push!(compound_events, color_compound_events)

  # remove duplicate events that are observationally equivalent
  # println("here i am!")
  event_vector_dict, redundant_events_set = prune_by_observational_equivalence(event_vector_dict, redundant_events_set)
  # println("and here?")
  # println("END construct_compound_events")
  sort(collect(keys(event_vector_dict)), by=length)
end

function prune_by_observational_equivalence(event_vector_dict, redundant_events_set)
  all_values = Set(values(event_vector_dict))
  events = sort(collect(keys(event_vector_dict)), by=length)
  values_to_events = Dict()
  for event in events 
    event_values = event_vector_dict[event]
    if event_values in all_values 
      delete!(all_values, event_values)
      values_to_events[event_values] = [event] 
    else
      if event == "(in true (map (--> obj (isFree (.. (moveRight (prev obj)) origin))) (filter (--> obj (== (.. obj id) x)) (prev addedObjType2List))))"
        # println("WTF")
        # @show values_to_events[event_values]
        # @show event_values 
        # @show values_to_events
      end
      existing_events = values_to_events[event_values]
      if (occursin("globalVar", event) && foldl(|, map(e -> occursin("globalVar", e), existing_events))) || (!occursin("globalVar", event) && !foldl(|, map(e -> occursin("globalVar", e), existing_events)))
        delete!(event_vector_dict, event)
        push!(redundant_events_set, event)
      else
        push!(values_to_events[event_values], event)
      end
    end
  end
  event_vector_dict, redundant_events_set
end