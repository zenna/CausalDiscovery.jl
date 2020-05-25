module Util

import MacroTools: postwalk, prewalk
using MLStyle
using ..AExpressions

"""
Wraps MacroToolls.postwalk:

postwalk(f, expr)
Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk. See also
`prewalk`.
"""
postwalk(f, aexpr::AExpr) = AExpr(postwalk(f, aexpr.expr))
prewalk(f, aexpr::AExpr) = AExpr(prewalk(f, aexpr.expr))


@inline mapindex(f, xs) = map(f, xs, 1:length(xs))

walkindex(x, inner, outer) = outer(x)
walkindex(x::Expr, inner, outer) = outer(Expr(x.head, mapindex(inner, x.args)...))

"Applies `f(node, position)` to each node, where position is the position is the tree"
postwalkpos(f, x) = walkindex(x, x -> postwalk(f, x), f)


## Need to
# Add position, if we want to remove
# 


# Should we just us Expr objects?
# Benefits, can use existing tools

# Cons
# No dispatch so we need big ifelse loops
# dispatch might be slow.. is a fair bit slower
# Typed has greater constraints that data is correct
# harder to write abstract rules 

end