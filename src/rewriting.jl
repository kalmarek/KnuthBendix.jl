RewritingBuffer{T}(::Any) where {T} = RewritingBuffer{T}() # no history
RewritingBuffer{T}(::IndexAutomaton{S}) where {T,S} = RewritingBuffer{T}(S[])

"""
    rewrite(u::AbstractWord, rewriting)
Rewrites word `u` using the `rewriting` object. The object must implement
`rewrite!(v::AbstractWord, w::AbstractWord, rewriting)`.

# Example
```jldoctest
julia> alph = Alphabet([:a, :A, :b], [2,1,3])
Alphabet of Symbol
  1. a    (inverse of: A)
  2. A    (inverse of: a)
  3. b    (self-inverse)

julia> a = Word([1]); A = Word([2]); b = Word([3]);

julia> rule = KnuthBendix.Rule(a*b => a)
1·3 ⇒ 1

julia> KnuthBendix.rewrite(a*b^2*A*b^3, rule) == a*A*b^3
true

julia> KnuthBendix.rewrite(a*A*b^3, alph) == b
true

```
"""
function rewrite(
    u::W,
    rewriting,
    rwbuffer::RewritingBuffer = RewritingBuffer{T}(rewriting);
    kwargs...,
) where {T,W<:AbstractWord{T}}
    isempty(rewriting) && return W(u)
    Words.store!(rwbuffer, u)
    v = rewrite!(rwbuffer, rewriting; kwargs...)
    return W(v)
end

function rewrite!(v::AbstractWord, w::AbstractWord, A::Any; kwargs...)
    throw(
        """No method for rewriting with $(typeof(A)). You need to implement
        `KnuthBendix.rewrite!(::AbstractWord, ::AbstractWord, ::$(typeof(A)); kwargs...)`
        yourself.""",
    )
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, rule::Rule)
Rewrite word `w` storing the result in `v` by using a single rewriting `rule`.

# Example
```jldoctest
julia> a = Word([1]); A = Word([2]); b = Word([3]);

julia> rule = KnuthBendix.Rule(a*b => a)
1·3 ⇒ 1

julia> v = one(a); KnuthBendix.rewrite!(v, a*b^2*A*b^3, rule);

julia> v == a*A*b^3
true
```
"""
@inline function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    rule::Rule;
    kwargs...,
)
    v = empty!(v)
    lhs, rhs = rule
    while !isone(w)
        push!(v, popfirst!(w))
        if issuffix(lhs, v)
            prepend!(w, rhs)
            resize!(v, length(v) - length(lhs))
        end
    end
    return v
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, A::Alphabet)
Rewrite word `w` storing the result in `v` by applying free reductions as
defined by the inverses present in alphabet `A`.

# Example
```jldoctest
julia> alph = Alphabet([:a, :A, :b], [2,1,3])
Alphabet of Symbol
  1. a    (inverse of: A)
  2. A    (inverse of: a)
  3. b    (self-inverse)

julia> a = Word([1]); A = Word([2]); b = Word([3]);

julia> v = one(a); KnuthBendix.rewrite!(v, a*b^2*A*b^3, alph);

julia> v == b
true
```
"""
@inline function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    A::Alphabet;
    kwargs...,
)
    v = empty!(v)
    while !isone(w)
        if isone(v)
            push!(v, popfirst!(w))
        else
            # the first check is for monoids only
            if hasinverse(last(v), A) && inv(last(v), A) == first(w)
                pop!(v)
                popfirst!(w)
            else
                push!(v, popfirst!(w))
            end
        end
    end
    return v
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, rws::RewritingSystem)
Rewrite word `w` storing the result in `v` using rewriting rules of `rws`.

