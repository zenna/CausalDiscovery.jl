using Test
using CausalDiscovery
using Random
using MLStyle
import Base.Cartesian.lreplace

abstract type Object end
abstract type KeyPress end

struct Left <: KeyPress end
struct Right <: KeyPress end
struct Up <: KeyPress end
struct Down <: KeyPress end

struct Click
  x::Int
  y::Int
end

mutable struct Position
  x::Int
  y::Int
end

struct Cell
  position::Position
  color::String
  opacity::Float64
end

Cell(position::Position, color::String) = Cell(position, color, 0.8)
Cell(x::Int, y::Int, color::String) = Cell(Position(floor(Int, x), floor(Int, y)), color, 0.8)
Cell(x::Int, y::Int, color::String, opacity::Float64) = Cell(Position(floor(Int, x), floor(Int, y)), color, opacity)

struct Scene
  objects::Array{Object}
  background::String
end

Scene(objects::AbstractArray) = Scene(objects, "#ffffff00")

function render(scene::Scene)::Array{Cell}
  vcat(map(obj -> render(obj), filter(obj -> obj.alive && !obj.hidden, scene.objects))...)
end

function render(obj::Object)::Array{Cell}
  map(cell -> Cell(move(cell.position, obj.origin), cell.color), obj.render)
end

function isWithinBounds(obj::Object)::Bool
  # println(filter(cell -> !isWithinBounds(cell.position),render(obj)))
  length(filter(cell -> !isWithinBounds(cell.position), render(obj))) == 0
end

function clicked(click::Union{Click, Nothing}, object::Object)::Bool
  if click == nothing
    false
  else
    GRID_SIZE = state.GRID_SIZEHistory[0]
    nums = map(cell -> GRID_SIZE*cell.position.y + cell.position.x, render(object))
    (GRID_SIZE * click.y + click.x) in nums
  end
end

function clicked(click::Union{Click, Nothing}, objects::AbstractArray)
  # println("LOOK AT ME")
  # println(reduce(&, map(obj -> clicked(click, obj), objects)))
  reduce(|, map(obj -> clicked(click, obj), objects))
end

function objClicked(click::Union{Click, Nothing}, objects::AbstractArray)::Object
  println(click)
  filter(obj -> clicked(click, obj), objects)[1]
end

function clicked(click::Union{Click, Nothing}, x::Int, y::Int)::Bool
  if click == nothing
    false
  else
    click.x == x && click.y == y
  end
end

function clicked(click::Union{Click, Nothing}, pos::Position)::Bool
  if click == nothing
    false
  else
    click.x == pos.x && click.y == pos.y
  end
end

function intersects(obj1::Object, obj2::Object)::Bool
  nums1 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj1))
  nums2 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj2))
  length(intersect(nums1, nums2)) != 0
end

function intersects(obj1::Object, obj2::Array{<:Object})::Bool
  nums1 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, render(obj1))
  nums2 = map(cell -> state.GRID_SIZEHistory[0]*cell.position.y + cell.position.x, vcat(map(render, obj2)...))
  length(intersect(nums1, nums2)) != 0
end

function intersects(list1, list2)::Bool
  length(intersect(list1, list2)) != 0
end

function intersects(object::Object)::Bool
  objects = state.scene.objects
  intersects(object, objects)
end

function addObj(list::Array{<:Object}, obj::Object)
  new_list = vcat(list, obj)
  new_list
end

function addObj(list::Array{<:Object}, objs::Array{<:Object})
  new_list = vcat(list, objs)
  new_list
end

function removeObj(list::Array{<:Object}, obj::Object)
  filter(x -> x.id != obj.id, list)
end

function removeObj(list::Array{<:Object}, fn)
  orig_list = filter(obj -> !fn(obj), list)
end

function removeObj(obj::Object)
  obj.alive = false
  deepcopy(obj)
end

function updateObj(obj, field::String, value)
  println(updateObj)
  fields = fieldnames(typeof(obj))
  custom_fields = fields[5:end-1]
  origin_field = (fields[2],)

  constructor_fields = (custom_fields..., origin_field...)
  constructor_values = map(x -> x == Symbol(field) ? value : getproperty(obj, x), constructor_fields)

  new_obj = typeof(obj)(constructor_values...)
  setproperty!(new_obj, :id, obj.id)
  setproperty!(new_obj, :alive, obj.alive)
  setproperty!(new_obj, :hidden, obj.hidden)

  setproperty!(new_obj, Symbol(field), value)
  new_obj
