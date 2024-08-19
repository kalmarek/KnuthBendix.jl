@testset "PackedVector" begin
    pvec = KB.PackedVector{Char}()
    @test pvec isa AbstractVector
    @test length(pvec) == 0

    push!(pvec, 'a':'c')
    @test length(pvec) == 1
    @test pvec == [['a', 'b', 'c']]

    push!(pvec, 'd':'g')
    @test length(pvec) == 2
    @test pvec == [['a', 'b', 'c'], ['d', 'e', 'f', 'g']]

    KB.__unsafe_finalize!(pvec)
    @test length(pvec) == 3
    @test pvec == [['a', 'b', 'c'], ['d', 'e', 'f', 'g'], Char[]]

    KB.__unsafe_push!(pvec, 'a')
    KB.__unsafe_push!(pvec, 'a')
    @test length(pvec) == 3
    @test pvec == [['a', 'b', 'c'], ['d', 'e', 'f', 'g'], Char[]]

    KB.__unsafe_finalize!(pvec)
    @test length(pvec) == 4
    @test pvec == [['a', 'b', 'c'], ['d', 'e', 'f', 'g'], Char[], ['a', 'a']]

    @test_throws AssertionError resize!(pvec, 5)
    @test resize!(pvec, 2) == [['a', 'b', 'c'], ['d', 'e', 'f', 'g']]
    @test length(pvec) == 2
end
