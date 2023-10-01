# Naive

This version is a simplistic implementation of the completion that is terrible
to run and great for understanding the general idea. This version follows
closely procedure `KBS_1` from **Section 2.5**[^Sims1994].

----

Below is a julia-flavoured pseudocode describing the completion procedure.

```julia
function knuthbendix1(rws::RewritingSystem; kwargs...)
    for ri in rules(rws)
        for rj in rules(rws)
            forceconfluence!(rws, ri, rj)
            ri == rj && break
            forceconfluence!(rws, rj, ri)
        end
        # Maybe some checks here, etc.
    end
    return rws
end
```

```@meta
CurrentModule = KnuthBendix
```

Here [`forceconfluence!`](@ref
forceconfluence!(::RewritingSystem, ::Any, ::Any))
finds all potential failures to local confluence in `rws` that arise as
intersection of rules `ri` and `rj`, and [`deriverule!`](@ref
deriverule!(rws::RewritingSystem, ::AbstractWord, ::AbstractWord))
resolves them. This means that all suffix-prefix words are identified
(see [Local confluence and suffix-prefix words](@ref)) and the appropriate
rules to resolve the failures in rewriting are **pushed** to `rws`.
This extends[^1] the iteration over `rules(rws)` and the outer loop becomes
longer.

An important feature is that while the outer loop (`for ri in rules(rws)`) is
potentially infinite, the inner one (`for rj in rules(rws)`) is always broken
after a finite number of steps. We therefore traverse (potentially) doubly
infinite iteration space in finite chunks which guarantees that each pair of
rules will be considered **after a finite amount of time**. Completion even for
very simple rewriting systems may fail if this condition is not observed.

As a side-effect we may choose to run some checks etc. after the inner loop is
and we could e.g. decide to quit early (if things go out of hand) or do
something else.

```@docs
knuthbendix1
forceconfluence!(rws::RewritingSystem, ::Any, ::Any)
deriverule!(rws::RewritingSystem, ::AbstractWord, ::AbstractWord)
reduce!(::KBS1AlgPlain, ::RewritingSystem)
```

[^1]: If you don't like changing the structure while iterating over it you are
      not alone, but sometimes it is the easiest things to do.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.

## Example from the theoretical section

To reproduce computations of the [Example](@ref) one could call `knuthbendix1`
as follows.

```@meta
CurrentModule = KnuthBendix
DocTestSetup  = quote
    using KnuthBendix
end
```

