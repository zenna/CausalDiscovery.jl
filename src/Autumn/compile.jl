"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program
using MLStyle 

export compiletojulia, runprogram

binaryOperators = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]

struct AutumnCompileError <: Exception
  msg
end
AutumnCompileError() = AutumnCompileError("")

"compile `aexpr` into `program::Program`"
function compiletojulia(aexpr::AExpr)::Expr

  data = Dict([("historyVars" => []),
               ("externalVars" => []),
               ("initnextVars" => []),
               ("liftedVars" => []),
               ("types" => Dict())])
  
  # ----- HELPER FUNCTIONS ----- #
  function compile(expr::AExpr, parent=nothing)
    arr = [expr.head, expr.args...]
    res = MLStyle.@match arr begin
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
      [args...] => throw(AutumnCompileError())
    end
  end

  function compile(expr, parent=nothing)
    expr
  end
  
  function compileassign(expr::AExpr, parent::AExpr, data::Dict{String, Any})
    # get type, if declared
    type = haskey(data["types"], (expr.args[1], parent)) ? data["types"][(expr.args[1], parent)] : nothing
    if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
      if type !== nothing # handle function with typed arguments/return type
        args = compile(expr.args[2].args[1]).args # function args
        argTypes = type.args[1:(end-1)] # function arg types
        tuples = [(arg, type) for arg in args, type in argTypes]
        typedArgExprs = map(x -> :($(x[1])::$(x[2])), tuples)
        quote 
          function $(compile(expr.args[1]))($(typedArgExprs...))::$(type.args[end])
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
      if parent !== nothing && (parent.head == :program || parent.head == :external) 
        push!(data["historyVars"], expr.args[1])
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
    data["types"][(expr.args[1], parent)] = expr.args[2]
    :()
  end
  
  function compileexternal(expr, data)
    push!(data["externalVars"], expr.args[1].args[1])
    push!(data["historyVars"], expr.args[1].args[1])
    :()
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
        :($(fnName)($(compile(expr.args[2])), $(expr.args[3])))
      else
        :($(compile(expr.args[2])) == $(compile(expr.args[3])))
      end
  end
  
  function compilelet(expr)
    quote
      $(vcat(map(x -> compile(x, expr), expr.args[1]), compile(expr.args[2]))...)
    end
  end

  function compilecase(expr)
    quote 
      MLStyle.@match $(compile(expr.args[1])) begin
        $(map(x -> :($(compile(x.args[1])) => $(compile(x.args[2]))), expr.args[3:end])...)
      end
    end
  end
  
  function compileinitnext(data)
    initFunction = quote
      function init()
        $(map(x -> :(global $(compile(x.args[1])) = $(compile(x.args[2].args[1]))), data["initnextVars"])...)
        $(map(x -> :(global $(compile(x.args[1])) = $(compile(x.args[2]))), data["liftedVars"])...)
        $(map(x -> :($(Symbol(string(x)*"History"))[time] = deepcopy($(compile(x)))), data["historyVars"])...)
      end
     end
    nextFunction = quote
      function next($(map(x -> compile(x), data["externalVars"])...))
        global time += 1
        $(map(x -> :(global $(compile(x.args[1])) = $(compile(x.args[2].args[2]))), data["initnextVars"])...)
        $(map(x -> :(global $(compile(x.args[1])) = $(compile(x.args[2]))), data["liftedVars"])...)
        $(map(x -> :($(Symbol(string(x) * "History"))[time] = deepcopy($(compile(x)))), data["historyVars"])...)
      end
     end
     [initFunction, nextFunction]
  end
  # ----- END HELPER FUNCTIONS ----- #


  # ----- COMPILATION -----#
  if (aexpr.head == :program)
    # handle AExpression lines
    lines = filter(x -> x !== :(),map(arg -> compile(arg, aexpr), aexpr.args))
    
    # handle history 
    initGlobalVars = map(expr -> :($(compile(expr)) = nothing), data["historyVars"])
    push!(initGlobalVars, :(time = 0))
    initHistoryDictArgs = map(expr -> :($(Symbol(string(expr) * "History")) = Dict{Int64, Any}), data["historyVars"])
    
    # handle initnext
    initnextFunctions = compileinitnext(data)
    prevFunctions = compileprevfuncs(data)
    builtinFunctions = compilebuiltin()

    # remove empty lines
    lines = filter(x -> x != :(), 
            vcat(initGlobalVars, initHistoryDictArgs, prevFunctions, builtinFunctions, lines, initnextFunctions))

    # construct module
    expr = quote
      module CompiledProgram
        export init, next
        using Distributions
        using MLStyle 
        $(lines...)
      end
    end  
    expr.head = :toplevel
    expr
  else
    throw(AutumnCompileError())
  end
end

"Run `prog` forever"
function runprogram(prog::AProgram)
  initexterns = (x = 3, y = 2)
  state = init(p, initexterns)
  while true
    externs = (x = rand(3:10), y = rand(1:10))
    state = next(state, externs)
  end
  state
end

# ----- Built-In and Prev Function Helpers ----- #

function compileprevfuncs(data::Dict{String, Any})
  prevFunctions = map(x -> quote
        function $(Symbol(string(x) * "Prev"))(n::Int)
          $(Symbol(string(x) * "History"))[time - n] 
        end
        end, 
  data["historyVars"])
  prevFunctions
end

function compilebuiltin()
  occurredFunction = builtInDict["occurred"]
  uniformChoiceFunction = builtInDict["uniformChoice"]
  clickType = builtInDict["clickType"]
  [occurredFunction, uniformChoiceFunction, clickType]
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
"clickType"       =>  quote
                        struct Click
                          x::Int
                          y::Int                    
                        end     
                      end
])

end