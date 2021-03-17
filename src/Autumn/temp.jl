"""
# start at line 394

"""
function isWithinBounds(obj::Object)::Bool
function clicked(click::Union{Click, Nothing}, object::Object)::Bool
function clicked(click::Union{Click, Nothing}, objects::AbstractArray)::Bool
function objClicked(click::Union{Click, Nothing}, objects::AbstractArray)::Object
function clicked(click::Union{Click, Nothing}, x::Int, y::Int)::Bool
function clicked(click::Union{Click, Nothing}, pos::Position)::Bool
function intersects(obj1::Object, obj2::Object)::Bool
function intersects(obj1::Object, obj2::Array{<:Object})::Bool
function intersects(list1, list2)::Bool
function intersects(object::Object)::Bool
function addObj(list::Array{<:Object}, obj::Object)
function addObj(list::Array{<:Object}, objs::Array{<:Object})
function removeObj(list::Array{<:Object}, obj::Object)
function removeObj(list::Array{<:Object}, fn)::Object
function removeObj(obj::Object)::Object
function updateObj(obj::Object, field::String, value)::Object
function filter_fallback(obj::Object)
function updateObj(list::Array{<:Object}, map_fn, filter_fn=filter_fallback)
function adjPositions(position::Position)::Array{Position}
function isWithinBounds(position::Position)::Bool
function isFree(position::Position)::Bool
function isFree(click::Union{Click, Nothing})::Bool
function unitVector(position1::Position, position2::Position)::Position
function unitVector(object1::Object, object2::Object)::Position
function unitVector(object::Object, position::Position)::Position
function unitVector(position::Position, object::Object)::Position
function unitVector(position::Position)::Position
function displacement(position1::Position, position2::Position)::Position
function displacement(cell1::Cell, cell2::Cell)::Position
function adjacent(position1::Position, position2::Position)::Bool
function adjacent(cell1::Cell, cell2::Cell)::Bool
function adjacent(cell::Cell, cells::Array{Cell})
function rotate(object::Object)::Object
function rotate(position::Position)::Position
function rotateNoCollision(object::Object)::Object
function move(position1::Position, position2::Position)
function move(cell::Cell, position::Position)
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
function moveWrap(cell::Cell, position::Position)
function moveWrap(position::Position, cell::Cell)
function moveWrap(object::Object, x::Int, y::Int)::Object
function moveWrap(position1::Position, position2::Position)::Position
function moveWrap(position::Position, x::Int, y::Int)::Position
function moveLeftWrap(object::Object)::Object
function moveRightWrap(object::Object)::Object
function moveUpWrap(object::Object)::Object
function moveDownWrap(object::Object)::Object
function randomPositions(GRID_SIZE::Int, n::Int)::Array{Position}
function distance(position1::Position, position2::Position)::Int
function distance(object1::Object, object2::Object)::Int
function distance(object::Object, position::Position)::Int
function closest(object::Object, type::DataType)::Position
function mapPositions(constructor, GRID_SIZE::Int, filterFunction, args...)::Union{Object, Array{<:Object}}
function allPositions(GRID_SIZE::Int)
function updateOrigin(object::Object, new_origin::Position)::Object
function updateAlive(object::Object, new_alive::Bool)::Object
function nextLiquid(object::Object)::Object 
function nextSolid(object::Object)::Object 
function allPositions()