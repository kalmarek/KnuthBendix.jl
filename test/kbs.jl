@testset "KBS" begin
    lenlex = let A = Alphabet([:a, :b, :A, :B])
        KB.setinverse!(A, :a, :A)
        KB.setinverse!(A, :b, :B)
        LenLex(A, order = [:a, :A, :b, :B])
    end

    a, b, A, B = [Word([i]) for i in 1:length(alphabet(lenlex))]

    R = RewritingSystem([(a * b, b * a)], lenlex) # ℤ²

    RC = RewritingSystem(
        [(a * b, b * a), (b * A, A * b), (B * a, a * B), (B * A, A * B)],
        lenlex,
    ) # ℤ² confluent

    crs = Set(KB.rules(RC))

    @test Set(KB.rules(knuthbendix(KB.KBPlain(), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.KBStack(), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.KBS2AlgRuleDel(), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.KBIndex(), R))) == crs
end
