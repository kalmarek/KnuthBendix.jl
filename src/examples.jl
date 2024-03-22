module ExampleRWS

using KnuthBendix

"""
    ZxZ()
Rewriting system of the natural presentation of
> `ℤ² = ⟨ a, b | a·b = b·a ⟩`
ordered by [`LenLex`](@ref) order `a < a⁻¹ < b < b⁻¹`.
"""
function ZxZ()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'a', 'A')
    KnuthBendix.setinverse!(Al, 'b', 'B')
    a, A, b, B = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem(
        [(b * a, a * b)],
        LenLex(Al, order = ['a', 'A', 'b', 'B']),
    )

    return R
end

"""
    ZxZ_nonterminating()
Rewriting system of the natural presentation of
> `ℤ² = ⟨ a, b | a·b = b·a ⟩`
ordered by [`LenLex`](@ref) order `a < b < a⁻¹ < b⁻¹`.

Knuth-Bendix completion does not terminate on this system producing an infinite
set of rewriting rules of the form `a·bⁿ·a⁻¹ → bⁿ`.
"""
function ZxZ_nonterminating()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'a', 'A')
    KnuthBendix.setinverse!(Al, 'b', 'B')
    a, A, b, B = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem(
        [(b * a, a * b)],
        LenLex(Al, order = ['a', 'b', 'A', 'B']),
    )

    return R
end

"""
    triangle(l,n,m)
Rewriting system of the monoid presentation of `(l,n,m)`-triangle group
> `⟨ a, b | 1 = aˡ = bⁿ = (a·b)ᵐ⟩`
ordered by [`LenLex`](@ref) order `a < b`.
"""
function triangle(l, n, m)
    Al = Alphabet([:a, :b])

    a, b = Word.([i] for i in 1:length(Al))
    ε = one(a)

    eqns = [(a^l, ε), (b^n, ε), ((a * b)^m, ε)]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

triangle232() = triangle(2, 3, 2)
triangle233() = triangle(2, 3, 3)
triangle234() = triangle(2, 3, 4)
triangle235() = triangle(2, 3, 5)

"""
    Sims_Example_5_4()
Rewriting system of the `(2,3,3)`-triangle group presentation
> `⟨ a, b, B | 1 = aˡ = bⁿ = (a·b)ᵐ = b·B = B·b ⟩`
ordered by [`LenLex`](@ref) order `a < b < B`.
"""
function Sims_Example_5_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)

    R = RewritingSystem([(a^2, ε), (b^3, ε), ((a * b)^3, ε)], LenLex(Al))

    return R
end

"""
    Heisenberg()
Rewriting system of the group presentation of the Heisenberg group
> `⟨ a, b, c | 1 = [a,c] = [b,c], [a,b] = c ⟩
ordered by [`WreathOrder`](@ref) `a(6) < A(5) < b(4) < B(3) < c(2) < C(1)`.

Similar ordering which leads to the same confluent system is
[`Sims_Example_5_5`](@ref).
"""
function Heisenberg()
    alph = Alphabet([:a, :A, :b, :B, :c, :C])
    for (l, L) in ((:a, :A), (:b, :B), (:c, :C))
        KnuthBendix.setinverse!(alph, l, L)
    end
    a, A, b, B, c, C = [Word([i]) for i in 1:length(alph)]
    eqns = [(b * a, a * b * c), (c * a, a * c), (c * b, b * c)]
    ord = KnuthBendix.WreathOrder(alph, levels = [6, 5, 4, 3, 2, 1])

    return RewritingSystem(eqns, ord)
end

