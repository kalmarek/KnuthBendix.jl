# Using a stack

```@meta
CurrentModule = KnuthBendix
```

As can be observed in [Knuth Bendix completion - an example](@ref) after we
have added rule 6, there was no point considering rule 5, since it was
rendered redundant. This can be achieved by maintaining the reducedness property
of the rewriting system during the completion.

```@docs
KBStack
```

You can run it on a `rws` by calling
```julia
knuthbendix(KnuthBendix.KBStack(), rws)
```

By default the algorithm terminates early after `500` of __active__ rewriting
rules have been found.
To control this behaviour pass explicit [`Settings`](@ref) to `knuthbendix`
call as the last argument.

!!! tip "Performance"
    While `KBStack` vastly outperforms the
    [naive `KBPlain`](@ref Naive) it is still rather slow.
    E.g. the eight quotient of (2,3,7) triangle group

    $$\langle a,b \mid a^2 = b^3 = (ab)^7 = \left(a^{-1}b^{-1}ab\right)^8 \rangle.$$

    which has a confluent rewriting system with `1023` rules is still too large
    to be completed succesfully.

    There are two main performance problems here:
    1. the poor performance of [naive rewriting](@ref "Naive rewriting") that is
       still used by `KBStack`: the complexity of this rewriting depends on
       the overall size of the rewriting system.
    2. the fact that `find_critical_pairs!` and `deriverules!`
       **assume and maintain the reducedness** of the rewriting system makes
       their complexity quadratic with the size of the rewriting system and
       therefore become the bottleneck for larger rewriting systems.

    To address both problems we will use the theory of Automata and regular languages in [`KBIndex`](@ref).

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

Not much has changed compared to `KBPlain` on the surface, but there are
more substantial changes under the hood. In particular
[`forceconfluence!`](@ref
forceconfluence!(::RewritingSystem, ::Any, ::Any, ::Any, ::Workspace))
has become simply

```julia
function forceconfluence!(rws::RewritingSystem, stack, ri, rj, ...)
    find_critical_pairs!(stack, rws, ri, rj, ...)
    deriverules!(rws, stack, ...)
    return rws
end
```

I.e. we first push all failures to local confluence derived from `ri` and `rj`
onto `stack` ([`find_critical_pairs!`](@ref
find_critical_pairs!(::Any, ::Any, ::Rule, ::Rule, ::Workspace))), then
empty the stack ([`deriverule!`](@ref deriverule!(::RewritingSystem, stack))).
To do this the top pair `lhs → rhs` is picked from the stack, we mark all
the rules in `rws` that could be reduced with `lhs` as inactive and push them
onto the stack. Only afterwards we push `lhs → rhs` to `rws` and we repeat
until the stack is empty. More concretely, in julia-flavoured pseudocode,

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

Note that in `KBStack` we can `break` (or `continue`) in the internal
loop on the inactivity of rules as specified in the listing above.
As in the process of completion the rule `ri` being currently processed
could have been marked as inactive (e.g. it became redundant)
it is advisable that those checks are performed after every call to
`forceconfluence!`.

## Internal functions

```@docs
forceconfluence!(::RewritingSystem, stack, r₁, r₂, ::Workspace)
find_critical_pairs!(stack, rewritng, ::Rule, ::Rule, ::Workspace)
deriverule!(::RewritingSystem, stack, ::Workspace)
reduce!(::KBStack, ::RewritingSystem, work::Workspace)
```
