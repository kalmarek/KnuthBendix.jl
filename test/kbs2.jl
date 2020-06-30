@testset "KBS2" begin

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

    @test KnuthBendix.rules(KnuthBendix.knuthbendix2(rs)) == KnuthBendix.rules(rsc)
end
