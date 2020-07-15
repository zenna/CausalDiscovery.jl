"Code transformations to Autumn programs"
module Transform
using ..AExpressions
using ..SubExpressions
using ..Parameters
using ..Scope
using MLStyle
export sub, recursub
# using OmegaCore

"""
Expand a subexpression.

Returns a parametric representation over graphs.

x = au\"\"\"
(program
  (= x 3)
  (= y (x + ?)))
\"\"\"

hole = first(holes(x))    # Find the first hole
ϕ = expand(hole)          # Get parametric representation of hole
sub = sat(ϕ)             # Find any expression
xnew = replace(x, sub)   # Construct `x`
```
"""

abstract type NonTerminal end

struct Statement <: NonTerminal end
struct External <: NonTerminal end
struct Assignment <: NonTerminal end
struct TypeDeclaration <: NonTerminal end
struct VariableName <: NonTerminal end

# ## Values
struct ValueExpression <: NonTerminal end
struct Literal <: NonTerminal end
struct FunctionApp <: NonTerminal end
struct Lambda <: NonTerminal end
struct Let <: NonTerminal end
struct LetBindings <: NonTerminal end
struct LetBinding <: NonTerminal end

struct ArgumentList <: NonTerminal end

# ## Types
struct TypeExpression <: NonTerminal end
struct PrimitiveType <: NonTerminal end
struct CustomType <: NonTerminal end
struct FunctionType <: NonTerminal end

AExpressions.showstring(T::Q) where {Q <: NonTerminal} = "{$(Q.name.name)}"
Base.show(io::IO, nt::NonTerminal) = print(io, AExpressions.showstring(nt))

"`sub(ϕ, subexpr::SubExpr{<:Statement})`returns `parent` with subexpression subed"
function sub end

function sub(ϕ, subex::SubExpr, ::Statement)
  choice(ϕ, [External(), Assignment(), TypeDeclaration()])
  # choice(ϕ, [Assignment()])
end

function sub(ϕ, subex::SubExpr, ::External)
  AExpr(:external, TypeDeclaration())
end

# ## Types
function sub(ϕ, subex::SubExpr, ::TypeDeclaration)
  AExpr(:typedecl, VariableName(), TypeExpression())
end

function sub(ϕ, subex::SubExpr, ::TypeExpression)
  choice(ϕ, [PrimitiveType(), FunctionType()])
end

function sub(ϕ, subex::SubExpr, ::PrimitiveType)
  primtypes = [Int, Float64, Bool]
  choice(ϕ, primtypes)
end

function sub(ϕ, subex::SubExpr, ::FunctionType)
  AExpr(:functiontype, TypeExpression(), TypeExpression())
end

# ## Declarations
function sub(ϕ, subex::SubExpr, ::Assignment)
  # @show vars_in_scope(subex)
  AExpr(:assign, VariableName(), ValueExpression())
end

const VARNAMES = 
  map(Symbol ∘ join,
      Iterators.product('a':'z', 'a':'z', 'a':'z'))[:]

function sub(ϕ, subex::SubExpr, ::VariableName)
  ## Choose a variable name that is correct in this context
  # Choose a variable that is not in extandvars
  # @show vars_in_scope(subex)
  choice_ = choice(ϕ, VARNAMES)
  # Choice(VARNAMES)(id, φ) |ᶜ var -> var ∉ vars_in_scope(subex)
end

# function ssub(φ, subex::SubExpr, ::VariableOK)
#   Choice(VARNAMES)(id, φ) |ᶜ var -> var ∈ vars_in_scope(subex)
# end

function sub(ϕ, subex::SubExpr, ::ValueExpression)
  choice(ϕ, [Literal(), FunctionApp(), Lambda(), Let(), VariableName()])
end



function sub(ϕ, subex::SubExpr, ::Lambda)
  AExpr(:fn, ArgumentList(), ValueExpression())
end

function sub(ϕ, subex::SubExpr, ::LetBindings)
  MAXARGS = 4
  nargs = choice(ϕ, 1:MAXARGS)
  args = [Assignment() for i = 1:nargs]
  AExpr(:letargs, args...)
end

function sub(ϕ, subex::SubExpr, ::Let)
  AExpr(:let, LetBindings(), ValueExpression())
end

function sub(ϕ, subex::SubExpr, ::ArgumentList)
  MAXARGS = 4
  nargs = choice(ϕ, 1:MAXARGS)
  args = [VariableName() for i = 1:nargs]
  AExpr(:args, args...)
end

function sub(ϕ, subex::SubExpr, ::FunctionApp)
  # TODO: Need type constraitns
  AExpr(:call, ValueExpression(), ValueExpression(), ValueExpression())
end

function sub(ϕ, subex::SubExpr, ::Literal)
  # FINISHME: Do type inference
  literaltype = Int
  choice(ϕ, literaltype)
end

function sub(ϕ, subexpr::SubExpr)
  aex = resolve(subexpr)
  MLStyle.@match aex begin
    Statement => sub(ϕ, subexpr, aex)
    # FIXME: well this must be wrong
  end
end

allnonterminals(aex) = 
  filter(x-> resolve(x) isa NonTerminal, subexprs(aex))

"Stop when the graph is too large"
stopwhenbig(subexpr; sizelimit = 100) = nnodes(subex) > sizelimit

"Returns a stop function that stops after `n` calls"
stopaftern(n) = (i = 1; (ϕ, subexpr) -> (i += 1; i > n))

"Recursively fill `subex` until `stop`"
function recursub(ϕ, aex::AExpr, stop = stopaftern(100))
  #FIXME, what if i want stop to have state
  # FIXME: account for fact that there is none
  while !stop(ϕ, aex)
    nts = allnonterminals(aex)
    if isempty(nts)
      break
    else
      subex = choice(ϕ, nts)
      newex = sub(ϕ, subex)
      aex = update(subex, newex)
      println("#### Done\n")
    end
  end
  aex
end



end
