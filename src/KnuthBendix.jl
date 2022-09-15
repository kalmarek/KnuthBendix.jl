module KnuthBendix

using ProgressMeter

export Alphabet, Word, RewritingSystem
export LenLex, WreathOrder, RecursivePathOrder, WeightedLex
export alphabet, ordering, knuthbendix

include("Words/Words.jl")
using .Words

include("alphabets.jl")
include("orderings.jl")
include("rules.jl")

include("rewriting.jl")
include("automata.jl")
include("index_automaton.jl")
include("rebuilding_idxA.jl")
include("helper_structures.jl")

include("knuthbendix1.jl")

include("derive_rule.jl")
include("force_confluence.jl")
include("kbs.jl")
include("kbc_automaton.jl")

include("parsing.jl")
end
