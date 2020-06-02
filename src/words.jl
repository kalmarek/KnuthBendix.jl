"""
    AbstractWord{T} <: AbstractVector{T}
Abstract type representing words over an Alphabet.

`AbstractWord` as such has its meaning only in the contex of an Alphabet.
The subtypes of `AbstractWord{T}` need to implement the following methods which
constitute `AbstractWord` interface:
 * `Base.==`: the equality (as words),
 * `Base.hash`: simple uniqueness hashing function
 * `Base.one` the empty word (i.e. monoid identity element)
 * `Base.push!`/`Base.pushfirst!`: appending a single value at the end/beginning
 * `Base.pop!`/`Base.popfirst!`: popping a single value from the end/beginning
 * `Base.append!`/`Base.prepend!`: appending a another word at the end/beginning,
 * `Base.:*` for words concatentation (monoid binary operation)
 * full iteration protocol for `AbstractArray`s, returning pointers to letters
of an Alphabet
 * `length` the length of word as written in the alphabet.

Note that `length` represents how word is written and not the shortest form of
e.g. free reduced word.

Iteration over an `AbstractWord` may produce negative numbers. In such case the
inverse (if exists) of the pointed generator is meant.
"""

abstract type AbstractWord{T<:Integer} <: AbstractVector{T} end

"""
    Word{T} <: AbstractWord{T}
Word as written in an alphabet storing only pointers to letters of an Alphabet.

Note that the negative values in `genptrs` field represent the inverse of letter.
If type is not specified in the constructor it will default to `Int16`.
"""
struct Word{T} <: AbstractWord{T}
    ptrs::Vector{T}

    function Word{T}(v::AbstractVector{<:Integer}) where {T}
        @assert all(x -> x > 0, v) "All entries of a Word must be positive integers"
        return new{T}(v)
    end
end

Word(n::Integer) = Word([n])

# setting the default type to Int16
Word(x::Union{<:Vector{<:Integer},<:AbstractVector{<:Integer}}) = Word{UInt16}(x)

Base.:(==)(w::Word, v::Word) = w.ptrs == v.ptrs
Base.hash(w::Word, h::UInt) =
    foldl((h, x) -> hash(x, h), w.ptrs, init = hash(0x352c2195932ae61e, h))
# the init value is simply hash(Word)

Base.one(w::Word{T}) where {T} = Word{T}(T[])
Base.isone(w::Word) = isempty(w.ptrs)

Base.push!(w::Word, n::Integer) = (@assert n > 0; push!(w.ptrs, n); w)
Base.pushfirst!(w::Word, n::Integer) = (@assert n > 0; pushfirst!(w.ptrs, n); w)
Base.append!(w::Word, v::Word) = (append!(w.ptrs, v.ptrs); w)
Base.prepend!(w::Word, v::Word) = (prepend!(w.ptrs, v.ptrs); w)
Base.:*(w::Word{S}, v::Word{T}) where {S,T} =
    (TT = promote_type(S, T); Word{TT}(TT[w.ptrs; v.ptrs]))

Base.pop!(w::Word) = (pop!(w.ptrs))
Base.popfirst!(w::Word) = (popfirst!(w.ptrs))

Base.iterate(w::Word) = iterate(w.ptrs)
Base.iterate(w::Word, state) = iterate(w.ptrs, state)
Base.size(w::Word) = size(w.ptrs)

Base.similar(w::Word, ::Type{S}) where {S} = Word{S}(fill(one(S), length(w.ptrs)))

Base.@propagate_inbounds function Base.getindex(w::Word, n::Integer)
    @boundscheck checkbounds(w, n)
    return @inbounds w.ptrs[n]
end

Base.@propagate_inbounds function Base.setindex!(w::Word, v::Integer, n::Integer)
    @boundscheck checkbounds(w, n)
    @assert v > 0 "All entries of a Word must be positive integers"
    return @inbounds w.ptrs[n] = v
end

"""
    longestcommonprefix(u::Word, v::Word)
Returns the length of longest common prefix of two words (and simultaneously
the index at which the prefix ends).
"""
function longestcommonprefix(u::Word, v::Word)
    n=0
    for (lu, lv) in zip(u,v)
        lu != lv && break
        n += 1
    end
    return n
end