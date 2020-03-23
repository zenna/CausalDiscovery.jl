using Documenter, CausalDiscovery

makedocs(;
    modules=[CausalDiscovery],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/zenna/CausalDiscovery.jl/blob/{commit}{path}#L{line}",
    sitename="CausalDiscovery.jl",
    authors="Zenna Tavares",
    assets=String[],
)

deploydocs(;
    repo="github.com/zenna/CausalDiscovery.jl",
)
