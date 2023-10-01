"""
    Alphabet(letters::AbstractVector[, inversions])

An alphabet consists of the symbols of a common type `T`.

An `Alphabet` defines a bijection between consecutive integers and its letters,
i.e. it can be queried for the index of a letter, or the letter corresponding to
a given index.

# Example
```jldoctest
julia> al = Alphabet([:a, :b, :c])
Alphabet of Symbol
  1. a
  2. b
  3. c

julia> al[2]
:b

julia> al[:c]
3

julia> Alphabet([:a, :A, :b], [2, 1, 0])
Alphabet of Symbol
  1. a    (inverse of: A)
  2. A    (inverse of: a)
  3. b
```
"""
struct Alphabet{T}
    letters::Vector{T}
    letter_to_idx::Dict{T,Int}
    inversions::Vector{Int}

    function Alphabet(
        letters::AbstractVector,
        inversions::AbstractVector{<:Integer} = zeros(Int, length(letters)),
    )
        @assert !(eltype(letters) <: Integer)
        @assert length(unique(letters)) == length(letters) "Non-unique set of letters"
        @assert length(letters) == length(inversions)
        @assert all(i -> 0 ≤ i ≤ length(letters), inversions)

        letters_to_idx = Dict(l => i for (i, l) in pairs(letters))
        A = new{eltype(letters)}(letters, letters_to_idx, inversions)
        for (x, X) in pairs(inversions)
            X == 0 && continue
            setinverse!(A, x, X)
        end
        return A
    end
end

Base.iterate(A::Alphabet) = iterate(A.letters)
Base.iterate(A::Alphabet, state) = iterate(A.letters, state)
Base.length(A::Alphabet) = length(A.letters)
Base.eltype(::Type{Alphabet{T}}) where {T} = T

Base.in(letter, A::Alphabet) = Base.haskey(A.letter_to_idx, letter)
Base.in(idx::Integer, A::Alphabet) = 1 ≤ idx ≤ length(A)

function Base.getindex(A::Alphabet, idx::Integer)
    @boundscheck abs(idx) in A
    if idx > 0
        return A.letters[idx]
    elseif idx < 0 && hasinverse(-idx, A)
        return A.letters[A.inversions[-idx]]
    end
    return throw(DomainError("Inversion of $(A.letters[-idx]) is not defined"))
end
function Base.getindex(A::Alphabet, letter)
    letter in A && return A.letter_to_idx[letter]
    throw(DomainError("$letter is not in the alphabet"))
end

Base.isempty(A::Alphabet) = iszero(length(A))

function Base.:(==)(A::Alphabet, B::Alphabet)
    return A.letters == B.letters && A.inversions == B.inversions
end
function Base.hash(A::Alphabet{T}, h::UInt) where {T}
    return hash(A.letters, hash(A.inversions, hash(Alphabet, h)))
end

"""
    hasinverse(idx::Integer, A::Alphabet)
    hasinverse(letter, A::Alphabet)
Check if alphabet `A` defines the inverse of `letter`.
"""
hasinverse(idx::Integer, A::Alphabet) = !iszero(A.inversions[idx])
hasinverse(letter, A::Alphabet) = hasinverse(A[letter], A)

function Base.show(io::IO, A::Alphabet{T}) where {T}
    return print(io, "Alphabet{$T}: ", A.letters)
end

function Base.show(io::IO, ::MIME"text/plain", A::Alphabet{T}) where {T}
    println(io, "Alphabet of ", T)
    for (idx, l) in enumerate(A)
        print(io, lpad(idx, 3), ". ", rpad(l, 4))
        if hasinverse(idx, A)
            if inv(l, A) == l
                print(io, " (self-inverse)")
            else
                print(io, " (inverse of: ", inv(l, A), ')')
            end
        end
        idx == length(A) && break
        println(io)
    end
end

function _deleteinverse!(
    A::Alphabet,
    idx::Integer,
    inv_idx::Integer = inv(idx, A),
)
    @assert inv(idx, A) == inv_idx
    A.inversions[idx] = 0
    A.inversions[inv_idx] = 0
    return A
end

"""
    setinverse!(A::Alphabet{T}, x::T, X::T) where T

Set the inversion of `x` to `X` (and vice versa).

# Example
```jldoctest; filter=r"┌ Warning.*\\n└ @ KnuthBendix.*\\n"
julia> al = Alphabet([:a, :b, :c])
Alphabet of Symbol
  1. a
  2. b
  3. c

julia> KnuthBendix.setinverse!(al, :a, :c)
Alphabet of Symbol
  1. a    (inverse of: c)
  2. b
  3. c    (inverse of: a)

julia> KnuthBendix.setinverse!(al, :a, :b)
┌ Warning: a already has an inverse: c; overriding
└ @ KnuthBendix ~/.julia/dev/KnuthBendix/src/alphabets.jl:157
Alphabet of Symbol
  1. a    (inverse of: b)
  2. b    (inverse of: a)
  3. c
```
"""
function setinverse!(A::Alphabet, x::Integer, X::Integer)
    @assert x in A && X in A
    for (l, L) in ((x, X), (X, x))
        if hasinverse(l, A) && inv(l, A) ≠ L
            @warn "$(A[l]) already has an inverse: $(A[inv(l,A)]); overriding"
            _deleteinverse!(A::Alphabet, l)
        end
    end
    A.inversions[x] = X
    A.inversions[X] = x
    return A
end
setinverse!(A::Alphabet, l1, l2) = setinverse!(A, A[l1], A[l2])

"""
    inv(idx::Integer, A::Alphabet)
    inv(letter::Integer, A::Alphabet)
Return the inverse of a letter `letter` in the context of alphabet `A`.

If `hasinverse(letter, A) == false` a `DomainError` is thrown.
"""
Base.inv(letter, A::Alphabet) = A[inv(A[letter], A)]
function Base.inv(idx::Integer, A::Alphabet)
    hasinverse(idx, A) && return A.inversions[idx]
    throw(DomainError(idx => A[idx], "$(idx=>A[idx]) is not invertible in $A"))
end

"""
    inv(w::AbstractWord, A::Alphabet)
Return the inverse of a word `w` in the context of alphabet `A`.
"""
Base.inv(w::AbstractWord, A::Alphabet) = inv!(similar(w), w, A)

function inv!(res::AbstractWord, w::AbstractWord, A::Alphabet)
    resize!(res, length(w))
    @inbounds for (i, l) in zip(eachindex(res), Iterators.reverse(w))
        res[i] = inv(l, A)
    end
    return res
end

function _print_syllable(io, symbol, pow)
    str = string(symbol)
    if length(str) > 3 && endswith(str, "^-1")
        print(io, first(str, length(str) - 3), "^-", pow)
    else
        if pow == 1
            print(io, str)
        else
            print(io, str, "^", pow)
        end
    end
end

function print_repr(io::IO, w::AbstractWord, A::Alphabet, sep = "*")
    if isone(w)
        print(io, w)
    else
        first_syllable = true
        idx = 1
        pow = 1
        while idx < length(w)
            if w[idx] == w[idx+1]
                pow += 1
                idx += 1
            else
                first_syllable || print(io, sep)
                _print_syllable(io, A[w[idx]], pow)
                first_syllable = false
                pow = 1
                idx += 1
            end
        end
        @assert idx == length(w)
        first_syllable || print(io, sep)
        _print_syllable(io, A[w[idx]], pow)
    end
end
