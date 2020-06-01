"""
    AbstractRewritingSystem{T}
Abstract type representing rewriting system.

`AbstractRewritingSystem` as such has its meaning only in the contex of an Alphabet.
The subtypes of `AbstractRewritingSystem{T}` need to implement the following
methods which constitute `AbstractRewritingSystem` interface:
 * `Base.push!`/`Base.pushfirst!`: appending a single rule at the end/beginning
 * `Base.append!`/`Base.prepend!`: appending a another system at the end/beginning,
 * `Base.insert!`: inserting a single rule at a given place
 * `Base.delateat!`: delating rules at given positions
 * `Base.empty!`: delating all the rules
 * `length`: the number of rules (not necessarily unique) stored inside the system
"""
abstract type AbstractRewritingSystem{T} end

"""
    RewritingSystem{T} <: AbstractRewritingSystem{T}
RewritingSystem written as a list of pairs of Words (left side => right side)
"""
struct RewritingSystem{T} <: AbstractRewritingSystem{T}
    rwrules::Vector{T}
end

rules(s::RewritingSystem) = s.rwrules

Base.:(==)(s::RewritingSystem, r::RewritingSystem) = rules(s) == rules(r)
Base.hash(s::RewritingSystem, h::UInt) =
    foldl((h, x) -> hash(x, h), s.rwrules, init = hash(0x905098c1dcf219bc, h))
# the init value is simply hash(RewritingSystem)

Base.zero(s::RewritingSystem{T}) where T = RewritingSystem{T}(Pair{T,T}[])
Base.iszero(s::RewritingSystem) = isempty(rules(s))

Base.push!(s::RewritingSystem, r::Pair{T,T}) where {T<:AbstractWord} = (push!(rules(s), r); s)
Base.pushfirst!(s::RewritingSystem, r::Pair{T,T}) where {T<:AbstractWord} = (pushfirst!(rules(s), r); s)

Base.append!(s::RewritingSystem, v::RewritingSystem) = (append!(rules(s), rules(v)); s)
Base.prepend!(s::RewritingSystem, v::RewritingSystem) = (prepend!(rules(s), rules(v)); s)

Base.insert!(s::RewritingSystem, i::Integer, r::Pair{T,T}) where {T<:AbstractWord} = (insert!(rules(s), i, r); s)
Base.deleteat!(s::RewritingSystem, i::Integer) = (deleteat!(rules(s), i); s)
Base.deleteat!(s::RewritingSystem, inds) = (deleteat!(rules(s), inds); s)
Base.empty!(s::RewritingSystem) = (empty!(rules(s)); s)

Base.length(s::RewritingSystem) = length(rules(s))


"""
    rewrite_from_left(u::Word, rs::RewritingSystem)
Rewrites a word from left using rules from a given RewritingSystem. See [Sims, p.66]
"""
function rewrite_from_left(u::Word, rs::RewritingSystem)
    iszero(rs) && return u
    v = one(u)
    w = copy(u)
    while !isone(w)
        push!(v, popfirst!(w))
        for (lhs, rhs) in rules(rs)
            lenl = length(lhs)
            lenv = length(v)
            if lenl ≤ lenv
                if lhs == Word(v[end-lenl+1:end])
                    prepend!(w, rhs)
                    v = Word(v[1:end-lenl])
                end
            end
        end
    end
    return v
end
