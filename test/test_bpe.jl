using BytePairEncoding: read_merges, CachedBPE, AbstractBPE
using TextEncodeBase: FlatTokenizer, WordTokenization, MatchTokenization, Sentence, getvalue

function process_line(tkr, line)
    pat = r"\S.*\S"
    m = match(pat, line)
    isnothing(m) && return line
    sentence = join(map(getvalue, tkr(Sentence(m.match))), ' ')
    return replace(line, pat=>sentence)
end

struct FakeBPE <: AbstractBPE
    sepsym::String
    endsym::String
end

(bpe::FakeBPE)(x) = [x[1:div(length(x),2)]*bpe.sepsym, x[div(length(x),2)+1:end]*bpe.endsym]

@testset "bpe" begin
    infile = joinpath(dirname(@__FILE__), "data/corpus.en")
    bpefile = joinpath(dirname(@__FILE__), "data/bpe.ref")
    refile = joinpath(dirname(@__FILE__), "data/corpus.bpe.ref.en")

    merges = read_merges(bpefile, "</w>")
    bpe = CachedBPE(BPE(merges; sepsym = "@@", endsym = ""))
    tkr = FlatTokenizer(BPETokenization(WordTokenization(tokenize = _python_whitespace_tokenizer), bpe))

    open(refile) do fr
        open(infile) do fi
            for (li, lr) ∈ zip(eachline(fi), eachline(fr))
                @test process_line(tkr, li) == lr
            end
        end
    end

    @test process_line(tkr, "  iron cement  \n") == "  ir@@ on c@@ ement  \n"
    @test process_line(tkr, "iron" * "\ua0" * "cement\n") == "ir@@ on@@ "*"\ua0"*"@@ c@@ ement\n"
    @test process_line(tkr, "\n") == "\n"

    tkr1 = FlatTokenizer(
        MatchTokenization(
            BPETokenization(
                WordTokenization(tokenize = _python_whitespace_tokenizer),
                FakeBPE("@@", "/")
            ),
            ["like", "Manuel", "USA"],
        )
    )
    @test process_line(tkr1, "wordlikeword likeManuelword") == "wo@@ rd/ like wo@@ rd/ like Manuel wo@@ rd/"
end
