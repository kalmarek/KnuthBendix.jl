###########################################
# States

"""
    AbstractState{T}
Abstract type representing state of the (index) automaton.

The subtypes of `AbstractState{T}` should implement the following methods which
constitute `AbstractState` interface:
 * `name`: gives external name of the state
 * `isterminal`: gives whether the state is terminal or not (i.e. whether the
    state represents left-hand side of some rewriting rule)
 * `rightrule`: gives the right-hand side of the rewriting rule (for terminal
    states) or Nothing (for non-terminal states)
 * `inedges`: gives the vector (indexed by position of the letter in the alphabet)
    of states from which there is an edge entering given state and labelled by
    the given letter
 * `outedges`: gives the vector (indexed by position of the letter in the alphabet)
    of states to which there is an edge starting at given state and labelled by
    the given letter
 * `Base.length`: gives the length of the signature of the shortest path to the
    state, which starts at initial state (length of "simple path")
"""
abstract type AbstractState{T} end

"""
    State{T} <: AbstractState{T}
State as a name (corresponding to the signature of the simple path ending at this
state), possibly a right-hand part of the rewriting rule, vector of states (indexed
by the position of the letter in the alphabet) from which there is an edge (labelled
by letter indexed) to this state and vector of states (indexed by position of the
letter in the alphabet) to which there is an edge (labelled by letter indexed) from
this state.
"""
mutable struct State{T} <: AbstractState{T}
    name::AbstractWord{T}
    rrule::Union{AbstractWord{T}, Nothing}
    ined::Vector{Union{State{T}, Nothing}}
    outed::Vector{Union{State{T}, Nothing}}
end


State(name::AbstractWord{T}, absize::Int) where {T} = State(name, nothing, Vector{Union{State{T}, Nothing}}(nothing, absize), Vector{Union{State{T}, Nothing}}(nothing, absize))
State(name::AbstractWord{T}, rrule::Union{AbstractWord{T}, Nothing}) where T = State(name, rrule, State{T}[], State{T}[])
State(name::AbstractWord{T}) where T = State(name, nothing, State{T}[], State{T}[])

name(s::State) = s.name
isterminal(s::State) = (s.rrule !== nothing)
rightrule(s::State) = s.rrule
inedges(s::State) = s.ined
outedges(s::State) = s.outed
Base.length(s::State) = length(name(s))

"""
    declarerightrule!(s::State, w::AbstractWord)
Decalres given word as a right-hand side rule of a given state (and makes this)
state terminal.
"""
function declarerightrule!(s::State, w::AbstractWord)
    s.rrule = w
end

function Base.show(io::IO, s::State)
    if isterminal(s)
        println(io, "Terminal state $(name(s))")
        println(io, "Right rule: $(rightrule(s))")
        println(io, " Edges entering:")
        for (i, e) in enumerate(inedges(s))
            (e !== nothing) && println(io, "   ", " - with label $(i) from state $(name(e))")
        end
    else
        println(io, "State $(name(s))")
        println(io, " Edges entering:")
        for (i, fromst) in enumerate(inedges(s))
            (fromst !== nothing) && println(io, "   ", " - with label $(i) from state $(name(fromst))")
        end
        println(io, " Edges leaving:")
        for (i, tost) in enumerate(outedges(s))
            (tost !== nothing) && println(io, "   ", " - with label $(i) from state $(name(tost))")
        end
    end
end


###########################################
# Automata

"""
    AbstractAutomaton
Abstract type representing (index) automaton.

The subtypes of `AbstractAutomaton` should implement the following methods which
constitute `AbstractAutomaton` interface:
 * `states`: returning the list of states in the automaton
 * `initialstate`: returning the initial state of the automaton
 * `Base.push!`: appending a single state to the automaton
 * `addedge!`: adding edge between two states
 * `removeedge!`: removing edge between two states
 * `Base.deleteat!`: delating state at given position (together with edges)
 * `walk`: traveling through the automaton according to given path and initial state

"""
abstract type AbstractAutomaton end

"""
    Automaton{T} <: AbstractAutomaton
Automaton as a vector of states together with alphabet.
"""
struct Automaton{T} <: AbstractAutomaton
    states::Vector{State{T}}
    abt::Alphabet
end

# setting the default type to UInt16
Automaton(states::Vector{Union{State{T}, AbstractState{T}}}, abt::Alphabet) where {T<:Integer} = Automaton{UInt16}(states, abt)

Automaton(abt::Alphabet) = Automaton([State(Word(Int[]), length(abt))], abt)

states(a::Automaton) = a.states
initialstate(a::Automaton) = states(a)[1]

function Base.push!(a::Automaton{T}, s::State{T}) where {T}
    @assert (length(s.ined) == length(a)) && (length(s.outed) == length(a)) "Tables of in and out edges must have the same length as alphabet"
    push!(a.states, s)
end

Base.push!(a::Automaton{T}, name::AbstractWord{T}) where {T} = push!(states(a), State(name, length(a.abt)))


