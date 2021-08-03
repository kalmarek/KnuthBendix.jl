"""
    AbstractWord{T} <: AbstractVector{T}
Abstract type representing words over an Alphabet.

`AbstractWord` as such has its meaning only in the contex of an Alphabet.
The subtypes of `AbstractWord{T}` need to implement the following methods which
constitute `AbstractWord` interface:
 * a constructor from `AbstractVector{T}`
 * linear indexing (1-based) consistent with iteration returning pointers to letters of an alphabet (`getindex`, `setindex`, `length`),
 * `length`: the length of word as written in the alphabet,
 * `Base.push!`/`Base.pushfirst!`: append a single value at the end/beginning,
 * `Base.pop!`/`Base.popfirst!`: pop a single value from the end/beginning,
 * `Base.append!`/`Base.prepend!`: append a another word at the end/beginning,
 * `Base.resize!`: drop/extend a word at the end to the requested length
 * `Base.:*`: word concatenation (monoid binary operation),
 * `Base.similar`: an uninitialized word of a similar type/storage.

Note that `length` represents free reduced word (how it is written in an alphabet)
and not its the shortest form (e.g. the normal form).

The following are implemented for `AbstractWords` but can be overloaded for
performance reasons:

* `Base.==`: the equality (as words),
* `Base.hash`: simple uniqueness hashing function
* `Base.view`: creating `SubWord` e.g. based on subarray.
"""
abstract type AbstractWord{T<:Integer} <: AbstractVector{T} end

Base.hash(w::AbstractWord, h::UInt) =
    foldl((h, x) -> hash(x, h), w, init = hash(AbstractWord, h))
@inline Base.:(==)(w::AbstractWord, v::AbstractWord) =
    length(w) == length(v) && all(@inbounds w[i] == v[i] for i in 1:length(w))

Base.convert(::Type{W}, w::AbstractWord) where W<:AbstractWord = W(w)
Base.convert(::Type{W}, w::W) where W<:AbstractWord = w

# resize + copyto!
function store!(w::AbstractWord, v::AbstractWord)
    resize!(w, length(v))
    copyto!(w, v)
    return w
end

Base.size(w::AbstractWord) = (length(w),)

Base.one(::Type{W}) where {T, W<:AbstractWord{T}} = W(T[])
Base.one(::W) where W <: AbstractWord = one(W)
Base.isone(w::AbstractWord) = iszero(length(w))

Base.getindex(w::W, u::AbstractRange) where W<:AbstractWord =
    W([w[i] for i in u])

Base.view(w::AbstractWord, u::AbstractRange) = w[u] # general fallback

Base.:^(w::AbstractWord, n::Integer) = n >= 0 ? Base.power_by_squaring(w, n) :
    throw(DomainError(n, "To rise a Word to negative power you need to provide its inverse."))
Base.literal_pow(::typeof(^), w::AbstractWord, ::Val{p}) where p =
    p >= 0 ? Base.power_by_squaring(w, p) :
    throw(DomainError(p, "To rise a Word to negative power you need to provide its inverse."))

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

"""
    longestcommonprefix(u::AbstractWord, v::AbstractWord)
Returns the length of longest common prefix of two words (and simultaneously
the index at which the prefix ends).
"""
function longestcommonprefix(u::AbstractWord, v::AbstractWord)
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

"""
    isprefix(u::AbstractWord, v::AbstractWord[, k::Integer=length(u)])
Check if subword `u[1:k]` is a prefix of `v`.
"""
@inline function isprefix(u::AbstractWord, v::AbstractWord, k::Integer=length(u))
    k <= min(length(u), length(v)) || return false
    @inbounds for i in 1:k
        u[i] == v[i] || return false
    end
    return true
end

"""
    issuffix(u::AbstractWord, v::AbstractWord[, k::Integer=length(u)])
Check if subword `u[1:k]` is a suffix of `v`.
"""
@inline function issuffix(u::AbstractWord, v::AbstractWord, k::Integer=length(u))
    k ≤ min(length(u), length(v)) || return false
    @inbounds for i in 1:k
        u[i] == v[end-k+i] || return false
    end
    return true
end

function Base.show(io::IO, ::MIME"text/plain", w::AbstractWord)
    print(io, typeof(w), ": ")
    show(io, w)
end

function Base.show(io::IO, w::AbstractWord{T}) where T
    if isone(w)
        print(io, "(id)")
    else
        join(io, w, "·")
    end
end

_max_alphabet_length(::Type{<:AbstractWord{T}}) where T = typemax(T)
