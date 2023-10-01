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

struct CachedBPE{B <: AbstractBPE, D <: AbstractDict{String, Vector{String}}} <: AbstractBPE
    bpe::B
    cache::D
end

CachedBPE(bpe::AbstractBPE) = CachedBPE(bpe, Dict{String, Vector{String}}())

function (bpe::CachedBPE)(x)
    haskey(bpe.cache, x) && return bpe.cache[x]
    y = bpe.bpe(x)
    bpe.cache[x] = y
    return y
end

Base.show(io::IO, bpe::CachedBPE) = (print(io, "CachedBPE("); show(io, bpe.bpe); print(io, ')'))


function lowestrank(merging_rank, ms::MutableLinkedList)
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

function merge_loop!(merging_rank, ms, x)
    for _ in 1:length(ms)
        r, i = lowestrank(merging_rank, ms)
        r == typemax(Int) && break
        merge!(ms, i, merging_rank)
        isone(length(ms)) && break
    end
    return
end

function _merge!(node, m1, metanode, ms, ranks)
    nextnode = node.next
    newnextnode = nextnode.next
    m2 = first(nextnode.data)
    m = Merge(m1, m2)
    if newnextnode === metanode
        r = typemax(Int)
    else
        m3 = first(newnextnode.data)
        r = get(ranks, (m, m3), typemax(Int))
    end
    node.data = (m, r)
    node.next = newnextnode
    newnextnode.prev = node
    ms.len -= 1
    prevnode = node.prev
    if prevnode !== metanode
        m0 = first(prevnode.data)
        r = get(ranks, (m0, m), typemax(Int))
        prevnode.data = (m0, r)
    end
    return newnextnode
end

function merge!(ms::MutableLinkedList, node, ranks)
    metanode = ms.node
    m1, r = node.data
    node = _merge!(node, m1, metanode, ms, ranks)
    while node !== metanode
        m1, r1 = node.data
        if r1 == r
            node = _merge!(node, m1, metanode, ms, ranks)
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
    ranks = bpe.merging_rank
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
                    r0 = get(ranks, (m0, m1), typemax(Int))
                    push!(l, (m0, r0))
                end
            end
            push!(l, (m1, r))
            break
        else
            gh2, state = v_state
            m2 = units2merge(gh2)
            r = get(ranks, (m1, m2), typemax(Int))
            push!(l, (m1, r))
            m1 = m2
        end
    end
    return l
end

function _merges2string!(bpe, ms)
    len = length(ms)
    y = Vector{String}(undef, len)

    metanode = ms.node
    node = metanode.next
    i = 1
    while true
        node === metanode && break
        m, _ = node.data
        @inbounds y[i] = as_string(m, bpe.sepsym, bpe.endsym)
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
        merge_loop!(bpe.merging_rank, ms, x)
    end
    y = _merges2string!(bpe, ms)
    return y
end
