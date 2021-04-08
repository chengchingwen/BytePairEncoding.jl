# Encode

The overall encoding procedure:

1. normalize the input text.
2. separate word in glossary.
3. transform input (like tokenization) but no on glossary words.
4. codemapping for all words.
5. bpe on non-glossary words.
6. output transform (like vocabulary) on all words.


see [Utilities](@ref) for some helper type/function.


## Basic Type

```julia
GenericBPE{T}(;sepsym=nothing, oldendsym = nothing, endsym = oldendsym,
	input_transform = nothing, output_transform = nothing,
	merging_rank = Dict{Tuple{T, T}, Int}(), cache = Dict{T, Vector{T}}(),
	glossaries = nothing, codemap = nothing,
	normalizer = nothing) where T
```

This is the signature of `GenericBPE{String}`. where:

1. `sepsym` is the extra tag for non-end word. For example: If we split "word" into "wo" and "rd" and we set the `sepsym = "_"`, then the result would be `["wo_", "rd"]`.
2. `endsym` is the extra tag for end word. This is usually equal to the value of `oldendsym`. For example: If we split "word" into "wo" and "rd" and we set the `endsym = "/"`, then the result would be `["wo", "rd/"]`.
3. `oldendsym` is the `endsym` read from a bpe file.  For example: `subword-mnt` use `"<w/>"` as the end tag and thus need to be set accordingly. We can also set `endsym` to different value to override the setting.
4. `input_transform`: the tokenizer.
5. `output_transform`: some postprocessing function (like the vocabulary).
6. `merging_rank`: the bpe data.
7. `cache`: cache for bpe result.
8. `glossaries`: see [Glossary](@ref)
9. `codemap`: see [Codepoint Mapping/UnMapping](@ref)
10. `normalizer`: see [Unicode Normalization](@ref)

