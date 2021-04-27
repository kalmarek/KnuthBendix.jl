using MacroTools

@testset "kbmag parsing" begin
    w = MacroTools.postwalk(KnuthBendix.replace_powering, :((a*c*b^2)^3))
    @test w == :((a*c*(b*b))*(a*c*(b*b))*(a*c*(b*b)))
    @test KnuthBendix.mult_args!(Symbol[], w) == [:a, :c, :b, :b, :a, :c, :b, :b, :a, :c, :b, :b]

    kb_data = joinpath(@__DIR__, "..", "kb_data")

    let file_content = String(read(joinpath(kb_data, "a4")))
        # file_content = join(split(file_content), "")
        rws = KnuthBendix.parse_kbmag(file_content, method=:string)

        @test rws.generators == [Symbol("g.10"), Symbol("g.20"), Symbol("g.30")]
        @test rws.inverses == [1, 3, 2]
        @test rws.equations == [[2,2]=>[3], [3,1,3]=>[1,2,1]]
    end

    let file_content = String(read(joinpath(kb_data, "3a6")))
        # file_content = join(split(file_content), "")
        rws = KnuthBendix.parse_kbmag(file_content, method=:ast)
        @test rws.generators == [:a, :b, :A, :B]
        @test rws.inverses == [3, 4, 1, 2]
        @test rws.equations == [
            [1,1,1]=>Int[],
            [2,2,2]=>Int[],
            [1,2,1,2,1,2,1,2]=>Int[],
            [1,4,1,4,1,4,1,4,1,4]=>Int[]
        ]
    end

    for f in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, f)))
            # file_content = join(split(file_content), "")
            method = (f=="a4" ? :string : :ast)
            rws = KnuthBendix.parse_kbmag(file_content, method=method)
            @test rws isa KnuthBendix.RwsGAP
            @test !isempty(rws.generators)
            @test length(rws.generators) == length(rws.inverses)
            @test all(!isempty(lhs) for (lhs, rhs) in rws.equations)
            rws
        end
        @test RewritingSystem(rwsgap) isa RewritingSystem

    end
end
