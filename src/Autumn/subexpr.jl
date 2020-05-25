"Autumn SubExpressions"
module SubExpressions

using ..AExpressions

export SubExpr,
       subexpr,
       resolve

"Subexpression of `parent::AE` indicated by pointer `p::P`"
struct SubExpr{AE <: AExpr, P}
  parent::AE
  pointer::P
end

subexpr(aexpr, id) = SubExpr(aexpr, id)
subexpr(aexpr, id::Integer) = SubExpr(aexpr, (id,))
subexpr(::SubExpr) = error("Cannot take subexpression of subexpression, yet")

"Resolve `AExpr` pointed to by `subexpr`"
function resolve(subexpr::SubExpr)
  ex = subexpr.parent
  for id in subexpr.pointer
    ex = arg(ex, id)
  end
  ex
end

"Update subexpr.parent such that `subexpr` is `newexpr`"
function update(subexpr::SubExpr, newexpr::AExpr)
  ex = 
end

end