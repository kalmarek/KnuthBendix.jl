@testset "Automata" begin

    using KnuthBendix

    abt = KnuthBendix.Alphabet(['a', 'b', 'c', 'd'])
    a = KnuthBendix.Automaton(abt)
    emptystate = KnuthBendix.states(a)[1]

    @test length(KnuthBendix.states(a)) == 1
    @test length(KnuthBendix.inedges(emptystate)) == 4
    @test length(KnuthBendix.outedges(emptystate)) == 4

end