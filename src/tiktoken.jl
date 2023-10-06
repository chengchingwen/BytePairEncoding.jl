using Artifacts, LazyArtifacts
using Base64

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
