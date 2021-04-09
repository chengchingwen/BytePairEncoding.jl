# BytePairEncoding.jl

[![Build status](https://github.com/chengchingwen/BytePairEncoding.jl/workflows/CI/badge.svg)](https://github.com/chengchingwen/BytePairEncoding.jl/actions)
[![codecov](https://codecov.io/gh/chengchingwen/BytePairEncoding.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/chengchingwen/BytePairEncoding.jl)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://chengchingwen.github.io/BytePairEncoding.jl/dev/)

Pure Julia implementation of the Byte Pair Encoding (BPE) method.

The design is inspired by the original python package [subword-nmt](https://github.com/rsennrich/subword-nmt) and the byte-level bpe use in [openai-gpt2](https://github.com/openai/gpt-2). `BytePairEncoding.jl` support different tokenize
method(with the help of WordTokenizers.jl). You can simply set the tokenizer and then learn the BPE map with it.


# Installation

In the Julia REPL:

```
]add BytePairEncoding
```


# Usage

```julia
julia> using BytePairEncoding, WordTokenizers

# using the bpe from openai gpt
julia> bpe = Bpe(Base.download("https://huggingface.co/openai-gpt/resolve/main/merges.txt"))
GenericBPE{String}(n_merge=40000, endsym=</w>, oldendsym=</w>, input_transform=tokenize)

# reset the tokenize method to do lowercase before tokenization
julia> bpe = GenericBPE(bpe; input_transform = tokenize∘lowercase)
GenericBPE{String}(n_merge=40000, endsym=</w>, oldendsym=</w>, input_transform=ComposedFunction{typeof(tokenize), typeof(lowercase)}(WordTokenizers.tokenize, lowercase))

# segment the sentence
julia> bpe("Peter Piper picked a peck of pickled peppers")
8-element Vector{String}:
 "peter</w>"
 "piper</w>"
 "picked</w>"
 "a</w>"
 "peck</w>"
 "of</w>"
 "pickled</w>"
 "peppers</w>"

# using the byte level bpe from openai gpt2
julia> bbpe = ByteLevelBPE(Base.download("https://s3.amazonaws.com/models.huggingface.co/bert/gpt2-merges.txt"))
GenericBPE{String}(n_merge=50000, input_transform=gpt2_tokenizer, codemap=BytePairEncoding.CodeMap(StepRange{Char,
Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń']))

# segment the sentence
julia> bbpe("This is a 😺")
5-element Vector{String}:
 "This"
 "Ġis"
 "Ġa"
 "ĠðŁĺ"
 "º"

# to see the origin input, set the output_transform method that unmap the codepoint
julia> decoded_bbpe = GenericBPE(bbpe; output_transform = BytePairEncoding.UnMap(bbpe.codemap))
GenericBPE{String}(n_merge=50000, input_transform=gpt2_tokenizer, output_transform=BytePairEncoding.UnMap(BytePairEncoding.CodeMap(StepRange{Char, Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń'])), codemap=BytePairEncoding.CodeMap(StepRange{Char, Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń']))

julia> decoded_bbpe("This is a 😺")
5-element Vector{String}:
 "This"
 " is"
 " a"
 " \xf0\x9f\x98"
 "\xba"

julia> join(ans)
"This is a 😺"

```


