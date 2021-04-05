# mapping some unicode character to some other value

struct CodeMap
  from::Vector{StepRange{Char, Int}}
  to::Vector{StepRange{Char, Int}}
end

CodeMap(args...) = CodeMap(args)
function CodeMap(args)
  len = length(args)
  from = Vector{StepRange}(undef, len)
  to = Vector{StepRange}(undef, len)

  for i = 1:len
    arg = args[i]
    if arg isa Tuple{StepRange, StepRange}
      fi, ti = arg
      @assert length(fi) == length(ti) "codemap of two range with different length"
      from[i] = fi
      to[i] = ti
    elseif arg isa Tuple{UnitRange, UnitRange}
      fi, ti = arg
      @assert length(fi) == length(ti) "codemap of two range with different length"
      from[i] = Char(fi.start):Char(fi.stop)
      to[i] = Char(ti.start):Char(ti.stop)
    elseif arg isa Pair{<:Integer, <:Integer}
      fi, ti = arg
      fi = Char(fi)
      ti = Char(ti)
      from[i] = fi:fi
      to[i] = ti:ti      
    elseif arg isa Pair{Char, Char}
      fi, ti = arg
      from[i] = fi:fi
      to[i] = ti:ti
    else
      error("unknow codemap format: only tuple of two char range or pair of char is supported: $(typeof(arg))")
    end
  end
  return CodeMap(from, to)
end

function codemap(cm::CodeMap, x)
  c = Char(x)
  @inbounds for i = 1:length(cm.from)
    fi = cm.from[i]
    if c in fi
      idx = Int(x) - Int(fi.start) + 1
      return UInt16(cm.to[i][idx])
    end
  end
  return UInt16(x)
end

function codeunmap(cm::CodeMap, x)
  c = Char(x)
  @inbounds for i = 1:length(cm.to)
    ti = cm.to[i]
    if c in ti
      idx = Int(x) - Int(ti.start) + 1
      return UInt8(cm.from[i][idx])
    end
  end
  return UInt8(x)
end

encode(cm::CodeMap, x::String) = transcode(String, map(c->codemap(cm, c), transcode(UInt8, x)))
decode(cm::CodeMap, x::String) = transcode(String, map(c->codeunmap(cm, c), transcode(UInt16, x)))
encode(cm::CodeMap, xs::AbstractVector{String}) = map(Base.Fix1(encode, cm), xs)
decode(cm::CodeMap, xs::AbstractVector{String}) = map(Base.Fix1(decode, cm), xs)

(cm::CodeMap)(x) = encode(cm, x)
