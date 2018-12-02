@testset "learn" begin
    bper = BPELearner([joinpath(dirname(@__FILE__), "data/corpus.en")], 1000)
    learn!(bper)
    open(joinpath(dirname(@__FILE__), "data/bpe.ref")) do ref
        _v, lines = Iterators.peel(readlines(ref))
        result = map((x)->Pair(split(x)...), lines)
        @test length(bper.result) == length(result)

        for (lr, res) ∈ zip(bper.result, result)
            @test lr == res
        end
    end
end

