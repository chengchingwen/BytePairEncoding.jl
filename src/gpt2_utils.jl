using Artifacts
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

"the tokenizer used by openai gpt2"
function gpt2_tokenizer(text)
  pattern = r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"
  return map(x->String(x.match), eachmatch(pattern, text))
end

function load_gpt2()
    ENDOFTEXT = "<|endoftext|>"
    artifact_dir = artifact"gpt2"
    path = joinpath(artifact_dir, "vocab.bpe")
    bpe = BPE(path)
    base_tkr = GPT2Tokenization()
    matches = [ENDOFTEXT]
    tkr = TextEncodeBase.FlatTokenizer(
        TextEncodeBase.MatchTokenization(
            TextEncodeBase.CodeNormalizer(
                BPETokenization(base_tkr, bpe),
                gpt2_codemap()),
            matches
        )
    )
    return tkr
end
