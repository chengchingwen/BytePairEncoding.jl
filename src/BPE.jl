module BPE

using WordTokenizers
using InternedStrings

export BPELearner, learn!, add!, emit
export set_endsym, set_tokenizer, tokenize, whitespace_tokenize
export isolate_gloss
export Bpe, process_line, segment, segment_token

include("./stats.jl")
include("./learn.jl")
include("./glossary.jl")
include("./bpe.jl")

end # module
