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
    head(u::AbstractWord{T}) where {T<:Integer}
Function returning the maximum degree of a word, the list of its degrees and
the list of its heads with respect to the basic wreath-product ordering.
Required for `lt(o::BasicWreath, ...)`.
"""
function head(u::AbstractWord{T}) where {T<:Integer}
    P = Word{T}[]
    d = T[]
    m = 0
    for letter in u
        if letter > m
            m = letter
            pushfirst!(d, m)
            pushfirst!(P, Word{T}([letter]))
        elseif letter == m
            push!(first(P), letter)
        end
    end
    return (length(d), d, P)
end

"""
    struct WreathOrder{T} <: Ordering

Structure representing basic wreath-product ordering (determined by the Lexicographic
ordering of the Alphabet) of the words over given Alphabet. This Lexicographinc
ordering of an Alphabet is implicitly specified inside Alphabet struct.
"""
struct WreathOrder{T} <: Ordering
    A::Alphabet{T}
end
Base.:(==)(o1::WreathOrder, o2::WreathOrder) = alphabet(o1) == alphabet(o2)
Base.hash(o::WreathOrder, h::UInt) = hash(o.A, hash(h, hash(WreathOrder)))

"""
    lt(o::WreathOrder, p::T, q::T) where T<:Word{Integer}

Return whether the first word is less then the other one in a given WreathOrder ordering.
"""
function lt(o::WreathOrder, p::T, q::T) where T<:AbstractWord{<:Integer}
    iprefix = lcp(p, q) + 1
    dp, degreesp, headsp = @views head(p[iprefix:end])
    dq, degreesq, headsq = @views head(q[iprefix:end])

    if dp > dq
        return false
    else
        for i in 1:dp
            @inbounds (degreesp[i] == degreesq[i]) || return (degreesp[i] < degreesq[i])
            @inbounds (headsp[i] == headsq[i]) || return (headsp[i] < headsq[i])
        end
        dp < dq ? true : false
    end
end
