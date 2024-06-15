using TextEncodeBase
using TextEncodeBase: PerforatedOverwritableLookupVector, DictBackedLookupDict, DATLookupVector

struct BPEEncoder{T<:BPETokenizer, V<:Vocab} <: AbstractTextEncoder
    tokenizer::T
    vocab::V
end
TextEncodeBase.process(e::BPEEncoder) = identity
(e::BPEEncoder)(x::AbstractString) = TextEncodeBase.lookup(e.vocab, encode_indices(e, x))

Base.propertynames(e::BPEEncoder) = (:encode, :decode, fieldnames(BPEEncoder)...)
function Base.getproperty(e::BPEEncoder, sym::Symbol)
    if sym == :encode
        return e
    elseif sym == :decode
        return Base.Fix1(TextEncodeBase.decode_text, e)
    else
        return getfield(e, sym)
    end
end

function Base.show(io::IO, e::BPEEncoder)
    print(io, "BPEEncoder(")
    show(io, e.tokenizer)
    print(io, ", Vocab(size = ")
    print(io, length(e.vocab))
    print(io, "))")
end

"""
    load_tiktoken_encoder(name)

    Load the tiktoken encoder (tokenizer + predefined vocabulary)

!!! warning
    The encoded value is off by 1 comparing to the python/rust tiktoken.

```julia-repl
julia> enc = BytePairEncoding.load_tiktoken_encoder("cl100k_base")
┌ Warning: The maximum encoded value (`length(BPEEncoder.vocab)`) is larger than the number of possible tokens
│ because there are some "gaps" in the vocabulary. Be carefull if used to initialize embedding table.
└ @ BytePairEncodin
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
"""
function load_tiktoken_encoder(name)
    ENDOFTEXT = "<|endoftext|>"
    FIM_PREFIX = "<|fim_prefix|>"
    FIM_MIDDLE = "<|fim_middle|>"
    FIM_SUFFIX = "<|fim_suffix|>"
    ENDOFPROMPT = "<|endofprompt|>"
    tkr = load_tiktoken(name)
    bpe = tkr.tokenization.base.bpe
    warn = true
    if name == "o200k_base"
        sptk = Dict(
            ENDOFTEXT => 199999 + 1,
            ENDOFPROMPT => 200018 + 1,
        )
    elseif name == "cl100k_base"
        sptk = Dict(
            ENDOFTEXT => 100257 + 1,
            FIM_PREFIX => 100258 + 1,
            FIM_MIDDLE => 100259 + 1,
            FIM_SUFFIX => 100260 + 1,
            ENDOFPROMPT => 100276 + 1,
        )
    elseif name == "p50k_edit"
        sptk = Dict(
            ENDOFTEXT => 50256 + 1,
            FIM_PREFIX => 50281 + 1,
            FIM_MIDDLE => 50282 + 1,
            FIM_SUFFIX => 50283 + 1,
        )
    else
        sptk = Dict(
            ENDOFTEXT => 50256 + 1,
        )
        warn = false
    end
    if warn
        @warn """The maximum encoded value (`length(BPEEncoder.vocab)`) is larger than the number of possible tokens 
              because there are some "gaps" in the vocabulary. Be carefull if used to initialize embedding table."""
    end
    vector = PerforatedOverwritableLookupVector(
        DATLookupVector(bpe.encoder),
        DictBackedLookupDict(sptk, Dict(v=>k for (k, v) in sptk)))
    vocab = Vocab(vector, "", 0) # byte level bpe should be free from unknown token
    return BPEEncoder(tkr, vocab)
end
