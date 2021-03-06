mutable struct BufferWord{T} <: AbstractWord{T}
    storage::Vector{T}
    lidx::Int
    ridx::Int

    function BufferWord{T}(v::AbstractVector{<:Integer},
        freeatbeg=8, freeatend=8) where T

        storage = Vector{T}(undef, freeatbeg + length(v) + freeatend)
        bw = new{T}(storage, freeatbeg+1, freeatbeg + length(v))

        # placing content in the middle
        # storage[freeatbeg+1:end-freeatend] .= v
        @inbounds for i in 1:length(v)
            bw[i] = v[i]
        end

        return bw
    end

    function BufferWord{T}(freeatbeg, freeatend) where T
        l = freeatbeg + freeatend
        return new{T}(Vector{T}(undef, l), freeatbeg+1, freeatbeg)
    end
end

BufferWord(v::Union{<:Vector{<:Integer},<:AbstractVector{<:Integer}}) =
    BufferWord{UInt16}(v)

# helper functions for growing storage:

internal_length(bw::BufferWord) = length(bw.storage)

function _growatbeg!(bw::BufferWord, k::Integer)
    @assert k ≥ 0
    k == 0 && return bw
    resize!(bw.storage, internal_length(bw) + k)

    @inbounds for i in 0:length(bw)-1
        bw.storage[bw.ridx+k-i] = bw.storage[bw.ridx-i]
    end

    bw.ridx += k
    bw.lidx += k

    return bw
end

_growatend!(bw::BufferWord, k::Integer) =
    resize!(bw.storage, internal_length(bw) + k)

# AbstractWord Interface:

Base.@propagate_inbounds function Base.getindex(bw::BufferWord, n::Integer)
    @boundscheck checkbounds(bw, n)
    return @inbounds bw.storage[bw.lidx+n-1]
end

Base.@propagate_inbounds function Base.setindex!(bw::BufferWord, val, n::Integer)
    @boundscheck checkbounds(bw, n)
    return @inbounds bw.storage[bw.lidx+n-1] = val
end
Base.length(bw::BufferWord) = length(bw.lidx:bw.ridx)

function Base.push!(bw::BufferWord, k::Integer)
    if internal_length(bw) == bw.ridx
        _growatend!(bw, max(length(bw), 16))
    end
    bw.ridx += 1
    @inbounds bw[end] = k
    return bw
end

function Base.pushfirst!(bw::BufferWord, k::Integer)
    if bw.lidx ≤ firstindex(bw.storage)
        _growatbeg!(bw, max(length(bw), 16))
    end
    bw.lidx -= 1
    @inbounds bw[1] = k
    return bw
end

function Base.pop!(bw::BufferWord)
    @assert !isempty(bw)
    @inbounds val = bw[end]
    bw.ridx -= 1
    return val
end

function Base.popfirst!(bw::BufferWord)
    @assert !isempty(bw)
    @inbounds val = bw[1]
    bw.lidx +=1
    return val
end

function Base.prepend!(bw::BufferWord, w::AbstractVector)

    free_space = bw.lidx - 1
    lw = length(w)

    if (free_space - lw) ≤ 0
        _growatbeg!(bw, lw)
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
        _growatend!(bw, lw)
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
        if nl-l > free_space
            _growatend!(bw, nl-l)
        end
    elseif nl != l
        if nl < 0
            throw(ArgumentError("new length must be ≥ 0"))
        end
    end
    bw.ridx += nl-l
    return bw
end

function Base.:*(bw::BufferWord{S}, bv::BufferWord{T}) where {S, T}
    res = BufferWord{promote_type(S,T)}(
        bw.lidx-1+length(bw) + length(bv),
        internal_length(bv) - bv.ridx
    )
    res.lidx = bw.lidx
    res.ridx = res.lidx+length(bw)+length(bv)-1
    @inbounds for i in 1:length(bw)
        res[i] = bw[i]
    end
    @inbounds for i in 1:length(bv)
        res[length(bw)+i] = bv[i]
    end
    return res
end

Base.similar(bw::BufferWord, ::Type{S}) where S =
    (l = internal_length(bw)÷2; BufferWord{S}(l, l))

function Base.empty!(bw::BufferWord)
    bw.lidx = 1
    bw.ridx = 0
    return bw
end

# performance methods overloaded from AbstractWord:
# one less allocation:
Base.one(::Type{BufferWord{T}}) where T = BufferWord{T}(8, 8)

# @view constructor
Base.view(bw::BufferWord, u::UnitRange{Int}) =
    KnuthBendix.SubWord(view(bw.storage, u.+(bw.lidx-1)))
