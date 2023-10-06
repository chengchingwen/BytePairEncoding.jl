using Artifacts, LazyArtifacts
using Base64
using TextEncodeBase

_load_tiktoken_encoder_dict(path) = Dict((((token, rank) = split(line); base64decode(token) => parse(Int, rank)) for line in readlines(path)))
_load_tiktoken_encoder(path) = TikTokenBPE(_load_tiktoken_encoder_dict(path))

function load_tiktoken_bpe(name)
    artifact_dir = try
        @artifact_str(name)
    catch e
        throw(ArgumentError("No tiktoken model named $name."))
    end
    path = joinpath(artifact_dir, "$(name).tiktoken")
    return _load_tiktoken_encoder(path)
end

function cl100k_base_tokenizer(text)
    pattern = r"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"
    return map(x->String(x.match), eachmatch(pattern, text))
end

function load_tiktoken(name)
    ENDOFTEXT = "<|endoftext|>"
    FIM_PREFIX = "<|fim_prefix|>"
    FIM_MIDDLE = "<|fim_middle|>"
    FIM_SUFFIX = "<|fim_suffix|>"
    ENDOFPROMPT = "<|endofprompt|>"
    bpe = load_tiktoken_bpe(name)
    if name == "cl100k_base"
        base_tkr = Cl100kBaseTokenization()
        matches = [ENDOFTEXT, FIM_PREFIX, FIM_MIDDLE, FIM_SUFFIX, ENDOFPROMPT]
    else
        base_tkr = GPT2Tokenization()
        if name == "p50k_edit"
            matches = [ENDOFTEXT, FIM_PREFIX, FIM_MIDDLE, FIM_SUFFIX]
        else
            matches = [ENDOFTEXT]
        end
    end
    tkr = TextEncodeBase.FlatTokenizer(
        TextEncodeBase.MatchTokenization(
            BPETokenization(base_tkr, bpe), matches
        )
    )
    return tkr
end

struct TikTokenBPE <: AbstractBPE
    encoder::Dict{Vector{UInt8}, Int}
end
(bpe::TikTokenBPE)(x) = bytepairencode(bpe, x)

function Base.getproperty(bpe::TikTokenBPE, sym::Symbol)
    if sym == :endsym || sym == :sepsym
        return nothing
    end
    return getfield(bpe, sym)
end

function Base.show(io::IO, bpe::TikTokenBPE)
    print(io, "TikTokenBPE(")
    print(io, length(bpe.encoder))
    print(io, " merges)")
end

units_itr(bpe::TikTokenBPE, x) = Iterators.map(i->Merge(x, i-1, 1, false, false), 1:ncodeunits(x))

function getrank(bpe::TikTokenBPE, m)
    m = Merge(m...)
    r = get(bpe.encoder, @inbounds(@view(codeunits(m.string)[m.offset .+ (1:m.ncodeunits)])), typemax(Int))
    return r
end
