using Artifacts, LazyArtifacts
using Base64
using TextEncodeBase
using TextEncodeBase: DATLookupDict
using DoubleArrayTries
using DoubleArrayTries: StringView

function _load_tiktoken_encoder_dict(path)
    Dict(
        (((token, rank) = split(line); base64decode(token) => parse(Int, rank))
         for line in readlines(path))
    )
end
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

"""
    load_tiktoken(name)

Load tiktoken tokenizer. `name` can be `"o200k_base"`, `"cl100k_base"`, `"p50k_base"`, `"p50k_base"`,
 `"r50k_base"`, or `"gpt2"`.

```julia-repl
julia> tkr = BytePairEncoding.load_tiktoken("cl100k_base")
BPETokenizer(MatchTokenization(BPETokenization(Cl100kBaseTokenization, bpe = TikTokenBPE(100256 merges)), 5 patterns))

julia> tkr("hello world aaaaaaaaaaaa")
5-element Vector{String}:
 "hello"
 " world"
 " a"
 "aaaaaaaa"
 "aaa"

```
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
    if name == "o200k_base"
        base_tkr = O200kBaseTokenization()
        matches = [ENDOFTEXT, ENDOFPROMPT]
    elseif name == "cl100k_base"
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
    tkr = BPETokenizer(
        TextEncodeBase.MatchTokenization(
            BPETokenization(base_tkr, bpe), matches
        )
    )
    return tkr
end

struct TikTokenBPE <: AbstractBPE
    encoder::DATLookupDict
    function TikTokenBPE(encoder::Dict{Vector{UInt8}, Int})
        words = sort!(collect((StringView(k) for k in keys(encoder))))
        trie = DoubleArrayTrie(words)
        # assuming rank range = 0:n-1 and set rank+1 as idx
        # Unfortunately, there might be gaps in the ranks, so set rank2uid with the largest value
        uid2rank = Vector{Int}(undef, length(trie))
        rank2uid = zeros(Int, maximum(values(encoder)) + 1)
        for word in words
            rank = encoder[word.data] + 1
            uid = TextEncodeBase.lookup(trie, word)
            uid2rank[uid] = rank
            rank2uid[rank] = uid
        end
        return new(DATLookupDict(trie, DoubleArrayTries.CVector(uid2rank), DoubleArrayTries.CVector(rank2uid)))
    end
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
    r = get(bpe.encoder, @inbounds(@view(codeunits(m.string)[m.offset .+ (1:m.ncodeunits)])), nothing)
    return isnothing(r) ? typemax(Int) : r - 1
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
    return TextEncodeBase.StructWalk.postwalk(TextEncodeBase.TokenizerStyle(), tkr) do x
        x isa BPETokenization && found[] && !isnothing(codemap) && return CodeNormalizer(x, codemap)
        x isa Union{TikTokenBPE, CachedBPE{TikTokenBPE}} && (found[] = true) && return tiktoken2bbpe(x, codemap)
        return x
    end
end
tiktoken2bbpe(bpe::CachedBPE, codemap::Union{CodeMap, Nothing} = nothing) = CachedBPE(tiktoken2bbpe(bpe.bpe, codemap))
function tiktoken2bbpe(_bpe::TikTokenBPE, codemap::Union{CodeMap, Nothing} = nothing)
    encoder = _bpe.encoder
    bpe = TikToken2BBPE(_bpe, Ref(0))
    ranks = Dict{NTuple{2, Merge}, Int}()
    offset = count(isone ∘ ncodeunits, keys(encoder)) - 1
    for (token, rank1) in encoder
        rank = rank1 - 1
        len = ncodeunits(token)
        isone(len) && continue
        bpe.max_rank[] = rank
        merged = Tuple(bpe(token))
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
    return TextEncodeBase.StructWalk.postwalk(TextEncodeBase.TokenizerStyle(), tkr) do x
        x isa CodeNormalizer && found[] && !isnothing(codemap) && return x.base
        x isa Union{BPE, CachedBPE{BPE}} && (found[] = true) && return bbpe2tiktoken(x, codemap)
        return x
    end
end
bbpe2tiktoken(bpe::CachedBPE, codemap::Union{CodeMap, Nothing} = nothing) = CachedBPE(bbpe2tiktoken(bpe.bpe, codemap))
function bbpe2tiktoken(bpe::BPE, codemap::Union{CodeMap, Nothing} = nothing)
    @assert all(isnothing, (bpe.endsym, bpe.sepsym)) "Cannot convert bpe with `sepsym` or `endsym`"
    unmap = isnothing(codemap) ? identity : TextEncodeBase.CodeUnMap(codemap)
    chars = sort!([(!isprint(c) || c == ' ' || c == '\ua0' #= python not printable =#, c) for c in Char(0):Char(2^8-1)])
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
