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

    println(length(types))
    println(length(objects))

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

function generate_hypothesis_update_rule(object, object_decomposition; p=0.3)
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

function generate_hypothesis_position(position, environment_vars)
  objects = map(obj -> "obj$(obj.id)", filter(x -> x isa Obj, environment_vars))
  user_event = filter(x -> !(x isa Obj), environment_vars)[1]
  @show environment_vars
  choices = []
  # if length(objects) != 0
  #   push!(choices, ["(.. $(rand(objects)) origin)",
  #                   "(move (.. $(rand(objects)) origin) (Position $(rand(0:1)) $(rand(0:1))))"]...)
  # end

  if !isnothing(user_event) && (occursin("click", split(user_event, " ")[1])) 
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
  @show string
  @show objects
  x = filter(type -> length(type.custom_fields) > 0 && string in type.custom_fields[1][3], object_types)
  @show x
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

function gen_event_bool(object_decomposition, object_id, user_events, global_var_dict)
  choices = ["true", "left", "right", "(& clicked (isFree click))", "up", "down"] # "left", "right", "up", "down" "(& clicked (isFree click))", "up", "down"
  object_types, object_mapping, _, _ = object_decomposition
  environment_vars = map(k -> object_mapping[k][1], filter(key -> !isnothing(object_mapping[key][1]), collect(keys(object_mapping))))
  non_list_objects = filter(x -> count(y -> y.type.id == x.type.id, environment_vars) == 1, environment_vars)

  user_events = filter(e -> (e != "") && (e != "nothing"), user_events)
  user_event = filter(x -> !isnothing(x), user_events) == [] ? nothing : filter(x -> !isnothing(x), user_events)[1]
  # if !isnothing(user_event) && !occursin("click", user_event)
  #   push!(choices, user_event)
  # end

  type_id = filter(x -> !isnothing(x), object_mapping[object_id])[1].type.id
  other_object_types = filter(type -> type.id != type_id, object_types)  

  # if length(non_list_objects) > 0
  #   object = rand(non_list_objects)
  #   if length(object.type.custom_fields) > 0
  #     color = object.type.custom_fields[1][3][rand(1:2)]
  #     push!(choices, """(== (.. obj$(object.id) color) "$(color)")""")    
  #   end
  #   push!(choices, """(intersects (prev obj$(object.id)) (prev addedObjType$(rand(other_object_types).id)List))""")
  # end

  # if length(other_object_types) > 0 && !(object_id in map(x -> x.id, non_list_objects))
  #   push!(choices, "(intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)) (list $(join(map(x -> "(prev obj$(x.id))", non_list_objects), " "))))")
  #   push!(choices, "(intersects (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)) (prev addedObjType$(rand(other_object_types).id)List))")  
  # end

  # push!(choices, "(== (% (prev time) 10) 5)")
  # push!(choices, "(== (% (prev time) 10) 0)")  
  # push!(choices, "(== (% (prev time) 5) 2)")

  push!(choices, "(== (% (prev time) 4) 2)")

  # # if "clicked" in user_events
  # push!(choices, "(& clicked (== (prev addedObjType$(type_id)List) (list)))")
  # push!(choices, "(& clicked (!= (prev addedObjType$(type_id)List) (list)))")
  # # end

  color_fields = filter(tuple -> tuple[1] == "color", filter(t -> t.id == type_id, object_types)[1].custom_fields)
  if color_fields != [] && !(object_id in map(x -> x.id, non_list_objects))
    colors = color_fields[1][3]
    push!(choices, """(intersects (adjacentObjs (first (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)))) (filter (--> obj (== (.. obj color) "$(rand(colors))")) (prev addedObjType$(type_id)List)))""")
  end


  non_color_fields = filter(tuple -> tuple[1] != "color", filter(t -> t.id == type_id, object_types)[1].custom_fields)
  if (non_color_fields != [])
    tuple = non_color_fields[1]
    field_name = tuple[1]
    field_values = tuple[3]
    push!(choices, "(& $(rand(["left", "right", "up", "down"])) (== (.. (first (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))) $(field_name)) $(rand(field_values))))")
    
  end

  # if length(collect(keys(global_var_dict))) != 0
  #   values = unique(global_var_dict[1])
  #   push!(choices, "(& (& clicked (isFree click)) (== (prev globalVar1) $(rand(values))))")
  #   if (user_event != "nothing") && !(occursin("click", user_event))
  #     push!(choices, "(& $(user_event) (== (prev globalVar1) $(rand(values))))")
  #   end
  #   push!(choices, "(== (prev globalVar1) $(rand(values)))")
  # end

  # if non_list_objects != []
  #   object = rand(non_list_objects)
  #   push!(choices, "(clicked (prev obj$(object.id)))")
  # end

  # for type in object_types 
  #   if (length(type.custom_fields) > 0) && type.custom_fields[1][1] == "color" 
  #     color_values = type.custom_fields[1][3]
  #     push!(choices, """(clicked (filter (--> obj (== (.. obj color) "$(rand(color_values))")) (prev addedObjType$(type.id)List)))""")
  #   end
  # end
  
  push!(choices, "(& (clicked (prev addedObjType$(type_id)List)) (in (objClicked click (prev addedObjType$(type_id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List))))")
  push!(choices, "(& (clicked (prev addedObjType$(type_id)List)) (! (in (objClicked click (prev addedObjType$(type_id)List)) (filter (--> obj (== (.. obj id) $(object_id))) (prev addedObjType$(type_id)List)))))")

  choice = rand(choices)
  println("XYZ")
  println(object_id)
  print(choices)
  println(choice)
  choice
end