module SubExpression

abstract type SubExpr end

"Subexpression of `AE` indicated by `P`"
struct SubExpr{AE <: AExpr, P}
  parent::AE
  pointer::P
end

"Pull out the `expr` pointed to by `subexpr` from its parent"
function pullout(subexpr) end



end