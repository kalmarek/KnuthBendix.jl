@testset "backtrack" begin
    R = let n = 3
        Al = Alphabet([:a, :b, :B])
        KnuthBendix.setinverse!(Al, :b, :B)

        a, b, B = [Word{Int8}([i]) for i in 1:length(Al)]
        ε = one(a)

        eqns = [
            # b*B => ε,
            # B*b => ε,
            a^2 => ε,
            b^3 => ε,
            (a * b)^7 => ε,
            (a * b * a * B)^n => ε,
        ]

        RewritingSystem(eqns, LenLex(Al), reduced = true)
    end

    a, b, B = [Word{UInt8}([i]) for i in 1:3]
    idxA = Automata.IndexAutomaton(R)
    search_completion = Automata.BacktrackSearch(idxA)

    let X = collect(search_completion(a))
        @test length(X) == 3
        for st in X
            @test Automata.isterminal(idxA, st)
            @test first(Automata.value(st)) == Automata.signature(idxA, st)
        end
    end

    let X = collect(search_completion(b * a))
        @test length(X) == 3
        for st in X
            @test Automata.isterminal(idxA, st)
            @test first(Automata.value(st)) == Automata.signature(idxA, st)
        end
    end
    @test collect(search_completion(b * a)) == collect(search_completion(a))

    # let X = collect(search_completion(b * a, max_age = 5))
    #     @test length(X) == 2
    #     for st in X
    #         @test Automata.isterminal(idxA, st)
    #         @test first(Automata.value(st)) == Automata.signature(idxA, st)
    #     end
    # end

    # let X = collect(search_completion(b * a, 5))
    #     @test length(X) == 2
    #     @test Automata.signature.(Ref(idxA), X) ⊆ [a^2, (a * b)^7]
    # end

    @inferred collect(search_completion(b * a))

    R = let n = 4
        Al = Alphabet([:a, :b, :B])
        KnuthBendix.setinverse!(Al, :b, :B)

        a, b, B = [Word{Int8}([i]) for i in 1:length(Al)]
        ε = one(a)

        eqns = [
            # b*B => ε,
            # B*b => ε,
            a^2 => ε,
            b^3 => ε,
            (a * b)^7 => ε,
            (a * b * a * B)^n => ε,
        ]

        knuthbendix(RewritingSystem(eqns, LenLex(Al), reduced = true))
    end

    idxA = Automata.IndexAutomaton(R)
    btsearch = Automata.BacktrackSearch(idxA)

    for rule in KnuthBendix.rules(R)
        lhs₁, _ = rule
        tests = map(btsearch(lhs₁[2:end])) do st
            t1 = Automata.isterminal(idxA, st)
            lhs₂, _ = Automata.value(st)
            lb = length(lhs₂) - length(btsearch.tape) + 1
            t2 = lb ≥ 1
            t3 = lb < length(lhs₂)
            t4 = lhs₁[end-lb+1:end] == lhs₂[1:lb]
            return t1 && t2 && t3 && t4
        end
        @test all(tests)
    end
end
