"""
    rewrite(u::AbstractWord, rewriting)
Rewrites word `u` (from left) using `rewriting` object. The object must implement
`rewrite!(v::AbstractWord, w::AbstractWord, rewriting)`.
"""
@inline function rewrite(
    u::W,
    rewriting,
    vbuff = Words.BufferWord{T}(0, length(u)),
    wbuff = Words.BufferWord{T}(length(u), 0),
) where {T,W<:AbstractWord{T}}
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

# buffers are not necessary for free rewrite
function rewrite(u::AbstractWord, A::Alphabet, vbuff = nothing, wbuff = nothing)
    v = similar(u)
    resize!(v, 0)
    return rewrite!(v, u, A)
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, rule::Rule)
Rewrite word `w` storing the result in `v` by using a single rewriting `rule`.
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
"""
@inline function rewrite!(v::AbstractWord, w::AbstractWord, A::Alphabet)
    v = resize!(v, 0)
    idx = 1
    isgroup = is_group_alphabet(A)
    @inbounds while idx ≤ length(w)
        l = w[idx]
        if isone(v)
            push!(v, l)
        else
            if (isgroup || hasinverse(v[end], A)) && inv(v[end], A) == l
                pop!(v)
            else
                push!(v, l)
            end
        end
        idx += 1
    end
    return v
end

"""
    rewrite!(v::AbstractWord, w::AbstractWord, rws::RewritingSystem)
Rewrite word `w` storing the result in `v` by left using rewriting rules of
rewriting system `rws`. See [Sims, p.66]
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
