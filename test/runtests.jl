using CausalDiscovery
using Test

# @testset "CausalDiscovery.jl" begin
#   # Write your own tests here.
#   include("CISC.jl")
#   include("model.jl")
# end

@testset "Autumn" begin
  # include("Autumn/sexpr.jl")
  # include("Autumn/transform.jl")
  # include("Autumn/particles.jl")
  # include("Autumn/compile.jl")
  include("Autumn/actualCausality.jl")
end
