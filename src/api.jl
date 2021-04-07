ByteLevelBPE(bfile::AbstractString; kws...) = open(io->ByteLevelBPE(io; kws...), bfile)

function ByteLevelBPE(io::IO;
              glossaries = nothing,
              merge::Int = -1, sepsym = nothing, endsym = nothing,
              has_header::Bool = true,
              codemap = default_codemap(),
              input_transform = gpt2_tokenizer,
              normalizer=nothing)

  cache = Dict{String, String}()
  oldsym, rank = read_bpefile(io, merge=merge, has_header=has_header)
  return GenericBPE{String}(sepsym, oldsym, endsym, input_transform, nothing, rank, cache, glossaries, codemap, normalizer)
end
