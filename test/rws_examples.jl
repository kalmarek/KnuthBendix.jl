function RWS_Example_5_1()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'a', 'A')
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a,A,b,B = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem([b*a=>a*b], LenLex(Al))

    return R
end

RWS_ZxZ() = RWS_Example_5_1()

function RWS_Example_5_2()
    Al = Alphabet(['a', 'b', 'B', 'A'])
    KnuthBendix.set_inversion!(Al, 'a', 'A')
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a,b,B,A = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem([b*a=>a*b], LenLex(Al))

    return R
end

RWS_ZxZ_nonterminating() = RWS_Example_5_2()

function RWS_Example_5_3()
    Al = Alphabet(['a', 'b'])

    a,b = Word.([i] for i in 1:2)
    ε = one(a)

    R = RewritingSystem([a^2=>ε, b^3=>ε, (a*b)^3=>ε], LenLex(Al))

    return R
end

function RWS_Example_5_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a,b,B = Word.([i] for i in 1:3)
    ε = one(a)

    R = RewritingSystem([a^2=>ε, b^3=>ε, (a*b)^3=>ε], LenLex(Al))

    return R
end

function RWS_Example_5_5()
    Al = Alphabet(['c', 'C', 'b', 'B', 'a', 'A'])
    KnuthBendix.set_inversion!(Al, 'c', 'C')
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    KnuthBendix.set_inversion!(Al, 'a', 'A')

    c, C, b, B, a, A = Word.([i] for i in 1:6)
    ε = one(a)

    eqns = [c*a =>a*c, c*b=>b*c, b*a=>a*b*c]

    R = RewritingSystem(eqns, WreathOrder(Al))
    return R
end

function RWS_Example_6_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)
    eqns = [a*a=>ε, b*B=>ε, b^3=>ε, (a*b)^7=>ε, (a*b*a*B)^4=>ε]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

function RWS_Example_6_5()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)
    eqns = KnuthBendix.Rule.(
        [a*a=>ε, b*B=>ε, b^2=>B, (B*a)^3*B=>(a*b)^3*a, (b*a*B*a)^2=>(a*b*a*B)^2]
    )

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

function RWS_Example_237_abaB(n)
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)

    # eqns = [a^2=>ε, b^3=>ε, (a*b)^7=>ε, (a*b*a*B)^n=>ε]
    eqns = [b*B=>ε, B*b=>ε, a^2=>ε, b^3=>ε, (a*b)^7=>ε, (a*b*a*B)^n=>ε]

    R = RewritingSystem(eqns, LenLex(Al), bare=true)
    return R
end

RWS_Example_6_6() = RWS_Example_237_abaB(8)

function RWS_Exercise_6_1(n)
    Al = Alphabet(['a', 'b'])

    a, b = Word.([i] for i in 1:2)
    ε = one(a)

    eqns = [a^2=>ε, b^3=>ε, (a*b)^n=>ε]

    R = RewritingSystem(eqns, LenLex(Al), bare=true)
    return R
end

function RWS_Closed_Orientable_Surface(n)
    ltrs = String[]
    for i in 1:n
        subscript = join('₀'+d for d in reverse(digits(i)))
        append!(ltrs, ["a" * subscript, "A" * subscript, "b" * subscript, "B" * subscript])
    end
    Al = Alphabet(reverse!(ltrs))
    for i in 1:n
        subscript = join('₀'+d for d in reverse(digits(i)))
        KnuthBendix.set_inversion!(Al, "a" * subscript, "A" * subscript)
        KnuthBendix.set_inversion!(Al, "b" * subscript, "B" * subscript)
    end

    ε = one(Word{UInt16})
    rules = Pair{typeof(ε), typeof(ε)}[]
    word = Int[]

    for i in reverse(1:n)
        x = 4 * i
        append!(word, [x, x-2, x-1, x-3])
    end
    push!(rules, Word(word) => ε)
    R = RewritingSystem(rules, RecursivePathOrder(Al))

    return R
end
