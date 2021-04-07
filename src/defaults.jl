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
default_codemap() = CodeMap([(0:32, 256:288), (127:160, 289:322), 173=>323])

"the tokenizer used by openai gpt2"
function gpt2_tokenizer(text)
  pattern = r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"
  return map(x->intern(x.match), eachmatch(pattern, text))
end

"simply the built-in split function for the origin tokenize method in subword-nmt"
whitespace_tokenize(str::AbstractString) = split(str)

