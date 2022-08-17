using BytePairEncoding
using Documenter

DocMeta.setdocmeta!(BytePairEncoding, :DocTestSetup, :(using BytePairEncoding); recursive=true)

makedocs(;
    modules=[BytePairEncoding],
    authors="chengchingwen <adgjl5645@hotmail.com> and contributors",
    repo="https://github.com/chengchingwen/BytePairEncoding.jl/blob/{commit}{path}#{line}",
    sitename="BytePairEncoding.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chengchingwen.github.io/BytePairEncoding.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/chengchingwen/BytePairEncoding.jl",
)
