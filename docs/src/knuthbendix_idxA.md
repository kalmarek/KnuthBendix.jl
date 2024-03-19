# Using index automaton

```@meta
CurrentModule = KnuthBendix
```

Major speedups in rewriting can be obtained by using a specialized data
structure for rewriting system. The structure is known in the contex[^Sims1994]
of Knuth-Bendix completion as an index automaton, but a more widely name for
the automaton is the Aho-Corasik automaton[^Aho1975].
This automaton provides an optimal complexity for string searching in a corpus,
namely, once the automaton is built, the searching for the left hand sides of
the rules (and hence rewriting) takes `Ω(length(w))` where `w` is the word being
rewritten. Thus we can obtain rewrites in time independent of the size of the
rewriting system.

To learn more about fast rewriting using the automaton see
[Index automaton rewriting](@ref "Index automaton").

```@docs
KBIndex
```

You can run it on a `rws` by calling
```julia
knuthbendix(KnuthBendix.KBIndex(), rws)
```

!!! tip "Performance"
    The 8th quotient of 2-3-7 vanDyck group from
    [Knuth-Bendix completion using a stack](@ref "Using a stack") poses no
    challenges to `KBIndex` which solves it in a fraction of second.
    The performance bottleneck for larger examples is the incorporation of the
    stack of newly found rules into the rewriting system, while maintaining its
    reducedness (the construction of the index automaton, but more importantly,
    the confluence check require a reduced rewriting system).

By default the size of the stack is `200` rules and  the algorithm terminates
early after `5_000` of rewriting rules have been found.
To control this behaviour pass explicit [`Settings`](@ref) to `knuthbendix`
call as the last argument.

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
            # reduce the rws and then rebuild idxA
            rws, ... = reduce!(rws, stack)
            idxA, ... = Automata.rebuild!(idxA, rws)
        end
        ...
    end
    return rws
end
```

The main difference in the procedure is that instead immediately forcing
reducedness with every discovered rule we delay this check until `stack` is
bigger than a user provided `MAX_STACK`. Only then
1. we invoke [`KnuthBendix.reduce!`](@ref ) which
   * uses [`deriverule!`](@ref deriverule!(::RewritingSystem, stack)) to push
     all critical pairs from `stack` to `rws` while maintaining its reducedness,
   * removes inactive rules from `rws`,
2. we re-sync the index automaton `idxA` with `rws`.

This allows to amortize the time needed for reduction of `rws` (dominating!)
and the construction of `idxA` (rather cheap, in comparison) across many
different pairs of rules `(ri, rj)`.

## Backtrack search and the test for (local) confluence

Another very important feature of `IndexAutomaton` is that it allows us to test
cheaply for confluence. Naively we need to check all pairs of rules for their
suffix-prefix intersections and resolve the potentially critical pairs. However
if we have an `idxA::IndexAutomaton` at our disposal checking for confluence
becomes much easier: given a rule `lhs → rhs` from our rewriting system we need
to see how can we extend `lhs[2:end]` to a word `w` which ends with the
left-hand-side `lhs'` of some other rule.

Here we don't need to search for all possible completions, since if `w` can be
written as `w = lhs[2:end]*X*lhs'`, then it satisfies local confluence w.r.t.
the rewrites with the given rules trivially. If you think about index automaton
as a tree with some (a plenty of) additional "shortcut" edges, then the answer
is right in front of you: for every `lhs` we need to perform a
single **backtrack** search on `idxA`. The search starts at the last state of
`trace(idxA, lhs[2:end])`. We then backtrack

* when the depth of search becomes too large i.e. equal to
  `lenght(lhs[2:end])`, or
* when the edge lead us to a vertex closer to the origin than we were (i.e.
  we took a shortcut).

As it turns out these conditions can be combined together to say that

* we backtrack whenever the distance of the current state to the origin is
shorter than the length of the history tape.

This mechanism is implemented by
[`Automata.ConfluenceOracle`](@ref "Automata.ConfluenceOracle"),
see [Backtrack searches](@ref "Backtrack searches").

----

With this, instead of examining `k²` pairs for all possible suffix-prefix
intersections it is enouth to perform `k` backtrack searches (where `k` is the
number of rules of our `rws`). In pseudocode

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
