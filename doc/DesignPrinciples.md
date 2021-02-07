# Design Principles

## Words

`AbstractWord{T} <: AbstractVector{T}` is an abstract type representing words over an Alphabet.
It is generally assumed that `T<:Integer`, i.e. a word `w::AbstractWord`, stores indices of letters of an alphabet,
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

Note that `length` represents how word is written and not the shortest form of, e.g., free reduced word.
The following methods are implemented for `AbstractWords` but can be overloaded for performance reasons:
* `Base.==`: the equality (as words),
* `Base.hash`: simple uniqueness hashing function
* `Base.isone`: predicate checking if argument represents the empty word (i.e. monoid identity element)
* `Base.view`: creating `SubWord` e.g. based on subarray.

In this package we implemented the following concrete subtypes of `AbstractWord{T}`:
* `Word{T}`: a simple `Base.Vector{T}` based implementation
* `BufferWord{T}`: an implementation based on `Vector{T}` storage,
which tries to pre-allocate storage to avoid unnecessary allocations for `push!`/`pop!` operations.

## Orderings

`KnuthBendix.jl` defined an abstract type `WordOrdering <: Base.Ordering`.
Each ordering should subtype `WordOrdering`.
By making word ordrings as subtypes of `Base.Ordering` we can use on words a number
of sorting algorithms already furnished in Julia.

We made a design choice to include/bundle an alphabet into orderings of word,
i.e. each `WO::WordOrdering` is valid only with respect to the alphabet it was defined over.
All subtypes of `WordOrdering` should implement a method of `KnuthBendix.alphabet` returning the alphabet.

**TODO:** remove this definition.
The default implementation at the moment expects a field `A::KnuthBendix.Alphabet` but this can be extended by te user.

The `Base.lt(o::O, left, right) where {O<:Base.Ordering}` ("less than") method is used to compare words,
and ordering needs to implement it.
For details consult `src/orderings.jl`.

Orderings already implemented:
 * `KnuthBendix.LenLex`: left-to-right length+lexicographic (shortlex),
 * `KnuthBendix.WreathOrder` basic wreath-product ordering, and
 * `KnuthBendix.RecursivePathOrder` recursive path ordering.

 **TODO:** do we actually need `Base.:==(o1::T, o2::T) where {T<:WordOrdering}`?
 The same for `Base.hash(o::O) where {O<:WordOrdering}`?
Are these only used during tests?

Ad TODO: I [MP] belive we do not need it.

## Rewriting systems

Each rewriting system should be a subtype of `KnuthBendix.AbstractRewritingSystem{W}`.
Note that a rewriting system is well defined only in the context of a `WordOrdering`
and `KnuthBendix.ordering(rws::AbstractRewritingSystem)` should return the ordering.

Moreover, each `rws::AbstractRewritingSystem` stores rewriting rules ordered according to the defining ordering of `rws`.
(To be precise: the list of rules is not ordered, it is only the left and the right side of each rule that are ordered,
so that left-hand side > right-hand side).
To access the iterator (FIXME: ???) over all rules stored in a rewriting system `KnuthBendix.rules` function should be used.

Each subtype of this abstract type should implement the following interface
(see docstring for that abstract type for more information):
pushing, popping, appending, inserting, deleting rules, emptying the whole structure and obtaining the length of it
(i.e. number of rules stored in the structure - both active and inactive).

TODO: add more precise list and info about methods with `AbstractRewritingSystem` which we use in rewriting.

Specific places where certain interfaces arw used:

* `push!(rws)` - used in `forceconfluece!` and `deriverule!` to add rules to stack or rewriting system;
* `pop!(rws)` - during `deriverule!`, to get the rules from a stack;
* `empty!(rws)` - used in the beginning of some of `knuthbendix` procedure implementations;
* `isactive(rws, i::Integer)` - at various stages of `knuthbendix` procedure to check if the rule is active;
* `setinactive!(rws, i::Integer)` - during `deriverule!`, to mark rules as inactive.

### `KnuthBendix.RewritingSystem`

