module BytePairEncoding

using TextEncodeBase
using TextEncodeBase: CodeMap
using WordTokenizers
using InternedStrings

export BPELearner, learn!, add!, emit
export Bpe, process_line, segment, segment_token

export GenericBPE, ByteLevelBPE

include("./mstring.jl")
include("./bpe.jl")
include("tokenization.jl")
# include("./learn.jl")
# include("./stats.jl")
include("./defaults.jl")
# include("./api.jl")
# include("./old_api.jl")


end # module
