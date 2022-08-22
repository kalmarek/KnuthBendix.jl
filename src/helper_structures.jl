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
    return v
end

mutable struct kbWork{T}
    lhsPair::BufferPair{T}
    rhsPair::BufferPair{T}
    tmpPair::BufferPair{T}
end

kbWork{T}() where {T} = (BP = BufferPair{T}; kbWork(BP(), BP(), BP()))
kbWork(::RewritingSystem{W}) where {W} = kbWork{eltype(W)}()
