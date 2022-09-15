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
include("rewriting_system.jl")
include("Automata/Automata.jl")
using .Automata
include("rewriting.jl")

include("helper_structures.jl")

include("knuthbendix.jl")
include("knuthbendix1.jl")
include("knuthbendix2.jl")
include("knuthbendix_delete.jl")
include("knuthbendix_idxA.jl")

include("parsing.jl")
end
