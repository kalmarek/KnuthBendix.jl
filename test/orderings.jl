import Base.Order.lt

function generic_tests(ord::KB.RewritingOrdering)
    @testset "Generic properties: $ord" begin
        X = alphabet(ord)
        @test X isa KB.Alphabet
        S = [Word([i]) for i in 1:length(X)]
        @test !lt(ord, one(first(S)), one(first(S)))

        @test all(lt(ord, one(s), s) for s in S)
        @test !any(lt(ord, s, one(s)) for s in S)

        @test all(
            lt(ord, one(first(S)), Word(rand(1:length(X), 5))) for _ in 1:10
        )

        # left invariance
        w = Word(rand(1:length(X), 10))
        idcs = [(i, j) for i in 1:length(X) for j in 1:length(X)]

        @test all(
            lt(ord, w * S[i], w * S[j]) for
            (i, j) in idcs if lt(ord, S[i], S[j])
        )
        @test all(
            !lt(ord, w * S[i], w * S[j]) for
            (i, j) in idcs if !lt(ord, S[i], S[j])
        )
    end
end

@testset "Orderings" begin
    @testset "LenLex" begin
        al = Alphabet([:a, :A, :b, :B])
        a, A, b, B = [Word([i]) for i in 1:length(al)]
        lenlex = LenLex(al, order = [:a, :b, :B, :A])
        @test contains(sprint(show, lenlex), "a < b < B < A")

        generic_tests(lenlex)

        # a < b < B < A
        @test lt(lenlex, a, b)
        @test lt(lenlex, b, B)
        @test lt(lenlex, B, A)

        # ! a < a
        @test !lt(lenlex, a, a)
        # A > B > b > a
        @test !lt(lenlex, b, a)
        @test !lt(lenlex, B, b)
        @test !lt(lenlex, A, B)

        @test !lt(lenlex, a * b * B * b, a * b * B * a)
        @test !lt(lenlex, a * b * B * b, a * b * B * b)
        @test lt(lenlex, a * b * B * b, a * b * B * B)
        @test lt(lenlex, a * b * B * b, a * b * B * A)
    end

    @testset "WeightedLex" begin
        al = Alphabet([:a, :A, :b, :B])
        a, A, b, B = [Word([i]) for i in 1:length(al)]
        # WeightedLex
        @test_throws AssertionError WeightedLex(al, weights = [1, 2, 3])
        @test_throws AssertionError WeightedLex(al, weights = [1, 2, 3, -4])

        wtlex =
            WeightedLex(al, weights = [1, 2, 3, 4], order = [:a, :b, :B, :A])
        @test contains(sprint(show, wtlex), "a(1) < b(3) < B(4) < A(2)")

        generic_tests(wtlex)

        @test lt(wtlex, first(a), first(b))
        @test lt(wtlex, first(b), first(B))
        @test lt(wtlex, first(B), first(A))
        @test !lt(wtlex, first(A), first(a))

        @test sort([1, 2, 3, 4], order = wtlex) == [1, 3, 4, 2]

        @test lt(wtlex, a * a, A)
        @test lt(wtlex, A, a * a * a)
        @test lt(wtlex, B * A, A * B)
        @test lt(wtlex, b * B, B * a * a * a)
    end

    @testset "WreathOrder" begin
        @testset "Sims Example 1.1" begin
            X = Alphabet([:a, :b, :B])
            a, b, B = Word([1]), Word([2]), Word([3])

            wro = WreathOrder(X, levels = [1, 2, 2], order = [:a, :b, :B])

            generic_tests(wro)

            @test lt(wro, a^100, a * b * a^2) # by level only
            @test lt(wro, a^2 * b * a, b^2 * a) # by max-level word
            @test lt(wro, a * B, b * a * B * B) # by length of max-level word
            @test lt(wro, b * a * B * b, b * a * B * B) # by max-level word

            @test lt(wro, a * b * a^2, a^2 * b * a) # by the lower level prefix
            @test lt(wro, b^2 * a, b * a * b) # by the lower level prefix
            @test lt(wro, b * a * b, a * b^2) # by the lower level prefix

            @test !lt(wro, a * b * a * b, a * b^2) # by the lower level prefix

            v = [a * b^2, b * a * b, b^2 * a, a^2 * b * a, a * b * a^2, a^100]

            @test sort(v, order = wro) ==
                  [a^100, a * b * a^2, a^2 * b * a, b^2 * a, b * a * b, a * b^2]
        end

        @testset "Sims Example 1.2" begin
            X = Alphabet([:a, :b, :A, :B])
            a, b, A, B = [Word([i]) for i in 1:length(X)]
            wro =
                WreathOrder(X, levels = [1, 2, 1, 2], order = [:a, :A, :b, :B])
            @test contains(sprint(show, wro), "a(1) < A(1) < b(2) < B(2)")

            generic_tests(wro)

            @test lt(wro, one(a), Word(rand(1:length(X), 5)))

            @test lt(wro, first(a), first(A))
            @test lt(wro, first(A), first(b))
            @test lt(wro, first(b), first(B))
            @test !lt(wro, first(B), first(a))

            @test lt(wro, a * b * A * B * a^2, A * b * a^2 * B * a)
            @test lt(wro, A * b * a^2 * B * a, a^2 * B * a * b * A)
            @test lt(wro, a^2 * B * a * b * A, a^2 * B * A * b * a)
        end

        let X = Alphabet([:a, :A, :b, :B], [2, 1, 4, 3])
            a, A, b, B = [Word([i]) for i in 1:length(X)]
            wro = WreathOrder(X, levels = [1, 3, 5, 7])
            @test contains(sprint(show, wro), "a(1) < A(3) < b(5) < B(7)")

            generic_tests(wro)

            @test lt(wro, one(a), Word(rand(1:length(X), 5)))

            w1 = b * a * (B) * A * b
            w2 = a * b * (B) * b * A

            w3 = (a * b) * A * a * (B) * a * A
            w4 = (a * b) * a * A * (B) * A * a

            w5 = (a * A * b * A) * B * a * (A * B)
            w6 = (a * A * b * A) * a * B * (A * B)
            ε = one(w1)

            a = [w1, w5, w4, w6, w2, w3, ε]

            @test sort(a, order = wro) == [ε, w1, w2, w3, w4, w5, w6]
        end
    end

    @testset "Recursive" begin
        X = Alphabet([:a, :A, :b, :B], [2, 1, 4, 3])
        a, A, b, B = [Word([i]) for i in 1:length(X)]

        rec = KB.Recursive{KB.Right}(
            X,
            order = [:a, :A, :b, :B],
        )
        @test contains(sprint(show, rec), "a < A < b < B")

        generic_tests(rec)

        @test lt(rec, first(a), first(A))
        @test lt(rec, first(A), first(b))
        @test lt(rec, first(b), first(B))
        @test !lt(rec, first(B), first(a))

        v = [a * B, a, a * A * A * B, A * a * B, one(a)]
        @test sort(v, order = rec) ==
              [one(a), a, a * B, A * a * B, a * A * A * B]
        w = [b * A * a * B * a, A * a * B, a, one(a), A * B * a, A, B * a]
        @test sort(w, order = rec) ==
              [one(a), a, A, A * a * B, B * a, A * B * a, b * A * a * B * a]

        @testset "Sims Example 1.1" begin
            X = Alphabet([:a, :b])
            a, b = Word([1]), Word([2])

            rec = Recursive(X, order = [:a, :b]) # i.e. left-recursive
            generic_tests(rec)
            @test lt(rec, first(a), first(b))
            @test !lt(rec, first(b), first(a))

            @test lt(rec, one(a), Word(rand(1:length(X), 5)))

            @test lt(rec, a^100, a * b * a^2) # by level only
            @test lt(rec, a^2 * b * a, b^2 * a) # by max-level word
            @test lt(rec, a * b * a^2, a^2 * b * a) # by the lower level prefix
            @test lt(rec, b^2 * a, b * a * b) # by the lower level prefix
            @test lt(rec, b * a * b, a * b^2) # by the lower level prefix

            @test !lt(rec, a * b * a * b, a * b^2) # by the lower level prefix

            v = [a * b^2, b * a * b, b^2 * a, a^2 * b * a, a * b * a^2, a^100]

            @test sort(v, order = rec) ==
                  [a^100, a * b * a^2, a^2 * b * a, b^2 * a, b * a * b, a * b^2]
        end

        let X = Alphabet([:a, :b, :A, :B], [3, 4, 1, 2])
            a, A, b, B = [Word([i]) for i in 1:length(X)]
            wro = Recursive{KB.Left}(X, order = [:a, :A, :b, :B])
            generic_tests(rec)

            w1 = b * a * (B) * A * b
            w2 = a * b * (B) * b * A

            w3 = (a * b) * A * a * (B) * a * A
            w4 = (a * b) * a * A * (B) * A * a

            w5 = (a * A * b * A) * B * a * (A * B)
            w6 = (a * A * b * A) * a * B * (A * B)
            ε = one(w1)

            a = [w1, w5, w4, w6, w2, w3, ε]

            @test sort(a, order = wro) == [ε, w1, w2, w3, w4, w5, w6]
        end

        @testset "Independence from alphabet order" begin
            let Al = Alphabet([:b, :a, :A], [0, 3, 2])
                b, a, A = [Word([i]) for i in 1:length(Al)]
                rec = Recursive(Al, order = [:a, :A, :b])
                @test occursin("a < A < b", sprint(show, rec))
                @test lt(rec, b * a^10, a * b)
                @test !lt(rec, b * a^10, b)
                @test lt(rec, a * A, b * a^10)
            end

            let Al = Alphabet([:a, :A, :b], [2, 1, 0])
                a, A, b = [Word([i]) for i in 1:length(Al)]
                rec = Recursive(Al, order = [:a, :A, :b])
                @test occursin("a < A < b", sprint(show, rec))
                @test lt(rec, b * a^10, a * b)
                @test !lt(rec, b * a^10, b)
                @test lt(rec, a * A, b * a^10)
            end
        end
    end
end
