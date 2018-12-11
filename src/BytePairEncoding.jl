module BytePairEncoding

using WordTokenizers
using InternedStrings

export normalize, UtfNomalizer
export BPELearner, learn!, add!, emit
export set_endsym, set_tokenizer, tokenize, whitespace_tokenize
export isolate_gloss
export Bpe, process_line, segment, segment_token

include("./utfnorm.jl")
include("./stats.jl")
include("./learn.jl")
include("./glossary.jl")
include("./bpe.jl")

end # module
