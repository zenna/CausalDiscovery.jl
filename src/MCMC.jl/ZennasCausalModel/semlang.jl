"Domain Specific Language for SEMs"
module SEMLang

# export @SEM, interpret, SEMSyntaxError
export @SEM
using ..CausalCore: ExogenousVariable, EndogenousVariable

struct SEMSyntaxError <: Exception
  msg
end

SEMSyntaxError() = SEMSyntaxError("")

"Parse exogenous variable `line`"
function parseexo(line)
  new_var = line.args[2]
  dist = line.args[3]
  :($new_var = ExogenousVariable( $(Meta.quot(new_var)), $(dist)))
end

"Parse endogenous variable"
function parseendo(line)
    line
end

"Structural Equation Model"
function SEM(sem)
  if sem.head != :block
    throw(SEMSyntaxError("@SEM expects a block expression as input"))
  end
  semlines = Expr[]
  for line in sem.args
    if typeof(line) == Expr
      if line.head == :(=)
        expr = parseendo(line)
      elseif line.head == :call
        expr = parseexo(line)
      else
        throw(SEMSyntaxError())
      end
      push!(semlines, expr)
    end    
  end
  Expr(:block, semlines...)
end

end