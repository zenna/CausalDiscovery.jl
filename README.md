# AutumnSynth

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://zenna.github.io/CausalDiscovery.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://zenna.github.io/CausalDiscovery.jl/dev)
[![Codecov](https://codecov.io/gh/zenna/CausalDiscovery.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/zenna/CausalDiscovery.jl)

# Installation

Install Julia 1.5.4 from [older releases](https://julialang.org/downloads/oldreleases/) and [Python 3](https://www.python.org/downloads/).

Install Python dependencies:
``` 
pip install z3-solver 
pip install bitstring
```
Clone repository:
```
git clone https://github.com/zenna/CausalDiscovery.jl.git
```
Install [Autumn.jl](https://github.com/riadas/Autumn.jl):
```
shell> cd CausalDiscovery.jl
shell> julia
julia> ] activate .
(@v1.5) pkg> rm Autumn
(@v1.5) pkg> add https://github.com/riadas/Autumn.jl#master
```

# Quick Start
CISC:
``` 
julia> include("src/synthesis/cisc/cisc.jl")
julia> @timed sols = run_model("ice", "heuristic")
julia> println(sols[1])
```

EMPA:
``` 
julia> include("src/synthesis/empa/empa.jl")
julia> @timed sols = run_model("Bait", "heuristic")
julia> println(sols[1])
```
