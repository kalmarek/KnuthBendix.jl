@testset "KBS1" begin

    A = Alphabet(['a', 'e', 'b', 'p'])
    KnuthBendix.set_inversion!(A, 'a', 'e')
    KnuthBendix.set_inversion!(A, 'b', 'p')

    a = Word([1,2])
    b = Word([2,1])
    c = Word([3,4])
    d = Word([4,3])
    ε = one(a)

    ba = Word([3,1])
    ab = Word([1,3])

    be = Word([3,2])
    eb = Word([2,3])

    pa = Word([4,1])
    ap = Word([1,4])

    pe = Word([4,2])
    ep = Word([2,4])

    lenlexord = LenLex(A)
    rs = RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab], lenlexord)
    rsc = RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, be=>eb, pa=>ap, pe=>ep], lenlexord)
    @test KnuthBendix.getirreduciblesubsystem(rsc) == [a,b,c,d,ba,be,pa,pe]

    KnuthBendix.forceconfluence!(rs,5,1)
    @test KnuthBendix.rules(rs) == [a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, Word([1,3,2])=>Word([3])]

    KnuthBendix.deriverule!(rs, Word([4,1,3]), Word([1]))
    @test  KnuthBendix.rules(rs) == [a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, Word([1,3,2])=>Word([3]), Word([4,1,3])=>Word([1])]


    B = KnuthBendix.Alphabet(['a', 'b', 'p'])
    KnuthBendix.set_inversion!(B, 'a', 'a')
    KnuthBendix.set_inversion!(B, 'b', 'p')

    aa = Word([1,1])
    bp = Word([2,3])
    bbb = Word([2,2,2])
    ab3 = Word([1,2,1,2,1,2])
    ε = one(a)

    bb = Word([2,2])
    p = Word([3])

    babab = Word([2,1,2,1,2])
    a = Word([1])

    ababa = Word([1,2,1,2,1])
    p = Word([3])

    pp = Word([3,3])
    b = Word([2])

    pb = Word([3,2])
    # epsilon for the right side

    baba = Word([2,1,2,1])
    ap = Word([1,3])

    abab = Word([1,2,1,2])
    pa = Word([3,1])

    bab = Word([2,1,2])
    apa = Word([1,3,1])

    pap = Word([3,1,3])
    aba = Word([1,2,1])

    paba = Word([3,1,2,1])
    bap = Word([2,1,3])

    abap = Word([1,2,1,3])
    pab = Word([3,1,2])

    apab = Word([1,3,1,2])
    # bap for the right side

    bapa  = Word([2,1,3,1])
    # pab for the right side

    lenlexordB = LenLex(B)
    rsb = RewritingSystem([aa=>ε, bp=>ε, bbb=>ε, ab3=>ε, bb=>p, babab=>a, ababa=>p, pp=>b, pb=>ε, baba=>ap, abab=>pa, bab=>apa, pap=>aba, paba=>bap, abap=>pab, apab=>bap, bapa=>pab], lenlexordB)

    @test KnuthBendix.getirreduciblesubsystem(rsb) == [aa, bp, bb, pp, pb, bab, pap, paba, abap, apab, bapa]

end
