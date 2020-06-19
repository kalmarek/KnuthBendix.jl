@testset "Rewriting" begin

    import KnuthBendix.Word, KnuthBendix.RewritingSystem, KnuthBendix.Alphabet, KnuthBendix.set_inversion!

    A = Alphabet{String}(["a", "e", "b", "p"])
    set_inversion!(A, "a", "e")
    set_inversion!(A, "b", "p")
    lenlexord = KnuthBendix.LenLex(A)

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
    @test !isempty(s)

    @test hash(s) isa UInt
    @test hash(s) !== hash(z)
    @test hash(s, UInt(1)) != hash(s, UInt(0))

    @test push!(z, c=>ε) == RewritingSystem([c=>ε], lenlexord)
    @test KnuthBendix.rules(z)[1] == (c=>ε)
    @test KnuthBendix.ordering(z) == lenlexord
    @test z == RewritingSystem([c=>ε], lenlexord)

    @test pushfirst!(z, b=>ε) == RewritingSystem([b=>ε, c=>ε], lenlexord)
    @test KnuthBendix.rules(z)[1] == (b=>ε)
    @test z == RewritingSystem([b=>ε, c=>ε], lenlexord)

    @test append!(z, RewritingSystem([ba=>ab], lenlexord)) == RewritingSystem([b=>ε, c=>ε, ba=>ab], lenlexord)
    @test prepend!(z, RewritingSystem([a=>ε], lenlexord)) == RewritingSystem([a=>ε, b=>ε, c=>ε, ba=>ab], lenlexord)

    @test KnuthBendix.rules(z)[1] == (a=>ε)
    @test length(z) == 4
    @test length(KnuthBendix.active(z)) == length(z)

    KnuthBendix.setinactive!(z, 4)
    @test !KnuthBendix.isactive(z, 4)
    @test collect(KnuthBendix.arules(z)) == [a=>ε, b=>ε, c=>ε]
    @test KnuthBendix.active(z) == [true, true, true, false]
    KnuthBendix.setactive!(z, 4)
    @test KnuthBendix.isactive(z, 4)

    @test KnuthBendix.rules(z) == [a=>ε, b=>ε, c=>ε, ba=>ab]

    @test insert!(z, 4, d=>ε) == s
    @test hash(s) == hash(z)
    @test deleteat!(z, 5) == RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε], lenlexord)
    @test deleteat!(z, 3:4) == RewritingSystem([a=>ε, b=>ε], lenlexord)

    @test KnuthBendix.rewrite_from_left(a, s) == ε
    @test KnuthBendix.rewrite_from_left(c, z) == c

    KnuthBendix.setinactive!(s, 1)
    @test KnuthBendix.rewrite_from_left(a, s) == a
    KnuthBendix.setactive!(s, 1)
    @test KnuthBendix.rewrite_from_left(a, s) == ε

    @test pop!(z) == (b=>ε)
    @test popfirst!(z) == (a=>ε)
    @test length(KnuthBendix.active(z)) == 0

    push!(z, c=>ε)
    @test empty!(z) == empty(s)
    @test KnuthBendix.rewrite_from_left(c, z) == c

end
