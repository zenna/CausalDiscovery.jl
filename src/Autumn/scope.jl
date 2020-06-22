module Scope
using ..SubExpressions
using ..AExpressions
using MLStyle

export varsavailable

# # Scope

abstract type Terminal end
struct ProgramNode <: Terminal end
struct LetNode <: Terminal end
struct FnNode <: Terminal end

# "Returns a predicate `p` such that `p(n)` tests whether `n is a node of type `T``"
# isnode(::Type{T}) where {T <: Terminal} = let \tau = T()

"""

variables available (i.e., in scope) at to `subex`

```
prog = au\"\"\"(program
                 (= x 3)
                 (= y (fn (a b c) (+)))
                 (= z (fn (q t) (+ q t))))
              \"\"\"

subex1 = subexpr(prog, [2, 2, 3])
subex2 = subexpr(prog, [1, 2])
varsavailable(subex1)
```

"""
function varsavailable(subex::SubExpr)
  vars = Symbol[]
  addvars(subex, vars_) = vcat(vars_, varsproduced(subex))
  parentwalk(addvars, subex, vars)
end

"variables produced by `subex`"
function varsproduced(subex::SubExpr)
  ex = Expr(resolve(subex))
  MLStyle.@match ex begin
    Expr(:program, args...) => varsproduced(subex, ProgramNode())
    Expr(:let, args...)     => varsproduced(subex, LetNode())
    Expr(:fn, args...)      => varsproduced(subex, FnNode())
    _                       => Symbol[]
  end
  ## Find examples in scope
  ## What are the variables in 
end

function varsproduced(subex::SubExpr, ::ProgramNode)::Vector{Symbol}
  ## Find any assigments
  function cap(subex::SubExpr)
    ex = Expr(resolve(subex))
    MLStyle.@match ex begin
      Expr(:assign, x::Symbol, v) => x
      _                           => nothing
    end
  end
  assigns = Symbol[]
  assigns = collect(filter(!isnothing, map(cap, args(subex))))
end


## TODO
## What this doesn't capture
## In a let block, the arguments defined before, at the same level

# let
#   q = 21
#   z = let 
#         x = 3
#         y = 2
#       in
#       o + y
#   o = 3 + z
#   in
#     z + 3
# o = 21
# end


## Julia scoping rules
## Two types of scope, global, vs nested
##

ancestors(::SubExpr) = ..
siblings(::SubExpr) = ..

"Does `a` project variables to `b`" 
doesaprojectb(a, b) = parent(a) ∈ ancestors(b)
  

end