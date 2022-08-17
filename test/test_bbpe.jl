using BytePairEncoding: default_codemap, GPT2Tokenization, Merge
using TextEncodeBase: FlatTokenizer, CodeNormalizer, Sentence, getvalue
using Downloads

@testset "ByteLevel" begin
    weird_sentence_answer = ["ðĿ", "ĺ", "Ĳ", "Ġ", "ðĿ", "Ĺ", "Ĩ", "ðĿ", "Ĺ", "Ĥ", "ðĿ", "Ĺ", "´", "ðĿ", "ĺ", "©", "ðĿ", "Ļ", "©", "Ġ", "ðĿ", "ļ", "ķ", "ðĿ", "ļ", "ĺ", "ðĿ", "ļ", "ĺ", "k", "Ġ", "ðĿ", "Ļ", "ĩ", "ðĿ", "ĺ", "ª", "ðĿ", "Ĺ", "¸", "ðĿ", "ĸ", "¾", "Ġ", "ðĿ", "ĸ", "Ĩ", "Ġ", "ðĿ", "ĸ", "ĵ", "ðĿ", "ĸ", "Ķ", "ðĿ", "ĸ", "Ĺ", "ðĿ", "ķ", "ŀ", "ðĿ", "ķ", "Ĵ", "ðĿ", "ķ", "Ŀ", "Ġ", "ðĿ", "Ķ", "°", "ðĿ", "ĵ", "®", "ðĿ", "ĵ", "ĥ", "ðĿ", "Ĵ", "ķ", "ðĿ", "ĳ", "Ĵ", "ðĿ", "Ĳ", "§", "ce"]

    bpe = BPE(Downloads.download("https://s3.amazonaws.com/models.huggingface.co/bert/gpt2-merges.txt"))
    tkr = FlatTokenizer(CodeNormalizer(BPETokenization(GPT2Tokenization(), bpe), default_codemap()))
    @test map(getvalue, tkr(Sentence("𝘐 𝗆𝗂𝗴𝘩𝙩 𝚕𝚘𝚘k 𝙇𝘪𝗸𝖾 𝖆 𝖓𝖔𝖗𝕞𝕒𝕝 𝔰𝓮𝓃𝒕𝑒𝐧ce"))) == weird_sentence_answer

    merges = Dict(
        (Merge("\u0120")   , Merge("l")) => 1,
        (Merge("\u0120l")  , Merge("o")) => 2,
        (Merge("\u0120lo") , Merge("w")) => 3,
        (Merge("e")        , Merge("r")) => 4,
    )
    tkr1 = FlatTokenizer(CodeNormalizer(BPETokenization(GPT2Tokenization(), BPE(merges)), default_codemap()))
    @test map(getvalue, tkr1(Sentence(" lower newer"))) == ["\u0120low", "er", "\u0120", "n", "e", "w", "er"]
end
