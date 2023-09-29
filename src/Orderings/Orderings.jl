import Base.Order: Ordering, lt

"""
    RewritingOrdering

Abstract type representing translation bi-invariant well-orderings on free
monoids over an alphabet. Translation (bi-)invariance means that whenever
`u < v`, then `aub < avb` for arbitrary words `a` and `b`.
In particular `ε` (the monoid identity) is the smallest word for any
`RewritingOrdering`.

The subtypes of `RewritingOrdering` must implement:

* `alphabet` which returns the underlying alphabet, over which a particular
  order is defined;
* `Base.Order.lt(o::RewritingOrdering, a::AbstractWord, b::AbstractWord)` to
  test whether `a` is less than `b` according to the ordering `o`.
"""
abstract type RewritingOrdering <: Ordering end

"""
    alphabet(ord::RewritingOrdering)
Return the alphabet of the free monoid on which `ord` is defined.
"""
function alphabet(::RewritingOrdering) end

abstract type Side end
struct Right <: Side end
struct Left <: Side end

include("lexicographic.jl")
include("wreath.jl")
include("recursive.jl")
