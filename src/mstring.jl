struct Merge
    string::String
    offset::UInt16
    ncodeunits::UInt16
    extra::Bool
end

Merge(str, offset::Int, ncodeunits::Int, extra) = Merge(str, UInt16(offset), UInt16(ncodeunits), extra)
Merge(a::Merge, e::Bool) = Merge(a.string, a.offset, a.ncodeunits, e)
Merge(s::SubString, e::Bool = false) = Merge(s.string, s.offset, s.ncodeunits, e)
Merge(s::String, e::Bool = false) = Merge(SubString(s), e)

function Merge(a::Merge, b::Merge)
  if a.string === b.string
    if a.offset < b.offset
      offset = a.offset
      @assert offset + a.ncodeunits == b.offset "merge un-adjacent Merge"
    elseif a.offset > b.offset
      offset = b.offset
      @assert offset + b.ncodeunits == a.offset "merge un-adjacent Merge"
    else
      error("merge two Merge at same offset: partial string?")
    end
    nunits = a.ncodeunits + b.ncodeunits
    return Merge(a.string, offset, nunits, b.extra)
  else
    error("merge different Merge")
  end
end

function parse_merge(line::AbstractString, pattern = nothing)
    pair = Tuple(split(line, ' '; limit = 2))::NTuple{2, SubString{String}}
    return parse_merge(pair, pattern)
end
function parse_merge(pair::NTuple{2}, pattern = nothing)
    p1, p2 = pair
    p1 = Merge(String(p1))
    if !isnothing(pattern)
        m = match(pattern, p2)
        extra = !isnothing(m)
        if extra
            p2 = m.captures[]
        end
        p2 = Merge(String(p2), extra)
    else
        p2 = Merge(String(p2))
    end
    return (p1, p2)
end

read_merges(f::AbstractString, endsym = nothing; kws...) = open(io->read_merges(io, endsym; kws...), f)
function read_merges(io::IO, endsym = nothing; limit = typemax(Int), header = true)
    rank = Dict{NTuple{2, Merge}, Int}()
    if header
        line1 = readline(io)
        if isnothing(endsym)
            # use the endsym from file only when not provided
            esi = findlast("#endsym:", line1)
            if !isnothing(esi)
                endsym_s = line1[last(esi)+1:end]
                endsym = isempty(endsym_s) ? nothing : endsym_s
            end
        end
    end
    pattern = isnothing(endsym) ? nothing : Base.compile(Regex("(.*)\\Q$endsym\\E\$"))
    for (i, line) in enumerate(eachline(io))
        i > limit && break
        p = parse_merge(line, pattern)
        rank[p] = i
    end
    return rank
end

function rank2list(rank::Dict{NTuple{2, Merge}, Int}, endsym = nothing)
    list = Vector{NTuple{2, String}}(undef, length(rank))
    for (k, v) in rank
        list[v] = as_string.(k, nothing, endsym)
    end
    return list
end

write_merges(file::AbstractString, rank, endsym = nothing; limit = typemax(Int), comment = "", header = true) =
    open(io->write_merges(io, rank, endsym; limit, comment, header), file)
function write_merges(io::IO, rank, endsym = nothing; limit = typemax(Int), comment = "", header = true)
    list = rank2list(rank, endsym)
    header && write(io, ":$(comment)#endsym:$(endsym)\n")
    for i in 1:min(length(rank), limit)
        p = list[i]
        write(io, p[1], ' ', p[2], '\n')
    end
    return
end

function Base.hash(m::Merge, h::UInt)
    h = hash(m.extra, h) + Base.memhash_seed
    str_size = m.ncodeunits * sizeof(UInt8)
    str = m.string
    ptr = convert(Ptr{UInt8}, pointer(str)) + m.offset
    return GC.@preserve str ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), ptr, str_size, h % UInt32) + h
end

function Base.:(==)(m1::Merge, m2::Merge)
    m1.extra == m2.extra || return false
    s = m1.ncodeunits
    s == m2.ncodeunits || return false
    str1 = m1.string
    str2 = m2.string
    p1 = convert(Ptr{UInt8}, pointer(str1)) + m1.offset
    p2 = convert(Ptr{UInt8}, pointer(str2)) + m2.offset
    return GC.@preserve str1 str2 0 == Base._memcmp(p1, p2, s * sizeof(UInt8))
end

function as_string(m::Merge, sepsym, endsym)
    str = m.string
    offset = m.offset
    s = SubString(str, offset+1, prevind(str, offset + m.ncodeunits + 1))
    sym = m.extra ? endsym : sepsym
    return isnothing(sym) ? String(s) : string(s, sym)
end
