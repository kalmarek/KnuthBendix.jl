abstract type AbstractBufferPair{T} end

"""
    struct BufferPair{T}  <: AbstractBufferPair{T}
A helper struct used to store pair of `BufferWord` used for rewriting.
`BufferPair`s are used in conjunction with `kbWork` struct.
"""
struct BufferPair{T} <: AbstractBufferPair{T}
    _vWord::BufferWord{T}
    _wWord::BufferWord{T}
end

BufferPair{T}() where {T} = BufferPair(one(BufferWord{T}), one(BufferWord{T}))

get_v_word(bp::BufferPair) = bp._vWord
get_w_word(bp::BufferPair) = bp._wWord

"""
    function rewrite_from_left(u::W, bp::BufferPair, rewriting)
Rewrites a word from left using buffer words from `BufferPair` declared in `kbWork`
object and `rewriting` object. The `rewriting` object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to successfully
rewrite `u`.
Important: this implementation returns an instance of `BufferWord`!
"""
function rewrite_from_left!(bp::BufferPair, u::W, rewriting) where {W<:AbstractWord}
    isempty(rewriting) && (resize!(bp._vWord, length(u)); copyto!(bp._vWord, u); return bp._vWord)
    empty!(bp._vWord)
    resize!(bp._wWord, length(u))
    copyto!(bp._wWord, u)
    v = rewrite_from_left!(bp._vWord, bp._wWord, rewriting)
    return v
end

mutable struct kbWork{T}
    lhsPair::BufferPair{T}
    rhsPair::BufferPair{T}
end

kbWork{T}() where {T} = kbWork(BufferPair{T}(), BufferPair{T}())