end

function filter_fallback(obj::Object)
  true
end

Base.:(==)(a::Position, b::Position) = equalPosition(a, b)

function equalPosition(a, b)
  return a.x == b.x && a.y == b.y
end

function updateObj(list::Array{<:Object}, map_fn, filter_fn=filter_fallback)
  orig_list = filter(obj -> !filter_fn(obj), list)
  filtered_list = filter(filter_fn, list)
  new_filtered_list = map(map_fn, filtered_list)
  vcat(orig_list, new_filtered_list)
end

function adjPositions(position::Position)::Array{Position}
  filter(isWithinBounds, [Position(position.x, position.y + 1), Position(position.x, position.y - 1), Position(position.x + 1, position.y), Position(position.x - 1, position.y)])
end

function isWithinBounds(position::Position)::Bool
  (position.x >= 0) && (position.x < state.GRID_SIZEHistory[0]) && (position.y >= 0) && (position.y < state.GRID_SIZEHistory[0])
end

function isFree(position::Position)::Bool
  length(filter(cell -> cell.position.x == position.x && cell.position.y == position.y, render(state.scene))) == 0
end

function isFree(click::Union{Click, Nothing})::Bool
  if click == nothing
    false
  else
    isFree(Position(click.x, click.y))
  end
end

function unitVector(position1::Position, position2::Position)::Position
  deltaX = position2.x - position1.x
  deltaY = position2.y - position1.y
  if (floor(Int, abs(sign(deltaX))) == 1 && floor(Int, abs(sign(deltaY))) == 1)
    uniformChoice([Position(sign(deltaX), 0), Position(0, sign(deltaY))])
  else
    Position(sign(deltaX), sign(deltaY))
  end
end

function unitVector(object1::Object, object2::Object)::Position
  position1 = object1.origin
  position2 = object2.origin
  unitVector(position1, position2)
end
function unitVector(object1, object2)::Position
  position1 = object1.origin
  position2 = object2.origin
  deltaX = position2.x - position1.x
  deltaY = position2.y - position1.y
  if (floor(Int, abs(sign(deltaX))) == 1 && floor(Int, abs(sign(deltaY))) == 1)
    uniformChoice([Position(sign(deltaX), 0), Position(0, sign(deltaY))])
  else
    Position(sign(deltaX), sign(deltaY))
  end
end

function unitVector(object::Object, position::Position)::Position
  unitVector(object.origin, position)
end

function unitVector(position::Position, object::Object)::Position
  unitVector(position, object.origin)
end

function unitVector(position::Position)::Position
  unitVector(Position(0,0), position)
end

function displacement(position1::Position, position2::Position)::Position
  Position(floor(Int, position2.x - position1.x), floor(Int, position2.y - position1.y))
end

function displacement(cell1::Cell, cell2::Cell)::Position
  displacement(cell1.position, cell2.position)
end

function adjacent(position1::Position, position2::Position):Bool
  displacement(position1, position2) in [Position(0,1), Position(1, 0), Position(0, -1), Position(-1, 0)]
end

function adjacent(cell1::Cell, cell2::Cell)::Bool
  adjacent(cell1.position, cell2.position)
end

function adjacent(cell::Cell, cells::Array{Cell})
  length(filter(x -> adjacent(cell, x), cells)) != 0
end

function rotate(object::Object)::Object
  new_object = deepcopy(object)
  new_object.render = map(x -> Cell(rotate(x.position), x.color), new_object.render)
  new_object
end

function rotate(position::Position)::Position
  Position(-position.y, position.x)
 end

function rotateNoCollision(object::Object)::Object
  (isWithinBounds(rotate(object)) && isFree(rotate(object), object)) ? rotate(object) : object
end

function move(position1::Position, position2::Position)
  Position(position1.x + position2.x, position1.y + position2.y)
end

function move(position::Position, cell::Cell)
  Position(position.x + cell.position.x, position.y + cell.position.y)
end

