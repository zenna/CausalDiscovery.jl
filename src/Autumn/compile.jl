"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program

struct AutumnCompileError <: Exception
  msg
end

AutumnCompileError() = AutumnCompileError("")

historyVars = []
externalVars = []
initnextVars = []

"Compile `aexpr` into `program::Program`"
function compileToJulia(aexpr::AExpr)::AProgram
  if (aexpr.head == :program)
    args = map(arg -> toRepr(arg, aexpr), aexpr.args)
    
    # handle initnext and history 
    globalVars = map(expr -> string(toRepr(expr.args[1], " = Nothing\n"), historyVars))
    push!(globalVars, "time = 0\n")
    initHistoryDictArgs = map(expr -> string(toRepr(expr.args[1]),"History = Dict{Any, Any}"), historyVars)
    
    initnextFunctionArgs = []
    initFunction = string("function init()\n", join(map(x -> string("\t",toRepr(x.args[1]), " == ", toRepr(x.args[2].args[1]), "\n")), initnextFunctionArgs), "\nend")
    nextFunction = string("function next(", join(map(x -> toRepr(x.args[1].args[1]), externalVars)), ")\n", join(map(x -> string("\t",toRepr(x.args[1]), " == ", toRepr(x.args[2].args[1]), "\n")), initnextFunctionArgs),"\n", join(map(expr -> string(toRepr(expr.args[1]),"History[time] = deepcopy(",toRepr(expr.args[1],")\n")), historyVars),"\n"), "\nend")

    push!(args, initFunction, nextFunction)
    args = vcat(args, globalVars, initHistoryDictArgs)

    Expr(:block, map(Meta.parse, split(join(args), "\n")...))
  else
    throw(AutumnCompileError())
  end
end

function toRepr(expr::AExpr, parent::Union{AExpr, Nothing}=Nothing)::String
  if expr.head == :if
    var = parent.args[1]
    cond = expr.args[1]
    then = expr.args[2]
    els = expr.args[3]
    string("if (", toRepr(cond), ")\n", toRepr(var), " = ", toRepr(then), "\nelse", toRepr(var), " = ", toRepr(els), "\nend")
  elseif expr.head == :assign
    if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :if)
      toRepr(expr.args[2], expr)
    elseif expr.args[2].head == :initnext
      push!(initnextVars, expr)
    else
      if parent.head == :program || parent.head == :external
        push!(historyVars, expr)
      end
      string(toRepr(expr.args[1]), " = ", toRepr(expr.args[2]), "\n")
    end
  elseif expr.head == :typedecl
    string(toRepr(expr.args[1], " : ", toRepr(expr.args[2])), "\n")
  elseif expr.head == :external
    push!(externalVars, expr)
    string("external ", toRepr(expr.args[1]), "\n")
  elseif expr.head == :const
    string("const ", toRepr(expr.args[1]), "\n")
  elseif expr.head == :let
    string(join(map(toRepr, expr.args[1]),"\n"), toRepr(expr.args[2]))
  elseif expr.head == :case
    name = expr.args[1]
    cases = expr.args[2]
    string("if ", toRepr(name), " == ", toRepr(cases[1].args[1]), "\n", toRepr(cases[1].args[2]), map(x -> string("elseif ", toRepr(name), " == ", toRepr(x.args[1]), "\n", toRepr(x.args[2]), "\n"), cases[2:end]), "\nend") #TODO
  elseif expr.head == :typealias
    name = expr.args[1]
    fields = map(field -> (
      string(repr(field.args[1])[2:end], "::", repr(field.args[2])[2:end])
    ), expr.args[2].args)
    string("struct ", repr(name)[2:end], "\n", join(fields, "\n"), "end")
  elseif expr.head == :fn
    string("function", toRepr(expr.args[1]), "\n", join(map(toRepr, expr.args[2], "\n")), "\nend\n")    
  elseif expr.head == :lambda
    string(toRepr(expr.args[1]), " -> " , toRepr(expr.args[2]))
  elseif expr.head == :list
    repr(expr.args)[4:end]
  elseif expr.head == :call
    string(toRepr(expr.args[1]), "(", join(map(repr, expr.args[2:end]), ", "), ")")
  else
    throw(AutumnCompileError())
  end
end

function toRepr(expr::Symbol)::String
  repr(expr)[2:end]
end

function toRepr(expr)::String
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
