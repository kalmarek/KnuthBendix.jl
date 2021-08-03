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
function rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Rule)
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

abstract type AbstractRewritingSystem{W, O} end

"""
    RewritingSystem{W<:AbstractWord, O<:WordOrdering}
RewritingSystem written as a list of Rules (ordered pairs) of `Word`s together with the ordering.
"""
struct RewritingSystem{W<:AbstractWord, O<:WordOrdering} <: AbstractRewritingSystem{W, O}
    rwrules::Vector{Rule{W}}
    order::O
end

function RewritingSystem(rwrules::Vector{Pair{W,W}}, order::O; bare=false) where
    {W<:AbstractWord, O<:WordOrdering}
    @assert length(alphabet(order)) <= _max_alphabet_length(W) "Type $W can not store words over $(alphabet(order))."

    # add rules from the alphabet
    rls = bare ? Rule{W}[] : rules(W, order)
    # properly orient rwrules
    append!(rls, [Rule{W}(a, b, order) for (a, b) in rwrules])

    return RewritingSystem(rls, order)
end

rules(s::RewritingSystem) = Iterators.filter(isactive, s.rwrules)
ordering(s::RewritingSystem) = s.order
alphabet(s::RewritingSystem) = alphabet(ordering(s))

Base.push!(s::RewritingSystem{W}, r::Rule{W}) where W = (push!(s.rwrules, r); s)
Base.empty!(s::RewritingSystem) = (empty!(s.rwrules); s)
Base.empty(s::RewritingSystem{W},o::WordOrdering = ordering(s)) where W =
    RewritingSystem(Rule{W}[], o)
Base.isempty(s::RewritingSystem) = isempty(rules(s))

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
        for (lhs, rhs) in rules(rws)

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
    rls = collect(rules(rws))
    println(io, "Rewriting System with $(length(rls)) active rules ordered by $(ordering(rws)):")
    height = first(displaysize(io))
    A = alphabet(rws)
    if height > length(rls)
        for (i, rule) in enumerate(rls)
            _print_rule(io, i, rule, A)
        end
    else
        for i in 1:height-5
            rule = rls[i]
            _print_rule(io, i, rule, A)
        end

        println(io, "⋮")
        for i in (length(rls)-4):length(rls)
            rule = rls[i]
            _print_rule(io, i, rule, A)
        end
    end
end

function _print_rule(io::IO, i, rule, A)
    (lhs, rhs) = rule
    print(io, i, ". ")
    print_repr(io, lhs, A)
    print(io, "\t → \t")
    print_repr(io, rhs, A)
    println(io, "")
end
