include("scene.jl")
include("dynamics.jl")

function generateprogram(rng=Random.GLOBAL_RNG; gridsize::Int=16)
  # generate objects and types 
  types, objects, background, _ = generatescene_objects(rng, gridsize=gridsize)



  # construct environment object
  environment = Dict(["custom_types" => Dict(
                                             map(t -> "Object_ObjType$(t.id)" => [("color", "String")], types) 
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
end