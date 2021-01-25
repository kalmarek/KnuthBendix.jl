# Design Principles

## Words

`AbstractWord{T} <: AbstractVector{T}` is an abstract type representing words over an Alphabet.
It is generally assumed that `T<:Integer` i.e. a word `w::AbstractWord` stores indices of letters of an alphabet,
and therefore as such has its meaning only in the contex of one.

The subtypes of `W <: AbstractWord` need to implement the following methods which
constitute `AbstractWord` interface:
 * `W()`: empty constructor returning the identity (e.g. empty) element
 * linear indexing (1-based) consistent with iteration returning indices of letters
 in an alphabet (`getindex`, `setindex`),
 * `length`: the length of word as written in the alphabet,
 * `Base.push!`/`Base.pushfirst!`: appending a single value at the end/beginning,
 * `Base.pop!`/`Base.popfirst!`: popping a single value from the end/beginning,
 * `Base.append!`/`Base.prepend!`: appending a another word at the end/beginning,
 * `Base.resize!`: dropping/extending a word at the end to the requested length
 * `Base.:*`: word concatenation (monoid binary operation),
 * `Base.similar`: an uninitialized word of a similar type/storage.

Note that `length` represents how word is written and not the shortest form of
e.g. free reduced word.
The following methods are implemented for `AbstractWords` but can be overloaded for
performance reasons:
* `Base.==`: the equality (as words),
* `Base.hash`: simple uniqueness hashing function
* `Base.isone`: predicate checking if argument represents the empty word (i.e. monoid identity element)
* `Base.view`: creating `SubWord` e.g. based on subarray.

In this package we implemented the following concrete subtypes of `AbstractWord{T}`:
* `Word{T}`: a simple `Base.Vector{T}` based implementation
* `BufferWord{T}`: an implementation based on `Vector{T}` storage, which tries to pre-allocate storage to avoid unnecessary allocations for `push!`/`pop!` operations.

## Orderings

`KnuthBendix.jl` defined an abstract type `WordOrdering <: Base.Ordering`. Each ordering should subtype `WordOrdering`.
By making word ordrings as subtypes of `Base.Ordering` we can use on words a number of sorting algorithms already furnished in Julia.

We made a design choice to include/bundle an alphabet to orderings of word, i.e. each `WO::WordOrdering` is valid only with respect to the alphabet it was defined over.
All subtypes of `WordOrdering` should implement a method of `KnuthBendix.alphabet` returning the alphabet.

**TODO:** remove this definition.
The default implementation at the moment expects a field `A::KnuthBendix.Alphabet` but this can be extended by te user.

The `Base.lt(o::O, left, right) where {O<:Base.Ordering}` ("less than") method is used to compare words, and ordering need to implement it.
For details consult `src/orderings.jl`.

Orderings already implemented:
 * `KnuthBendix.LenLex`: left-to-right length+lexicographic (shortlex),
 * `KnuthBendix.WreathOrder` basic wreath-product ordering, and
 * `KnuthBendix.RecursivePathOrder` recursive path ordering.

 **TODO:** do we actually need `Base.:==(o1::T, o2::T) where {T<:WordOrdering}` ? the same for `Base.hash(o::O) where {O<:WordOrdering}`?
Are these only used during tests?

## Rewriting systems

Each rewriting system should be a subtype of `KnuthBendix.AbstractRewritingSystem{W}`.
Note that a rewriting system is well defined only in the context of a `WordOrdering` and `KnuthBendix.ordering(rws::AbstractRewritingSystem)` should return the ordering.

Moreover each `rws::AbstractRewritingSystem` stores rewriting rules ordered according to the defining ordering of `rws`.
To access the iterator (FIXME: ???) over all rules stored in a rewriting system `KnuthBendix.rules` function should be used.

Each subtype of this abstract type should implement the following interface (see docstring for that abstract type for more information): pushing, poping, appending, inserting, delating rules, emptying the whole structure and obtaining the length of ot (i.e. number of rules stored in the structure - both active and inactive).

TODO: add more precise list and info about methods with `AbstractRewritingSystem` which we use in rewriting.

### `KnuthBendix.RewritingSystem`

We implemented a simple `RewritingSystem{W<:AbstractWord, O<:WordOrdering} <:AbstractRewritingSystem{W}` which stores the defining ordering in one of its fields.
Each rule (in the current implementation) consist of an ordered pair of words `(lhs, rhs)::Tuple{W,W}` (i.e. `Base.lt(ordering(rws), lhs, rhs)` holds), which represents rewriting rule
> `lhs` → `rhs`.

**IDEA:** create a distinct type/class for a single rewriting rule and store the rules as a list of this objects. Such rule could store also its status (active or not), etc. See #24.

Inside `RewritingSystem{W}` we also store `rules::Vector{W}` and (paired with it) `act::BitArray` which stores `1` when the corresponding rule in `rules` is active and `0` otherwise. Note that iterating over `KnuthBendix.rules(rws)` returns all rules, regardless of their active status.

**TODO:** return an specialized iterator over rules of `rws` which iterates only over active rules. This would surely make code simpler/easier to read and more generic.

### Simplifying rules

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
