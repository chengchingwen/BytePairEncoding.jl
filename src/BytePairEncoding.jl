module BytePairEncoding

using TextEncodeBase
using TextEncodeBase: CodeMap

export BPELearner
export BPE, BPETokenization
export BBPEEncoder, RegexTokenization, load_bbpe_encoder

include("mstring.jl")
include("bpe.jl")
include("bytefallback.jl")
include("tokenize_base.jl")
include("tokenization.jl")
include("learn.jl")
include("gpt2_utils.jl")
include("tiktoken.jl")
include("encoder.jl")
include("bbpe_encoder.jl")

end # module
