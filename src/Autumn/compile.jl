"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program
using MLStyle

export compiletojulia

"compile `aexpr` into `program::Program`"
function compiletojulia(aexpr::AExpr)::Expr

  # ----- DATA ----- #
  data = Dict([("historyVars" => []),
               ("externalVars" => []),
               ("initnextVars" => []),
               ("liftedVars" => []),
               ("types" => Dict())])
  
  # ----- COMPILATION ----- #
  if (aexpr.head == :program)
    # handle AExpression lines
    lines = map(arg -> compile(arg, aexpr, data), aexpr.args)
    
    # handle history 
    initGlobalVars = map(expr -> :($(compile(expr, aexpr, data)) = nothing), data["historyVars"])
    push!(initGlobalVars, :(time = 0))
    initHistoryDictArgs = map(expr -> :($(Symbol(string(expr) * "History")) = Dict{Int64, Any}), data["historyVars"])
    
    # handle initnext
    initnextFunctions = compileinitnext(aexpr, data)
    prevFunctions = compileprevfuncs(data)
    builtinFunctions = compilebuiltin()

    # remove empty lines
    lines = filter(x -> x != :(), 
            vcat(initGlobalVars, initHistoryDictArgs, prevFunctions, builtinFunctions, args, initnextFunctions))
    
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


binaryOperators = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]
struct AutumnCompileError <: Exception
  msg
end
AutumnCompileError() = AutumnCompileError("")

function compile(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  arr = [expr.head, expr.args...]
  res = MLStyle.@match arr begin
    [:if, cond, then, els] => :($(compile(cond, expr, data)) ? $(compile(then, expr, data)) : $(compile(els, expr, data)))
    [:assign, args...] => compileassign(expr, parent, data)
    [:typedecl, args...] => compiletypedecl(expr, parent, data)
    [:external, args...] => compileexternal(expr, parent, data)
    [:const, args...] => :(const $(compile(args[1].args[1], args[1], data)) = $(compile(args[1].args[2], args[1], data)))
    [:let, args...] => compilelet(expr, parent, data)
    [:case, args...] => compilecase(expr, parent, data)
    [:typealias, args...] => compiletypealias(expr, parent, data)
    [:lambda, args...] => :($(compile(args[1], expr, data)) -> $(compile(args[2], expr, data)))
    [:list, args...] => :([$(map(x -> compile(x, expr, data), expr.args)...)])
    [:call, args...] => compilecall(expr, parent, data)
    [:field, args...] => :($(compile(expr.args[1], expr, data)).$(compile(expr.args[2], expr, data)))
    [args...] => throw(AutumnCompileError())
  end
end

function compile(expr, parent::AExpr, data::Dict{String, Any})
  expr
end

function compileassign(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  type = haskey(data["types"], (expr.args[1], parent)) ? data["types"][(expr.args[1], parent)] : nothing
  if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
    if type !== nothing
      args = compile(expr.args[2].args[1], parent, data).args
      argTypes = type.args[1:(end-1)]
      tuples = [(arg, type) for arg in args, type in argTypes]
      typedArgExprs = map(x -> :($(x[1])::$(x[2])), tuples)
      quote 
        function $(compile(expr.args[1], expr, data))($(typedArgExprs...))::$(type.args[end])
          $(compile(expr.args[2].args[2], expr.args[2], data))  
        end
      end 
    else
      quote 
        function $(compile(expr.args[1], expr, data))($(compile(expr.args[2].args[1], expr.args[2], data).args...))
            $(compile(expr.args[2].args[2], expr.args[2], data))  
        end 
      end          
    end
  else
      if parent !== nothing && (parent.head == :program || parent.head == :external)
      push!(data["historyVars"], expr.args[1])
        if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
          push!(data["initnextVars"], expr)
        elseif (parent.head == :program)
          push!(data["liftedVars"], expr)
        end
        :()
      else
        if type !== nothing
          :($(compile(expr.args[1], expr, data))::$(compile(type, parent, data)) = compile(expr.args[2], expr, data))
        else
            :($(compile(expr.args[1], expr, data)) = $(compile(expr.args[2], expr, data)))
        end
      end
  end
end

function compiletypedecl(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  data["types"][(expr.args[1], parent)] = expr.args[2]
  :()
end

function compileexternal(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  push!(data["externalVars"], expr.args[1].args[1])
  push!(data["historyVars"], expr.args[1].args[1])
  :()
end

function compiletypealias(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
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

function compilelet(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  quote
    $(vcat(map(x -> compile(x, expr, data), expr.args[1]), compile(expr.args[2], expr, data))...)
  end
end

function compilecase(expr::AExpr, parent::AExpr, data::Dict{String, Any})::Expr
  quote 
    MLStyle.@match $(compile(expr.args[1], expr, data)) begin
      $(map(x -> :($(compile(x.args[1], x, data)) => $(compile(x.args[2], x, data))), expr.args[3:end])...)
    end
  end
end

function compilecall(expr::AExpr, parent::AExpr, data::Dict{String, Any})
  fnName = expr.args[1]
  if !(fnName in binaryOperators) && fnName != :prev
    :($(fnName)($(map(x -> compile(x, expr, data), expr.args[2:end])...)))
  elseif fnName == :prev
    :($(Symbol(string(expr.args[2]) * "Prev"))($(map(x -> compile(x, expr, data), expr.args[3:end])...)))
  elseif fnName != :(==)        
    :($(fnName)($(compile(expr.args[2], expr, data)), $(expr.args[3])))
  else
    :($(compile(expr.args[2], expr, data)) == $(compile(expr.args[3], expr, data)))
  end
end

function compileinitnext(aexpr, data)
  initFunction = quote
    function init()
      $(map(x -> :(global $(compile(x.args[1], x, data)) = $(compile(x.args[2].args[1], x.args[2], data))), data["initnextVars"])...)
      $(map(x -> :(global $(compile(x.args[1], x, data)) = $(compile(x.args[2], x, data))), data["liftedVars"])...)
      $(map(x -> :($(Symbol(string(x)*"History"))[time] = deepcopy($(compile(x, aexpr, data)))), data["historyVars"])...)
    end
   end
  nextFunction = quote
    function next($(map(x -> compile(x, aexpr, data), data["externalVars"])...))
      global time += 1
      $(map(x -> :(global $(compile(x.args[1], x, data)) = $(compile(x.args[2].args[2], x.args[2], data))), data["initnextVars"])...)
      $(map(x -> :(global $(compile(x.args[1], x, data)) = $(compile(x.args[2], x, data))), data["liftedVars"])...)
      $(map(x -> :($(Symbol(string(x) * "History"))[time] = deepcopy($(compile(x, aexpr, data)))), data["historyVars"])...)
    end
   end
   [initFunction, nextFunction]
end

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