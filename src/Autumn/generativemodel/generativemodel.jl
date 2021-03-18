include("scene.jl")
include("dynamics.jl")

function generateprogram(rng=Random.GLOBAL_RNG; gridsize::Int=16)
  # generate objects and types 
  types, objects, background, _ = generatescene_objects(rng, gridsize=gridsize)

  # construct environment object
  environment = Dict(["custom_types" => Dict(
                                             map(t -> "Object_ObjType$(t[2])" => [("color", "String")], types) 
                                            ),
                      "variables" => Dict(
                                          map(obj -> "obj$(obj[4])" => "Object_ObjType$(obj[1][2])", objects)                    
                                         )])
  
  # generate next values for each object
  next_vals = map(obj -> genObjectUpdateRule("obj$(obj[4])", environment), objects)
  objects = [(objects[i]..., (next_vals[i],)...) for i in 1:length(objects)]

  # generate on-clauses
  on_clause_object_ids = rand(1:length(objects), rand(1:10))
  on_clauses = map(i -> (genBool(environment), genObjectUpdateRule("obj$(i)", environment), i), on_clause_object_ids)

  """
  (program
    (= GRID_SIZE $(gridsize))
    (= background "$(background)")
    $(join(map(t -> "(object ObjType$(t[2]) (: color String) (list $(join(map(cell -> "(Cell $(cell[1]) $(cell[2]) color)", t[1]), " "))))", types), "\n  "))

    $((join(map(obj -> """(: obj$(obj[4]) ObjType$(obj[1][2]))""", objects), "\n  "))...)

    $((join(map(obj -> 
    """(= obj$(obj[4]) (initnext (ObjType$(obj[1][2]) "$(obj[3])" (Position $(obj[2][1] - 1) $(obj[2][2] - 1))) $(obj[5])))""", objects), "\n  ")))

    $((join(map(tuple -> 
    """(on $(tuple[1])\n    (= obj$(tuple[3]) $(tuple[2])))""", on_clauses), "\n  "))...)
  )
  """
end