@testset "Rewriting" begin

    Al = Alphabet(["a", "e", "b", "p"])
    KnuthBendix.set_inversion!(Al, "a", "e")
    KnuthBendix.set_inversion!(Al, "b", "p")
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    @testset "Free Rewriting" begin
        @test KnuthBendix.rewrite_from_left(a * A, Al) == ε
        @test KnuthBendix.rewrite_from_left(a * A * b, Al) == b
        @test KnuthBendix.rewrite_from_left(a * B * b, Al) == a
        @test KnuthBendix.rewrite_from_left(a * B * b * A, Al) == ε
        @test KnuthBendix.rewrite_from_left(a * B * b * a, Al) == a * a
        @test KnuthBendix.rewrite_from_left(a * B * b * a * A, Al) == a
        @test KnuthBendix.rewrite_from_left(a * b * A * B, Al) == a * b * A * B
    end

    @testset "Rule simplification" begin
        Al = deepcopy(Al)
        push!(Al, "z")

        prefix = Word(rand(1:length(Al)-1, 100)) # all invertible
        suffix = Word(rand(1:length(Al)-1, 100)) # all invertible
        l = Word([5, 1, 2, 2])
        r = Word([5, 1, 2, 1])

        @test KnuthBendix.simplifyrule!(prefix * l, prefix * r, Al) == (l, r)
        @test KnuthBendix.simplifyrule!(l * suffix, r * suffix, Al) == (l, r)
        @test KnuthBendix.simplifyrule!(prefix * l * suffix, prefix * r * suffix, Al) ==
              (l, r)
        @test KnuthBendix.simplifyrule!(l * suffix, prefix * r * Word([5]), Al) ==
              (l * suffix, prefix * r * Word([5]))
        @test KnuthBendix.simplifyrule!(copy(l), copy(r), Al) == (l, r)
    end

    @testset "Rewriting System operations" begin

        R = RewritingSystem(
            [a * A => ε, A * a => ε, b * B => ε, B * b => ε, a * b => b * a],
            lenlexord,
            bare = true,
        )

        Z = empty(R)

        @test R isa KnuthBendix.AbstractRewritingSystem
        @test R isa RewritingSystem

        @test R !== Z
        @test isempty(Z)
        @test !isempty(R)

        push!(Z, b * B => ε)
        @test KnuthBendix.rules(Z) == [b * B => ε]
        @test KnuthBendix.ordering(Z) == lenlexord

        pushfirst!(Z, A * a => ε)
        @test KnuthBendix.rules(Z)[1] == (A * a => ε)
        @test KnuthBendix.rules(Z) == [A * a => ε, b * B => ε]

        append!(Z, RewritingSystem([a * b => b * a], lenlexord; bare = true))
        @test KnuthBendix.rules(Z) == [A * a => ε, b * B => ε, a * b => b * a]
        prepend!(Z, RewritingSystem([a * A => ε], lenlexord; bare = true))
        @test KnuthBendix.rules(Z) == [a * A => ε, A * a => ε, b * B => ε, a * b => b * a]

        @test KnuthBendix.rules(Z)[1] == (a * A => ε)
        @test length(Z) == 4
        @test length(KnuthBendix.active(Z)) == length(Z)

        KnuthBendix.setinactive!(Z, 4)
        @test !KnuthBendix.isactive(Z, 4)
        @test KnuthBendix.rules(Z)[KnuthBendix.active(Z)] ==
              [a * A => ε, A * a => ε, b * B => ε]
        @test KnuthBendix.active(Z) == [true, true, true, false]

        KnuthBendix.setactive!(Z, 4)
        @test KnuthBendix.isactive(Z, 4)

        @test KnuthBendix.rules(Z) == [a * A => ε, A * a => ε, b * B => ε, a * b => b * a]

        insert!(Z, 4, B * b => ε) == R
        @test issubset(KnuthBendix.rules(Z), KnuthBendix.rules(R))
        deleteat!(Z, 5)
        @test KnuthBendix.rules(Z) == [a * A => ε, A * a => ε, b * B => ε, B * b => ε]
        deleteat!(Z, 3:4) ==
        RewritingSystem([a * A => ε, A * a => ε], lenlexord, bare = true)
        @test KnuthBendix.rules(Z) == [a * A => ε, A * a => ε]

        @test KnuthBendix.rewrite_from_left(a * A, R) == ε
        @test KnuthBendix.rewrite_from_left(b * B, Z) == b * B

        KnuthBendix.setinactive!(R, 1)
        @test KnuthBendix.rewrite_from_left(a * A, R) == a * A
        KnuthBendix.setactive!(R, 1)
        @test KnuthBendix.rewrite_from_left(a * A, R) == ε

        @test pop!(Z) == (A * a => ε)
        @test popfirst!(Z) == (a * A => ε)
        @test length(KnuthBendix.active(Z)) == 0

        push!(Z, b * B => ε)
        @test KnuthBendix.rules(empty!(Z)) == KnuthBendix.rules(empty(R))
        @test KnuthBendix.rewrite_from_left(b * B, Z) == b * B

        @test sprint(show, Z) isa String
    end
end
