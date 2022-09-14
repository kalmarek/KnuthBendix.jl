struct BufferPair{T,S}
    _vWord::Words.BufferWord{T}
    _wWord::Words.BufferWord{T}
    history_tape::Vector{S}
end

function BufferPair{T}(history_tape::AbstractVector) where {T}
    BW = Words.BufferWord{T}
    return BufferPair(one(BW), one(BW), history_tape)
end

BufferPair{T}() where {T} = BufferPair{T}(Int[])

@inline function Words.store!(
    bufpair::BufferPair,
    a::AbstractWord,
    rhs₂::AbstractWord,
    rhs₁::AbstractWord,
    c::AbstractWord,
)
    a_rhs₂ = let Q = Words.store!(bufpair._vWord, a)
        append!(Q, rhs₂)
    end

    rhs₁_c = let Q = Words.store!(bufpair._wWord, rhs₁)
        append!(Q, c)
    end

    return rhs₁_c, a_rhs₂
end

"""
    function rewrite_from_left!(bp::BufferPair, u::AbstractWord, rewriting)
Rewrites a word from left using buffer words from `BufferPair` and `rewriting` object.

Note: this implementation returns an instance of `Words.BufferWord` aliased with the
intenrals of `BufferPair`.
"""
function rewrite_from_left!(bp::BufferPair, u::AbstractWord, rewriting)
    if isempty(rewriting)
        Words.store!(bp._vWord, u)
        return bp._vWord
    end
    empty!(bp._vWord)
    Words.store!(bp._wWord, u)
    v = _rewrite_from_left!(
        bp._vWord,
        bp._wWord,
        rewriting;
        history_tape = bp.history_tape,
    )
    empty!(bp._wWord) # shifts bp._wWord pointers to the beginning of its storage
    return v
end

function _rewrite_from_left!(
    u::AbstractWord,
    v::AbstractWord,
    rewriting;
    history_tape,
)
    return rewrite_from_left!(u, v, rewriting)
end
function _rewrite_from_left!(
    u::AbstractWord,
    v::AbstractWord,
    idxA::IndexAutomaton;
    history_tape,
)
    return rewrite_from_left!(u, v, idxA; history_tape = history_tape)
end

struct Workspace{T,H}
    iscritical_1p::BufferPair{T,H}
    iscritical_2p::BufferPair{T,H}
    find_critical_p::BufferPair{T,H}
end

function Workspace{T}(S::Type) where {T}
    return (BP = BufferPair{T}; Workspace(BP(S[]), BP(S[]), BP(S[])))
end
Workspace(::RewritingSystem{W}) where {W} = Workspace{eltype(W)}(Int)
function Workspace(::RewritingSystem{W}, ::Automaton{S}) where {W,S}
    return Workspace{eltype(W)}(S)
end

struct Settings
    """Terminate Knuth-Bendix completion if the number of rules exceeds `max_rules`."""
    max_rules::Int
    """Reduce the rws and update the indexing automaton whenever the stack
    of newly discovered rules exceeds `stack_size`.
    Note: this is only a hint."""
    stack_size::Int
    """Consider only new rules of lhs which does not exceed `max_length_lhs`."""
    max_length_lhs::Int
    """Consider only the new rules of rhs which does not exceed `max_length_rhs`."""
    max_length_rhs::Int
    """When finding critical pairs consider overlaps of length at most `max_overlap_length`."""
    max_lenght_overlap::Int
    """Specifies the level of verbosity"""
    verbosity::Int

    function Settings(;
        max_rules = 10000,
        stack_size = 100,
        max_length_lhs = 0,
        max_length_rhs = 0,
        max_length_overlap = 0,
        verbosity = 0,
    )
        return new(
            max_rules,
            stack_size,
            max_length_lhs,
            max_length_rhs,
            max_length_overlap,
            verbosity,
        )
    end
end
