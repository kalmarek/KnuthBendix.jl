@testset "KBS1" begin

    import KnuthBendix.Word

    A = KnuthBendix.Alphabet(['a', 'e', 'b', 'p'])
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

    lenlexord = KnuthBendix.LenLex(A)
    rs = KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab], lenlexord)

    rsc = KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, be=>eb, pa=>ap, pe=>ep], lenlexord)

    @test KnuthBendix.knuthbendix1(rs) == rsc
    @test KnuthBendix.getirrsubsys(rsc) == [a,b,c,d,ba,be,pa,pe]

    KnuthBendix.overlap1!(rs,5,1)
    @test rs == KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, Word([1,3,2])=>Word([3])], lenlexord)

    KnuthBendix.test1!(rs, Word([4,1,3]), Word([1]))
    @test rs == KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, Word([1,3,2])=>Word([3]), Word([4,1,3])=>Word([1])], lenlexord)

end
