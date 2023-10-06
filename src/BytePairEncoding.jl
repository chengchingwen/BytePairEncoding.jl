module BytePairEncoding

using TextEncodeBase
using TextEncodeBase: CodeMap

export BPELearner
export BPE, BPETokenization

include("mstring.jl")
include("bpe.jl")
include("bytefallback.jl")
include("tokenization.jl")
include("learn.jl")
include("gpt2_utils.jl")
include("tiktoken.jl")

end # module
