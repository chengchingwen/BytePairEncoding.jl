using LRUCache
using Unicode
using DataStructures

abstract type AbstractBPE end

struct BPE <: AbstractBPE
    merging_rank::Dict{NTuple{2, Merge}, Int}
    sepsym::Union{String, Nothing}
    endsym::Union{String, Nothing}
end
BPE(merging_rank::Dict; sepsym = nothing, endsym = nothing) = BPE(merging_rank, sepsym, endsym)
BPE(bpefile; sepsym = nothing, endsym = nothing, kws...) = BPE(read_merges(bpefile, endsym; kws...); sepsym, endsym)

(bpe::BPE)(x) = bytepairencode(bpe, x)

function Base.show(io::IO, bpe::BPE)
    print(io, "BPE(")
    print(io, length(bpe.merging_rank))
    print(io, " merges")
    !isnothing(bpe.sepsym) && print(io, ", sepsym = ", bpe.sepsym)
    !isnothing(bpe.endsym) && print(io, ", endsym = ", bpe.endsym)
    print(io, ')')
end

struct NoBPE <: AbstractBPE end

(bpe::NoBPE)(x) = [x]

Base.show(io::IO, bpe::NoBPE) = print(io, "NoBPE()")

struct CachedBPE{B <: AbstractBPE, D <: AbstractDict{<:AbstractString, Vector{String}}} <: AbstractBPE
    bpe::B
    cache::D
end

CachedBPE(bpe::AbstractBPE) = CachedBPE(bpe, LRU{AbstractString, Vector{String}}(; maxsize = 1000))

(bpe::CachedBPE)(x) = get!(()->bpe.bpe(x), bpe.cache, x)

Base.show(io::IO, bpe::CachedBPE) = (print(io, "CachedBPE("); show(io, bpe.bpe); print(io, ')'))

getrank(ranks, m) = get(ranks, m, typemax(eltype(values(ranks))))
getrank(bpe::AbstractBPE, m) = getrank(bpe.merging_rank, m)

lowestrank(bpe_or_ranks, ms::MutableLinkedList) = lowestrank(ms)
function lowestrank(ms::MutableLinkedList)
    # `MutableLinkedList` use the meta node to record the first & last node
    # Meanwhile, both prev(first node) and next(last node) point to the meta node
    metanode = ms.node
    node = metanode.next
    nextnode = node.next
    r = last(node.data)
    lst = r
    li = node
    while true
        node = nextnode
        nextnode = nextnode.next
        nextnode === metanode && break
        r = last(node.data)
        if r < lst
            lst = r
            li = node
        end
    end
    return lst, li
end

function merge_loop!(bpe_or_ranks, ms, x)
    for _ in 1:length(ms)
        r, i = lowestrank(bpe_or_ranks, ms)
        r == typemax(Int) && break
        merge!(ms, i, bpe_or_ranks)
        isone(length(ms)) && break
    end
    return
end

function _merge!(node, m1, metanode, ms, bpe_or_ranks)
    nextnode = node.next
    newnextnode = nextnode.next
    m2 = first(nextnode.data)
    m = Merge(m1, m2)
    if newnextnode === metanode
        r = typemax(Int)
    else
        m3 = first(newnextnode.data)
        r = getrank(bpe_or_ranks, (m, m3))
    end
    node.data = (m, r)
    node.next = newnextnode
    newnextnode.prev = node
    ms.len -= 1
    prevnode = node.prev
    if prevnode !== metanode
        m0 = first(prevnode.data)
        r = getrank(bpe_or_ranks, (m0, m))
        prevnode.data = (m0, r)
    end
    return newnextnode
end

function merge!(ms::MutableLinkedList, node, bpe_or_ranks)
    metanode = ms.node
    m1, r = node.data
    node = _merge!(node, m1, metanode, ms, bpe_or_ranks)
    while node !== metanode
        m1, r1 = node.data
        if r1 == r
            node = _merge!(node, m1, metanode, ms, bpe_or_ranks)
        else
            node = node.next
        end
    end
    return
end

units_itr(bpe::AbstractBPE, x) = graphemes(x)

units2merge(unit::Tuple{Bool, Any}) = Merge(unit[2], false, units[1])
units2merge(unit::SubString{String}) = Merge(unit)
units2merge(unit::Merge) = unit

function merges(bpe::AbstractBPE, x::AbstractString, itr = units_itr(bpe, x))
    endsym = bpe.endsym
    l = MutableLinkedList{Tuple{Merge, Int}}()

    v_state = iterate(itr)
    isnothing(v_state) && return l
    gh1, state = v_state
    m1 = units2merge(gh1)
    while true
        v_state = iterate(itr, state)
        if isnothing(v_state)
            r = typemax(Int)
            if !isnothing(endsym)
                m1 = Merge(m1, true)
                if !isempty(l)
                    m0 = first(pop!(l))
                    r0 = getrank(bpe, (m0, m1))
                    push!(l, (m0, r0))
                end
            end
            push!(l, (m1, r))
            break
        else
            gh2, state = v_state
            m2 = units2merge(gh2)
            r = getrank(bpe, (m1, m2))
            push!(l, (m1, r))
            m1 = m2
        end
    end
    return l
end

as_string(bpe::AbstractBPE, m::Merge) = as_string(m, bpe.sepsym, bpe.endsym)

function _merges2string!(bpe, ms)
    len = length(ms)
    y = Vector{String}(undef, len)

    metanode = ms.node
    node = metanode.next
    i = 1
    while true
        node === metanode && break
        m, _ = node.data
        @inbounds y[i] = as_string(bpe, m)
        prevnode = node
        node = node.next
        i += 1
    end
    return y
end

function bytepairencode(bpe::AbstractBPE, x::AbstractString)
    ms = merges(bpe, x)
    len = length(ms)
    if len == 0
        return String[]
    end
    if len == 1
        m, r = pop!(ms)
        push!(ms, (Merge(m, !isnothing(bpe.endsym)), r))
    else
        merge_loop!(bpe, ms, x)
    end
    y = _merges2string!(bpe, ms)
    return y
end
