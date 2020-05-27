"Autumn SubExpressions"
module SubExpressions

using ..AExpressions
using ..Util

export SubExpr,
       subexpr,
       resolve,
       update,
       subexprdfs,
       subexprs
       
"Subexpression of `parent::AE` indicated by pointer `p::P`"
struct SubExpr{AExpr, P}
  parent::AExpr
  pointer::P
end

subexpr(aexpr, id) = SubExpr(aexpr, id)
subexpr(aexpr, id::Integer) = SubExpr(aexpr, [id])
subexpr(::SubExpr) = error("Cannot take subexpression of subexpression, yet")

"Returns subexpressions that are children"
function AExpressions.args(subexpr::SubExpr)
  q = g(resolve(subexpr))
  [SubExpr(subexpr.parent, append(subexpr.pointer, i)) for i = 1:length(q)]
end
g(aex::AExpr) = aex.args
g(x) = []
append(xs::AbstractVector, x) = [xs; x]

"Resolve Value pointed to by `subexpr`"
function resolve(subexpr::SubExpr)
  ex = subexpr.parent
  for id in subexpr.pointer
    ex = arg(ex, id)
  end
  ex
end

"""Update subexpr.parent such that `subexpr` is `newexpr`

```
prog = au\"\"\"
(program
  (: x Int)
  (= x 3)
  (= y (initnext (+ 1 2) (/ 3 this)))
  (= z (f 1 2))
)\"\"\"
.push(w)

subexpr_ = subexpr(prog, [2])

prog2 = au\"\"\"(= x 4000)\"\"\"
update(subexpr_, prog2)
```
\"\"\"

```
"""
function update(subexpr::SubExpr, newexpr)
  function subchild(expr, pos)
    # @show pos, subexpr.pointer
    # @show pos == subexpr.pointer
    pos == subexpr.pointer ? newexpr : expr
  end
  postwalkpos(subchild, subexpr.parent)
end

"Depth first search of subexpressions"
function subexprdfs(subexpr::SubExpr)
  s = SubExpr[]
  res = SubExpr[]
  push!(s, subexpr)
  discovered = Set{SubExpr}()
  while !isempty(s)
    v = pop!(s)
    push!(res, v)
    if v ∉ discovered
      push!(discovered, v)
      for subexpr in args(v)
        push!(s, subexpr)
      end
    end
  end
  res

  # What's wrong with this
  # 1. we're not using the result 
  # 2. push pop needs better data structure
  # 3. not iterator friedly
  # 4. will be hashing these sexpr, which is slow
  # 5. args(v) undefiined on most things ERR
  # 6. args(v) doesn't returb subexpression ERR
end

# Use DFS by default
subexprs(x) = subexprdfs(x)

# Base.iterate(S::SubExpr, state)


subexprdfs(aexpr::AExpr) =
  subexprdfs(subexpr(aexpr, Int[]))

Base.show(io::IO, subexpr::SubExpr) =
  print(io, "Subexpression @ ", subexpr.pointer, ":\n", subexpr.parent, " => \n", resolve(subexpr), "\n")

end