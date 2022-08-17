using Unicode

abstract type AbstractBPE end

struct BPE <: AbstractBPE
    merging_rank::Dict{NTuple{2, Merge}, Int}
    sepsym::Union{String, Nothing}
    endsym::Union{String, Nothing}
end
BPE(merging_rank; sepsym = nothing, endsym = nothing) = BPE(merging_rank, sepsym, endsym)

_bigram(ms, i) where T = @inbounds ms[i], ms[i+1]

function lowestrank(merging_rank, ms)
  m0 = _bigram(ms, 1)
  lst = get(merging_rank, m0, typemax(Int))
  li = 1

  for i = 2:(length(ms) - 1)
    m = _bigram(ms, i)
    r = get(merging_rank, m, typemax(Int))
    if r < lst
      m0 = m
      lst = r
      li = i
    end
  end
  return lst, li
end

function merge_loop!(merging_rank, ms, x)
  for _ in 1:length(ms)
    r, i = lowestrank(merging_rank, ms)
    r == typemax(Int) && return ms
    ms = merge!(ms, i)
    isone(length(ms)) && return ms
  end
  return ms
end

function merge!(ms, i)
  m1, m2 = _bigram(ms, i)
  n = Merge(m1, m2)
  desidx = i
  len = length(ms) - 1
  i += 2
  @inbounds ms[desidx] = n
  @inbounds while i <= len
    desidx += 1
    m = ms[i]
    if m == m1 && ms[i+1] == m2
      ms[desidx] = n
      i += 2
    else
      ms[desidx] = m
      i += 1
    end
  end

  if i == length(ms)
    desidx += 1
    @inbounds ms[desidx] = ms[i]
  end

  return @inbounds @view(ms[1:desidx])
end

function merges(x::AbstractString, endsym = nothing)
  buf = map(Merge, graphemes(x))
  if endsym !== nothing
    @inbounds buf[end] = Merge(buf[end], true)
  end
  return buf
end

@inline bpe_postprocess(bpe::BPE, y::Merge) = as_string(y, bpe.sepsym, bpe.endsym)

function (bpe::BPE)(x)
  ms = merges(x, bpe.endsym)
  length(ms) < 2 && return [bpe_postprocess(bpe, Merge(x, !isnothing(bpe.endsym)))]
  y = merge_loop!(bpe.merging_rank, ms, x)
  return map(Base.Fix1(bpe_postprocess, bpe), y)
end

struct CachedBPE{B <: AbstractBPE, D <: AbstractDict{String, Vector{String}}} <: AbstractBPE
    bpe::B
    cache::D
end

CacheBPE(bpe::AbstractBPE) = CacheBPE(bpe, Dict{String, Vector{String}}())

function (bpe::CachedBPE)(x)
    haskey(bpe.cache, x) && return bpe.cache[x]
    y = bpe.bpe(x)
    bpe.cache[x] = y
    return y
end

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
