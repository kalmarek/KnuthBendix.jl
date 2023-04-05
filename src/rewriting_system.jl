"""
    RewritingSystem{W<:AbstractWord, O<:Ordering}
RewritingSystem written as a list of Rules (ordered pairs) of `Word`s together with the ordering.
"""
struct RewritingSystem{W<:AbstractWord,A,O<:Ordering}
    rwrules::Vector{Rule{W,A}}
    order::O
end

function RewritingSystem(
    rwrules::AbstractVector{Pair{W,W}},
    order::O;
    bare = false,
) where {W<:AbstractWord,O<:Ordering}
    if length(alphabet(order)) > Words._max_alphabet_length(W)
        throw("Type $W can not store words over $(alphabet(order)).")
    end

    # add rules from the alphabet
    rls = rules(W, order)
    rls = bare ? empty!(rls) : rls
    # properly orient rwrules
    append!(
        rls,
        [
            Rule{W}(
                simplify!(deepcopy(a), deepcopy(b), order, balance = true)...,
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
function Base.empty(s::RewritingSystem, o::Ordering = ordering(s))
    return RewritingSystem(empty(s.rwrules), o)
end
Base.isempty(s::RewritingSystem) = isempty(rules(s))

remove_inactive!(rws::RewritingSystem) = (filter!(isactive, rws.rwrules); rws)

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
    print(io, "Rewriting System ordered by $(ordering(rws)):")
    at_most = first(displaysize(io)) - 3
    rwrules = Iterators.take(rules(rws), at_most)
    A = alphabet(rws)
    lhs_maxl = mapreduce(max, rwrules, init = 10) do rule
        (lhs, rhs) = rule
        return length(sprint(print_repr, lhs, A))
    end
    pad_len = min(lhs_maxl, last(displaysize(io)) ÷ 2)

    printed_rules = 0
    for (idx, rule) in enumerate(rwrules)
        println(io)
        _print_rule(io, idx, rule, A, pad_by = pad_len)
        printed_rules += 1
    end

    total_rules = mapreduce((x) -> 1, +, rules(rws))
    if total_rules > printed_rules
        println(io, '\n', lpad('⋮', 18))
        print(io, "(contains $(total_rules - printed_rules) additional rules)")
    end
end

function _print_rule(io::IO, i, rule, A; pad_by = 10)
    (lhs, rhs) = rule
    print(io, i, ". ", rpad(sprint(print_repr, lhs, A), pad_by))
    print(io, "\t → \t")
    return print_repr(io, rhs, A)
end