"""
    Sims_Example_5_5()
Rewriting system of the group presentation of the Heisenberg group
> `⟨ a, b, c | 1 = [a,c] = [b,c], [a,b] = c⟩`
ordered by [`WreathOrder`](@ref) `c(1) < C(1) < b(3) < B(3) < a(5) < A(5)`.
Similar to [`Heisenberg`](@ref).

This system is **Example 5.5**[^Sims1994], p. 74.
"""
function Sims_Example_5_5()
    Al = Alphabet([:a, :b, :c, :A, :B, :C])
    KnuthBendix.setinverse!(Al, :c, :C)
    KnuthBendix.setinverse!(Al, :b, :B)
    KnuthBendix.setinverse!(Al, :a, :A)

    a, b, c, A, B, C = [Word([i]) for i in 1:6]
    ε = one(a)

    eqns = [(c * a, a * c), (c * b, b * c), (b * a, a * b * c)]

    R = RewritingSystem(
        eqns,
        WreathOrder(
            Al,
            levels = [5, 3, 1, 5, 3, 1],
            order = [:c, :C, :b, :B, :a, :A],
        ),
    )
    return R
end

"""
    Sims_Example_5_5_recursive()
Rewriting system of the group presentation of the Heisenberg group
> `⟨ a, b, c | 1 = [a,c] = [b,c], [a,b] = c⟩`
ordered by [`Recursive` ordering](@ref) `c < C < b < B < a < A`.

Same as [`Heisenberg`](@ref).
"""
function Sims_Example_5_5_recursive()
    Al = Alphabet([:a, :b, :c, :A, :B, :C])
    KnuthBendix.setinverse!(Al, :c, :C)
    KnuthBendix.setinverse!(Al, :b, :B)
    KnuthBendix.setinverse!(Al, :a, :A)

    a, b, c, A, B, C = [Word([i]) for i in 1:6]
    ε = one(a)

    eqns = [(c * a, a * c), (c * b, b * c), (b * a, a * b * c)]

    R = RewritingSystem(
        eqns,
        Recursive{KnuthBendix.Left}(Al, order = [:c, :C, :b, :B, :a, :A]),
    )
    return R
end

"""
    triangle_237_quotient(n)
Rewriting system of the presentation of
> `⟨ a, b, B | 1 = a² = b·B = B·B = b³ = (a·b)⁷ = (a·b·a·B)ⁿ ⟩`
ordered by [`LenLex`](@ref) `a < b < B`. The presentation defines a quotient of
`(2,3,7)`-triangle group by `n`-th power of the commutator `[a,b]`.
"""
function triangle_237_quotient(n::Integer)
    Al = Alphabet([:a, :b, :B])
    KnuthBendix.setinverse!(Al, :b, :B)

    a, b = Word.([i] for i in 1:length(Al))
    ε = one(a)
    eqns = [(a * a, ε), (b^3, ε), ((a * b)^7, ε), ((a * b * a * b^2)^n, ε)]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

"""
    Hurwitz4()
Rewriting system of the presentation of
[Hurwitz group](https://en.wikipedia.org/wiki/Hurwitz%27s_automorphisms_theorem)
[`triangle_237_quotient(4)`](@ref triangle_237_quotient).

`Hurwitz4` is finite of order `168`.
"""
Hurwitz4() = triangle_237_quotient(4)

"""
    Hurwitz8()
Rewriting system of the presentation of
[Hurwitz group](https://en.wikipedia.org/wiki/Hurwitz%27s_automorphisms_theorem)
[`quotient_237(8)`](@ref quotient_237).

`Hurwitz8` is finite of order `10752`.
"""
Hurwitz8() = triangle_237_quotient(8)

