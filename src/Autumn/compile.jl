"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program

export compileToJulia, toRepr

struct AutumnCompileError <: Exception
  msg
end

fixedSymbols = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]

AutumnCompileError() = AutumnCompileError("")

"Compile `aexpr` into `program::Program`"
function compileToJulia(aexpr::AExpr) #::AProgram

  ### DATA ###
  data = Dict([("historyVars" => []),
               ("externalVars" => []),
               ("initnextVars" => []),
               ("initnextOther" => []),
               ("types" => [])])

  ### HELPER FUNCTION ###
  function toRepr(expr::AExpr, parent=Nothing)::String
    if expr.head == :if
      cond = expr.args[1]
      then = expr.args[2]
      els = expr.args[3]
      string("(",toRepr(cond, expr), ") ? ", toRepr(then, expr), " : ", toRepr(els, expr), "\n")
    elseif expr.head == :assign
     if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
        push!(data["initnextVars"], expr)
        push!(data["historyVars"], expr.args[1])
        ""
      else
        if parent != Nothing && (parent.head == :program || parent.head == :external)
          if !(typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
            push!(data["historyVars"], expr.args[1])
            # patch fix, will refactor
            if (parent.head == :program)
              push!(data["initnextOther"], expr)
            end
          end
          ""
        else
          string(toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n")
        end
      end
    elseif expr.head == :typedecl
      push!(data["types"], expr)
      ""
    elseif expr.head == :external
      push!(data["externalVars"], expr.args[1].args[1])
      push!(data["historyVars"], expr.args[1].args[1])
      ""
    elseif expr.head == :const
      string("const ", toRepr(expr.args[1], expr), "\n")
    elseif expr.head == :let
      string(join(map(x -> toRepr(x, expr), expr.args[1]),"\n"), toRepr(expr.args[2]))
    elseif expr.head == :case
      name = expr.args[1]
      string("if ", toRepr(name), " == ", toRepr(expr.args[2].args[1]), "\n", 
        toRepr(expr.args[2].args[2]), "\n", 
        join(map(x -> (x.args[1] == :_) ?
            string("else\n", toRepr(x.args[2])) :
            string("elseif ", toRepr(name), " == ", toRepr(x.args[1]), "\n", toRepr(x.args[2]), "\n"), expr.args[3:end])),
      "\nend")
    elseif expr.head == :typealias
      name = expr.args[1]
      fields = map(field -> (
        string(repr(field.args[1])[2:end], "::", repr(field.args[2])[2:end])
      ), expr.args[2].args)
      string("struct ", toRepr(name), "\n", join(fields, "\n"), "\nend\n")
    elseif expr.head == :fn
      string("function(", toRepr(expr.args[1])[2:(end-1)], ")\n", toRepr(expr.args[2]), "\nend\n")    
    elseif expr.head == :lambda
      string(toRepr(expr.args[1]), " -> " , toRepr(expr.args[2]))
    elseif expr.head == :list
      string("[",join(map(toRepr, expr.args),","),"]")
    elseif expr.head == :call
      fnName = expr.args[1]
      if !(fnName in fixedSymbols) && fnName != :prev
        string(toRepr(fnName), "(", join(map(toRepr, expr.args[2:end]), ", "), ")")
      elseif fnName == :prev 
        string(toRepr(fnName), uppercase(toRepr(expr.args[2])[1]), toRepr(expr.args[2])[2:end],"(",join(map(toRepr, expr.args[3:end])),")")
      elseif fnName != :(==)
        string("(", toRepr(expr.args[2]) ,toRepr(fnName), toRepr(expr.args[3]), ")")
      else
        string("(", toRepr(expr.args[2]) ," == ", toRepr(expr.args[3]), ")")
      end
    elseif expr.head == :field
      string(toRepr(expr.args[1]), ".", toRepr(expr.args[2]))
    else
      throw(AutumnCompileError(string("expr.head is undefined: ",repr(expr.head))))
    end
  end
  
  function toRepr(expr, parent=Nothing)::String
    string(expr)
  end

  ### COMPILATION ###
  if (aexpr.head == :program)
    args = map(arg -> toRepr(arg, aexpr), aexpr.args)
    # handle history 
    initGlobalVars = map(expr -> string(toRepr(expr), " = Nothing\n"), data["historyVars"])
    push!(initGlobalVars, "global time = 0\n")
    initHistoryDictArgs = map(expr -> string(toRepr(expr),"History = Dict{Any, Any}\n"), data["historyVars"])
    # handle initnext
    initFunction = string("function init()\n", 
                          join(map(x -> string("\t global ",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[1]), "\n"), data["initnextVars"])),
                          "\n", 
                          join(map(expr -> string("global ",toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n"), data["initnextOther"])),
                          "\nend\n")
    nextFunction = string("function next(", 
                          join(map(x -> toRepr(x), data["externalVars"]),","), 
                          ")\n global time += 1\n", 
                          join(map(x -> string("\t global ",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[2]), "\n"), data["initnextVars"])),
                          "\n", 
                          join(map(expr -> string("global ",toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n"), data["initnextOther"])),
                          "\n",
                          join(map(expr -> string(toRepr(expr),"History[time] = deepcopy(",toRepr(expr),")\n"), data["historyVars"]),"\n"), 
                          "\nend\n")
    push!(args, initFunction, nextFunction)
    
    # construct built-in functions
    prevFunctions = join(map(x -> string(toRepr(x),"Prev = function(n::Int=0) \n", toRepr(x),"History[time - n]\nend\n"), data["historyVars"])) 
    occurredFunction = """function occurred(click)\n click != Nothing \nend\n"""
    uniformChoiceFunction = """uniformChoice = function(freePositions)\n freePositions[rand(Categorical(ones(length(freePositions))/length(freePositions)))] \nend\n"""

    args = vcat(["quote\n using Distributions\n"], initGlobalVars, initHistoryDictArgs, prevFunctions, occurredFunction, uniformChoiceFunction,args,["end"])
    # println(join(args))
    Meta.parse(join(args)).args[1]
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
