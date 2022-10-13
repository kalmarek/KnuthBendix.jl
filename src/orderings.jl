import Base.Order: Ordering, lt

"""
    WordOrdering <: Ordering
Abstract type representing well-orderings of words which are translation invariant.

The subtypes of `WordOrdering` should implement:
 * `alphabet` which returns the underlying alphabet, over which a particular order
 is defined;
 * `Base.Order.lt(o::WordOrdering, a::AbstractWord, b::AbstractWord)` to test
 whether `a` is less than `b` according to the ordering `o`.
"""
abstract type WordOrdering <: Ordering end

abstract type LexOrdering <: WordOrdering end

"""
    LenLex{T} <: WordOrdering
    LenLex(A::Alphabet[; order=collect(A)])

Compare words first by their length, then break ties by (left-)lexicographic order.

# Example
```julia-repl
julia> Al = Alphabet([:a, :A, :b, :B]);

julia> ll1 = LenLex(Al)
LenLex: a < A < b < B

julia> ll2 = LenLex(Al, order=[:a, :b, :A, :B])
LenLex: a < b < A < B

julia> a, A, b, B = [Word([i]) for i in 1:length(Al)];

julia> KnuthBendix.lt(ll1, a*A, a*b)
true

julia> KnuthBendix.lt(ll2, a*A, a*b)
false
```
"""
struct LenLex{T} <: LexOrdering
    A::Alphabet{T}
    letter_order::Vector{Int}
end

function LenLex(A::Alphabet{T}; order::AbstractVector{T} = collect(A)) where {T}
    @assert length(order) == length(A)
    @assert Set(order) == Set(A)
    letter_order = sortperm([A[l] for l in order])
    return LenLex(A, letter_order)
end

"""
    WeightedLex{T,S} <: WordOrdering
    WeightedLex(A::Alphabet; weights[, order=collect(A)])

Compare words first by their weight, then break ties by (left-)lexicographic order.

The `weights` vector assigns weights to each letter __as they appear in the alphabet__
and the weight of a word is the sum of weights of all of its letters.

With all weights equal to `1` `WeightedLex` becomes `LenLex`.

# Example
```julia-repl
julia> al = Alphabet([:a, :A, :b, :B]);

julia> a, A, b, B = (Word([i]) for i in 1:length(al));

julia> wtlex = WeightedLex(al, weights=[1, 2, 3, 4], order=[:a, :b, :B, :A])
WeightedLex: a(1) < b(3) < B(4) < A(2)

julia> lt(wtlex, b * B, B * a * a * a)
true

julia> lt(wtlex, A*B, B*A)
false
```
"""
struct WeightedLex{T,S} <: LexOrdering
    A::Alphabet{T}
    weights::Vector{S}
    letter_order::Vector{Int}
end

function WeightedLex(
    A::Alphabet{T};
    weights::AbstractVector{S},
    order::AbstractVector{T} = collect(A),
) where {T,S}
    @assert length(A) == length(weights) == length(order)
    @assert Set(order) == Set(A)
    @assert all(>=(one(S)), weights)
    letter_order = sortperm([A[l] for l in order])
    return WeightedLex(A, weights, letter_order)
end

alphabet(o::LexOrdering) = o.A

function lt(o::LexOrdering, lp::Integer, lq::Integer)
    return o.letter_order[lp] < o.letter_order[lq]
end

weight(::LenLex, p::AbstractWord) = length(p)

function weight(o::WeightedLex, p::AbstractWord)
    return @inbounds sum(
        (o.weights[l] for l in p),
        init = zero(eltype(o.weights)),
    )
end

function Base.Order.lt(o::LexOrdering, p::AbstractWord, q::AbstractWord)
    wp = weight(o, p)
    wq = weight(o, q)
    wp ≠ wq && return wp < wq
    m = min(length(p), length(q))
    @inbounds for i in 1:m
        p[i] == q[i] && continue
        return lt(o, p[i], q[i])
    end
    # @debug "words are prefix of each other, using lexicographic ordering"
    return length(p) < length(q)
end

function Base.show(io::IO, o::LenLex)
    print(io, "LenLex: ")
    A = alphabet(o)
    for (idx, p) in pairs(invperm(o.letter_order))
        letter = A[p]
        print(io, letter)
        idx == length(A) && break
        print(io, " < ")
    end
end

function Base.show(io::IO, o::WeightedLex)
    A = alphabet(o)
    print(io, "WeightedLex: ")
    for (idx, p) in pairs(invperm(o.letter_order))
        letter = A[p]
        w = o.weights[p]
        print(io, letter, '(', w, ')')
        idx == length(A) && break
        print(io, " < ")
    end
end

