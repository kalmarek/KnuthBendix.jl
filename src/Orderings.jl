import Base.Order: lt, Ordering
export LenLexOrder

"""
    struct LenLexOrder{T<:Alphabet} <: Ordering

Basic structure representing Length+Lexicographic (left-to-right) ordering of
the words over given Alphabet. Lexicographing ordering of an Alphabet is
implicitly specified inside Alphabet struct.
"""
struct LenLexOrder{T<:Alphabet} <: Ordering
    A::T
end

"""
    lt(o::LenLexOrder, p::T, q::T) where T<:AbstractWord

Return whether the first word is less then the other one in a given LenLex ordering.
"""
function lt(o::LenLexOrder, p::T, q::T) where T<:AbstractWord
    if length(p) == length(q)
        for (a, b) in zip(p,q)
            o.A[a] == o.A[b] || return isless(o.A[o.A[a]], o.A[o.A[b]])  # comparing only on positive pointer values
        end
        return false
    else
        return isless(length(p), length(q))
    end
end
