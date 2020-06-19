@testset "Orderings" begin

    import KnuthBendix.Alphabet, KnuthBendix.set_inversion!, KnuthBendix.Word
    import KnuthBendix.LenLex, Base.Order.lt

    A = Alphabet(['a', 'b', 'c', 'd'])
    set_inversion!(A, 'a', 'b')
    set_inversion!(A, 'c', 'd')

    lenlexord = LenLex(A)

    @test lenlexord isa Base.Order.Ordering

    u1 = Word([1,2])
    u3 = Word([1,3])
    u4 = Word([1,2,3])
    u5 = Word([1,4,2])

    @test lt(lenlexord, u1, u3) == true
    @test lt(lenlexord, u3, u1) == false
    @test lt(lenlexord, u3, u4) == true
    @test lt(lenlexord, u4, u5) == true
    @test lt(lenlexord, u5, u4) == false
    @test lt(lenlexord, u1, u1) == false
end
