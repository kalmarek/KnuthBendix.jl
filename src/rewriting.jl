"""
    rewrite_from_left(u::AbstractWord, rewriting)
Rewrites word `u` (from left) using `rewriting` object. The object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)`.
"""
function rewrite_from_left(
    u::W,
    rewriting,
    vbuff = BufferWord{T}(0, length(u)),
    wbuff = BufferWord{T}(length(u), 0),
) where {T,W<:AbstractWord{T}}
    isempty(rewriting) && return u
    store!(wbuff, u)
    v = rewrite_from_left!(vbuff, wbuff, rewriting)
    return W(v)
end

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, ::Any)
Trivial rewrite: word `w` is simply stored (copied) to `v`.
"""
rewrite_from_left!(v::AbstractWord, w::AbstractWord, ::Any) = store!(v, w)

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Rule)
Rewrite word `w` storing the result in `v` by using a single rewriting `rule`.
"""
function rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Rule)
    v = resize!(v, 0)
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
Rewrite word `w` storing the result in `v` by applying free reductions as
defined by the inverses present in alphabet `A`.
"""
function rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Alphabet)
    v = resize!(v, 0)
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

abstract type AbstractRewritingSystem{W,O} end

"""
    RewritingSystem{W<:AbstractWord, O<:WordOrdering}
RewritingSystem written as a list of Rules (ordered pairs) of `Word`s together with the ordering.
"""
struct RewritingSystem{W<:AbstractWord,O<:WordOrdering} <:
       AbstractRewritingSystem{W,O}
    rwrules::Vector{Rule{W}}
    order::O
end

function RewritingSystem(
    rwrules::Vector{Pair{W,W}},
    order::O;
    bare = false,
) where {W<:AbstractWord,O<:WordOrdering}
    @assert length(alphabet(order)) <= _max_alphabet_length(W) "Type $W can not store words over $(alphabet(order))."

    # add rules from the alphabet
    rls = bare ? Rule{W}[] : rules(W, order)
    # properly orient rwrules
    append!(
        rls,
        [
            Rule{W}(
                simplifyrule!(
                    deepcopy(a),
                    deepcopy(b),
                    order,
                    balance = true,
                )...,
                order,
            ) for (a, b) in rwrules
        ],
    )

    return RewritingSystem(rls, order)
end

rules(s::RewritingSystem) = Iterators.filter(isactive, s.rwrules)
ordering(s::RewritingSystem) = s.order
alphabet(s::RewritingSystem) = alphabet(ordering(s))

function Base.push!(s::RewritingSystem{W}, r::Rule{W}) where {W}
    return (push!(s.rwrules, r); s)
end
Base.empty!(s::RewritingSystem) = (empty!(s.rwrules); s)
function Base.empty(
    s::RewritingSystem{W},
    o::WordOrdering = ordering(s),
) where {W}
    return RewritingSystem(Rule{W}[], o)
end
Base.isempty(s::RewritingSystem) = isempty(rules(s))

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rws::RewritingSystem)
Rewrite word `w` storing the result in `v` by left using rewriting rules of
rewriting system `rws`. See [Sims, p.66]
"""
function rewrite_from_left!(
    v::AbstractWord,
    w::AbstractWord,
    rws::RewritingSystem,
)
    v = resize!(v, 0)
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
    return !any(r -> occursin(first(r), w), rules(rws))
end

"""
    subwords(w::AbstractWord[, minlength=1, maxlength=length(w)])
Return an iterator over all `SubWord`s of `w` of length between `minlength` and `maxlength`.
"""
function subwords(w::AbstractWord, minlength = 1, maxlength = length(w))
    n = length(w)
    return (
        @view(w[i:j]) for i in 1:n for
        j in i:n if minlength <= j - i + 1 <= maxlength
    )
end

"""
    irreduciblesubsystem(rws::RewritingSystem)
Return an array of left sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function irreduciblesubsystem(rws::RewritingSystem{W}) where {W}
    lsides = W[]
    for rule in rws.rwrules
        lhs = first(rule)
        length(lhs) >= 2 || break
        for sw in subwords(lhs, 2, length(lhs) - 1)
            if !isirreducible(sw, rws)
                @debug "subword $sw of $lhs is reducible. skipping!"
                break
            end
        end
        if all(sw -> isirreducible(sw, rws), subwords(lhs, 2, length(lhs) - 1))
            @debug "all subwords are irreducible; pushing $lhs"
            push!(lsides, lhs)
        end
    end
    return unique!(lsides)
end

"""
    simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
Simplifies both sides of the rule if they start/end with the same invertible word.
"""
function simplifyrule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
    common_suffix = 0
    k = min(length(lhs), length(rhs))
    @inbounds for i in 0:k-1
        l, r = lhs[end-i], rhs[end-i]
        l != r && break
        hasinverse(l, A) || break
        common_suffix += 1
    end

    if !iszero(common_suffix)
        resize!(lhs, length(lhs) - common_suffix)
        resize!(rhs, length(rhs) - common_suffix)
    end

    common_prefix = 0
    for (l, r) in zip(lhs, rhs)
        l != r && break
        hasinverse(l, A) || break
        common_prefix += 1
    end

    if !iszero(common_prefix)
        copyto!(lhs, 1, lhs, common_prefix + 1, length(lhs) - common_prefix)
        copyto!(rhs, 1, rhs, common_prefix + 1, length(rhs) - common_prefix)
        resize!(lhs, length(lhs) - common_prefix)
        resize!(rhs, length(rhs) - common_prefix)
    end

    return lhs, rhs
end

function balancerule!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
    while length(lhs) > 2 && length(lhs) > length(rhs)
        hasinverse(last(lhs), A) || break
        push!(rhs, inv(A, pop!(lhs)))
    end

    while length(lhs) > 2 && length(lhs) > length(rhs)
        hasinverse(first(lhs), A) || break
        pushfirst!(rhs, inv(A, popfirst!(lhs)))
    end

    return lhs, rhs
end

function simplifyrule!(
    lhs::AbstractWord,
    rhs::AbstractWord,
    o::Ordering;
    balance = false,
)
    lhs, rhs = simplifyrule!(lhs, rhs, alphabet(o))
    if balance
        lhs, rhs = balancerule!(lhs, rhs, alphabet(o))
    end

    return lhs, rhs
end

function Base.show(io::IO, rws::RewritingSystem)
    rls = collect(rules(rws))
    println(
        io,
        "Rewriting System with $(length(rls)) active rules ordered by $(ordering(rws)):",
    )
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
    return println(io, "")
end
