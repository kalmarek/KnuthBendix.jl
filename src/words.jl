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
 * `Base.:*` for words concatenation (monoid binary operation)
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
    Word{T}() where T = new{T}(T[])
end

# setting the default type to Int16
Word(x::Union{<:Vector{<:Integer},<:AbstractVector{<:Integer}}) = Word{UInt16}(x)
Word() = Word{UInt16}()

struct SubWord{T, V<:SubArray{T,1}} <: AbstractWord{T}
    ptrs::V
end

Base.view(w::AbstractWord, u::AbstractRange) = w[u] # general fallback
Base.view(w::Union{Word, SubWord}, u::UnitRange{Int}) = KnuthBendix.SubWord(view(w.ptrs, u))

Base.:(==)(w::Union{Word, SubWord}, v::Union{Word, SubWord}) = w.ptrs == v.ptrs
Base.hash(w::Union{Word, SubWord}, h::UInt) =
    foldl((h, x) -> hash(x, h), w.ptrs, init = hash(0x352c2195932ae61e, h))
# the init value is simply hash(Word)

Base.one(w::Union{Word{T}, SubWord{T}}) where {T} = Word{T}()
Base.isone(w::Union{Word, SubWord}) = isempty(w.ptrs)

Base.push!(w::Word, n::Integer) = (@assert n > 0; push!(w.ptrs, n); w)
Base.pushfirst!(w::Word, n::Integer) = (@assert n > 0; pushfirst!(w.ptrs, n); w)
Base.append!(w::Word, v::Union{Word, SubWord}) = (append!(w.ptrs, v.ptrs); w)
Base.prepend!(w::Word, v::Union{Word, SubWord}) = (prepend!(w.ptrs, v.ptrs); w)
Base.:*(w::Union{Word{S}, SubWord{S}}, v::Union{Word{T}, SubWord{T}}) where {S,T} =
    (TT = promote_type(S, T); Word{TT}(TT[w.ptrs; v.ptrs]))

Base.pop!(w::Word) = (pop!(w.ptrs))
Base.popfirst!(w::Word) = (popfirst!(w.ptrs))

Base.iterate(w::Union{Word, SubWord}) = iterate(w.ptrs)
Base.iterate(w::Union{Word, SubWord}, state) = iterate(w.ptrs, state)
Base.size(w::Union{Word, SubWord}) = size(w.ptrs)

function Base.findnext(subword::AbstractWord, word::AbstractWord, pos::Integer)
    k = length(subword)
    f = first(subword)
    @inbounds for i in pos:length(word)-k+1
        word[i] == f || continue
        issub = true
        for j in 2:k
            if word[i+j-1] != subword[j]
                issub = false
                break
            end
        end
        issub == true && return i:i+k-1
    end
    return nothing
end

@inline Base.findfirst(subword::AbstractWord, word::AbstractWord) = findnext(subword, word, firstindex(word))
@inline Base.occursin(subword::AbstractWord, word::AbstractWord) = findfirst(subword, word) !== nothing

Base.similar(w::Union{Word, SubWord}, ::Type{S}) where {S} = Word{S}(fill(one(S), length(w.ptrs)))

Base.@propagate_inbounds function Base.getindex(w::Union{Word, SubWord}, n::Integer)
    @boundscheck checkbounds(w, n)
    return @inbounds w.ptrs[n]
end

Base.@propagate_inbounds function Base.getindex(w::Union{Word{T}, SubWord{T}}, I::AbstractRange) where T
    @boundscheck checkbounds(w, I)
    return @inbounds Word{T}(w.ptrs[I])
end

Base.@propagate_inbounds function Base.setindex!(w::Union{Word, SubWord}, v::Integer, n::Integer)
    @boundscheck checkbounds(w, n)
    @assert v > 0 "All entries of a Word must be positive integers"
    return @inbounds w.ptrs[n] = v
end

"""
    longestcommonprefix(u::AbstractWord, v::AbstractWord)
Returns the length of longest common prefix of two words (and simultaneously
the index at which the prefix ends).
"""
function longestcommonprefix(u::Union{Word, SubWord}, v::Union{Word, SubWord})
    n=0
    for (lu, lv) in zip(u,v)
        lu != lv && break
        n += 1
    end
    return n
end
"""
    lcp(u::AbstractWord, v::AbstractWord)
See [`longestcommonprefix`](@ref).
"""
lcp(u::AbstractWord, v::AbstractWord) = longestcommonprefix(u,v)
