module KnuthBendix

using ProgressMeter

export Alphabet, Word, RewritingSystem
export LenLex, WreathOrder, Recursive, WeightedLex
export alphabet, isconfluent, ordering, knuthbendix

include("Words/Words.jl")
using .Words
include("buffer_pair.jl")
include("settings_workspace.jl")

include("alphabets.jl")
include("Orderings/Orderings.jl")
include("rules.jl")
include("rewriting_system.jl")
include("Automata/Automata.jl")
using .Automata
include("rewriting.jl")

function Workspace(at::Automata.Automaton{S}, settings::Settings) where {S}
    return Workspace(word_type(at), S[], settings)
end

include("knuthbendix_base.jl")
include("knuthbendix1.jl")
include("knuthbendix2.jl")
include("knuthbendix_delete.jl")
include("knuthbendix_idxA.jl")

include("confluence_check.jl")

include("utils/packed_vector.jl")
include("parsing.jl")

include("examples.jl")

# include("Benchmarking/BenchmarkRun.jl")
# using .BenchmarkRun
end
