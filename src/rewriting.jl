RewritingBuffer{T}(::Any) where {T} = RewritingBuffer{T}() # no history

function RewritingBuffer{T}(::IndexAutomaton{S}) where {T,S}
    return RewritingBuffer{T}(Vector{S}())
end

function RewritingBuffer{T}(::PrefixAutomaton) where {T}
    return RewritingBuffer{T}(PackedVector{UInt32}())
end

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
    function rewrite!(rwb::RewritingBuffer, rewriting; kwargs...)
Rewrites word stored in `rwb` using `rewriting` object.

To store a word in `rwb`
[`Words.store!`](@ref Words.store!(::RewritingBuffer, ::AbstractWord))
should be used.

!!! warning
    This implementation returns an instance of `Words.BufferWord` whose memory
    is owned by `rwb`. To take the ownership You need to copy the return value
    explicitly.
"""
function rewrite!(rwb::RewritingBuffer, rewriting; kwargs...)
    v = if isempty(rewriting)
        Words.store!(rwb.output, rwb.input)
    else
        rewrite!(rwb.output, rwb.input, rewriting; kwargs...)
    end
    empty!(rwb.input) # shifts bp.input pointers to the beginning of its storage
    return v
end

function rewrite!(
    rwb::RewritingBuffer,
    rewriting::Automata.Automaton;
    kwargs...,
)
    v = if isempty(rewriting)
        Words.store!(rwb.output, rwb.input)
    else
        rewrite!(rwb.output, rwb.input, rewriting; history = rwb.history, kwargs...)
    end
    empty!(rwb.input) # shifts bp.input pointers to the beginning of its storage
    return v
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

The naive rewriting with [`RewritingSystem`](@ref)

  0. moves one letter from the beginning of `w` to the end of `v`
  1. checks every rule `lhs → rhs` in `rws` until `v` contains `lhs` as a
     suffix,
  2. if found, the suffix is removed from `v` and `rhs` is prepended to `w`.

Those steps repeat until `w` is empty.

The complexity of this rewriting is `Ω(length(w) · N)`, where `N` is the total
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

Tracing continues from the first letter of the newly prepended word.

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
    rewrite!(v::AbstractWord, w::AbstractWord, pfxA::PrefixAutomaton[; history, skipping])
Rewrite word `w` storing the result in `v` using prefix automaton `idxA`.
As rewriting rules are stored **externally**, they must be passed in the
`rules` keyword argument.

Rewriting with a [`PrefixAutomaton`](@ref Automata.PrefixAutomaton) traces
(i.e. follows) simultanously all paths in the automaton determined by `w`.
To be more precise we trace a path in the power-set automaton (states are the
subsets of states of the original automaton) via a prodedure described by Sims as
the lazy _accessible subset construction_.
Since the non-deterministic part of the automaton consists of `ε`-loop at the
initial state there are at most `length(w)-1` such paths.

Whenever a non-accepting state is encountered **on any** of those paths

1. its corresponding rule `lhs → rhs` is retrived,
2. the appropriate suffix of `v` (equal to `lhs`) is removed, and
3. `rhs` is prepended to `w`.

Tracing continues from the first letter of the newly prepended word.

To continue tracing `w` through the automaton we need to backtrack on our path
in the automaton and for this `rewrite` maintains a history consisting of subsets of
states of `pfxA`. Whenever a suffix is removed from `v`, the path is rewinded
(i.e. shortened to the appropriate length) and the next letter of `w` is traced
from the last state on the path. This maintains the property that signature of
the path is equal to `v` at all times.

Once prefix automaton `pfxA` is build the complexity of this rewriting is
`Ω(length(w) · max(length(w), m))`, where `m` is the number of states of `pfxA`.
"""
function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    pfxA::PrefixAutomaton;
    history::PackedVector = PackedVector{UInt32}(),
    skipping = nothing,
)
    resize!(history, 0)
    __unsafe_push!(history, Automata.initial(pfxA))
    __unsafe_finalize!(history)
    v = resize!(v, 0)
    # we're doing path tracing on PrefixAutomaton that is non-deterministic
    # in the sense that we add an ε-loop at the initial state
    # thus this is path tracing via (lazy) accessible set construction
    # i.e. simultanously tracing all possible paths with the given signature,
    # or tracing a path in power-set automaton (states are the subsets of
    # states of the original automaton).
    # We rewind the history of ALL paths whenever a terminal is found in ONE of them.
    while !isone(w)
        letter = popfirst!(w)
        # we're tracing a bunch of paths simultanously:
        rule_found = false
        # @info "current multi-state" last(history)
        for σ in last(history)
            Automata.hasedge(pfxA, σ, letter) || continue # this path doesn't proceed any further
            τ = Automata.trace(letter, pfxA, σ)
            # @info "with letter=$letter we transition" src = σ dst = τ
            -τ == skipping && continue
            if Automata.isaccepting(pfxA, τ)
                __unsafe_push!(history, τ)
            else
                # find the length of the corresponding lhs and rewind
                # @info "The dst is non-accepting, using:" pfxA.rwrules[-τ] v
                lhs, rhs = pfxA.rwrules[-τ]
                resize!(v, length(v) - length(lhs) + 1)
                prepend!(w, rhs)
                resize!(history, length(history) - length(lhs) + 1)
                rule_found = true
                break
            end
        end
        if !rule_found
            # @info """none of the dsts were terminal:
            # extending v (by $letter) & pushing initial (1) to history"""
            push!(v, letter)
            # we finish by a suffix of w by adding the initial state:
            __unsafe_push!(history, Automata.initial(pfxA))
            # after we're done with all of the path we proclaim the next subset
            __unsafe_finalize!(history)
        end
        # @info "afterwards:" v w
    end
    return v
end
