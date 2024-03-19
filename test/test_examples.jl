@testset "KBS1 examples" begin
    R = RWS_Example_5_1()
    rws = knuthbendix(
        KnuthBendix.KBPlain(),
        R,
        KnuthBendix.Settings(verbosity = 1),
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 8
    @test collect(KnuthBendix.rules(R))[1:5] ==
          collect(KnuthBendix.rules(rws))[1:5]

    R = RWS_Example_5_2()
    rws = knuthbendix(
        KnuthBendix.KBPlain(),
        R,
        KnuthBendix.Settings(max_rules = 100),
    )
    @test KnuthBendix.isreduced(rws)
    @test !isconfluent(rws)
    @test KnuthBendix.nrules(rws) > 50 # there could be less rules that 100 in the irreducible rws

    R = RWS_Example_5_3()
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
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
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 11

    R = RWS_Example_5_5()
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 18

    R = RWS_Example_5_5_rec()
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 18

    R = RWS_Example_6_4()
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 40

    R = RWS_Example_6_5()
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 40

    R = RWS_Closed_Orientable_Surface(3)
    rws = knuthbendix(KnuthBendix.KBPlain(), R)
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 16

    R = RWS_Coxeter_group_cube()
    rws = KnuthBendix.knuthbendix(
        KnuthBendix.KBPlain(),
        R,
        KnuthBendix.Settings(max_rules = 300),
    )
    @test isconfluent(rws)
    @test KnuthBendix.nrules(rws) == 205
    @test sprint(show, rws) isa String
end

function test_kbs2_methods(R, methods, len; kwargs...)
    rwses = [
        KnuthBendix.knuthbendix(
            method,
            R,
            KnuthBendix.Settings(; kwargs...),
        ) for method in methods
    ]
    lengths = KnuthBendix.nrules.(rwses)
    @test all(==(len), lengths)
    @test all(isconfluent, rwses)
end

@testset "KBS2 examples" begin
    let R = RWS_Example_5_1(), nrules = 8
        rws = KnuthBendix.knuthbendix(KnuthBendix.KBStack(), R)
        @test KnuthBendix.nrules(rws) == nrules
        @test Set(collect(KnuthBendix.rules(R))[1:5]) ==
              Set(collect(KnuthBendix.rules(rws))[1:5])
        @test isconfluent(rws)
        @test KnuthBendix.nrules(KnuthBendix.reduce!(rws)) == nrules
    end

    R = RWS_Example_5_2()
    rws = KnuthBendix.knuthbendix(
        KnuthBendix.KBStack(),
        R,
        KnuthBendix.Settings(max_rules = 50),
    )
    @test KnuthBendix.isreduced(rws)
    @test !isconfluent(rws)

    rws = KnuthBendix.knuthbendix(
        KnuthBendix.KBS2AlgRuleDel(),
        R,
        KnuthBendix.Settings(max_rules = 50),
    )
    @test KnuthBendix.isreduced(rws)
    @test !isconfluent(rws)

    rws = KnuthBendix.knuthbendix(
        KnuthBendix.KBIndex(),
        R,
        KnuthBendix.Settings(max_rules = 50),
    )
    @test KnuthBendix.isreduced(rws)
    @test !isconfluent(rws)

    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix(KnuthBendix.KBStack(), R)
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

    kbs2methods = (
        KnuthBendix.KBStack(),
        KnuthBendix.KBS2AlgRuleDel(),
        KnuthBendix.KBIndex(),
    )
    test_kbs2_methods(R, kbs2methods, 6, verbosity = 1)

    R = RWS_Example_5_4()
    test_kbs2_methods(R, kbs2methods, 11)

    R = RWS_Example_5_5()
    test_kbs2_methods(R, kbs2methods, 18)

    R = RWS_Example_6_4()
    test_kbs2_methods(R, kbs2methods, 40)

    rws = KnuthBendix.knuthbendix(KnuthBendix.KBStack(), R)
    rwsd = KnuthBendix.knuthbendix(KnuthBendix.KBS2AlgRuleDel(), R)
    rwsa = KnuthBendix.knuthbendix(KnuthBendix.KBIndex(), R)

    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsd))
    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsa))

    w = Word([3, 3, 2, 2, 3, 3, 3, 1, 1, 1, 3, 1, 2, 3, 2, 3, 2, 3, 3, 3])

    @test KnuthBendix.rewrite(w, rws) == Word([1, 3, 1, 2])
    @test KnuthBendix.rewrite(w, rwsd) == Word([1, 3, 1, 2])
    @test KnuthBendix.rewrite(w, rwsa) == Word([1, 3, 1, 2])

    R = RWS_Example_6_5()
    test_kbs2_methods(R, kbs2methods, 40)

    R = RWS_Closed_Orientable_Surface(3)
    test_kbs2_methods(R, kbs2methods, 16)

    R = RWS_Coxeter_group_cube()
    test_kbs2_methods(R, kbs2methods, 205, max_rules = 300)

    R = RWS_Alt4()
    test_kbs2_methods(R, kbs2methods, 12)

    R = RWS_Fib2_Monoid(5)
    test_kbs2_methods(R, kbs2methods, 24)

    R = RWS_Fib2_Monoid_Recursive(5)
    test_kbs2_methods(R, kbs2methods, 5)

    R = RWS_Heisenberg()
    test_kbs2_methods(R, kbs2methods, 18)
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
        # RWS_Example_237_abaB(8), # same as RWS_Example_6_6()
        RWS_Baumslag_Solitar(3, 2),
        RWS_Alt4(),
        RWS_Fib2_Monoid(5),
        RWS_Fib2_Monoid_Recursive(5),
        RWS_Heisenberg(),
    ]
        rws = KnuthBendix.knuthbendix2(R)
        R = KnuthBendix.knuthbendix(
            KnuthBendix.KBIndex(),
            R,
            KnuthBendix.Settings(max_rules = 2000, verbosity = 1),
        )
        @test KnuthBendix.nrules(R) == KnuthBendix.nrules(rws)
        @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(R))
    end
end
