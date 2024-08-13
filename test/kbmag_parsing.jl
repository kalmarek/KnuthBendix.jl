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
  0.000370 seconds (772 allocations: 52.234 KiB)
  0.000355 seconds (1.14 k allocations: 79.398 KiB)
[ Info: 237_8
  1.320919 seconds (137.15 k allocations: 14.049 MiB)
  0.561978 seconds (101.87 k allocations: 13.687 MiB)
[ Info: 3a6
  0.021710 seconds (13.92 k allocations: 1.066 MiB)
  0.011513 seconds (9.77 k allocations: 831.055 KiB)
[ Info: a4
  0.000119 seconds (339 allocations: 21.344 KiB)
  0.000156 seconds (526 allocations: 33.773 KiB)
[ Info: a4monoid
  0.000085 seconds (228 allocations: 15.906 KiB)
  0.000107 seconds (357 allocations: 24.305 KiB)
[ Info: ab1
  0.000061 seconds (156 allocations: 9.219 KiB)
  0.000105 seconds (241 allocations: 13.977 KiB)
[ Info: ab2
  0.000088 seconds (272 allocations: 16.703 KiB)
  0.000134 seconds (459 allocations: 29.242 KiB)
[ Info: c2
  0.000060 seconds (150 allocations: 8.828 KiB)
  0.000098 seconds (224 allocations: 12.914 KiB)
[ Info: cosets
  0.000286 seconds (693 allocations: 41.938 KiB)
  0.000297 seconds (1.02 k allocations: 66.711 KiB)
[ Info: d22
  0.000733 seconds (1.71 k allocations: 120.766 KiB)
  0.000538 seconds (1.98 k allocations: 149.523 KiB)
[ Info: degen1
  0.000053 seconds (129 allocations: 7.531 KiB)
  0.000084 seconds (203 allocations: 11.617 KiB)
[ Info: degen2
  0.000064 seconds (168 allocations: 9.406 KiB)
  0.000087 seconds (237 allocations: 13.164 KiB)
[ Info: degen3
  0.000175 seconds (260 allocations: 15.250 KiB)
  0.000089 seconds (325 allocations: 18.258 KiB)
[ Info: degen4a
  0.001472 seconds (2.11 k allocations: 157.422 KiB)
  0.007583 seconds (10.78 k allocations: 993.023 KiB)
[ Info: degen4b
  0.129463 seconds (209.92 k allocations: 19.600 MiB)
  0.116493 seconds (65.19 k allocations: 6.899 MiB)
[ Info: e8
  0.611625 seconds (102.82 k allocations: 8.418 MiB)
  0.378842 seconds (82.47 k allocations: 9.191 MiB)
[ Info: f2
  0.000071 seconds (208 allocations: 11.719 KiB)
  0.000093 seconds (315 allocations: 17.977 KiB)
[ Info: f25
  0.000930 seconds (3.51 k allocations: 186.078 KiB)
  0.000914 seconds (4.37 k allocations: 258.547 KiB)
[ Info: f25monoid
  0.000509 seconds (893 allocations: 60.266 KiB)
  0.000366 seconds (1.10 k allocations: 78.531 KiB)
[ Info: f27
  6.184674 seconds (218.80 k allocations: 39.324 MiB)
  2.011773 seconds (253.06 k allocations: 43.119 MiB)
[ Info: f27_2gen
  0.281742 seconds (114.44 k allocations: 11.813 MiB)
  0.699237 seconds (219.68 k allocations: 28.142 MiB)
[ Info: f27monoid
  1.349455 seconds (99.36 k allocations: 17.297 MiB)
  6.981328 seconds (506.05 k allocations: 146.956 MiB)
[ Info: freenilpc3
  0.001303 seconds (1.74 k allocations: 136.859 KiB)
  0.001280 seconds (4.04 k allocations: 327.188 KiB)
[ Info: funny3
  0.306605 seconds (113.58 k allocations: 11.202 MiB)
  1.206064 seconds (333.28 k allocations: 42.003 MiB)
[ Info: heinnilp
  0.056099 seconds (42.99 k allocations: 6.087 MiB)
  0.421140 seconds (287.29 k allocations: 41.641 MiB)
[ Info: l32ext
  1.362215 seconds (141.29 k allocations: 14.509 MiB)
  0.743610 seconds (103.44 k allocations: 15.463 MiB)
[ Info: m11
  0.895431 seconds (305.18 k allocations: 27.377 MiB)
  2.059599 seconds (284.35 k allocations: 45.621 MiB)
[ Info: nilp2
  0.000261 seconds (479 allocations: 32.125 KiB)
  0.000279 seconds (894 allocations: 64.289 KiB)
[ Info: nonhopf
  0.000207 seconds (350 allocations: 26.328 KiB)
  0.000283 seconds (925 allocations: 71.180 KiB)
[ Info: s16
  0.014580 seconds (13.19 k allocations: 1.091 MiB)
  0.008340 seconds (8.66 k allocations: 739.570 KiB)
[ Info: s3
  0.000062 seconds (189 allocations: 10.953 KiB)
  0.000083 seconds (283 allocations: 16.164 KiB)
[ Info: s4
  0.000188 seconds (369 allocations: 24.578 KiB)
  0.000169 seconds (586 allocations: 37.422 KiB)
[ Info: s9
  0.000970 seconds (1.58 k allocations: 115.844 KiB)
  0.000789 seconds (2.05 k allocations: 153.461 KiB)
[ Info: torus
  0.000174 seconds (496 allocations: 35.391 KiB)
  0.000202 seconds (830 allocations: 62.398 KiB)
[ Info: verifynilp
  0.059045 seconds (29.42 k allocations: 34.397 MiB)
  0.034591 seconds (43.35 k allocations: 5.250 MiB)
=#
