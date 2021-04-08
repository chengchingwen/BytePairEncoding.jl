struct GenericBPE{T, IT, OT, G, C, Norm}
  sepsym::Union{T, Nothing}
  oldendsym::Union{T, Nothing}
  endsym::Union{T, Nothing}
  input_transform::IT
  output_transform::OT
  merging_rank::Dict{Tuple{T, T}, Int}
  cache::Dict{T, Vector{T}}
  glossaries::G
  codemap::C
  normalizer::Norm
end

function GenericBPE{T}(;sepsym=nothing, oldendsym = nothing, endsym = oldendsym,
                       input_transform = nothing, output_transform = nothing,
                       merging_rank = Dict{Tuple{T, T}, Int}(), cache = Dict{T, Vector{T}}(),
                       glossaries = nothing, codemap = nothing,
                       normalizer = nothing) where T
  return GenericBPE{T}(sepsym, oldendsym, endsym,
                       input_transform, output_transform,
                       merging_rank, cache,
                       glossaries, codemap, normalizer)
end

function GenericBPE(bpe::GenericBPE{T}; kws...) where T
  kws = kws.data
  sepsym = haskey(kws, :sepsym) ? kws.sepsym : bpe.sepsym
  oldendsym = haskey(kws, :oldendsym) ? kws.oldendsym : bpe.oldendsym
  endsym = haskey(kws, :endsym) ? kws.endsym : bpe.endsym
  input_transform = haskey(kws, :input_transform) ? kws.input_transform : bpe.input_transform
  output_transform = haskey(kws, :output_transform) ? kws.output_transform : bpe.output_transform
  merging_rank = haskey(kws, :merging_rank) ? kws.merging_rank : bpe.merging_rank
  cache = haskey(kws, :cache) ? kws.cache : bpe.cache
  glossaries = haskey(kws, :glossaries) ? kws.glossaries : bpe.glossaries
  codemap = haskey(kws, :codemap) ? kws.codemap : bpe.codemap
  normalizer = haskey(kws, :normalizer) ? kws.normalizer : bpe.normalizer
  return GenericBPE{T}(; sepsym, oldendsym, endsym,
                       input_transform, output_transform,
                       merging_rank, cache,
                       glossaries, codemap, normalizer)
end


function GenericBPE{T}(endsym, merging_rank = Dict{Tuple{T, T}, Int}(); input_transform = nothing, codemap = nothing,
                       glossaries = nothing, normalizer = nothing) where T
  return GenericBPE{T}(; oldendsym=endsym, endsym=endsym, input_transform = input_transform,
                       codemap = codemap, glossaries = glossaries, normalizer = normalizer)
end

function GenericBPE{T}(s, oe, e, i, o, m, c, g, cm, n) where T
  return GenericBPE{T, typeof(i), typeof(o), typeof(g), typeof(cm), typeof(n)}(s, oe, e, i, o, m, c, g, cm, n)
end

Base.eltype(::GenericBPE{T}) where T = T
Base.empty!(bpe::GenericBPE) = (empty!(bpe.cache); empty!(bpe.merging_rank))
Base.length(bpe::GenericBPE) = length(bpe.merging_rank)

read_bpefile(bfile::AbstractString; kws...) = open(io->read_bpefile(io; kws...), bfile)
function read_bpefile(io::IO; has_header::Bool=true, merge::Int = -1)
  rank = Dict{Tuple{String,String}, Int}()

  if has_header
    header = readline(io)
    esi = findlast(isequal("#endsym:"), header)
    oldsym = esi === nothing ? nothing : header[last(esi)+1:end]
  else
    oldsym = nothing
  end

  for (i, line) ∈ enumerate(eachline(io))
    merge < 0 || i <= merge || break
    pair = Tuple(intern.(split(line, ' ')))
    rank[pair] = i
  end
  return oldsym, rank
end

"""
  init_merges(bpe::GenericBPE, x)::Vector{Merge}

Generate the initial list of `Merge`s.
"""
function init_merges(bpe::GenericBPE{String}, x)
  ms = Vector{Merge{String}}(undef, length(x))
  for (i, idx) = enumerate(eachindex(x))
    ms[i] = Merge(SubString(x, idx, idx))
  end
  return ms
end

"""
  merges(bpe::GenericBPE, x)::Vector{Merge}

Return the buffer for merging subword.
"""
function merges(bpe::GenericBPE, x)
  buf = init_merges(bpe, x)
  if bpe.oldendsym !== nothing
    @inbounds buf[end] = Merge(buf[end], bpe.oldendsym)
  end
  return buf
end

"""
  bigram(ms::AbstractVector{Merge{T}}, i)

Get the bigram(`Tuple{T, T}`) of `ms` start at index `i`.
"""
bigram(ms::AbstractVector{Merge{T}}, i) where T = @inbounds ms[i], ms[i+1]

"""
  bigram(T, ms::AbstractVector{Merge}, i) where T

Get the bigram(`Tuple{T, T}`) of `ms` start at index `i` and convert `Merge` to type `T`.
`T(::Merge)` need to be defined.
"""
bigram(::Type{T}, ms::AbstractVector{Merge{T}}, i) where T =  T.(bigram(ms, i))

