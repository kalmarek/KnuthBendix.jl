# Using index automaton

Now we will obtain major speedups in rewriting by using a special data
structure to keep our rewriting system. The structure is known as an index
automaton in this context[^Sims1994], but a more widely name for the automaton
is the Aho-Corasik automaton[^Aho1975]. This automaton provides an optimal
complexity for string searching in a corpus, namely, once the automaton is
built, the rewriting takes `Ω(m)` where `m` is the length of the word to be
rewritten. Thus we can obtain rewrites independent of the size of the rewriting
system.

This version of Knuth-Bendix completion is uses
[Index automaton rewriting](@ref "Index automaton") for fast rewrites.

----

Keeping the construction of the automaton as a black box, below is a
julia-flavoured pseudocode describing the completion procedure.

```julia
function knuthbendix2automaton(rws::RewritingSystem{W}, MAX_STACK, ...) where W
    stack = Vector{Tuple{W,W}}()
    rws = reduce(rws)  # this is assumed by IndexAutomaton!
    idxA = Automata.IndexAutomaton(rws)

    # ... initialize more temporary structures here
    for ri in rules(rws)
        for rj in rules(rws)
            isactive(ri) || break
            find_critical_pairs!(stack, idxA, ri, rj, ...)
            ri === rj && break
            isactive(ri) || break
            isactive(rj) || continue
            find_critical_pairs!(stack, idxA, rj, ri, ...)
        end
        if lenght(stack) > MAX_STACK || ri == last(rules(rws))
            rws, idxA, ... = Automata.rebuild!(idxA, rws, stack, ...)
            # rebuild! reduces rws and rebuilds idxA on top
        end
        ...
    end
    return rws
end
```

```@meta
CurrentModule = KnuthBendix
```


The main difference in the procedure is that instead immediately forcing
reducedness with every discovered rule we delay this check until `stack` is
bigger than a user provided `MAX_STACK`. Only then is the
[`Automata.rebuild!`](@ref ) invoked which

1. uses [`deriverule!`](@ref deriverule!(::RewritingSystem, stack)) to push
    all critical pairs from `stack` to `rws` while maintaining its reducedness,
2. removes inactive rules from `rws`,
3. rebuilds `idxA` the index automaton for `rws`.

This allows to amortize the time needed for reduction of `rws` (dominating!)
and the construction of `idxA` (rather cheap, in comparison) across many
different pairs of rules `(ri, rj)`.

```@doc
knuthbendix!(::KBS2AlgIndexAut, args...)
Automata.rebuild!
```

## On index automaton

### Backtrack search and test for confluence

Another very important feature of `IndexAutomaton` is that it allows us to test
cheaply for confluence. Normally we need to check all pairs of rules for their
suffix-prefix intersections and resolve the potentially critical pairs. However
if we have an `idxA::IndexAutomaton` at hand checking for confluence becomes
much easier: given a rule `lhs → rhs` from our rewriting system we need to see
how can we extend `lhs[2:end]` to a word `w` which ends with the left-hand-side
`lhs'` of some other rule. We need to be careful though that the length of `w`
is not too large (otherwise `w = lhs[2:end]*X*lhs'` and we don't get our
candidate for the failure of local confluence).
If you think about index automaton as a tree with some (plenty of) additional
edges, then the answer is right there: for every `lhs` we need to perform a
single **backtrack** search on `idxA`. Where do we start? At the last state of
`trace(idxA, lhs[2:end])`. When do we backtrack?

* when the depth of search becomes too large i.e. equal to
  `lenght(lhs[2:end])`, or
* when the edge lead us to a vertex closer to the origin than we were (i.e.
  we took the skew-edge).

As it turns out these conditions can be combined together to say that

* we backtrack whenever the distance of the current state to the origin is
shorter than the length of the history tape.

This mechanism is implemented in [`Automata.BacktrackSearch`](@ref).

----

With this, instead of examining `k²` pairs for suffix-prefix intersections
it is enouth to perform `k` backtrack searches (where `k` is the number of
rules of our `rws`). In pseudocode

```julia
function check_confluence(rws::RewritingSystem{W}, idxA::IndexAutomaton) where W
    stack = Vector{Tupe{W,W}}()
    backtrack = Automata.BacktrackSearch(idxA)

    # ... initialize some temporary structures here
    for ri in rules(rws)
        stack = find_critical_pairs!(stack, backtrack, ri, ...)
        !isempty(stack) && break
        # i.e. we found some honest failures to local confluence
    end
    return stack
end
```

If you inspect the actual code, you will be surprised how close it is to the
listing above.

```@docs
find_critical_pairs!(stack, ::Automata.BacktrackSearch, ::Rule, ::Workspace)
```

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
[^Aho1975]: Alfred V. Aho and Margaret J. Corasick _Efficient string matching: an aid to bibliographic search_ Commun. ACM 18, 6 (June 1975), 333–340. [doi:10.1145/360825.360855](https://doi.org/10.1145/360825.360855)
