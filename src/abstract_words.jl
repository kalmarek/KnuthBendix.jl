"""
    AbstractWord{T} <: AbstractVector{T}
Abstract type representing words over an Alphabet.

`AbstractWord` is just a string of integers and as such gains its meaning in the
contex of an Alphabet (when integers are understood as pointers to letters).
The subtypes of `AbstractWord{T}` need to implement the following methods which
constitute `AbstractWord` interface:
 * a constructor from `AbstractVector{T}`
 * linear indexing (1-based) consistent with iteration returning pointers to letters of an alphabet (`getindex`, `setindex`, `size`),
 * `Base.push!`/`Base.pushfirst!`: append a single value at the end/beginning,
 * `Base.pop!`/`Base.popfirst!`: pop a single value from the end/beginning,
 * `Base.append!`/`Base.prepend!`: append a another word at the end/beginning,
 * `Base.resize!`: drop/extend a word at the end to the requested length
 * `Base.similar`: an uninitialized word of a similar type/storage.

Note that `length` represents free reduced word (how it is written in an alphabet)
and not its the shortest form (e.g. the normal form).

!!! note
    It is assumed that `eachindex(w::AbstractWord)` returns `Base.OneTo(length(w))`

The following are implemented for `AbstractWords` but can be overloaded for
performance reasons:

* `Base.==`: the equality (as words),
* `Base.hash`: simple uniqueness hashing function
* `Base.view`: creating `SubWord` e.g. based on subarray.
"""
abstract type AbstractWord{T<:Integer} <: AbstractVector{T} end

Base.IndexStyle(::Type{<:AbstractWord}) = IndexLinear()

# to allow the vectorization of loops over AbstractWords;
# the default Base.iterate(a::AbstractArray,...) inhibits it
# here we use the assumption eachindex(w) == Base.OneTo(length(w))
function Base.iterate(w::AbstractWord, idx = 0)
    idx == length(w) && return nothing
    return @inbounds w[idx+1], idx + 1
end

function Base.hash(w::AbstractWord, h::UInt)
    return foldl((h, x) -> hash(x, h), w, init = hash(AbstractWord, h))
end

@inline function Base.:(==)(w::AbstractWord, v::AbstractWord)
    return length(w) == length(v) && all(w[i] == v[i] for i in eachindex(w))
end

Base.convert(::Type{W}, w::AbstractWord) where {W<:AbstractWord} = W(w)
Base.convert(::Type{W}, w::W) where {W<:AbstractWord} = w

# resize + copyto!
function store!(w::AbstractWord, v::AbstractWord)
    resize!(w, length(v))
    copyto!(w, v)
    return w
end

function Base.:*(w::AbstractWord, v::AbstractWord)
    out = similar(w)
    copyto!(out, w)
    isone(v) && return out
    resize!(out, length(w)+length(v))
    copyto!(out, length(w)+1, v, 1)
    # append!(out, v)
    return out
end

Base.one(::Type{W}) where {W<:AbstractWord} = W(eltype(W)[])
Base.one(::W) where {W<:AbstractWord} = one(W)
Base.isone(w::AbstractWord) = iszero(length(w))

function Base.getindex(w::W, u::AbstractRange) where {W<:AbstractWord}
    return W([w[i] for i in u])
end

Base.view(w::AbstractWord, u::AbstractRange) = w[u] # general fallback

function Base.:^(w::AbstractWord, n::Integer)
    return n >= 0 ? Base.power_by_squaring(w, n) :
           throw(
        DomainError(
            n,
            "To rise a Word to negative power you need to provide its inverse.",
        ),
    )
end

function Base.literal_pow(::typeof(^), w::AbstractWord, ::Val{p}) where {p}
    return p >= 0 ? Base.power_by_squaring(w, p) :
           throw(
        DomainError(
            p,
            "To rise a Word to negative power you need to provide its inverse.",
        ),
    )
end

function Base.findnext(
    pattern::AbstractWord{T},
    word::AbstractWord{T},
    pos::Integer,
) where {T}
    k = _searchindex(word, pattern, pos)
    return isempty(k) ? nothing : k
end

function Base.findfirst(subword::AbstractWord, word::AbstractWord)
    return findnext(subword, word, firstindex(word))
end
function Base.occursin(subword::AbstractWord, word::AbstractWord)
    return findfirst(subword, word) !== nothing
end

"""
    longestcommonprefix(u::AbstractWord, v::AbstractWord)
Returns the length of longest common prefix of two words (and simultaneously
the index at which the prefix ends).
"""
function longestcommonprefix(u::AbstractWord, v::AbstractWord)
    k = min(length(u), length(v))
    @inbounds for i in 1:k
        u[i] != v[i] && return i - 1
    end
    return k
end

"""
    lcp(u::AbstractWord, v::AbstractWord)
See [`longestcommonprefix`](@ref).
"""
lcp(u::AbstractWord, v::AbstractWord) = longestcommonprefix(u, v)

"""
    isprefix(u::AbstractWord, v::AbstractWord)
Check if `u` is a prefix of `v`.
"""
@inline function isprefix(u::AbstractWord, v::AbstractWord)
    k = length(u)
    k < length(v) || return false
    lcp = longestcommonprefix(u, v)
    return lcp == k
end

"""
    issuffix(u::AbstractWord, v::AbstractWord)
Check if `u` is a suffix of `v`.
"""
@inline function issuffix(u::AbstractWord, v::AbstractWord)
    k = length(u)
    k ≤ length(v) || return false
    @inbounds for i in eachindex(u)
        u[i] == v[end-k+i] || return false
    end
    return true
end

function Base.show(io::IO, ::MIME"text/plain", w::AbstractWord)
    print(io, typeof(w), ": ")
    return show(io, w)
end

function Base.show(io::IO, w::AbstractWord{T}) where {T}
    if isone(w)
        print(io, "(id)")
    else
        join(io, w, "·")
    end
end

_max_alphabet_length(::Type{<:AbstractWord{T}}) where {T} = typemax(T)

suffixes(a::AbstractWord) = suffixes(a, 1:length(a))
suffixes(a::AbstractWord, range) = (@view(a[end-i+1:end]) for i in range)
