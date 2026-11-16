using BytePairEncoding: load_bbpe_encoder, BBPEEncoder, qwen2_regex, regex_tokenize
using TextEncodeBase: encode, decode

@testset "BBPEEncoder" begin
    @testset "qwen2 pre-tokenization" begin
        # digits are split one by one; letters keep one leading non-letter
        @test regex_tokenize(qwen2_regex(), "x 123") == ["x", " ", "1", "2", "3"]
        @test regex_tokenize(qwen2_regex(), "Hello, world!\n\nIt's") ==
              ["Hello", ",", " world", "!\n\n", "It", "'s"]
        @test regex_tokenize(qwen2_regex(), "a  b") == ["a", " ", " b"]
    end

    # byte-level tokens: "Ġ" is a space, "Ċ" a newline (GPT-2 code map)
    tokens = ["a", "b", "c", "Ġ", "ab", "Ġab", "abc", "<|im_start|>", "Ċ", "é", "Ã", "©"]
    merges = ["a b", "Ġ ab", "ab c"]
    e = load_bbpe_encoder(tokens, merges; pattern=qwen2_regex(), special_tokens=["<|im_start|>"])
    @test e isa BBPEEncoder
    @test length(e) == length(tokens)
    # "ab" -> ab; " abc" -> Ġ a b c -> Ġ ab c -> Ġab c ("Ġab c" is not a merge)
    @test e("ab abc") == [4, 5, 2]
    @test encode(e, "ab abc") == [4, 5, 2]
    @test e.tokenizer("ab abc") == ["ab", "Ġab", "c"]
    @test e("<|im_start|>ab\n") == [7, 4, 8]
    @test decode(e, [7, 4, 8]) == "<|im_start|>ab\n"
    @test decode(e, e("ab abc\nc")) == "ab abc\nc"
    # a multi-byte character is two byte tokens, "Ã" (0xC3) and "©" (0xA9)
    @test e("é") == [10, 11]
    @test decode(e, [10, 11]) == "é"
    # a Dict vocabulary (vocab.json) and pair merges give the same encoder
    e2 = load_bbpe_encoder(Dict(t => i - 1 for (i, t) in enumerate(tokens)), [("a", "b"), ("Ġ", "ab"), ("ab", "c")];
                           pattern=qwen2_regex(), special_tokens=["<|im_start|>"])
    @test e2("<|im_start|>ab abc") == [7, 4, 5, 2]
    @test_throws ArgumentError load_bbpe_encoder(tokens, merges; special_tokens=["<nope>"])
    @test_throws ErrorException e("d")     # not in this toy vocabulary
end
