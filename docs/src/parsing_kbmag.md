```@meta
CurrentModule = KnuthBendix
DocTestSetup  = quote
    using KnuthBendix
end
```

`KnuthBendix.jl` provides a very simple parsing of the `kbmag` input files.
To replicate e.g.
[Example 1](https://gap-packages.github.io/kbmag/doc/chap2_mj.html#X8388E29680F31ABD)
from GAP documentation you can run

```jldoctest
julia> example1_str = """rec(
              isRWS := true,
         generatorOrder := [_g1,_g2,_g3],
           inverses := [_g1,_g3,_g2],
           ordering := "shortlex",
          equations := [
            [_g2^2,_g3],
            [_g1*_g2*_g1,_g3*_g1*_g3]
          ]
       )""";

julia> kbrws = KnuthBendix.parse_kbmag(example1_str)
rec(
           isRWS := true,
  generatorOrder := [_g1,_g2,_g3],
        inverses := [_g1,_g3,_g2],
        ordering := "shortlex",
       equations := [
    [_g2*_g2, _g3],
    [_g1*_g2*_g1, _g3*_g1*_g3]
  ]
)

julia> rws = RewritingSystem(kbrws)
Rewriting System with 5 active rules ordered by LenLex: _g1 < _g2 < _g3:
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                            _g1^2 │ (id)                             │
│    2 │                          _g2*_g3 │ (id)                             │
│    3 │                          _g3*_g2 │ (id)                             │
│    4 │                            _g2^2 │ _g3                              │
│    5 │                      _g3*_g1*_g3 │ _g1*_g2*_g1                      │
└──────┴──────────────────────────────────┴──────────────────────────────────┘


julia> knuthbendix(rws)
Rewriting System with 11 active rules ordered by LenLex: _g1 < _g2 < _g3:
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                            _g1^2 │ (id)                             │
│    2 │                          _g2*_g3 │ (id)                             │
│    3 │                          _g3*_g2 │ (id)                             │
│    4 │                            _g2^2 │ _g3                              │
│    5 │                      _g3*_g1*_g3 │ _g1*_g2*_g1                      │
│    6 │                            _g3^2 │ _g2                              │
│    7 │                  _g1*_g2*_g1*_g3 │ _g3*_g1*_g2                      │
│    8 │                  _g3*_g1*_g2*_g1 │ _g2*_g1*_g3                      │
│    9 │                      _g2*_g1*_g2 │ _g1*_g3*_g1                      │
│   10 │                  _g2*_g1*_g3*_g1 │ _g3*_g1*_g2                      │
│   11 │                  _g1*_g3*_g1*_g2 │ _g2*_g1*_g3                      │
└──────┴──────────────────────────────────┴──────────────────────────────────┘


```
