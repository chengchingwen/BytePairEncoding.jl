using Documenter, BytePairEncoding

makedocs(sitename="BytePairEncoding.jl",
         pages = Any[
           "Home"=>"index.md",
         ],
         )
deploydocs(
    repo = "github.com/chengchingwen/BytePairEncoding.jl.git",
)
