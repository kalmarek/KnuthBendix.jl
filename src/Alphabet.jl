"""
    mutable struct Alphabet{T}

A basic struct for storing alphabets. An alphabet consists of the symbols of a common type `T`.

# Example
```julia-repl
julia> Alphabet{String}()
Empty alphabet of String
```
"""
mutable struct Alphabet{T}
    alphabet::Vector{T}
    inversions::Vector{Integer}
    function Alphabet{T}(; safe = true) where T
        if safe && T <: Integer
            error("I am sorry to say that, but it is not allowed for alphabet symbols to be integers. If you do *really* know what you are doing, call the constructor with `safe = false`.")
        end
        new(Vector{T}[], Vector{Integer}[])
    end
end

function Base.show(io::IO, A::Alphabet{T}) where T
    if length(A.alphabet) == 0
        print(io, "Empty alphabet of $(T)")
    else
        print(io, "Alphabet of $(T):")
        for i in 1:length(A.alphabet)
            print(io, "\n\t$(i).\t")
            show(io, A.alphabet[i])
            if(A.inversions[i] > 0)
                print(io, " = (")
                show(io, "$(A.alphabet[A.inversions[i]])")
                print(io, ")⁻¹")
            end
        end
    end
end

"""
    function Base.push!(A::Alphabet{T}, symbols::Vararg{T,1}) where T

Pushes one or more elements of type `T` at the end of the alphabet `A`.

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
function Base.push!(A::Alphabet{T}, symbols::Vararg{T,1}) where T
    for s in symbols
        if findfirst(symbol -> symbol == s, A.alphabet) != nothing
            error("Symbol $(s) already in the alphabet.")
        end
        push!(A.alphabet, s)
        push!(A.inversions, 0)
    end
    A
end

"""
    function set_inversion!(A::Alphabet{T}, x::T, y::T) where T

Sets the inversion of `x` to `y` (and vice versa).

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b", "c")
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
    if (ix = findfirst(symbol -> symbol == x, A.alphabet)) == nothing
        error("Element $(x) not found in the alphabet.")
    end
    if (iy = findfirst(symbol -> symbol == y, A.alphabet)) == nothing
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
    function getindexbysymbol(A::Alphabet{T}, x::T) where T

Returns the position of the symbol `x` in the alphabet `A`.

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b", "c")
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> getindexbysymbol(A, "c")
3
```
"""
function getindexbysymbol(A::Alphabet{T}, x::T) where T
    if (index = findfirst(symbol -> symbol == x, A.alphabet)) == nothing
        throw(DomainError("Element '$(x)' not found in the alphabet"))
    end
    index
end

"""
    function Base.getindex(A::Alphabet{T}, x::T) where T

Returns the position of the symbol `x` in the alphabet `A`. If you, by any chance, work with the alphabet of integers, use `getindexbysymbol`.

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b", "c")
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> A["c"]
3
```
"""
Base.getindex(A::Alphabet{T}, x::T) where T = getindexbysymbol(A, x)


"""
    function Base.getindex(A::Alphabet{T}, p::Integer) where T

Returns the symbol that holds the `p`th position in the alphabet `A`. If `p < 0`, then it returns the inversion of the `|p|`th symbol.

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b", "c")
Alphabet of String:
    1. "a"
    2. "b"
    3. "c"

julia> set_inversion!(A, "a", "c")
Alphabet of String:
    1. "a" = ("c")⁻¹
    2. "b"
    3. "c" = ("a")⁻¹

julia> A[-A["a"]]
"c"
```
"""
function Base.getindex(A::Alphabet{T}, p::Integer) where T
    if p > 0
        return A.alphabet[p]
    elseif p < 0 && A.inversions[-p] > 0
        return A.alphabet[A.inversions[-p]]
    end

    throw(DomainError("Inversion of $(A.alphabet[-p]) is not defined"))
end
