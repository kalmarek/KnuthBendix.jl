@testset "Rewriting" begin
    @test_throws String KB.rewrite(Word([1, 2, 3]), "abc")

    Al = Alphabet([:a, :A, :b, :B])
    KB.setinverse!(Al, :a, :A)
    KB.setinverse!(Al, :b, :B)
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    @testset "Rules" begin
        r = KB.Rule(a => ε)
        @test collect(r) == [a, ε]

        @test KB.rewrite(a * A, KB.Rule(a => ε)) == A
        @test KB.rewrite(a * A, KB.Rule(a * A => ε)) == ε
        @test KB.rewrite(a * A, KB.Rule(A * a => ε)) == a * A

        @test sprint(show, KB.Rule(a => ε)) isa String
    end

    @testset "Free Rewriting" begin
        @test KB.rewrite(a * A, Al) == ε
        @test KB.rewrite(a * A * b, Al) == b
        @test KB.rewrite(a * B * b, Al) == a
        @test KB.rewrite(a * B * b * A, Al) == ε
        @test KB.rewrite(a * B * b * a, Al) == a * a
        @test KB.rewrite(a * B * b * a * A, Al) == a
        @test KB.rewrite(a * b * A * B, Al) == a * b * A * B
    end

    @testset "Rule simplification" begin
        Al = Alphabet([:a, :A, :b, :B, :z])
        KB.setinverse!(Al, :a, :A)
        KB.setinverse!(Al, :b, :B)

        prefix = Word(rand(1:length(Al)-1, 100)) # all invertible
        suffix = Word(rand(1:length(Al)-1, 100)) # all invertible
        l = Word([5, 1, 2, 2])
        r = Word([5, 1, 2, 1])

        @test KB.simplify!(prefix * l, prefix * r, Al) == (l, r)
        @test KB.simplify!(l * suffix, r * suffix, Al) == (l, r)
        @test KB.simplify!(
            prefix * l * suffix,
            prefix * r * suffix,
            Al,
        ) == (l, r)
        @test KB.simplify!(l * suffix, prefix * r * Word([5]), Al) ==
              (l * suffix, prefix * r * Word([5]))
        @test KB.simplify!(copy(l), copy(r), Al) == (l, r)

        @test KB.simplify!(a^4, a^2, Al) == (a^2, one(a))
    end

    @testset "Rewriting System operations" begin
        ord = LenLex(Alphabet([:a, :A, :b, :B]))
        R = RewritingSystem(
            [(a * A, ε), (A * a, ε), (b * B, ε), (B * b, ε), (a * b, b * a)],
            ord,
        )

        Z = empty(R)

        @test R isa RewritingSystem
        @test !isconfluent(R)
        @test !KB.isreduced(R)

        @test R !== Z
        @test isempty(Z)
        @test !isempty(R)

        push!(Z, KB.Rule(b * B => ε))
        @test collect(KB.rules(Z)) == [KB.Rule(b * B => ε)]
        @test KB.ordering(Z) == ord

        KB.deactivate!(first(KB.rules(Z)))
        @test isempty(collect(KB.rules(Z)))

        @test KB.rewrite(a * A, R) == ε
        @test KB.rewrite(b * B, Z) == b * B

        KB.deactivate!(first(KB.rules(R)))
        @test KB.rewrite(a * A, R) == a * A

        push!(Z, KB.Rule(b * B => ε))
        @test isempty(KB.rules(empty!(Z)))
        @test isempty(KB.rules(empty(R)))
        @test KB.rewrite(b * B, Z) == b * B

        @test sprint(show, R) isa String
    end
end
