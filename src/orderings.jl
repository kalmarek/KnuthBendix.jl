import Base.Order: lt, Ordering
export LenLex, WreathOrder, RecursivePathOrder

"""
    WordOrdering <: Ordering
Abstract type representing word orderings.

The subtypes of `WordOrdering` should contain a field `A` storing the `Alphabet`
over which a particular order is defined. Morever, an `Base.lt` method should be
defined to compare whether one word is less than the other (in the ordering
defined).
"""
abstract type WordOrdering <: Ordering end


alphabet(o::WordOrdering) = o.A
Base.:(==)(o1::T, o2::T) where {T<:WordOrdering} = alphabet(o1) == alphabet(o2)
string_repr(W::AbstractWord, o::WordOrdering) = string_repr(W, alphabet(o))


"""
    struct LenLex{T} <: WordOrdering

Basic structure representing Length+Lexicographic (left-to-right) ordering of
the words over given Alphabet. Lexicographic ordering of an Alphabet is
implicitly specified inside Alphabet struct.
"""
struct LenLex{T} <: WordOrdering
    A::Alphabet{T}
end

Base.hash(o::LenLex, h::UInt) = hash(o.A, hash(h, hash(LenLex)))

"""
    lt(o::LenLex, p::T, q::T) where T<:AbstractWord{<:Integer}

Return whether the first word is less then the other one in a given LenLex ordering.
"""
function lt(o::LenLex, p::T, q::T) where T<:AbstractWord{<:Integer}
    if length(p) == length(q)
        for (a, b) in zip(p,q)
            a == b || return isless(a, b)  # comparing only on positive pointer values
        end
        return false
    else
        return isless(length(p), length(q))
    end
end


"""
    struct WreathOrder{T} <: WordOrdering

Structure representing Basic Wreath-Product ordering (determined by the Lexicographic
ordering of the Alphabet) of the words over given Alphabet. This Lexicographinc
ordering of an Alphabet is implicitly specified inside Alphabet struct.
"""
struct WreathOrder{T} <: WordOrdering
    A::Alphabet{T}
end

Base.hash(o::WreathOrder, h::UInt) = hash(o.A, hash(h, hash(WreathOrder)))

"""
    lt(o::WreathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}

Return whether the first word is less then the other one in a given WreathOrder ordering.
"""
function lt(o::WreathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}
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
    return @views lt(o, pp[1:first_pp - 1], qq[1:first_qq - 1])
end


"""
    struct RecursivePathOrder{T} <: WordOrdering

Structure representing Recursive Path Ordering (determined by the Lexicographic
ordering of the Alphabet) of the words over given Alphabet. This Lexicographinc
ordering of an Alphabet is implicitly specified inside Alphabet struct.
"""
struct RecursivePathOrder{T} <: WordOrdering
    A::Alphabet{T}
end

Base.hash(o::RecursivePathOrder, h::UInt) = hash(o.A, hash(h, hash(RecursivePathOrder)))

"""
    lt(o::RecursivePathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}

Return whether the first word is less then the other one in a given
RecursivePathOrder ordering.
"""
function lt(o::RecursivePathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}
    isone(p) && return !isone(q)
    isone(q) && return false

    # i.e. p, q ≂̸ ε
    length(p) == 1 && length(q) == 1 && return (first(p) < first(q))

    # i.e. we are not comparing single letter words
    if first(p) == first(q)
        @views lt(o, p[2:end], q[2:end]) && return true
    elseif first(p) < first(q)
        @views lt(o, p[2:end], q[1:end]) && return true
    end
    @views p == q[2:end] && return true
    @views return lt(o, p[1:end], q[2:end])
end
