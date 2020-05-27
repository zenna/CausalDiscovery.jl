using CausalDiscovery.Autumn
using CausalDiscovery.Autumn.Transform: Statement

function test1()
  p = AExpr(:program, Statement())
  ϕ = Phi()
  subexpr_ = subexpr(p, 1)
  sub(ϕ, subexpr_)
end

function test2()
  p = AExpr(:program, Statement())
  ϕ = Phi()
  recursub(ϕ, p)
end
