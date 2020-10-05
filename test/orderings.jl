@testset "Orderings" begin

    import KnuthBendix.set_inversion!
    import Base.Order.lt

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

    wo = WreathOrder(A)
    @test wo isa KnuthBendix.WordOrdering

    w1 = Word([3,1,4,2,3])
    w5 = Word([1,2,3,2,4,1,2,4])
    w4 = Word([1,3,1,2,4,2,1])
    w6 = Word([1,2,3,2,1,4,2,4])
    w2 = Word([1,3,4,3,2])
    w3 = Word([1,3,2,1,4,1,2])

    a = [w1, w5, w4, w6, w2, w3]

    @test sort(a, order = wo) == [w1, w2, w3, w4, w5, w6]

end
