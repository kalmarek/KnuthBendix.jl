import Base.Order: lt, Ordering
export LenLex, WreathOrder

"""
    struct LenLex{T} <: Ordering

Basic structure representing Length+Lexicographic (left-to-right) ordering of
the words over given Alphabet. Lexicographic ordering of an Alphabet is
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

string_repr(W::AbstractWord, o::Ordering) = string_repr(W, alphabet(o))


"""
    struct WreathOrder{T} <: Ordering

Structure representing basic wreath-product ordering (determined by the Lexicographic
ordering of the Alphabet) of the words over given Alphabet. This Lexicographinc
ordering of an Alphabet is implicitly specified inside Alphabet struct.
"""
struct WreathOrder{T} <: Ordering
    A::Alphabet{T}
end

alphabet(o::WreathOrder) = o.A
Base.:(==)(o1::WreathOrder, o2::WreathOrder) = alphabet(o1) == alphabet(o2)
Base.hash(o::WreathOrder, h::UInt) = hash(o.A, hash(h, hash(WreathOrder)))

"""
    lt(o::WreathOrder, p::T, q::T) where T<:Word{Integer}

Return whether the first word is less then the other one in a given WreathOrder ordering.
"""
function lt(o::WreathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}
    iprefix = lcp(p, q) + 1

    @views pp = p[iprefix:end]
    @views qq = q[iprefix:end]

    if isone(pp)
        isone(qq) ? (return false) : (return true)
    elseif isone(qq)
        return false
    end

    max_p = maximum(pp)
    max_q = maximum(qq)

    if max_p < max_q
        return true
    elseif max_p == max_q
        head_p = findall(isequal(max_p), pp)
        head_q = findall(isequal(max_p), qq)
        if length(head_p) < length(head_q)
            return true
        elseif length(head_p) == length(head_q)
            return @views lt(o, pp[1:first(head_p) - 1], qq[1:first(head_q) - 1])
        else
            return false
        end
    else
        return false
    end
end