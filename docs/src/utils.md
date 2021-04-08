# Utilities

Here are docs about some functionality we migth during the encoding process.

## Unicode Normalization

We provide `BytePairEncoding.UtfNormalizer` for unicode normalization. It simply wrap`Base.Unicode.normalize` as a callable object that perform the normalization on input text.

```julia
julia> norm = BytePairEncoding.UtfNormalizer(:NFKC_CF)
UtfNormalizer(1038)

julia> norm("i'M nOt LOWeRCaSE")
"i'm not lowercase"

```


## Codepoint Mapping/UnMapping

In the byte level bpe, we split the unicode string into UTF-8 bytes and map them into some fixed code range. We can do this with `BytePairEncoding.CodeMap`.

For example, we want to map `Char(0):Char(15)` to `'a':'p'` and `Char(16)` also to `'p'`.

```julia
julia> cm = BytePairEncoding.CodeMap([((Char(0):Char(15)) , ('a':'p')), Char(16)=>'p'])
BytePairEncoding.CodeMap{UInt8, UInt8}(StepRange{Char, Int64}['\0':1:'\x0f', '\x10':1:'\x10'], StepRange{Char, Int64}['a':1:'p', 'p':1:'p'])

# mapping the codepoint. 
# this is equivalent to `cm("\x00\x01\x0f\x10")`
julia> BytePairEncoding.encode(cm, "\x00\x01\x0f\x10")
"abpp"

# unmap the codedpoint.
# this is equvalent to `BytePairEncoding.UnMap(cm)(ans)`
julia> BytePairEncoding.decode(cm, ans)
"\0\x01\x0f\x0f"

```

!!! note 
	You might find that the decoded string and the origin input are different, because the code mapping is not bijective. 
	Therefore a good design of codemap is important, or you can just use `BytePairEncoding.default_codemap()` for the codemap used by openai gpt2.


## Glossary

`Glossary` is a list of `Regex` that specifing some text shouldn't be split by tokenizer or BPE.

```julia
julia> gloss = BytePairEncoding.Glossary([r"[0-9]", "New York"])
BytePairEncoding.Glossary(Regex[r"[0-9]", r"New\ York"])

julia> gloss("New York123")
4-element Vector{String}:
 "New York"
 "1"
 "2"
 "3"

```
