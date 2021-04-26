@testset "KBS1 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs1)
    @test length(rws) == 8
    @test KnuthBendix.rules(R)[1:5] == KnuthBendix.rules(rws)[1:5]

    R = RWS_Example_5_2()
    @test_logs (:warn,) rws = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:naive_kbs1)
    @test length(rws) > 50 # there could be less rules that 100 in the irreducible rws

    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs1)
    @test length(rws) == 6
    a,b = Word.([i] for i in 1:2)
    ε = one(a)
    @test KnuthBendix.rules(rws) == [a^2=>ε, b^3=>ε,
        (b*a)^2=>a*b^2, (a*b)^2=>b^2*a, a*b^2*a=>b*a*b, b^2*a*b^2=>a*b*a]


    R = RWS_Example_5_4()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs1)
    @test length(rws) == 11

    R = RWS_Example_5_5()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs1)
    @test length(rws) == 18

    R = RWS_Example_6_4()
    rws = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:naive_kbs1)
    @test_broken length(rws) == 81

    R = RWS_Example_6_5()
    rws = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:naive_kbs1)
    @test_broken length(rws) == 56

    R = RWS_Closed_Orientable_Surface(3)
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs1)
    @test length(rws) == 16
end

function test_kbs2_methods(R, methods, len)
    rwses = [KnuthBendix.knuthbendix(R, implementation=m) for m in methods]
    lengths = length.(rwses)
    @test all(==(len), lengths)
end

@testset "KBS2 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs2)
    @test length(rws) == 8
    @test Set(KnuthBendix.rules(R)[1:5]) == Set(KnuthBendix.rules(rws)[1:5])

    R = RWS_Example_5_2()
    @test_logs (:warn,) KnuthBendix.knuthbendix(R, maxrules=200, implementation=:naive_kbs2)

    R = RWS_Example_5_3()
    test_kbs2_methods(R, (:naive_kbs2, :automata, :deletion), 6)
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs2)

    a,b = Word.([i] for i in 1:2)
    ε = one(a)
    @test Set(KnuthBendix.rules(rws)) == Set([a^2=>ε, b^3=>ε,
        (b*a)^2=>a*b^2, a*b^2*a=>b*a*b, b^2*a*b^2=>a*b*a, (a*b)^2=>b^2*a])

    R = RWS_Example_5_4()
    test_kbs2_methods(R, (:naive_kbs2, :automata, :deletion), 11)

    R = RWS_Example_5_5()
    test_kbs2_methods(R, (:naive_kbs2, :automata, :deletion), 18)

    R = RWS_Example_6_4()
    test_kbs2_methods(R, (:naive_kbs2, :automata, :deletion), 40)

    rws  = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:naive_kbs2)
    rwsd = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:deletion)
    rwsa = KnuthBendix.knuthbendix(R, maxrules=100, implementation=:automata)
    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsd))
    @test Set(KnuthBendix.rules(rws)) == Set(KnuthBendix.rules(rwsa))

    w = Word([3, 3, 2, 2, 3, 3, 3, 1, 1, 1, 3, 1, 2, 3, 2, 3, 2, 3, 3, 3])

    @test KnuthBendix.rewrite_from_left(w, rws) == Word([1,3,1,2])

    R = RWS_Example_6_5()
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs2)
    @test length(rws) == 40

    R = RWS_Closed_Orientable_Surface(3)
    rws = KnuthBendix.knuthbendix(R, implementation=:naive_kbs2)
    @test length(rws) == 16
end