"""
  lowestrank(bpe::GenericBPE{T}, ms::AbstractVector{Merge{T}}) where T

Get index of the bigram in `ms` with lowest rank value and the value. return `(value, index)`.
"""
function lowestrank(bpe::GenericBPE{T}, ms::AbstractVector{Merge{T}}) where T
  m0 = bigram(T, ms, 1)
  lst = get(bpe.merging_rank, m0, typemax(Int))
  li = 1

  for i = 2:(length(ms) - 1)
    m = bigram(T, ms, i)
    r = get(bpe.merging_rank, m, typemax(Int))
    if r < lst
      m0 = m
      lst = r
      li = i
    end
  end
  return lst, li
end

"""
  merge!(ms::AbstractVector{M}, i) where M <: Merge

Merge the bigram to singal `Merge` in `ms`. All bigram equal to the one at index `i` will also be merged.
"""
function merge!(ms::AbstractVector{M}, i) where M <: Merge
  m1, m2 = bigram(ms, i)
  n = m1 * m2
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

"""
  merge_loop!(bpe::GenericBPE, ms, x)

Iteratively merge subword that is mergeable.
"""
function merge_loop!(bpe::GenericBPE, ms, x)
  for _ in 1:length(ms)
    r, i = lowestrank(bpe, ms)
    r == typemax(Int) && return ms
    ms = merge!(ms, i)
    isone(length(ms)) && return ms
  end
  return ms
end

"""
  bpe_postprocess(bpe::GenericBPE{T}, ms::AbstractVector{Merge{T}}) where T

Convert list of `Merge` to `Vector` of `T` (the encoding result we want).
"""
bpe_postprocess(bpe::GenericBPE{T}, y::AbstractVector{Merge{T}}) where T = map(Base.Fix1(bpe_postprocess, bpe), y)

function bpe_postprocess(bpe::GenericBPE{T}, y::Merge{T}) where T
  transform(s) = T(change_extra(s, bpe.sepsym, bpe.oldendsym, bpe.endsym))
  return intern(transform(y))
end

function flatmap(T, f, xs)
  ys = Vector{T}()
  for x in xs
    y = f(x)
    append!(ys, y)
  end
  return ys
end

"""
  uncache_bpe(bpe::GenericBPE{T}, x::T) where {T}

Byte pair encode `x` without saving the result in `bpe.cache`.
"""
function uncache_bpe(bpe::GenericBPE{T, IT, OT, G}, x) where {T, IT, OT, G}
  !(G <: Nothing) && isgloss(bpe.glossaries, x) && return [bpe_postprocess(bpe, Merge(x, bpe.oldendsym))]
  ms = merges(bpe, x)
  length(ms) < 2 && return [bpe_postprocess(bpe, Merge(x, bpe.oldendsym))]
  y = merge_loop!(bpe, ms, x)
  return bpe_postprocess(bpe, y)
end

uncache_bpe(bpe::GenericBPE, xs::V) where {V <: AbstractVector} = flatmap(eltype(bpe), Base.Fix1(uncache_bpe, bpe), xs)

"""
  bytepairencode(bpe::GenericBPE{T}, x::T) where T

Byte pair encode `x` and save the result in `bpe.cache`.
"""
function bytepairencode(bpe::GenericBPE, x)
  haskey(bpe.cache, x) && return @inbounds bpe.cache[x]
  e = uncache_bpe(bpe, x)
  @inbounds bpe.cache[x] = e
  return e
end

bytepairencode(bpe::GenericBPE, xs::V) where {V <: AbstractVector} = flatmap(eltype(bpe), Base.Fix1(bytepairencode, bpe), xs)

function Base.show(io::IO, bpe::GenericBPE{T}) where T
  print(io, "GenericBPE{$T}(n_merge=$(length(bpe.merging_rank))")
  bpe.endsym === nothing || print(io, ", endsym=$(bpe.endsym)")
  bpe.sepsym === nothing || print(io, ", sepsym=$(bpe.sepsym)")
  bpe.oldendsym === nothing || print(io, ", oldendsym=$(bpe.oldendsym)")
  bpe.input_transform === nothing || print(io, ", input_transform=$(bpe.input_transform)")
  bpe.output_transform === nothing || print(io, ", output_transform=$(bpe.output_transform)")
  bpe.glossaries === nothing || print(io, ", glossaries=$(bpe.glossaries)")
  bpe.codemap === nothing || print(io, ", codemap=$(bpe.codemap)")
  bpe.normalizer === nothing || print(io, ", normalizer=$(bpe.normalizer)")
  print(io, ")")
end

function preprocess(bpe::GenericBPE{T, IT, OT, Nothing, C, Norm}, x) where {T, IT, OT, C, Norm}
  Norm <: Nothing || (x = bpe.normalizer(x))
  IT <: Nothing || (x = bpe.input_transform(x))
  C <: Nothing || (x = bpe.codemap(x))
  return x
end

function preprocess(bpe::GenericBPE{T, IT, OT, G, C, Norm}, x) where {T, IT, OT, G, C, Norm}
  Norm <: Nothing || (x = bpe.normalizer(x))
  x = bpe.glossaries(x)
  g = map(Base.Fix1(isgloss, bpe.glossaries), x)
  IT <: Nothing || begin
    ys = Vector{T}()
    for (xi, gi) in zip(x, g)
      if gi
        push!(ys, xi)
      else
        y = bpe.input_transform(xi)
        append!(ys, y)
      end
    end
    x = ys
  end
  C <: Nothing || (x = bpe.codemap(x))
  return x
end

function (bpe::GenericBPE{T, IT, OT})(x) where {T, IT, OT}
  x = preprocess(bpe, x)
  y  = bytepairencode(bpe, x)
  OT <: Nothing || (y = bpe.output_transform(y))
  return y
end
