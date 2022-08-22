struct BufferPair{T}
    _vWord::BufferWord{T}
    _wWord::BufferWord{T}
end

BufferPair{T}() where {T} = BufferPair(one(BufferWord{T}), one(BufferWord{T}))

"""
    function rewrite_from_left!(bp::BufferPair, u::AbstractWord, rewriting)
Rewrites a word from left using buffer words from `BufferPair` and `rewriting` object.

Note: this implementation returns an instance of `BufferWord`!
"""
function rewrite_from_left!(bp::BufferPair, u::AbstractWord, rewriting)
    if isempty(rewriting)
        store!(bp._vWord, u)
        return bp._vWord
    end
    empty!(bp._vWord)
    store!(bp._wWord, u)
    v = rewrite_from_left!(bp._vWord, bp._wWord, rewriting)
    empty!(bp._wWord)
    return v
end

mutable struct kbWork{T}
    lhsPair::BufferPair{T}
    rhsPair::BufferPair{T}
    tmpPair::BufferPair{T}
end

kbWork{T}() where {T} = (BP = BufferPair{T}; kbWork(BP(), BP(), BP()))
kbWork(::RewritingSystem{W}) where {W} = kbWork{eltype(W)}()

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
