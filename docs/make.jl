using Documenter, BytePairEncoding

makedocs(sitename="BytePairEncoding.jl",
         pages = Any[
           "Home"=>"index.md",
           "Guides" => Any[
             "Encode" => "encode.md",
             "Learning BPE" => "learn.md",
             "Utilities" => "utils.md",
           ]
         ],
         )
deploydocs(
    repo = "github.com/chengchingwen/BytePairEncoding.jl.git",
)
