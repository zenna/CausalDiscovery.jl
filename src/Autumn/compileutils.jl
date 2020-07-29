module CompileUtils

using ..AExpressions
using Distributions: Categorical
using MLStyle: @match

export AutumnCompileError, compile, compilestatestruct, compileinitstate, compileinitnext, compileprevfuncs, compilebuiltin, compileobject, compileon

"Autumn Compile Error"
struct AutumnCompileError <: Exception
  msg
end
AutumnCompileError() = AutumnCompileError("")
abstract type Object end
# ----- Compile Helper Functions ----- #

function compile(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  arr = [expr.head, expr.args...]
  res = @match arr begin
    [:if, args...] => :($(compile(args[1], data)) ? $(compile(args[2], data)) : $(compile(args[3], data)))
    [:assign, args...] => compileassign(expr, data, parent)
    [:typedecl, args...] => compiletypedecl(expr, data, parent)
    [:external, args...] => compileexternal(expr, data)
    [:let, args...] => compilelet(expr, data)
    [:case, args...] => compilecase(expr, data)
    [:typealias, args...] => compiletypealias(expr, data)
    [:lambda, args...] => :($(compile(args[1], data)) -> $(compile(args[2], data)))
    [:list, args...] => :([$(map(x -> compile(x, data), expr.args)...)])
    [:call, args...] => compilecall(expr, data)
    [:field, args...] => :($(compile(expr.args[1], data)).$(compile(expr.args[2], data)))
    [:object, args...] => compileobject(expr, data)
    [:on, args...] => compileon(expr, data)
    [args...] => throw(AutumnCompileError(string("Invalid AExpr Head: ", expr.head))) # if expr head is not one of the above, throw error
  end
end

function compile(expr::AbstractArray, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  if length(expr) == 0 || (length(expr) > 1 && expr[1] != :List)
    throw(AutumnCompileError("Invalid List Syntax"))
  elseif expr[1] == :List
    :(Array{$(compile(expr[2:end], data))})
  else
    expr[1]      
  end
end

function compile(expr, data::Dict{String, Any}, parent::Union{AExpr, Nothing}=nothing)
  expr
end

function compileassign(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing})
  # get type, if declared
  type = haskey(data["types"], expr.args[1]) ? data["types"][expr.args[1]] : nothing
  if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
    if type !== nothing # handle function with typed arguments/return type
      args = compile(expr.args[2].args[1], data).args # function args
      argtypes = map(x -> compile(x, data), type.args[1:(end-1)]) # function arg types
      tuples = [(args[i], argtypes[i]) for i in [1:length(args);]]
      typedargexprs = map(x -> :($(x[1])::$(x[2])), tuples)
      quote 
        function $(compile(expr.args[1], data))($(typedargexprs...))::$(compile(type.args[end], data))
          $(compile(expr.args[2].args[2], data))  
        end
      end 
    else # handle function without typed arguments/return type
      quote 
        function $(compile(expr.args[1], data))($(compile(expr.args[2].args[1], data).args[2]...))
            $(compile(expr.args[2].args[2], data))
        end 
      end          
    end
  else # handle non-function assignments
    # handle global assignments
    if parent !== nothing && (parent.head == :program) 
      if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
        push!(data["initnext"], expr)
      else
        push!(data["lifted"], expr)
      end
      :()
    # handle non-global assignments
    else 
      if type !== nothing
        # :($(compile(expr.args[1], data))::$(compile(type, data)) = $(compile(expr.args[2], data)))
        :($(compile(expr.args[1], data)) = $(compile(expr.args[2], data)))
      else
          :($(compile(expr.args[1], data)) = $(compile(expr.args[2], data)))
      end
    end
  end
end

function compiletypedecl(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing})
  if (parent !== nothing && (parent.head == :program || parent.head == :external))
    println(expr.args[1])
    println(expr.args[2])
    data["types"][expr.args[1]] = expr.args[2]
    :()
  else
    :(local $(compile(expr.args[1], data))::$(compile(expr.args[2], data)))
  end
end

function compileexternal(expr::AExpr, data::Dict{String, Any})
  println("here: ")
  println(expr.args[1])
  if !(expr.args[1] in data["external"])
    push!(data["external"], expr.args[1])
  end
  compiletypedecl(expr.args[1], data, expr)
end

function compiletypealias(expr::AExpr, data::Dict{String, Any})
  name = expr.args[1]
  fields = map(field -> (
    :($(field.args[1])::$(field.args[2]))
  ), expr.args[2].args)
  quote
    struct $(name)
      $(fields...) 
    end
  end
end

