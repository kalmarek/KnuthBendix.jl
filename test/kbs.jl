@testset "KBS" begin
    lenlex = let A = Alphabet([:a, :b, :A, :B])
        KnuthBendix.setinverse!(A, :a, :A)
        KnuthBendix.setinverse!(A, :b, :B)
        LenLex(A, order = [:a, :A, :b, :B])
    end

    a, b, A, B = [Word([i]) for i in 1:length(KnuthBendix.alphabet(lenlex))]

    R = RewritingSystem([(a * b, b * a)], lenlex) # ℤ²

    RC = RewritingSystem(
        [(a * b, b * a), (b * A, A * b), (B * a, a * B), (B * A, A * B)],
        lenlex,
    ) # ℤ² confluent

    crs = Set(KnuthBendix.rules(RC))

    @test Set(KnuthBendix.rules(KnuthBendix.knuthbendix1(R))) == crs
    @test Set(KnuthBendix.rules(KnuthBendix.knuthbendix2(R))) == crs

    @test Set(KnuthBendix.rules(knuthbendix(KnuthBendix.KBS1AlgPlain(), R))) ==
          crs

    @test Set(KnuthBendix.rules(knuthbendix(KnuthBendix.KBS2AlgPlain(), R))) ==
          crs

    @test Set(
        KnuthBendix.rules(knuthbendix(KnuthBendix.KBS2AlgRuleDel(), R)),
    ) == crs

    @test Set(
        KnuthBendix.rules(knuthbendix(KnuthBendix.KBS2AlgIndexAut(), R)),
    ) == crs
end
