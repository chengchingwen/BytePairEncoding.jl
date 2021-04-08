@testset "ByteLevel" begin
  bbpe = ByteLevelBPE(Base.download("https://s3.amazonaws.com/models.huggingface.co/bert/gpt2-merges.txt"))  
  weird_sentence_answer = ["ðĿ", "ĺ", "Ĳ", "Ġ", "ðĿ", "Ĺ", "Ĩ", "ðĿ", "Ĺ", "Ĥ", "ðĿ", "Ĺ", "´", "ðĿ", "ĺ", "©", "ðĿ", "Ļ", "©", "Ġ", "ðĿ", "ļ", "ķ", "ðĿ", "ļ", "ĺ", "ðĿ", "ļ", "ĺ", "k", "Ġ", "ðĿ", "Ļ", "ĩ", "ðĿ", "ĺ", "ª", "ðĿ", "Ĺ", "¸", "ðĿ", "ĸ", "¾", "Ġ", "ðĿ", "ĸ", "Ĩ", "Ġ", "ðĿ", "ĸ", "ĵ", "ðĿ", "ĸ", "Ķ", "ðĿ", "ĸ", "Ĺ", "ðĿ", "ķ", "ŀ", "ðĿ", "ķ", "Ĵ", "ðĿ", "ķ", "Ŀ", "Ġ", "ðĿ", "Ķ", "°", "ðĿ", "ĵ", "®", "ðĿ", "ĵ", "ĥ", "ðĿ", "Ĵ", "ķ", "ðĿ", "ĳ", "Ĵ", "ðĿ", "Ĳ", "§", "ce"]
  @test bbpe("𝘐 𝗆𝗂𝗴𝘩𝙩 𝚕𝚘𝚘k 𝙇𝘪𝗸𝖾 𝖆 𝖓𝖔𝖗𝕞𝕒𝕝 𝔰𝓮𝓃𝒕𝑒𝐧ce") == weird_sentence_answer


  bbpe1 = GenericBPE{String}(; input_transform = BytePairEncoding.gpt2_tokenizer, codemap = BytePairEncoding.default_codemap(), merging_rank=Dict{Tuple{String, String}, Int}(("\u0120", "l")=>1, ("\u0120l", "o")=>2, ("\u0120lo", "w")=>3, ("e", "r")=>4))
  @test bbpe1(" lower newer") == ["\u0120low", "er", "\u0120", "n", "e", "w", "er"]
end
