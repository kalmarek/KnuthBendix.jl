"""
    Recursive{Side,T} <: WordOrdering
    Recursive{Side}(A::Alphabet; order=collect(A))

A special case of `WreathOrder` where each letter is given a unique level.

Since levels are unique they just linearly order letters in the alphabet `A`.
The order generally promotes smaller generators, and larger ones will occur
in minimal words relatively early. For example if `a < b` then `a·b > b·aⁿ`.

# Definition
Given a partial order `(A, <)` on an alphabet `A`, for `p, q ∈ A*` we say that
`p < q` w.r.t. left-recursive ordering if
> 1. `p == ε ≠ q`, or
> 2. `p = p′·a`, `q = q′·b` for some `a, b ∈ A` and
    * `a == b` and `p′ < q′`, or
    * `a < b` and `p < q′`, or
    * `a > b` and `p′ < q`

For the right-recursive ordering one needs to change the decompositions in
point 2. to
> `p = a·p′`, `q = b·q′` for some `a, b ∈ A` …

See M. Jentzen _Confluent String Rewriting_, Definition 1.2.14 p.24.
The ordering is sometimes also known as _recursive path ordering_ and is useful
e.g. for polycyclic groups.


# Example
```julia-repl
julia> X = Alphabet([:a, :A, :b],[2,1,0]);

julia> a, A, b = [Word([i]) for i in 1:length(X)];

julia> rec = Recursive(X, order=[:a, :A, :b])
KnuthBendix.Left-Recursive: a < A < b

julia> lt(rec, b*a^10, a*b)
true

julia> lt(rec, b*a^10, b)
false

julia> lt(rec, a*A, b*a^10)
true

julia> rt_rec = Recursive{KnuthBendix.Right}(X, order=[:a, :A, :b])
KnuthBendix.Right-Recursive: a < A < b
```
"""
struct Recursive{LR<:Side,T} <: WordOrdering
    A::Alphabet{T}
    letter_order::Vector{Int}
end

Recursive(A::Alphabet; order = collect(A)) = Recursive{Left}(A, order = order)

function Recursive{LR}(
    A::Alphabet{T};
    order::AbstractVector{T} = collect(A),
) where {LR,T}
    @assert length(A) == length(order)
    @assert Set(order) == Set(A)

    letter_order = sortperm([A[l] for l in order])
    return Recursive{LR,T}(A, letter_order)
end

function recursive_order(A::Alphabet)
    done = falses(length(A))
    order = Vector{eltype(A)}(undef, length(A))
    top = lastindex(done)
    bottom = firstindex(done)
    for letter in A
        done[A[letter]] && continue
        if hasinverse(letter, A)
            done[A[letter]] = true
            order[bottom] = letter
            bottom += 1

            inv_letter = inv(A, letter)
            inv_letter == letter && continue

            done[A[inv_letter]] = true
            order[bottom] = inv_letter
            bottom += 1
        else
            done[A[letter]] = true
            order[top] = letter
            top -= 1
        end
    end
    @assert all(done)
    return order
end

alphabet(o::Recursive) = o.A

next(::Type{Right}, low, high) = (low + 1, high)
next(::Type{Left}, low, high) = (low, high - 1)

letter(::Type{Right}, w::AbstractWord, low, high) = w[low]
letter(::Type{Left}, w::AbstractWord, low, high) = w[high]

function lt(o::Recursive, lp::Integer, lq::Integer)
    return o.letter_order[lp] < o.letter_order[lq]
end

function lt(o::Recursive{Side}, p::AbstractWord, q::AbstractWord) where {Side}
    if isone(p)
        isone(q) && return false
        return true
    end

    # we're going forwards shifting ip and iq until they go out of bounds
    p_is_smaller = true
    lowp, highp = firstindex(p), lastindex(p)
    lowq, highq = firstindex(q), lastindex(q)
    while true
        if lowp > highp
            lowq > highq && return !p_is_smaller
            return true
        end
        lowq > highq && return false

        # compare first letters and chop the smaller from the corresponding word.
        # recurse
        a = letter(Side, p, lowp, highp)
        b = letter(Side, q, lowq, highq)

        if a == b
            # return lt(o, p[2:end], q[2:end])
            lowp, highp = next(Side, lowp, highp)
            lowq, highq = next(Side, lowq, highq)
        else
            if lt(o, a, b)
                # return lt(o, p[2:end], q])
                lowp, highp = next(Side, lowp, highp)
                p_is_smaller = true
            else
                # return lt(o, p, q[2:end])
                lowq, highq = next(Side, lowq, highq)
                p_is_smaller = false
            end
        end
    end
end

function Base.show(io::IO, o::Recursive{LR}) where {LR}
    print(io, LR, "-Recursive: ")
    A = alphabet(o)
    for (idx, p) in pairs(o.letter_order)
        letter = A[p]
        print(io, letter)
        idx == length(A) && break
        print(io, " < ")
    end
end
