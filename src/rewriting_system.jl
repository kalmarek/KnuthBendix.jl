"""
    RewritingSystem{W<:AbstractWord, O<:Ordering}
RewritingSystem written as a list of Rules (ordered pairs) of `Word`s together with the ordering.
"""
struct RewritingSystem{W<:AbstractWord,O<:Ordering}
    rwrules::Vector{Rule{W}}
    order::O
end

function RewritingSystem(
    rwrules::Vector{Pair{W,W}},
    order::O;
    bare = false,
) where {W<:AbstractWord,O<:Ordering}
    if length(alphabet(order)) > Words._max_alphabet_length(W)
        throw("Type $W can not store words over $(alphabet(order)).")
    end

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
word_type(s::RewritingSystem{W}) where {W} = W

function Base.push!(
    rws::RewritingSystem{W},
    t::Tuple{<:AbstractWord,AbstractWord},
) where {W}
    return push!(rws, Rule{W}(t..., ordering(rws)))
end
Base.push!(rws::RewritingSystem, r::Rule) = (push!(rws.rwrules, r); rws)

Base.empty!(s::RewritingSystem) = (empty!(s.rwrules); s)
function Base.empty(s::RewritingSystem{W}, o::Ordering = ordering(s)) where {W}
    return RewritingSystem(Rule{W}[], o)
end
Base.isempty(s::RewritingSystem) = isempty(rules(s))

remove_inactive!(rws::RewritingSystem) = (filter!(isactive, rws.rwrules); rws)

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rws::RewritingSystem)
Rewrite word `w` storing the result in `v` by left using rewriting rules of
rewriting system `rws`. See [Sims, p.66]
"""
@inline function rewrite_from_left!(
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
                # since suffixes of v has been already checked against rws we
                # can break here
                break
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
