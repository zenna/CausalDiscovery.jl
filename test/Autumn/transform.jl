using CausalDiscovery.Autumn
using CausalDiscovery.Autumn.Transform: Statement
# using CausalDiscovery.Autumn.Transform: findnonterminal

function test1()
  p = AExpr(:program, Statement())
  ϕ = Phi()
  subexpr_ = subexpr(p, 1)
  sub(ϕ, subexpr_)
end

function test2()
  aex = AExpr(:program, Statement(), Statement(), Statement(), Statement())
  ϕ = Phi()
  recursub(ϕ, aex)
end

@testset "transform" begin
  test1()
  test2()
end