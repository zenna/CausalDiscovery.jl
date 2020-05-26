"Code transformations to Autumn programs"
module Transform
using ..AExpressions
using ..SubExpressions
using ..Parameters
using MLStyle
export expand, sub, recursub
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

# Non-terminal nodes to be replaced

# FIXME: Do these fit into all the expr types
# FIXME: Some naming convention

abstract type NonTerminal end

struct Statement <: NonTerminal end
struct External <: NonTerminal end
struct Assignment <: NonTerminal end
struct TypeDeclaration <: NonTerminal end
struct VariableName <: NonTerminal end
struct ValueExpression <: NonTerminal end
struct Literal <: NonTerminal end

AExpressions.showstring(T::NonTerminal) = "{$(string(typeof(T)))}"
Base.show(io::IO, nt::NonTerminal) = print(io, AExpressions.showstring(nt))

"`sub(ϕ, subexpr::SubExpr{<:Statement})`returns `parent` with subexpression subed"
function sub end

function sub(ϕ, sexpr::SubExpr, ::Statement)
  choice(ϕ, [External(), Assignment(), TypeDeclaration()])
end

function sub(ϕ, ::SubExpr{Assignment})
  AssignExpr(VariableName(), ValueExpression())
end

function sub(ϕ, ::SubExpr{VariableName})
  ## Choose a variable name that is correct in this context
  extantvars = # Look through parents
  # Choose a variable that is not in extandvars
  choice(ϕ, [:x, :y, :z])
end

function sub(ϕ, ::SubExpr{ValueExpression})
  choice(ϕ, [Literal(), FunctionApp()])
end

function sub(ϕ, ::SubExpr{Literal})
  # FINISHME: Do type inference
  choice(ϕ, [1, 2, 3])
end

function sub(ϕ, subexpr::SubExpr)
  aex = resolve(subexpr)
  MLStyle.@match aex begin
    Statement => sub(ϕ, subexpr, aex)
  end
end

"(Parametrically) find a non-terminal subexpr"
function findnonterminal(ϕ, sexpr)
  # Walk the graph, and in the presence of a non-terminal, decide whether to stop or not
  allnonterminals = # FINISHME
  choice(ϕ, allnonterminals)
end

"Stop when the graph is too large"
stopwhenbig(subexpr; sizelimit = 100) = nnodes(sexpr) > sizelimit

"Returns a stop function that stops after `n` calls"
stopaftern(n) = (i = 1; (ϕ, subexpr) -> (i += 1; i > n))

"Recursively fill `sexpr` until `stop`"
function recursub(ϕ, subexpr, stop = stopaftern(10))
  #FIXME, what if i want stop to have state
  while !stop(ϕ, subexpr)
    newexpr = sub(ϕ, subexpr)
    aexpr = update(subexpr, newexpr)
    subexpr = findnonterminal(ϕ, aexpr)
  end
  subexpr
end

# function sub(φ, ::SubExpr{FAppExpr})
#   #
# end

## Type specific
# function sub(ϕ, ::SubExpr{Type{Int}})
# end

## Test

## Things to consider:
## What are the lexical constraints
## - You can't use a variable before its been defined
## - If a variable is already defined you can't define it again
## - You can't use a type name if its already been used
## - You can't use a type variable if its already been used in that type definition

# Q: Are these abstract / Do they require convergence?
# Q: if for example there are no variables defined, then I won't be able to pick any variables
# Can i avoid going down a garden path
# or must i be able to backtrack

## How does type inference fit into all of this


end
