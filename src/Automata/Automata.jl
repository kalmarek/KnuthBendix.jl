module Automata

import ..KnuthBendix
import ..KnuthBendix:
    AbstractWord, RewritingOrdering, AbstractRewritingSystem, Rule
import ..KnuthBendix: alphabet, ordering, rules, word_type

export IndexAutomaton, PrefixAutomaton

include("states.jl")
include("interface.jl")
include("index_automaton.jl")
include("rebuilding_idxA.jl")

include("prefix_automaton.jl")

include("backtrack.jl")

end # of module Automata
