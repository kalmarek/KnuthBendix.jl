# Design Principles

## Orderings

Each word ordering should be a subtype of an abstract type `WordOrdering`, which - in turn - is a subtype of an abstract type `Ordering`. `Ordering` is an abstract type defined in `Base` package of Julia - by making word ordrings as subtypes of `Ordering` we enable the use of a number of sorting algorithms already furnished in Julia.

All subtypes of `WordOrdering` should contain a field `A` storing the `Alphabet`
over which a particular order is defined. Morever, an `Base.lt` method should be
defined to compare whether one word is less than the other (in the ordering
defined).

**Note:** `lt` means "less than". :D

Orderings already implemented: left-to-right length+lexicographic (lenlex/shortlex); basic wreath-product ordering and recursive path ordering.

## Rewriting systems etc.

`RewritingSystem{W<:AbstractWord, O<:WordOrdering}` stores rewriting rules (as of now: as list of pairs of words `W`: `first` element of the pair being left-hand side of the rule and the `second` element of the pair being right-hand side of the rule).

Each `RewritingSystem` should also have a `WordOrdering` in which it works specified. In particular left side of each rule should be bigger than the right side (in that ordering).

**IDEA:** create a distinct type/class for a single rewriting rule and store the rules as a list of this objects.

Inside `RewritingSystem` we also store an BitArray `act` which is of the same length as the array of rules stored and indicates by `1` when the rule stored in the corresponding place in the array of rules is active and by `0` that it is inactive.

Inside `RewritingSystem` we also store `_inactiverules` which is a vector of indices of rules that are inactive. This is used by `removeinactive!` method called in some versions of KnuthBendix2 procedure which deletes those inactive rules. The field `_inactiverules` will/should probably be moved to `kbWord` structure.

Each `RewritingSystem` should be a subtype of `AbstractRewritingSystem{W,O}`. In particular each subtype of this abstract type should implement the following interface (see docstring for that abstract type for more information): pushing, poping, appending, inserting, delating rules, emptying the whole structure and obtaining the length of ot (i.e. number of rules stored in the structure - both active and inactive).

## Simplifying rules

Method `simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)` was suggested in the book by Sims. It takes a rule (typically prodcued during Knuth-Bendix procedure) and (as of now) cancels out maximal invertible prefix of both sides of the rule.

**IDEA:** add all cancelling out of invertible suffixes.

## States

Before describing automata itself we should desribe a single state in it. `State` (and `AbstractState`) struct is indexed by parameters `N` (an integer equal to the length of the alphabet we use - a letter and its inverse is - as of now - considered as two distinct elements of the alphabet) and `W` (particular type of `Word` tha we use).

A state has a `name`: a word corresponding to the shortest path from intial state to the state in mention (that way it is easy to define a length function for a state - as mentioned in Sims - this is just a length of the name).

A field `terminal` is a boolean which indicates whether the state represents a word which is a left-hand side of sime rewriting rule in `RewritingSystem`. In case this is the case (field `terminal` is `true`) field `rrule` should be equal to the `Word` representing the right-hand side of that rewriting rule.

Field `ined` (incoming edges) is a vector of instances of `State` struct - those instances of `State` from which there is an edge leading to a state in mention (so for a `State` with name "abc" there must be - in particular - a `State` with name "ab" in the `ined` list). What is more: always on the first place on that list should be a state representing (having field `name`) the `Word` of the form `name[1:end-1]` (i.e. the name which is sort of "the closest predecessor" of that state/word) - compare the algorithm for `makeindexautomaton`. [BTW: in the case of index automata all the inedges should be labelled by the same letter.]

Field `outed` (outcoming edges) - is a N-tuple (i.e. tuple of the size equal to the size of alphabet) of states to which there is an edge from the state in mention. Since index automata are deterministic there is only one edge for every letter in the alphabet coming out of our state. Thus we use N-tuples - indexes of the tuple correspond to indexes of the letters in the `Alphabet` struct. I.e. the idea is as follows: if we want to travel from a state `s` (say with name "ab") through the edge labelled by letter "c" (say it is stored in the `Alphabet` at the index 3) we just take call `s.outed[3]` and we would land in the state named "abc" (provided of course, that all the states are defined within automaton).

Field `representsnoedge` (boolean) is a field that is used to represent kind of an empty state which is created when we create a new automaton (this state is necesarry to represent edges which are not yet constructed in the tuple `outed`). Since `ined` and `outed` introduce circular connections between states there is a need to have a unique "noedge" state in the whole automaton to which we can point (in order to prevent additional allocations and in order to have the N-Tuple representing outedges of parametrized by `{N, State{N, W}`).

**IMPORTANT:** states should not be created on its own. One should always create an `Automaton` first and the add states inside it via `push!` and `addedge!` interface.

**IDEA:** When working with groups we could try to utilise the fact that a letter and its inverse are closely related and that each letter has an inverse (so that maybe we could skip some fields).

## Automata

`Automaton` is the basic structure that contatins states. Recall that an instance of `State` should not leave outside automata. `Automaton` and `AbstractAutomaton` are paramaterized the same way the `State` is (i.e. by `N` - size of the `Alphabet` and `W` - the particular type of `Word` used).

Field `states` is a list of states in the automaton. During the declaration of automaton the unique initial state corresponding to emty word is created and appended to that list.

Field `abt` contains alphabet used. Field `uniquenoedge` is a field that contains a uniqe state representing lack of edge - it is created during the declaration of the automaton. Field `stateslengths` is a list of lengths of states (indexes corresponding to the indexes in `states`).

**IDEA:** Implement automata as matrices (consult Sims' book: chapter about automata and chapter about implementation considerations at the end of the book),
