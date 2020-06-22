"Autumn SubExpressions"
module SubExpressions

using ..AExpressions
using ..Util

export SubExpr,
       subexpr,
       resolve,
       update,
       subexprdfs,
       subexprs,
       parent,
       isroot,
       parentwalk

       
"Subexpression of `parent::AE` indicated by pointer `p::P`"
struct SubExpr{AExpr, P}
  parent::AExpr
  pointer::P
end

subexpr(aexpr, id) = SubExpr(aexpr, id)
subexpr(aexpr, id::Integer) = SubExpr(aexpr, [id])
subexpr(::SubExpr) = error("Cannot take subexpression of subexpression, yet")

"`parent(subex::SubExpr)` Parent SubExpr of `subex`"
Base.parent(subex::SubExpr) = SubExpr(subex.parent, pop(subex.pointer))

"Remove last element of `xs`"
pop(xs::AbstractVector) = xs[1:end-1]

"`subex` is is the `pop(subex)`th child of `parent(subex)`"
pos(subex::SubExpr) = subex.pointer[end]

"Is `subex` the root expression?"
isroot(subex::SubExpr) = isempty(subex.pointer)

"Head of AExpr pointed to by `subex`"
AExpressions.head(subex::SubExpr) =
  AExpressions.head(resolve(subex))

"Returns subexpressions that are children"
function AExpressions.args(subexpr::SubExpr)
  q = g(resolve(subexpr))
  (SubExpr(subexpr.parent, append(subexpr.pointer, i)) for i = 1:length(q))
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

# ## Traversal

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
  # What's wrong with this
  # 1. we're not using the result 
  # 2. push pop needs better data structure
  # 3. not iterator friedly
  # 4. will be ha       parentwalk

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
end

"""
`parentwalk(f, subex, s = f(subex))`
Walk from `subex` upwards through parents

```
prog = au\"\"\"
(program
  (= x 3)
  (= y (fn (a b c) (+ a b c))))\"\"\"

subex = subexpr(prog, [2, 2, 3])
f(x) = println(x.head)
parentwalk(subex, prog)
```
"""
function parentwalk(f, subex, s)
  while !isroot(subex)
    subex = Base.parent(subex)
    s = f(subex, s)
  end
  s
end

# Use DFS by default
subexprs(x) = subexprdfs(x)

# Base.iterate(S::SubExpr, state)

subexprdfs(aexpr::AExpr) =
  subexprdfs(subexpr(aexpr, Int[]))

# Relations

"Ancestors of `subexpr`"
ancestors(subex::SubExpr) = (parent(subex))
siblings(subex::SubExpr) = args(parent(subex))

"Siblings that have an position greater than subex"
youngersiblings(subex::SubExpr) =
  filter(sib -> pos(sib) > pos(subex), siblings(subex))

Base.show(io::IO, subexpr::SubExpr) =
  print(io, "Subexpression @ ", subexpr.pointer, ":\n", subexpr.parent, " => \n", resolve(subexpr), "\n")

  

end