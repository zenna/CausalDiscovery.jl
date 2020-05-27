using CausalDiscovery
using Test

# @testset "CausalDiscovery.jl" begin
#   # Write your own tests here.
#   include("CISC.jl")
#   include("model.jl")
# end

@testset "Autumn" begin
  include("Autumn/sexpr.jl")
  include("Autumn/transform.jl")
end
