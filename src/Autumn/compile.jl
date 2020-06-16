"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program

export compileToJulia, toRepr

struct AutumnCompileError <: Exception
  msg
end

fixedSymbols = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]

historyVars = []
externalVars = []
initnextVars = []
types = []

AutumnCompileError() = AutumnCompileError("")

"Compile `aexpr` into `program::Program`"
function compileToJulia(aexpr::AExpr) #::AProgram
  if (aexpr.head == :program)
    args = map(arg -> toRepr(arg, aexpr), aexpr.args)
    println("hi 1")
    # handle history 
    initGlobalVars = map(expr -> string(toRepr(expr), " = Nothing\n"), historyVars)
    push!(initGlobalVars, "time = 0\n")
    initHistoryDictArgs = map(expr -> string(toRepr(expr),"History = Dict{Any, Any}\n"), historyVars)
    println("hi 2")
    # handle initnext
    println(string("externalVars: ", repr(externalVars)))
    println(string("initnextVars: ", repr(initnextVars)))
    println(string("historyVars: ", repr(historyVars)))
    initFunction = string("function init()\n", 
                          join(map(x -> string("\t",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[1]), "\n"), initnextVars)), 
                          "\nend\n")
    println("hi 2.5")
    nextFunction = string("function next(", 
                          join(map(x -> toRepr(x.args[1].args[1]), externalVars),","), 
                          ")\n time += 1\n", 
                          join(map(x -> string("\t",toRepr(x.args[1]), " = ", toRepr(x.args[2].args[2]), "\n"), initnextVars)),
                          "\n", 
                          join(map(expr -> string(toRepr(expr),"History[time] = deepcopy(",toRepr(expr),")\n"), historyVars),"\n"), 
                          "\nend\n")
    println("hi 3")
    push!(args, initFunction, nextFunction)
    println("hi 4")
    println("nextFunction")
    println(nextFunction)
    println("nextFunction end")
    args = vcat(["quote\n"],args, initGlobalVars, initHistoryDictArgs, ["end"])
    println(join(args))
    Meta.parse(join(args)).args[1]
  else
    throw(AutumnCompileError())
  end
end

function toRepr(expr::AExpr, parent=Nothing)::String
  if expr.head == :if
    cond = expr.args[1]
    then = expr.args[2]
    els = expr.args[3]
    string("(",toRepr(cond, expr), ") ? ", toRepr(then, expr), " : ", toRepr(els, expr), "\n")
  elseif expr.head == :assign
   if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :initnext)
      println("HERE")
      push!(initnextVars, expr)
      ""
    else
      if parent != Nothing && (parent.head == :program || parent.head == :external)
        if !(typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
          push!(historyVars, expr.args[1])
        end
        ""
      end
      string(toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n")
    end
  elseif expr.head == :typedecl
    push!(types, expr)
    ""
  elseif expr.head == :external
    println("HELLO")
    push!(externalVars, expr)
    push!(historyVars, expr.args[1].args[1])
    ""
  elseif expr.head == :const
    string("const ", toRepr(expr.args[1], expr), "\n")
  elseif expr.head == :let
    string(join(map(x -> toRepr(x, expr), expr.args[1]),"\n"), toRepr(expr.args[2]))
  elseif expr.head == :case
    name = expr.args[1]
    cases = expr.args[2]
    string("if ", toRepr(name), " == ", toRepr(cases[1].args[1]), "\n", toRepr(cases[1].args[2]), map(x -> string("elseif ", toRepr(name), " == ", toRepr(x.args[1]), "\n", toRepr(x.args[2]), "\n"), cases[2:end]), "\nend") #TODO
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
    if !(fnName in fixedSymbols)
      string(toRepr(fnName), "(", join(map(toRepr, expr.args[2:end]), ", "), ")")
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

function toRepr(expr::Symbol, parent=Nothing)::String
  repr(expr)[2:end]
end

function toRepr(expr, parent=Nothing)::String
  repr(expr)
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
