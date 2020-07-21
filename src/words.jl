
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

    function Word{T}(v::AbstractVector{<:Integer}, check=true) where {T}
        check && @assert all(x -> x > 0, v) "All entries of a Word must be positive integers"
        return new{T}(v)
    end
    Word{T}() where T = new{T}(T[])
end

# setting the default type to Int16
Word(x::AbstractVector{<:Integer}) = Word{UInt16}(x)
Word(w::AbstractWord{T}) where T = Word{T}(w, false)
Word() = Word{UInt16}()

struct SubWord{T, V<:SubArray{T,1}} <: AbstractWord{T}
    ptrs::V
end

Base.view(w::Union{Word, SubWord}, u::UnitRange{Int}) =
    KnuthBendix.SubWord(view(w.ptrs, u))

# AbstractWord Interface:

Base.@propagate_inbounds function Base.getindex(w::Union{Word, SubWord}, n::Integer)
    @boundscheck checkbounds(w, n)
    return @inbounds w.ptrs[n]
end

Base.@propagate_inbounds function Base.setindex!(w::Union{Word, SubWord}, v::Integer, n::Integer)
    @boundscheck checkbounds(w, n)
    @assert v > 0 "All entries of a Word must be positive integers"
    return @inbounds w.ptrs[n] = v
end
Base.length(w::Union{Word, SubWord}) = length(w.ptrs)

Base.push!(w::Word, n::Integer) = (@assert n > 0; push!(w.ptrs, n); w)
Base.pushfirst!(w::Word, n::Integer) = (@assert n > 0; pushfirst!(w.ptrs, n); w)
Base.pop!(w::Word) = (pop!(w.ptrs))
Base.popfirst!(w::Word) = (popfirst!(w.ptrs))

Base.append!(w::Word, v::AbstractVector{<:Integer}) = (append!(w.ptrs, v); w)
Base.prepend!(w::Word, v::AbstractVector{<:Integer}) = (prepend!(w.ptrs, v); w)
Base.append!(w::Word, v::Union{Word, SubWord}) = append!(w, v.ptrs)
Base.prepend!(w::Word, v::Union{Word, SubWord}) = prepend!(w, v.ptrs)

Base.resize!(w::Word, n::Integer) = (resize!(w.ptrs, n); w)

Base.:*(w::Union{Word{S}, SubWord{S}}, v::Union{Word{T}, SubWord{T}}) where {S,T} =
    (TT = promote_type(S, T); Word{TT}(TT[w.ptrs; v.ptrs], false))

Base.similar(w::Union{Word, SubWord}, ::Type{S}) where {S} = Word{S}(Vector{S}(undef, length(w)), false)

# performance methods overloaded from AbstractWord:

Base.isone(w::Union{Word, SubWord}) = isempty(w.ptrs)
