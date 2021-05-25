"""
    rewrite_from_left(u::AbstractWord, rewriting)
Rewrites a word from left using `rewriting` object. The object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to successfully rewrite `u`.
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
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Alphabet)
Append `w` to `v` applying free reductions as defined by the inverses of `A`.
"""
function rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Alphabet)
    while !isone(w)
        if isone(v)
            push!(v, popfirst!(w))
        else
            # the first check is for monoids only
            if hasinverse(last(v), A) && inv(A, last(v)) == first(w)
                pop!(v)
                popfirst!(w)
            else
                push!(v, popfirst!(w))
            end
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
 * `Base.deleteat!`: deleting rules at given positions
 * `Base.empty!`: deleting all the rules
 * `length`: the number of rules (not necessarily unique) stored inside the system
"""
abstract type AbstractRewritingSystem{W, O} end

"""
    RewritingSystem{W<:AbstractWord, O<:WordOrdering} <: AbstractRewritingSystem{W,O}
RewritingSystem written as a list of pairs of `Word`s together with the ordering.
Field `_len` stores the number of all rules in the RewritingSystem (length of the
system). Fields `_i` and `_j` are a helper fields used during KnuthBendix procedure.
"""
struct RewritingSystem{W<:AbstractWord, O<:WordOrdering} <: AbstractRewritingSystem{W, O}
    rwrules::Vector{Pair{W,W}}
    order::O
    act::BitArray{1}
end

function RewritingSystem(rwrules::Vector{Pair{W,W}}, order::O; bare=false) where
    {W<:AbstractWord, O<:WordOrdering}
    @assert length(alphabet(order)) <= _max_alphabet_length(W) "Type $W can not store words over $(alphabet(order))."

    rls = if !bare
        abt_rules = rules(W, alphabet(order))
        [abt_rules; rwrules]
    else
        rwrules
    end
    return RewritingSystem(rls, order, trues(length(rls)))
end

active(s::RewritingSystem) = s.act
rules(s::RewritingSystem) = s.rwrules
ordering(s::RewritingSystem) = s.order
alphabet(s::RewritingSystem) = alphabet(ordering(s))

isactive(s::RewritingSystem, i::Integer) = active(s)[i]
setactive!(s::RewritingSystem, i::Integer) = active(s)[i] = true
setinactive!(s::RewritingSystem, i::Integer) = active(s)[i] = false

Base.push!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W, O} =
    (push!(rules(s), r); push!(active(s), true); s)
Base.pushfirst!(s::RewritingSystem{W,O}, r::Pair{W,W}) where {W, O} =
    (pushfirst!(rules(s), r); pushfirst!(active(s), true); s)

Base.pop!(s::RewritingSystem) =
    (pop!(active(s)); pop!(rules(s)))
Base.popfirst!(s::RewritingSystem)=
    (popfirst!(active(s)); popfirst!(rules(s)))

Base.append!(s::RewritingSystem, v::RewritingSystem) =
    (append!(rules(s), rules(v)); append!(active(s), active(v)); s)
Base.prepend!(s::RewritingSystem, v::RewritingSystem) =
    (prepend!(rules(s), rules(v)); prepend!(active(s), active(v)); s)

Base.insert!(s::RewritingSystem{W,O}, i::Integer, r::Pair{W,W}) where {W<:AbstractWord, O<:WordOrdering} =
    (insert!(rules(s), i, r); insert!(active(s), i, true); s)
Base.deleteat!(s::RewritingSystem, i::Integer) =
    (deleteat!(rules(s), i); deleteat!(active(s), i); s)
Base.deleteat!(s::RewritingSystem, inds) =
    (deleteat!(rules(s), inds); deleteat!(active(s), inds); s)

Base.empty!(s::RewritingSystem) =
    (empty!(s.rwrules); empty!(s.act); s)

function Base.empty(
    s::RewritingSystem{W,O},
    ::Type{<:AbstractWord} = W,
    o::WordOrdering = ordering(s),
) where {W,O}
    RewritingSystem(Pair{W,W}[], o, bare=true)
end

Base.isempty(s::RewritingSystem) = isempty(rules(s))

Base.length(s::RewritingSystem) = length(rules(s))

function rules(::Type{W}, A::Alphabet) where {W<:AbstractWord}
    rls = Pair{W,W}[]
    for l in letters(A)
        if KnuthBendix.hasinverse(l, A)
            L = inv(A, l)
            push!(rls, W([A[l], A[L]]) => one(W))
        end
    end
    return rls
end

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

"""
    isirreducible(w::AbstractWord, rws::RewritingSystem)
Returns whether a word is irreducible with respect to a given rewriting system
"""
function isirreducible(w::AbstractWord, rws::RewritingSystem)
    for (lhs, _) in rules(rws)
        occursin(lhs, w) && return false
    end
    return true
end

"""
    getirreduciblesubsystem(rws::RewritingSystem)
Returns a list of right sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function getirreduciblesubsystem(rws::RewritingSystem{W}) where W
    rsides = W[]
    for (lhs, _) in rules(rws)
        ok = true
        n = length(lhs)
        if n > 2
            for j in 2:(n-1)
                w = @view(lhs[1:j])
                isirreducible(w, rws) || (ok = false; break)
            end
            for i in 2:(n-1)
                ok || break
                for j in (i+1):n
                    w = @view(lhs[i:j])
                    isirreducible(w, rws) || (ok = false; break)
                end
            end
        end
        ok && push!(rsides, lhs)
    end
    return rsides
end

"""
    simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
Simplifies both sides of the rule if they start with an invertible word.
"""
function simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
    common_prefix=0
    for (l, r) in zip(lhs,rhs)
        l != r && break
        hasinverse(l, A) || break
        common_prefix += 1
    end

    common_suffix=0
    for (l,r) in Iterators.reverse(zip(lhs, rhs))
        l != r && break
        hasinverse(l , A) || break
        common_suffix += 1
    end

    if !(iszero(common_prefix) && iszero(common_suffix))
        # @debug "Simplifying rule" length(lhs) length(rhs) common_prefix common_suffix
        sc_o = common_prefix + 1
        del_len = common_prefix + common_suffix

        copyto!(lhs, 1, lhs, sc_o, length(lhs) - del_len)
        copyto!(rhs, 1, rhs, sc_o, length(rhs) - del_len)

        resize!(lhs, length(lhs) - del_len)
        resize!(rhs, length(rhs) - del_len)
    end

    return lhs, rhs
end

function Base.show(io::IO, rws::RewritingSystem)
    println(io, "Rewriting System with $(length(rules(rws))) rules ordered by $(ordering(rws)):")
    for (i, (lhs, rhs)) in enumerate(rules(rws))
        act = isactive(rws, i) ? "✓" : " "
        print(io, lpad("$i", 4, " "), " $act ")
        print_repr(io, lhs, alphabet(rws))
        print(io, "\t → \t")
        print_repr(io, rhs, alphabet(rws))
        println(io, "")
    end
end
