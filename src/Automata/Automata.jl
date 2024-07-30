module Automata

import ..KnuthBendix
import ..KnuthBendix: AbstractWord, RewritingOrdering, RewritingSystem, Rule
import ..KnuthBendix: alphabet, rules, word_type

export IndexAutomaton, PrefixAutomaton

include("states.jl")
include("interface.jl")
include("index_automaton.jl")
include("rebuilding_idxA.jl")

include("prefix_automaton.jl")

include("backtrack.jl")

end # of module Automata