function move(cell::Cell, position::Position)
  Position(position.x + cell.position.x, position.y + cell.position.y)
end

function move(object::Object, position::Position)
  new_object = deepcopy(object)
  new_object.origin = move(object.origin, position)
  new_object
end

function move(object, position::Position)
  new_object = deepcopy(object)
  new_origin = move(Position(object.origin.x, object.origin.y), position)
  new_object.origin.x = new_origin.x
  new_object.origin.y = new_origin.y
    new_object
end

function move(object::Object, x::Int, y::Int)::Object
  move(object, Position(x, y))
end

function moveNoCollision(object::Object, position::Position)::Object
  (isWithinBounds(move(object, position)) && isFree(move(object, position.x, position.y), object)) ? move(object, position.x, position.y) : object
end

function moveNoCollision(object::Object, x::Int, y::Int)
  (isWithinBounds(move(object, x, y)) && isFree(move(object, x, y), object)) ? move(object, x, y) : object
end

function moveWrap(object::Object, position::Position)::Object
  new_object = deepcopy(object)
  new_object.position = moveWrap(object.origin, position.x, position.y)
  new_object
end

function moveWrap(cell::Cell, position::Position)
  moveWrap(cell.position, position.x, position.y)
end

function moveWrap(position::Position, cell::Cell)
  moveWrap(cell.position, position)
end

function moveWrap(object::Object, x::Int, y::Int)::Object
  new_object = deepcopy(object)
  new_object.position = moveWrap(object.origin, x, y)
  new_object
end

function moveWrap(position1::Position, position2::Position)::Position
  moveWrap(position1, position2.x, position2.y)
end

function moveWrap(position::Position, x::Int, y::Int)::Position
  GRID_SIZE = state.GRID_SIZEHistory[0]
  # println("hello")
  # println(Position((position.x + x + GRID_SIZE) % GRID_SIZE, (position.y + y + GRID_SIZE) % GRID_SIZE))
  Position((position.x + x + GRID_SIZE) % GRID_SIZE, (position.y + y + GRID_SIZE) % GRID_SIZE)
end

function randomPositions(GRID_SIZE::Int, n::Int)::Array{Position}
  nums = uniformChoice([0:(GRID_SIZE * GRID_SIZE - 1);], n)
  # println(nums)
  # println(map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums))
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end

function distance(position1::Position, position2::Position)::Int
  abs(position1.x - position2.x) + abs(position1.y - position2.y)
end

function distance(object1::Object, object2::Object)::Int
  position1 = object1.origin
  position2 = object2.origin
  distance(position1, position2)
end

function distance(object::Object, position::Position)::Int
  distance(object.origin, position)
end

function distance(position::Position, object::Object)::Int
  distance(object.origin, position)
end

function closest(object::Object, type::DataType)::Position
  objects_of_type = filter(obj -> (obj isa type) && (obj.alive), state.scene.objects)
  if length(objects_of_type) == 0
    object.origin
  else
    min_distance = min(map(obj -> distance(object, obj), objects_of_type))
    filter(obj -> distance(object, obj) == min_distance, objects_of_type)[1].origin
  end
end

function mapPositions(constructor, GRID_SIZE::Int, filterFunction, args...)::Union{Object, Array{<:Object}}
  map(pos -> constructor(args..., pos), filter(filterFunction, allPositions(GRID_SIZE)))
end

function allPositions(GRID_SIZE::Int)
  nums = [0:(GRID_SIZE * GRID_SIZE - 1);]
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end

function updateOrigin(object::Object, new_origin::Position)::Object
  new_object = deepcopy(object)
  new_object.origin = new_origin
  new_object
end

function updateAlive(object::Object, new_alive::Bool)::Object
  new_object = deepcopy(object)
  new_object.alive = new_alive
  new_object
end

