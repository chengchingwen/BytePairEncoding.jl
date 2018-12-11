@testset "utfnorm" begin
    using DelimitedFiles

    hexcode2unicode(x) =  transcode(String, map(x->parse(UInt32, x;base=16), split(x)))

    nr = BytePairEncoding.UtfNormalizer(:NFKC)
    xnr = BytePairEncoding.UnNormalizer()

    tbl = readdlm(joinpath(dirname(@__FILE__), "data/nfkc.tsv"), '\t', String; comments=true)
    for i ∈ 1:size(tbl)[1]
        lhs = hexcode2unicode(tbl[i, 1])
        rhs = hexcode2unicode(tbl[i, 2])
        @test normalize(nr, lhs) == rhs
        @test normalize(xnr, lhs) == lhs
        @test normalize(xnr, rhs) == rhs
    end
end
