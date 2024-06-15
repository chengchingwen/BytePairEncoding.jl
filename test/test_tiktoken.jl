const xnli = readlines(joinpath(artifact_dir, "xnli-dev.txt"))
using PythonCall
const tiktoken = pyimport("tiktoken")

using BytePairEncoding: load_tiktoken_encoder, load_tiktoken, load_gpt2, tiktoken2bbpe, bbpe2tiktoken, gpt2_codemap

@testset "TikToken" begin
    codemap = gpt2_codemap()
    unmap = TextEncodeBase.CodeUnMap(codemap)
    for model in (
        "o200k_base",
        "cl100k_base",
        "p50k_base",
        "p50k_edit",
        "r50k_base",
        "gpt2",
    )
        enc = load_tiktoken_encoder(model)
        tkr = enc.tokenizer
        tkr2 = tiktoken2bbpe(tkr, codemap)
        @test collect(tkr.tokenization.base.bpe.encoder) == collect(bbpe2tiktoken(tkr2).tokenization.base.bpe.encoder)
        pytkr = tiktoken.get_encoding(model)
        for line in xnli
            @test enc(line) == pyconvert(Array{Int}, pytkr.encode(line)) .+ 1
            @test enc.decode(enc(line)) == line
            tokens = tkr(line)
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s,
                                pytkr.decode_single_token_bytes.(pyconvert(Array{Int}, pytkr.encode(line))))
            tokens2 = map(unmap, tkr2(line))
            @test join(tokens2) == line
            @test tokens == tokens2
        end
    end

    @testset "gpt2" begin
        tkr = load_gpt2()
        unmap = TextEncodeBase.CodeUnMap(tkr.tokenization.base.codemap)
        tkr2 = bbpe2tiktoken(tkr)
        @test tkr.tokenization.base.base.bpe.merging_rank ==
            tiktoken2bbpe(tkr2, codemap).tokenization.base.base.bpe.merging_rank
        pytkr = tiktoken.get_encoding("gpt2")
        for line in xnli
            tokens = map(unmap, tkr(line))
            @test join(tokens) == line
            @test tokens == map(py->pyconvert(Base.CodeUnits, py).s,
                                pytkr.decode_single_token_bytes.(pyconvert(Array{Int}, pytkr.encode(line))))
            tokens2 = tkr2(line)
            @test join(tokens2) == line
            @test tokens == tokens2
        end
    end
end