function nextLiquid(object::Object)::Object
  # println("nextLiquid")
  GRID_SIZE = state.GRID_SIZEHistory[0]
  new_object = deepcopy(object)
  if object.origin.y != GRID_SIZE - 1 && isFree(move(object.origin, Position(0, 1)))
    new_object.origin = move(object.origin, Position(0, 1))
  else
    leftHoles = filter(pos -> (pos.y == object.origin.y + 1)
                               && (pos.x < object.origin.x)
                               && isFree(pos), allPositions())
    rightHoles = filter(pos -> (pos.y == object.origin.y + 1)
                               && (pos.x > object.origin.x)
                               && isFree(pos), allPositions())
    if (length(leftHoles) != 0) || (length(rightHoles) != 0)
      if (length(leftHoles) == 0)
        closestHole = closest(object, rightHoles)
        if isFree(move(closestHole, Position(0, -1)), move(object.origin, Position(1, 0)))
          new_object.origin = move(object.origin, unitVector(object, move(closestHole, Position(0, -1))))
        end
      elseif (length(rightHoles) == 0)
        closestHole = closest(object, leftHoles)
        if isFree(move(closestHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
          new_object.origin = move(object.origin, unitVector(object, move(closestHole, Position(0, -1))))
        end
      else
        closestLeftHole = closest(object, leftHoles)
        closestRightHole = closest(object, rightHoles)
        if distance(object.origin, closestLeftHole) > distance(object.origin, closestRightHole)
          if isFree(move(object.origin, Position(1, 0)), move(closestRightHole, Position(0, -1)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestRightHole, Position(0, -1))))
          elseif isFree(move(closestLeftHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestLeftHole, Position(0, -1))))
          end
        else
          if isFree(move(closestLeftHole, Position(0, -1)), move(object.origin, Position(-1, 0)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestLeftHole, Position(0, -1))))
          elseif isFree(move(object.origin, Position(1, 0)), move(closestRightHole, Position(0, -1)))
            new_object.origin = move(object.origin, unitVector(new_object, move(closestRightHole, Position(0, -1))))
          end
        end
      end
    end
  end
  new_object
end

function nextSolid(object::Object)::Object
  # println("nextSolid")
  GRID_SIZE = state.GRID_SIZEHistory[0]
  new_object = deepcopy(object)
  if (isWithinBounds(move(object, Position(0, 1))) && reduce(&, map(x -> isFree(x, object), map(cell -> move(cell.position, Position(0, 1)), render(object)))))
    new_object.origin = move(object.origin, Position(0, 1))
  end
  new_object
end

function closest(object::Object, positions::Array{Position})::Position
  closestDistance = sort(map(pos -> distance(pos, object.origin), positions))[1]
  closest = filter(pos -> distance(pos, object.origin) == closestDistance, positions)[1]
  closest
end

function isFree(start::Position, stop::Position)::Bool
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [(GRID_SIZE * start.y + start.x):(GRID_SIZE * stop.y + stop.x);]
  reduce(&, map(num -> isFree(Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE))), nums))
end

function isFree(start::Position, stop::Position, object::Object)::Bool
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [(GRID_SIZE * start.y + start.x):(GRID_SIZE * stop.y + stop.x);]
  reduce(&, map(num -> isFree(Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), object), nums))
end

function isFree(position::Position, object::Object)
  length(filter(cell -> cell.position.x == position.x && cell.position.y == position.y,
  filter(x -> !(x in render(object)), render(state.scene)))) == 0
end

function isFree(object::Object, orig_object::Object)::Bool
  reduce(&, map(x -> isFree(x, orig_object), map(cell -> cell.position, render(object))))
end

function allPositions()
  GRID_SIZE = state.GRID_SIZEHistory[0]
  nums = [1:GRID_SIZE*GRID_SIZE - 1;]
  map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums)
end

aexpr = au"""(program
  (= GRID_SIZE 16)

  (: broken Bool)
  (= broken (initnext false (prev broken)))

  (: suzie Int)
  (= suzie (initnext 1 (+ (prev suzie) 1)))

  (: billy Int)
  (= billy (initnext 0 (+ (prev billy) 1)))

  (: bottle Int)
  (= bottle (initnext 5 (prev bottle)))

  (on (== billy bottle) (= broken true))

  (on (== suzie bottle) (= broken true))

  )"""

  aexpr2 = au"""(program
    (= GRID_SIZE 16)

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (: suzie Int)
    (= suzie (initnext 1 (+ (prev suzie) 1)))

    (: billy Int)
    (= billy (initnext 0 (+ (prev billy) 1)))

    (: bottle Int)
    (= bottle (initnext 5 (prev bottle)))

    (on (== billy bottle) (= broken true))

    (on (== (- suzie bottle) 0) (= broken true))

    )"""

