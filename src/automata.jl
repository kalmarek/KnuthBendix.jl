
## States

mutable struct State{T,S,W}
    transitions::Vector{State{T,S}}
    name::W
    data::T
    value::S

    function State{T,S,W}(n::Integer, name::AbstractWord) where {T,S,W}
        return new{T,S,W}(Vector{State{T,S,W}}(undef, n), name)
    end
    function State{T,S,W}(n::Integer, name::AbstractWord, data) where {T,S,W}
        return new{T,S,W}(Vector{State{T,S,W}}(undef, n), name, data)
    end
end

isterminal(s::State) = isdefined(s, :value)
name(s::State) = s.name

hasedge(s::State, i::Integer) = isassigned(s.transitions, i)

function Base.getindex(s::State, i::Integer)
    !hasedge(s, i) && return nothing
    return s.transitions[i]
end
function Base.setindex!(s::State, v::State, i::Integer)
    return s.transitions[i] = v
end

function value(s::State)
    isterminal(s) && return s.value
    return throw("state is not terminal and its value is not assigned")
end
setvalue!(s::State, v) = s.value = v

max_degree(s::State) = length(s.transitions)
degree(s::State) = count(i -> hasedge(s, i), 1:max_degree(s))
iscomplete(s::State) = degree(s) == max_degree(s)

transitions(s::State) = (s[i] for i in 1:max_degree(s) if hasedge(s, i))

function Base.show(io::IO, s::State)
    if isterminal(s)
        print(io, "TState: ", value(s))
    else
        print(io, "NTState: ", name(s), " (data=", s.data, ")")
    end
end

function Base.show(io::IO, ::MIME"text/plain", s::State)
    if isterminal(s)
        println(io, "Terminal state")
        println(io, "\tvalue: $(value(s))")
    else
        println(io, "Non-terminal state: ", name(s))
        println(io, "\tdata: ", s.data)
        println(io, "\ttransitions:")
        for l in 1:max_degree(s)
            !hasedge(s, l) && continue
            print(io, "\t\t$l → ")
            show(io, s[l])
            println(io)
        end
    end
end

###########################################
# Automata

abstract type Automaton end

"""
	hasedge(A::Automaton, σ, label)
Check if `A` contains an edge starting at `σ` labeled by `label`
"""
function hasedge(A::Automaton, σ, label) end

function addedge!(A::Automaton, src::S, dst::S, label) where {S} end

"""
	trace(label, A::Automaton, σ)
Return `τ` if `(σ, label, τ)` is in `A`, otherwise return nothing.
"""
function trace(label, A::Automaton, σ) end

"""
	trace(w::AbstractVector{<:Integer}, A::Automaton[, σ=initial(A)])
Return a pair `(l, τ)`, where
 * `l` is the length of the longest prefix of `w` which defines a path starting at `σ` in `A` and
 * `τ` is the last state (node) on the path.
"""
@inline function trace(w::AbstractVector, A::Automaton, σ = initial(A))
    for (i, l) in enumerate(w)
        if hasedge(A, σ, l)
            σ = trace(l, A, σ)
        else
            return i - 1, σ
        end
    end
    return length(w), σ
end

## particular implementation of Index Automaton

mutable struct IndexAutomaton{T,S,V} <: Automaton
    initial::State{T,S}
    states::V
end

initial(idxA::IndexAutomaton) = idxA.initial
alphabet(idxA::IndexAutomaton) = idxA.alphabet

hasedge(idxA::IndexAutomaton, σ::State, label::Integer) = hasedge(σ, label)
addedge!(idxA::IndexAutomaton, src::State, dst::State, label) = src[label] = dst

Base.isempty(idxA::Automaton) = degree(initial(idxA)) == 0

trace(label::Integer, idxA::IndexAutomaton, σ::State) = σ[label]

function IndexAutomaton(R::RewritingSystem{W}) where {W}
    A = alphabet(R)
    α = State{UInt32,eltype(rules(R)),W}(length(A), one(W), 0)

    indexA = IndexAutomaton(α, Vector{typeof(α)}[])
    append!(indexA, rules(R))

    return indexA
end

function Base.append!(idxA::IndexAutomaton, rwrules)
    # isempty(rwrules) && return idxA
    idxA = direct_edges!(idxA, rwrules)
    idxA = skew_edges!(idxA)
    return idxA
end

function addstate!(idxA::IndexAutomaton, σ::State)
    radius = length(name(σ))
    ls = length(idxA.states)
    if ls < radius
        T = eltype(idxA.states)
        resize!(idxA.states, radius)
        for i in ls+1:radius
            idxA.states[i] = Vector{T}[]
        end
    end
    return push!(idxA.states[radius], σ)
end

_word_type(idxA::IndexAutomaton{T,V}) where {T,V} = _word_type(V)
_word_type(::Type{Rule{W}}) where {W} = W

function direct_edges!(idxA::IndexAutomaton, rwrules)
    W = _word_type(idxA)
    α = initial(idxA)
    S = typeof(α)
    n = max_degree(α)
    for rule in rwrules
        lhs, _ = rule
        σ = α
        σ.data = σ.data + 1
        for (radius, l) in enumerate(lhs)
            if !hasedge(σ, l)
                τ = S(n, lhs[1:radius], 0)
                addstate!(idxA, τ)
                addedge!(idxA, σ, τ, l)
            end
            σ = σ[l]
            σ.data = σ.data + 1
        end
        setvalue!(σ, rule)
    end
    return idxA
end

function skew_edges!(idxA::IndexAutomaton)
    # add missing loops at the root (start of the induction)
    α = initial(idxA)
    if !iscomplete(α)
        for x in 1:max_degree(α)
            if !hasedge(idxA, α, x)
                addedge!(idxA, α, α, x)
            end
        end
    end

    # this has to be done in breadth-first fashion
    # to ensure that trace(U, idxA) is successful
    for states in idxA.states
        for σ in states # states of particular radius
            iscomplete(σ) && continue

            τ = let U = @view name(σ)[2:end]
                l, τ = trace(U, idxA) # we're tracing a shorter word, so...
                @assert l == length(U) # the whole U defines a path in A and
                @assert iscomplete(τ) # (by the induction step)
                τ
            end

            for label in 1:max_degree(σ)
                hasedge(idxA, σ, label) && continue
                addedge!(idxA, σ, τ[label], label)
            end
        end
    end
    return idxA
end

function rewrite_from_left!(
    v::AbstractWord,
    w::AbstractWord,
    idxA::IndexAutomaton;
    path = [initial(idxA)],
)
    resize!(v, 0)
    sizehint!(path, length(w))
    while !isone(w)
        x = popfirst!(w)
        σ = path[end] # current state
        τ = σ[x] # next state
        @assert !isnothing(τ) "ia doesn't seem to be complete!; $σ"

        if isterminal(τ)
            lhs, rhs = value(τ)
            # lhs is a suffix of v·x, so we delete it from v
            resize!(v, length(v) - length(lhs) + 1)
            # and prepend rhs to w
            prepend!(w, rhs)
            # now we need to rewind the path
            resize!(path, length(path) - length(lhs) + 1)
            # @assert trace(v, ia) == (length(v), last(path))
        else
            push!(v, x)
            push!(path, τ)
        end
    end
    return v
end

function rebuild!(idxA::IndexAutomaton, rws::RewritingSystem)
    at = IndexAutomaton(rws)
    idxA.initial = at.initial
    idxA.states = at.states
    return idxA
end
