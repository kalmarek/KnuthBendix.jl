###########################################
# States

"""
    AbstractState{T, N, W}
Abstract type representing state of the (index) automaton.

The subtypes of `AbstractState{T, N, W}` should implement the following methods which
constitute `AbstractState` interface:
 * `name`: gives external name of the state
 * `isterminal`: returns whether the state is terminal or not (i.e. whether the
    state represents left-hand side of some rewriting rule)
 * `rightrule`: gives the right-hand side of the rewriting rule (for terminal
    states) or Nothing (for non-terminal states)
 * `inedges`: gives the vector (indexed by position of the letter in the alphabet)
    of states from which there is an edge entering given state and labelled by
    the given letter
 * `outedges`: gives the vector (indexed by position of the letter in the alphabet)
    of states to which there is an edge starting at given state and labelled by
    the given letter
 * `isnoedge`: returns whether the state represents lack of edge or not
 * `Base.length`: gives the length of the signature of the shortest path to the
    state, which starts at initial state (length of "simple path")
"""
abstract type AbstractState{T, N, W} end

"""
    State{T, N, W<:AbstractWord{T}} <: AbstractState{T, N, W}
State as a name (corresponding to the signature of the simple path ending at this
state), indication whether it is terminal (in which case there is a right-hand part
of the rewriting rule, vector of states (indexed by the position of the letter in
the alphabet) from which there is an edge (labelled by letter indexed) to this state
and vector of states (indexed by position of the letter in the alphabet) to which
there is an edge (labelled by letter indexed) from this state.
"""
mutable struct State{T, N, W<:AbstractWord{T}} <: AbstractState{T, N, W}
    name::W
    terminal::Bool
    rrule::W
    ined::Vector{State{T, N, W}}
    outed::NTuple{N, State{T, N, W}}
    representsnoedge::Bool

    function State{T, N, W}() where {T, N, W<:AbstractWord{T}}
        x = new()
        x.representsnoedge = true
        return x
    end

    function State(name::W, noedge::State{T, N, W}) where {T, N, W<:AbstractWord{T}}
        s = State{T, N, W}()
        s.name = name
        s.terminal = false
        s.rrule = W()
        s.ined = State{T, N, W}[]
        s.outed = ntuple(i -> noedge, N)
        s.representsnoedge = false
        return s
    end
end

name(s::State) = s.name
isterminal(s::State) = s.terminal
rightrule(s::State) = isterminal(s) ? s.rrule : nothing
inedges(s::State) = s.ined
outedges(s::State) = s.outed
isnoedge(s::State) = s.representsnoedge
Base.length(s::State) = length(name(s))

"""
    declarerightrule!(s::State{T, N, W}, w::W) where {T, N, W}
Decalres given word as a right-hand side rule of a given state (and makes this)
state terminal.
"""
function declarerightrule!(s::State{T, N, W}, w::W) where {T, N, W}
    s.terminal = true
    s.rrule = w
end

function Base.show(io::IO, s::State)
    if isnoedge(s)
        println("Unintialized state")
    elseif isterminal(s)
        println(io, "Terminal state $(name(s))")
        println(io, "Right rule: $(rightrule(s))")
        println(io, " Edges entering:")
        for (i, e) in enumerate(inedges(s))
            !isnoedge(e) && println(io, "   ", " - with label $(i) from state $(name(e))")
        end
    else
        println(io, "State $(name(s))")
        println(io, " Edges entering:")
        for (i, fromst) in enumerate(inedges(s))
            !isnoedge(fromst) && println(io, "   ", " - with label $(i) from state $(name(fromst))")
        end
        println(io, " Edges leaving:")
        for (i, tost) in enumerate(outedges(s))
            !isnoedge(tost) && println(io, "   ", " - with label $(i) from state $(name(tost))")
        end
    end
end


###########################################
# Automata

"""
    AbstractAutomaton{T, N, W}
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
abstract type AbstractAutomaton{T, N, W} end

"""
    Automaton{T, N, W<:AbstractWord{T}} <: AbstractAutomaton{T, N, W}
Automaton as a vector of states together with alphabet.
"""
struct Automaton{T, N, W<:AbstractWord{T}} <: AbstractAutomaton{T, N, W}
    states::Vector{State{T, N, W}}
    abt::Alphabet
    uniquenoedge::State{T, N, W}
end

# Default type is set to UInt16
function Automaton(abt::Alphabet)
    uniquenoedge = State{UInt16, length(abt), Word{UInt16}}()
    Automaton{UInt16, length(abt), Word{UInt16}}([State(Word{UInt16}(), uniquenoedge)], abt, uniquenoedge)
end

states(a::Automaton) = a.states
initialstate(a::Automaton) = states(a)[1]
noedge(a::Automaton) = a.uniquenoedge

Base.push!(a::Automaton{T, N, W}, name::W) where {T, N, W} = push!(states(a), State(name, noedge(a)))

"""
    replace(k::NTuple{N, T}, val, idx::Integer) where {N, T}
Returns a copy of `NTuple` `k` with value at index `idx` changed to `val`.
"""
Base.@propagate_inbounds function replace(k::NTuple{N, T}, val, idx::Integer) where {N, T}
    @boundscheck 1 ≤ idx ≤ N || throw(BoundsError(k, idx))
    return ntuple( i->i==idx ? val : k[i], N)
end


"""
    updateoutedges!(s::State{T, N, W}, to::State{T, N, W}, label::Integer) where {T, N, W}
