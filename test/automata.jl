@testset "Automata" begin
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
    rsc = KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, be=>eb, pa=>ap, pe=>ep], lenlexord)
    ia = KnuthBendix.IndexAutomaton(rsc)

    testword = Word([1,1,1,1,1,2,2,2,3,4,2,2,3,3,3,4,4,4,4,3,4,3,4,1,2,1,1,1,1,1,1,1,2,1,3,4])
    @test KnuthBendix.rewrite_from_left(testword, rsc) == KnuthBendix.rewrite_from_left(testword, ia)

    w = Word([1,3,4,1,4,4,1,1,4,2,3,2,4,2,2,3,1,2,1])
    @test KnuthBendix.rewrite_from_left(w, rsc) == KnuthBendix.rewrite_from_left(w, ia)

    @test !isempty(ia)

    rsd = KnuthBendix.RewritingSystem([a=>ε, b=>ε], lenlexord)
    iad = KnuthBendix.IndexAutomaton(rsd)
    @test KnuthBendix.rewrite_from_left(testword, rsd) == KnuthBendix.rewrite_from_left(testword, iad)
end
