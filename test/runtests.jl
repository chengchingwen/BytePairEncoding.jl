using CondaPkg
testproj_dir = dirname(Base.load_path()[1])
cp(joinpath(@__DIR__, "CondaPkg.toml"), joinpath(testproj_dir, "CondaPkg.toml"))

using Artifacts, LazyArtifacts
const artifact_dir = @artifact_str("xnli_dev", nothing, joinpath(@__DIR__, "Artifacts.toml"))

using BytePairEncoding
using TextEncodeBase
using Test

#use the same tokenize method and frequency method with origin python code
_python_whitespace_tokenizer(x::AbstractString) = split(x, ('\r','\n', ' '), keepempty=false)

most_freq(stats) = sort(collect(stats.pair_freq); alg=PartialQuickSort(1), by=(x)->(x.second, x.first), rev=true)[1].first

@test isempty(detect_ambiguities(BytePairEncoding))

tests = [
    "learn",
    "bpe",
    "bbpe",
    "tiktoken",
]

@testset "BytePairEncoding" begin
    for t in tests
        fp = joinpath(dirname(@__FILE__), "test_$t.jl")
        @info "Test $t"
        include(fp)
    end
end

