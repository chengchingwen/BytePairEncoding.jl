@testset "glossary" begin
    @testset "isolate_gloss" begin
        gloss = "like"
        isolike(x) = isolate_gloss(x, gloss)
        @test isolike("") == [""]
        @test isolike("word") == ["word"]
        @test isolike("like") == ["like"]
        @test isolike("likeword") == ["like", "word"]
        @test isolike("wordlikeword") == ["word", "like", "word"]
        @test isolike("likelike") == ["like", "like"]
        @test isolike("wordlikewordlike") == ["word", "like", "word", "like"]
    end

    @testset "multiple gloss" begin
        glossaries = ["like", "Manuel", "USA"]
        @test isolate_gloss("wordlikeUSAwordManuelManuelwordUSA" , glossaries) == ["word", "like", "USA", "word", "Manuel", "Manuel", "word", "USA"]
    end

    @testset "regex gloss" begin
        glossaries = [r"<country>\w*</country>", r"<name>\w*</name>", r"\d+"]
        @test isolate_gloss("wordlike<country>USA</country>word10001word<name>Manuel</name>word<country>USA</country>", glossaries) == ["wordlike", "<country>USA</country>", "word", "10001", "word", "<name>Manuel</name>", "word", "<country>USA</country>"]
    end

    @testset "bpe with gloss" begin
        glossaries = ["like", "Manuel", "USA"]

        #mocking bpe
        bpefile = joinpath(dirname(@__FILE__), "data/bpe.out")
        bpe = Bpe(bpefile; sepsym="@@", endsym="", glossaries = glossaries)
        import BytePairEncoding: Bpe
        function (b::Bpe)(x::String)::Tuple
            if x ∈ b.glossaries
                tuple(x)
            else
                l = length(x)
                tuple(x[1:div(l,2)], x[div(l,2)+1:end])
            end
        end

        @test join(segment(bpe, "wordlikeword likeManuelword"), " ") == "wo@@ rd@@ like@@ wo@@ rd like@@ Manuel@@ wo@@ rd"

    end
end