__subscript(i) = join('₀' + d for d in reverse(digits(i)))
"""
    π₁Surface_recursive(n)
Rewriting system of the group presentation of `π₁(Σₙ)`, the fundamental group of
orientable surface of genus `n`:
> `⟨ aᵢ, Aᵢ, bᵢ, Bᵢ | 1 = Πᵢ[aᵢ, bᵢ] ⟩`
ordered by [`Left-Recursive`](@ref Recursive) ordering
`Bₙ < bₙ < Aₙ < aₙ < ... < B₁ < b₁ < A₁ < a₁`.

This terminating system was discovered by S.M.Hermiller[^Hermiller1994].

[^Hermiller1994]: Susan M. Hermiller Rewriting systems for Coxeter groups
                  _Journal of Pure and Applied Algebra_, Volume 92, Issue 2,
                  1994, p. 137-148.
"""
function π₁Surface_recursive(genus)
    Al = let genus = genus, ltrs = Symbol[]
        l(a, i) = Symbol(a, i)

        for i in 1:genus
            ss = __subscript(i)
            append!(ltrs, [l(:a, ss), l(:A, ss), l(:b, ss), l(:B, ss)])
        end
        Al = Alphabet(ltrs)
        for i in 1:genus
            ss = __subscript(i)
            KnuthBendix.setinverse!(Al, l(:a, ss), l(:A, ss))
            KnuthBendix.setinverse!(Al, l(:b, ss), l(:B, ss))
        end
        Al
    end

    ord = Recursive(Al, order = reverse(collect(Al)))

    relator = one(Word{UInt16})
    for i in reverse(1:genus)
        x = 4 * i
        append!(relator, [x, x - 2, x - 1, x - 3])
    end
    R = RewritingSystem([(relator, one(relator))], ord)

    return R
end

"""
    π₁Surface(n)
Rewriting system of the group presentation of `π₁(Σₙ)`, the fundamental group of
orientable surface of genus `n`:
> `⟨ aᵢ, Aᵢ, bᵢ, Bᵢ | 1 = Πᵢ[aᵢ, bᵢ] ⟩`
ordered by [`LenLex`](@ref) ordering
`a₁ < A₁ < a₂ < A₂ < ⋯ < aₙ < Aₙ < b₁ < B₁ < b₂ < B₂ < ⋯ < b₃ < B₃`.
"""
function π₁Surface(genus)
    @assert genus ≥ 0
    Al = let genus = genus, letters = Symbol[]
        l(a, i) = Symbol(a, __subscript(i))
        for i in 1:genus
            push!(letters, l(:a, i), l(:A, i))
        end
        for i in 1:genus
            push!(letters, l(:b, i), l(:B, i))
        end
        inverses = vcat([[i + 1, i] for i in 1:2:length(letters)]...)
        Alphabet(letters, inverses)
    end

    S = [Word([i]) for i in 1:length(Al)]
    as, bs = S[begin:2:length(S)÷2], S[length(S)÷2+1:2:end]
    __commutator(a, b, Al) = inv(a, Al) * inv(b, Al) * a * b

    relator = prod(__commutator(a, b, Al) for (a, b) in zip(as, bs))

    relations = [
        (relator[begin:i], inv(relator[i+1:end], Al)) for
        i in 0:length(relator)-1
    ]

    return RewritingSystem(relations, LenLex(Al))