Updates outedges of the state `s` with state `to` connected through the edge `label`.
"""
Base.@propagate_inbounds function updateoutedges!(s::State{T, N, W}, to::State{T, N, W}, label::Integer) where {T, N, W}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(s), label))
    @inbounds s.outed = replace(outedges(s), to, label)
end

"""
    addinedge!(s::State{T, N, W}, from::State{T, N, W}) where {T, N, W}
Updates `inedges` of the state `s` with state `from` connected through some edge.
"""
function addinedge!(s::State{T, N, W}, from::State{T, N, W}) where {T, N, W}
    push!(inedges(s), from)
end

"""
    addedge!(a::Automaton{T, N, W}, label::Integer, from::Integer, to::Integer) where {T, N, W}
Adds the edge with a given `label` directed `from` state `to` state.
"""
Base.@propagate_inbounds function addedge!(a::Automaton{T, N, W}, label::Integer, from::Integer, to::Integer) where {T, N, W}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(states(a)[from]), label))
    @boundscheck checkbounds(states(a), from)
    @boundscheck checkbounds(states(a), to)
    @inbounds fromstate = states(a)[from]
    @inbounds tostate = states(a)[to]
    @inbounds updateoutedges!(fromstate, tostate, label)
    addinedge!(tostate, fromstate)
end

Base.@propagate_inbounds function addedge!(a::Automaton{T, N, W}, label::Integer, from::State{T, N, W}, to::State{T, N, W}) where {T, N, W}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(from), label))
    @assert from in states(a) "State from which the edge is added must be inside automaton"
    @assert to in states(a) "State to which the edge is added must be inside automaton"
    @inbounds updateoutedges!(from, to, label)
    addinedge!(to, from)
end
# Should we also check if the edge corresponding to a given letter does not exist?

"""
    removeedge!(a::Automaton{T, N, W}, label::Integer, from::Integer, to::Integer) where {T, N, W}
Removes the edge with a given `label` `from` one state `to` another.
"""
Base.@propagate_inbounds function removeedge!(a::Automaton{T, N, W}, label::Integer, from::Integer, to::Integer) where {T, N, W}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(states(a)[from]), label))
    @boundscheck checkbounds(states(a), from)
    @boundscheck checkbounds(states(a), to)
    @inbounds fromstate = states(a)[from]
    @inbounds tostate = states(a)[to]
    @inbounds updateoutedges!(fromstate, noedge(a), label)
    deleteat!(inedges(tostate), findfirst(isequal(fromstate), inedges(tostate)))
end

Base.@propagate_inbounds function Base.deleteat!(a::Automaton, idx::Integer)
    @boundscheck checkbounds(states(a), idx)
    @inbounds state = states(a)[idx]
    for σ in outedges(state)
        isnoedge(σ) || deleteat!(inedges(σ), findfirst(isequal(state), inedges(σ)))
    end
    for σ in inedges(state)
        updateoutedges!(σ, noedge(a), findfirst(isequal(state), outedges(σ)))
    end
    @inbounds deleteat!(states(a), idx)
end

"""
    walk(a::Automaton{T, N, W}, sig::W, first::Integer) where {T, N, W}
Travels through index automaton according to the path given by the signature
starting from the state at position `first`. Returns a tuple (idx, state) where
idx is the last index of the letter from signature used to travel through automaton
and state is the resulting state. Note that `idx` ≂̸ `length(sig)` that there is no
path corresponding to the full signature.
"""
function walk(a::Automaton{T, N, W}, sig::W, first::Integer) where {T, N, W}
    σ = states(a)[first]
    i = 0
    for (idx, k) in enumerate(sig)
        next = outedges(σ)[k]
        isnoedge(next) ? break : (i, σ) = (idx, next)
    end
    return (i, σ)
end

walk(a::Automaton{T, N, W}, w::W) where {T, N, W} = walk(a, w, 1)


function Base.show(io::IO, a::Automaton)
    println(io, "Automaton with $(length(states(a))) states")
    abt = a.abt
    for (i, state) in enumerate(states(a))
        println(io, " $i. Edges leaving state (", constructword(name(state), abt), "):")

        for (i, tostate) in enumerate(outedges(state))
            !isnoedge(tostate) && println(io, "   ", " - with label ", abt[i], " to state (", constructword(name(tostate), abt), ")")
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
            if !isnoedge(outedges(σ)[letter])
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
        isnoedge(state) && addedge!(a, state, 1, 1)
    end
    i = 1
    indcs = findall(isequal(i), Σᵢ)
    while !isempty(indcs)
        for idx in indcs
            σ = states(a)[idx]
            τ = walk(a, name(σ)[2:end])[2]
            for (letter, state) in enumerate(outedges(σ))
                isnoedge(state) && addedge!(a, letter, σ, outedges(τ)[letter])
            end
        end
        i += 1
        indcs = findall(isequal(i), Σᵢ)
    end
    return a
end


"""
    index_rewrite(u::W, a::Automaton{T, N, W}) where {T, N, W}
Rewrites a word using a given index automaton.
"""
function index_rewrite(u::W, a::Automaton{T, N, W}) where {T, N, W}
    v = one(u)
    w = copy(u)
    states = Vector{State{T, N, W}}(undef, length(w))
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
