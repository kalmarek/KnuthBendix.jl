abstract type AbstractBufferPair{T} end

"""
    struct BufferPair{T}  <: AbstractBufferPair{T}
A helper struct used to store pair of `BufferWord` used for rewriting.
`BufferPair`s are used in conjucntion with `kbWork` struct.
"""
struct BufferPair{T} <: AbstractBufferPair{T}
    _vWord::BufferWord{T}
    _wWord::BufferWord{T}
end

BufferPair{T}() where {T} = BufferPair(one(BufferWord{T}), one(BufferWord{T}))

get_v_word(bp::BufferPair) = wrk._vWord
get_w_word(bp::BufferPair) = wrk._wWord

"""
    function rewrite_from_left(u::W, bp::BufferPair, rewriting)
Rewrites a word from left using buffer words from `BufferPair` declared in `kbWork`
object and `rewriting` object. The `rewriting` object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to succesfully
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

"""
    mutable struct kbWork{T}
Helper structure used to iterate over rewriting system in Knuth-Bendix procedure.
`i` field is the iterator over the outer loop and `j` is the iterator over the
inner loop. `lhsPair` and `rhsPair` are inner `BufferPair`s used for rewriting.
`_inactiverules` is just a list of inactive rules in the `RewritingSystem`
subjected to Knuth-Bendix procedure.
"""
mutable struct kbWork{T}
    i::Int
    j::Int
    lhsPair::BufferPair{T}
    rhsPair::BufferPair{T}
    _inactiverules::Vector{Int}
end

kbWork{T}(i::Int, j::Int) where {T} = kbWork(i, j, BufferPair{T}(), BufferPair{T}(), Int[])

get_i(wrk::kbWork) = wrk.i
get_j(wrk::kbWork) = wrk.j
inactiverules(wrk::kbWork) = wrk._inactiverules
hasinactiverules(wrk::kbWork) = !isempty(wrk._inactiverules)

"""
    function removeinactive!(rws::RewritingSystem, work::kbWork)
Function removing inactive rules from the given `RewritingSystem` and updating
indices used to iterate in Knuth-Bendix procedure and stored in `kbWork`.
"""
function removeinactive!(rws::RewritingSystem, work::kbWork)
    hasinactiverules(work) || return
    isempty(rws) && return
    sort!(work._inactiverules)

    while !isempty(work._inactiverules)
        idx = pop!(work._inactiverules)
        deleteat!(rws, idx)
        idx ≤ get_i(work) && (work.i -= 1)
        idx ≤ get_j(work) && (work.j -= 1)
    end
end
