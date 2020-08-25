@testset "Automata" begin

    using KnuthBendix

    abt = KnuthBendix.Alphabet(['a', 'e', 'b', 'p'])
    triviala = KnuthBendix.Automaton(abt)
    inits = KnuthBendix.initialstate(triviala)

    @test triviala isa KnuthBendix.AbstractAutomaton
    @test triviala isa KnuthBendix.Automaton
    @test triviala isa KnuthBendix.Automaton{UInt16}
    @test inits isa KnuthBendix.AbstractState
    @test inits isa KnuthBendix.State
    @test inits isa KnuthBendix.State{UInt16}

    @test KnuthBendix.name(inits) == Word(Int[])
    @test !KnuthBendix.isterminal(inits)
    @test KnuthBendix.rightrule(inits) == nothing
    @test length(KnuthBendix.states(triviala)) == 1
    @test length(KnuthBendix.inedges(inits)) == 4
    @test length(KnuthBendix.outedges(inits)) == 4
    @test length(inits) == 0

    KnuthBendix.declarerightrule!(inits, Word())
    @test KnuthBendix.isterminal(inits)
    @test KnuthBendix.rightrule(inits) == Word()

    push!(triviala, KnuthBendix.Word([1]))
    KnuthBendix.addedge!(triviala, 1, 1, 2)
    @test KnuthBendix.walk(triviala, KnuthBendix.Word([1])) == KnuthBendix.states(triviala)[2]
    @test_throws AssertionError KnuthBendix.addedge!(triviala, 5, 1, 2)
    @test_throws AssertionError KnuthBendix.addedge!(triviala, 1, 3, 2)
    @test_throws AssertionError KnuthBendix.addedge!(triviala, 1, 1, 3)
    @test_throws AssertionError KnuthBendix.removeedge!(triviala, 5, 1, 2)
    @test_throws AssertionError KnuthBendix.removeedge!(triviala, 1, 3, 2)
    @test_throws AssertionError KnuthBendix.removeedge!(triviala, 1, 1, 3)
    KnuthBendix.removeedge!(triviala, 1, 1, 2)
    @test_throws ErrorException KnuthBendix.walk(triviala, KnuthBendix.Word([1]))

    KnuthBendix.addedge!(triviala, 1, 1, 2)
    deleteat!(triviala, 2)
    @test length(KnuthBendix.states(triviala)) == 1
    @test KnuthBendix.outedges(inits)[1] == nothing

    A = KnuthBendix.Alphabet(['a', 'e', 'b', 'p'])
    KnuthBendix.set_inversion!(A, 'a', 'e')
    KnuthBendix.set_inversion!(A, 'b', 'p')

    a = KnuthBendix.Word([1,2])
    b = KnuthBendix.Word([2,1])
    c = KnuthBendix.Word([3,4])
    d = KnuthBendix.Word([4,3])
    ε = KnuthBendix.Word()
    ba = KnuthBendix.Word([3,1])
    ab = KnuthBendix.Word([1,3])
    be = KnuthBendix.Word([3,2])
    eb = KnuthBendix.Word([2,3])
    pa = KnuthBendix.Word([4,1])
    ap = KnuthBendix.Word([1,4])
    pe = KnuthBendix.Word([4,2])
    ep = KnuthBendix.Word([2,4])

    lenlexord = KnuthBendix.LenLex(A)
    rsc = KnuthBendix.RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab, be=>eb, pa=>ap, pe=>ep], lenlexord)
    ia = KnuthBendix.makeindexautomaton(rsc, A)

    testword = KnuthBendix.Word([1,1,1,1,1,2,2,2,3,4,2,2,3,3,3,4,4,4,4,3,4,3,4,1,2,1,1,1,1,1,1,1,2,1,3,4])
    @test KnuthBendix.rewrite_from_left(testword, rsc) == KnuthBendix.index_rewrite(testword, ia)
end