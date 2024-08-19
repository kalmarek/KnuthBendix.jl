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
The linear-complexity algorithm uses two stacks `v` and `w`:

* `v` is initially empty (represents the trivial word), while
* `w` contains the content of `u` (the word to be rewritten with its first
  letter on its top).

!!! note "Rewriting algorithm"
    1. we pop the first letter `l = popfirst!(w)` from `w`,
    2. we push `l` to the end of `v`,
    3. we determine a rewritng rule (if it exists) `lhs → rhs` with `v = v'·lhs` (i.e.
       `lhs` is equal to a suffix of `v`), and we set
       * `v ← v'` i.e. we remove the suffix fom `v`, and
       * `w ← rhs·w` i.e. `rhs` is _prepended_ to `w`
    4. if no such rule exists we go back to 1.

    These four steps are repeated until `w` becomes empty.

In julia flavoured pseudocode the rewrite procedure looks as follows:

```julia
function rewrite!(v::AbstractWord, w::AbstractWord, rewriting; kwargs...)
    while !isone(w)
        push!(v, popfirst!(w))
        res = find_rule_with_suffix(rewriting, v)
        isnothing(res) && continue # no rule matching was found
        (lhs, rhs) = res
        @assert v[end-length(lhs)+1:end] == lhs # i.e. v = v'·lhs
        resize!(v, length(v)-length(lhs)) # v ← v'
        prepend!(w, rhs) # w ← rhs·w
    end
    return v
end
```

In practice our implementations in place of stacks use [`RewritingBuffer`](@ref)
which consists of a pair of [`BufferWord`s](@ref Words.BufferWord) (a special
implementation of the `AbstractWord` API).

# Particular implementations of rewriting.

Here are some examples of the internal rewriting function already defined:

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::Rule)
rewrite!(::AbstractWord, ::AbstractWord, ::Alphabet)
```
----

Let a rewriting system `rws` is given, and let `lhsₖ → rhsₖ` denote its `k`-th
rule. Let `ℒ = {lhsₖ}ₖ` denote the language of left-hand-sides of `rws` and let
`N = Σₖ length(lhsₖ)` be the total length of `ℒ`.

## Naive rewriting

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::RewritingSystem)
```

The naive rewriting with a rewriting system is therefore in the worst case
**proportional** to the total size of the whole `rws` which makes it a very
inefficient rewriting strategy.

## Index automaton rewriting

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::Automata.IndexAutomaton; history)
```

In practice the complexity of building and maintaining `idxA` synchronized with
`ℒ` overwhelms gains made in rewriting (to construct `idxA` one need to
fully _reduce_ `rws` first which is a very costly operation).

## Prefix automaton rewriting

Rewriting with a prefix automaton `pfxA` traces `w` through a non non-deterministic
automaton which is `pfxA` with a `ε`-labeled loop added at its (unique) initial state.
In tracing we follow **all possible** paths determined by `w`, i.e. in this case
each path begins at every letter of `w`.
Whenever a non-accepting state is encountered on _any_ of the paths,
the corresponding rule `lhs →  rhs` is used for rewriting.

This rewriting can be also understood differently: given the non-deterministic
automaton one could determinize it through power-set construction and
then trace deterministicaly in the automaton whose states are subsets of states
of the initial automaton.
Here we do it without realizing the power-set explicitly and we are
tracing through a procedure described in Sims book as the
_accessible subset construction_.

```@docs
rewrite!(::AbstractWord, ::AbstractWord, ::Automata.PrefixAutomaton; history)
```

In practice the history consists of the subsets of states (of `pfxA`) which are
stored in `PackedVector`, a contiguous array of states with separators. A new path is started whenever a new letter is
pushed onto `v` by simply adding the the initial state of `pfxA` to the current
subset. The rewinding of the history then happens simultanuously for all
paths without additional book-keeping.

Once prefix automaton is build the complexity of this rewriting is achievable
in realistically **quadratic** time with respect to the length of the rewritten word.
This rewriting strikes a balance between the complexity of rewriting and the
synchronization of `pfxA` and `ℒ`, as the insertion of a rule into `pfxA` has linear complexity and can be accomplished without reducing the automaton.

### Even more internals of rewriting



#### On `RewritingBuffer`s

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
  0.000015 seconds (7 allocations: 336 bytes)
Word{UInt16}: 3

```

```@meta
DocTestFilters = nothing
```

This is because the system is tuned towards re-using the storage in the process
of the completion. In particular a [`RewritingBuffer`](@ref) consisting of two
[`Words.BufferWord`](@ref) and the final returned word (of the same type as `w`)
are allocated in the process:

```julia
function rewrite(
    w::W,
    rewriting,
    rwbuffer::RewritingBuffer = RewritingBuffer{T}(rewriting),
    kwargs...,
) where {T,W<:AbstractWord{T}}
    # first copy the content of w into rwbuffer
    Words.store!(rwbuffer, w)
    # then rewrite reusing the internal BufferWords
    rewrite!(rwbuffer, rewriting; kwargs...)
    # finally take ownership of the result
    return W(rwbuffer.output)
end
```

```@docs
RewritingBuffer
```

[`Words.BufferWord`](@ref) is an implementation of [`AbstractWord`](@ref) tuned for the
purpose of this form of rewriting (with `O(1)` complexity for `popfirst!`,
`push!` and `prepend!`).
In the Knuth-Bendix completion these `RewritingBuffer`s are allocated only once per
run and re-used later, so that destructive rewriting is as free
from allocations and memory copy as possible.
