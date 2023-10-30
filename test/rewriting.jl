@testset "Rewriting" begin
    @test_throws String KnuthBendix.rewrite(Word([1, 2, 3]), "abc")

    Al = Alphabet([:a, :A, :b, :B])
    KnuthBendix.setinverse!(Al, :a, :A)
    KnuthBendix.setinverse!(Al, :b, :B)
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    @testset "Rules" begin
        r = KnuthBendix.Rule(a => ε)
        @test collect(r) == [a, ε]

        @test KnuthBendix.rewrite(a * A, KnuthBendix.Rule(a => ε)) == A
        @test KnuthBendix.rewrite(a * A, KnuthBendix.Rule(a * A => ε)) == ε
        @test KnuthBendix.rewrite(a * A, KnuthBendix.Rule(A * a => ε)) == a * A

        @test sprint(show, KnuthBendix.Rule(a => ε)) isa String
    end

    @testset "Free Rewriting" begin
        @test KnuthBendix.rewrite(a * A, Al) == ε
        @test KnuthBendix.rewrite(a * A * b, Al) == b
        @test KnuthBendix.rewrite(a * B * b, Al) == a
        @test KnuthBendix.rewrite(a * B * b * A, Al) == ε
        @test KnuthBendix.rewrite(a * B * b * a, Al) == a * a
        @test KnuthBendix.rewrite(a * B * b * a * A, Al) == a
        @test KnuthBendix.rewrite(a * b * A * B, Al) == a * b * A * B
    end

    @testset "Rule simplification" begin
        Al = Alphabet([:a, :A, :b, :B, :z])
        KnuthBendix.setinverse!(Al, :a, :A)
        KnuthBendix.setinverse!(Al, :b, :B)

        prefix = Word(rand(1:length(Al)-1, 100)) # all invertible
        suffix = Word(rand(1:length(Al)-1, 100)) # all invertible
        l = Word([5, 1, 2, 2])
        r = Word([5, 1, 2, 1])

        @test KnuthBendix.simplify!(prefix * l, prefix * r, Al) == (l, r)
        @test KnuthBendix.simplify!(l * suffix, r * suffix, Al) == (l, r)
        @test KnuthBendix.simplify!(
            prefix * l * suffix,
            prefix * r * suffix,
            Al,
        ) == (l, r)
        @test KnuthBendix.simplify!(l * suffix, prefix * r * Word([5]), Al) ==
              (l * suffix, prefix * r * Word([5]))
        @test KnuthBendix.simplify!(copy(l), copy(r), Al) == (l, r)

        @test KnuthBendix.simplify!(a^4, a^2, Al) == (a^2, one(a))
    end

    @testset "Rewriting System operations" begin
        ord = LenLex(Alphabet([:a, :A, :b, :B]))
        R = RewritingSystem(
            [a * A => ε, A * a => ε, b * B => ε, B * b => ε, a * b => b * a],
            ord,
        )

        Z = empty(R)

        @test R isa RewritingSystem

        @test R !== Z
        @test isempty(Z)
        @test !isempty(R)

        push!(Z, KnuthBendix.Rule(b * B => ε))
        @test collect(KnuthBendix.rules(Z)) == [KnuthBendix.Rule(b * B => ε)]
        @test KnuthBendix.ordering(Z) == ord

        KnuthBendix.deactivate!(first(KnuthBendix.rules(Z)))
        @test isempty(collect(KnuthBendix.rules(Z)))

        @test KnuthBendix.rewrite(a * A, R) == ε
        @test KnuthBendix.rewrite(b * B, Z) == b * B

        KnuthBendix.deactivate!(first(KnuthBendix.rules(R)))
        @test KnuthBendix.rewrite(a * A, R) == a * A

        push!(Z, KnuthBendix.Rule(b * B => ε))
        @test isempty(KnuthBendix.rules(empty!(Z)))
        @test isempty(KnuthBendix.rules(empty(R)))
        @test KnuthBendix.rewrite(b * B, Z) == b * B

        @test sprint(show, R) isa String
    end
end
