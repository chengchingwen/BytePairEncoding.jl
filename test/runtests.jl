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
]

@testset "BytePairEncoding" begin
    for t in tests
        fp = joinpath(dirname(@__FILE__), "test_$t.jl")
        @info "Test $t"
        include(fp)
    end
end