aexpr3 = au"""(program
  (= GRID_SIZE 16)

  (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))
  (object Billy (: timeTillThrow Integer) (Cell 0 0 "red"))

  (: suzieThrew Bool)
  (= suzieThrew (initnext false (prev suzieThrew)))

  (: suzie Suzie)
  (= suzie (initnext (Suzie 3 (Position 0 0))
    (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

  (: billy Billy)
  (= billy (initnext (Billy 4 (Position 0 15))
    (updateObj (prev billy) "timeTillThrow" (- (.. (prev billy) timeTillThrow) 1))))

  (on (== (.. suzie timeTillThrow) 0) (= suzieThrew true))
  (on (== (.. billy timeTillThrow) 0) (= billyThrew true))

  )"""

  aexpr4 = au"""(program
    (= GRID_SIZE 16)

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (object Rock (: moving Bool) (Cell 0 0 "blue"))


    (object Bottle (: broken Bool) (list (Cell 0 0 (if broken then "yellow" else "white"))
                                          (Cell 0 1 (if broken then "white" else "yellow"))
                                          (Cell 0 2 (if broken then "gray" else "yellow"))
                                          (Cell 0 3 (if broken then "white" else "yellow"))
                                          (Cell 0 4 (if broken then "yellow" else "white"))))

    (object BottleSpot (Cell 0 0 "white"))

    (: suzieRock Rock)
    (= suzieRock (initnext (Rock true (Position 0 7))
      (if (.. suzieRock moving) then (move (prev suzieRock) (unitVector (prev suzieRock) bottleSpot)) else (prev suzieRock))))


    (: bottleSpot BottleSpot)
    (= bottleSpot (initnext (BottleSpot (Position 15 7)) (prev bottleSpot)))

    (on (intersects bottleSpot suzieRock) (= broken true))

  )"""

  aexpr5 = au"""(program
    (= GRID_SIZE 16)

    (: broken Bool)
    (= broken (initnext false (prev broken)))

    (object Suzie (: timeTillThrow Integer) (Cell 0 0 "blue"))
    (object Billy (: timeTillThrow Integer) (Cell 0 0 "red"))

    (object BottleSpot (Cell 0 0 "white"))
    (object Rock (: moving Bool) (Cell 0 0 "black"))

    (: suzie Suzie)
    (= suzie (initnext (Suzie 3 (Position 0 0))
      (updateObj (prev suzie) "timeTillThrow" (- (.. (prev suzie) timeTillThrow) 1))))

    (: billy Billy)
    (= billy (initnext (Billy 4 (Position 0 15))
      (updateObj (prev billy) "timeTillThrow" (- (.. (prev billy) timeTillThrow) 1))))

    (: bottleSpot BottleSpot)
    (= bottleSpot (initnext (BottleSpot (Position 15 7)) (BottleSpot (Position 15 7))))


    (: suzieRock Rock)
    (= suzieRock (initnext (Rock false (Position 0 7))
      (if (.. suzieRock moving) then (move (prev suzieRock) (unitVector (prev suzieRock) bottleSpot)) else (prev suzieRock))))

    (on (== (.. suzie timeTillThrow) 0) (updateObj suzieRock "moving" true))
    (on (intersects (prev bottleSpot) (prev suzieRock)) (= broken true))
  )"""

function tostate(var)
  return Meta.parse("state.$(var)History[step]")
end

function tostate(var, field)
  return Meta.parse("state.$(var)History[step].$field")
end

function tostateshort(var)
  return Meta.parse("state.$(var)History")
end

function isfield(var)
  (length(split(string(var), "].")) > 1 || length(split(string(var), ").")) > 1)
end

function getfieldnames(var)
  split_ = split(string(var), "].")
  if length(split_) > 1
    return split(split_[2], ".")
  end
  split(split(string(var), ").")[2], ".")
end

