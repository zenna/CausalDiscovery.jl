using Random

"""
> genObject("object1", [])
"""

function genObject(object, environment)
  prob = rand()
  object = "(prev $(object))"
  if prob < 0.5
    object
  else
    choices = [
      ("moveLeft", [object]),
      ("moveRight", [object]),
      ("moveUp", [object]),
      ("moveDown", [object]),
      ("moveNoCollision", [object, :(genInt($(environment))), :(genInt($(environment)))]),
      ("nextLiquid", [object]),
      ("nextSolid", [object]),
      ("rotate", [object]),
      ("rotateNoCollision", [object]),
    ]
    choice = choices[rand(1:length(choices))]
    "($(choice[1]) $(join(map(eval, choice[2]), " ")))"
  end
end

"""
function objClicked(click::Union{Click, Nothing}, objects::AbstractArray)::Object
function removeObj(obj::Object)::Object
function updateObj(obj::Object, field::String, value)::Object
function rotate(object::Object)::Object
function rotateNoCollision(object::Object)::Object
function move(object::Object, position::Position)::Object
function move(object::Object, x::Int, y::Int)::Object
function moveLeft(object::Object)::Object
function moveRight(object::Object)::Object
function moveUp(object::Object)::Object
function moveDown(object::Object)::Object
function moveNoCollision(object::Object, position::Position)::Object
function moveNoCollision(object::Object, x::Int, y::Int)
function moveLeftNoCollision(object::Object)::Object
function moveRightNoCollision(object::Object)::Object
function moveUpNoCollision(object::Object)::Object
function moveDownNoCollision(object::Object)::Object
function moveWrap(object::Object, position::Position)::Object
function moveLeftWrap(object::Object)::Object
function moveRightWrap(object::Object)::Object
function moveUpWrap(object::Object)::Object
function moveDownWrap(object::Object)::Object
function nextLiquid(object::Object)::Object 
function nextSolid(object::Object)::Object 
"""


# built-in Autumn types: Int, Bool, Cell, Position, Click

function genInt(environment)
  rand(1:5)
end
"""
function distance(position1::Position, position2::Position)::Int
function distance(object1::Object, object2::Object)::Int
function distance(object::Object, position::Position)::Int  
"""

function genBool(environment)
  options = [
    "",
    "",
    "",
    ""
  ]
  options[rand(1:length(options))]
end
"""
function isWithinBounds(obj::Object)::Bool
function clicked(click::Union{Click, Nothing}, object::Object)::Bool
function clicked(click::Union{Click, Nothing}, objects::AbstractArray)::Bool
function clicked(click::Union{Click, Nothing}, x::Int, y::Int)::Bool
function clicked(click::Union{Click, Nothing}, pos::Position)::Bool
function intersects(obj1::Object, obj2::Object)::Bool
function intersects(obj1::Object, obj2::Array{<:Object})::Bool
function intersects(list1, list2)::Bool
function intersects(object::Object)::Bool
function isWithinBounds(position::Position)::Bool
function isFree(position::Position)::Bool
function isFree(click::Union{Click, Nothing})::Bool
function adjacent(position1::Position, position2::Position)::Bool
function adjacent(cell1::Cell, cell2::Cell)::Bool
        
"""

function genCell(environment)
  options = [
    "",
    "",
    "",
    ""
  ]
  options[rand(1:length(options))]
end

function genPosition(environment)
  options = [
    "",
    "",
    "",
    ""
  ]
  options[rand(1:length(options))]
end

function genClick(environment)
  options = [
    "",
    "",
    "",
    ""
  ]
  options[rand(1:length(options))]
end
