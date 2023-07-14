using KnuthBendix

problems = ("237", "237_8", "e8", "f27", "f27_2gen", "freenilpc3", "funny3", "l32ext", "m11", "heinnilp")

let kb_data = joinpath(@__DIR__, "..", "..", "kb_data")
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
    @time knuthbendix(R, implementation=:index_automaton)
    @profview knuthbendix(R, implementation=:index_automaton)
end
