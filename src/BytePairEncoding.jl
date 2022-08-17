module BytePairEncoding

using TextEncodeBase
using TextEncodeBase: CodeMap
using WordTokenizers

export BPELearner
export BPE, BPETokenization

include("mstring.jl")
include("bpe.jl")
include("tokenization.jl")
include("learn.jl")
include("defaults.jl")
# include("./api.jl")
# include("./old_api.jl")


end # module
