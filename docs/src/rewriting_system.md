# Rewriting System

It's just a struct that holds things together required for Knuth-Bendix
completion.

```@meta
CurrentModule = KnuthBendix
```

```@docs
RewritingSystem

rules(::RewritingSystem)
ordering(::RewritingSystem)
alphabet(::RewritingSystem)
isreduced
isconfluent
check_confluence
reduce!(::RewritingSystem)
isirreducible(::AbstractWord, ::RewritingSystem)
```
