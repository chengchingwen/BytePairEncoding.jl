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

function merges(bpe::ByteFallbackBPE, x::AbstractString)
    vocab = bpe.vocab
    y = Vector{Merge}()
    offset = 0
    for c in split(x, "")
        i = DoubleArrayTries.lookup(vocab, c)
        nu = ncodeunits(c)
        if iszero(i)
            cu = codeunits(c)
            for i = 1:nu
                push!(y, Merge(x, offset, 1, false, true))
                offset += 1
            end
        else
            push!(y, Merge(x, offset, nu, false))
            offset += nu
        end
    end
    if bpe.endsym !== nothing
        @inbounds y[end] = Merge(y[end], true)
    end
    return y
end
