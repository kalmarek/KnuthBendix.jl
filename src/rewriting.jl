"""
    AbstractRewritingSystem{W,O}
Abstract type representing rewriting system.

`AbstractRewritingSystem` as such has its meaning only in the contex of an Alphabet.
The subtypes of `AbstractRewritingSystem{W,O}` need to implement the following
methods which constitute `AbstractRewritingSystem` interface:
 * `Base.push!`/`Base.pushfirst!`: appending a single rule at the end/beginning
 * `Base.append!`/`Base.prepend!`: appending a another system at the end/beginning,
 * `Base.insert!`: inserting a single rule at a given place
 * `Base.delateat!`: delating rules at given positions
 * `Base.empty!`: delating all the rules
 * `length`: the number of rules (not necessarily unique) stored inside the system
"""
abstract type AbstractRewritingSystem{W, O} end

"""
    RewritingSystem{W<:AbstractWord, O<:Ordering} <: AbstractRewritingSystem{T}
RewritingSystem written as a list of pairs of `Word`s together with the ordering
"""
struct RewritingSystem{W<:AbstractWord, O<:Ordering} <: AbstractRewritingSystem{W, O}
    rwrules::Vector{Pair{W,W}}
    order::O
end

rules(s::RewritingSystem) = s.rwrules
ordering(s::RewritingSystem) = s.order

Base.:(==)(s::RewritingSystem, r::RewritingSystem) = (rules(s) == rules(r) && ordering(s) == ordering(r))
Base.hash(s::RewritingSystem, h::UInt) =
    foldl((h, x) -> hash(x, h), s.rwrules, init = hash(s.order, hash(0x905098c1dcf219bc, h)))
# the init value is simply hash(RewritingSystem)

Base.zero(s::RewritingSystem{W,O}) where {W,O} = RewritingSystem{W,O}(Pair{W,W}[], ordering(s))
Base.iszero(s::RewritingSystem) = isempty(rules(s))

Base.push!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (push!(rules(s), r); s)
Base.pushfirst!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (pushfirst!(rules(s), r); s)

Base.append!(s::RewritingSystem, v::RewritingSystem) = (append!(rules(s), rules(v)); s)
Base.prepend!(s::RewritingSystem, v::RewritingSystem) = (prepend!(rules(s), rules(v)); s)

Base.insert!(s::RewritingSystem{W,O}, i::Integer, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (insert!(rules(s), i, r); s)
Base.deleteat!(s::RewritingSystem, i::Integer) = (deleteat!(rules(s), i); s)
Base.deleteat!(s::RewritingSystem, inds) = (deleteat!(rules(s), inds); s)
Base.empty!(s::RewritingSystem) = (empty!(rules(s)); s)

Base.length(s::RewritingSystem) = length(rules(s))


"""
    rewrite_from_left(u::W, rs::RewritingSystem)
Rewrites a word from left using rules from a given RewritingSystem. See [Sims, p.66]
"""
function rewrite_from_left(u::W, rs::RewritingSystem{W,O}) where {W<:AbstractWord, O<:Ordering}
    iszero(rs) && return u
    v = one(u)
    w = copy(u)
    while !isone(w)
        push!(v, popfirst!(w))
        for (lhs, rhs) in rules(rs)
            lenl = length(lhs)
            lenv = length(v)
            if lenl ≤ lenv
                if lhs == W(v[end-lenl+1:end])
                    prepend!(w, rhs)
                    v = W(v[1:end-lenl])
                end
            end
        end
    end
    return v
end