```jldoctest
julia> alph = Alphabet([:a,:A,:b],[2,1,0])
Alphabet of Symbol
  1. a    (inverse of: A)
  2. A    (inverse of: a)
  3. b

julia> a,A,b = [Word([i]) for i in 1:length(alph)]
3-element Vector{Word{UInt16}}:
 Word{UInt16}: 1
 Word{UInt16}: 2
 Word{UInt16}: 3

julia> rules = [b^3=>one(b), a*b => b*a]
2-element Vector{Pair{Word{UInt16}, Word{UInt16}}}:
 3·3·3 => (id)
   1·3 => 3·1

julia> rws = RewritingSystem(rules, LenLex(alph))
Rewriting System with 4 active rules ordered by LenLex: a < A < b:
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                              a*A │ (id)                             │
│    2 │                              A*a │ (id)                             │
│    3 │                              b^3 │ (id)                             │
│    4 │                              b*a │ a*b                              │
└──────┴──────────────────────────────────┴──────────────────────────────────┘

julia> KnuthBendix.knuthbendix1(rws, verbosity = 2)
┌ Warning: knuthbendix1 is a simplistic implementation for educational purposes only.
└ @ KnuthBendix ~/.julia/dev/KnuthBendix/src/knuthbendix1.jl:146
[ Info: consider (1, 1) for critical pairs
[ Info: consider (2, 1) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (2·1 ⇒ (id), 1·2 ⇒ (id))
│   (a, b, c) = (2, 1, 2)
└   pair = (2, 2)
[ Info: pair does not fail local confluence, both sides rewrite to 2
[ Info: consider (1, 2) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (1·2 ⇒ (id), 2·1 ⇒ (id))
│   (a, b, c) = (1, 2, 1)
└   pair = (1, 1)
[ Info: pair does not fail local confluence, both sides rewrite to 1
[ Info: consider (2, 2) for critical pairs
[ Info: consider (3, 1) for critical pairs
[ Info: consider (1, 3) for critical pairs
[ Info: consider (3, 2) for critical pairs
[ Info: consider (2, 3) for critical pairs
[ Info: consider (3, 3) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·3·3 ⇒ (id), 3·3·3 ⇒ (id))
│   (a, b, c) = (3·3, 3, 3·3)
└   pair = (3·3, 3·3)
[ Info: pair does not fail local confluence, both sides rewrite to 3·3
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·3·3 ⇒ (id), 3·3·3 ⇒ (id))
│   (a, b, c) = (3, 3·3, 3)
└   pair = (3, 3)
[ Info: pair does not fail local confluence, both sides rewrite to 3
[ Info: consider (4, 1) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·1 ⇒ 1·3, 1·2 ⇒ (id))
│   (a, b, c) = (3, 1, 2)
└   pair = (1·3·2, 3)
[ Info: pair fails local confluence, rewrites to 1·3·2 ≠ 3
[ Info: adding rule [ 5. a*b*A	 → 	b ] to rws
[ Info: consider (1, 4) for critical pairs
[ Info: consider (4, 2) for critical pairs
[ Info: consider (2, 4) for critical pairs
[ Info: consider (4, 3) for critical pairs
[ Info: consider (3, 4) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·3·3 ⇒ (id), 3·1 ⇒ 1·3)
│   (a, b, c) = (3·3, 3, 1)
└   pair = (1, 3·3·1·3)
[ Info: pair does not fail local confluence, both sides rewrite to 1
[ Info: consider (4, 4) for critical pairs
[ Info: consider (5, 1) for critical pairs
[ Info: consider (1, 5) for critical pairs
[ Info: consider (5, 2) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (1·3·2 ⇒ 3, 2·1 ⇒ (id))
│   (a, b, c) = (1·3, 2, 1)
└   pair = (3·1, 1·3)
[ Info: pair does not fail local confluence, both sides rewrite to 1·3
[ Info: consider (2, 5) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (2·1 ⇒ (id), 1·3·2 ⇒ 3)
│   (a, b, c) = (2, 1, 3·2)
└   pair = (3·2, 2·3)
[ Info: pair fails local confluence, rewrites to 3·2 ≠ 2·3
[ Info: adding rule [ 6. b*A	 → 	A*b ] to rws
[ Info: consider (5, 3) for critical pairs
[ Info: consider (3, 5) for critical pairs
[ Info: consider (5, 4) for critical pairs
[ Info: consider (4, 5) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·1 ⇒ 1·3, 1·3·2 ⇒ 3)
│   (a, b, c) = (3, 1, 3·2)
└   pair = (1·3·3·2, 3·3)
[ Info: pair does not fail local confluence, both sides rewrite to 3·3
[ Info: consider (5, 5) for critical pairs
[ Info: consider (6, 1) for critical pairs
[ Info: consider (1, 6) for critical pairs
[ Info: consider (6, 2) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·2 ⇒ 2·3, 2·1 ⇒ (id))
│   (a, b, c) = (3, 2, 1)
└   pair = (2·3·1, 3)
[ Info: pair does not fail local confluence, both sides rewrite to 3
[ Info: consider (2, 6) for critical pairs
[ Info: consider (6, 3) for critical pairs
[ Info: consider (3, 6) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (3·3·3 ⇒ (id), 3·2 ⇒ 2·3)
│   (a, b, c) = (3·3, 3, 2)
└   pair = (2, 3·3·2·3)
[ Info: pair does not fail local confluence, both sides rewrite to 2
[ Info: consider (6, 4) for critical pairs
[ Info: consider (4, 6) for critical pairs
[ Info: consider (6, 5) for critical pairs
[ Info: consider (5, 6) for critical pairs
┌ Info: lhs₁ suffix-prefix lhs₂:
│   rules = (1·3·2 ⇒ 3, 3·2 ⇒ 2·3)
│   (a, b, c) = (1, 3·2, (id))
└   pair = (3, 1·2·3)
[ Info: pair does not fail local confluence, both sides rewrite to 3
[ Info: consider (6, 6) for critical pairs
Rewriting System with 5 active rules ordered by LenLex: a < A < b:
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                              a*A │ (id)                             │
│    2 │                              A*a │ (id)                             │
│    3 │                              b^3 │ (id)                             │
│    4 │                              b*a │ a*b                              │
│    5 │                              b*A │ A*b                              │
└──────┴──────────────────────────────────┴──────────────────────────────────┘


```
