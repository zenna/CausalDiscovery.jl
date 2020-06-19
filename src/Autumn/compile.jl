"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program
using MLStyle 

export compiletojulia

struct AutumnCompileError <: Exception
  msg
end

fixedSymbols = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]

AutumnCompileError() = AutumnCompileError("")

"Compile `aexpr` into `program::Program`"
function compiletojulia(aexpr::AExpr)::Expr

  ### DATA ###
  data = Dict([("historyVars" => []),
               ("externalVars" => []),
               ("initnextVars" => []),
               ("liftedVars" => []),
               ("types" => Dict())])
  
  ### HELPER FUNCTIONS ###
  function toRepr(expr::AExpr, parent=nothing)
    arr = [expr.head, expr.args...]
    res = MLStyle.@match arr begin
      [:if, args...] => string("(",toRepr(expr.args[1], expr), ") ? ", toRepr(expr.args[2], expr), " : ", toRepr(expr.args[3], expr), "\n")
      [:assign, args...] => toReprAssign(expr, parent, data)
      [:typedecl, args...] => toReprTypeDecl(expr, parent, data)
      [:external, args...] => toReprExternal(expr, data)
      [:const, args...] => string("const ", toRepr(expr.args[1], expr), "\n")
      [:let, args...] => string(join(map(x -> toRepr(x, expr), expr.args[1]),"\n"), toRepr(expr.args[2]))
      [:case, args...] => toReprCase(expr)
      [:typealias, args...] => toReprTypeAlias(expr)
      [:fn, args...] => string("function(", toRepr(expr.args[1])[2:(end-1)], ")\n", toRepr(expr.args[2]), "\nend\n") 
      [:lambda, args...] => string(toRepr(expr.args[1]), " -> " , toRepr(expr.args[2]))
      [:list, args...] => string("[",join(map(toRepr, expr.args),","),"]")
      [:call, args...] => toReprCall(expr)
      [:field, args...] => string(toRepr(expr.args[1]), ".", toRepr(expr.args[2]))
      [args...] => throw(AutumnCompileError())
    end
  end

  function toRepr(expr::AbstractArray, parent=nothing)::String
    if expr == [] 
      "" 
    elseif (expr[1] == :List)
      string("Array{", toRepr(expr[2:end]),"}")
    else
      string(expr[1])
    end
  end
  
  function toRepr(expr, parent=nothing)::String
    string(expr)
  end
  
  function typedFnHelper(expr, type)
    args = expr.args[1].args
    argTypes = type.args[1:(end-1)]
    tuples = [(arg, type) for arg in args, type in argTypes]
    string("(", join(map(x -> string(toRepr(x[1]), "::", toRepr(x[2])), tuples), ", "), ")::", toRepr(type.args[end]),"\n", toRepr(expr.args[2]), "\nend\n")    
  end
  
  function toReprAssign(expr, parent, data)
    type = haskey(data["types"], (expr.args[1], parent)) ? data["types"][(expr.args[1], parent)] : nothing
    if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
      if type !== nothing
        string("function ", toRepr(expr.args[1]), typedFnHelper(expr.args[2], type), "\n")              
      else
        string(toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n")            
      end
    else
      if parent !== nothing && (parent.head == :program || parent.head == :external)
        push!(data["historyVars"], expr.args[1])
        if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
          push!(data["initnextVars"], expr)
        elseif (parent.head == :program)
          push!(data["liftedVars"], expr)
        end
        ""
      else
        if type !== nothing
          string(toRepr(expr.args[1]), "::", toRepr(type), " = ", toRepr(expr.args[2]), "\n")
        else
          string(toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n")            
        end
      end
    end
  end
  
  function toReprTypeDecl(expr, parent, data)
    data["types"][(expr.args[1], parent)] = expr.args[2]
    ""
  end
  
  function toReprExternal(expr, data)
    push!(data["externalVars"], expr.args[1].args[1])
    push!(data["historyVars"], expr.args[1].args[1])
    ""
  end
  
  function toReprCase(expr)
    name = expr.args[1]
      string("if ", toRepr(expr.args[1]), " == ", toRepr(expr.args[2].args[1]), "\n", 
        toRepr(expr.args[2].args[2]), "\n", 
        join(map(x -> (x.args[1] == :_) ?
            string("else\n", toRepr(x.args[2])) :
            string("elseif ", toRepr(expr.args[1]), " == ", toRepr(x.args[1]), "\n", toRepr(x.args[2]), "\n"), expr.args[3:end])),
      "\nend")
  end
  
  function toReprTypeAlias(expr)
    name = expr.args[1]
    fields = map(field -> (
      string(repr(field.args[1])[2:end], "::", repr(field.args[2])[2:end])
    ), expr.args[2].args)
    string("struct ", toRepr(name), "\n", join(fields, "\n"), "\nend\n")
  end
  
  function toReprCall(expr)
    fnName = expr.args[1]
    if !(fnName in fixedSymbols) && fnName != :prev
      string(toRepr(fnName), "(", join(map(toRepr, expr.args[2:end]), ", "), ")")
    elseif fnName == :prev 
      string(toRepr(expr.args[2]),"Prev(",join(map(toRepr, expr.args[3:end])),")")
    elseif fnName != :(==)
      string("(", toRepr(expr.args[2]) ,toRepr(fnName), toRepr(expr.args[3]), ")")
    else
      string("(", toRepr(expr.args[2]) ," == ", toRepr(expr.args[3]), ")")
    end
  end

  ### COMPILATION ###
  if (aexpr.head == :program)
    args = map(arg -> toRepr(arg, aexpr), aexpr.args)
    # handle history 
    initGlobalVars = map(expr -> string(toRepr(expr), " = nothing\n"), data["historyVars"])
    push!(initGlobalVars, "time = 0\n")
    initHistoryDictArgs = map(expr -> string(toRepr(expr),"History = Dict{Int64, Any}()\n"), data["historyVars"])
    # handle initnext
    initFunction = string("function init()\n", 
                          join(map(x -> string("\t global ",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[1]), "\n"), data["initnextVars"])),
                          "\n", 
                          join(map(expr -> string("global ",toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n"), data["liftedVars"])),
                          join(map(expr -> string(toRepr(expr),"History[time] = deepcopy(",toRepr(expr),")\n"), data["historyVars"]),"\n"), 
                          "\nend\n")
    nextFunction = string("function next(", 
                          join(map(x -> toRepr(x), data["externalVars"]),","), 
                          ")\n global time += 1\n", 
                          join(map(x -> string("\t global ",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[2]), "\n"), data["initnextVars"])),
                          "\n", 
                          join(map(expr -> string("global ",toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n"), data["liftedVars"])),
                          "\n",
                          join(map(expr -> string(toRepr(expr),"History[time] = deepcopy(",toRepr(expr),")\n"), data["historyVars"]),"\n"), 
                          "\nend\n")
    push!(args, initFunction, nextFunction)
    
    # construct built-in functions
    prevFunctions = join(map(x -> string(toRepr(x),"Prev = function(n::Int=0) \n", toRepr(x),"History[time - n]\nend\n"), data["historyVars"])) 
    occurredFunction = """function occurred(click)\n click !== nothing \nend\n"""
    uniformChoiceFunction = """uniformChoice = function(freePositions)\n freePositions[rand(Categorical(ones(length(freePositions))/length(freePositions)))] \nend\n"""
    clickType = """struct Click\n x::Int\n y::Int\n end\n"""
    args = vcat(["quote\n module CompiledProgram \n export init, next \n using Distributions\n"], initGlobalVars, initHistoryDictArgs, prevFunctions, occurredFunction, uniformChoiceFunction, clickType, args,["\nend\nend"])
    expr = Meta.parse(join(args))
    expr.args[1].head = :toplevel
    expr.args[1]
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

end
