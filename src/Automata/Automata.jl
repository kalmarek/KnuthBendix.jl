module Automata

import ..KnuthBendix
import ..KnuthBendix: AbstractWord, RewritingSystem, Rule
import ..KnuthBendix: alphabet, rules, word_type

export IndexAutomaton

include("states.jl")
include("interface.jl")
include("index_automaton.jl")
include("rebuilding_idxA.jl")

end # of module Automata