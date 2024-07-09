```@meta
CurrentModule = KnuthBendix.Automata
```

# Interface

```@docs
Automaton
initial
hasedge
isfail
isterminal
trace

```

# Proving finiteness

```@docs
infiniteness_certificate
Base.isfinite(::Automaton)
irreducible_words
```
