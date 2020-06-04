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

alphabet(o::LenLex) = o.A
Base.:(==)(o1::LenLex, o2::LenLex) = alphabet(o1) == alphabet(o2)
Base.hash(o::LenLex, h::UInt) = hash(o.A, hash(h, hash(LenLex)))

"""
    lt(o::LenLex, p::T, q::T) where T<:Word{Integer}

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
