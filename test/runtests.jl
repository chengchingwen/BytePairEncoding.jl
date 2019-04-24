using BytePairEncoding
using Test

#use the same tokenize method and frequency method with origin python code
using WordTokenizers
_python_whitespace_tokenizer(x::AbstractString) = split(x, ('\r','\n', ' '), keepempty=false)
set_tokenizer(_python_whitespace_tokenizer)

import BytePairEncoding: Statistic, most_freq
most_freq(stats::Statistic) = sort(collect(stats.pair_freq); alg=PartialQuickSort(1), by=(x)->(x.second, x.first), rev=true)[1].first


@test isempty(detect_ambiguities(Base, Core, BytePairEncoding))

tests = [
    "learn",
    "bpe",
    "glossary",
    "utfnorm",
]

@testset "BytePairEncoding" begin
    for t in tests
        fp = joinpath(dirname(@__FILE__), "test_$t.jl")
        @info "Test $t"
        include(fp)
    end
end

