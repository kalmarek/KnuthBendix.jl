@testset "backtrack" begin
    @testset "Confluence oracle" begin
        R = let n = 3
            Al = Alphabet([:a, :b, :B])
            KB.setinverse!(Al, :b, :B)

            a, b, B = [Word{Int8}([i]) for i in 1:length(Al)]
            ε = one(a)

            eqns = [
                # b*B => ε,
                # B*b => ε,
                (a^2, ε),
                (b^3, ε),
                ((a * b)^7, ε),
                ((a * b * a * B)^n, ε),
            ]

            RewritingSystem(eqns, LenLex(Al), reduced = true)
        end

        a, b, B = [Word{UInt8}([i]) for i in 1:3]

        idxA = Automata.IndexAutomaton(R)
        search_completion =
            Automata.BacktrackSearch(idxA, Automata.ConfluenceOracle())

        let X = collect(search_completion(a))
            @test length(X) == 3
            @test first.(X) ==
                  [a * a, (a * b)^6 * a, (a * b * a * B)^2 * (a * b * a)]
        end

        let X = collect(search_completion(b * a))
            @test length(X) == 3
            @test first.(X) ==
                  [a * a, (a * b)^6 * a, (a * b * a * B)^2 * (a * b * a)]
        end
        @test map(first, search_completion(b)) == [b * b, b * B]
        @test map(first, search_completion(b * a)) ==
              map(first, search_completion(b * a))

        @inferred collect(search_completion(b * a))

        idxA = Automata.IndexAutomaton(R)
        btsearch = Automata.BacktrackSearch(idxA, Automata.ConfluenceOracle())

        for rule in KB.rules(R)
            lhs₁, _ = rule
            tests = map(btsearch(lhs₁[2:end])) do r
                lhs₂, _ = r
                irr = Automata.isaccepting(idxA, last(btsearch.history))
                lb = length(lhs₂) - length(btsearch.history) + 1
                t2 = lb ≥ 1
                t3 = lb < length(lhs₂)
                t4 = lhs₁[end-lb+1:end] == lhs₂[1:lb]
                return !irr && t2 && t3 && t4
            end
            @test all(tests)
        end
    end

    R = let n = 4
        Al = Alphabet([:a, :b, :B])
        KB.setinverse!(Al, :b, :B)

        a, b, B = [Word{Int8}([i]) for i in 1:length(Al)]
        ε = one(a)

        eqns = [
            # b*B => ε,
            # B*b => ε,
            (a^2, ε),
            (b^3, ε),
            ((a * b)^7, ε),
            ((a * b * a * B)^n, ε),
        ]

        knuthbendix(RewritingSystem(eqns, LenLex(Al), reduced = true))
    end

    idxA = Automata.IndexAutomaton(R)

    @testset "LoopSearch oracle" begin
        lso = Automata.LoopSearchOracle()
        bts = Automata.BacktrackSearch(idxA, lso)
        @test isnothing(iterate(bts))
        cert = Automata.infiniteness_certificate(idxA)
        @assert isone(cert.suffix)
        @test isfinite(idxA)

        R = KB.ExampleRWS
    end

    @testset "IrreducibleWords/WordCount oracles" begin
        @test Automata.num_irreducible_words(idxA) == 168
        wrds = collect(Automata.irreducible_words(idxA))
        @test length(wrds) == Automata.num_irreducible_words(idxA)
        l = maximum(length, wrds)
        @test l == 12

        wcount = Automata.WordCountOracle(l)
        iterate(Automata.BacktrackSearch(idxA, wcount))
        @test wcount.counts[1] == 1
        @test sum(wcount.counts) == 168

        @test Automata.num_irreducible_words(idxA, 0, 12) == wcount.counts
        k = 10
        @test sum(Automata.num_irreducible_words(idxA, k, l)) ==
              count(w -> k ≤ length(w) ≤ l, wrds)
    end
end
