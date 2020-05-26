module Util

# import MacroTools: postwalk, prewalk
using MLStyle
using ..AExpressions

export postwalkstate,
       postwalkpos

"""
Wraps MacroToolls.postwalk:

postwalk(f, expr)
Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk. See also
`prewalk`.
"""
# postwalk(f, aexpr::AExpr) = AExpr(postwalk(f, aexpr.expr))
# prewalk(f, aexpr::AExpr) = AExpr(prewalk(f, aexpr.expr))

walk(x, inner, outer, mapf) = outer(x)
walk(x::Expr, inner, outer, mapf = map) =
  outer(Expr(x.head, mapf(inner, @show x.args)...))

postwalk(f, x, mapf = map) = walk(x, x -> postwalk(f, x, mapf), f, mapf)

@inline mapenumerate(f, xs) = map(f, enumerate(xs))
@inline mapid(f, xs) = map(f, 1:length(xs), xs)

"Applies `f(node, position)` to each node, where position is the position is the tree"
postwalkpos(f, x) = postwalk(f, x, mapid)

# ## With state

"""
Postwalk with state.

`postwalkstate(x::Expr, f, state, statef, mapf = map)`

postwalk(f, expr)
Applies `f(expr, state)` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk.
`state` seen by each node is inductively defined:
  `state` for `x` is `state`
  `state` for each child of is `stataf(state, parent, i)` where
    `parent` is the parent of 
    `i` is position of child in `parent`
```
s0 = Int[]
statef(state, arg, i) = @show [i; state]
expr = :(let x = 4, y = 3
  x + y
end)
f(expr, state) = expr
postwalkstate(expr, f, s0, statef)
```
"""
postwalkstate(f, x::Expr, state, statef) = 
  let g(i, x_) = postwalkstate(f, x_,  statef(state, x, i), statef)
    f(Expr(x.head, mapid(g, x.args)...), state)
  end

postwalkstate(f, x, state, statef) = x

idappend(state, arg, i) = [i; state]
postwalkpos(f, x, p0 = Int[]) = postwalkstate(f, x, p0, idappend)

postwalkstate(f, x::AExpr, state, statef) =
  wrap(postwalkstate(f, x.expr, state, statef))

wrap(expr::Expr) = AExpr(expr)
wrap(x) = x

end