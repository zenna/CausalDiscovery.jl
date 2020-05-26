"Autumn SubExpressions"
module SubExpressions

using ..AExpressions
using ..Util

export SubExpr,
       subexpr,
       resolve,
       update 
       

"Subexpression of `parent::AE` indicated by pointer `p::P`"
struct SubExpr{AExpr, P}
  parent::AExpr
  pointer::P
end

subexpr(aexpr, id) = SubExpr(aexpr, id)
subexpr(aexpr, id::Integer) = SubExpr(aexpr, [id])
subexpr(::SubExpr) = error("Cannot take subexpression of subexpression, yet")

"Resolve `AExpr` pointed to by `subexpr`"
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

prog2 = au\"\"\"(= x 4000)\"\"\"
subexpr_ = subexpr(prog, [2])
update(subexpr_, prog2)
```
\"\"\"

```
"""
function update(subexpr::SubExpr, newexpr::AExpr)
  function subchild(expr, pos)
    pos == subexpr.pointer ? newexpr : expr
  end
  postwalkpos(subchild, subexpr.parent)
end

# Base.show(io::IO, subexpr::SubExpr) =
#   print(io, subexpr.)

end