using BytePairEncoding: BPETokenization, NoBPE, count_words, read_merges, write_merges
using TextEncodeBase: WordTokenization

@testset "learn" begin
    tkn = BPETokenization(WordTokenization(tokenize = _python_whitespace_tokenizer), NoBPE())
    bper = BPELearner(tkn)
    word_counts = count_words(bper, joinpath(@__DIR__, "data/corpus.en"))
    rank = BytePairEncoding.learn(most_freq, word_counts, 1000, bper.endsym, bper.min_freq)
    list = BytePairEncoding.rank2list(rank, bper.endsym)
    open(joinpath(@__DIR__, "data/bpe.ref")) do ref
        lines = Iterators.drop(eachline(ref), 1)
        result = map(Tuple ∘ split, lines)
        @test length(list) == length(result)
        for (lr, res) ∈ zip(list, result)
            @test lr == res
        end
    end
    @test read_merges(joinpath(@__DIR__, "data/bpe.ref"), bper.endsym) == rank

    bpe_out = tempname()
    open(io->write_merges(io, rank, bper.endsym; comment = "this is for testing..."), bpe_out, "w+")
    @test open(Base.Fix2(read_merges, bper.endsym), bpe_out) == rank

    bpefile = joinpath(@__DIR__, "data/bpe.ref")
    ref = open(bpefile) do io
        readline(io)
        read(io, String)
    end
    tst = open(bpe_out) do io
        readline(io)
        read(io, String)
    end
    @test ref == tst
end
