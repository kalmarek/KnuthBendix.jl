@testset "Automata" begin

    using KnuthBendix

    abt = KnuthBendix.Alphabet(['a', 'e', 'b', 'p'])
    ta = KnuthBendix.Automaton(abt)
    σ = KnuthBendix.initialstate(ta)
    @test sprint(show, ta) isa String

    @test ta isa KnuthBendix.AbstractAutomaton
    @test ta isa KnuthBendix.Automaton
    @test ta isa KnuthBendix.Automaton{4, Word{UInt16}}
    @test σ isa KnuthBendix.AbstractState
    @test σ isa KnuthBendix.State
    @test σ isa KnuthBendix.State{4, Word{UInt16}}

    @test isone(KnuthBendix.name(σ))
    @test !KnuthBendix.isterminal(σ)
    @test isone(KnuthBendix.rightrule(σ))

    @test length(KnuthBendix.states(ta)) == 1
    @test length(KnuthBendix.inedges(σ)) == 0
    @test length(KnuthBendix.outedges(σ)) == 4
    @test length(KnuthBendix.stateslengths(ta)) == 1
    @test length(σ) == 0

    KnuthBendix.declarerightrule!(σ, one(KnuthBendix.name(σ)))
    @test KnuthBendix.isterminal(σ)
    @test isone(KnuthBendix.rightrule(σ))

    push!(ta, Word([1]))
    KnuthBendix.addedge!(ta, 1, 1, 2)
    @test length(KnuthBendix.inedges(KnuthBendix.states(ta)[2])) == 1
    @test KnuthBendix.walk(ta, Word([1])) == (1, KnuthBendix.states(ta)[2])
    @test_throws BoundsError KnuthBendix.addedge!(ta, 5, 1, 2)
    @test_throws BoundsError KnuthBendix.addedge!(ta, 1, 3, 2)
    @test_throws BoundsError KnuthBendix.addedge!(ta, 1, 1, 3)
    @test_throws BoundsError KnuthBendix.removeedge!(ta, 5, 1, 2)
    @test_throws BoundsError KnuthBendix.removeedge!(ta, 1, 3, 2)
    @test_throws BoundsError KnuthBendix.removeedge!(ta, 1, 1, 3)
    KnuthBendix.removeedge!(ta, 1, 1, 2)
    @test KnuthBendix.walk(ta, Word([1])) == (0, KnuthBendix.states(ta)[1])

    KnuthBendix.addedge!(ta, 1, 1, 2)
    deleteat!(ta, 2)
    @test length(KnuthBendix.states(ta)) == 1
    @test length(KnuthBendix.stateslengths(ta)) == 1
    @test KnuthBendix.isnoedge(KnuthBendix.outedges(σ)[1])

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
    ia = KnuthBendix.makeindexautomaton(rsc, A)

    testword = Word([1,1,1,1,1,2,2,2,3,4,2,2,3,3,3,4,4,4,4,3,4,3,4,1,2,1,1,1,1,1,1,1,2,1,3,4])
    @test KnuthBendix.rewrite_from_left(testword, rsc) == KnuthBendix.rewrite_from_left(testword, ia)

    w = Word([1,3,4,1,4,4,1,1,4,2,3,2,4,2,2,3,1,2,1])
    @test KnuthBendix.rewrite_from_left(w, rsc) == KnuthBendix.rewrite_from_left(w, ia)

    @test !isempty(ia)
    @test isempty(empty!(ia))

    rsd = KnuthBendix.RewritingSystem([a=>ε, b=>ε], lenlexord)
    iad = KnuthBendix.makeindexautomaton(rsd, A)
    @test KnuthBendix.rewrite_from_left(testword, rsd) == KnuthBendix.rewrite_from_left(testword, iad)
end
