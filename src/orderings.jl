import Base.Order: lt, Ordering
export LenLex, WreathOrder, RecursivePathOrder, WeightedLex

"""
    WordOrdering <: Ordering
Abstract type representing well-orderings of words which are translation invariant.

The subtypes of `WordOrdering` should implement:
 * `alphabet` - function (not necessary if they contain a field `A` storing the `Alphabet`), over which a particular order is defined;
 * `Base.Order.lt(o::WordOrdering, a, b)` - method to test whether `a` is less than `b` according to the ordering `o`.
 * `Base.hash` - a simple hashing function.
"""
abstract type WordOrdering <: Ordering end

alphabet(o::WordOrdering) = o.A
Base.:(==)(o1::T, o2::T) where {T<:WordOrdering} = alphabet(o1) == alphabet(o2)

"""
    struct LenLex{T} <: WordOrdering
    LenLex(A::Alphabet)

`LenLex` order compares words first by length and then by lexicographic (left-to-right) order determined by the order of letters `A`.
"""
struct LenLex{T} <: WordOrdering
    A::Alphabet{T}
end

Base.hash(o::LenLex, h::UInt) = hash(o.A, hash(h, hash(LenLex)))

function lt(o::LenLex, p::AbstractWord, q::AbstractWord)
    if length(p) == length(q)
        for (a, b) in zip(p, q)
            a == b || return isless(a, b)  # comparing only on positive pointer values
        end
        return false
    else
        return isless(length(p), length(q))
    end
end

"""
    struct WreathOrder{T} <: WordOrdering
    WreathOrder(A::Alphabet)

`WreathOrder` compares words wreath-product ordering of words over the given `Alphabet`. Internal lexicographic ordering is determined by the order of letters `A`.
Here wreath product refers to
> `⟨A[1]⟩ ≀ ⟨A[2]⟩ ≀ … ≀ ⟨A[n]⟩`,
where `⟨A[i]⟩` denotes the monoid generated by `i`-th letter.

For the precise definition see e.g.
> Charles C. Sims, _Computation with finitely presented groups_
> Cambridge University Press 1994,
> pages 46-47.
"""
struct WreathOrder{T} <: WordOrdering
    A::Alphabet{T}
end

Base.hash(o::WreathOrder, h::UInt) = hash(o.A, hash(h, hash(WreathOrder)))

function lt(o::WreathOrder, p::AbstractWord, q::AbstractWord)
    iprefix = lcp(p, q) + 1

    @views pp = p[iprefix:end]
    @views qq = q[iprefix:end]

    isone(pp) && return !isone(qq)
    isone(qq) && return false

    # i.e. pp, qq ≂̸ ε
    max_p = maximum(pp)
    max_q = maximum(qq)

    max_p < max_q && return true
    max_p > max_q && return false

    # i.e. max_p == max_q
    head_p_len = count(isequal(max_p), pp)
    head_q_len = count(isequal(max_p), qq)

    head_p_len < head_q_len && return true
    head_p_len > head_q_len && return false

    # i.e. head_p_len == head_q_len
    first_pp = findfirst(isequal(max_p), pp)
    first_qq = findfirst(isequal(max_p), qq)
    return @views lt(o, pp[1:first_pp-1], qq[1:first_qq-1])
end

"""
    struct RecursivePathOrder{T} <: WordOrdering
    RecursivePathOrder(A::Alphabet)

`RecursivePathOrder` represents a rewriting ordering of words over the given `Alphabet`.
Internal lexicographic ordering is determined by the order of letters `A`.

For the precise definition see
> Susan M. Hermiller, Rewriting systems for Coxeter groups,
> _Journal of Pure and Applied Algebra_,
> Volume 92, Issue 2, 7 March 1994, pages 137-148.
"""
struct RecursivePathOrder{T} <: WordOrdering
    A::Alphabet{T}
end

function Base.hash(o::RecursivePathOrder, h::UInt)
    return hash(o.A, hash(h, hash(RecursivePathOrder)))
end

function lt(o::RecursivePathOrder, p::AbstractWord, q::AbstractWord)
    isone(p) && return !isone(q)
    isone(q) && return false

    # i.e. p, q ≂̸ ε
    length(p) == 1 && length(q) == 1 && return (first(p) < first(q))

    # i.e. we are not comparing single letter words
    @views begin
        p == q[2:end] && return true
        lt(o, p, q[2:end]) && return true
        first(p) < first(q) && lt(o, p[2:end], q) && return true
        first(p) == first(q) && lt(o, p[2:end], q[2:end]) && return true
    end
    return false
end

"""
    struct WeightedLex{T} <: WordOrdering
    WeightedLex(A::Alphabet, weights::AbstractVector)

`WeightedLex` order compares words first according to their weight and then
by the lexicographic order determined by the order of letters `A`.
The `weight` array assigns weights to each letter and the weight of a word is
simply the sum of weights of all letters.
The `LenLex` ordering is a special case of `WeightedLex` when all weights are equal to `1`.

!!! note:
    Since empty word is assigned a value of `zero(eltype(weights))` a vector of
    positive weights is strongly recommended.
"""
struct WeightedLex{T,S} <: WordOrdering
    A::Alphabet{T}
    weights::Vector{S}

    function WeightedLex(A::Alphabet{T}, weights::AbstractVector{S}) where {T,S}
        @assert length(weights) == length(A)
        @assert all(w -> w >= (zero(S)), weights)
        return new{T,S}(A, weights)
    end
end

Base.hash(wl::WeightedLex, h::UInt) = hash(wl.weights, hash(wl.lenlex, h))

Base.@propagate_inbounds weight(o::WeightedLex, l::Integer) = o.weights[l]

function weight(o::WeightedLex, p::AbstractWord)
    isone(p) && return zero(eltype(o.weights))
    return @inbounds sum(weight(o, l) for l in p)
end

function Base.Order.lt(o::WeightedLex, p::AbstractWord, q::AbstractWord)
    S = eltype(o.weights)

    weight_p = weight(o, p)
    weight_q = weight(o, q)

    if weight_p == weight_q
        for (a, b) in zip(p, q)
            # comparing only on positive pointer values
            a == b || return isless(a, b)
        end
        return false
    else
        return isless(weight_p, weight_q)
    end
end
