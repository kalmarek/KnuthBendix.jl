@testset "Alphabets" begin
    import KnuthBendix.getindexbysymbol, KnuthBendix.set_inversion!

    @test Alphabet() isa Alphabet{Char}
    @test_throws ErrorException Alphabet{Int}()
    @test_throws ErrorException Alphabet([1, 2, 3])
    @test Alphabet([1, 2, 3], safe = false) isa Alphabet
    @test Alphabet{Integer}(safe = false) isa Alphabet{Integer}

    A = Alphabet{Char}()
    @test length(A.letters) == 0 && length(A.inversions) == 0
    @test sprint(show, A) isa String

    B = Alphabet(['a', 'b', 'c'])
    @test sprint(show, B) isa String
    @test B isa Alphabet{Char}
    @test length(B.letters) == 3 && length(B.inversions) == 3
    @test findfirst(i -> i != 0, B.inversions) === nothing

    @test_throws ErrorException Alphabet(['a', 'b', 'a'])

    push!(A, 'a', 'b', 'c')
    @test length(A.letters) == 3 && length(A.inversions) == 3
    @test findfirst(i -> i != 0, A.inversions) === nothing
    @test_throws ErrorException push!(A, 'a')

    @test A[1] == 'a' && A[2] == 'b' && A[3] == 'c'
    @test A['a'] == 1 && A['b'] == 2 && A['c'] == 3
    @test getindexbysymbol(A, 'b') == 2

    @test B[1] == 'a' && B[2] == 'b' && B[3] == 'c'
    @test B['a'] == 1 && B['b'] == 2 && B['c'] == 3
    @test getindexbysymbol(B, 'c') == 3
    @test_throws DomainError getindexbysymbol(B, 'd')

    @test_throws ErrorException set_inversion!(A, 'd', 'e')
    @test_throws ErrorException set_inversion!(A, 'a', 'e')

    set_inversion!(A, 'a', 'b')
    @test A[-2] == 'a' && A[-1] == 'b'
    set_inversion!(A, 'b', 'c')
    @test A[-2] == 'c' && A[-3] == 'b'
    set_inversion!(A, 'a', 'c')
    @test A[-1] == 'c' && A[-3] == 'a'
    @test_throws DomainError A[-2]

    @test A[A[1]] == 1

    w = KnuthBendix.Word([1, 2])
    @test_throws DomainError inv(A, w) # b is not invertible
    w = KnuthBendix.Word([1, 1, 3])
    @test inv(A, w) == Word([1, 3, 3]) # inv(a*a*c)
    @test inv(A, inv(A, w)) == w
end