The naive rewriting with [`RewritingSystem](@ref)

0. moves one letter from the beginning of `w` to the end of `v`
1. checks every rule `lhs → rhs` in `rws` until `v` contains `lhs` as a
suffix,
2. if found, the suffix is removed from `v` and `rhs` is prepended to `w`.

Those steps repeat until `w` is empty.

The complexity of this rewriting is `Ω(length(u) · N)`, where `N` is the total
size of left hand sides of the rewriting rules of `rws`.

See procedure `REWRITE_FROM_LEFT` from **Section 2.4**[^Sims1994], p. 66.

[^Sims1994]: C.C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    rws::AbstractRewritingSystem;
    kwargs...,
)
    v = empty!(v)
    while !isone(w)
        push!(v, popfirst!(w))
        for (lhs, rhs) in rules(rws)
            if issuffix(lhs, v)
                prepend!(w, rhs)
                resize!(v, length(v) - length(lhs))
                # since suffixes of v has been already checked against rws we
                # can break here
                break
            end
        end
    end
    return v
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, idxA::Automata.IndexAutomaton)
Rewrite word `w` storing the result in `v` using index automaton `idxA`.

Rewriting with an [`IndexAutomaton`](@ref Automata.IndexAutomaton) traces
(i.e. follows) the path in the automaton determined by `w` (since the
automaton is deterministic there is only one such path).
Whenever a terminal (i.e. accepting) state is encountered

1. its corresponding rule `lhs → rhs` is retrived,
2. the appropriate suffix of `v` (equal to `lhs`) is removed, and
3. `rhs` is prepended to `w`.

Tracing continues from the newly prepended letter.

To continue tracing `w` through the automaton we need to backtrack on our path
in the automaton and for this `rewrite` maintains a vector of visited states of
`idxA` (the history of visited states of `idxA`). Whenever a suffix is removed
from `v`, the path is rewinded (i.e. shortened) to the appropriate length and
the next letter of `w` is traced from the last state on the path. This maintains
the property that signature of the path is equal to `v` at all times.

Once index automaton is build the complexity of this rewriting is `Ω(length(w))`
which is the optimal rewriting strategy.

See procedure `INDEX_REWRITE` from **Section 3.5**[^Sims1994], p. 113.

[^Sims1994]: C.C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    idxA::Automata.IndexAutomaton{S};
    history = S[],
    kwargs...,
) where {S}
    resize!(history, 1)
    history[1] = Automata.initial(idxA)

    v = empty!(v)
    while !isone(w)
        σ = last(history) # current state
        x = popfirst!(w)
        @inbounds τ = Automata.trace(x, idxA, σ) # next state
        @assert !isnothing(τ) "idxA doesn't seem to be complete!; $σ"

        push!(v, x)
        push!(history, τ)
        Automata.isaccepting(idxA, τ) && continue
        # else ...
        lhs, rhs = Automata.value(τ)
        # lhs is a suffix of v, so we delete it from v
        resize!(v, length(v) - length(lhs))
        # and prepend rhs to w
        prepend!(w, rhs)
        # now we need to rewind the history tape
        resize!(history, length(history) - length(lhs))
        # @assert trace(v, ia) == (length(v), last(path))
    end
    return v
end

"""
    function rewrite!(bp::BufferPair, rewriting; kwargs...)
Rewrites word stored in `BufferPair` using `rewriting` object.

To store a word in `bp`
[`Words.store!`](@ref Words.store!(::BufferPair, ::AbstractWord))
should be used.

!!! warning
    This implementation returns an instance of `Words.BufferWord` aliased with
    the intenrals of `BufferPair`. You need to copy the return value if you
    want to take the ownership.
"""
function rewrite!(bp::RewritingBuffer, rewriting; kwargs...)
    v = if isempty(rewriting)
        Words.store!(bp.output, bp.input)
    else
        rewrite!(bp.output, bp.input, rewriting; kwargs...)
    end
    empty!(bp.input) # shifts bp._wWord pointers to the beginning of its storage
    return v
end
function rewrite!(bp::RewritingBuffer, rewriting::IndexAutomaton; kwargs...)
    v = if isempty(rewriting)
        Words.store!(bp.output, bp.input)
    else
        rewrite!(bp.output, bp.input, rewriting; history = bp.history, kwargs...)
    end
    empty!(bp.input) # shifts bp._wWord pointers to the beginning of its storage
    return v
end
