mutable struct BufferWord{T} <: AbstractWord{T}
    storage::Vector{T}
    lidx::Int
    ridx::Int

    function BufferWord{T}(
        v::AbstractVector{<:Integer},
        freeatbeg = 8,
        freeatend = 8,
        check = true,
    ) where {T}
        storage = Vector{T}(undef, freeatbeg + length(v) + freeatend)
        bw = new{T}(storage, freeatbeg + 1, freeatbeg + length(v))

        # placing content in the middle
        # storage[freeatbeg+1:end-freeatend] .= v
        @inbounds for i in 1:length(v)
            check && @assert v[i] > 0 "AbstractWords must consist of positive integers"
            bw[i] = v[i]
        end

        return bw
    end

    function BufferWord{T}(freeatbeg, freeatend) where {T}
        l = freeatbeg + freeatend
        return new{T}(Vector{T}(undef, l), freeatbeg + 1, freeatbeg)
    end
end

function BufferWord(v::Union{<:Vector{<:Integer},<:AbstractVector{<:Integer}})
    return BufferWord{UInt16}(v)
end

# helper functions for growing storage:

internal_length(bw::BufferWord) = length(bw.storage)

function _growbeg!(bw::BufferWord, delta::Integer)
    Base._growbeg!(bw.storage, delta)
    bw.ridx += delta
    bw.lidx += delta
    return nothing
end

_growend!(bw::BufferWord, delta::Integer) = Base._growend!(bw.storage, delta)

# AbstractWord Interface:

Base.size(bw::BufferWord) = (length(bw.lidx:bw.ridx),)

Base.@propagate_inbounds function Base.getindex(bw::BufferWord, n::Integer)
    @boundscheck checkbounds(bw, n)
    return bw.storage[bw.lidx+n-1]
end

Base.@propagate_inbounds function Base.setindex!(
    bw::BufferWord,
    val,
    n::Integer,
)
    return bw.storage[bw.lidx+n-1] = val
end

function Base.push!(bw::BufferWord, k::Integer)
    if internal_length(bw) == bw.ridx
        _growend!(bw, max(length(bw), 16))
    end
    bw.ridx += 1
    @inbounds bw[end] = k
    return bw
end

function Base.pushfirst!(bw::BufferWord, k::Integer)
    if bw.lidx ≤ firstindex(bw.storage)
        _growbeg!(bw, max(length(bw), 16))
    end
    bw.lidx -= 1
    @inbounds bw[1] = k
    return bw
end

function Base.pop!(bw::BufferWord)
    isempty(bw) && throw(ArgumentError("word must be non-empty"))
    @inbounds val = bw[end]
    bw.ridx -= 1
    return val
end

function Base.popfirst!(bw::BufferWord)
    isempty(bw) && throw(ArgumentError("word must be non-empty"))
    @inbounds val = bw[1]
    bw.lidx += 1
    return val
end

function Base.prepend!(bw::BufferWord, w::AbstractVector)
    free_space = bw.lidx - 1
    lw = length(w)

    if (free_space - lw) ≤ 0
        _growbeg!(bw, lw)
    end

    @inbounds for i in 1:lw
        bw.storage[bw.lidx-lw+i-1] = w[i]
    end
    bw.lidx -= lw

    return bw
end

function Base.append!(bw::BufferWord, w::AbstractVector)
    free_space = internal_length(bw) - bw.ridx
    lw = length(w)

    if (free_space - lw) ≤ 0
        _growend!(bw, lw)
    end

    @inbounds for i in 1:lw
        bw.storage[bw.ridx+i] = w[i]
    end
    bw.ridx += lw

    return bw
end

function Base.resize!(bw::BufferWord, nl::Integer)
    l = length(bw)
    if nl > l
        free_space = internal_length(bw) - bw.ridx
        if nl - l > free_space
            _growend!(bw, nl - l)
        end
    elseif nl != l
        if nl < 0
            throw(ArgumentError("new length must be ≥ 0"))
        end
    end
    bw.ridx += nl - l
    return bw
end

function Base.:*(bw::BufferWord{S}, bv::BufferWord{T}) where {S,T}
    res = BufferWord{promote_type(S, T)}(
        bw.lidx - 1 + length(bw) + length(bv),
        internal_length(bv) - bv.ridx,
    )
    res.lidx = bw.lidx
    res.ridx = res.lidx + length(bw) + length(bv) - 1
    @inbounds for i in 1:length(bw)
        res[i] = bw[i]
    end
    @inbounds for i in 1:length(bv)
        res[length(bw)+i] = bv[i]
    end
    return res
end

function Base.similar(bw::BufferWord, ::Type{S}, dims::Base.Dims{1}) where {S}
    l = internal_length(bw) ÷ 2
    w = BufferWord{S}(l, l)
    resize!(w, dims...)
    return w
end

function Base.empty!(bw::BufferWord)
    bw.lidx = 1
    bw.ridx = bw.lidx - 1
    return bw
end

# performance methods overloaded from AbstractWord:
# one less allocation:
Base.one(::Type{BufferWord{T}}) where {T} = BufferWord{T}(8, 8)

# @view constructor
function Base.view(bw::BufferWord, u::UnitRange{Int})
    return SubWord(view(bw.storage, u .+ (bw.lidx - 1)))
end