We implemented a simple `RewritingSystem{W<:AbstractWord, O<:WordOrdering} <:AbstractRewritingSystem{W}`
which stores the defining ordering in one of its fields.
Each rule (in the current implementation) consist of an ordered pair of words `(lhs, rhs)::Tuple{W,W}`
(i.e. `Base.lt(ordering(rws), lhs, rhs)` holds), which represents rewriting rule
> `lhs` → `rhs`.

**IDEA:** create a distinct type/class for a single rewriting rule and store the rules as a list of this objects.
Such rule could store also its status (active or not), etc. See #24.

Inside `RewritingSystem{W}` we also store `rules::Vector{W}` and (paired with it) `act::BitArray`,
which stores `1` when the corresponding rule in `rules` is active and `0` otherwise.
Note that iterating over `KnuthBendix.rules(rws)` returns all rules, regardless of their active status.

**TODO:** return an specialized iterator over rules of `rws` which iterates only over active rules.
This would surely make code simpler/easier to read and more generic.

### Simplifying rules

Method `simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)` was suggested in the book by Sims.
It takes a rule (typically prodcued during Knuth-Bendix procedure) and (as of now)
cancels out maximal invertible prefix and suffix of both sides of the rule.

## States and Automata

### States

Before describing automata itself we should describe a single state in it.
`KnuthBendix.State{N, W}<:KnuthBendix.AbstractState` struct is indexed by two parameters:
* `N` the length of the alphabet we use (a letter and its inverse are considered as two distinct elements of the alphabet), and
* `W` particular type of `AbstractWord` that we use.

#### Details of implementation

A state has a `name`: a word corresponding to the shortest path from initial state to the state in mention
(that way it is easy to define a length function for a state - as mentioned in Sims - this is just a length of the name).

A field `terminal` is a boolean which indicates whether the state represents a word,
which is a left-hand side of some rewriting rule in `RewritingSystem`.
In case this is the case (field `terminal` is `true`) field `rrule` should be equal to the `Word` representing
the right-hand side of that rewriting rule.

Field `ined` (incoming edges) is a vector of instances of `State` struct - those instances of `State`
from which there is an edge leading to a state in mention
(so for a `State` with name "abc" there must be - in particular - a `State` with name "ab" in the `ined` list).
What is more: always on the first place on that list should be a state representing (having field `name`)
the `Word` of the form `name[1:end-1]` (i.e. the name which is sort of "the closest predecessor" of that state/word)
- compare the algorithm for `makeindexautomaton`.
[BTW: in the case of index automata all the `inedges` should be labelled by the same letter.]

Field `outed` (outcoming edges) - is a `NTuple` (i.e. tuple of the size equal to the size of alphabet)
of states to which there is an edge from the state in mention.
Since index automata are deterministic there is only one edge for every letter in the alphabet coming out of our state.
Thus we use N-tuples - indexes of the tuple correspond to indexes of the letters in the `Alphabet` struct.
I.e. the idea is as follows: if we want to travel from a state `s` (say with name "ab")
through the edge labelled by letter "c" (say it is stored in the `Alphabet` at the index 3)
we just take call `s.outed[3]` and we would land in the state named "abc"
(provided of course, that all the states are defined within automaton).

Field `isfailstate` (boolean) is a field that is used to represent kind of an empty state / failure state
which is created when we create a new automaton
(this state is necessary to represent edges which are not yet constructed in the tuple `outed`).
Since `ined` and `outed` introduce circular connections between states,
there is a need to have a unique "noedge / failstate" state in the whole automaton to which we can point
(in order to prevent additional allocations and in order to have the N-Tuple representing outedges of parametrized by `{N, State{N, W}`).

**IMPORTANT:** states should not be created on its own.
One should always create an `Automaton` first and the add states inside it via `push!` and `addedge!` interface.

**IDEA:** When working with groups we could try to utilise the fact that a letter and its inverse are closely related
and that each letter has an inverse (so that maybe we could skip some fields).

### Automata

`Automaton{N, W} <: AbstractAutomaton{N, W}` is the basic structure that contatins states.
Recall that an instance of `State` should not "live" outside of automaton.
Automata are paramaterized the same way the `State`s are
(i.e. by `N` - size of the `Alphabet` and `W` - the particular type of `AbstractWord` used).

