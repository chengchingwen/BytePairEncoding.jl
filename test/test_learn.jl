@testset "learn" begin
    bper = BPELearner([joinpath(dirname(@__FILE__), "data/corpus.en")], 1000)
    learn!(bper)
    bper_result = emit(bper)
    open(joinpath(dirname(@__FILE__), "data/bpe.ref")) do ref
        _v, lines = Iterators.peel(readlines(ref))
        result = map((x)->Tuple(split(x)), lines)
        @test length(bper.bpe) == length(result)

        for (lr, res) ∈ zip(bper_result, result)
            @test lr == res
        end
    end

    bpefile = joinpath(dirname(@__FILE__), "data/bpe.out")
    emit(bper, bpefile; comment = "this is for testing...")

    open(bpefile) do bf
        _h = readline(bf)
        for (i, line) ∈ enumerate(eachline(bf))
            pair = Tuple(split(line, " "))
            @test pair == bper_result[i]
        end
    end
end

