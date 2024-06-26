# BytePairEncoding.jl

[![Build status](https://github.com/chengchingwen/BytePairEncoding.jl/workflows/CI/badge.svg)](https://github.com/chengchingwen/BytePairEncoding.jl/actions)
[![codecov](https://codecov.io/gh/chengchingwen/BytePairEncoding.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/chengchingwen/BytePairEncoding.jl)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://chengchingwen.github.io/BytePairEncoding.jl/dev/)

Pure Julia implementation of the Byte Pair Encoding (BPE) method. Support
 [openai-gpt2](https://github.com/openai/gpt-2) byte-level bpe
 and [openai tiktoken](https://github.com/openai/tiktoken). `BytePairEncoding.jl` rely on
 [TextEncodeBase.jl](https://github.com/chengchingwen/TextEncodeBase.jl) and support different tokenization method.


```julia
julia> using BytePairEncoding

julia> tkr = BytePairEncoding.load_tiktoken("cl100k_base")
BPETokenizer(MatchTokenization(BPETokenization(Cl100kBaseTokenization, bpe = TikTokenBPE(100256 merges)), 5 patterns))

julia> tkr("hello world aaaaaaaaaaaa")
5-element Vector{String}:
 "hello"
 " world"
 " a"
 "aaaaaaaa"
 "aaa"

julia> tkr2 = BytePairEncoding.load_gpt2()
BPETokenizer(MatchTokenization(CodeNormalizer(BPETokenization(GPT2Tokenization, bpe = BPE(50000 merges)), codemap = CodeMap{UInt8 => UInt16}(3 code-ranges)), 1 patterns))

julia> tkr2("hello world aaaaaaaaaaaa")
6-element Vector{String}:
 "hello"
 "Ġworld"
 "Ġa"
 "aaaa"
 "aaaa"
 "aaa"

julia> enc = BytePairEncoding.load_tiktoken_encoder("cl100k_base")
┌ Warning: The maximum encoded value (`length(BPEEncoder.vocab)`) is larger than the number of possible tokens
│ because there are some "gaps" in the vocabulary. Be carefull if used to initialize embedding table.
└ @ BytePairEncoding
BPEEncoder(BPETokenizer(MatchTokenization(BPETokenization(Cl100kBaseTokenization, bpe = TikTokenBPE(100256 merges)), 5 patterns)), Vocab(size = 100277))

julia> enc.encode("hello world aaaaaaaaaaaa") # === enc(...)
5-element Vector{Int64}:
 15340
  1918
   265
 70541
 33747

julia> enc.decode(enc("hello world aaaaaaaaaaaa"))
"hello world aaaaaaaaaaaa"

```
