module KnuthBendix

using ProgressMeter

export Word, Alphabet, RewritingSystem, LenLex, knuthbendix

include("abstract_words.jl")
include("searchindex.jl")
include("words.jl")
include("bufferwords.jl")
include("alphabets.jl")
include("orderings.jl")
include("rules.jl")

include("rewriting.jl")
include("automata.jl")
include("helper_structures.jl")
include("derive_rule.jl")
include("force_confluence.jl")
include("kbs.jl")
include("kbc_automaton.jl")

include("parsing.jl")
end
