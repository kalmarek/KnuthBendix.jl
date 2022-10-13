using MacroTools

@testset "kbmag" begin
    kb_data = joinpath(@__DIR__, "..", "kb_data")

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
        "e8", # 3.229832 seconds (106.80 k allocations: 14.409 MiB)
        "f27", # 46.193392 seconds (217.63 k allocations: 44.759 MiB)
        "f27_2gen", # 21.226852 seconds (183.67 k allocations: 24.295 MiB)
        "f27monoid", # ordering := "recursive",
        "freenilpc3", # ordering := "recursive",
        "funny3", # 10.782928 seconds (176.58 k allocations: 22.722 MiB, 1.02% gc time)
        "heinnilp", # ordering := "recursive",
        "m11", # 27.482646 seconds (256.87 k allocations: 31.985 MiB, 0.04% gc time)
        "nilp2", # ordering := "recursive",
        "nonhopf", # ordering := "recursive",
        "verifynilp", # ordering := "recursive",
    ]

    @testset "kbmag example: $fn" for fn in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, fn)))
            method = (fn == "a4" ? :string : :ast)
            rws = KnuthBendix.parse_kbmag(file_content, method = method)
            @test rws isa KnuthBendix.RwsGAP
            @test !isempty(rws.generators)
            @test length(rws.generators) == length(rws.inverses)
            @test all(!isempty(lhs) for (lhs, rhs) in rws.equations)
            rws
        end
        @test RewritingSystem(rwsgap) isa RewritingSystem

        sett = KnuthBendix.Settings(
            max_rules = 2000,
            verbosity = 1,
            stack_size = 50,
        )
        @info fn
        fn in failed_exs && continue
        rws = RewritingSystem(rwsgap)
        @time R = knuthbendix(rws, sett)
        @test isconfluent(R)
    end
end
