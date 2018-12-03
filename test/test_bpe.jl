@testset "bpe" begin
    infile = joinpath(dirname(@__FILE__), "data/corpus.en")
    bpefile = joinpath(dirname(@__FILE__), "data/bpe.out")
    refile = joinpath(dirname(@__FILE__), "data/corpus.bpe.ref.en")

    bpe = Bpe(bpefile; sepsym="@@", endsym="")

    open(refile) do fr
        open(infile) do fi
            for (li, lr) ∈ zip(eachline(fi), eachline(fr))
                @test process_line(bpe, li) == lr
            end
        end
    end

    @test process_line(bpe, "  iron cement  \n") == "  ir@@ on c@@ ement  \n"
    @test process_line(bpe, "iron" * "\ua0" * "cement\n") == "ir@@ on@@ "*"\ua0"*"@@ c@@ ement\n"
    @test process_line(bpe, "\n") == "\n"
end
