"Compilation to Julia (and other targets, if you want)"
module Compile2

using ..AExpressions
using ..Program

export toRepr2

struct AutumnCompileError <: Exception
  msg
end

fixedSymbols = [:+, :-, :/, :*, :&&, :||, :>=, :<=, :>, :<, :(==)]

AutumnCompileError() = AutumnCompileError("")


### DATA ###
data = Dict([("historyVars" => []),
              ("externalVars" => []),
              ("initnextVars" => []),
              ("liftedVars" => []),
              ("types" => Dict())])

### HELPER FUNCTIONS ###
function toRepr2(expr::AExpr, parent=nothing)
  if expr.head == :if
    cond = expr.args[1]
    then = expr.args[2]
    els = expr.args[3]
    :( $(toRepr2(cond, expr)) ? $(toRepr2(then, expr)) : $(toRepr2(els, expr)))
    # string("(",toRepr2(cond, expr), ") ? ", toRepr2(then, expr), " : ", toRepr2(els, expr), "\n")
  elseif expr.head == :assign
    type = haskey(data["types"], (expr.args[1], parent)) ? data["types"][(expr.args[1], parent)] : nothing
    if (typeof(expr.args[2]) == AExpr && expr.args[2].head == :fn)
      if type !== nothing
        args = toRepr2(expr.args[2].args[1]).args[2]
        argTypes = type.args[1:(end-1)]
        tuples = [(arg, type) for arg in args, type in argTypes]
        typedArgExprs = map(x -> :($(x[1])::$(x[2])), tuples)
        quote 
          function $(toRepr2(expr.args[1]))($(typedArgExprs...))::$(type.args[end])
            $(toRepr2(expr.args[2].args[2]))  
          end
        end 
      else
        quote 
          function $(toRepr2(expr.args[1]))($(toRepr2(expr.args[2].args[1]).args[2]...))
              $(toRepr2(expr.args[2].args[2]))  
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
                :($(toRepr2(expr.args[1]))::$(toRepr2(type)) = toRepr2(expr.args[2]))
            else
                :($(toRepr2(expr.args[1])) = $(toRepr2(expr.args[2])))
            end
        end
    end
  elseif expr.head == :typedecl
    data["types"][(expr.args[1], parent)] = expr.args[2]
    :()
    # ""
  elseif expr.head == :external
    push!(data["externalVars"], expr.args[1].args[1])
    push!(data["historyVars"], expr.args[1].args[1])
    :()
    # ""
  elseif expr.head == :const
    Meta.parse(string("const ", string(toRepr2(expr.args[1], expr)), "\n"))
  elseif expr.head == :let 
    quote
      $(vcat(map(x -> toRepr2(x, expr), expr.args[1]), toRepr2(expr.args[2]))...)
    end
    # string(join(map(x -> toRepr2(x, expr), expr.args[1]),"\n"), toRepr2(expr.args[2]))
  elseif expr.head == :case # FIX
    name = expr.args[1]
    Meta.parse(string("if ", string(toRepr2(name)), " == ", string(toRepr2(expr.args[2].args[1])), "\n", 
      string(toRepr2(expr.args[2].args[2])), "\n", 
      join(map(x -> (x.args[1] == :_) ?
          string("else\n", string(toRepr2(x.args[2]))) :
          string("elseif ", string(toRepr2(name)), " == ", string(toRepr2(x.args[1])), "\n", string(toRepr2(x.args[2])), "\n"), expr.args[3:end])),
    "\nend"))
  elseif expr.head == :typealias
    name = expr.args[1]
    fields = map(field -> (
      :($(field.args[1])::$(field.args[2]))
    ), expr.args[2].args)
    quote
      struct $(name)
          $(fields...) 
      end
    end
  elseif expr.head == :lambda
    :($(toRepr2(expr.args[1])) -> $(toRepr2(expr.args[2])))
    # string(toRepr2(expr.args[1]), " -> " , toRepr2(expr.args[2]))
  elseif expr.head == :list
    quote
      $(map(toRepr2, expr.args))
    end
    # string("[",join(map(toRepr2, expr.args),","),"]")
  elseif expr.head == :call
    fnName = expr.args[1]
    if !(fnName in fixedSymbols) && fnName != :prev
      :($(fnName)($(map(toRepr2, expr.args[2:end])...)))
      # string(toRepr2(fnName), "(", join(map(toRepr2, expr.args[2:end]), ", "), ")")
    elseif fnName == :prev
      :($(Symbol(string(expr.args[2]) * "Prev"))($(map(toRepr2, expr.args[3:end])...)))
      # string(toRepr2(expr.args[2]),"Prev(",join(map(toRepr2, expr.args[3:end])),")")
    elseif fnName != :(==)        
      :($(fnName)($(toRepr2(expr.args[2])), $(expr.args[3])))
      # string("(", toRepr2(expr.args[2]) ,toRepr2(fnName), toRepr2(expr.args[3]), ")")
    else
      :($(toRepr2(expr.args[2])) == $(toRepr2(expr.args[3])))
      # string("(", toRepr2(expr.args[2]) ," == ", toRepr2(expr.args[3]), ")")
    end
  elseif expr.head == :field
    :($(toRepr2(expr.args[1])).$(toRepr2(expr.args[2])))
    # string(toRepr2(expr.args[1]), ".", toRepr2(expr.args[2]))
  else
    throw(AutumnCompileError(string("expr.head is undefined: ",repr(expr.head))))
  end
end

function toRepr2(expr, parent=nothing)
  expr
end

function typedFnHelper(expr, type)
  args = expr.args[1].args
  argTypes = type.args[1:(end-1)]
  tuples = [(arg, type) for arg in args, type in argTypes]
  string("(", join(map(x -> string(toRepr2(x[1]), "::", toRepr2(x[2])), tuples), ", "), ")::", toRepr2(type.args[end]),"\n", toRepr2(expr.args[2]))    
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

