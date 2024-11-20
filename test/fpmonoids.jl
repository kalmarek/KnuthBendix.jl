using GroupsCore
import KnuthBendix.FPMonoids as Monoids

include(joinpath(pathof(GroupsCore), "..", "..", "test", "conformance_test.jl"))

@testset "FPMonoids" begin
    M = Monoids.FreeMonoid(4)
    test_GroupsCore_interface(M)
    @testset "Monoid of commuting projections (quantum stuff)" begin
        function example_monoid(n::Integer)
            A = KB.Alphabet(
                append!(
                    [Symbol('a', i) for i in 1:n],
                    [Symbol('b', i) for i in 1:n],
                ),
            )
            F = Monoids.FreeMonoid(A)
            rels = let S = gens(F)
                squares = [(g^2, one(g)) for g in S]
                @views a, b = S[1:n], S[n+1:end]
                aibj =
                    [(a[i] * b[j], b[j] * a[i]) for i in 1:n for j in 1:n]
                [squares; aibj]
            end

            return F / rels
        end

        N = 5
        M = example_monoid(N)
        test_GroupsCore_interface(M)

        a = gens(M)[1:N]
        b = gens(M)[N+1:2N]

        w = *(a...)
        i = 1
        @test b[i] * w == w * b[i]

        biw = b[i] * w
        @test Monoids.word(biw) == [N + i; 1:N]
        @test !Monoids.isnormal(biw)
        biw_dc = deepcopy(biw)

        @test parent(biw_dc) == parent(biw)
        @test Monoids.word(biw_dc) == Monoids.word(biw)
        @test Monoids.word(biw_dc) !== Monoids.word(biw)

        @test Monoids.normalform!(biw_dc) isa Monoids.FPMonoidElement
        @test Monoids.word(biw_dc) != Monoids.word(biw)
        @test Monoids.word(biw_dc) == [1:N; N + i]

        @test sprint(show, MIME"text/plain"(), biw) == "a1*a2*a3*a4*a5*b1"
        @test sprint(show, MIME"text/plain"(), M) ==
              "monoid defined by 35 relations over Alphabet{Symbol}: [:a1, :a2, :a3, :a4, :a5, :b1, :b2, :b3, :b4, :b5]"

        len = 10
        wa, wb = M(rand(1:N, len)), M(rand(N+1:2N, len))
        @test wa * wb == wb * wa

        @test !isfinite(M)

        elts = collect(Iterators.take(M, 10))
        @test first(elts) == one(M)
        a1 = gens(M, 1)
        a2 = gens(M, 2)
        @test last(elts) == a1 * a2 * a1 * a2 * a1 * a2 * a1 * a2 * a1
        @test_throws GroupsCore.InfiniteOrder length(M)

        @test (wa * wb)' == wb' * wa'
        w, v = rand(M, 2)
        @test (w * v)' == v' * w'

        elts, sizes = Monoids.elements(M, 4)
        @test isone(elts[sizes[0]])
        @test all(e -> length(Monoids.word(e)) == 1, elts[sizes[0]+1:sizes[1]])
        @test all(e -> length(Monoids.word(e)) == 2, elts[sizes[1]+1:sizes[2]])
        @test all(e -> length(Monoids.word(e)) == 3, elts[sizes[2]+1:sizes[3]])
        @test all(e -> length(Monoids.word(e)) == 4, elts[sizes[3]+1:sizes[4]])

        eltsᵀ = elts'
        @test isone(eltsᵀ[sizes[0]])
        B2 = elts[sizes[0]+1:sizes[2]]
        @test all(≤(sizes[2]), [findfirst(==(e'), elts) for e in B2])

    end

    @testset "237-triangle monoid" begin
        R237 = KB.ExampleRWS.triangle_237_quotient(6)
        M237 = Monoids.FPMonoid(R237)

        R237_c = KB.knuthbendix(R237)
        M237_c = Monoids.FPMonoid(R237_c)

        w = [3, 3, 3]
        @test !isone(M237(w)) # B·B·B
        @test isone(M237_c(w)) # B·B·B

        @test_throws GroupsCore.InfiniteOrder GroupsCore.order(Int, M237)
        @test GroupsCore.order(Int, M237_c) == 1092
        @test collect(M237_c) isa Vector{<:MonoidElement}
        @test collect(M237_c) isa Vector{<:Monoids.FPMonoidElement}

        test_GroupsCore_interface(M237_c)
    end
end
