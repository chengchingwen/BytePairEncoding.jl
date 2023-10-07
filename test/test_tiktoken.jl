const xnli = readlines(joinpath(artifact_dir, "xnli-dev.txt"))
using PythonCall
const tiktoken = pyimport("tiktoken")

using TextEncodeBase: Sentence, getvalue

@testset "TikToken" begin
    for model in (
        "cl100k_base",
        "p50k_base",
        "p50k_edit",
        "r50k_base",
    )
        tkr = BytePairEncoding.load_tiktoken(model)
        pytkr = tiktoken.get_encoding(model)
        for line in xnli
            tokens = map(getvalue, tkr(Sentence(line)))
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s, pytkr.decode_single_token_bytes.(pytkr.encode(line)))
        end
    end

    @testset "gpt2" begin
        tkr = BytePairEncoding.load_gpt2()
        unmap = TextEncodeBase.CodeUnMap(tkr.tokenization.base.codemap)
        pytkr = tiktoken.get_encoding("gpt2")
        for line in xnli
            tokens = map(unmap ∘ getvalue, tkr(Sentence(line)))
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s, pytkr.decode_single_token_bytes.(pytkr.encode(line)))
        end
    end
end
