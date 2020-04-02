using CausalDiscovery
using Test
using Random

@testset "CausalDiscovery.jl" begin
  # Write your own tests here.
  include("CISC.jl")
  include("MCMC.jl")
end
