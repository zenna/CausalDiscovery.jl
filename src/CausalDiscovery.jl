module CausalDiscovery
using Reexport

include("Inference/Inference.jl")
@reexport using .Inference
# include("CISC/CISC.jl")
# include("CISC.jl")
# include("MCMC.jl/model.jl")
# include("MCMC.jl/grammar.jl")


end # module
