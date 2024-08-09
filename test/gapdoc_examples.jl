@testset "GAPDoc Examples" begin
    @testset "Example 1: Alt(4)" begin
        rws = KB.ExampleRWS.Alt4()
        R = knuthbendix(rws)
        @test KnuthBendix.nrules(R) == 12
        ia = Automata.IndexAutomaton(R)
        oracle = Automata.LoopSearchOracle()
        bs = Automata.BacktrackSearch(ia, oracle)
        @test isnothing(iterate(bs(one(KnuthBendix.word_type(R)))))

        @test oracle.n_visited == 12
        @test oracle.max_depth == 3

        bs2 =
            Automata.BacktrackSearch(ia, Automata.IrreducibleWordsOracle(0, 12))
        irr_w = collect(bs2)
        @test length(irr_w) == oracle.n_visited
        @test maximum(length, irr_w) == oracle.max_depth

        cert = Automata.infiniteness_certificate(ia)
        @test isone(cert.prefix)
        @test isone(cert.suffix)
        @test isfinite(ia)
        @test Automata.num_irreducible_words(ia) == 12
    end

    @testset "Example 2: Fib(2,5)" begin
        rws = KB.ExampleRWS.Fibonacci2(5)
        R = knuthbendix(rws)
        @test KnuthBendix.nrules(R) == 24
        ia = Automata.IndexAutomaton(R)
        @test Automata.num_irreducible_words(ia) == 12

        rws2 = KB.ExampleRWS.Fibonacci2_recursive(5)
        R2 = knuthbendix(rws2)
        @test KnuthBendix.nrules(R2) == 5
        ia2 = Automata.IndexAutomaton(R2)
        @test Automata.num_irreducible_words(ia2) == 12

        irr_w = Automata.irreducible_words(ia2)
        a = last(collect(Iterators.take(irr_w, 2)))
        @test collect(irr_w) == [a^i for i in 0:11]
    end

    @testset "Example 3: Heisenberg group" begin
        rws = KB.ExampleRWS.Heisenberg()
        R = knuthbendix(rws)
        @test KnuthBendix.nrules(R) == 18

        ia = Automata.IndexAutomaton(R)
        @test !isfinite(ia)
        @test_throws "The language of the automaton is infinite" Automata.num_irreducible_words(
            ia,
        )

        res = Automata.infiniteness_certificate(ia)
        @test isone(res.prefix)
        @test !isone(res.suffix)

        for k in 1:20
            w_k = res.prefix * res.suffix^k
            @test KnuthBendix.rewrite(w_k, ia) == w_k
        end

        x, X, y, Y, z, Z = [Word([i]) for i in 1:length(alphabet(rws))]

        zyx = z * y * x
        @test KnuthBendix.rewrite(zyx, R) == x * y * z^2
        @test KnuthBendix.rewrite(x * y * z^2, R) == x * y * z^2
    end

    @testset "Example 4: Nilpotency" begin
        alph = let letters = Symbol[]
            for l in 'h':-1:'a'
                push!(letters, Symbol(l))
                push!(letters, Symbol(uppercase(l)))
            end
            Alphabet(
                letters,
                [isodd(i) ? i + 1 : i - 1 for i in 1:length(letters)],
            )
        end

        h, g, f, e, d, c, b, a = [Word([i]) for i in 1:2:length(alph)]
        rels = let A = alph
            Comm(a, b) = inv(a, A) * inv(b, A) * a * b
            [
                (Comm(b, a), c),
                (Comm(c, a), d),
                (Comm(d, a), e),
                (Comm(e, b), f),
                (Comm(f, a), g),
                (Comm(g, b), h),
                (Comm(g, a), one(g)),
                (Comm(c, b), one(c)),
                (Comm(e, a), one(e)),
            ]
        end

        sett = KnuthBendix.Settings(
            KB.KBIndex();
            # confluence_delay = 10,
            max_length_lhs = 10,
            max_length_rhs = 10,
            verbosity = 0,
        )

        rws = KnuthBendix.RewritingSystem(rels, KnuthBendix.Recursive(alph))

        @time R = knuthbendix(sett, rws)

        @test KB.isreduced(R)
        @test KB.isconfluent(R)
        @test KB.nrules(R) == 101

        sett = KnuthBendix.Settings(
            KB.KBPrefix();
            max_length_lhs = 10,
            max_length_rhs = 10,
            verbosity = 0,
        )

        rws = KnuthBendix.RewritingSystem(rels, KnuthBendix.Recursive(alph))

        @time R = knuthbendix(sett, rws)

        @test KB.isreduced(R)
        @test KB.isconfluent(R)
        @test KB.nrules(R) == 101

    end
end
