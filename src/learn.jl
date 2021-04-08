struct BPELearner{B<:GenericBPE}
  bpe::B
  merge::Int
  min_freq::Int
  vocabs::Dict{String, Int}
end

get_vocab(bpe::GenericBPE{String}, v) = get_vocab!(bpe, Dict{String, Int}(), v)
get_vocab!(bpe::GenericBPE{String}, vocab::Dict{String, Int}, vfile::AbstractString) = open(io->get_vocab!(bpe, vocab, io), vfile)
function get_vocab!(bpe::GenericBPE{String}, vocab::Dict{String, Int}, io::IO)
  for line in  eachline(io)
    tokens = preprocess(bpe, line)
    for token in tokens
      vocab[intern(token)] = get(vocab, token, 0) + 1
    end
  end
  return vocab
end

"add a new file to learner"
add!(bper::BPELearner, vfile::String) = get_vocab!(bper.bpe, bper.vocabs, vfile)

"learn a BPE map"
function learn!(bper::BPELearner)
  empty!(bper.bpe)
  stats = Statistic(bper)
  for i ∈ 1:bper.merge
    mfp = most_freq(stats)
    get_freq(stats, mfp) < bper.min_freq && break
    merge_pair!(stats, mfp)
    bper.bpe.merging_rank[Tuple(mfp)] = i
  end
  return bper.bpe
end

function emit(bper::BPELearner)
  m = Vector{Tuple{String, String}}(undef, length(bper.bpe))
  for (bigram, rank) in bper.bpe.merging_rank
    m[rank] = bigram
  end
  return m
end

"emit the BPE map to ofile; can add one-line comment to the header(first line)"
function emit(bper::BPELearner, ofile::AbstractString; comment::String = "")
  @assert '\n' ∉ comment && '\r' ∉ comment
  open(ofile, "w+") do fo
    write(fo, ":$comment#endsym:$(bper.bpe.endsym)\n")
    for (f, s) ∈ emit(bper)
      write(fo, f, " ", s, "\n")
    end
  end
  return ofile
end

function Base.show(io::IO, bper::BPELearner)
  print(io, "BPELearner(bpe = ")
  show(io, bper.bpe)
  print(io, ", merge = ", bper.merge)
  print(io, ", min_freq = ", bper.min_freq)
  print(io, ")")
end
