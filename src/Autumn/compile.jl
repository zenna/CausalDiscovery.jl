"Compilation to Julia (and other targets, if you want)"
module Compile

using ..AExpressions
using ..Program
using ..CompileUtils: compile, compilebuiltin, compileinitnext, compileprevfuncs, AutumnCompileError
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

end