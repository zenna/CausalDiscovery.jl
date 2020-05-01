using CausalDiscovery.CISC: f

@testset "f" begin
  @test f(0.123) > 0
end
