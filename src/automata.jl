## States

mutable struct State{I,D,V}
    transitions::Vector{State{I,D,V}}
    id::I
    data::D
    value::V

    State{I,D,V}() where {I,D,V} = new{I,D,V}()
    function State{I,D,V}(transitions::AbstractVector, id) where {I,D,V}
        return new{I,D,V}(transitions, id)
    end
end

function State{I,D,V}(id, data; max_degree::Integer) where {I,D,V}
    s = State{I,D,V}(Vector{State{I,D,V}}(undef, max_degree), id)
    s.data = data
    return s
end

isfail(s::State) = !isdefined(s, :transitions)
isterminal(s::State) = isdefined(s, :value)
id(s::State) = s.id

hasedge(s::State, i::Integer) = isassigned(s.transitions, i) && !isfail(s.transitions[i])

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
    if isfail(s)
        print(io, "fail")
    elseif isterminal(s)
        print(io, "TState: ", value(s))
    else
        print(io, "NTState: ", id(s), " (data=", s.data, ")")
    end
end

function Base.show(io::IO, ::MIME"text/plain", s::State)
    if isfail(s)
        print(io, "fail state")
    elseif isterminal(s)
        println(io, "Terminal state")
        println(io, "\tvalue: $(value(s))")
    else
        println(io, "Non-terminal state: ", id(s))
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

mutable struct IndexAutomaton{S,V} <: Automaton
    initial::S
    states::V
    _path::Vector{S}
end

initial(idxA::IndexAutomaton) = idxA.initial

hasedge(idxA::IndexAutomaton, σ::State, label::Integer) = hasedge(σ, label)
addedge!(idxA::IndexAutomaton, src::State, dst::State, label) = src[label] = dst

Base.isempty(idxA::Automaton) = degree(initial(idxA)) == 0

word_type(::IndexAutomaton{<:State{S,D,V}}) where {S,D,V} = eltype(V)

trace(label::Integer, idxA::IndexAutomaton, σ::State) = σ[label]

function IndexAutomaton(R::RewritingSystem{W}) where {W}
    id = @view one(W)[1:0]
    # id = one(W)
    α = State{typeof(id),UInt32,eltype(rules(R))}(
        id,
        0,
        max_degree = length(alphabet(R)),
    )

    indexA = IndexAutomaton(α, Vector{typeof(α)}[], [α])
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
    radius = length(id(σ))
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

function direct_edges!(idxA::IndexAutomaton, rwrules)
    α = initial(idxA)
    S = typeof(α)
    n = max_degree(α)
    for rule in rwrules
        lhs, _ = rule
        σ = α
        α.data += 1
        for (radius, letter) in enumerate(lhs)
            if !hasedge(idxA, σ, letter)
                τ = S(@view(lhs[1:radius]), 0, max_degree = n)
                addstate!(idxA, τ)
                addedge!(idxA, σ, τ, letter)
            end
            @assert id(σ[letter]) == @view lhs[1:radius]

            σ = σ[letter]
            σ.data += 1
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

            τ = let U = @view id(σ)[2:end]
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
    path = idxA._path,
)
    resize!(path, 1)
    path[1] = initial(idxA)

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
