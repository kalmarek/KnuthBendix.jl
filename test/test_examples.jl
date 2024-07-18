import KnuthBendix.ExampleRWS
@testset "Knuth-Bendix completion examples" begin

    ordered_rwrules(rws) =
        sort!(collect(KB.rules(rws)), by = first, order = rws.order)

    @testset "Example ℤ×ℤ" begin
        R = ExampleRWS.ZxZ()

        rws = knuthbendix(KB.Settings(KB.KBPlain(); verbosity = 1), R)
        @test isconfluent(rws)
        @test KB.isreduced(rws)
        @test KB.nrules(rws) == 8
        @test collect(KB.rules(R))[1:5] == collect(KB.rules(rws))[1:5]

        rws = KB.knuthbendix(KB.Settings(KB.KBStack()), R)
        @test isconfluent(rws)
        @test KB.isreduced(rws)
        @test KB.nrules(rws) == 8
        @test Set(collect(KB.rules(R))[1:5]) == Set(collect(KB.rules(rws))[1:5])
    end

    @testset "Example non-terminating ℤ×ℤ" begin
        R = ExampleRWS.ZxZ_nonterminating()

        rws = knuthbendix(
            KB.Settings(KB.KBPlain(), max_rules = 100, verbosity = 1),
            R,
        )
        @test KB.isreduced(rws)
        @test !isconfluent(rws)
        @test KB.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws

        rws = KB.knuthbendix(
            KB.Settings(KB.KBStack(), max_rules = 100, verbosity = 1),
            R,
        )
        @test KB.isreduced(rws)
        @test !isconfluent(rws)
        @test KB.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws

        rws = KB.knuthbendix(
            KB.Settings(KB.KBS2AlgRuleDel(), max_rules = 100, verbosity = 1),
            R,
        )
        @test KB.isreduced(rws)
        @test !isconfluent(rws)
        @test KB.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws

        rws = KB.knuthbendix(
            KB.Settings(KB.KBIndex(), max_rules = 100, verbosity = 1),
            R,
        )
        @test KB.isreduced(rws)
        @test !isconfluent(rws)
        @test KB.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws
    end

    @testset "Example (2,3,3)-triangle group" begin
        R = ExampleRWS.triangle233()
        confluent_rules = let (a, b) = Word.([i] for i in 1:2)
            ε = one(a)
            sort!(
                KB.Rule.([
                    a^2 => ε,
                    b^3 => ε,
                    (b * a)^2 => a * b^2,
                    (a * b)^2 => b^2 * a,
                    a * b^2 * a => b * a * b,
                    b^2 * a * b^2 => a * b * a,
                ]),
                by = first,
                order = ordering(R),
            )
        end

        rws = knuthbendix(KB.Settings(KB.KBPlain()), R)
        @test KB.isreduced(rws)
        @test isconfluent(rws)
        @test ordered_rwrules(rws) == confluent_rules

        rws = knuthbendix(KB.Settings(KB.KBStack()), R)
        @test KB.isreduced(rws)
        @test isconfluent(rws)
        @test ordered_rwrules(rws) == confluent_rules

        rws = knuthbendix(KB.Settings(KB.KBS2AlgRuleDel()), R)
        @test KB.isreduced(rws)
        @test isconfluent(rws)
        @test ordered_rwrules(rws) == confluent_rules

        rws = knuthbendix(KB.Settings(KB.KBIndex()), R)
        @test KB.isreduced(rws)
        @test isconfluent(rws)
        @test ordered_rwrules(rws) == confluent_rules
    end

    @testset "Example Hurwitz4 ⟨ a,b | 1=a²=b³=(a·b)⁷=[a,b]⁴ ⟩" begin
        R = ExampleRWS.Hurwitz4()
        rws_pl = knuthbendix(KB.Settings(KB.KBPlain(), verbosity = 0), R)
        rws_st = knuthbendix(KB.Settings(KB.KBStack()), R)
        rws_dl = knuthbendix(KB.Settings(KB.KBS2AlgRuleDel()), R)
        rws_at = knuthbendix(KB.Settings(KB.KBIndex()), R)

        rwrules = ordered_rwrules(rws_pl)
        @test ordered_rwrules(rws_st) == rwrules
        @test ordered_rwrules(rws_dl) == rwrules
        @test ordered_rwrules(rws_at) == rwrules

        w = Word([3, 3, 2, 2, 3, 3, 3, 1, 1, 1, 3, 1, 2, 3, 2, 3, 2, 3, 3, 3])
        rw = Word([1, 3, 1, 2])

        @test KB.rewrite(w, rws_pl) == rw
        @test KB.rewrite(w, rws_st) == rw
        @test KB.rewrite(w, rws_dl) == rw
        @test KB.rewrite(w, rws_at) == rw
    end

    @testset "Easy examples" begin
        completion_problems = [
            (ExampleRWS.ZxZ(), 8),
            # ExampleRWS.ZxZ_nonterminating, # non-terminating ℤ²
            (ExampleRWS.triangle233(), 6),
            (ExampleRWS.Heisenberg(), 18),
            (ExampleRWS.Sims_Example_5_5(), 18),
            (ExampleRWS.Sims_Example_5_5_recursive(), 18),
            (ExampleRWS.Hurwitz4(), 40), # Δ(2,3,7)/[a,b]⁴ imbalanced presentation
            (ExampleRWS.triangle232(), 6),
            (ExampleRWS.triangle233(), 6),
            (ExampleRWS.triangle234(), 5),
            (ExampleRWS.triangle235(), 7),
            (ExampleRWS.π₁Surface_recursive(2), 12),
            (ExampleRWS.π₁Surface_recursive(3), 16),
            (ExampleRWS.π₁Surface_recursive(4), 20),
            (ExampleRWS.π₁Surface(2), 16),
            (ExampleRWS.π₁Surface(3), 24),
            (ExampleRWS.π₁Surface(4), 32),
            (ExampleRWS.Coxeter_cube(), 205),
            (ExampleRWS.Baumslag_Solitar(3, 5), 8),
            (ExampleRWS.Fibonacci2(5), 24),
            (ExampleRWS.Fibonacci2_recursive(5), 5),
        ]

        methods =
            (KB.KBPlain(), KB.KBStack(), KB.KBS2AlgRuleDel(), KB.KBIndex())
        @testset "$method" for method in methods
            settings = if method == KB.KBPlain()
                KB.Settings(method; verbosity = 0, max_rules = 300)
            else
                KB.Settings(method)
            end
            for (R, len) in completion_problems
                rws = knuthbendix(settings, R)
                @test KB.isreduced(rws)
                @test KB.isconfluent(rws)
                if method == KB.KBPlain() && R == last(completion_problems)[1]
                    @test_broken KB.nrules(rws) == len
                else
                    @test KB.nrules(rws) == len
                end
            end
        end
    end

    @testset "Harder examples" begin
        completion_problems = [
            (ExampleRWS.Hurwitz8(), 1026), # Δ(2,3,7)/[a,b]⁸ group presentation
        ]
        methods = (KB.KBIndex(),)
        @testset "$method" for method in methods
            for (R, len) in completion_problems
                rws = knuthbendix(KB.Settings(method), R)
                @test KB.isreduced(rws)
                @test KB.isconfluent(rws)
                @test KB.nrules(rws) == len
            end
        end
    end
end
