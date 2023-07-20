using KnuthBendix
using BenchmarkTools
include("tools.jl")

const hard_examples = [
    "237",
    "237_8",
    "e8",
    "f27",
    "f27_2gen",
    "freenilpc3",
    "funny3",
    "l32ext",
    "m11",
    "heinnilp",
]

let problem = joinpath(@__DIR__, "..", "kb_data", "237_8")
    R = rwsfromfile(problem)
    # @time R₁ = knuthbendix(R; implementation = :index_automaton)
    @time R₂ = knuthbendix(R; implementation = :parallel_1)
    # @assert R₁ == R₂
    print("done")
end