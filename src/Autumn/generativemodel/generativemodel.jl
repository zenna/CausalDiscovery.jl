include("scene.jl")
include("dynamics.jl")

function generateprogram(rng=Random.GLOBAL_RNG; gridsize::Int=16, group::Bool=false)
  # generate objects and types 
  types, objects, background, _ = generatescene_objects(rng, gridsize=gridsize)

  if (!group)
    # construct environment object
    environment = Dict(["custom_types" => Dict(
                                              map(t -> "Object_ObjType$(t.id)" => [], types) 
                                              ),
                        "variables" => Dict(
                                            map(obj -> "obj$(obj.id)" => "Object_ObjType$(obj.type.id)", objects)                    
                                          )])
    
    # generate next values for each object
    next_vals = map(obj -> genObjectUpdateRule("obj$(obj.id)", environment), objects)
    objects = [(objects[i], next_vals[i]) for i in 1:length(objects)]

    # generate on-clauses
    on_clause_object_ids = rand(1:length(objects), rand(1:length(objects)))
    on_clauses = map(i -> (genBool(environment), genObjectUpdateRule("obj$(i)", environment), i), on_clause_object_ids)

    """
    (program
      (= GRID_SIZE $(gridsize))
      (= background "$(background)")
      $(join(map(t -> "(object ObjType$(t.id) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

      $((join(map(obj -> """(: obj$(obj[1].id) ObjType$(obj[1].type.id))""", objects), "\n  "))...)

      $((join(map(obj -> 
      """(= obj$(obj[1].id) (initnext (ObjType$(obj[1].type.id) (Position $(obj[1].position[1] - 1) $(obj[1].position[2] - 1))) $(obj[2])))""", objects), "\n  ")))

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= obj$(tuple[3]) $(tuple[2])))""", on_clauses), "\n  "))...)
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
                                map(t -> "Object_ObjType$(t.id)" => [], types) 
                                ),
                        "variables" => Dict(
                              vcat(
                                map(id -> "objList$(findall(x -> x == id, list_type_ids)[1])" => "ObjectList_ObjType$(id)", list_type_ids)...,
                                map(id -> "obj$(findall(x -> x == id, constant_type_ids)[1])" => "Object_ObjType$(id)", constant_type_ids)       
                              )             
                            )])

    # generate next values and on-clauses for each object
    # lists
    if length(list_type_ids) != 0
      next_list_vals = map(id -> genObjectListUpdateRule("objList$(findall(x -> x == id, list_type_ids)[1])", environment), list_type_ids)

      on_clause_list_ids = rand(list_type_ids, rand(1:length(list_type_ids)))
      on_clauses_list = map(id -> (genBool(environment), genObjectListUpdateRule("objList$(findall(x -> x == id, list_type_ids)[1])", environment), findall(x -> x == id, list_type_ids)[1]), on_clause_list_ids)
    else
      next_list_vals = []
      on_clauses_list = []
    end

    # constants
    if length(constant_type_ids) != 0
      next_constant_vals = map(id -> genObjectUpdateRule("obj$(findall(x -> x == id, constant_type_ids)[1])", environment), constant_type_ids)
      
      on_clauses_constant_ids = rand(constant_type_ids, rand(1:length(constant_type_ids)))
      on_clauses_constant = map(id -> (genBool(environment), genObjectUpdateRule("obj$(findall(x -> x == id, constant_type_ids)[1])", environment), findall(x -> x == id, constant_type_ids)[1]), on_clauses_constant_ids)
    else
      next_constant_vals = []
      on_clauses_constant = []
    end

    """
    (program
      (= GRID_SIZE $(gridsize))
      (= background "$(background)")
      $(join(map(t -> "(object ObjType$(t.id) (list $(join(map(cell -> """(Cell $(cell[1]) $(cell[2]) "$(t.color)")""", t.shape), " "))))", types), "\n  "))

      $((join(map(id -> """(: objList$(findall(x -> x == id, list_type_ids)[1]) (List ObjType$(id)))""", list_type_ids), "\n  "))...)
      $((join(map(id -> """(: obj$(findall(x -> x == id, constant_type_ids)[1]) ObjType$(id))""", constant_type_ids), "\n  "))...)

      $((join(map(id -> 
      """(= objList$(findall(x -> x == id, list_type_ids)[1]) (initnext (list $(join(map(obj -> "(ObjType$(obj.type.id) (Position $(obj.position[1] - 1) $(obj.position[2] - 1)))", filter(o -> o.type.id == id, objects)), " "))) $(next_list_vals[findall(y -> y == id, list_type_ids)[1]])))""", list_type_ids), "\n  ")))

      $((join(map(id -> 
      """(= obj$(findall(x -> x == id, constant_type_ids)[1]) (initnext $(join(map(obj -> "(ObjType$(obj.type.id) (Position $(obj.position[1] - 1) $(obj.position[2] - 1)))", filter(o -> o.type.id == id, objects)))) $(next_constant_vals[findall(y -> y == id, constant_type_ids)[1]])))""", constant_type_ids), "\n  ")))

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= objList$(tuple[3]) $(tuple[2])))""", on_clauses_list), "\n  "))...)

      $((join(map(tuple -> 
      """(on $(tuple[1]) (= obj$(tuple[3]) $(tuple[2])))""", on_clauses_constant), "\n  "))...)
    )
    """
  end
end