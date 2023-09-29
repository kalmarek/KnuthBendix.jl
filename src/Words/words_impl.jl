
###########################################
# Concrete implementations of AbstractWord:
#   Word and SubWord
#

"""
    Word{T} <: AbstractWord{T}
Word as written in an alphabet storing only pointers to letters of an Alphabet.

Note that the negative values in `genptrs` field represent the inverse of letter.
If type is not specified in the constructor it will default to `Int16`.
"""
struct Word{T} <: AbstractWord{T}
    ptrs::Vector{T}

    function Word{T}(v::AbstractVector{<:Integer}, check = true) where {T}
        check &&
            @assert all(x -> x > 0, v) "All entries of a Word must be positive integers"
        return new{T}(v)
    end
end

# setting the default type to UInt16
Word(x::AbstractVector{<:Integer}) = Word{UInt16}(x)
Word(w::AbstractWord{T}) where {T} = Word{T}(w, false)

struct SubWord{T,V<:SubArray{T,1}} <: AbstractWord{T}
    ptrs::V
end

Base.show(io::IO, ::Type{<:SubWord{T}}) where {T} = print(io, "SubWord{$T, …}")

Base.getindex(w::Word, u::AbstractUnitRange) = typeof(w)(w.ptrs[u], false)
Base.getindex(w::SubWord, u::AbstractUnitRange) = @view w[u]

function Base.view(w::Union{Word,SubWord}, u::AbstractUnitRange)
    return SubWord(view(w.ptrs, u))
end

# AbstractWord Interface:

Base.size(w::Union{Word,SubWord}) = size(w.ptrs)

Base.@propagate_inbounds function Base.getindex(
    w::Union{Word,SubWord},
    n::Integer,
)
    return w.ptrs[n]
end

Base.@propagate_inbounds function Base.setindex!(
    w::Union{Word,SubWord},
    v::Integer,
    n::Integer,
)
    @assert v > 0 "All entries of a Word must be positive integers"
    return w.ptrs[n] = v
end

Base.push!(w::Word, n::Integer) = (@assert n > 0; push!(w.ptrs, n); w)
Base.pushfirst!(w::Word, n::Integer) = (@assert n > 0; pushfirst!(w.ptrs, n); w)
Base.pop!(w::Word) = (pop!(w.ptrs))
Base.popfirst!(w::Word) = (popfirst!(w.ptrs))

Base.append!(w::Word, v::AbstractVector{<:Integer}) = (append!(w.ptrs, v); w)
Base.prepend!(w::Word, v::AbstractVector{<:Integer}) = (prepend!(w.ptrs, v); w)
Base.append!(w::Word, v::Union{Word,SubWord}) = append!(w, v.ptrs)
Base.prepend!(w::Word, v::Union{Word,SubWord}) = prepend!(w, v.ptrs)

Base.resize!(w::Word, n::Integer) = (resize!(w.ptrs, n); w)

function Base.similar(
    w::Union{Word,SubWord},
    ::Type{S},
    dims::Base.Dims{1},
) where {S}
    return Word{S}(similar(w.ptrs, S, dims), false)
end