function reducenoeval(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  Meta.parse(split_[1])
end

function pushbyfield(var, val)
  if isfield(a.args[2])
    eval(Expr(:(=), a.args[2], val))
  else
    push!(reduce(a.args[2]), step =>val)
  end
end

function fakereduce(var)
  Meta.parse(string(var))
end

function reduce(var)
  strvar = replace(string(var), "(" => "")
  strvar = replace(strvar, ")" => "")
  split_ = split(strvar, "[")
  eval(Meta.parse(split_[1]))
end

function getstep(var)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
end

function increment(var::Expr)
  split_1 = split(string(var), "[")
  split_2 = split(split_1[2], "]")
  index = eval(Meta.parse(split_2[1]))
  if index == :step
    return eval(Meta.parse(join([split_1[1], "[step]", split_2[2]])))
  end
  return Meta.parse(join([split_1[1], "[", string(index + 1), "]", split_2[2]]))
end

function intersects(obj1, obj2)
  obj1.origin.x == obj2.origin.x && obj1.origin.y == obj2.origin.y
end

intersects(obj1::Array, obj2) = intersects(obj2, obj1)

function intersects(obj1, obj2::Array)
  for obj in obj2
    if obj1.origin == obj.origin
      return true
    end
  end
  false
end

restrictedvalues = Dict(:(state.suzieHistory) => [0, 1, 2, 3, 4, 5, 6])

function possvals(val::Bool)
  [true, false]
end

function possvals(val::Union{BigInt, Int64})
  [-2^4:1:(2^4);]
end

function possvals(val)
  throw(AutumnError(string("Invalid variable type: ", typeof(val))))
end

function possiblevalues(var::Expr, val)
  if reducenoeval(var) in keys(restrictedvalues)
    return restrictedvalues[reducenoeval(var)]
  end
  possvals(eval(val))
end

# Base.:(==)(a::Foo, b::Bar) =

function tryb(cause_b)
  try
    return eval(cause_b)
  catch e
    println(e)
    return false
  end
end

function acaused(cause_a::Expr, cause_b::Expr)
  if eval(cause_a)
    varstore = eval(cause_a.args[2])
    short = eval(reduce(cause_a.args[2]))
    index = getstep(cause_a.args[2])
    for val in possiblevalues(cause_a.args[2], cause_a.args[3])
      println(val)
      if isfield(cause_a.args[2])
        eval(Expr(:(=), cause_a.args[2], val))
      else
        push!(reduce(cause_a.args[2]), step =>val)
      end
      println(eval(cause_b))
      if !(eval(cause_b))
        if isfield(cause_a.args[2])
          eval(Expr(:(=), cause_a.args[2], varstore))
        else
          push!(reduce(cause_a.args[2]), step =>varstore)
        end
        return true
        break
      end
    end
    if isfield(cause_a.args[2])
      eval(Expr(:(=), cause_a.args[2], varstore))
    else
      push!(reduce(cause_a.args[2]), step =>varstore)
    end
  end
  false
end
# ------------------------------Change to function------------------------------
macro test_ac(expected_true, aexpr_,  cause_a_, cause_b_)
    if expected_true
      cause = Meta.parse("@test true")
      not_cause = Meta.parse("@test false")
    else
      cause = Meta.parse("@test false")
      not_cause = Meta.parse("@test true")
    end
    global step = 0
    return quote
      global step = 0
      get_a_causes = getcausal($aexpr_)
      # println(get_a_causes)
      eval(get_a_causes)
      aumod = eval(compiletojulia($aexpr_))
      state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
      causes = [$cause_a_]
      cause_b = $cause_b_

      while !tryb(cause_b) && length(causes) > 0
        new_causes = []
        println(causes)
        for cause_a in causes
          try
            if eval(cause_a)
              append!(new_causes, a_causes(cause_a))
            else
              append!(new_causes, [cause_a])
            end
          catch e
            println(e)
            append!(new_causes, [cause_a])
          end
        end
        global causes = new_causes
        global state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
        global step = step + 1
      end
    for cause_a in causes
      if acaused(cause_a, cause_b)
        println("A did cause B")
        println("a path")
        println(cause_a)
        println("b path")
        println(cause_b)
        $cause
        return
      end
    end
    println("A did not cause B")
    println("causes")
    println(causes)
    println("cause b")
    println(cause_b)
    $not_cause
  end
end
# ------------------------------Suzie Test---------------------------------------
# # cause((suzie == 1), (broken == true))
# a = :(state.suzieHistory[step] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr, a, b)
#
# a = :(state.suzieHistory[0] == 1)
# b = :(state.brokenHistory[5] == true)
# @test_ac(true, aexpr, a, b)
#
# a = :(state.suzieHistory[2] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[step] == 0)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[0] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[1] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr, a, b)
#
# # ------------------------------Suzie Test---------------------------------------
# #cause((suzie == 1), (broken == true))
# a = :(state.suzieHistory[step] == 1)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr2, a, b)
#
# # -------------------------------Billy Test---------------------------------------
# # cause((billy == 0), (broken == true))
# a = :(state.billyHistory[step] == 0)
# b = :(state.brokenHistory[step] == true)
# @test_ac(false, aexpr2, a, b)
# #
# # # # -----------------------------Advanced Suzie Test No Rock-----------------------
# a = :(state.suzieHistory[step].timeTillThrow == 3)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(true, aexpr3, a, b)
#
# a = :(state.suzieHistory[step].timeTillThrow == 2)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(true, aexpr3, a, b)
#
# a = :(state.suzieHistory[2].timeTillThrow == 3)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)
#
# # # -----------------------------Advanced Billy Test No Rock-----------------------
# a = :(state.suzieHistory[step].timeTillThrow == 4)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)
#
# a = :(state.suzieHistory[0].timeTillThrow == 4)
# b = :(state.suzieThrewHistory[step] == true)
# @test_ac(false, aexpr3, a, b)
#
# # -------------------------------Advanced Rock Test---------------------------------------
#
# a = :(state.suzieRockHistory[step].origin.x == 0)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr4, a, b)

# # -------------------------------Advanced Suzie Test---------------------------------------
# Autumn program has a bug.  After the first on clause the program stops updating.
# a = :(state.suzieHistory[step].timeTillThrow == 3)
# b = :(state.brokenHistory[step] == true)
# @test_ac(true, aexpr5, a, b)

# #------------------------------Current Assumptions-------------------------------
# # cause and event are both in the form x == y
#
# #-------------------------------Julia Questions---------------------------------
# # Switch from compiler to interpreter?
# # Clean up code and add documentation
# # Look at notion
# # What should occur if the variable isnt actually related
#   #on (suzie < infinity or suzie > infinity) something

# When the transition works will need to take the change from the assignment
# Loop through the fields and any that are different given the assignment should be traced?
barrier = au"""(program
  (= GRID_SIZE 16)

  (object Goal (Cell 0 0 "green"))
  (: goal Goal)
  (= goal (initnext (Goal (Position 0 10)) (prev goal)))

  (object Ball (: direction Float64) (: color String) (Cell 0 0 color))

  (object Wall (: visible Bool)(list (Cell 0 0 (if visible then "black" else "white")) (Cell 0 1 (if visible then "black" else "white")) (Cell 0 2 (if visible then "black" else "white"))))

  (: wall Wall)
  (= wall (initnext (Wall true (Position 4 9)) (prev wall)))

  (= nextBall (fn (ball)
    (if (< (.. ball direction) 45)
      then (updateObj ball "origin"
             (Position (.. (.. ball origin) x) (- (.. (.. ball origin) y) 1)))
   else
    (if (< (.. ball direction) 90)
      then (updateObj ball "origin"
             (Position (+ (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
   else
    (if (< (.. ball direction) 135)
      then (updateObj ball "origin"
             (Position (+ (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
   else
    (if (< (.. ball direction) 180)
      then (updateObj ball "origin"
             (Position (+ (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
   else
    (if (< (.. ball direction) 225)
      then (updateObj ball "origin"
             (Position (.. (.. ball origin) x) (+ (.. (.. ball origin) y) 1)))
    else
      (if (< (.. ball direction) 270)
        then (updateObj ball "origin"
               (Position (- (.. (.. ball origin) x) 1) (+ (.. (.. ball origin) y) 1)))
    else
      (if (< (.. ball direction) 315)
            then (updateObj ball "origin"
                   (Position (- (.. (.. ball origin) x) 1) (.. (.. ball origin) y)))
    else
      (if (< (.. ball direction) 360)
          then (updateObj ball "origin"
                 (Position (- (.. (.. ball origin) x) 1) (- (.. (.. ball origin) y) 1)))
      else ball))))))))))


  (on (clicked wall) (= wall (updateObj wall "visible" (! (.. wall visible)))))

  (= wallintersect (fn (ball)
    (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (- 180 (.. ball direction)) else
    (if (& (== (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then 0 else
    (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 15)) then (+ 90 (.. ball direction)) else
    (if (& (& (< (.. ball direction) 270) (> (.. ball direction) 180)) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
    (if (& (== (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then 90 else
    (if (& (> (.. ball direction) 270) (== (.. (.. ball origin) x) 0)) then (- 360 (.. ball direction)) else
    (if (& (< (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then (+ 270 (.. ball direction)) else
    (if (& (== (.. ball direction) 90) (== (.. (.. ball origin) x) 15)) then 270 else
    (if (& (& (> (.. ball direction) 90) (< (.. ball direction) 180)) (== (.. (.. ball origin) x) 15)) then (+ 90 (.. ball direction)) else
    (if (& (> (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 520 (.. ball direction)) else
    (if (& (== (.. ball direction) 45) (== (.. (.. ball origin) y) 0)) then 180 else
    (if (& (< (.. ball direction) 180) (== (.. (.. ball origin) y) 0)) then (- 180 (.. ball direction)) else

  (.. ball direction)))))))))))))))

  (= ballcollision (fn (ball1 ball2)
    (/ (+ (.. ball1 direction) (.. ball2 direction)) 2)
  ))

  (: ball_a Ball)
  (= ball_a (initnext (Ball 271.0 "blue" (Position 15 10)) (if (intersects ball_a ball_b) then (nextBall (updateObj (prev ball_a) "direction" (ballcollision (prev ball_a) (prev ball_b)))) else (nextBall (updateObj (prev ball_a) "direction" (wallintersect (prev ball_a)))))))

  (: ball_b Ball)
  (= ball_b (initnext (Ball 225.0 "red" (Position 15 5)) (if (intersects (prev ball_a) ball_b) then (nextBall (updateObj (prev ball_b) "direction" 361)) else (nextBall (updateObj (prev ball_b) "direction" (wallintersect (prev ball_b)))))))
)"""
  #
  aumod = eval(compiletojulia(barrier))
  step = 0
  state = aumod.init(nothing, nothing, nothing, nothing, nothing, MersenneTwister(0))
  println(state.ball_aHistory[step])
  step+=1
  #
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1
  state = aumod.next(state, aumod.Click(0, 0), nothing, nothing, nothing, nothing)
  println(state.ball_aHistory[step])
  step+=1



  # println(state.brokenHistory[step])
  # println(fieldnames(typeof(state.suzieRockHistory[step])))
  # println(state.suzieRockHistory[step].id)
  # println(state.suzieRockHistory[step].alive)
  # println(state.suzieRockHistory[step].render)
  # # state.rocksHistory[step][1].origin = Position(4, 7)
  # # println(state.rocksHistory[step][1].origin)
  # step+=1
  #
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.suzieRockHistory[step])
  # println(state.suzieRockHistory[step].origin.x)
  # println(state.suzieRockHistory[step].origin.y)
  #
  # println(state.brokenHistory[step])
  # step+=1
  # state = aumod.next(state, nothing, nothing, nothing, nothing, nothing)
  # println(state.suzieRockHistory[step])
  # println(state.suzieRockHistory[step].origin.x)
  # println(state.suzieRockHistory[step].origin.y)
#syntactic pattern matching but its not necessarily syntactic thing
#what to do if non trivial
#in my set of causes
#instead of checking syntax check if changing the value changes the next value
#maybe split the ors then do that?
#remove it


#Now it removes the variable and if it errors or becomes false then it determines that it is related
#Need to think about or statements/and statements where it is always true
#(but for the a < 100 or a >99 wouldnt a not existing prevent this from being true and would therefore be the cause?)
#Need to handle more syntax things like the sub fields

#changes from always true to maybe true
#find some p that makes it false
#execute abstractly
#abstraction problem
#abstract interpretation take program redefine operations to work with values (replace numbers with intervals)


#changed model where change what we currently have
#suppose that suzie throws and if its close then it breaks
#except for some tiny location think about it and solve it
#add to the question
#prove that there are no counter examples

#tracking objects within the list is hard