function compilecall(expr::AExpr, data::Dict{String, Any})
  fnName = expr.args[1]
  if !(fnName in binaryOperators) && fnName != :prev
    :($(fnName)($(map(x -> compile(x, data), expr.args[2:end])...)))
  elseif fnName == :prev
    :($(Symbol(string(expr.args[2]) * "Prev"))($(map(compile, expr.args[3:end])...)))
  elseif fnName != :(==)        
    :($(fnName)($(compile(expr.args[2], data)), $(compile(expr.args[3], data))))
  else
    :($(compile(expr.args[2], data)) == $(compile(expr.args[3], data)))
  end
end

function compilelet(expr::AExpr, data::Dict{String, Any})
  quote
    $(map(x -> compile(x, data), expr.args)...)
  end
end

function compilecase(expr::AExpr, data::Dict{String, Any})
  quote 
    @match $(compile(expr.args[1], data)) begin
      $(map(x -> :($(compile(x.args[1], data)) => $(compile(x.args[2], data))), expr.args[2:end])...)
    end
  end
end

function compileobject(expr::AExpr, data::Dict{String, Any})
  name = expr.args[1]
  push!(data["objects"], name)
  custom_fields = map(field -> (
    :($(field.args[1])::$(field.args[2]))
  ), filter(x -> x.head == :typedecl, expr.args[2:end]))
  custom_field_names = map(field -> field.args[1], filter(x -> x.head == :typedecl, expr.args[2:end]))
  rendering = compile(filter(x -> x.head != :typedecl, expr.args[2:end])[1], data)
  quote
    mutable struct $(name) <: Object
      id::Int
      origin::Position
      alive::Bool
      $(custom_fields...) 
      render::Array{ColoredCell}
    end

    function $(name)($(vcat(custom_fields, :(origin::Position))...))::$(name)
      state.objectsCreated += 1
      rendering = $(rendering)      
      $(name)(state.objectsCreated, origin, true, $(custom_field_names...), rendering isa AbstractArray ? rendering : [rendering])
    end
  end
end

function compileon(expr::AExpr, data::Dict{String, Any})
  println(compile(expr.args[2], data))
  data["on"][compile(expr.args[1], data)] = compile(expr.args[2], data)
  :()
end

function compileinitnext(data::Dict{String, Any})
  init = quote
    $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2].args[1], data))), data["initnext"])...)
  end
  next = quote
    if occurred(click)
      $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
          vcat(data["initnext"], data["lifted"]))...)
      $(get(data["on"], :click, :(GRID_SIZE = GRID_SIZE)))
    elseif occurred(keypress)
      if keypress == Left()
        $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
          vcat(data["initnext"], data["lifted"]))...)
        $(get(data["on"], :(keypress("left")), :(GRID_SIZE = GRID_SIZE)))
      elseif keypress == Right()
        $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
        vcat(data["initnext"], data["lifted"]))...)
        $(get(data["on"], :(keypress("right")), :(GRID_SIZE = GRID_SIZE)))
      elseif keypress == Up() 
        $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
        vcat(data["initnext"], data["lifted"]))...)
        $(get(data["on"], :(keypress("up")), :(GRID_SIZE = GRID_SIZE)))
      elseif keypress == Down()
        $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
        vcat(data["initnext"], data["lifted"]))...)
        $(get(data["on"], :(keypress("down")), :(GRID_SIZE = GRID_SIZE)))
      end
    else
      $(map(x -> :($(compile(x.args[1], data)) = state.$(Symbol(string(x.args[1])*"History"))[state.time - 1]), 
          vcat(data["external"], data["initnext"], data["lifted"]))...)
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2].args[2], data))), data["initnext"])...)
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), filter(x -> x.args[1] != :GRID_SIZE, data["lifted"]))...)
    end
  end
  

  initFunction = quote
    function init($(map(x -> :($(compile(x.args[1], data))::Union{$(compile(data["types"][x.args[1]], data)), Nothing}), data["external"])...))::STATE
      $(compileinitstate(data))
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), filter(x -> x.args[1] == :GRID_SIZE, data["lifted"]))...)
      $(init)
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), filter(x -> x.args[1] != :GRID_SIZE, data["lifted"]))...)
      $(map(x -> :(state.$(Symbol(string(x.args[1])*"History"))[state.time] = $(compile(x.args[1], data))), 
            vcat(data["external"], data["initnext"], data["lifted"]))...)
            state.scene = Scene(vcat([$(filter(x -> get(data["types"], x, :Any) in vcat(data["objects"], map(x -> [:List, x], data["objects"])), 
        map(x -> x.args[1], vcat(data["initnext"], data["lifted"])))...)]...), :backgroundHistory in fieldnames(STATE) ? state.backgroundHistory[state.time] : "transparent")
      deepcopy(state)
    end
    end
  nextFunction = quote
    function next($([:(old_state::STATE), map(x -> :($(compile(x.args[1], data))::Union{$(compile(data["types"][x.args[1]], data)), Nothing}), data["external"])...]...))::STATE
      global state = deepcopy(old_state)
      state.time = state.time + 1
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), filter(x -> x.args[1] == :GRID_SIZE, data["lifted"]))...)
      $(next)
      $(map(x -> :(state.$(Symbol(string(x.args[1])*"History"))[state.time] = $(compile(x.args[1], data))), 
            vcat(data["external"], data["initnext"], data["lifted"]))...)
      state.scene = Scene(vcat([$(filter(x -> get(data["types"], x, :Any) in vcat(data["objects"], map(x -> [:List, x], data["objects"])), 
        map(x -> x.args[1], vcat(data["initnext"], data["lifted"])))...)]...), :backgroundHistory in fieldnames(STATE) ? state.backgroundHistory[state.time] : "transparent")
      deepcopy(state)
    end
    end
    [initFunction, nextFunction]
