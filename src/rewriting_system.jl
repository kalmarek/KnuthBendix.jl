"""
    RewritingSystem{W<:AbstractWord, O<:Ordering}
    RewritingSystem(rwrules::Vector{Pair{W,W}}, order, bare=false)
`RewritingSystem` holds the list of ordered (by `order`) rewriting rules of `W<:AbstractWord`s.
"""
struct RewritingSystem{W<:AbstractWord,O<:Ordering}
    rwrules::Vector{Rule{W}}
    order::O
    confluent::Bool
    reduced::Bool
end

function RewritingSystem(
    rwrules::Vector{Pair{W,W}},
    order::O;
    confluent = false,
    reduced = false,
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

    return RewritingSystem(
        rls,
        order,
        confluent,
        reduced,
    )
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

Base.push!(rws::RewritingSystem, r::Rule) = (push!(rws.rwrules, r); rws)

"""
    isreduced(rws::RewritingSystem)
Check whether the rewriting system knows its reducedness.

!!! note
    Rewriting systems assume non-reducedness at creation. [`knuthbendix`](@ref)
    will always return reduced rewriting system, unless manually interrupted.
"""
isreduced(rws::RewritingSystem) = rws.reduced

"""
    isconfluent(rws::RewritingSystem)
Check whether the rewriting system is confluent.

!!! note
    Since [`check_confluence`](@ref) is relatively cheap only for **reduced**
    rewriting systems `isconfluent` will not try to reduce the system on its
    own and will return `false`. For definitive answer one should
    [`reduce!`](@ref) the rewrting system before calling `isconfluent`.
"""
function isconfluent(rws::RewritingSystem)
    if !rws.confluent && isreduced(rws)
        stack, _ = check_confluence(rws)
        if isempty(stack)
            rws.confluent = true
        end
    end
    return rws.confluent
end

Base.empty!(s::RewritingSystem) = (empty!(s.rwrules); s)
function Base.empty(s::RewritingSystem{W}, o::Ordering = ordering(s)) where {W}
    return RewritingSystem(Rule{W}[], o)
end
Base.isempty(s::RewritingSystem) = nrules(s) == 0

remove_inactive!(rws::RewritingSystem) = (filter!(isactive, rws.rwrules); rws)

"""
    isirreducible(w::AbstractWord, rws::RewritingSystem)
Returns whether a word is irreducible with respect to a given rewriting system
"""
function isirreducible(w::AbstractWord, rws::RewritingSystem)
    return !any(r -> occursin(first(r), w), rules(rws))
end

## IO, i.e. Tables.jl interface

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
