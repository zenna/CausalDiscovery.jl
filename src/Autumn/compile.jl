"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using Distributions: Categorical
using MLStyle: @match
import MacroTools: striplines

export compiletojulia, runprogram

binaryOperators = [:+, :-, :/, :*, :&, :|, :>=, :<=, :>, :<, :(==), :!=, :%, :&&]

struct AutumnCompileError <: Exception
  msg
end
AutumnCompileError() = AutumnCompileError("")

"compile `aexpr` into Expr"
function compiletojulia(aexpr::AExpr)::Expr

  data = Dict([("historyVars" => []),
               ("externalVars" => []),
               ("initnextVars" => []),
               ("liftedVars" => []),
               ("types" => Dict())])
  
  # ----- HELPER FUNCTIONS ----- #
  function compile(expr::AExpr, parent=nothing)
    arr = [expr.head, expr.args...]
    res = @match arr begin
      [:if, args...] => :($(compile(args[1], expr)) ? $(compile(args[2], expr)) : $(compile(args[3], expr)))
      [:assign, args...] => compileassign(expr, parent, data)
      [:typedecl, args...] => compiletypedecl(expr, parent, data)
      [:external, args...] => compileexternal(expr, data)
      [:const, args...] => :(const $(compile(args[1].args[1])) = $(compile(args[1].args[2])))
      [:let, args...] => compilelet(expr)
      [:case, args...] => compilecase(expr)
      [:typealias, args...] => compiletypealias(expr)
      [:lambda, args...] => :($(compile(args[1])) -> $(compile(args[2])))
      [:list, args...] => :([$(map(compile, expr.args)...)])
      [:call, args...] => compilecall(expr)
      [:field, args...] => :($(compile(expr.args[1])).$(compile(expr.args[2])))
      [args...] => throw(AutumnCompileError("Invalid AExpr Head: "))
    end
  end

  function compile(expr::AbstractArray, parent=nothing)
    if length(expr) == 0 || (length(expr) > 1 && expr[1] != :List)
      throw(AutumnCompileError("Invalid Compound Type"))
    elseif expr[1] == :List
      :(Array{$(compile(expr[2:end]))})
    else
      expr[1]      
    end
  end

  function compile(expr, parent=nothing)
    expr
  end
  
  function compileassign(expr::AExpr, parent::Union{AExpr, Nothing}, data::Dict{String, Any})
    # get type, if declared
    type = haskey(data["types"], (expr.args[1], parent)) ? data["types"][(expr.args[1], parent)] : nothing
    if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
      if type !== nothing # handle function with typed arguments/return type
        args = compile(expr.args[2].args[1]).args # function args
        argTypes = map(compile, type.args[1:(end-1)]) # function arg types
        tuples = [(args[i], argTypes[i]) for i in [1:length(args);]]
        typedArgExprs = map(x -> :($(x[1])::$(x[2])), tuples)
        quote 
          function $(compile(expr.args[1]))($(typedArgExprs...))::$(compile(type.args[end]))
            $(compile(expr.args[2].args[2]))  
          end
        end 
      else # handle function without typed arguments/return type
        quote 
          function $(compile(expr.args[1]))($(compile(expr.args[2].args[1]).args[2]...))
              $(compile(expr.args[2].args[2]))  
          end 
        end          
      end
    else # handle non-function assignments
      # handle global assignments
      if parent !== nothing && (parent.head == :program) 
        push!(data["historyVars"], (expr.args[1], parent))
        if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
          push!(data["initnextVars"], expr)
        elseif (parent.head == :program)
          push!(data["liftedVars"], expr)
        end
        :()
      # handle non-global assignments
      else 
        if type !== nothing
          :($(compile(expr.args[1]))::$(compile(type)) = compile(expr.args[2]))
        else
            :($(compile(expr.args[1])) = $(compile(expr.args[2])))
        end
      end
    end
  end
  
  function compiletypedecl(expr, parent, data)
    if (parent !== nothing && (parent.head == :program || parent.head == :external))
      data["types"][(expr.args[1], parent)] = expr.args[2]
      :()
    else
      :(local $(compile(expr.args[1]))::$(compile(expr.args[2])))
    end
  end
  
  function compileexternal(expr, data)
    push!(data["externalVars"], expr.args[1].args[1])
    push!(data["historyVars"], (expr.args[1].args[1], expr))
    compiletypedecl(expr.args[1], expr, data)
  end
  
  function compiletypealias(expr)
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
  
  function compilecall(expr)
    fnName = expr.args[1]
      if !(fnName in binaryOperators) && fnName != :prev
        :($(fnName)($(map(compile, expr.args[2:end])...)))
      elseif fnName == :prev
        :($(Symbol(string(expr.args[2]) * "Prev"))($(map(compile, expr.args[3:end])...)))
      elseif fnName != :(==)        
        :($(fnName)($(compile(expr.args[2])), $(compile(expr.args[3]))))
      else
        :($(compile(expr.args[2])) == $(compile(expr.args[3])))
      end
  end
  
  function compilelet(expr)
    quote
      $(map(x -> compile(x, expr), expr.args)...)
    end
  end

  function compilecase(expr)
    quote 
      @match $(compile(expr.args[1])) begin
        $(map(x -> :($(compile(x.args[1])) => $(compile(x.args[2]))), expr.args[2:end])...)
      end
    end
  end
  
  function compileinitnext(data)
    initStateParamsInternal = map(expr -> :(Dict{Int64, $(haskey(data["types"], expr) ? compile(data["types"][expr]) : Any)}()), 
    filter(x -> !(x[1] in data["externalVars"]), data["historyVars"]))
    initStateParamsExternal = map(expr -> :(Dict{Int64, Union{$(compile(data["types"][expr])), Nothing}}()), 
        filter(x -> (x[1] in data["externalVars"]), data["historyVars"]))
    initStateParams = [0, initStateParamsInternal..., initStateParamsExternal...]
    initStateStruct = :(state = STATE($(initStateParams...)))

    initFunction = quote
      function init($(map(x -> :($(compile(x[1]))::Union{$(compile(data["types"][x])), Nothing}), filter(x -> (x[1] in data["externalVars"]), data["historyVars"]))...))::STATE
        $(initStateStruct)
        $(map(x -> :($(compile(x.args[1])) = $(compile(x.args[2].args[1]))), data["initnextVars"])...)
        $(map(x -> :($(compile(x.args[1])) = $(compile(x.args[2]))), data["liftedVars"])...)
        $(map(x -> :(state.$(Symbol(string(x[1])*"History"))[state.time] = $(compile(x[1]))), data["historyVars"])...)
        deepcopy(state)
      end
     end
    nextFunction = quote
      function next($([:(old_state::STATE), map(x -> :($(compile(x[1]))::Union{$(compile(data["types"][x])), Nothing}), filter(x -> (x[1] in data["externalVars"]), data["historyVars"]))...]...))::STATE
        global state = deepcopy(old_state)
        state.time = state.time + 1
        $(map(x -> :($(compile(x.args[1])) = $(compile(x.args[2].args[2]))), data["initnextVars"])...)
        $(map(x -> :($(compile(x.args[1])) = $(compile(x.args[2]))), data["liftedVars"])...)
        $(map(x -> :(state.$(Symbol(string(x[1])*"History"))[state.time] = $(compile(x[1]))), data["historyVars"])...)
        deepcopy(state)
      end
     end
     [initFunction, nextFunction]
  end
  # ----- END HELPER FUNCTIONS ----- #


  # ----- COMPILATION -----#
  if (aexpr.head == :program)
    # handle AExpression lines
    lines = filter(x -> x !== :(), map(arg -> compile(arg, aexpr), aexpr.args))
    
    # construct STATE struct
    stateParamsInternal = map(expr -> :($(Symbol(string(expr[1]) * "History"))::Dict{Int64, $(haskey(data["types"], expr) ? compile(data["types"][expr]) : Any)}), 
                              filter(x -> !(x[1] in data["externalVars"]), data["historyVars"]))
    stateParamsExternal = map(expr -> :($(Symbol(string(expr[1]) * "History"))::Dict{Int64, Union{$(compile(data["types"][expr])), Nothing}}), 
                              filter(x -> (x[1] in data["externalVars"]), data["historyVars"]))
    stateStruct = quote
      mutable struct STATE
        time::Int
        $(stateParamsInternal...)
        $(stateParamsExternal...)
      end
    end

    # initialize state::STATE variable
    initStateParamsInternal = map(expr -> :(Dict{Int64, $(haskey(data["types"], expr) ? compile(data["types"][expr]) : Any)}()), 
                                 filter(x -> !(x[1] in data["externalVars"]), data["historyVars"]))
    initStateParamsExternal = map(expr -> :(Dict{Int64, Union{$(compile(data["types"][expr])), Nothing}}()), 
                                 filter(x -> (x[1] in data["externalVars"]), data["historyVars"]))
    initStateParams = [0, initStateParamsInternal..., initStateParamsExternal...]
    initStateStruct = :(state = STATE($(initStateParams...)))
    
    # handle initnext
    initnextFunctions = compileinitnext(data)
    prevFunctions = compileprevfuncs(data)
    builtinFunctions = compilebuiltin()

    # remove empty lines
    lines = filter(x -> x != :(), 
            vcat(builtinFunctions, lines, stateStruct, initStateStruct, prevFunctions, initnextFunctions))

    # construct module
    expr = quote
      module CompiledProgram
        export init, next
        import Base.min
        using Distributions
        using MLStyle: @match 
        $(lines...)
      end
    end  
    expr.head = :toplevel
    striplines(expr)
  else
    throw(AutumnCompileError())
  end
end

"Run `prog` forever"
function runprogram(prog::Expr, n::Int)
  mod = eval(prog)
  particles = mod.init(mod.Click(5, 5))

  externals = [nothing, nothing]
  for i in 1:n
    externals = [nothing, mod.Click(rand([1:10;]), rand([1:10;]))]
    particles = mod.next(mod.next(externals[rand(Categorical([0.7, 0.3]))]))
  end
  particles
end

# ----- Built-In and Prev Function Helpers ----- #

function compileprevfuncs(data::Dict{String, Any})
  prevFunctions = map(x -> quote
        function $(Symbol(string(x[1]) * "Prev"))(n::Int=1)
          state.$(Symbol(string(x[1]) * "History"))[state.time - n >= 0 ? state.time - n : 0] 
        end
        end, 
  data["historyVars"])
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

builtInDict = Dict([
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

end