"""
    addedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
Adds the edge with a given `label` `from` one state `to` another .
"""
function addedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
    @assert 0 < label <= length(a.abt) "Edge must be a valid pointer to the label (letter)"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[label] = states(a)[to]
    inedges(states(a)[to])[label] = states(a)[from]
end

function addedge!(a::Automaton, label::Integer, from::State{T}, to::State{T}) where {T}
    @assert from in states(a) "State from which the edge is added must be inside automaton"
    @assert to in states(a) "State to which the edge is added must be inside automaton"
    outedges(from)[label] = to
    inedges(to)[label] = from
end
# Should we also check if the edge corresponding to a given letter does not exist?

"""
    removeedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
Removes the edge with a given `label` `from` one state `to` another.
"""
function removeedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
    @assert 0 < label <= length(a.abt) "Edge must be a valid pointer to the label (letter)"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[label] = nothing
    inedges(states(a)[to])[label] = nothing
end

function Base.deleteat!(a::Automaton, idx::Integer)
    for (i, σ) in enumerate(outedges(states(a)[idx]))
        (σ === nothing) || (inedges(σ)[i] = nothing)
    end
    for (i, σ) in enumerate(inedges(states(a)[idx]))
        (σ === nothing) || (outedges(σ)[i] = nothing)
    end
    deleteat!(states(a), idx)
end

"""
    walk(a::Automaton, sig::AbstractWord, first::Integer)
Travels through index automaton according to the path given by the signature
starting from the state at position `first`. Returns a tuple (idx, state) where
idx is the last index of the letter from signature used to travel through automaton
and state is the resulting state. Note that `idx` ≂̸ `length(sig)` that there is no
path corresponding to the full signature.
"""
function walk(a::Automaton, sig::AbstractWord, first::Integer)
    σ = states(a)[first]
    i = 0
    for (idx, k) in enumerate(sig)
        next = outedges(σ)[k]
        next === nothing ? break : (i, σ) = (idx, next)
    end
    return (i, σ)
end

walk(a::Automaton, w::AbstractWord) = walk(a, w, 1)


function Base.show(io::IO, a::Automaton)
    println(io, "Automaton with $(length(states(a))) states")
    abt = a.abt
    for (i, state) in enumerate(states(a))
        println(io, " $i. Edges leaving state (", constructword(name(state), abt), "):")

        for (i, tostate) in enumerate(outedges(state))
            (tostate !== nothing) && println(io, "   ", " - with label ", abt[i], " to state (", constructword(name(tostate), abt), ")")
        end
    end
end
constructword(W::AbstractWord, A::Alphabet) = isone(W) ? "ε" : join(A[w] for w in W)


###########################################
# Ad index automata

"""
    makeindexautomaton(rws::RewritingSystem, abt::Alphabet)
Creates index automaton corresponding to a given rewriting system.
"""
function makeindexautomaton(rws::RewritingSystem, abt::Alphabet)
    Σᵢ = Int[0]
    a = Automaton(abt)
    # Determining simple paths
    for (lhs, rhs) in rules(rws)
        σ = initialstate(a)
        for (i, letter) in enumerate(lhs)
            if (outedges(σ)[letter]) !== nothing
                σ = outedges(σ)[letter]
            else
                push!(a, lhs[1:i])
                push!(Σᵢ, i)
                addedge!(a, letter, σ, states(a)[end])
                σ = states(a)[end]
            end
        end
        terminal = states(a)[end]
        declarerightrule!(terminal, rhs)
        # Add loops for terminal state
        for i in 1:length(outedges(terminal))
            addedge!(a, i, terminal, terminal)
        end
    end
    # Determining cross paths
    for state in outedges(initialstate(a))
        (state === nothing) && addedge!(a, state, 1, 1)
    end
    i = 1
    indcs = findall(isequal(i), Σᵢ)
    while !isempty(indcs)
        for idx in indcs
            σ = states(a)[idx]
            τ = walk(a, name(σ)[2:end])[2]
            for (letter, state) in enumerate(outedges(σ))
                (state === nothing) && addedge!(a, letter, σ, outedges(τ)[letter])
            end
        end
        i += 1
        indcs = findall(isequal(i), Σᵢ)
    end
    return a
end


"""
    index_rewrite(u::AbstractWord{T}, a::Automaton{T}) where {T}
Rewrites a word using a given index automaton.
"""
function index_rewrite(u::AbstractWord{T}, a::Automaton{T}) where {T}
    v = one(u)
    w = copy(u)
    states = Vector{State{T}}(undef, length(w))
    state = initialstate(a)
    states[1] = state

    while !isone(w)
        x = popfirst!(w)
        k = length(v) + 1
        state = outedges(states[k])[x]

        if !isterminal(state)
            @inbounds states[k+1] = state
            push!(v, x)
        else
            v = v[1:end-length(state)+1]
            w = prepend!(w, rightrule(state))
        end
    end
    return v
end
