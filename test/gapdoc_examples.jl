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
            max_rules = 400,
            stack_size = 100,
            confluence_delay = 40,
        )

        rws = KnuthBendix.RewritingSystem(rels, KnuthBendix.Recursive(alph))
        @time let R = rws
            KnuthBendix.reduce!(R)
            i = 10
            while !isempty(KnuthBendix.check_confluence(R))
                @time R = knuthbendix(KB.KBIndex(), R, sett)
                # this is hacking, todo: implement using Settings.max_length_lhs
                after_knuthbendix = KnuthBendix.nrules(R)
                filter!(r -> length(r.lhs) < i && length(r.rhs) < i, R.rwrules)
                after_filter_lt10 = KnuthBendix.nrules(R)
                append!(R.rwrules, R.rules_orig)
                R.reduced = false
                R.confluent = false
                KnuthBendix.reduce!(R)
                append_orig_reduc = KnuthBendix.nrules(R)
                @info "number of rules" after_knuthbendix after_filter_lt10 append_orig_reduc
            end
        end

        #=
        R = knuthbendix(
            rws,
            KnuthBendix.Settings(
                max_rules = 1000,
                stack_size = 100,
                confluence_delay = 40,
                verbosity = 2,
            ),
        )
        =#
    end
end
