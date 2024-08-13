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
            rws = KnuthBendix.parse_kbmag(file_content)

            @test rws.generatorOrder ==
                  [Symbol("g.10"), Symbol("g.20"), Symbol("g.30")]
            @test rws.inverses == [1, 3, 2]
            @test rws.equations == [[2, 2] => [3], [3, 1, 3] => [1, 2, 1]]
        end

        let file_content = String(read(joinpath(kb_data, "3a6")))
            rws = KnuthBendix.parse_kbmag(file_content)
            @test rws.generatorOrder == [:a, :b, :A, :B]
            @test rws.inverses == [3, 4, 1, 2]
            @test rws.equations == [
                [1, 1, 1] => Int[],
                [2, 2, 2] => Int[],
                [1, 2, 1, 2, 1, 2, 1, 2] => Int[],
                [1, 4, 1, 4, 1, 4, 1, 4, 1, 4] => Int[],
            ]

            res = """rec(
                                isRWS := true,
                       generatorOrder := [a,b,A,B],
                             inverses := [A,B,a,b],
                             ordering := "shortlex",
                            equations := [
                         [a*a*a, IdWord],
                         [b*b*b, IdWord],
                         [a*b*a*b*a*b*a*b, IdWord],
                         [a*B*a*B*a*B*a*B*a*B, IdWord]
                       ]
                     )"""
            @test sprint(show, MIME"text/plain"(), rws) == res
        end
        let file_content = String(read(joinpath(kb_data, "cosets")))
            rws = KnuthBendix.parse_kbmag(file_content)
            @test rws.generatorOrder == [:H, :a, :A, :b, :B]
            @test rws.inverses == [0, 3, 2, 5, 4]
            @test rws.equations == [
                [2, 2, 2] => Int[],
                [4, 4, 4, 4] => Int[],
                [2, 4, 2, 4] => Int[],
                [1, 4] => [1],
                [1, 1] => [1],
                [2, 1] => [1],
                [4, 1] => [1],
            ]

            res = """rec(
                                isRWS := true,
                       generatorOrder := [H,a,A,b,B],
                             inverses := [ ,A,a,B,b],
                             ordering := "shortlex",
                            equations := [
                         [a*a*a, IdWord],
                         [b*b*b*b, IdWord],
                         [a*b*a*b, IdWord],
                         [H*b, H],
                         [H*H, H],
                         [a*H, H],
                         [b*H, H]
                       ]
                     )"""
            @test sprint(show, MIME"text/plain"(), rws) == res
        end
    end

    failed_examples = [
        "degen4c", # eventually finishes with some touches, but takes too much time
    ]

    options = Dict([
        "237_8" => (reduce_delay = 500,),
        "degen4b" => (max_length_lhs = 20,),
        "e8" => (confluence_delay = 100,),
        "f27" => (reduce_delay = 500,),
        "f27_2gen" => (reduce_delay = 500,),
        "f27monoid" =>
            (reduce_delay = 500, max_length_lhs = 30, max_length_rhs = 30),
        # kb_data file sets max_length to to [15, 15];
        # since a^30 → a is a rule kbmag fails on thi example
        "funny3" => (reduce_delay = 500,),
        "heinnilp" => (reduce_delay = 500,),
    ])

    @testset "kbmag easy examples: $fn" for fn in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, fn)))
            rws = KnuthBendix.parse_kbmag(file_content)
            @test rws isa KnuthBendix.KbmagRWS
            @test !isempty(rws.generatorOrder)
            @test length(rws.generatorOrder) == length(rws.inverses)
            @test all(!isempty(lhs) for (lhs, rhs) in rws.equations)
            rws
        end
        @test RewritingSystem(rwsgap) isa RewritingSystem

        sett_idx = KB.Settings(KB.KBIndex(), rwsgap; get(options, fn, (;))...)
        sett_pfx = KB.Settings(KB.KBPrefix(), rwsgap; get(options, fn, (;))...)
        sett_idx.max_rules = sett_pfx.max_rules = 1 << 15

        fn in failed_examples && continue
        @info fn # sett_pfx

        GC.gc()
        rws = RewritingSystem(rwsgap)
        @time Rpfx = knuthbendix(sett_pfx, rws)
        @test isconfluent(Rpfx)

        GC.gc()
        @time Ridx = knuthbendix(sett_idx, rws)
        @test isconfluent(Ridx)
        @test KB.nrules(Ridx) == KB.nrules(Rpfx)
    end
end

#=
[ Info: 237
  0.000361 seconds (1.21 k allocations: 79.055 KiB)
[ Info: 237_8
  1.194131 seconds (104.70 k allocations: 20.352 MiB)
[ Info: 3a6
  0.010471 seconds (9.26 k allocations: 775.977 KiB)
[ Info: a4
  0.000105 seconds (541 allocations: 34.258 KiB)
[ Info: a4monoid
  0.000052 seconds (330 allocations: 22.961 KiB)
[ Info: ab1
  0.000031 seconds (233 allocations: 15.086 KiB)
[ Info: ab2
  0.000064 seconds (445 allocations: 29.023 KiB)
[ Info: c2
  0.000028 seconds (217 allocations: 14.086 KiB)
[ Info: cosets
  0.000225 seconds (1.03 k allocations: 66.195 KiB)
[ Info: d22
  0.000581 seconds (2.15 k allocations: 157.500 KiB)
[ Info: degen1
  0.000025 seconds (196 allocations: 12.789 KiB)
[ Info: degen2
  0.000031 seconds (231 allocations: 14.398 KiB)
[ Info: degen3
  0.000068 seconds (319 allocations: 19.477 KiB)
[ Info: degen4a
  0.005365 seconds (4.65 k allocations: 392.031 KiB)
[ Info: e8
  0.472674 seconds (60.31 k allocations: 6.680 MiB, 1.12% gc time)
[ Info: f2
  0.000110 seconds (306 allocations: 19.945 KiB)
[ Info: f25
  0.001225 seconds (4.30 k allocations: 251.086 KiB)
[ Info: f25monoid
  0.000322 seconds (1.13 k allocations: 76.422 KiB)
[ Info: freenilpc3
  0.000904 seconds (2.69 k allocations: 220.523 KiB)
[ Info: l32ext
  1.436185 seconds (110.77 k allocations: 21.370 MiB)
[ Info: m11
  5.466974 seconds (199.91 k allocations: 43.134 MiB, 0.10% gc time)
[ Info: nilp2
  0.000224 seconds (856 allocations: 62.953 KiB)
[ Info: nonhopf
  0.000108 seconds (599 allocations: 41.500 KiB)
[ Info: s16
  0.015451 seconds (23.77 k allocations: 1.550 MiB)
[ Info: s3
  0.000058 seconds (274 allocations: 17.211 KiB)
[ Info: s4
  0.000101 seconds (595 allocations: 37.594 KiB)
[ Info: s9
  0.000888 seconds (2.65 k allocations: 176.445 KiB)
[ Info: torus
  0.000141 seconds (826 allocations: 61.352 KiB)
=#
