"""
    struct Alphabet{T}

A basic struct for storing alphabets. An alphabet consists of the symbols of a common type `T`.

# Example
```julia-repl
julia> Alphabet{Char}()
Empty alphabet of Char

julia> Alphabet(["a", "b", "c"])
Alphabet of String:
    1.  "a"
    2.  "b"
    3.  "c"
```
"""
struct Alphabet{T}
    letters::Vector{T}
    letter_to_idx::Dict{T,Int}
    inversions::Vector{Int}

    function Alphabet(letters::AbstractVector)
        @assert !(eltype(letters) <: Integer)
        @assert length(unique(letters)) == length(letters) "Non-unique set of letters"
        letters_to_idx = Dict(l => i for (i, l) in pairs(letters))
        inversions = zeros(Int, length(letters))

        return new{eltype(letters)}(letters, letters_to_idx, inversions)
    end
end

function Alphabet(
    letters::AbstractVector,
    inversions::AbstractVector{<:Integer},
)
    A = Alphabet(letters)
    @assert length(letters) == length(inversions)
    @assert all(i -> 0 ≤ i ≤ length(letters), inversions)

    for (x, X) in pairs(inversions)
        X == 0 && continue
        setinverse!(A, x, X)
    end
    return A
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

hasinverse(idx::Integer, A::Alphabet) = !iszero(A.inversions[idx])
hasinverse(letter, A::Alphabet) = hasinverse(A[letter], A)

function Base.show(io::IO, A::Alphabet{T}) where {T}
    return print(io, "Alphabet{$T}: ", A.letters)
end

function Base.show(io::IO, ::MIME"text/plain", A::Alphabet)
    for (idx, l) in enumerate(A)
        print(io, " ", idx, ":\t → ", l)
        hasinverse(idx, A) && print(io, "\t inverse of: ", inv(A, l))
        idx == length(A) && break
        println(io)
    end
end

function _deleteinverse!(
    A::Alphabet,
    idx::Integer,
    inv_idx::Integer = inv(A, idx),
)
    @assert inv(A, idx) == inv_idx
    A.inversions[idx] = 0
    A.inversions[inv_idx] = 0
    return A
end

"""
    setinverse!(A::Alphabet{T}, x::T, y::T) where T

Set the inversion of `x` to `y` (and vice versa).

# Example
```julia-repl
julia> A = Alphabet(["a", "b", "c"])
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> setinverse!(A, "a", "c")
Alphabet of String:
    1. "a" = ("c")⁻¹
    2. "b"
    3. "c" = ("a")⁻¹

julia> setinverse!(A, "a", "b")
Alphabet of String:
    1. "a" = ("b")⁻¹
    2. "b" = ("a")⁻¹
    3. "c"
```
"""
function setinverse!(A::Alphabet, x::Integer, X::Integer)
    @assert x in A && X in A
    for (l, L) in ((x, X), (X, x))
        if hasinverse(l, A) && inv(A, l) ≠ L
            @warn "$(A[l]) already has an inverse: $(A[inv(A, l)]); overriding"
            _deleteinverse!(A::Alphabet, l)
        end
    end
    A.inversions[x] = X
    A.inversions[X] = x
    return A
end
setinverse!(A::Alphabet, l1, l2) = setinverse!(A, A[l1], A[l2])

Base.inv(A, letter) = A[inv(A, A[letter])]
function Base.inv(A::Alphabet, idx::Integer)
    hasinverse(idx, A) && return A.inversions[idx]
    throw(DomainError(idx => A[idx], "$(idx=>A[idx]) is not invertible in $A"))
end

"""
    inv(A::Alphabet, w::AbstractWord)
Return the inverse of a word `w` in the context of alphabet `A`.
"""
function Base.inv(A::Alphabet, w::AbstractWord)
    res = similar(w)
    n = length(w)
    for (i, l) in zip(eachindex(res), Iterators.reverse(w))
        res[i] = inv(A, l)
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