Field `states` is a list of states in the automaton.
During the declaration of automaton the unique initial state corresponding to empty word is created and appended to that list.

Field `abt` contains alphabet used.
Field `failstate` is a field that contains a unique state representing lack of edge / failure state -
it is created during the declaration of the automaton.
Field `stateslengths` is a list of lengths of states (indexes corresponding to the indexes in `states`).

The following constitutes a interface to `Automaton{N, W}` and `State{N,W}`:
* `push!(at::Automaton, name::W)`: pushes a new state with the `name` to the automaton;
* `addedge!(at::Automaton, label::Integer, src::Integer, dst::Integer)`:
adds the edge with a given `label` (index of the letter in thegiven alphabet) directed
from `src` state (index of the source state in the list of states stored in the automaton)
to `dst` state (index of the source state in the list of states stored in the automaton);
* `removeedge!(a::Automaton, label::Integer, from::Integer, to::Integer)` as above, but removes edge;
* `walk(a::AbstractAutomaton, signature::AbstractWord[, state=initialstate(a)])`: walks or traces the automaton
according to the path given by the `signature`, starting from `state`.
Returns a tuple `(idx, state)` where `idx` is the length of prefix of signature which was successfully traced and
`state` is the final state.
Note that if `idx ≠ length(signature)` there is no path in the automaton corresponding to the full signature.
* `makeindexautomaton!(a::Automaton, rws::RewritingSystem)` builds an index automaton corrresponding to
the given rewriting system on the automaton `a`;
* `updateautomaton!(a::Automaton, rws::RewritingSystem)`: this is an interface designed for future -
to be used to update existing index automaton instead of rebuilding it from scratch.
At the moment it performs rebuilding automaton from scratch.

**IDEA:** Implement automata as matrices (consult Sims' book:
chapter about automata and chapter about implementation considerations at the end of the book).

## Helper structures

### BufferPair

`BufferPair{T} <: AbstractBufferPair{T}` is a pair of `BufferWord{T}` (stored in fields `_vWord` and `_wWord`),
that are used for rewriting.
This structure is used to limit the number of allocations while performing Knuth-Bendix procedure.
Two `BufferPair`s are needed for an efficient rewriting. One is used in rewriting the left-hand side of the rule
and the other in rewriting of the right-hand side (which is performed in `deriverule!`).
`BufferPair`s are stored in `kbWork{T}` helper structure - see below.

### kbWork

`kbWork{T}` is a helper structure used to iterate over rewriting system in Knuth-Bendix procedure.
It has the following fields:
* `i` field is the iterator over the outer loop and
* `j` is the iterator over the inner loop
* `lhsPair` and `rhsPair` are inner `BufferPair`s used for rewriting.
* `_inactiverules` is just a list of inactive rules in the `RewritingSystem` subjected to Knuth-Bendix procedure.

The aim of this structure is to:
* enable deletion of inactive rules (which requires updating working indexes `i` and `j` of Knuth-Bendix procedure).
This deletion is performed by the `removeinactive!(rws::RewritingSystem, work::kbWork)` function which is called
periodically during certain implementations of Knuth-Bendix procedure.
* reduce the number of allocations caused by rules rewriting (thus there are two `BufferPair`s).

This structure is created inside `knuthbendix` and is passed to `forceconfluence!` and `deriverule!`.

## Knuth-Bendix procedure

As of now there 4 implementations:
* `crude`, which is basically 1-1 implementation of `KBS1` from the Sims' book.
* `naive`, which is an implementation of `KBS2` from the Sims' book with simplification of rules incorporated.
* `deletion`, which is based on `KBS2`, uses simplification of rules and periodically removes inactive rules.
* `automata`, which is uses automata for rewriting. Simplification of the rules is also incorporated.

Versions `deletion` and `automata` can be considered the best (fastest) ones at the moment.
The problem with `automata` is that the index automaton needs to be rebuilt quite often
(due to the changes in `RewritingSystem`) - this can hinder the efficiency gain obtained by faster rewriting.
