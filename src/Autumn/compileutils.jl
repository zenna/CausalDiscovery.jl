module CompileUtils

using ..AExpressions
using Distributions: Categorical
using MLStyle: @match

export AutumnCompileError, compile, compilestatestruct, compileinitstate, compileinitnext, compileprevfuncs, compilebuiltin

"Autumn Compile Error"
struct AutumnCompileError <: Exception
  msg
end
AutumnCompileError() = AutumnCompileError("")

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
        :($(compile(expr.args[1], data))::$(compile(type, data)) = compile(expr.args[2], data))
      else
          :($(compile(expr.args[1], data)) = $(compile(expr.args[2], data)))
      end
    end
  end
end

function compiletypedecl(expr::AExpr, data::Dict{String, Any}, parent::Union{AExpr, Nothing})
  if (parent !== nothing && (parent.head == :program || parent.head == :external))
    data["types"][expr.args[1]] = expr.args[2]
    :()
  else
    :(local $(compile(expr.args[1], data))::$(compile(expr.args[2], data)))
  end
end

function compileexternal(expr::AExpr, data::Dict{String, Any})
  push!(data["external"], expr.args[1])
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

function compileinitnext(data::Dict{String, Any})
  initFunction = quote
    function init($(map(x -> :($(compile(x.args[1], data))::Union{$(compile(data["types"][x.args[1]], data)), Nothing}), data["external"])...))::STATE
      $(compileinitstate(data))
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2].args[1], data))), data["initnext"])...)
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), data["lifted"])...)
      $(map(x -> :(state.$(Symbol(string(x.args[1])*"History"))[state.time] = $(compile(x.args[1], data))), 
            vcat(data["external"], data["initnext"], data["lifted"]))...)
      deepcopy(state)
    end
    end
  nextFunction = quote
    function next($([:(old_state::STATE), map(x -> :($(compile(x.args[1], data))::Union{$(compile(data["types"][x.args[1]], data)), Nothing}), data["external"])...]...))::STATE
      global state = deepcopy(old_state)
      state.time = state.time + 1
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2].args[2], data))), data["initnext"])...)
      $(map(x -> :($(compile(x.args[1], data)) = $(compile(x.args[2], data))), data["lifted"])...)
      $(map(x -> :(state.$(Symbol(string(x.args[1])*"History"))[state.time] = $(compile(x.args[1], data))), 
            vcat(data["external"], data["initnext"], data["lifted"]))...)
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
  initStateParams = [0, initStateParamsInternal..., initStateParamsExternal...]
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
  [occurredFunction, uniformChoiceFunction, uniformChoiceFunction2, minFunction, clickType, rangeFunction]
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
                          x::BigInt
                          y::BigInt                    
                        end     
                      end,
"range"           => quote
                      function range(start::BigInt, stop::BigInt)
                        [start:stop;]
                      end
                     end
])

# binary operators
const binaryOperators = [:+, :-, :/, :*, :&, :|, :>=, :<=, :>, :<, :(==), :!=, :%, :&&]

end