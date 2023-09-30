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
        # times with `stack_size = 250`
        "degen4b",    # too hard
        "degen4c",    # too hard
        # "237_8",    #   1.885474 seconds (106.73 k allocations: 11.966 MiB)
        # "e8",       #   2.146169 seconds (106.69 k allocations: 10.614 MiB)
        "f27",      #  10.704827 seconds (274.99 k allocations: 31.164 MiB)
        "f27_2gen", #  20.397737 seconds (204.91 k allocations: 43.457 MiB)
        "f27monoid",# too hard
        "funny3",   #  16.825623 seconds (230.61 k allocations: 41.266 MiB)
        "heinnilp",   #  77.018298 seconds (476.10 k allocations: 77.103 MiB)
        # "l32ext",   #   2.267469 seconds (115.22 k allocations: 13.604 MiB)
        "m11", # 37.746448 seconds (311.76 k allocations: 59.166 MiB, 0.06% gc time)
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
            max_rules = 25_000,
            verbosity = 0,
            stack_size = 250,
        )
        fn in failed_exs && continue
        @info fn
        rws = RewritingSystem(rwsgap)
        @time R = knuthbendix(rws, sett)
        @test isconfluent(R)
    end
end
