@testset "Rewriting" begin

    import KnuthBendix.Word, KnuthBendix.RewritingSystem, KnuthBendix.Alphabet, KnuthBendix.set_inversion!

    A = Alphabet{String}(["a", "e", "b", "p"])
    set_inversion!(A, "a", "e")
    set_inversion!(A, "b", "p")

    a = Word([1,2])
    b = Word([2,1])
    c = Word([3,4])
    d = Word([4,3])
    ε = one(a)

    ba = Word([3,1])
    ab = Word([1,3])

    s = RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε, ba=>ab])
    z = zero(s)

    @test s isa KnuthBendix.AbstractRewritingSystem
    @test s isa RewritingSystem

    @test s !==  z
    @test iszero(z)
    @test !iszero(s)

    @test hash(s) isa UInt
    @test hash(s) !== hash(z)
    @test hash(s, UInt(1)) != hash(s, UInt(0))

    @test push!(z, c=>ε) == RewritingSystem([c=>ε])
    @test z[1] == (c=>ε)
    @test z == RewritingSystem([c=>ε])

    @test pushfirst!(z, b=>ε) == RewritingSystem([b=>ε, c=>ε])
    @test z[1] == (b=>ε)
    @test z == RewritingSystem([b=>ε, c=>ε])

    @test append!(z, RewritingSystem([ba=>ab])) == RewritingSystem([b=>ε, c=>ε, ba=>ab])
    @test prepend!(z, RewritingSystem([a=>ε])) == RewritingSystem([a=>ε, b=>ε, c=>ε, ba=>ab])

    @test collect(z) == [a=>ε, b=>ε, c=>ε, ba=>ab]
    @test collect(z) isa Vector{Pair{Word{UInt16},Word{UInt16}}}
    @test z[1] == (a=>ε)
    @test length(z) == 4
    @test_throws BoundsError s[-1]
    @test_throws BoundsError s[7]

    @test insert!(z, 4, d=>ε) == s
    @test hash(s) == hash(z)
    @test deleteat!(z, 5) == RewritingSystem([a=>ε, b=>ε, c=>ε, d=>ε])
    @test deleteat!(z, 3:4) == RewritingSystem([a=>ε, b=>ε])

    @test KnuthBendix.rewrite_from_left(a, s) == ε
    @test KnuthBendix.rewrite_from_left(c, z) == c

    @test empty!(z) == zero(s)
    @test KnuthBendix.rewrite_from_left(c, z) == c

end
