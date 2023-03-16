using Random

"""
Example Use:
> genObject("object1", env)
"""

env = Dict(["custom_types" => Dict([
            "Object1" => [],
            "Object2" => [],
            "Object3" => [],              
            ]),
            "variables" => Dict([
              "object1" => "Object_Object2",
              "object2" => "Object_Object3",
              "objectlist1" => "ObjectList_Object3",
            ])])

function genUpdateRule(var, environment; p=0.7)
  if environment["variables"][var] == "Int"
    genInt(environment)
  elseif environment["variables"][var] == "Bool"
    genBoolUpdateRule(var, environment)
  elseif occursin("Object_", environment["variables"][var])
    genObjectUpdateRule(var, environment, p=p)
  else
    genObjectListUpdateRule(var, environment, p=p)
  end
end

# -----begin object generator + helper functions ----- #
function genObject(environment; p=0.9)
  object = genObjectName(environment)
  genObjectUpdateRule(object, environment, p=p)
end

function genObjectName(environment)
  objects = filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))
  objects[rand(1:length(objects))]
end

function genObjectUpdateRule(object, environment; p=0.0)
  prob = rand()
  if prob < p
    if object == "obj"
      "$(object)"
    else
      "(prev $(object))"
    end
  else
    
    choices = [
      # "(moveLeft $(object))",
      # ("moveLeft", [:(genObjectUpdateRule($(object), $(environment), p=0.9))]),
      # ("moveRight", [:(genObjectUpdateRule($(object), $(environment), p=0.9))]),
      # ("moveUp", [:(genObjectUpdateRule($(object), $(environment), p=0.9))]),
      # ("moveDown", [:(genObjectUpdateRule($(object), $(environment), p=0.9))]),
      # ("moveNoCollision", [:(genObjectUpdateRule($(object), $(environment))), :(genPosition($(environment)))]),
      # ("nextLiquid", [:(genObjectUpdateRule($(object), $(environment)))]),
      # ("nextSolid", [:(genObjectUpdateRule($(object), $(environment)))]),
      # ("rotate", [:(genObjectUpdateRule($(object), $(environment)))]),
      # ("rotateNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
    ]
    other_types = filter(type -> type != environment["variables"][object], collect(keys(environment["custom_types"])))
    if length(other_types) > 0
      push!(choices, "(move $(object) (unitVector $(object) (closest $(object) $(split(rand(other_types), "_")[2]))))")
    end
    choice = choices[rand(1:length(choices))]
    # "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
    choice
  end
end

# ----- end object generator + helper functions ----- #

# ----- Int generator ----- # 
function genInt(environment)
  int_vars = map(v -> "(prev $(v))", filter(var -> environment["variables"][var] == "Int", collect(keys(environment["variables"]))))
  choices = [ #= fieldsFromCustomTypes("Int", environment)..., =# collect(1:5)..., int_vars...]
  choice = rand(choices)
  if (choice isa String) || (choice isa Int)
    choice
  else
    @show "($(choice[1]) $(join(map(eval, choice[2]), " ")))"  
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"      
  end
end

# ----- Bool generator ----- #
function genBool(environment)
  choices = [
    ("clicked", []),
    ("clicked", [:(genPosition($(environment)))]),
    ("left", []),
    ("right", []),
    ("up", []),
    ("down", []),
    ("true", []), # TODO: add not, or, and -- need to be able to specify prior probabilities 
  ]
  if length(filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))) > 0
    push!(choices, [("clicked", [:(genObject($(environment), p=1.0))]),
                    ("intersects", [:(genObject($(environment), p=1.0)), :(genObject($(environment), p=1.0))]),
                    ("isWithinBounds", [:(genObject($(environment)))])
                   ]...)
  end

  bool_vars = map(v -> "(prev $(v))", filter(var -> environment["variables"][var] == "Bool", collect(keys(environment["variables"]))))
  foreach(var -> push!(choices, (var, [])), bool_vars)

  push!(choices, fieldsFromCustomTypes("Bool", environment)...)

  choice = choices[rand(1:length(choices))]
  if (length(choice[2]) == 0)
    "$(choice[1])"
  else
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
  end 

