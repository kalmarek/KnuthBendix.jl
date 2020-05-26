import Base.Order: lt, Ordering
export LenLex

"""
    struct LenLex{T} <: Ordering

Basic structure representing Length+Lexicographic (left-to-right) ordering of
the words over given Alphabet. Lexicographing ordering of an Alphabet is
implicitly specified inside Alphabet struct.
"""
struct LenLex{T} <: Ordering
    A::Alphabet{T}
end


"""
    lt(o::LenLex, p::T, q::T) where T<:Word{Integer}

Return whether the first word is less then the other one in a given LenLex ordering.
"""
function lt(o::LenLex, p::T, q::T) where T<:AbstractWord{<:Integer}
    if length(p) == length(q)
        for (a, b) in zip(p,q)
            o.A[o.A[a]] == o.A[o.A[b]] || return isless(o.A[o.A[a]], o.A[o.A[b]])  # comparing only on positive pointer values
        end
        return false
    else
        return isless(length(p), length(q))
    end
end
