```@meta
CurrentModule = KnuthBendix.Automata
```

# Interface

```@docs
Automaton
initial
hasedge
isfail
isaccepting
trace

```

# Proving finiteness

```@docs
infiniteness_certificate
Base.isfinite(::Automaton)
irreducible_words
```
