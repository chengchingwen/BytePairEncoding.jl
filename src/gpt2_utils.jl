using Artifacts, LazyArtifacts
using TextEncodeBase

# function bytes_to_unicode()
#   cs = vcat(collect(('!'):('~')), collect(('¡'):('¬')), collect(('®'):('ÿ')))
#   bs = map(Int, cs)
#   cs = bs[:]
#   n = 0
#   for b in 0:2^8 - 1
#     if !(b in bs)
#       push!(bs, b)
#       push!(cs, 2^8 + n)
#       n += 1
#     end
#   end
#   cs = map(Char, cs)
#   return Dict(zip(bs, cs))
# end

"the codemap used by openai gpt2"
gpt2_codemap() = CodeMap(Pair[0:32=>256:288, 127:160=>289:322, 173=>323])

load_gpt2_bpe() = BPE(joinpath(artifact"gpt2", "vocab.bpe"))

"""
    load_gpt2()

Load gpt2 tokenizer.
"""
function load_gpt2()
    ENDOFTEXT = "<|endoftext|>"
    bpe = load_gpt2_bpe()
    base_tkr = GPT2Tokenization()
    matches = [ENDOFTEXT]
    tkr = BPETokenizer(
        TextEncodeBase.MatchTokenization(
            TextEncodeBase.CodeNormalizer(
                BPETokenization(base_tkr, bpe),
                gpt2_codemap()),
            matches
        )
    )
    return tkr
end
