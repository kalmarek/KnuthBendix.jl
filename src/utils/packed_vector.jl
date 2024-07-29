
struct PackedVector{T} <:
       AbstractVector{SubArray{T,1,Vector{T},Tuple{UnitRange{Int64}},true}}
    linear_tape::Vector{T}
    subset_pointers::Vector{Int}
    PackedVector{T}() where {T} = new{T}(T[], [1])
end

Base.size(pvec::PackedVector) = (length(pvec.subset_pointers) - 1,)
Base.@propagate_inbounds function Base.getindex(pvec::PackedVector, i::Integer)
    @boundscheck 1 ≤ i ≤ length(pvec)
    ptr = pvec.subset_pointers
    return @inbounds @view pvec.linear_tape[ptr[i]:ptr[i+1]-1]
end

__unsafe_push!(pvec::PackedVector, v) = (push!(pvec.linear_tape, v); pvec)
function __unsafe_finalize!(pvec::PackedVector)
    k = length(pvec.linear_tape) + 1
    @assert k ≥ last(pvec.subset_pointers)
    push!(pvec.subset_pointers, k)
    return pvec
end

function Base.resize!(pvec::PackedVector, n::Integer)
    @assert 0 ≤ n ≤ length(pvec) "growing of pvec is not supported"
    resize!(pvec.subset_pointers, n + 1)
    resize!(pvec.linear_tape, pvec.subset_pointers[end] - 1)
    return pvec
end

function Base.push!(pvec::PackedVector, v::AbstractVector)
    append!(pvec.linear_tape, v)
    push!(pvec.subset_pointers, pvec.subset_pointers[end] + length(v))
    return pvec
end

