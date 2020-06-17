"""
    AbstractRewritingSystem{W,O}
Abstract type representing rewriting system.

The subtypes of `AbstractRewritingSystem{W,O}` need to implement the following
methods which constitute `AbstractRewritingSystem` interface:
 * `Base.push!`/`Base.pushfirst!`: appending a single rule at the end/beginning
 * `Base.pop!`/`Base.popfirst!`: delating a single rule at the end/beginning
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
    act::BitArray{1}
end

RewritingSystem(rwrules::Vector{Pair{W,W}}, order::O) where{W<:AbstractWord, O<:Ordering} = RewritingSystem(rwrules, order, trues(length(rwrules)))

rules(s::RewritingSystem) = s.rwrules
active(s::RewritingSystem) = s.act
arules(s::RewritingSystem) = rules(s)[active(s)]
ordering(s::RewritingSystem) = s.order

isactive(s::RewritingSystem, i::Integer) = active(s)[i]

setactive!(s::RewritingSystem, i::Integer) = active(s)[i] = true
setinactive!(s::RewritingSystem, i::Integer) = active(s)[i] = false

Base.:(==)(s::RewritingSystem, r::RewritingSystem) = (Set(rules(s)) == Set(rules(r)) && ordering(s) == ordering(r))
Base.hash(s::RewritingSystem, h::UInt) =
    foldl((h, x) -> hash(x, h), s.rwrules, init = hash(s.order, hash(0x905098c1dcf219bc, h)))
# the init value is simply hash(RewritingSystem)

Base.push!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (push!(rules(s), r); push!(active(s), true); s)
Base.pushfirst!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (pushfirst!(rules(s), r); pushfirst!(active(s), true); s)

Base.pop!(s::RewritingSystem) = (pop!(active(s)); pop!(rules(s)))
Base.popfirst!(s::RewritingSystem)= (popfirst!(active(s)); popfirst!(rules(s)))

Base.append!(s::RewritingSystem, v::RewritingSystem) = (append!(rules(s), rules(v)); append!(active(s), active(v)); s)
Base.prepend!(s::RewritingSystem, v::RewritingSystem) = (prepend!(rules(s), rules(v)); prepend!(active(s), active(v)); s)

Base.insert!(s::RewritingSystem{W,O}, i::Integer, r::Pair{W,W}) where {W<:AbstractWord, O<:Ordering} = (insert!(rules(s), i, r); insert!(active(s), i, true); s)
Base.deleteat!(s::RewritingSystem, i::Integer) = (deleteat!(rules(s), i); deleteat!(active(s), i); s)
Base.deleteat!(s::RewritingSystem, inds) = (deleteat!(rules(s), inds); deleteat!(active(s), inds); s)
Base.empty!(s::RewritingSystem) = (empty!(rules(s)); empty!(active(s)); s)
Base.empty(s::RewritingSystem{W, O}, ::Type{<:AbstractWord}=W,o::Ordering=ordering(s)) where {W,O} =
    RewritingSystem(Pair{W,W}[], o)
Base.isempty(s::RewritingSystem) = isempty(rules(s))

Base.length(s::RewritingSystem) = length(rules(s))

"""
    rewrite_from_left(u::W, rs::RewritingSystem)
Rewrites a word from left using active rules from a given RewritingSystem.
See [Sims, p.66]
"""
function rewrite_from_left(u::AbstractWord, rs::RewritingSystem)
    isempty(rs) && return u
    v = one(u)
    w = copy(u)
    while !isone(w)
        push!(v, popfirst!(w))
        for (lhs, rhs) in arules(rs)
            lenl = length(lhs)
            lenv = length(v)
            if lenl ≤ lenv && lhs == @view v[end-lenl+1:end]
                prepend!(w, rhs)
                v = v[1:end-lenl]
            end
        end
    end
    return v
end

function Base.show(io::IO, rws::RewritingSystem)
    println(io, "Rewriting System with $(length(rules(rws))) rules ordered by $(ordering(rws)):")
    O = ordering(rws)
    for (i, (lhs, rhs)) in enumerate(rules(rws))
        lhs_str = join(O[lhs], "*")
        rhs_str = isone(rhs) ? "(empty word)" : join(O[rhs], "*")
        println(io, "  $i.  ", lhs_str, " → ", rhs_str)
    end
end
