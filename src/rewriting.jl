"""
    rewrite_from_left(u::AbstractWord, rewriting)
Rewrites a word from left using `rewriting` object. The object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to succesfully rewrite `u`.
"""
function rewrite_from_left(u::W, rewriting) where {W<:AbstractWord}
    isempty(rewriting) && return u
    T = eltype(u)
    v = BufferWord{T}(0, length(u))
    w = BufferWord{T}(u, 0, 0)
    v = rewrite_from_left!(v, w, rewriting)
    return W(v)
end

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, ::Any)
Trivial rewrite: word `w` is simply appended to `v`.
"""
rewrite_from_left!(v::AbstractWord, w::AbstractWord, ::Any) = append!(v, w)

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Pair{<:AbstractWord, <:AbstractWord})
Rewrite: word `w` appending to `v` by using a single rewriting `rule`.
"""
function rewrite_from_left!(
    v::AbstractWord,
    w::AbstractWord,
    rule::Pair{<:AbstractWord, <:AbstractWord},
)
    lhs, rhs = rule
    while !isone(w)
        push!(v, popfirst!(w))
        if issuffix(lhs, v)
            prepend!(w, rhs)
            resize!(v, length(v) - length(lhs))
        end
    end
    return v
end

"""
    AbstractRewritingSystem{W,O}
Abstract type representing rewriting system.

The subtypes of `AbstractRewritingSystem{W,O}` need to implement the following
methods which constitute `AbstractRewritingSystem` interface:
 * `Base.push!`/`Base.pushfirst!`: appending a single rule at the end/beginning
 * `Base.pop!`/`Base.popfirst!`: deleting a single rule at the end/beginning
 * `Base.append!`/`Base.prepend!`: appending a another system at the end/beginning,
 * `Base.insert!`: inserting a single rule at a given place
 * `Base.delateat!`: deleting rules at given positions
 * `Base.empty!`: deleting all the rules
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

active(s::RewritingSystem) = s.act
rules(s::RewritingSystem) = s.rwrules
ordering(s::RewritingSystem) = s.order

isactive(s::RewritingSystem, i::Integer) = active(s)[i]
setactive!(s::RewritingSystem, i::Integer) = active(s)[i] = true
setinactive!(s::RewritingSystem, i::Integer) = active(s)[i] = false

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
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rws::RewritingSystem)
Rewrites word `w` from left using active rules from a given RewritingSystem and
appends the result to `v`. For standard rewriting `v` should be empty. See [Sims, p.66]
"""
function rewrite_from_left!(
    v::AbstractWord,
    w::AbstractWord,
    rws::RewritingSystem,
)
    while !isone(w)
        push!(v, popfirst!(w))
        for (i, (lhs, rhs)) in enumerate(rules(rws))
            KnuthBendix.isactive(rws, i) || continue

            if issuffix(lhs, v)
                prepend!(w, rhs)
                resize!(v, length(v) - length(lhs))
            end
        end
    end
    return v
end

function Base.show(io::IO, rws::RewritingSystem)
    println(io, "Rewriting System with $(length(rules(rws))) rules ordered by $(ordering(rws)):")
    for (i, (lhs, rhs)) in enumerate(rules(rws))
        lhs_str = string_repr(lhs, ordering(rws))
        rhs_str = string_repr(rhs, ordering(rws))
        act = isactive(rws, i) ? "✓" : " "
        println(io, lpad("$i", 4, " "), " $act ", lhs_str, "\t → \t", rhs_str)
    end
end
