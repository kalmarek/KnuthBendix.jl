abstract type AbstractRewritingSystem{W<:AbstractWord} end

"""
    alphabet(rws::AbstractRewritingSystem)
Return the underlying `Alphabet` of the rewriting system.
"""
alphabet(rws::AbstractRewritingSystem) = alphabet(ordering(rws))
word_type(::AbstractRewritingSystem{W}) where {W} = W

"""
    isirreducible(w::AbstractWord, rws::RewritingSystem)
Returns whether a word is irreducible with respect to a given rewriting system
"""
function isirreducible(w::AbstractWord, rws::AbstractRewritingSystem)
    return !any(r -> occursin(first(r), w), rules(rws))
end

"""
    rules(rws::AbstractRewritingSystem)
Return the iterator over **active** rewriting rules.
"""
function rules(rws::AbstractRewritingSystem)
    return Iterators.filter(isactive, __rawrules(rws))
end
nrules(rws::AbstractRewritingSystem) = count(isactive, __rawrules(rws))

Base.isempty(rws::AbstractRewritingSystem) = !any(isactive, __rawrules(rws))

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

Tables.istable(::Type{<:AbstractRewritingSystem}) = true

Tables.rowaccess(::Type{<:AbstractRewritingSystem}) = true
Tables.rows(rws::AbstractRewritingSystem) = __rawrules(rws)

# Tables.getcolumn(r::Rule, i::Integer) = (t = (lhs, rhs) = r; t[i])
Tables.columnnames(::Rule) = (:lhs, :rhs)
Base.getindex(r::Rule, s::Symbol) = getfield(r, s)

function Base.show(io::IO, ::MIME"text/plain", rws::AbstractRewritingSystem)
    hl_odd = PrettyTables.Highlighter(
        f = (rule, i, j) -> i % 2 == 0,
        crayon = PrettyTables.Crayon(;
            foreground = :dark_gray,
            negative = true,
        ),
    )
    if isreduced(rws)
        print(io, "reduced")
        print(io, isconfluent(rws) ? ", " : " ")
    end
    if isconfluent(rws)
        print(io, "confluent ")
    end
    println(
        io,
        "rewriting system with ",
        nrules(rws),
        " active rules.\n",
        "rewriting ordering: ",
        ordering(rws),
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

"""
    RewritingSystem{W<:AbstractWord, O<:Ordering}
    RewritingSystem(rwrules::Vector{Pair{W,W}}, order[; confluent=false, reduced=false])
`RewritingSystem` holds the list of ordered (by `order`) rewriting rules of `W<:AbstractWord`s.
"""
mutable struct RewritingSystem{W<:AbstractWord,O<:Ordering} <:
               AbstractRewritingSystem{W}
    rules_orig::Vector{Rule{W}}
    rules_alphabet::Vector{Rule{W}}
    rwrules::Vector{Rule{W}}
    order::O
    confluent::Bool
    reduced::Bool
end

function RewritingSystem(
    rwrules::AbstractVector{<:Rule{W}},
    order::RewritingOrdering;
    confluent::Bool = false,
    reduced::Bool = false,
) where {W}
    return RewritingSystem(
        rwrules,
        rules(W, order),
        deepcopy(rwrules),
        order,
        confluent,
        reduced,
    )
end

function RewritingSystem(
    rwrules::Vector{Tuple{W,W}},
    order::RewritingOrdering;
    confluent::Bool = false,
    reduced::Bool = false,
) where {W<:AbstractWord}
    if length(alphabet(order)) > Words._max_alphabet_length(W)
        throw("Type $W can not store words over $(alphabet(order)).")
    end

    rules_orig = [Rule{W}(a, b, order) for (a, b) in rwrules]
    rules_alphabet = rules(W, order)
    rls = deepcopy(rules_alphabet)
    append!(
        rls,
        [
            Rule{W}(
                Pair(simplify!(copy(a), copy(b), order, balance = true)...),
            ) for (a, b) in rwrules
        ],
    )

    return RewritingSystem(
        rules_orig,
        rules_alphabet,
        rls,
        order,
        confluent,
        reduced,
    )
end

__rawrules(rws::RewritingSystem) = rws.rwrules

"""
    ordering(rws::RewritingSystem)
Return the ordering of the rewriting system.
"""
ordering(rws::RewritingSystem) = rws.order

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
        if isempty(check_confluence(rws))
            rws.confluent = true
        end
    end
    return rws.confluent
end

Base.push!(rws::RewritingSystem, r::Rule) = (push!(rws.rwrules, r); rws)
Base.empty!(s::RewritingSystem) = (empty!(s.rwrules); s)
function Base.empty(s::RewritingSystem{W}, o::Ordering = ordering(s)) where {W}
    return RewritingSystem(Rule{W}[], o)
end

remove_inactive!(rws::RewritingSystem) = (filter!(isactive, rws.rwrules); rws)

"""
    reduce!(rws::RewritingSystem[, work=Workspace(rws); kwargs...])
Reduce the rewriting system in-place using the default algorithm

Currently the default algorithm is KBStack(), see
[`reduce!(::KBStack, ...)`](@ref
reduce!(::KBStack, ::RewritingSystem, work::Workspace)).
"""
function reduce!(
    rws::RewritingSystem,
    work::Workspace = Workspace(rws);
    kwargs...,
)
    rws = reduce!(KBStack(), rws, work; kwargs...)
    remove_inactive!(rws)
    return rws
end
