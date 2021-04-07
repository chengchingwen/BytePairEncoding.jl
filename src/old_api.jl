"process a line, remain leading & trailing whitespace"
function process_line(bpe::GenericBPE, line)
  pat = r"\S.*\S"
  m = match(pat, line)
  m === nothing && return line
  sentence = m.match
  seg = join(segment(bpe, sentence), ' ')
  return replace(line, pat=>seg)
end

"segment a given sentence"
segment(bpe::GenericBPE, sentence::AbstractString) = bpe(sentence)

"bpe tokens"
segment_token(bpe::GenericBPE, tokens::Vector{String}) = bytepairencode(bpe, tokens)


Bpe(bfile::AbstractString; kws...) = open(io->Bpe(io; kws...), bfile)

function Bpe(io::IO;
             glossaries = nothing, #Vector{Union{Regex, String}}(),
             merge::Int = -1, sepsym = nothing, endsym = "</w>",
             have_header::Bool=true,
             normalizer=nothing)

  cache = Dict{String, Vector{String}}()
  _oldsym, rank = read_bpefile(io, merge=merge, has_header=have_header)
  oldsym = _oldsym === nothing ? "</w>" : _oldsym
  return GenericBPE{String}(sepsym, oldsym, endsym, tokenize, nothing, rank, cache, glossaries, nothing, normalizer)
end

function BPELearner(vfiles::Vector{String}, num_sym::Int;
                    min_freq::Int = 2, endsym = "</w>",
                    normalizer = nothing)
  bpe = GenericBPE{String}(endsym, whitespace_tokenize, nothing, nothing, normalizer)
  vocab = Dict{String, Int}()
  foreach(v->get_vocab!(bpe, vocab, v), vfiles)
  stats = Statistic(bpe, vocab)
  return BPELearner(bpe, num_sym, min_freq, stats)
end

function BPELearner(vocab::Dict{String, Int};
                    min_freq::Int = 2, endsym = "</w>",
                    normalizer = nothing)
  bpe = GenericBPE{String}(endsym, whitespace_tokenize, nothing, nothing, normalizer)
  stats = Statistic(bpe, vocab)
  return BPELearner(bpe, num_sym, min_freq, stats)
end
