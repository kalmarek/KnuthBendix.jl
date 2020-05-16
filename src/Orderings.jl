module Orderings

import Base.Order: lt, Ordering
export LexicographicOrdering, LexicographicOrder, LenLexOrder

abstract type LexicographicOrdering <: Ordering end


## Assuming the order is given by dictionary with entries (::"letter", ::int)
struct LexicographicOrder <: LexicographicOrdering
    order::Dict
end


struct LenLexOrder{LexOrd<:LexicographicOrdering} <: Ordering
    lexord::LexOrd
end

# `T` shall be later changed to the type of letters of the Alphabet (Char?)
lt(o::LexicographicOrder, a::T, b::T) = isless(o.order[a], o.order[b])


## Assuming the following methods are implemented for type Word:
## length, iteration
## Assuming that for "letters" from Alphabet exists method: ==
function lt(o::LenLexOrder, p::T, q::T) where T<:AbstractWord
    if length(p) == length(q)
        for i in 1:length(p)
            p[i]==q[i] ||  return lt(o.lexord, p[i], q[i])
        end
        return false
    else
        return isless(length(p), length(q))
    end
end


