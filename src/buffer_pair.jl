struct RewritingBuffer{T,V<:AbstractVector}
    output::Words.BufferWord{T}
    input::Words.BufferWord{T}
    history::V
end

function RewritingBuffer{T}(history::AbstractVector) where {T}
    BW = Words.BufferWord{T}
    return RewritingBuffer(one(BW), one(BW), history)
end

RewritingBuffer{T}() where {T} = RewritingBuffer{T}(Int[])

function Words.store!(rwbuf::RewritingBuffer, u::AbstractWord...)
    Words.store!(rwbuf.input, u...)
    return rwbuf
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
function rewrite!(bp::RewritingBuffer, rewriting; kwargs...)
    v = if isempty(rewriting)
        Words.store!(bp.output, bp.input)
    else
        rewrite!(bp.output, bp.input, rewriting; history = bp.history, kwargs...)
    end
    empty!(bp.input) # shifts bp._wWord pointers to the beginning of its storage
    return v
end
