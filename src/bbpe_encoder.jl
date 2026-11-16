# Byte-level BPE encoders built from a vocabulary and a merge list, the format
# used by HuggingFace `tokenizer.json` / `vocab.json` + `merges.txt` and by the
# `tokenizer.ggml.*` metadata of GGUF files.

using TextEncodeBase: BaseTokenization, SentenceStage, getvalue, FindAllIterator, CodeNormalizer, CodeUnMap

"""
    RegexTokenization(regex)

Pre-tokenization splitting a sentence into the successive matches of `regex`,
as the `Split` pre-tokenizer of HuggingFace tokenizers and tiktoken do.
"""
struct RegexTokenization <: BaseTokenization
    regex::Regex
end
TextEncodeBase.splitting(t::RegexTokenization, s::SentenceStage) = FindAllIterator(t.regex, getvalue(s))
Base.show(io::IO, t::RegexTokenization) = print(io, "RegexTokenization(", t.regex, ')')

"the regex pattern used by the Qwen2, Qwen2.5 and Qwen3 tokenizers"
function qwen2_regex()
    return r"""(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"""
end

"""
    BBPEEncoder

A byte-level BPE encoder: text to token ids and back. Build one with
[`load_bbpe_encoder`](@ref).

- `e(text)`, or `TextEncodeBase.encode(e, text)`, returns the token ids
  (0-based, as in the vocabulary files);
- `TextEncodeBase.decode(e, ids)` returns the text;
- `e.tokenizer(text)` returns the token strings.
"""
struct BBPEEncoder{T<:BPETokenizer}
    tokenizer::T
    token2id::Dict{String,Int}
    id2token::Vector{String}
    special::Set{String}
    unmap::CodeUnMap
end

"""
    load_bbpe_encoder(tokens, merges; pattern = gpt2_regex(), special_tokens = String[], codemap = gpt2_codemap())

Build a [`BBPEEncoder`](@ref) from:

- `tokens`: the vocabulary, a vector whose `i`-th entry is the token with id
  `i - 1` (as `tokenizer.ggml.tokens` in GGUF), or a `Dict` from token to id
  (as `vocab.json`). Tokens are in byte-level form: each byte is one character
  of `codemap` (`"Ġ"` for a space with the GPT-2 map).
- `merges`: the merge rules in priority order, as `"a b"` strings or pairs.
- `pattern`: the pre-tokenization regex ([`qwen2_regex`](@ref) for Qwen models).
- `special_tokens`: tokens matched verbatim in the input before
  pre-tokenization and never split (e.g. `"<|im_start|>"`); they must be in
  `tokens`.
"""
function load_bbpe_encoder(tokens, merges; pattern::Regex=gpt2_regex(), special_tokens=String[],
                           codemap::CodeMap=gpt2_codemap())
    id2token = _id2token(tokens)
    token2id = Dict{String,Int}(t => i - 1 for (i, t) in enumerate(id2token))
    ranks = Dict{NTuple{2,Merge},Int}()
    for (r, m) in enumerate(merges)
        pair = m isa AbstractString ? parse_merge(m) : parse_merge(Tuple(m))
        get!(ranks, pair, r)
    end
    specials = String.(collect(special_tokens))
    for s in specials
        haskey(token2id, s) || throw(ArgumentError("special token $(repr(s)) is not in the vocabulary"))
    end
    base = CodeNormalizer(BPETokenization(RegexTokenization(pattern), CachedBPE(BPE(ranks))), codemap)
    tokenization = isempty(specials) ? base : TextEncodeBase.MatchTokenization(base, specials)
    return BBPEEncoder(BPETokenizer(tokenization), token2id, id2token, Set(specials), CodeUnMap(codemap))
end

_id2token(tokens::AbstractVector) = String.(tokens)
function _id2token(tokens::AbstractDict)
    n = maximum(values(tokens)) + 1
    v = fill("", n)
    for (t, i) in tokens
        v[i+1] = String(t)
    end
    return v
end

Base.length(e::BBPEEncoder) = length(e.id2token)

function Base.show(io::IO, e::BBPEEncoder)
    print(io, "BBPEEncoder(", length(e.id2token), " tokens, ", length(e.special), " special)")
end

(e::BBPEEncoder)(text::AbstractString) = TextEncodeBase.encode(e, text)

"""
    encode(e::BBPEEncoder, text) -> Vector{Int}

Token ids (0-based) of `text`.
"""
function TextEncodeBase.encode(e::BBPEEncoder, text::AbstractString)
    toks = e.tokenizer(text)
    ids = Vector{Int}(undef, length(toks))
    for (i, t) in enumerate(toks)
        id = get(e.token2id, t, -1)
        id < 0 && error("BBPEEncoder: token $(repr(t)) is not in the vocabulary")
        ids[i] = id
    end
    return ids
end

"""
    decode(e::BBPEEncoder, ids) -> String

Text of the token ids `ids` (0-based). Invalid UTF-8 (a multi-byte character
cut between tokens) is kept as is.
"""
function TextEncodeBase.decode(e::BBPEEncoder, ids)
    io = IOBuffer()
    for id in ids
        t = e.id2token[id+1]
        write(io, t in e.special ? t : e.unmap(t))
    end
    return String(take!(io))
end
