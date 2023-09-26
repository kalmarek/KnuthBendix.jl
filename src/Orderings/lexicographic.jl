abstract type LexOrdering <: RewritingOrdering end

"""
    LenLex{T} <: LexOrdering
    LenLex(A::Alphabet[; order=collect(A)])

Compare words first by their length, then break ties by (left-)lexicographic order.

# Example
```julia-repl
julia> Al = Alphabet([:a, :A, :b, :B]);

julia> ll1 = LenLex(Al)
LenLex: a < A < b < B

julia> ll2 = LenLex(Al, order=[:a, :b, :A, :B])
LenLex: a < b < A < B

julia> a, A, b, B = [Word([i]) for i in 1:length(Al)];

julia> KnuthBendix.lt(ll1, a*A, a*b)
true

julia> KnuthBendix.lt(ll2, a*A, a*b)
false
```
"""
struct LenLex{T} <: LexOrdering
    A::Alphabet{T}
    letter_order::Vector{Int}
end

function LenLex(A::Alphabet{T}; order::AbstractVector{T} = collect(A)) where {T}
    @assert length(order) == length(A)
    @assert Set(order) == Set(A)
    letter_order = sortperm([A[l] for l in order])
    return LenLex(A, letter_order)
end

"""
    WeightedLex{T,S} <: LexOrdering
    WeightedLex(A::Alphabet; weights[, order=collect(A)])

Compare words first by their weight, then break ties by (left-)lexicographic order.

The `weights` vector assigns weights to each letter __as they appear in the alphabet__
and the weight of a word is the sum of weights of all of its letters.

With all weights equal to `1` `WeightedLex` becomes `LenLex`.

# Example
```julia-repl
julia> al = Alphabet([:a, :A, :b, :B]);

julia> a, A, b, B = (Word([i]) for i in 1:length(al));

julia> wtlex = WeightedLex(al, weights=[1, 2, 3, 4], order=[:a, :b, :B, :A])
WeightedLex: a(1) < b(3) < B(4) < A(2)

julia> lt(wtlex, b * B, B * a * a * a)
true

julia> lt(wtlex, A*B, B*A)
false
```
"""
struct WeightedLex{T,S} <: LexOrdering
    A::Alphabet{T}
    weights::Vector{S}
    letter_order::Vector{Int}
end

function WeightedLex(
    A::Alphabet{T};
    weights::AbstractVector{S},
    order::AbstractVector{T} = collect(A),
) where {T,S}
    @assert length(A) == length(weights) == length(order)
    @assert Set(order) == Set(A)
    @assert all(>=(one(S)), weights)
    letter_order = sortperm([A[l] for l in order])
    return WeightedLex(A, weights, letter_order)
end

alphabet(o::LexOrdering) = o.A

weight(::LenLex, p::AbstractWord) = length(p)

function weight(o::WeightedLex, p::AbstractWord)
    return @inbounds sum(
        (o.weights[l] for l in p),
        init = zero(eltype(o.weights)),
    )
end

function lt(o::LexOrdering, lp::Integer, lq::Integer)
    return o.letter_order[lp] < o.letter_order[lq]
end

function Base.Order.lt(o::LexOrdering, p::AbstractWord, q::AbstractWord)
    wp = weight(o, p)
    wq = weight(o, q)
    wp ≠ wq && return wp < wq
    m = min(length(p), length(q))
    @inbounds for i in 1:m
        p[i] == q[i] && continue
        return lt(o, p[i], q[i])
    end
    # @debug "words are prefix of each other, using lexicographic ordering"
    return length(p) < length(q)
end

function Base.show(io::IO, o::LenLex)
    print(io, "LenLex: ")
    A = alphabet(o)
    for (idx, p) in pairs(invperm(o.letter_order))
        letter = A[p]
        print(io, letter)
        idx == length(A) && break
        print(io, " < ")
    end
end

function Base.show(io::IO, o::WeightedLex)
    A = alphabet(o)
    print(io, "WeightedLex: ")
    for (idx, p) in pairs(invperm(o.letter_order))
        letter = A[p]
        w = o.weights[p]
        print(io, letter, '(', w, ')')
        idx == length(A) && break
        print(io, " < ")
    end
end
