"""
    RewritingBuffer{T}()
    RewritingBuffer{T}(history::AbstractVector)
A pair of [`BufferWords`](@ref Words.BufferWord) used for efficient rewriting of words with letters of type {T}.

Additional `history` may be passed to construct a buffer for rewriting with
an appropriate automaton. See methods of [`rewrite!`](@ref).
"""
struct RewritingBuffer{T,V<:AbstractVector}
    output::Words.BufferWord{T}
    input::Words.BufferWord{T}
    history::V

    function RewritingBuffer{T}(
        output::BW,
        input::BW,
        history::AbstractVector,
    ) where {T,BW<:Words.BufferWord{T}}
        return new{T,typeof(history)}(output, input, history)
    end

    function RewritingBuffer{T}(
        output::BW,
        input::BW,
    ) where {T,BW<:Words.BufferWord{T}}
        return new{T,Vector{Int}}(output, input)
    end
end

function RewritingBuffer{T}() where {T}
    BW = Words.BufferWord{T}
    return RewritingBuffer{T}(one(BW), one(BW))
end

function RewritingBuffer{T}(history::AbstractVector) where {T}
    BW = Words.BufferWord{T}
    return RewritingBuffer{T}(one(BW), one(BW), history)
end

function Words.store!(rwbuf::RewritingBuffer, u::AbstractWord...)
    Words.store!(rwbuf.input, u...)
    return rwbuf
end
