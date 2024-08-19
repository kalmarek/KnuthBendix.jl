# Using prefix automaton

```@meta
CurrentModule = KnuthBendix
```

To balance the cost of maintaining the reduced rewriting system with the cost of
rewrites `KBPrefix` completion algorithm employs [`PrefixAutomaton`](@ref) for
both purposes. There are two major advantages of using the automaton:
 * `PrefixAutomaton` can be created from a non-reduced rewriting system;
 * the `KBPrefix` [reduction](@ref Reduction) is an iterative process which can be interrupted __before__ a fully reduced system is found;

Unfortunately [rewrites with `PrefixAutomaton`](@ref "Prefix automaton rewriting") are considerably slower than the ones using `IndexAutomaton`.

```@docs
KBPrefix
```

You can run it on a `rws` by calling
```julia
knuthbendix(KnuthBendix.Settings(KnuthBendix.KBPrefix()), rws)
```
The default [`Settings`](@ref) are as follows
```@repl
using KnuthBendix; # hide
KnuthBendix.Settings(KnuthBendix.KBPrefix())
```
You may alter the default parameters you may pass any number of keywords to the constructor.

## Reduction

Reduction of a rewriting system using `PrefixAutomaton` in julia-flavoured pseudocode looks as follows.

```julia
function reduce!(::KBPrefix, rws::RewritingSystem; kwargs...)
    while true
        pfxA = PrefixAutomaton(rws)
        redundant = 0
        altered = 0
        for rule in rules(rws)
            lhs, rhs = rule
            lhs_r = rewrite(lhs, pfxA, skipping=rule)
            rhs_r = rewrite(rhs, pfxA)
            lhs_r == lhs && rhs_r == rhs && continue # rule is reduced
            if lhs_r == rhs_r
                # rule is redundant
                redundant += 1
                deactivate!(rule)
            else # either lhs_r ≠ lhs or rhs_r ≠ rhs
                # rule is not reduced but it still carries some information
                # which does not follow from other rwrules
                altered += 1
                lhs_r, rhs_r = simplify!(lhs_r, rhs_r, ordering(rws))
                Words.store!(rule, lhs_r=>rhs_r)
            end
        end
        altered == 0 && redundant == 0 && break # rws is reduced now
        # some early breaking conditions based on kwargs may be placed here
    end
    remove_inactive!(rws) # clean up the rewriting system
    return rws
end
```
A single pass of the reduction looks as follow.
We iterate over the rules of the rewriting system checking for one of the three
possibilities.
* Rule is reduced w.r.t. the remaining rewriting system. This happens when
   the only way to rewrite the rules' left hand side is to apply the rule to itself.
* Rule is redundant w.r.t. the remaining rewriting system. This happens when
   the rule follows from the remaining rewriting rules, i.e. rewriting both
   sides of the rule (without applying the rule itself) leads to the same word.
* The rule is neither reduced nor redundant. This happens when either of the
   sides of the rule can be rewritten w.r.t. the remaining rewriting system, but
   the results are different.

When the rule is reduced we keep it, when it is redundant we mark it as
inactive and in the third case we alter the rule accordingly.
The rewriting system is reduced when a fixed point (i.e. a set of rewriting
rules which does not change) is reached.

Since `PrefixAutomaton` can be constructed from a non-reduced rewriting system
there is no need to actually reach the fixed point! During `KBPrefix` completion
the only place where a fully reduced rewriting system is needed is the
early confluence check based on `IndexAutomaton`. Thus usually we can perform
an early break of the reduction `while` loop e.g. after a certain number of
passes or when the rewriting system did not change too much in the last pass.
Even if a redundant rule survives the partial reduction this time, it will be sweeped away when partial reduction is run again.

This sometimes allows for great speed-ups in discovering new rules at the cost
of operating non-reduced (hence larger) rewriting system.
