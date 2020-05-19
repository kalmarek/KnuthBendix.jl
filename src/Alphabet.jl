import Base: push!

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
    inversions::Vector{Int}
    function Alphabet{T}() where T
        new(Vector{T}[], Vector{Int}[])
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
    function push!(A::Alphabet{T}, symbols::Vararg{T,1}) where T

Pushes one or more elements of type `T` at the end of the alphabet `A`.

# Example
```julia-repl
julia> A = Alphabet{String}()
Empty alphabet of String

julia> push!(A, "a", "b")
Alphabet of String:
    1  "a"
    2  "b"
```
"""
function push!(A::Alphabet{T}, symbols::Vararg{T,1}) where T
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
    function get_index(A::Alphabet{T}, x::T) where T

Returns the position of the symbol `x` in the alphabet `A`.
"""
function get_index(A::Alphabet{T}, x::T) where T
    findfirst(symbol -> symbol == x, A.alphabet)
end


"""
    function get_symbol(A::Alphabet{T}, p::Int) where T

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

julia> get_symbol(A, -get_index(A, "a"))
# nothing

julia> set_inversion!(A, "a", "c")
Alphabet of String:
    1. "a" = ("c")⁻¹
    2. "b"
    3. "c" = ("a")⁻¹

julia> get_symbol(A, -get_index(A, "a"))
"c"
```
"""
function get_symbol(A::Alphabet{T}, p::Int) where T
    if p > 0
        return A.alphabet[p]
    elseif p < 0 && A.inversions[-p] > 0
        return A.alphabet[A.inversions[-p]]
    end
    nothing
end
