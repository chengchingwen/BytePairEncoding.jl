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
