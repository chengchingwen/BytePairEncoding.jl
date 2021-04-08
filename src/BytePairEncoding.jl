module BytePairEncoding

using WordTokenizers
using InternedStrings

export normalize, UtfNormalizer
export BPELearner, learn!, add!, emit
export Bpe, process_line, segment, segment_token

export GenericBPE, ByteLevelBPE

include("./utfnorm.jl")
include("./codemap.jl")
include("./glossary.jl")
include("./mstring.jl")
include("./bpe.jl")
include("./stats.jl")
include("./learn.jl")
include("./defaults.jl")
include("./api.jl")
include("./old_api.jl")

end # module
