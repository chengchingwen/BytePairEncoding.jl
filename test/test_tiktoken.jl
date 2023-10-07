const xnli = readlines(joinpath(artifact_dir, "xnli-dev.txt"))
using PythonCall
const tiktoken = pyimport("tiktoken")

using BytePairEncoding: load_tiktoken, load_gpt2, tiktoken2bbpe, bbpe2tiktoken, gpt2_codemap
using TextEncodeBase: Sentence, getvalue

@testset "TikToken" begin
    codemap = gpt2_codemap()
    unmap = TextEncodeBase.CodeUnMap(codemap)
    for model in (
        "cl100k_base",
        "p50k_base",
        "p50k_edit",
        "r50k_base",
        "gpt2",
    )
        tkr = load_tiktoken(model)
        tkr2 = tiktoken2bbpe(tkr, codemap)
        pytkr = tiktoken.get_encoding(model)
        for line in xnli
            tokens = map(getvalue, tkr(Sentence(line)))
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s, pytkr.decode_single_token_bytes.(pytkr.encode(line)))
            tokens2 = map(unmap ∘ getvalue, tkr2(Sentence(line)))
            @test join(tokens2) == line
            @test tokens == tokens2
        end
    end

    @testset "gpt2" begin
        tkr = load_gpt2()
        unmap = TextEncodeBase.CodeUnMap(tkr.tokenization.base.codemap)
        tkr2 = bbpe2tiktoken(tkr)
        pytkr = tiktoken.get_encoding("gpt2")
        for line in xnli
            tokens = map(unmap ∘ getvalue, tkr(Sentence(line)))
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s, pytkr.decode_single_token_bytes.(pytkr.encode(line)))
            tokens2 = map(getvalue, tkr2(Sentence(line)))
            @test join(tokens2) == line
            @test tokens == tokens2
        end
    end
end
