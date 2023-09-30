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
