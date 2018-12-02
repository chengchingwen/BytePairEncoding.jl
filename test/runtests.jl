using BPE
using Test

#use the same tokenize method and frequency method with origin python code
using WordTokenizers
set_tokenizer(BPE.whitespace_tokenizer)

import BPE: Statistic, most_freq
most_freq(stats::Statistic) = sort(collect(stats.pair_freq); alg=PartialQuickSort(1), by=(x)->(x.second, x.first), rev=true)[1].first


@test isempty(detect_ambiguities(Base, Core, BPE))

tests = [
    "learn"
]

@testset "BPE" begin
    for t in tests
        fp = joinpath(dirname(@__FILE__), "test_$t.jl")
        println("$fp ...")
        include(fp)
    end
end

