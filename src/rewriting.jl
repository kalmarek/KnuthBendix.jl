"""
    rewrite(u::AbstractWord, rewriting)
Rewrites word `u` (from left) using `rewriting` object. The object must implement
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
@inline function rewrite(
    u::W,
    rewriting,
    vbuff = Words.BufferWord{T}(0, length(u)),
    wbuff = Words.BufferWord{T}(length(u), 0),
) where {T,W<:AbstractWord{T}}
    isempty(rewriting) && return u
    Words.store!(wbuff, u)
    v = rewrite!(vbuff, wbuff, rewriting)
    return W(v, false)
end

function rewrite!(v::AbstractWord, w::AbstractWord, A::Any)
    msg_ = [
        "No method for rewriting with $(typeof(A)).",
        "You need to implement",
        "KnuthBendix.rewrite!(::AbstractWord, ::AbstractWord, ::$(typeof(A)))",
        "yourself",
    ]
    throw(join(msg_, " "))
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
@inline function rewrite!(v::AbstractWord, w::AbstractWord, rule::Rule)
    v = resize!(v, 0)
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
@inline function rewrite!(v::AbstractWord, w::AbstractWord, A::Alphabet)
    v = resize!(v, 0)
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

See procedure `REWRITE_FROM_LEFT` from **Section 2.4**[^Sims1994], p. 66.

[^Sims1994]: C.C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
@inline function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    rws::RewritingSystem,
)
    v = resize!(v, 0)
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
    rewrite!(v::AbstractWord, w::AbstractWord, idxA::Automata.IndexAutomaton;
        [history])
Rewrite word `w` storing the result in `v` using index automaton `idx`.

See procedure `INDEX_REWRITE` from **Section 3.5**[^Sims1994], p. 113.

[^Sims1994]: C.C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    idxA::Automata.IndexAutomaton{S};
    history_tape = S[],
) where {S}
    resize!(history_tape, 1)
    history_tape[1] = Automata.initial(idxA)

    resize!(v, 0)
    while !isone(w)
        x = popfirst!(w)
        σ = last(history_tape) # current state
        @inbounds τ = Automata.trace(x, idxA, σ) # next state
        @assert !isnothing(τ) "idxA doesn't seem to be complete!; $σ"

        if Automata.isterminal(idxA, τ)
            lhs, rhs = Automata.value(τ)
            # lhs is a suffix of v·x, so we delete it from v
            resize!(v, length(v) - length(lhs) + 1)
            # and prepend rhs to w
            prepend!(w, rhs)
            # now we need to rewind the history tape
            resize!(history_tape, length(history_tape) - length(lhs) + 1)
            # @assert trace(v, ia) == (length(v), last(path))
        else
            push!(v, x)
            push!(history_tape, τ)
        end
    end
    return v
end
