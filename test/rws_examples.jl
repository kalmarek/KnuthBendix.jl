function RWS_Example_5_1()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'a', 'A')
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    
    ε = Word()
    a,A,b,B = Word.([i] for i in 1:4)

    R = RewritingSystem([a*A=>ε, A*a=>ε, b*B=>ε, B*b=>ε, b*a=>a*b], LenLex(Al))

    return R
end

RWS_ZxZ() = RWS_Example_5_1()

function RWS_Example_5_2()
    Al = Alphabet(['a', 'b', 'B', 'A'])
    KnuthBendix.set_inversion!(Al, 'a', 'A')
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    
    ε = Word()
    a,b,B,A = Word.([i] for i in 1:4)

    R = RewritingSystem([a*A=>ε, A*a=>ε, b*B=>ε, B*b=>ε, b*a=>a*b], LenLex(Al))

    return R
end

RWS_ZxZ_nonterminating() = RWS_Example_5_2()

function RWS_Example_5_3()
    Al = Alphabet(['a', 'b'])
    
    ε = Word()
    a,b = Word.([i] for i in 1:2)

    R = RewritingSystem([a^2=>ε, b^3=>ε, (a*b)^3=>ε], LenLex(Al))

    return R
end

function RWS_Example_5_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    
    ε = Word()
    a,b,B = Word.([i] for i in 1:3)
    
    R = RewritingSystem([a^2=>ε, b*B=>ε, b^3=>ε, (a*b)^3=>ε], LenLex(Al))

    return R
end

function RWS_Example_5_5()
    Al = Alphabet(['c', 'C', 'b', 'B', 'a', 'A'])
    KnuthBendix.set_inversion!(Al, 'c', 'C')
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    KnuthBendix.set_inversion!(Al, 'a', 'A')

    ε = Word()
    c, C, b, B, a, A = Word.([i] for i in 1:6)

    eqns = [a*A=>ε, A*a=>ε, b*B=>ε, B*b=>ε, c*C=>ε, C*c=>ε,
        c*a =>a*c, c*b=>b*c, b*a=>a*b*c]
    
    throw("WreathOrder not implemented yet")

    R = RewritingSystem(eqns, WreathOrder(Al))
    return R
end

function RWS_Example_237_abaB(n)
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    ε = Word()
    a, b, B = Word.([i] for i in 1:3)

    eqns = [a^2=>ε, b*B=>ε, b^3=>ε, (a*b)^7=>ε, (a*b*a*B)^n=>ε]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

RWS_Example_6_4() = RWS_Example_237_abaB(4) 
RWS_Example_6_5() = RWS_Example_237_abaB(8)


@testset "KBS1 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix1(R)
    @test length(rws) == 8
    @test KnuthBendix.rules(R)[1:5] == KnuthBendix.rules(rws)[1:5]


    R = RWS_Example_5_2()
    @test_logs (:warn,) rws = KnuthBendix.knuthbendix1(R, maxrules=100)
    @test length(rws) > 50 # there could be less rules that 100 in the irreducible rws


    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix1(R)
    @test length(rws) == 6
    a,b = Word.([i] for i in 1:2)
    ε = Word()
    @test KnuthBendix.rules(rws) == [a^2=>ε, b^3=>ε, 
        (b*a)^2=>a*b^2, (a*b)^2=>b^2*a, a*b^2*a=>b*a*b, b^2*a*b^2=>a*b*a]
    

    R = RWS_Example_5_4()
    rws = KnuthBendix.knuthbendix1(R)
    @test length(rws) == 11


    # R = RWS_Example_5_5() 
    # rws = KnuthBendix.knuthbendix1(R)
    # @test length(rws) == 18

    R = RWS_Example_6_4()
    @test_logs (:warn, ) rws = KnuthBendix.knuthbendix1(R, maxrules=100)
end

@testset "KBS2 examples" begin
    R = RWS_Example_5_1()
    rws = KnuthBendix.knuthbendix2(R)
    @test length(rws) == 8
    @test Set(KnuthBendix.rules(R)[1:5]) == Set(KnuthBendix.rules(rws)[1:5])

    R = RWS_Example_5_2()
    @test_logs (:warn,) rws = KnuthBendix.knuthbendix2(R, maxrules=100)
    @test length(rws) > 50 # there could be less rules that 100 in the irreducible rws


    R = RWS_Example_5_3()
    rws = KnuthBendix.knuthbendix2(R)
    @test length(rws) == 6
    a,b = Word.([i] for i in 1:2)
    ε = Word()
    @test Set(KnuthBendix.rules(rws)) == Set([a^2=>ε, b^3=>ε,
        (b*a)^2=>a*b^2, a*b^2*a=>b*a*b, b^2*a*b^2=>a*b*a, (a*b)^2=>b^2*a])

    R = RWS_Example_5_4()
    rws = KnuthBendix.knuthbendix2(R)
    @test length(rws) == 11


    # R = RWS_Example_5_5() 
    # rws = KnuthBendix.knuthbendix1(R)
    # @test length(rws) == 18

    R = RWS_Example_6_4()
    rws = KnuthBendix.knuthbendix2(R, maxrules=100)
    @test length(rws) == 40
end




    w = Word([3, 3, 2, 2, 3, 3, 3, 1, 1, 1, 3, 1, 2, 3, 2, 3, 2, 3, 3, 3])

    @test KnuthBendix.rewrite_from_left(w, rws) == Word([1,3,1,2])
end
