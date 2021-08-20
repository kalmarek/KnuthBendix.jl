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
    inversions::Vector{Int}

    function Alphabet(letters::AbstractVector{T}, inversions::AbstractVector{<:Integer}) where T
        @assert length(unique(letters)) == length(letters) "Non-unique set of letters"
        @assert !(T<:Integer) "Alphabets of integers are not supported."
        @assert length(letters) == length(inversions)
        @assert all(i-> 0 ≤ i ≤ length(letters), inversions)
        return new{T}(letters, inversions)
    end
end

Alphabet{T}() where T = Alphabet(T[])
Alphabet(init::AbstractVector{T}) where T = Alphabet(init, fill(0, length(init)))

letters(A::Alphabet) = A.letters

Base.length(A::Alphabet) = length(letters(A))
Base.isempty(A::Alphabet) = isempty(letters(A))
Base.:(==)(A::Alphabet, B::Alphabet) =
    letters(A) == letters(B) && A.inversions == B.inversions
Base.hash(A::Alphabet{T}, h::UInt) where T =
    hash(letters(A), hash(A.inversions, hash(h, hash(Alphabet{T}))))

Base.show(io::IO, A::Alphabet) = print(io, Alphabet, " ", letters(A))

hasinverse(i::Integer, A::Alphabet) = A.inversions[i] > 0
hasinverse(l::T, A::Alphabet{T}) where T = hasinverse(A[l], A)

function Base.show(io::IO, ::MIME"text/plain", A::Alphabet{T}) where T
    if isempty(A)
        print(io, "Empty alphabet of $(T)")
    else
        print(io, "Alphabet of $(T):")
        for (i, l) in pairs(letters(A))
            print(io, "\n\t$(i).\t")
            show(io, l)
            if hasinverse(i, A)
                print(io, " = (")
                show(io, A[-i])
                print(io, ")⁻¹")
            end
        end
    end
end

"""
    push!(A::Alphabet{T}, symbols::T...) where T

Push one or more elements of type `T` at the end of the alphabet `A`.

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b")
Alphabet of String:
    1.  "a"
    2.  "b"
```
"""
function Base.push!(A::Alphabet{T}, symbols::T...) where T
    for s in symbols
        if findfirst(symbol -> symbol == s, letters(A)) !== nothing
            error("Symbol $(s) already in the alphabet.")
        end
        push!(A.letters, s)
        push!(A.inversions, 0)
    end
    A
end

"""
    set_inversion!(A::Alphabet{T}, x::T, y::T) where T

Set the inversion of `x` to `y` (and vice versa).

# Example
```julia-repl
julia> A = Alphabet(["a", "b", "c"])
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> set_inversion!(A, "a", "c")
Alphabet of String:
    1. "a" = ("c")⁻¹
    2. "b"
    3. "c" = ("a")⁻¹

julia> set_inversion!(A, "a", "b")
Alphabet of String:
    1. "a" = ("b")⁻¹
    2. "b" = ("a")⁻¹
    3. "c"
```
"""
function set_inversion!(A::Alphabet{T}, x::T, y::T) where T
    if (ix = findfirst(symbol -> symbol == x, letters(A))) === nothing
        error("Element $(x) not found in the alphabet.")
    end
    if (iy = findfirst(symbol -> symbol == y, letters(A))) === nothing
        error("Element $(y) not found in the alphabet.")
    end

    if A.inversions[ix] > 0
        A.inversions[A.inversions[ix]] = 0
    end
    if A.inversions[iy] > 0
        A.inversions[A.inversions[iy]] = 0
    end

    A.inversions[ix] = iy
    A.inversions[iy] = ix
    A
end

"""
    getindex(A::Alphabet{T}, x::T) where T

Return the position of the symbol `x` in the alphabet `A`.

# Example
```julia-repl
julia> A = Alphabet(["a", "b", "c"])
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> A["c"]
3
```
"""
function Base.getindex(A::Alphabet{T}, x::T) where T
    if (index = findfirst(symbol -> symbol == x, letters(A))) === nothing
        throw(DomainError("Element '$(x)' not found in the alphabet"))
    end
    return index
end

"""
    getindex(A::Alphabet{T}, p::Integer) where T

Return the symbol that holds the `p`th position in the alphabet `A`. If `p < 0`, then the inversion of the `|p|`th symbol is returned.

# Example
```julia-repl
julia> A = Alphabet(["a", "b", "c"])
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> set_inversion!(A, "a", "c")
Alphabet of String:
    1. "a" = ("c")⁻¹
    2. "b"
    3. "c" = ("a")⁻¹

julia> A["a"]
1

julia> A[-A["a"]]
"c"
```
"""
Base.@propagate_inbounds function Base.getindex(A::Alphabet, p::Integer)
    @boundscheck checkbounds(letters(A), abs(p))
    if p > 0
        return @inbounds letters(A)[p]
    elseif p < 0 && hasinverse(-p, A)
        return @inbounds letters(A)[A.inversions[-p]]
    end

    throw(DomainError("Inversion of $(letters(A)[-p]) is not defined"))
end

function Base.inv(A::Alphabet, i::Integer)
    hasinverse(i, A) && return A.inversions[i]

    throw(DomainError(A[i], "is not invertible over $A"))
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

Base.inv(A::Alphabet{T}, a::T) where {T} = A[-A[a]]

function _print_syllable(io, symbol, pow)
    str = string(symbol)
    if length(str) > 3 && endswith(str, "^-1")
        print(io, first(str, length(str)-3), "^-", pow)
    else
        if pow == 1
            print(io, str)
        else
            print(io, str, "^", pow)
        end
    end
end

function print_repr(io::IO, w::AbstractWord, A::Alphabet, sep="*")
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
