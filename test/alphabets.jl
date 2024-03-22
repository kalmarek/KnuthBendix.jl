@testset "Alphabets" begin
    @testset "basic tests" begin
        letters = [:a, :b, :A]
        A = Alphabet(letters)
        @test collect(A) == letters
        @test eltype(A) == eltype(letters)

        @test !any(KB.hasinverse(l, A) for l in letters)
        @test !any(KB.hasinverse(i, A) for i in 1:length(letters))

        @test A[letters[1]] == 1
        @test A[1] == letters[1]

        @test_throws DomainError inv(1, A)
        KB.setinverse!(A, 1, 3)
        @test inv(1, A) == 3
        @test inv(A[1], A) == A[3]
        @test KB.hasinverse(3, A)

        KB.setinverse!(A, A[1], A[2])

        @test inv(1, A) == 2
        @test inv(A[1], A) == A[2]
        @test !KB.hasinverse(3, A)

        @test :b in A && 2 in A
        @test !(:d in A) && !(4 in A)
    end

    @test Alphabet([:a, :b]) isa Alphabet{Symbol}
    @test_throws AssertionError Alphabet([1, 2, 3])
    @test_throws AssertionError Alphabet(['a', 'b', 'a'])

    let B = Alphabet(['a', 'b', 'c'])
        @test B isa Alphabet{Char}
        @test sprint(show, B) isa String
        @test sprint(show, MIME"text/plain"(), B) isa String
        @test length(B.letters) == 3 && length(B.inversions) == 3
        @test findfirst(i -> i != 0, B.inversions) === nothing

        @test B[1] == 'a' && B[2] == 'b' && B[3] == 'c'
        @test B['a'] == 1 && B['b'] == 2 && B['c'] == 3
        @test_throws DomainError B['d']
    end

    let A = Alphabet(['a', 'b', 'c'])
        @test sprint(show, A) isa String
        @test sprint(show, MIME"text/plain"(), A) isa String

        @test length(A.letters) == 3 && length(A.inversions) == 3
        @test findfirst(i -> i != 0, A.inversions) === nothing

        @test A[1] == 'a' && A[2] == 'b' && A[3] == 'c'
        @test A['a'] == 1 && A['b'] == 2 && A['c'] == 3

        @test_throws DomainError KB.setinverse!(A, 'd', 'e')
        @test_throws DomainError KB.setinverse!(A, 'a', 'e')

        @test_throws DomainError A[-2]

        KB.setinverse!(A, 'a', 'b')
        @test A[-2] == 'a' && A[-1] == 'b'
        KB.setinverse!(A, 'b', 'c')
        @test A[-2] == 'c' && A[-3] == 'b'
        KB.setinverse!(A, 'a', 'c')
        @test A[-1] == 'c' && A[-3] == 'a'

        @test sprint(show, A) isa String
        @test sprint(show, MIME"text/plain"(), A) isa String

        @test A[A[1]] == 1

        A = Alphabet(["a₁", "a₁^-1"], [2, 1])
        w = Word([1, 2, 2])
        @test sprint(KB.print_repr, w, A) == "a₁*a₁^-2"
        @test sprint(KB.print_repr, one(w), A) == "(id)"
    end

    @testset "Inverting using Alphabet" begin
        A = Alphabet(['a', 'b', 'A'])
        KB.setinverse!(A, 'a', 'A')

        w = Word([1, 2])
        @test_throws DomainError inv(w, A) # b is not invertible
        w = Word([1, 1, 3])
        @test inv(w, A) == Word([1, 3, 3]) # inv(a*a*c)
        @test inv(inv(w, A), A) == w

        @test sprint(KB.print_repr, w, A) == "a^2*A"
        @test sprint(KB.print_repr, inv(w, A), A) == "a*A^2"

        B = Alphabet(["a", "a^-1", "c"], [2, 1, 0])
        w = Word([1])
        @test sprint(KB.print_repr, w, B) == "a"
        w = Word([1, 1])
        @test sprint(KB.print_repr, w, B) == "a^2"
        w = Word([2])
        @test sprint(KB.print_repr, w, B) == "a^-1"
        w = Word([2, 2])
        @test sprint(KB.print_repr, w, B) == "a^-2"

        w = Word([3, 1])
        @test sprint(KB.print_repr, w, B) == "c*a"
        w = Word([3, 1, 1])
        @test sprint(KB.print_repr, w, B) == "c*a^2"
        w = Word([3, 2])
        @test sprint(KB.print_repr, w, B) == "c*a^-1"
        w = Word([3, 2, 2])
        @test sprint(KB.print_repr, w, B) == "c*a^-2"
    end
end
