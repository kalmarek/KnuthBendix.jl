@testset "Rewriting" begin

    import KnuthBendix.set_inversion!

    A = Alphabet{String}(["a", "e", "b", "p"])
    set_inversion!(A, "a", "e")
    set_inversion!(A, "b", "p")
    lenlexord = LenLex(A)

    a = Word([1,2])
    b = Word([2,1])
    c = Word([3,4])
    d = Word([4,3])
    ε = one(a)

    ba = Word([3,1])
    ab = Word([1,3])

    s = RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab], lenlexord)
    z = empty(s)

    @test s isa KnuthBendix.AbstractRewritingSystem
    @test s isa RewritingSystem

    @test s !==  z
    @test isempty(z)
    @test z._len[] == 0
    @test !isempty(s)

    push!(z, c=>ε)
    @test z._len[] == 1
    @test KnuthBendix.rules(z) == [c=>ε]
    @test KnuthBendix.ordering(z) == lenlexord

    pushfirst!(z, b=>ε)
    @test z._len[] == 2
    @test KnuthBendix.rules(z)[1] == (b=>ε)
    @test KnuthBendix.rules(z) == [b=>ε, c=>ε]

    append!(z, RewritingSystem([ba=>ab], lenlexord))
    @test z._len[] == 3
    @test KnuthBendix.rules(z) == [b=>ε, c=>ε, ba=>ab]
    prepend!(z, RewritingSystem([a=>ε], lenlexord))
    @test z._len[] == 4
    @test KnuthBendix.rules(z) == [a=>ε, b=>ε, c=>ε, ba=>ab]

    @test KnuthBendix.rules(z)[1] == (a=>ε)
    @test length(z) == 4
    @test length(KnuthBendix.active(z)) == length(z)

    KnuthBendix.setinactive!(z, 4)
    @test !KnuthBendix.isactive(z, 4)
    @test KnuthBendix.rules(z)[KnuthBendix.active(z)] == [a=>ε, b=>ε, c=>ε]
    @test KnuthBendix.active(z) == [true, true, true, false]

    w = deepcopy(z)
    deleteat!(KnuthBendix.rules(w), .!KnuthBendix.active(w))
    @test length(w) == 3
    @test w._len[] == 3

    KnuthBendix.setactive!(z, 4)
    @test KnuthBendix.isactive(z, 4)

    @test KnuthBendix.rules(z) == [a=>ε, b=>ε, c=>ε, ba=>ab]

    insert!(z, 4, d=>ε) == s
    @test z._len[] == 5
    @test KnuthBendix.rules(z) == KnuthBendix.rules(s)
    deleteat!(z, 5)
    @test z._len[] == 4
    @test KnuthBendix.rules(z) == [a=>ε, b=>ε, c=>ε, d=>ε]
    deleteat!(z, 3:4) == RewritingSystem([a=>ε, b=>ε], lenlexord)
    @test z._len[] == 2
    @test KnuthBendix.rules(z) == [a=>ε, b=>ε]

    @test KnuthBendix.rewrite_from_left(a, s) == ε
    @test KnuthBendix.rewrite_from_left(c, z) == c

    KnuthBendix.setinactive!(s, 1)
    @test KnuthBendix.rewrite_from_left(a, s) == a
    KnuthBendix.setactive!(s, 1)
    @test KnuthBendix.rewrite_from_left(a, s) == ε

    @test pop!(z) == (b=>ε)
    @test z._len[] == 1
    @test popfirst!(z) == (a=>ε)
    @test z._len[] == 0
    @test length(KnuthBendix.active(z)) == 0

    push!(z, c=>ε)
    @test KnuthBendix.rules(empty!(z)) == KnuthBendix.rules(empty(s))
    @test KnuthBendix.rewrite_from_left(c, z) == c

    @test sprint(show, z) isa String
end
