"""
    RewritingSystem{W<:AbstractWord, O<:Ordering}
    RewritingSystem(rwrules::Vector{Pair{W,W}}, order, bare=false)
`RewritingSystem` holds the list of ordered (by `order`) rewriting rules of `W<:AbstractWord`s.
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
                simplify!(deepcopy(a), deepcopy(b), order, balance = true)...,
                order,
            ) for (a, b) in rwrules
        ],
    )

    return RewritingSystem(rls, order)
end

"""
    rules(rws::RewritingSystem)
Return the iterator over **active** rewriting rules.
"""
rules(rws::RewritingSystem) = Iterators.filter(isactive, rws.rwrules)
nrules(rws::RewritingSystem) = count(isactive, rws.rwrules)
"""
    ordering(rws::RewritingSystem)
Return the ordering of the rewriting system.
"""
ordering(rws::RewritingSystem) = rws.order
"""
    alphabet(rws::RewritingSystem)
Return the underlying `Alphabet` of the rewriting system.
"""
alphabet(rws::RewritingSystem) = alphabet(ordering(rws))
word_type(::RewritingSystem{W}) where {W} = W

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


function _print_rule(io::IO, i, rule, A)
    (lhs, rhs) = rule
    print(io, i, ". ")
    print_repr(io, lhs, A)
    print(io, "\t → \t")
    print_repr(io, rhs, A)
    return
end

using Tables
import PrettyTables

Tables.istable(::Type{<:RewritingSystem}) = true

Tables.rowaccess(::Type{<:RewritingSystem}) = true
Tables.rows(rws::RewritingSystem) = rws.rwrules

# Tables.getcolumn(r::Rule, i::Integer) = (t = (lhs, rhs) = r; t[i])
Tables.columnnames(::Rule) = (:lhs, :rhs)
Base.getindex(r::Rule, s::Symbol) = getfield(r, s)

function Base.show(io::IO, ::MIME"text/plain", rws::RewritingSystem)
    hl_odd = PrettyTables.Highlighter(
        f = (rule, i, j) -> i % 2 == 0,
        crayon = PrettyTables.Crayon(;
            foreground = :dark_gray,
            negative = true,
        ),
    )
    println(
        io,
        "Rewriting System with $(nrules(rws)) active rules ordered by $(ordering(rws)):",
    )

    return PrettyTables.pretty_table(
        io,
        rws,
        show_row_number = true,
        row_number_column_title = "Rule",
        formatters = (w, args...) -> sprint(print_repr, w, alphabet(rws)),
        autowrap = true,
        linebreaks = true,
        reserved_display_lines = 3[],
        columns_width = displaysize(io)[2] ÷ 2 - 8,
        # vcrop_mode = :middle,
        # equal_columns_width = true,
        # crop = :vertical,
        ellipsis_line_skip = 1,
        alignment = [:r, :l],
        highlighters = hl_odd,
    )
end
