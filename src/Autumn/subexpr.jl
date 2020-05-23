"Autumn SubExpressions"
module SubExpressions

using ..AExpressions

export SubExpr,
       subexpr

"Subexpression of `parent::AE` indicated by pointer `p::P`"
struct SubExpr{AE <: AExpr, P}
  parent::AE
  pointer::P
end

subexpr(aexpr, i) = SubExpr(aexpr, args(aexpr)[i])
subexpr(::SubExpr) = error("Cannot take subexpression of subexpression, yet")

end