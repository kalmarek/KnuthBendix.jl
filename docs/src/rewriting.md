# On rewriting

```@meta
CurrentModule = KnuthBendix
```

```@docs
rewrite
```

## Internals

Implementing rewriting procedure naively could easily lead to quadratic
complexity due to unnecessary moves of parts of the rewritten word.
We follow the the linear-complexity algorithm in which we use two stacks and
`rewrite` function calls internally

```julia
function rewrite!(v::AbstractWord, w::AbstractWord, rewriting; kwargs...)
    ...
    return v
end
```

The semantics are that `v` and `w` are two stacks and

* `v` is initially empty (represents the trivial word), while
* `w` contains the content of `u` (the word to be rewritten with its first
  letter on its top).

In practice we use [`BufferWord`s](@ref Words.BufferWord) (a special
implementation of `AbstractWord` API) and all our implementations the process
is as follows.

1. we pop the first letter `l = popfirst!(w)` from `w`,
2. we push `l` to the end of `v`,
3. we try to determine a rewritng rule `lhs → rhs` with `v = v'·lhs` (i.e.
   `lhs` is equal to a suffix of `v`) and we set
   * `v ← v'` i.e. we remove the suffix fom `v`, and
   * `w ← rhs·w` i.e. `rhs` is _prepended_ to `w`
4. if no such rule exists we go back to 1.

These four steps are repeated until `w` becomes empty.

Here are some examples of the internal rewriting function already defined:

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::Rule)
rewrite!(::AbstractWord, ::AbstractWord, ::Alphabet)
```

Let a rewriting system `rws` is given, and let `lhsₖ → rhsₖ` denote its `k`-th
rule. Let `ℒ = {lhsₖ}ₖ` denote the language of left-hand-sides of `rws` and let
`N = Σₖ nₖ` be the total length of `ℒ`.

## Naive rewriting

The naive version is to check for every rule `lhs → rhs` in `rws` if `v`
contains `lhs` as a suffix. If so, the suffix is removed from `v`, `rhs` is
prepended to `w` and we move to the (new) first letter of `w`.
With `m = length(u)` the complexity of this rewriting is `Ω(m · N)`, i.e. it is
**proportional** to the size of the whole rewriting system making it a very
inefficient rewriting strategy.

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::RewritingSystem)
```

## Index automaton

Rewriting with an index automaton `idxA` traces (follows) the path in the
automaton determined by `w` (since the automaton is deterministic there is only
one such path). Whenever a terminal (i.e. accepting) state is encountered its
corresponding rule `lhs → rhs` is retrived, the appropriate suffix of `v`
(equal to `lhs`) is removed, and `rhs` is prepended to `w`. Tracing continues
from the newly prepended letter.

To continue tracing `w` through the automaton we need to backtrack on our path
in the automaton and for this `rewrite` maintains a vector of visited states of
`idxA` (the history of visited states of `idxA`). Whenever a suffix is removed
from `v`, the path is rewinded (i.e. shortened) to the appropriate length and
the next letter of `w` is traced from the last state on the path. This maintains
the property that signature of the path is equal to `v` at all times.

Once index automaton is build the complexity of this rewriting is `Ω(m)` which
is the optimal rewriting strategy. In practice the complexity of building and
maintaining `idxA` synchronized with `ℒ` overwhelms gains made in rewriting
(to construct `idxA` one need to _reduce_ `rws` first which is `O(N²)` (??)).

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::Automata.IndexAutomaton; history)
```

## Non-deterministic prefix automaton

Rewriting with a non-deterministic prefix automaton `pfxA` traces the whole
set of paths in `pfxA` which are determined by `w`. Since `pfxA` contains an
`ε`-labeled loop at its (unique) initial state, tracing `w` through `pfxA`
amounts to tracing a set of paths where each begins at every letter of `w`.
Whenever a terminal (i.e. accepting) state is encountered on _any_ of the paths,
the corresponding rule `lhs →  rhs` is retrived, the appropriate suffix of `v`
(equal to `lhs`) is removed, and `rhs` is prepended to `w`.

As above, to continue tracing the set of paths we need to backtrack each path
and for this `rewrite` maintains the histories of visited states of `pfxA`
for each path. Whenever a suffix is removed from `v` each path must be
rewinded by an appropriate length.

This rewriting can be also understood differently: given the non-deterministic
automaton `pfxA` one could determinize it through power-set construction and
then trace deterministicaly in the automaton whose states are subsets of states
of `pfxA`. Here we do it without realizing the power-set explicitly and we are
tracing through procedute described in Sims as _accessible subset construction_.

In practice the history consists of the subsets of states (of `pfxA`) which are
stored in a contiguous array and an additional vector of indices marking the
separation indices is added. A new path is started whenever a new letter is
pushed onto `v` by simply adding the the initial state of `pfxA` to the current
subset. The rewinding of the history then can be done simultanuously for all
paths (without much bookkeeping) by shortening the vector of separators
and resizing contiguous array of states accordingly.

Once prefix automaton is build the complexity of this rewriting is `Ω(m²)`.
This rewriting strikes a balance between the complexity of rewriting and the
synchronization of `pfxA` and `ℒ`, as the insertion and the removal of a word
`w` to `pfxA` has complexity `O(m)`.

### Even more internals of rewriting

#### On `BufferWord`s

Rewriting is a crucial part of the Knuth-Bendix completion. In particular we
do care plenty not only about the theoretical complexity, but also the
practical speed of rewriting. You may be surprised then that a simple
`rewrite` allocates `6` times:

```@meta
CurrentModule = KnuthBendix
DocTestFilters = r"[0-9\.]+ seconds \(.*\)"
DocTestSetup  = quote
    using KnuthBendix
end
```

```jldoctest
julia> alph = Alphabet([:a, :A, :b], [2,1,3])
Alphabet of Symbol
  1. a    (inverse of: A)
  2. A    (inverse of: a)
  3. b    (self-inverse)

julia> a = Word([1]); A = Word([2]); b = Word([3]);

julia> w = a*A*b^3;

julia> @time KnuthBendix.rewrite(w, alph)
  0.000015 seconds (6 allocations: 272 bytes)
Word{UInt16}: 3

```

```@meta
DocTestFilters = nothing
```

This is because the system is tuned towards re-using the storage in the process
of the completion. In particular two [`Words.BufferWord`](@ref) and the final
returned word (of the same type as `w`) are allocated in the process:

```julia
function rewrite(
    w::W,
    rewriting,
    vbuff = Words.BufferWord{T}(0, length(u)),
    wbuff = Words.BufferWord{T}(0, length(u));
    kwargs...,
) where {T,W<:AbstractWord{T}}
    # first copy the content of w into wbuff then
    rewrite!(vbuff, wbuff, rewriting; kwargs...)
    # finally take ownership of the content of vbuff
    return W(vbuff)
end
```

[`Words.BufferWord`](@ref) is an implementation of [`AbstractWord`](@ref) tuned for the
purpose of this form of rewriting (with `O(1)` complexity for `popfirst!`,
`push!` and `prepend!`).
In the Knuth-Bendix completion these `BufferWord`s are allocated only once per
run and re-used as much as possible, so that destructive rewriting is as free
from allocations and memory copy as possible.

In particular rewriting with `BufferPair` saves all of those allocations at the
cost of owning the result:

```@docs
rewrite!(::KnuthBendix.BufferPair, u::AbstractWord, rewriting)
```

`BufferPair` is just a convinience struct that bundles everything for
allocation-free rewriting. While it is used extensively during Knuth-Bendix
completion you should never see it outside of it!
