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

    @test Set(KB.rules(knuthbendix(KB.Settings(KB.KBPlain()), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.Settings(KB.KBStack()), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.Settings(KB.KBS2AlgRuleDel()), R))) == crs
    @test Set(KB.rules(knuthbendix(KB.Settings(KB.KBIndex()), R))) == crs

    @testset "io for RewritingSystem" begin
        @test sprint(show, MIME"text/plain"(), RC) isa String
        res = sprint(show, MIME"text/plain"(), RC)
        @test occursin("8 active rules", res)
        @test occursin("LenLex: a < A < b < B", res)
        @test occursin("b*a │ a*b", res)

        sett = KB.Settings(verbosity = 0)
        @test sprint(show, MIME"text/plain"(), sett) isa String
        res = sprint(show, MIME"text/plain"(), sett)
        @test occursin("• verbosity            : 0", res)

        res = sprint(show, MIME"text/plain"(), KB.Settings(; verbosity = 2))
        @test occursin("• verbosity            : 2", res)
    end
end
