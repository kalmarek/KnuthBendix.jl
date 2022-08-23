@testset "KBS" begin
    lenlex = let A = Alphabet(['a', 'A', 'b', 'B'])
        KnuthBendix.setinverse!(A, 'a', 'A')
        KnuthBendix.setinverse!(A, 'b', 'B')
        LenLex(A)
    end

    a, A, b, B = [Word([i]) for i in 1:length(KnuthBendix.alphabet(lenlex))]

    R = RewritingSystem([a * b => b * a], lenlex) # ℤ²

    RC = RewritingSystem(
        [a * b => b * a, b * A => A * b, B * a => a * B, B * A => A * B],
        lenlex,
    ) # ℤ² confluent

    crs = Set(KnuthBendix.rules(RC))

    @test Set(KnuthBendix.rules(KnuthBendix.knuthbendix1(R))) == crs
    @test Set(KnuthBendix.rules(KnuthBendix.knuthbendix2(R))) == crs

    @test Set(
        KnuthBendix.rules(knuthbendix(R, implementation = :naive_kbs1)),
    ) == crs

    @test Set(
        KnuthBendix.rules(knuthbendix(R, implementation = :naive_kbs2)),
    ) == crs

    @test Set(
        KnuthBendix.rules(knuthbendix(R, implementation = :rule_deletion)),
    ) == crs

    @test Set(
        KnuthBendix.rules(knuthbendix(R, implementation = :index_automaton)),
    ) == crs
end