end

# construct STATE struct
function compilestatestruct(data::Dict{String, Any})
  stateParamsInternal = map(expr -> :($(Symbol(string(expr.args[1]) * "History"))::Dict{Int64, $(haskey(data["types"], expr.args[1]) ? compile(data["types"][expr.args[1]], data) : Any)}), 
                            vcat(data["initnext"], data["lifted"]))
  stateParamsExternal = map(expr -> :($(Symbol(string(expr.args[1]) * "History"))::Dict{Int64, Union{$(compile(data["types"][expr.args[1]], data)), Nothing}}), 
                            data["external"])
  quote
    mutable struct STATE
      time::Int
      objectsCreated::Int
      scene::Scene
      $(stateParamsInternal...)
      $(stateParamsExternal...)
    end
  end
end

# initialize state::STATE variable
function compileinitstate(data::Dict{String, Any})
  initStateParamsInternal = map(expr -> :(Dict{Int64, $(haskey(data["types"], expr.args[1]) ? compile(data["types"][expr.args[1]], data) : Any)}()), 
                                vcat(data["initnext"], data["lifted"]))
  initStateParamsExternal = map(expr -> :(Dict{Int64, Union{$(compile(data["types"][expr.args[1]], data)), Nothing}}()), 
                                data["external"])
  initStateParams = [0, 0, :(Scene([])), initStateParamsInternal..., initStateParamsExternal...]
  initState = :(state = STATE($(initStateParams...)))
  initState
end

# ----- Built-In and Prev Function Helpers ----- #

function compileprevfuncs(data::Dict{String, Any})
  prevFunctions = map(x -> quote
        function $(Symbol(string(x.args[1]) * "Prev"))(n::Int=1)::$(haskey(data["types"], x.args[1]) ? compile(data["types"][x.args[1]], data) : Any)
          state.$(Symbol(string(x.args[1]) * "History"))[state.time - n >= 0 ? state.time - n : 0] 
        end
        end, 
  vcat(data["initnext"], data["lifted"]))
  prevFunctions = vcat(prevFunctions, map(x -> quote
        function $(Symbol(string(x.args[1]) * "Prev"))(n::Int=1)::Union{$(compile(data["types"][x.args[1]], data)), Nothing}
          state.$(Symbol(string(x.args[1]) * "History"))[state.time - n >= 0 ? state.time - n : 0] 
        end
        end, 
  data["external"]))
  prevFunctions
end

function compilebuiltin()
  occurredFunction = builtInDict["occurred"]
  uniformChoiceFunction = builtInDict["uniformChoice"]
  uniformChoiceFunction2 = builtInDict["uniformChoice2"]
  minFunction = builtInDict["min"]
  clickType = builtInDict["clickType"]
  rangeFunction = builtInDict["range"]
  utils = builtInDict["utils"]
  [occurredFunction, utils, uniformChoiceFunction, uniformChoiceFunction2, minFunction, clickType, rangeFunction]
end

