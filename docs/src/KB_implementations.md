# Implementations of Knuth-Bendix completion

## In `KnuthBendix.jl`

There are currently four implementations available:
1. `KBPlain` which follows [the naive version](@ref "Naive"),
2. `KBStack` which [uses stack](@ref "Using a stack") and rule
   deactivation to maintain reducedness.
3. `KBS2AlgRuleDel` - a modification of `KBStack` which frequently deletes
   the rules which are deemed redundant.
4. `KBIndex` - a modification of `KBSStack` which [uses
   `IndexAutomaton`](@ref "Using index automaton") to obtain optimal complexity
   of rewriting.

In general all of those methods dispatch through common interface:

```@meta
CurrentModule = KnuthBendix
```

```@docs
knuthbendix
```

## Knuth-Bendix on Monoids and Automatic Groups (`kbmag`)

The baseline `C`-implementation of the Knuth-Bendix completion (and much more!)
used by the [GAP System](https://www.gap-system.org/).
See [`kbmag` source code](https://github.com/gap-packages/kbmag) and the
documentation of the
[GAP interface](https://gap-packages.github.io/kbmag/doc/chap0_mj.html).

Much wider functionality (automatic structures, etc.) and way more tuning
options. In maintainance mode since ca. 1996.

## Monoid Automata Factory (`maf`)

Somehow more advanced and modern `C++`-implementation of similar functionality
to `kbmag` (it even has `kbmag` interface!).
According to their docs

> MAF succeeds on many examples where KBMAG either fails, or requires a very
> careful selection of options to succeed. In particular, MAF will usually work
> better with recursive orderings.

See package
[documentation](https://maffsa.sourceforge.net/) and its
[source code](https://sourceforge.net/p/maffsa/code/HEAD/tree/).
Not actively developed since 2011.
