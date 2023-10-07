using Artifacts, LazyArtifacts
using Base64
using TextEncodeBase
using DoubleArrayTries: StringView

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

"""
    load_tiktoken(name)

Load tiktoken tokenizer. `name` can be `"cl100k_base"`, `"p50k_base"`, `"p50k_base"`, `"r50k_base"`, or `"gpt2"`.
"""
function load_tiktoken(name)
    ENDOFTEXT = "<|endoftext|>"
    FIM_PREFIX = "<|fim_prefix|>"
    FIM_MIDDLE = "<|fim_middle|>"
    FIM_SUFFIX = "<|fim_suffix|>"
    ENDOFPROMPT = "<|endofprompt|>"
    if name == "gpt2"
        bpe = bbpe2tiktoken(load_gpt2_bpe(), gpt2_codemap())
    else
        bpe = load_tiktoken_bpe(name)
    end
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

# converter
struct TikToken2BBPE <: AbstractBPE
    bpe::TikTokenBPE
    max_rank::Base.RefValue{Int}
end
(bpe::TikToken2BBPE)(x) = bytepairencode(bpe, x)
units_itr(bpe::TikToken2BBPE, x) = units_itr(bpe.bpe, x)
function getrank(bpe::TikToken2BBPE, m)
    r = getrank(bpe.bpe, m)
    return r >= bpe.max_rank[] ? typemax(Int) : r
end
Base.getproperty(bpe::TikToken2BBPE, sym::Symbol) = sym == :endsym || sym == :sepsym ? nothing : getfield(bpe, sym)

function tiktoken2bbpe(tkr, codemap::Union{CodeMap, Nothing} = nothing)
    found = Ref(false)
    return replace(tkr) do x
        x isa BPETokenization && found[] && !isnothing(codemap) && return CodeNormalizer(x, codemap)
        x isa TikTokenBPE && (found[] = true) && return tiktoken2bbpe(x, codemap)
        return x
    end
end
function tiktoken2bbpe(_bpe::TikTokenBPE, codemap::Union{CodeMap, Nothing} = nothing)
    encoder = _bpe.encoder
    bpe = TikToken2BBPE(_bpe, Ref(0))
    ranks = Dict{NTuple{2, Merge}, Int}()
    offset = count(isone ∘ length, keys(encoder)) - 1
    for (token, rank) in encoder
        len = length(token)
        isone(len) && continue
        bpe.max_rank[] = rank
        merged = Tuple(bpe(StringView(token)))
        @assert length(merged) == 2
        if !isnothing(codemap)
            merged = codemap.(merged)
        end
        ranks[parse_merge(Tuple(merged), nothing)] = rank - offset
    end
    return BPE(ranks)
end


function bbpe2tiktoken(tkr)
    _codemap = Ref{Union{Nothing, CodeMap}}(nothing)
    TextEncodeBase.StructWalk.scan(TextEncodeBase.TokenizerStyle(), tkr) do x
        x isa CodeMap && (_codemap[] = x)
    end
    return bbpe2tiktoken(tkr, _codemap[])
end
function bbpe2tiktoken(tkr, codemap::Union{CodeMap, Nothing})
    found = Ref(false)
    return replace(tkr) do x
        x isa CodeNormalizer && !isnothing(codemap) && return x.base
        x isa BPE && (found[] = true) && return bbpe2tiktoken(x, codemap)
        return x
    end
end
function bbpe2tiktoken(bpe::BPE, codemap::Union{CodeMap, Nothing} = nothing)
    @assert all(isnothing, (bpe.endsym, bpe.sepsym)) "Cannot convert bpe with `sepsym` or `endsym`"
    unmap = isnothing(codemap) ? identity : TextEncodeBase.CodeUnMap(codemap)
    chars = sort((!isprint(c) || c == ' ' || c == '\ua0' #= python not printable =#, c) for c in Char(0):Char(2^8-1))
    encoder = Dict(UInt8[b] => i-1 for (i, (_, b)) in enumerate(chars))
    offset = length(encoder) - 1
    for (merges, rank) in bpe.merging_rank
        bytes = vcat(codeunits(unmap(merges[1].string)), codeunits(unmap(merges[2].string)))
        encoder[bytes] = offset + rank
    end
    return TikTokenBPE(encoder)
end

"""
    tiktoken2bbpe(tkr, codemap::Union{CodeMap, Nothing} = nothing)

Convert a tiktoken tokenizer (with `bpe::TikToken`) to gpt2-like byte-level tokenizer (with `bpe::BPE`).
 If `codemap` is provided, it will add the corresponding `CodeNormalizer` to the tokenizer.

see also: [`bbpe2tiktoken`](@ref)
"""
tiktoken2bbpe

"""
    bbpe2tiktoken(tkr)

Convert a gpt2-like byte-level tokenizer (with `bpe::BPE`) to tiktoken tokenizer (with `bpe::TikToken`).
 If there is a `CodeNormalizer` in the tokenizer, it will be removed accordingly.

see also: [`tiktoken2bbpe`](@ref)
"""
bbpe2tiktoken