const builtInDict = Dict([
"occurred"        =>  quote
                        function occurred(click)
                          click !== nothing
                        end
                      end,
"uniformChoice"   =>  quote
                        function uniformChoice(freePositions)
                          freePositions[rand(Categorical(ones(length(freePositions))/length(freePositions)))]
                        end
                      end,
"uniformChoice2"   =>  quote
                        function uniformChoice(freePositions, n)
                          map(idx -> freePositions[idx], rand(Categorical(ones(length(freePositions))/length(freePositions)), n))
                        end
                      end,
"min"              => quote
                        function min(arr)
                          min(arr...)
                        end
                      end,
"clickType"       =>  quote
                        struct Click
                          x::Union{BigInt, Int}
                          y::Union{BigInt, Int}                    
                        end     
                      end,
"range"           => quote
                      function range(start::Union{BigInt, Int}, stop::Union{BigInt, Int})
                        [start:stop;]
                      end
                    end,
"utils"           => quote
                        abstract type Object end

                        abstract type KeyPress end

                        struct Left <: KeyPress end
                        struct Right <: KeyPress end
                        struct Up <: KeyPress end
                        struct Down <: KeyPress end

                        struct Position
                          x::Union{BigInt, Int}
                          y::Union{BigInt, Int}
                        end

                        struct ColoredCell 
                          position::Position
                          color::String
                          opacity::Float64
                        end

                        ColoredCell(position::Position, color::String) = ColoredCell(position, color, 0.6)

                        struct Scene
                          objects::Array{Object}
                          background::String
                        end

                        Scene(objects::AbstractArray) = Scene(objects, "transparent")

                        function render(scene::Scene)::Array{ColoredCell}
                          vcat(map(obj -> map(cell -> ColoredCell(move(cell.position, obj.origin), cell.color), obj.render), filter(obj -> obj.alive, scene.objects))...)
                        end


                        function addObj(list::Array{<:Object}, obj::Object)
                          push!(list, obj)
                          list
                        end

                        function addObj(list::Array{<:Object}, objs::Array{<:Object})
                          list = vcat(list, objs)
                          list
                        end

                        function removeObj(list::Array{<:Object}, obj::Object)
                          old_obj = filter(x -> x.id == obj.id, list)
                          old_obj.alive = false
                          list
                        end

                        function removeObj(list::Array{<:Object}, fn)
                          orig_list = filter(obj -> !fn(obj), list)
                          removed_list = filter(obj -> fn(obj), list)
                          foreach(obj -> (obj.alive = false), removed_list)
                          vcat(orig_list, removed_list)
                        end

                        function removeObj(obj::Object)
                          obj.alive = false
                          obj
                        end

                        function updateObj(obj::Object, field::String, value)
                          fields = fieldnames(typeof(obj))
                          custom_fields = fields[4:end-1]
                          origin_field = (fields[2],)

                          constructor_fields = (custom_fields..., origin_field...)
                          constructor_values = map(x -> x == Symbol(field) ? value : getproperty(obj, x), constructor_fields)

                          new_obj = typeof(obj)(constructor_values...)
                          setproperty!(new_obj, :id, obj.id) 
                          new_obj
                        end

                        function filter_fallback(obj::Object)
                          true
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
                          length(filter(cell -> cell.position == position, render(state.scene))) == 0
                        end

                        function unitDistance(position1::Position, position2::Position)::Position
                          deltaX = position2.x - position1.x
                          deltaY = position2.y - position1.y
                          if (abs(sign(deltaX)) == 1 && abs(sign(deltaY) == 1))
                            uniformChoice([Position(sign(deltaX), 0), Position(0, sign(deltaY))])
                          else
                            Position(sign(deltaX), sign(deltaY))  
                          end
                        end

                        function unitDistance(object1::Object, object2::Object)::Position
                          position1 = object1.origin
                          position2 = object2.origin
                          unitDistance(position1, position2)
                        end

                        function unitDistance(object::Object, position::Position)::Position
                          unitDistance(object.origin, position)
                        end

                        function unitDistance(position::Position, object::Object)::Position
                          unitDistance(position, object.origin)
                        end

                        function move(position1::Position, position2::Position)
                          Position(position1.x + position2.x, position1.y + position2.y)
                        end

                        function move(object::Object, position::Position)
                          new_object = deepcopy(object)
                          new_object.origin = move(object.origin, position)
                          new_object
                        end

                        function randomPositions(GRID_SIZE::Union{BigInt, Int}, n::Union{BigInt, Int})::Array{Position}
                          nums = uniformChoice([0:(GRID_SIZE * GRID_SIZE - 1);], n)
                          println(nums)
                          println(map(num -> Position(num % GRID_SIZE, floor(Int, num / GRID_SIZE)), nums))
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

                        function mapPositions(constructor, GRID_SIZE::Union{Int, BigInt}, filterFunction, args...)::Union{Object, Array{<:Object}}
                          map(pos -> constructor(args..., pos), filter(filterFunction, allPositions(GRID_SIZE)))
                        end

                        function allPositions(GRID_SIZE::Union{Int, BigInt})
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

                        function addToRender(object::Object, cell::ColoredCell)

                        end

                        function addToRender(object::Object, cells::Array{ColoredCell})

                        end

                        function addToRender(object::Array{Object}, map_fn, filter_fn)

                        end

                        function removeFromRender(object)

                        end

                        function updateRender(object::Object, map_fn, filter_fn)

                        end

                        function updateRender(object::Array{Object}, map_fn, filter_fn)

                        end

                    end
])

# binary operators
const binaryOperators = [:+, :-, :/, :*, :&, :|, :>=, :<=, :>, :<, :(==), :!=, :%, :&&]

end