end

function genBoolUpdateRule(bool, environment)
  bool_val = "(prev $(bool))"
  rand(["(! $(bool_val))", bool_val])
end

# ----- Position generator ----- #
function genPosition(environment)
  choices = [
    ("Position", [:(genInt($(environment))), :(genInt($(environment)))]),
    ("displacement", [:(genPosition($(environment))), :(genPosition($(environment)))]),
    ("unitVector", [:(genPosition($(environment)))]),
    ("uniformChoice", [:(genPositionList($(environment)))])
  ]
  # if object constants exist, add support for (.. obj origin)
  if length(filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))) > 0
    push!(choices, ("..", [:(genObject($(environment), p=1.0)), :(String("origin"))]))    
  end

  choice = choices[rand(1:length(choices))]
  "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
end

# ----- Click generator ----- #
function genClick(environment)
  options = [
    "click"
  ]
  choice = choices[rand(1:length(choices))]
  "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
end

# ----- Position List generator ----- #
function genPositionList(environment)
  choices = [
    ("randomPositions", ["GRID_SIZE", :(genInt($(environment)))])
  ]
  if length(filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))) > 0
    push!(choices, ("adjPositions", [:(genObject($(environment)))]))
  end
  choice = choices[rand(1:length(choices))]
  "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
end

# ----- begin object list generator + helper functions ----- #
function genObjectList(environment)
  object_list = genObjectListName(environment)
  genObjectListUpdateRule(object_list, environment)
end

function genObjectListName(environment)
  object_lists = filter(var -> occursin("ObjectList_", environment["variables"][var]), collect(keys(environment["variables"])))
  object_lists[rand(1:length(object_lists))]
end

function genObjectConstructor(type, environment)
  new_type = occursin("_", type) ? type : string("Object_", type)
  constructor = map(tuple -> Meta.parse("gen$(tuple[2])($(environment))"), environment["custom_types"][new_type])
  push!(constructor, :(genPosition($(environment))))
  "($(type) $(join(map(eval, constructor), " ")))"
end

function genObject(type, environment, p=0.9)
  objects_with_type = filter(var -> environment["variables"][var] == type, collect(keys(environment["variables"])))
  prob = rand()
  if (prob < p) && length(objects_with_type) != 0
    rand(objects_with_type)
  else
    constructor = genObjectConstructor(type, environment)
    constructor 
  end
end

function genObjectListUpdateRule(object_list, environment; p=0.7)
  prob = rand()
  if prob < p
    "(prev $(object_list))"
  else
    choices = [
      ("addObj", 
        [:(genObjectListUpdateRule($(object_list), $(environment))), 
         :(genObjectConstructor($(String(split(environment["variables"][object_list], "_")[end])), $(environment))),
        ]
      ),
      ("updateObj", 
        [:(genObjectListUpdateRule($(object_list), $(environment))),
         :(genLambda($(environment)))
        ]),
    ]
    choice = choices[rand(1:length(choices))]
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
  end
end

function genLambda(environment)
  choice = ("-->", [:(String("obj")), :(genObjectUpdateRule("obj", $(environment)))])
  "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
end
# ----- end object list generator + helper functions ----- #

# ----- string generator ----- #
function genString(environment)
  colors = ["red", "yellow", "green", "blue"]
  color = colors[rand(1:length(colors))]
  """ "$(color)" """
end

# ----- helper functions ----- #

function fieldsFromCustomTypes(fieldtype::String, environment)
  branches = []
  types_with_field = filter(type -> fieldtype in map(tuple -> tuple[2], environment["custom_types"][type]), collect(keys(environment["custom_types"])))
  for type in types_with_field
    fieldnames = map(t -> t[1], filter(tuple -> tuple[2] == fieldtype, environment["custom_types"][type]))
    if length(filter(var -> environment["variables"][var] == type, collect(keys(environment["variables"])))) > 0  
      foreach(fieldname -> push!(branches, ("..", [Meta.parse("genObject(\"$(split(type, "_")[end])\", $(environment))"), :(String($(fieldname)))])), fieldnames)
    end
  end
  branches
end