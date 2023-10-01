# Using a stack

As can be observed in [Knuth Bendix completion -- an example](@ref) after we
have added rule 6, there was no point considering rule 5, since it was
rendered redundant. This can be achieved by keeping a boolean variable for each
rule indicating its status, and flipping it to `false` when it becomes
redundant. This version is based on procedure `KBS_2` from
**Section 2.6**[^Sims1994].

----

Below is a julia-flavoured pseudocode describing the completion procedure.

```julia
function knuthbendix2(rws::RewritingSystem{W}, ...) where W
    stack = Vector{Tuple{W,W}}()
    rws = reduce(rws) # this is assumed by forceconfluence!

    # ... initialize some temporary structures here
    for ri in rules(rws)
        for rj in rules(rws)
            isactive(ri) || break
            forceconfluence!(rws, stack, ri, rj, ...)

            ri === rj && break
            isactive(ri) || break
            isactive(rj) || continue
            forceconfluence!(rws, stack, rj, ri, ...)
        end
    end
    remove_inactive!(rws) # all active rules form a reduced confluent rws
    return rws
end
```

```@meta
CurrentModule = KnuthBendix
```

Not much has changed on the surface, but there are more substantial changes
under the hood. In particular [`forceconfluence!`](@ref
forceconfluence!(::RewritingSystem, ::Any, ::Any, ::Any, ::Workspace)) has become simply

```julia
function forceconfluence!(rws::RewritingSystem, stack, ri, rj, ...)
    find_critical_pairs!(stack, rws, ri, rj, ...)
    deriverules!(rws, stack, ...)
    return rws
end
```

I.e. we first push all failures to local confluence derived from `ri` and `rj`
onto `stack` (([`find_critical_pairs!`](@ref
find_critical_pairs!(::Any, ::Any, ::Rule, ::Rule, ::Workspace)))), then
empty the stack ([`deriverule!`](@ref deriverule!(::RewritingSystem, stack))).
To do this the top pair `lhs → rhs` is picked from the stack, we mark all
the rules in `rws` that could be reduced with `lhs` as inactive and push them
onto the stack. Only afterwards we push `lhs → rhs` to `rws` and we repeat
until the stack is empty. More formally, in julia-flavoured pseudocode,

```julia
while !isempty(stack)
    (a, b) = pop!(stack)
    A, B = rewrite(a, rws), rewrite(b, rws)
    if A ≠ B
        new_rule = Rule(A,B, ordering(rws))
        for rule in rules(rws)
            if isreducible(rule, new_rule)
                deactivate!(rule)
                push!(stack, rule)
            end
        end
        push!(rws, new_rule)
    end
end
```

Note that in `knuthbendix2` we can `break` (or `continue`) on the inactivity
of rules as specified in the listing above. Moreover those checks should be
repeated after every call to `forceconfluence!` as in the process the rule
being currently processed could have been marked as inactive (i.e. possibly
redundant).

```@docs
knuthbendix2
forceconfluence!(::RewritingSystem, stack, r₁, r₂, ::Workspace)
find_critical_pairs!(stack, rewritng, ::Rule, ::Rule, ::Workspace)
deriverule!(::RewritingSystem, stack, ::Workspace)
reduce!(::KBS2AlgPlain, ::RewritingSystem, work::Workspace)
```

!!! tip "Performance"
    While `knuthbendix2` vastly outperforms the
    [naive `knuthbendix1`](@ref Naive) it is still rather slow.
    There are two performance problems here which we will address next:
    1. the poor performance of [naive rewriting](@ref "Naive rewriting") that is
       still used by `knuthbendix2`: the complexity of this rewriting depends on
       the overall size of the rewriting system.
    2. the fact that `find_critical_pairs!` and `deriverules!`
       **assume and maintain the reducedness** of the rewriting system and we
       pay a hefty price for this.

To address both problems we will use the theory of Automata and regular languages.

[^Sims1994]: C.C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
