"""
    WreathOrder{T,S} <: RewritingOrdering
    WreathOrder(A::Alphabet; levels[, order=collect(A)])

Compare words first by their levels, then break ties by recursion on prefixes.

The `levels` vector assigns levels to each letter __as they appear in the alphabet__
and the `level` of a word is the maximum of levels of all its letters.

The order compare words first by their levels, then break ties by `LenLex`
order of pure max-level words. Further ties are resolved by recursing on lower
level prefixes.

# Definition
Let `U = U₀·a₁·U₁·…·aᵣ·Uᵣ` be a decomposition of `U` such that
* all `aᵢ`s are at the same (maximal) level and
* each `Uᵢ` is at level strictly smaller.

Let `V = V₀·b₁·V₁·…·bₛ·Vₛ` be a similar decomposition. Then `U <≀ V` if either

* `a₁·…·aᵣ < b₁·…·bₛ` according to `LenLex` order, or
* `a₁·…·aᵣ = b₁·…·bₛ` and `U₀ <≀ V₀`, or `Uᵢ = Vᵢ` for `0≤i<k` but `Uₖ <≀ Vₖ`.

For more references see
> 1. C. Sims _Computation with finitely presented groups_, p. 46-47
> 2. D. Holt, B. Eick and E. O’Brien _Handbook of Computational Group Theory_,
>    Section 12.4 Rewriting systems for polycyclic groups, p. 426-427
> 3. S. Rees _Automatic groups associated with word orders other than shortlex_
>    Section 5.3 Wreath product orders.

# Example
```jldoctest
julia> X = Alphabet([:a, :b]);

julia> a, b = Word([1]), Word([2]);

julia> wro = WreathOrder(X, levels = [1, 2])
WreathOrder: a(1) < b(2)

julia> lt(wro, a^100, a * b * a^2) # by level only
true

julia> lt(wro, b^2*a, a^2 * b * a) # by max-level word
false

julia> lt(wro, a * b * a^2, a^2 * b * a) # by the lower level prefix
true
```
"""
struct WreathOrder{T,S} <: RewritingOrdering
    A::Alphabet{T}
    levels::Vector{S}
    letter_order::Vector{Int}
end

function WreathOrder(
    A::Alphabet{T};
    levels::AbstractVector{S},
    order::AbstractVector{T} = collect(A),
) where {T,S}
    @assert length(A) == length(levels) == length(order)
    @assert Set(order) == Set(A)
    @assert all(>=(zero(S)), levels)
    letter_order = sortperm([A[l] for l in order])
    return WreathOrder(A, levels, letter_order)
end

alphabet(o::WreathOrder) = o.A

level(o::WreathOrder, letter::Integer) = o.levels[letter]

function level(o::WreathOrder, p::AbstractWord)
    λ = 0
    for letter in p
        λ = max(λ, level(o, letter))
    end
    return λ
end

function lt(o::WreathOrder, lp::Integer, lq::Integer)
    return o.letter_order[lp] < o.letter_order[lq]
end

function lt(o::WreathOrder, p::AbstractWord, q::AbstractWord)
    iprefix = Words.lcp(p, q)
    @views u = p[iprefix+1:end]
    @views v = q[iprefix+1:end]

    return _lt_nocommonprefix(o::WreathOrder, u, v)
end

@inline function _lt_nocommonprefix(
    o::WreathOrder,
    u::AbstractWord,
    v::AbstractWord,
)
    λ = level(o, u)
    λv = level(o, v)
    # @debug "comparing levels:" λu = λ λv = λv

    λ < λv && return true
    λv > λ && return false
    # @debug "words are of the same level"

    u == v && return false # to avoid recusion in the trivial case

    # implements LenLex on level-λ subwords
    iu, iv = 0, 0
    while true
        iu = findnext(l -> level(o, l) == λ, u, iu + 1)
        iv = findnext(l -> level(o, l) == λ, v, iv + 1)
        if isnothing(iu)
            isnothing(iv) && break
            return true
        end
        isnothing(iv) && return false
        u[iu] == v[iv] && continue
        return lt(o, u[iu], v[iv])
    end
    # @debug "level-$λ words are equal, moving to words at level <$λ" u v

    #=
    Since we removed common prefix the difference between u and v must be now
    visible by considering U₀ and V₀, the 'heads of `u` and `v`. See
    > S. Rees _Automatic groups associated with word orders other than shortlex_
    > Section 5.3 Wreath product orders.
    =#

    su, sv = 1, 1
    eu = findnext(l -> level(o, l) == λ, u, su)
    ev = findnext(l -> level(o, l) == λ, v, sv)

    U₀ = @view u[su:eu-1]
    V₀ = @view v[sv:ev-1]

    # @debug "the heads for $u and $v are:" (su:eu-1, U₀) (sv:ev-1, V₀)

    @assert U₀ ≠ V₀ "Common prefix was not removed from $u, $v"

    isone(U₀) && return true
    isone(V₀) && return false
    return _lt_nocommonprefix(o, U₀, V₀)
end

function Base.show(io::IO, o::WreathOrder)
    A = alphabet(o)
    print(io, "WreathOrder: ")
    for (idx, p) in enumerate(invperm(o.letter_order))
        letter = A[p]
        l = level(o, p)
        print(io, letter, '(', l, ')')
        idx == length(A) && break
        print(io, " < ")
    end
end
