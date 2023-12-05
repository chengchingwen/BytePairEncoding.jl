import DoubleArrayTries
using DoubleArrayTries: DoubleArrayTrie, StringView

struct ByteFallbackBPE <: AbstractBPE
    vocab::DoubleArrayTrie
    merging_rank::Dict{NTuple{2, Merge}, Int}
    sepsym::Union{String, Nothing}
    endsym::Union{String, Nothing}
end

ByteFallbackBPE(vocab_list::AbstractVector{String}, merging_rank, sepsym, endsym) =
    ByteFallbackBPE(DoubleArrayTrie(collect(vocab_list)), merging_rank, sepsym, endsym)

(bpe::ByteFallbackBPE)(x) = bytepairencode(bpe, x)

function Base.show(io::IO, bpe::ByteFallbackBPE)
    print(io, "ByteFallbackBPE(")
    print(io, length(bpe.merging_rank))
    print(io, " merges")
    !isnothing(bpe.sepsym) && print(io, ", sepsym = ", bpe.sepsym)
    !isnothing(bpe.endsym) && print(io, ", endsym = ", bpe.endsym)
    print(io, ')')
end

struct ByteUnitsIterator
    vocab::DoubleArrayTrie
    string::SubString{String}
end
ByteUnitsIterator(vocab::DoubleArrayTrie, str::String) =
    ByteUnitsIterator(vocab, SubString(str))
ByteUnitsIterator(vocab::DoubleArrayTrie, str::AbstractString) =
    ByteUnitsIterator(vocab, String(str))
Base.eltype(::Type{ByteUnitsIterator}) = Merge
Base.IteratorSize(::Type{ByteUnitsIterator}) = Base.SizeUnknown()

function Base.iterate(itr::ByteUnitsIterator)
    offset = itr.string.offset
    return iterate(itr, (offset, 1, 1))
end
function Base.iterate(itr::ByteUnitsIterator, state)
    str = itr.string
    len = str.ncodeunits
    offset, nu, bid = state
    offset >= len && return nothing
    start = offset + 1
    if isone(bid)
        stop = nextind(str, start) - 1
        char = @inbounds view(codeunits(str), start:stop)
        nu = stop - offset
        vocab = itr.vocab
        i = DoubleArrayTries.lookup(vocab, char)
        isbyte = iszero(i)
        if isbyte
            unit = Merge(str, offset, 1, false, true)
            nextoffset = start
            nextbid = bid == nu ? 1 : bid + 1
        else
            unit = Merge(str, offset, nu, false, false)
            nextoffset = offset + nu
            nextbid = 1
        end
    else
        unit = Merge(str, offset, 1, false, true)
        nextoffset = start
        nextbid = bid == nu ? 1 : bid + 1
    end
    return unit, (nextoffset, nu, nextbid)
end

units_itr(bpe::ByteFallbackBPE, x) = ByteUnitsIterator(bpe.vocab, x)

function isfallback(str::AbstractString)
    m = match(r"<0x([0-9A-F]{2})>", str)
    if !isnothing(m)
        c = parse(UInt8, m.captures[]; base = 16)
        return (true, c)
    else
        return (false, 0x0)
    end
end

function fallback2byte(io::IO, str::AbstractString)
    isbyte, byte = isfallback(str)
    isbyte ? write(io, byte) : write(io, str)
end
function fallback2byte(str::AbstractString)
    isbyte, byte = isfallback(str)
    if isbyte
        return String([byte])
    else
        return String(str)
    end
end