end
"""
    Coxeter_cube()
Rewriting system of the group presentation of the Coxeter group associated to cube graph.

This terminating system and its [`WeightedLex`](@ref) ordering was discovered
by S.M.Hermiller[^Hermiller1994].

[^Hermiller1994]: Susan M. Hermiller Rewriting systems for Coxeter groups
                  _Journal of Pure and Applied Algebra_, Volume 92, Issue 2,
                  1994, p. 137-148.
"""
function Coxeter_cube()
    _coxeter_letter(simplex) = Symbol("s", join(simplex, ""))

    function coxeter_alphabet(itr)
        letters = [_coxeter_letter(v) for v in itr]
        inverses = 1:length(letters) # generators are of order 2 i.e. self-inverse
        return KnuthBendix.Alphabet(letters, inverses)
    end

    vertices = [[i] for i in 1:8]
    edges = [
        [1, 2],
        [1, 3],
        [1, 5],
        [2, 4],
        [2, 6],
        [3, 5],
        [3, 7],
        [4, 8],
        [5, 6],
        [5, 7],
        [6, 8],
        [7, 8],
    ] # 3-cube

    A = coxeter_alphabet([edges; vertices])
    weights = [fill(2, length(edges)); fill(1, length(vertices))]
    wtlex = WeightedLex(A, weights = weights)

    S = Dict(v => Word([A[_coxeter_letter(v)]]) for v in vertices)
    for σ in edges
        S[σ] = Word([A[_coxeter_letter(σ)]])
    end

    rels = map(edges) do e
        v1, v2 = [first(e)], [last(e)]
        s1, s2, s12 = S[v1], S[v2], S[e]
        return [ # (1)(2) → (12), (2)(1) → (12)
            (s1 * s2, s12),
            (s2 * s1, s12),
            #(1)(12) → (2)   (2)(12) → (1)   (12)(1) → (2)   (12)(2) → (1)
            (s1 * s12, s2),
            (s2 * s12, s1),
            (s12 * s1, s2),
            (s12 * s2, s1),
        ]
    end

    rels2 = eltype(eltype(rels))[]
    for e in edges
        for f in edges
            if length(intersect(e, f)) == 1
                edge = union(setdiff(e, f), setdiff(f, e))
                @assert length(edge) == 2
                haskey(S, edge) || reverse!(edge)
                if haskey(S, edge)
                    # (12)(13) → (23)
                    push!(rels2, (S[e] * S[f], S[edge]))
                end
            end
        end
    end
    push!(rels, rels2)

    return RewritingSystem(vcat(rels...), wtlex)
end

"""
    Baumslag_Solitar(m,n)
Rewriting system of the group presentation of the
[Baumslag-Solitar group](https://en.wikipedia.org/wiki/Baumslag–Solitar_group)
> `⟨ x,y | y·xⁿ·y⁻¹ = xᵐ ⟩`
ordered by [`WreathOrder`](@ref) `x(1) < X(2) < y(3) < Y(4)`.
"""
function Baumslag_Solitar(m, n)
    ltrs = [:x, :X, :y, :Y]
    Al = Alphabet(ltrs, [2, 1, 4, 3])

    x, X, y, Y = [Word([Al[l]]) for l in ltrs]

    R = RewritingSystem(
        [(y * x^n * Y, x^m)],
        WreathOrder(Al, levels = [1, 2, 3, 4]),
    )

    return R
end

function __F2_alphabet_rels(n)
    alph = Alphabet([Symbol('a', i) for i in 1:n])
    a = [Word([i]) for i in 1:length(alph)]
    rels = [(a[mod1(i, n)] * a[mod1(i + 1, n)], a[mod1(i + 2, n)]) for i in 1:n]

    return alph, rels
end
"""
    Fibonacci2(n)
Rewriting system corresponding to monoid presentation of the
[Fibonacci group](https://en.wikipedia.org/wiki/Fibonacci_group) `F(2,n)`
> `⟨ a₁, …, aₙ | a₁·a₂ = a₃, a₂·a₃ = a₄, …, aₙ₋₁·aₙ = a₁, aₙ·a₁ = a₂⟩`
ordered by [`LenLex`](@ref) ordering `a₁ < a₂ < … < aₙ`.

`F(2,n)` groups are finite for `n = 2,3,4,5,7` and infinite for other `n`s.
"""
function Fibonacci2(n)
    Al, rels = __F2_alphabet_rels(n)
    return RewritingSystem(rels, LenLex(Al))
end

"""
    Fibonacci2_recursive(n)
Rewriting system corresponding to monoid presentation of the
[Fibonacci group](https://en.wikipedia.org/wiki/Fibonacci_group) `F(2,n)`
> `⟨ a₁, …, aₙ | a₁·a₂ = a₃, a₂·a₃ = a₄, …, aₙ₋₁·aₙ = a₁, aₙ·a₁ = a₂⟩`
ordered by [`Recursive`](@ref) ordering `a₁ < a₂ < … < aₙ`.

See [`Fibonacci2`](@ref).
"""
function Fibonacci2_recursive(n)
    Al, rels = __F2_alphabet_rels(n)
    return RewritingSystem(rels, Recursive(Al))
end

end
