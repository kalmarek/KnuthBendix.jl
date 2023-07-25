using KnuthBendix
using Profile
using PProf
include("kbmag_defaults.jl")
include("tools.jl")

const problems = ("237", "237_8", "e8", "f27", "f27_2gen", "freenilpc3", "funny3", "l32ext", "m11", "heinnilp")
const kb_data = joinpath(@__DIR__, "..", "kb_data")

let problem = joinpath(kb_data, "237_8")
    R = rwsfromfile(problem)

    kb() = knuthbendix(R, kbmag_settings; implementation=:index_automaton)
    Profile.clear()
    @time kb()
    # Profile.@profile kb()
    # Profile.Allocs.@profile kb()
    @profile kb()
    pprof()

    print("Profiling done")
end

let problem = joinpath(kb_data, "237_8")
    R = rwsfromfile(problem)
    @time knuthbendix(R; implementation=:parallel_1)
    # @time knuthbendix(R; implementation=:index_automaton)
    println("Why did this work?")
end