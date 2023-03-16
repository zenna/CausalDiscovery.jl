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
  include("Autumn/particles.jl")
  include("Autumn/compile.jl")
  #commented out because it will not work until support for cells is added
  # include("Autumn/best_effort_ranking.jl")

end