"""
    WreathOrder{T,S} <: WordOrdering
    WreathOrder(A::Alphabet; levels[, order=collect(A)])

Compare words first by their levels, then break ties by recursion on prefixes.

The `levels` vector assigns levels to each letter __as they appear in the alphabet__
and the `level` of a word is the maximum of levels of all its letters.

The order compare words first by their levels, then break ties by `LenLex`
order of pure max-level words. Further ties are resolved by recursing on lower
level prefixes. Let `U = U₀·a₁·U₁·…·aᵣ·Uᵣ` be a decomposition of `U` such that
all `aᵢ`s are at the same (maximal) level and each `Uᵢ` is at level strictly
smaller. Let `V = V₀·b₁·V₁·…·bₛ·Vₛ` be a similar decomposition.
Then `U <≀ V` if either
    * `a₁·…·aᵣ < b₁·…·bₛ` according to `LenLex` order, or
    * `a₁·…·aᵣ = b₁·…·bₛ` and `U₀ <≀ V₀`, or `Uᵢ = Vᵢ` for `0≤i<k` but `Uₖ <≀ Vₖ`.

For more references see
> 1. C. Sims _Computation with finitely presented groups_, p. 46-47
> 2. D. Holt, B. Eick and E. O’Brien _Handbook of Computational Group Theory_,
>    Section 12.4 Rewriting systems for polycyclic groups, p. 426-427
> 3. S. Rees _Automatic groups associated with word orders other than shortlex_
>    Section 5.3 Wreath product orders.

# Example
```julia-repl
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
struct WreathOrder{T,S} <: WordOrdering
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

abstract type Side end
struct Right <: Side end
struct Left <: Side end

"""
    Recursive{Side,T} <: WordOrdering
    Recursive{Side}(A::Alphabet; order=collect(A))

A special case of `WreathOrder` where each letter is given a unique level.

Since levels are unique they just linearly order letters in the alphabet `A`.
The order generally promotes smaller generators, and larger ones will occur
in minimal words relatively early. For example if `a < b` then `a·b > b·aⁿ`.

The ordering is sometimes also known as _recursive path ordering_ and is useful
e.g. for polycyclic groups.

# Definition

Given a partial order `(A, <)` on an alphabet `A`, for `p, q ∈ A*` we say that
`p < q` w.r.t. left-recursive ordering if
> 1. `p == ε ≠ q`, or
> 2. `p = p′·a`, `q = q′·b` for some `a, b ∈ A` and
    * `a == b` and `p′ < q′`, or
    * `a < b` and `p < q′`, or
    * `a > b` and `p′ < q`

For the right-recursive ordering one needs to change the decompositions in
point 2. to
> `p = a·p′`, `q = b·q′` for some `a, b ∈ A` …

See M. Jentzen _Confluent String Rewriting_, Definition 1.2.14 p.24.

# Example
```julia-repl

```
"""
struct Recursive{LR<:Side,T} <: WordOrdering
    A::Alphabet{T}
    letter_order::Vector{Int}
end

Recursive(A::Alphabet; order = collect(A)) = Recursive{Left}(A, order = order)

function Recursive{LR}(
    A::Alphabet{T};
    order::AbstractVector{T} = collect(A),
) where {LR,T}
    @assert length(A) == length(order)
    @assert Set(order) == Set(A)

    letter_order = sortperm([A[l] for l in order])
    return Recursive{LR,T}(A, letter_order)
end

function recursive_order(A::Alphabet)
    done = falses(length(A))
    order = Vector{eltype(A)}(undef, length(A))
    top = lastindex(done)
    bottom = firstindex(done)
    for letter in A
        done[A[letter]] && continue
        if hasinverse(letter, A)
            done[A[letter]] = true
            order[bottom] = letter
            bottom += 1

            inv_letter = inv(A, letter)
            inv_letter == letter && continue

            done[A[inv_letter]] = true
            order[bottom] = inv_letter
            bottom += 1
        else
            done[A[letter]] = true
            order[top] = letter
            top -= 1
        end
    end
    @assert all(done)
    return order
end

alphabet(o::Recursive) = o.A
level(o::Recursive, l::Integer) = o.levels[l]

function Base.show(io::IO, o::Recursive{LR}) where {LR}
    print(io, LR, "-Recursive: ")
    A = alphabet(o)
    for (idx, p) in pairs(o.letter_order)
        letter = A[p]
        print(io, letter)
        idx == length(A) && break
        print(io, " < ")
    end
end

function lt(o::Recursive, lp::Integer, lq::Integer)
    return o.letter_order[lp] < o.letter_order[lq]
end

next(::Type{Right}, low, high) = (low + 1, high)
next(::Type{Left}, low, high) = (low, high - 1)

letter(::Type{Right}, w::AbstractWord, low, high) = w[low]
letter(::Type{Left}, w::AbstractWord, low, high) = w[high]

function lt(o::Recursive{Side}, p::AbstractWord, q::AbstractWord) where {Side}
    if isone(p)
        isone(q) && return false
        return true
    end

    # we're going forwards shifting ip and iq until they go out of bounds
    p_is_smaller = true
    lowp, highp = firstindex(p), lastindex(p)
    lowq, highq = firstindex(q), lastindex(q)
    while true
        if lowp > highp
            lowq > highq && return !p_is_smaller
            return true
        end
        lowq > highq && return false

        # compare first letters and chop the smaller from the corresponding word.
        # recurse
        a = letter(Side, p, lowp, highp)
        b = letter(Side, q, lowq, highq)

        if a == b
            # return lt(o, p[2:end], q[2:end])
            lowp, highp = next(Side, lowp, highp)
            lowq, highq = next(Side, lowq, highq)
        else
            if lt(o, a, b)
                # return lt(o, p[2:end], q])
                lowp, highp = next(Side, lowp, highp)
                p_is_smaller = true
            else
                # return lt(o, p, q[2:end])
                lowq, highq = next(Side, lowq, highq)
                p_is_smaller = false
            end
        end
    end
end
