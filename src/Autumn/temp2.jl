# built-in Autumn types: Int, Bool, Cell, Position, Click

# RETURN TYPE: OBJECT
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

# RETURN TYPE: INT
"""
function distance(position1::Position, position2::Position)::Int
function distance(object1::Object, object2::Object)::Int
function distance(object::Object, position::Position)::Int  
"""

# RETURN TYPE: BOOL
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
