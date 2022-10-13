@testset "Words" begin
    @test Word(Int[]) isa Words.AbstractWord
    @test Word(Int[]) isa Word
    @test Word(Int[]) isa Word{UInt16}
    @test one(Word{UInt16}) isa Word{UInt16}
    @test one(Word{Int}) isa Word{Int}

    w = Word([1, 2])
    W = Word{Int}([1, 2])
    @test w isa Word{UInt16}
    @test W isa Word{Int}

    @test w == Word([1, 2])
    @test w == W
    @test w !== Word([1, 2])
    @test w != one(w)
    @test !isone(w)
    @test isone(one(w))
    @test hash(w) isa UInt
    @test hash(w) == hash(W)
    @test hash(w, UInt(1)) != hash(w, UInt(0))
    @test hash(w) != hash(one(w))
    @test_throws AssertionError Word([1, -2])

    @test push!(w, 3) == Word([1, 2, 3])
    @test w[3] == 3
    @test w == Word([1, 2, 3])
    @test_throws AssertionError push!(w, -3)

    @test pushfirst!(w, 4) == Word([4, 1, 2, 3])
    @test w[1] == 4
    @test w == Word([4, 1, 2, 3])
    @test_throws AssertionError pushfirst!(w, -4)

    @test w[2:3] isa Word{UInt16}
    @test w[2:3] == Word([1, 2])
    @test W[2:2] isa Word{Int}
    @test W[2:2][1] == W[2]

    @test append!(w, Word([6])) == Word([4, 1, 2, 3, 6])
    @test prepend!(w, Word([5])) == Word([5, 4, 1, 2, 3, 6])
    @test collect(w) == [5, 4, 1, 2, 3, 6]
    @test collect(w) isa Vector{UInt16}
    @test w[1] == 5
    @test length(w) == 6
    @test_throws BoundsError w[-1]
    @test_throws BoundsError w[7]

    @test similar(w) isa Word{UInt16}
    @test similar(W) isa Word{Int}

    @test Word([1, 2]) * Word([2, 3]) == Word([1, 2, 2, 3])
    @test Word([1, 2]) * W == Word([1, 2, 1, 2])

    u1 = Word([1, 2, 3, 4])
    u2 = Word([1, 2])
    u3 = Word([4, 1, 2, 3, 4])

    @test pop!(u2) == 2
    @test u2 == Word([1])
    @test popfirst!(u3) == 4
    @test u3 == u1

    @test sprint(show, Word([1, 2])) == "1·2"
    @test sprint(show, MIME"text/plain"(), Word([1, 2])) == "Word{UInt16}: 1·2"
    @test sprint(show, one(Word{UInt16})) == "(id)"
end

@testset "SubWords" begin
    w = Word([1, 2, 3])
    @test @view(w[1:2]) isa Words.SubWord
    vw = @view w[2:3]
    @test vw == w[2:3]
    @test vw[1] == w[2]
    vw[1] = 10
    @test vw[1] == w[2] == 10

    @test @view(vw[1:1]) isa Words.SubWord

    u = Word([5, 6, 7])
    v = @view deepcopy(u)[2:3]
    @test u * v == Word([5, 6, 7, 6, 7])
    @test append!(u, v) isa Word
    @test prepend!(u, v) isa Word

    @test isone(@view(u[1:0]))
end

abstract_word_conformance_test(Word)
