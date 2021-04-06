module BytePairEncoding

using WordTokenizers
using InternedStrings

export normalize, UtfNormalizer
export BPELearner, learn!, add!, emit
export set_endsym, set_tokenizer, tokenize, whitespace_tokenize
export isolate_gloss
export Bpe, process_line, segment, segment_token

export GenericBPE

include("./utfnorm.jl")
include("./codemap.jl")
include("./stats.jl")
include("./learn.jl")
include("./glossary.jl")
include("./mstring.jl")
include("./bpe.jl")
include("./defaults.jl")
include("./api.jl")
include("./old_api.jl")

end # module
