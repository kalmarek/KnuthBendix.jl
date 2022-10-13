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

abstract type Side end
struct Right <: Side end
struct Left <: Side end

include("lexicographic.jl")
include("wreath.jl")
include("recursive.jl")
