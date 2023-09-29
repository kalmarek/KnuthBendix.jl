@testset "KBS1 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(verbosity = 1),
        implementation = :naive_kbs1,
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 8
    @test collect(KnuthBendix.rules(R))[1:5] ==
          collect(KnuthBendix.rules(rws))[1:5]

    R = RWS_Example_5_2()
    rws = @test_logs (:warn,) KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 100),
        implementation = :naive_kbs1,
    )
    @test !isconfluent(rws)
    @test KnuthBendix.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws

    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs1)
    @test isconfluent(rws)

    @test KnuthBendix.nrules(rws) == 6
    a, b = Word.([i] for i in 1:2)
    ε = one(a)
    @test collect(KnuthBendix.rules(rws)) ==
          KnuthBendix.Rule.([
        a^2 => ε,
        b^3 => ε,
        (b * a)^2 => a * b^2,
        (a * b)^2 => b^2 * a,
        a * b^2 * a => b * a * b,
        b^2 * a * b^2 => a * b * a,
    ])

    R = RWS_Example_5_4()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs1)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 11

    R = RWS_Example_5_5()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs1)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 18

    R = RWS_Example_5_5_rec()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs1)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 18

    R = RWS_Example_6_4()
    rws = KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 100),
        implementation = :naive_kbs1,
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 40

    R = RWS_Example_6_5()
    rws = KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 100),
        implementation = :naive_kbs1,
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 40

    R = RWS_Closed_Orientable_Surface(3)
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs1)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 16

    R = RWS_Coxeter_group_cube()
    rws = KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 300),
        implementation = :naive_kbs1,
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 205
    @test sprint(show, rws) isa String
end

function test_kbs2_methods(R, methods, len; kwargs...)
    rwses = [
        KnuthBendix.knuthbendix(
            R,
            KnuthBendix.Settings(; kwargs...);
            implementation = m,
        ) for m in methods
    ]
    lengths = KnuthBendix.nrules.(rwses)
    @test all(==(len), lengths)
    @test all(isconfluent, rwses)
end

@testset "KBS2 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs2)
    @test KnuthBendix.nrules(rws) == 8
    @test Set(collect(KnuthBendix.rules(R))[1:5]) ==
          Set(collect(KnuthBendix.rules(rws))[1:5])
    @test isconfluent(rws)

    R = RWS_Example_5_2()
    @test_logs (:warn,) KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 50),
        implementation = :naive_kbs2,
    )
    @test_logs (:warn,) KnuthBendix.knuthbendix(
        R,
        KnuthBendix.Settings(max_rules = 50),
        implementation = :index_automaton,
    )

    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs2)
    a, b = Word.([i] for i in 1:2)
    ε = one(a)
    @test Set(KnuthBendix.rules(rws)) == Set(
        KnuthBendix.Rule.([
            a^2 => ε,
            b^3 => ε,
            (b * a)^2 => a * b^2,
            a * b^2 * a => b * a * b,
            b^2 * a * b^2 => a * b * a,
            (a * b)^2 => b^2 * a,
        ]),
    )

    test_kbs2_methods(
        R,
        (:naive_kbs2, :rule_deletion, :index_automaton),
        6,
        verbosity = 1,
    )

    R = RWS_Example_5_4()
    test_kbs2_methods(R, (:naive_kbs2, :rule_deletion, :index_automaton), 11)

    R = RWS_Example_5_5()
    test_kbs2_methods(R, (:naive_kbs2, :rule_deletion, :index_automaton), 18)

    R = RWS_Example_6_4()
    test_kbs2_methods(R, (:naive_kbs2, :rule_deletion, :index_automaton), 40)

    rws = KnuthBendix.knuthbendix(R, implementation = :naive_kbs2)
    rwsd = KnuthBendix.knuthbendix(R, implementation = :rule_deletion)
    rwsa = KnuthBendix.knuthbendix(R, implementation = :index_automaton)

    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsd))
    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsa))

    w = Word([3, 3, 2, 2, 3, 3, 3, 1, 1, 1, 3, 1, 2, 3, 2, 3, 2, 3, 3, 3])

    @test KnuthBendix.rewrite(w, rws) == Word([1, 3, 1, 2])
    @test KnuthBendix.rewrite(w, rwsd) == Word([1, 3, 1, 2])
    @test KnuthBendix.rewrite(w, rwsa) == Word([1, 3, 1, 2])

    R = RWS_Example_6_5()
    test_kbs2_methods(R, (:naive_kbs2, :rule_deletion, :index_automaton), 40)

    R = RWS_Closed_Orientable_Surface(3)
    test_kbs2_methods(R, (:naive_kbs2, :rule_deletion, :index_automaton), 16)

    R = RWS_Coxeter_group_cube()
    test_kbs2_methods(
        R,
        (:naive_kbs2, :rule_deletion, :index_automaton),
        205,
        max_rules = 300,
    )
end

@testset "KBS-automata" begin
    for R in [
        RWS_Example_5_1(),
        # RWS_Example_5_2(), # non-confluent ℤ²
        RWS_Example_5_3(),
        RWS_Example_5_4(),
        RWS_Example_5_5(),
        RWS_Example_5_5_rec(),
        RWS_Example_6_4(),
        RWS_Example_6_5(),
        RWS_Closed_Orientable_Surface(4),
    ]
        rws = KnuthBendix.knuthbendix2(R)
        R = KnuthBendix.knuthbendix(R, implementation = :index_automaton)
        @test KnuthBendix.nrules(R) == KnuthBendix.nrules(rws)
        @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(R))
    end
end
