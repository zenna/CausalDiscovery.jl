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

# -----begin object generator + helper functions ----- #
function genObject(environment; p=0.9)
  object = genObjectName(environment)
  genObjectUpdateRule(object, environment, p=p)
end

function genObjectName(environment)
  objects = filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))
  objects[rand(1:length(objects))]
end

function genObjectUpdateRule(object, environment; p=0.7)
  prob = rand()
  if prob < p
    if object == "obj"
      "$(object)"
    else
      "(prev $(object))"
    end
  else
    choices = [
      ("moveLeftNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("moveRightNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("moveUpNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("moveDownNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("moveNoCollision", [:(genObjectUpdateRule($(object), $(environment))), :(genPosition($(environment)))]),
      ("nextLiquid", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("nextSolid", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("rotate", [:(genObjectUpdateRule($(object), $(environment)))]),
      ("rotateNoCollision", [:(genObjectUpdateRule($(object), $(environment)))]),
    ]
    choice = choices[rand(1:length(choices))]
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
  end
end

# ----- end object generator + helper functions ----- #

# ----- Int generator ----- # 
function genInt(environment)
  rand(1:5)
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
  ]
  if length(filter(var -> occursin("Object_", environment["variables"][var]), collect(keys(environment["variables"])))) > 0
    push!(choices, [("clicked", [:(genObject($(environment), p=1.0))]),
                    ("intersects", [:(genObject($(environment), p=1.0)), :(genObject($(environment), p=1.0))]),
                    ("isWithinBounds", [:(genObject($(environment)))])
                   ]...)
  end
  choice = choices[rand(1:length(choices))]
  if (length(choice[2]) == 0)
    "$(choice[1])"
  else
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
  end 

end

# ----- Position generator ----- #
function genPosition(environment)
  choices = [
    ("Position", [:(genInt($(environment))), :(genInt($(environment)))]),
    ("displacement", [:(genPosition($(environment))), :(genPosition($(environment)))]),
    ("unitVector", [:(genPosition($(environment)))]),
    ("uniformChoice", [:(genPositionList($(environment)))])
  ]
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
  constructor = map(tuple -> Meta.parse("gen$(tuple[2])($(environment))"), environment["custom_types"][string("Object_",type)])
  push!(constructor, :(genPosition($(environment))))
  "($(type) $(join(map(eval, constructor), " ")))"
end

function genObjectListUpdateRule(object_list, environment; p=0.7)
  prob = rand()
  if prob < p
    "(prev $(object_list))"
  else
    choices = [
      ("addObj", 
        [:(genObjectListUpdateRule($(object_list), $(environment))), 
         :(genObjectConstructor($(String(split(environment["variables"][object_list], "_")[2])), $(environment))),
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