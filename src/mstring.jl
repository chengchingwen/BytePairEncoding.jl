"""
  Merge{T}(s::T, offset::Int, nunits::Int, extra::Union{T, Nothing})

Similar to `SubString` but different.
"""
struct Merge{T}
  string::T
  offset::Int
  nunits::Int
  extra::Union{T, Nothing}
end

Merge(a::Merge, e) = Merge(a.string, a.offset, a.nunits, e)
Merge(s::SubString) = Merge(s, nothing)
Merge(s::SubString, e) = Merge(s.string, s.offset, s.ncodeunits, e)
Merge(s::String, e) = Merge(SubString(s), e)

SubString(a::Merge{String}) = SubString(a.string, a.offset+1, prevind(a.string, a.offset+a.nunits+1))

function String(a::Merge{String})
  s = SubString(a)
  if a.extra === nothing
    return String(s)
  else
    return string(s, a.extra)
  end
end

change_extra(a::Merge, s, o, e) = a.extra == o ? Merge(a, e) : Merge(a, s)

function Base.:(*)(a::Merge{T}, b::Merge{T}) where T
  if a.string === b.string
    if a.offset < b.offset
      offset = a.offset
      @assert offset + a.nunits == b.offset "merge un-adjacent Merge"
    elseif a.offset > b.offset
      offset = b.offset
      @assert offset + b.nunits == a.offset "merge un-adjacent Merge"
    else
      error("merge two Merge at same offset: partial string?")
    end
    nunits = a.nunits + b.nunits
    return Merge(a.string, offset, nunits, b.extra)
  else
    error("merge different Merge")
  end
end

function Base.show(io::IO, a::Merge)
  show(io, SubString(a))
  if a.extra !== nothing
    print(io, " + ")
    show(io, a.extra)
  end
  return io
end
