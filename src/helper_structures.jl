struct BufferPair{T,V<:AbstractVector}
    _vWord::Words.BufferWord{T}
    _wWord::Words.BufferWord{T}
    history::V
end

function BufferPair{T}(history::AbstractVector) where {T}
    BW = Words.BufferWord{T}
    return BufferPair(one(BW), one(BW), history)
end

BufferPair{T}() where {T} = BufferPair{T}(Int[])

Words.store!(bp::BufferPair, u::AbstractWord) = Words.store!(bp._wWord, u)

@inline function Words.store!(
    bufpair::BufferPair,
    ws::Tuple,
    vs::Tuple,
)
    Q = append!(empty!(bufpair._vWord), ws...)
    P = append!(empty!(bufpair._wWord), vs...)
    return Q, P
end

"""
    function rewrite!(bp::BufferPair, rewriting; kwargs...)
Rewrites word stored in `BufferPair` using `rewriting` object.

To store a word in `bp`
[`Words.store!`](@ref Words.store!(::BufferPair, ::AbstractWord))
should be used.

!!! warning
    This implementation returns an instance of `Words.BufferWord` aliased with
    the intenrals of `BufferPair`. You need to copy the return value if you
    want to take the ownership.
"""
function rewrite!(bp::BufferPair, rewriting; kwargs...)
    v = if isempty(rewriting)
        Words.store!(bp._vWord, bp._wWord)
    else
        rewrite!(bp._vWord, bp._wWord, rewriting; history = bp.history, kwargs...)
    end
    empty!(bp._wWord) # shifts bp._wWord pointers to the beginning of its storage
    return v
end

function _rewrite!(u::AbstractWord, v::AbstractWord, rewriting; history)
    return rewrite!(u, v, rewriting)
end
function _rewrite!(
    u::AbstractWord,
    v::AbstractWord,
    idxA::IndexAutomaton;
    history,
)
    return rewrite!(u, v, idxA; history = history)
end

mutable struct Workspace{T,H}
    iscritical_1p::BufferPair{T,H}
    iscritical_2p::BufferPair{T,H}
    find_critical_p::BufferPair{T,H}
    confluence_timer::Int
end

function Workspace{T}(VS::Type{<:AbstractVector}) where {T}
    BP = BufferPair{T}
    return Workspace(BP(VS()), BP(VS()), BP(VS()), 0)
end
Workspace(::RewritingSystem{W}) where {W} = Workspace{eltype(W)}(Vector{Int})
function Workspace(at::Automata.IndexAutomaton{S}) where {S}
    return Workspace{eltype(word_type(at))}(Vector{S})
end

mutable struct Settings
    """Terminate Knuth-Bendix completion if the number of rules exceeds `max_rules`."""
    max_rules::Int
    """Reduce the rws and update the indexing automaton whenever the stack
    of newly discovered rules exceeds `stack_size`.
    Note: this is only a hint."""
    stack_size::Int
    """
    Attempt a confluence check whenever no new rules are added to stack after
    `confluence_delay` iterations in the `knuthbendix` main loop.
    """
    confluence_delay::Int
    """Consider only new rules of lhs which does not exceed `max_length_lhs`."""
    max_length_lhs::Int
    """Consider only the new rules of rhs which does not exceed `max_length_rhs`."""
    max_length_rhs::Int
    """When finding critical pairs consider overlaps of length at most `max_overlap_length`."""
    max_lenght_overlap::Int
    """Specifies the level of verbosity"""
    verbosity::Int
    update_progress::Any

    function Settings(;
        max_rules = 10000,
        stack_size = 100,
        confluence_delay = 10,
        max_length_lhs = 0,
        max_length_rhs = 0,
        max_length_overlap = 0,
        verbosity = 0,
    )
        return new(
            max_rules,
            stack_size,
            confluence_delay,
            max_length_lhs,
            max_length_rhs,
            max_length_overlap,
            verbosity,
            (args...) -> nothing,
        )
    end
end
