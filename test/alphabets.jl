@testset "Alphabets" begin
    import KnuthBendix.Alphabet

    @test Alphabet{String}() isa KnuthBendix.Alphabet
    @test_throws ErrorException Alphabet{Int}()
    @test Alphabet{Int}(safe = false) isa KnuthBendix.Alphabet

    A = Alphabet{String}()
    @test length(A.alphabet) == 0 && length(A.inversions) == 0

    B = Alphabet{String}(["a", "b", "c"])
    @test length(B.alphabet) == 3 && length(B.inversions) == 3
    @test findfirst(i -> i != 0, B.inversions) == nothing

    @test_throws ErrorException Alphabet{String}(["a", "b", "a"])

    push!(A, "a", "b", "c")
    @test length(A.alphabet) == 3 && length(A.inversions) == 3
    @test findfirst(i -> i != 0, A.inversions) == nothing
    @test_throws ErrorException push!(A, "a")

    @test A[1] == "a" && A[2] == "b" && A[3] == "c"
    @test A["a"] == 1 && A["b"] == 2 && A["c"] == 3
    @test KnuthBendix.getindexbysymbol(A, "b") == 2

    @test B[1] == "a" && B[2] == "b" && B[3] == "c"
    @test B["a"] == 1 && B["b"] == 2 && B["c"] == 3
    @test KnuthBendix.getindexbysymbol(B, "c") == 3

    @test_throws ErrorException KnuthBendix.set_inversion!(A, "d", "e")

    KnuthBendix.set_inversion!(A, "b", "c")
    @test A[-2] == "c" && A[-3] == "b"
    KnuthBendix.set_inversion!(A, "a", "c")
    @test A[-1] == "c" && A[-3] == "a"
    @test_throws DomainError A[-2]

    @test A[A[1]] == 1
end
