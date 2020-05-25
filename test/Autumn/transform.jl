using CausalDiscovery.Autumn
using CausalDiscovery.Autumn.Transform: Statement

function test()
  p = ProgramExpr([Statement()])
  ϕ = Phi()
  subexpr_ = subexpr(p, 1)
  fill(ϕ, subexpr_)
end
