# Non-commutative Gröbner bases

Here is a small example how this package can be useful outside of the realm of
the theory of finitely presented monoids. Finding a normal form for polynomial
algebras

```math
\mathbb{K}\langle x_1, \ldots, x_n\rangle\big/
(f_1(x_1,\ldots, x_n), \ldots, f_k(x_1, \ldots, x_n))
```

in non-commutative variables modulo certain polynomial equations is a standard
problem that can be solved via the computation the non-commutative Gröbner
basis. For an example of such approach see
[GAP package `gbnp`](https://gap-packages.github.io/gbnp/doc/chap0.html).
It is curious that the majority (but not all!) of the examples listed in
[Appendix A](https://gap-packages.github.io/gbnp/doc/chapA.html)
are generated by a set of equations which equate one monomial to some other,
i.e. all ``f_i(x_1, \ldots, x_n)`` are of the form ``m_1 = k\cdot m_2`` where
``m_i`` are simply monomials in variables ``x_1, \ldots, x_n`` and
``k \in \mathbb{K}``.

To compute normal forms in such (associative) algebras it is enough to rephrase
the problem as a problem of finding the normal form in **monoid algebra**,
with monoid generated by ``x_1, \ldots, x_n`` possibly extended by zero and a
finite set of units from ``\mathbb{K}``.

## Physics inspired example

The example is derived from a [description of relations](https://github.com/blegat/CondensedMatterSOS.jl/blob/19bf2ebc4923fffba1e9263022b836c429ea9c7d/src/types.jl#L107-L171)
between spin variables.
In short we have three sets of variables ``(\sigma^x)_i``, ``(\sigma^y)_i`` and ``(\sigma^z)_i`` for ``i \in \{1, \ldots, L\}``. These variables satisfy the following relations (here `\mathbf{i}` denotes the complex unit):

```math
\begin{aligned}
(\sigma^a)_i^2 & = 1 &i=1,\ldots,L,\; a\in \{x,y,z\},\\
(\sigma^x)_i (\sigma^y)_i &= \mathbf{i}(\sigma^z)_i & i=1,\ldots,L,\\
(\sigma^y)_i (\sigma^z)_i &= \mathbf{i}(\sigma^x)_i & i=1,\ldots,L,\\
(\sigma^z)_i (\sigma^x)_i &= \mathbf{i}(\sigma^y)_i & i=1,\ldots,L,\\
(\sigma^a)_i (\sigma^b)_j &= (\sigma^b)_j (\sigma^a)_i & 1 \leq i\neq j \leq L,\; a\in \{x,y,z\}.
\end{aligned}
```

Moreover we require anticommutativity of ``(\sigma^a)_i`` and ``(\sigma^b)_i``,
i.e. if ``(\sigma^a)_i (\sigma^b)_i = \mathbf{i}(\sigma^c)_i``, then
``(\sigma^b)_i (\sigma^a)_i = -\mathbf{i}(\sigma^c)_i``, but as we shall see,
this already follows from the the rules.

If we treat ``\mathbf{i}`` as an additional variable commuting with every
``(\sigma^a)_i``, then all of these rules equate one monomial to another and
the computation of the normal form is therefore suitable for Knuth-Bendix
completion!. Let's have a look how one could implement this.

```@meta
CurrentModule = KnuthBendix
DocTestSetup  = quote
    using KnuthBendix
end
```

### The alphabet

Let us begin with an alphabet:

```jldoctest spin_example
julia> L = 4
4

julia> subscript = ["₁", "₂","₃","₄","₅","₆","₇","₈","₉","₀"];

julia> Sσˣ = [Symbol(:σˣ, subscript[i]) for i in 1:L]
4-element Vector{Symbol}:
 :σˣ₁
 :σˣ₂
 :σˣ₃
 :σˣ₄

julia> Sσʸ = [Symbol(:σʸ, subscript[i]) for i in 1:L];

julia> Sσᶻ = [Symbol(:σᶻ, subscript[i]) for i in 1:L];

julia> SI = Symbol(:I); # the complex unit

julia> letters = [SI; Sσˣ; Sσʸ; Sσᶻ];

julia> A = Alphabet(letters, [0; 2:length(letters)])
Alphabet of Symbol
  1. I
  2. σˣ₁  (self-inverse)
  3. σˣ₂  (self-inverse)
  4. σˣ₃  (self-inverse)
  5. σˣ₄  (self-inverse)
  6. σʸ₁  (self-inverse)
  7. σʸ₂  (self-inverse)
  8. σʸ₃  (self-inverse)
  9. σʸ₄  (self-inverse)
 10. σᶻ₁  (self-inverse)
 11. σᶻ₂  (self-inverse)
 12. σᶻ₃  (self-inverse)
 13. σᶻ₄  (self-inverse)

```

Now let's define words with just those letters, so that we can use them as
generators in the free monoid over `A`:

```jldoctest spin_example
julia> I = Word([A[SI]])
Word{UInt16}: 1

julia> σˣ = [Word([A[s]]) for s in Sσˣ];

julia> σʸ = [Word([A[s]]) for s in Sσʸ];

julia> σᶻ = [Word([A[s]]) for s in Sσᶻ];

```

Note that `I` has no inverse among letters while all other are self-inverse.

### Rewriting System

Let us define our relations now

```jldoctest spin_example
julia> complex_unit = [I^4 => one(I)]
1-element Vector{Pair{Word{UInt16}, Word{UInt16}}}:
 1·1·1·1 => (id)

julia> Σ = [σˣ, σʸ, σᶻ];

julia> complex_unit = [I^4 => one(I)]
1-element Vector{Pair{Word{UInt16}, Word{UInt16}}}:
 1·1·1·1 => (id)

julia> # squares are taken care of by the inverses in the alphabet
       # squares = [a*a=>one(a) for a in [σˣ;σʸ;σᶻ]]
       cyclic = [
            σᵃ[i]*σᵇ[i] => I*σᶜ[i] for i in 1:L
                for (σᵃ, σᵇ, σᶜ) in (Σ, circshift(Σ,1), circshift(Σ,2))
            ]
12-element Vector{Pair{Word{UInt16}, Word{UInt16}}}:
  2·6 => 1·10
 10·2 => 1·6
 6·10 => 1·2
  3·7 => 1·11
 11·3 => 1·7
 7·11 => 1·3
  4·8 => 1·12
 12·4 => 1·8
 8·12 => 1·4
  5·9 => 1·13
 13·5 => 1·9
 9·13 => 1·5

julia> commutations = [
               σᵃ[i]*σᵇ[j] => σᵇ[j]*σᵃ[i] for σᵃ in Σ for σᵇ in Σ
               for i in 1:L for j in 1:L if i ≠ j
           ];

julia> append!(commutations,
        # I commutes with everything, since it comes from the field
            [σ[i]*I => I*σ[i] for σ in Σ for i in 1:L],
        )
120-element Vector{Pair{Word{UInt16}, Word{UInt16}}}:
  2·3 => 3·2
  2·4 => 4·2
  2·5 => 5·2
  3·2 => 2·3
  3·4 => 4·3
  3·5 => 5·3
  4·2 => 2·4
  4·3 => 3·4
  4·5 => 5·4
  5·2 => 2·5
      ⋮
  5·1 => 1·5
  6·1 => 1·6
  7·1 => 1·7
  8·1 => 1·8
  9·1 => 1·9
 10·1 => 1·10
 11·1 => 1·11
 12·1 => 1·12
 13·1 => 1·13

julia> rws = RewritingSystem([complex_unit; cyclic; commutations], LenLex(A));

julia> rwsC = knuthbendix(rws)
Rewriting System with 507 active rules ordered by LenLex: I < σˣ₁ < σˣ₂ < σˣ₃ < σˣ₄ < σʸ₁ < σʸ₂ < σʸ₃ < σʸ₄ < σᶻ₁ < σᶻ₂ < σᶻ₃ < σᶻ₄:
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                            σˣ₁^2 │ (id)                             │
│    2 │                            σˣ₂^2 │ (id)                             │
│    3 │                            σˣ₃^2 │ (id)                             │
│    4 │                            σˣ₄^2 │ (id)                             │
│    5 │                            σʸ₁^2 │ (id)                             │
│    6 │                            σʸ₂^2 │ (id)                             │
│    7 │                            σʸ₃^2 │ (id)                             │
│    8 │                            σʸ₄^2 │ (id)                             │
│    9 │                            σᶻ₁^2 │ (id)                             │
│   10 │                            σᶻ₂^2 │ (id)                             │
│   11 │                            σᶻ₃^2 │ (id)                             │
│   12 │                            σᶻ₄^2 │ (id)                             │
│   13 │                          σˣ₁*σʸ₁ │ I*σᶻ₁                            │
│  ⋮   │                ⋮                 │                ⋮                 │
└──────┴──────────────────────────────────┴──────────────────────────────────┘
                                                              494 rows omitted

```

Previously we stated that the anticommutativity should hold, i.e. if

```math
(\sigma^a)_i (\sigma^b)_i (\sigma^c)_i = \mathbf{i}\quad \text{then} \quad
(\sigma^b)_i (\sigma^a)_i (\sigma^c)_i = -\mathbf{i} = \mathbf{i}^3.
```

Let us check this now.

```jldoctest spin_example
julia> KnuthBendix.rewrite(σʸ[1]*σˣ[1], rwsC)
Word{UInt16}: 6·2

julia> KnuthBendix.rewrite(I^3*σᶻ[1], rwsC)
Word{UInt16}: 6·2

```

Indeed, rewriting brings both of the words to the same form, so they must
represent the same element in the monoid.

### Weighting the letters

If we want to force normalforms to begin with `I` (if a word with such
presentation represents the given monomial) we could use [`WeightedLex`](@ref)
ordering, weighting other letters disproportionally higher than `w`, e.g.

```jldoctest spin_example
julia> wLA = WeightedLex(A, weights = [1; [1000 for _ in 2:length(A)]])
WeightedLex: I(1) < σˣ₁(1000) < σˣ₂(1000) < σˣ₃(1000) < σˣ₄(1000) < σʸ₁(1000) < σʸ₂(1000) < σʸ₃(1000) < σʸ₄(1000) < σᶻ₁(1000) < σᶻ₂(1000) < σᶻ₃(1000) < σᶻ₄(1000)

julia> rws2 = RewritingSystem([complex_unit; cyclic; commutations], wLA);

julia> rwsC2 = knuthbendix(rws2)
Rewriting System with 263 active rules ordered by WeightedLex: I(1) < σˣ₁(1000) < σˣ₂(1000) < σˣ₃(1000) < σˣ₄(1000) < σʸ₁(1000) < σʸ₂(1000) < σʸ₃(1000) < σʸ₄(1000) < σᶻ₁(1000) < σᶻ₂(1000) < σᶻ₃(1000) < σᶻ₄(1000):
┌──────┬──────────────────────────────────┬──────────────────────────────────┐
│ Rule │                              lhs │ rhs                              │
├──────┼──────────────────────────────────┼──────────────────────────────────┤
│    1 │                            σˣ₁^2 │ (id)                             │
│    2 │                            σˣ₂^2 │ (id)                             │
│    3 │                            σˣ₃^2 │ (id)                             │
│    4 │                            σˣ₄^2 │ (id)                             │
│    5 │                            σʸ₁^2 │ (id)                             │
│    6 │                            σʸ₂^2 │ (id)                             │
│    7 │                            σʸ₃^2 │ (id)                             │
│    8 │                            σʸ₄^2 │ (id)                             │
│    9 │                            σᶻ₁^2 │ (id)                             │
│   10 │                            σᶻ₂^2 │ (id)                             │
│   11 │                            σᶻ₃^2 │ (id)                             │
│   12 │                            σᶻ₄^2 │ (id)                             │
│   13 │                          σˣ₁*σʸ₁ │ I*σᶻ₁                            │
│  ⋮   │                ⋮                 │                ⋮                 │
└──────┴──────────────────────────────────┴──────────────────────────────────┘
                                                              250 rows omitted


julia> KnuthBendix.rewrite(σʸ[1]*σˣ[1], rwsC2)
Word{UInt16}: 1·1·1·10

julia> KnuthBendix.print_repr(stdout, ans, A)
I^3*σᶻ₁

```