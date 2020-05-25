@testset "Words" begin
    
    import KnuthBendix.Word

    @test Word(Int[]) isa KnuthBendix.AbstractWord
    @test Word(Int[]) isa Word
    @test Word(Int[]) isa Word{Int16}
    
    w = Word([1,-2])
    W = Word{Int}([1,-2])
    @test w isa Word{Int16}
    @test W isa Word{Int}
    
    @test w == Word([1,-2])
    @test w == W
    @test w !== Word([1,-2])
    @test w != one(w)
    @test !isone(w)
    @test isone(one(w))
    @test hash(w) isa UInt
    @test hash(w) == hash(W)
    @test hash(w, UInt(1)) != hash(w, UInt(0))
    @test hash(w) != hash(one(w))
    
    @test push!(w, 3) == Word([1,-2,3])
    @test w[3] == 3
    @test w == Word([1,-2,3])
    
    @test pushfirst!(w, -1) == Word([-1,1,-2,3])
    @test w[1] == -1
    @test w == Word([-1,1,-2,3])
    
    @test  append!(w, Word([6])) == Word(  [-1,1,-2,3,6])
    @test prepend!(w, Word([5])) == Word([5,-1,1,-2,3,6])
    @test collect(w) == [5, -1,1,-2,3,6]
    @test collect(w) isa Vector{Int16}
    @test w[1] == 5
    @test length(w) == 6
    @test_throws BoundsError w[-1]
    @test_throws BoundsError w[7]
    
    @test similar(w) isa Word{Int16}
    @test similar(W) isa Word{Int}
    
    @test Word([1,2])*Word([2,3]) == Word([1,2,2,3])
    @test Word([1,2])*W == Word([1,2,1,-2])
    
    @test inv(W) == Word([2,-1])
    @test inv(Word([1,-2,2])) == Word([-2, 2, -1])
    @test inv(inv(w)) == w
end
