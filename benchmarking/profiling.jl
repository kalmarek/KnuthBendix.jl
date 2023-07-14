using KnuthBendix
include("kbmag_defaults.jl")

problems = ("237", "237_8", "e8", "f27", "f27_2gen", "freenilpc3", "funny3", "l32ext", "m11", "heinnilp")

let kb_data = joinpath(@__DIR__, "..", "kb_data")
    problem = "f27_2gen"
    R = let file_content = String(read(joinpath(kb_data, problem)))
        rws = KnuthBendix.parse_kbmag(file_content, method = :ast)
        RewritingSystem(rws)
    end

    # sett = KnuthBendix.Settings(
    #     max_rules = 2000,
    #     verbosity = 1,
    #     stack_size = 50,
    # )
    kb() = knuthbendix(R, kbmag_settings; implementation=:index_automaton)
    @time kb()
    @profview kb()
end
