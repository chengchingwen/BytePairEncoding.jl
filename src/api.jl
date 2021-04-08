ByteLevelBPE(bfile::AbstractString; kws...) = open(io->ByteLevelBPE(io; kws...), bfile)

function ByteLevelBPE(io::IO;
                      glossaries = nothing,
                      merge::Int = -1, sepsym = nothing, endsym = nothing,
                      has_header::Bool = true,
                      codemap = default_codemap(),
                      input_transform = gpt2_tokenizer,
                      output_transform = nothing,
                      normalizer=nothing)

  cache = Dict{String, String}()
  oldendsym, merging_rank = read_bpefile(io, merge=merge, has_header=has_header)
  glossaries !== nothing && (glossaries = Glossary(glossaries))
  return GenericBPE{String}(; sepsym, oldendsym, endsym, input_transform, output_transform, merging_rank, cache, glossaries, codemap, normalizer)
end
