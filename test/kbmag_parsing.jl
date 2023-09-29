using MacroTools

@testset "kbmag" begin
    kb_data = joinpath(@__DIR__, "..", "benchmarking", "kb_data")

    @testset "parsing" begin
        w = MacroTools.postwalk(
            KnuthBendix.replace_powering,
            :((a * c * b^2)^3),
        )
        @test w == :((a * c * (b * b)) * (a * c * (b * b)) * (a * c * (b * b)))
        @test KnuthBendix.mult_args!(Symbol[], w) ==
              [:a, :c, :b, :b, :a, :c, :b, :b, :a, :c, :b, :b]

        let file_content = String(read(joinpath(kb_data, "a4")))
            # file_content = join(split(file_content), "")
            rws = KnuthBendix.parse_kbmag(file_content, method = :string)

            @test rws.generators ==
                  [Symbol("g.10"), Symbol("g.20"), Symbol("g.30")]
            @test rws.inverses == [1, 3, 2]
            @test rws.equations == [[2, 2] => [3], [3, 1, 3] => [1, 2, 1]]
        end

        let file_content = String(read(joinpath(kb_data, "3a6")))
            # file_content = join(split(file_content), "")
            rws = KnuthBendix.parse_kbmag(file_content, method = :ast)
            @test rws.generators == [:a, :b, :A, :B]
            @test rws.inverses == [3, 4, 1, 2]
            @test rws.equations == [
                [1, 1, 1] => Int[],
                [2, 2, 2] => Int[],
                [1, 2, 1, 2, 1, 2, 1, 2] => Int[],
                [1, 4, 1, 4, 1, 4, 1, 4, 1, 4] => Int[],
            ]
        end
    end

    failed_exs = [
        "degen4b", # too hard
        "degen4c", # too hard
        "237_8", # 1.693982 seconds (82.44 k allocations: 15.254 MiB)
        "e8", # 0.920605 seconds (51.88 k allocations: 6.614 MiB)
        "f27", # 12.826971 seconds (127.65 k allocations: 44.202 MiB)
        "f27_2gen", # 10.344746 seconds (140.49 k allocations: 47.661 MiB, 0.19% gc time)
        "f27monoid", # too hard
        "funny3", # 11.144962 seconds (185.75 k allocations: 53.332 MiB)
        "heinnilp", # 3.556067 seconds (137.59 k allocations: 18.026 MiB)
        "l32ext", # 1.979228 seconds (90.09 k allocations: 16.843 MiB)
        "m11", # 20.782630 seconds (230.82 k allocations: 61.726 MiB, 0.09% gc time)
        "verifynilp", # too hard
    ]

    @testset "kbmag example: $fn" for fn in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, fn)))
            method = (fn == "a4" ? :string : :ast)
            rws = KnuthBendix.parse_kbmag(file_content, method = method)
            @test rws isa KnuthBendix.KbmagRWS
            @test !isempty(rws.generators)
            @test length(rws.generators) == length(rws.inverses)
            @test all(!isempty(lhs) for (lhs, rhs) in rws.equations)
            rws
        end
        @test RewritingSystem(rwsgap) isa RewritingSystem

        sett = KnuthBendix.Settings(
            max_rules = 2000,
            verbosity = 0,
            stack_size = 50,
        )
        fn in failed_exs && continue
        @info fn
        rws = RewritingSystem(rwsgap)
        @time R = knuthbendix(rws, sett)
        @test isconfluent(R)
    end
end
