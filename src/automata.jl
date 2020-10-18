###########################################
# States

"""
    AbstractState{N, W}
Abstract type representing state of the (index) automaton.

The subtypes of `AbstractState{N, W}` should implement the following methods which
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
abstract type AbstractState{N, W} end

"""
    State{N, W<:AbstractWord} <: AbstractState{N, W}
State as a name (corresponding to the signature of the simple path ending at this
state), indication whether it is terminal (in which case there is a right-hand part
of the rewriting rule, vector of states (indexed by the position of the letter in
the alphabet) from which there is an edge (labelled by letter indexed) to this state
and vector of states (indexed by position of the letter in the alphabet) to which
there is an edge (labelled by letter indexed) from this state.
"""
mutable struct State{N, W<:AbstractWord} <: AbstractState{N, W}
    name::W
    terminal::Bool
    rrule::W
    ined::Vector{State{N, W}}
    outed::NTuple{N, State{N, W}}
    representsnoedge::Bool

    function State{N, W}() where {N, W<:AbstractWord}
        x = new()
        x.representsnoedge = true
        return x
    end

    function State(name::W, noedge::State{N, W}) where {N, W}
        s = State{N, W}()
        s.name = name
        s.terminal = false
        s.rrule = W()
        s.ined = typeof(s)[]
        s.outed = ntuple(i -> noedge, N)
        s.representsnoedge = false
        return s
    end
end

name(s::State) = s.name
isterminal(s::State) = s.terminal
rightrule(s::State) = s.rrule
inedges(s::State) = s.ined
outedges(s::State) = s.outed
isnoedge(s::State) = s.representsnoedge
Base.length(s::State) = length(name(s))

"""
    declarerightrule!(s::State, w::AbstractWord)
Decalres given word as a right-hand side rule of a given state (and makes this)
state terminal.
"""
function declarerightrule!(s::State, w::AbstractWord)
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
    AbstractAutomaton{N, W}
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
abstract type AbstractAutomaton{N, W} end

"""
    Automaton{N, W<:AbstractWord} <: AbstractAutomaton{N, W}
Automaton as a vector of states together with alphabet.
"""
struct Automaton{N, W<:AbstractWord} <: AbstractAutomaton{N, W}
    states::Vector{State{N, W}}
    abt::Alphabet
    uniquenoedge::State{N, W}
    stateslengths::Vector{Int}
    _past_states::Vector{State{N, W}}
end

# Default type is set to UInt16
function Automaton(abt::Alphabet, W::Type{<:AbstractWord}=Word{UInt16})
    S = State{length(abt), W}
    uniquenoedge = S()
    Automaton{length(abt), W}([State(W(), uniquenoedge)], abt, uniquenoedge, [0], S[])
end

alphabet(a::Automaton) = a.abt
states(a::Automaton) = a.states
initialstate(a::Automaton) = first(states(a))
noedge(a::Automaton) = a.uniquenoedge
stateslengths(a::Automaton) = a.stateslengths

function Base.isempty(a::Automaton)
    σ = initialstate(a)
    length(states(a)) == 1 && isone(name(σ)) && return true
    return false
end

Base.push!(a::Automaton{N, W}, name::W) where {N, W} = (push!(states(a), State(name, noedge(a))); push!(stateslengths(a), length(name)); a)
Base.empty!(a::Automaton{N, W}) where{N, W} = (empty!(states(a)); empty!(stateslengths(a)); push!(a, W()); a)

"""
    replace(k::NTuple{N, T}, val::T, idx::Integer) where {N, T}
Returns a copy of `NTuple` `k` with value at index `idx` changed to `val`.
"""
Base.@propagate_inbounds function replace(k::NTuple{N, T}, val::T, idx::Integer) where {N, T}
    @boundscheck 1 ≤ idx ≤ N || throw(BoundsError(k, idx))
    return @inbounds ntuple( i -> i==idx ? val : k[i], Val(N))
end

"""
    updateoutedges!(s::State, to::State, label::Integer)
Updates outedges of the state `s` with state `to` connected through the edge `label`.
"""
Base.@propagate_inbounds function updateoutedges!(s::State{N}, to::State{N}, label::Integer) where {N}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(s), label))
    @inbounds s.outed = replace(outedges(s), to, label)
end

"""
    addinedge!(s::State, from::State)
Adds an edge from state `from` to state `s` storing it in `inedges` of the state `s`.
"""
addinedge!(s::State, from::State) = push!(inedges(s), from)

"""
    addedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
Adds the edge with a given `label` directed `from` state `to` state.
"""
Base.@propagate_inbounds function addedge!(a::Automaton{N}, label::Integer, from::Integer, to::Integer) where {N}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(states(a)[from]), label))
    @boundscheck checkbounds(states(a), from)
    @boundscheck checkbounds(states(a), to)
    @inbounds fromstate = states(a)[from]
    @inbounds tostate = states(a)[to]
    @inbounds updateoutedges!(fromstate, tostate, label)
    addinedge!(tostate, fromstate)
end

Base.@propagate_inbounds function addedge!(a::Automaton{N}, label::Integer, from::State, to::State) where {N}
    @boundscheck 1 ≤ label ≤ N || throw(BoundsError(outedges(from), label))
    @assert from in states(a) "State from which the edge is added must be inside automaton"
    @assert to in states(a) "State to which the edge is added must be inside automaton"
    @inbounds updateoutedges!(from, to, label)
    addinedge!(to, from)
end
# Should we also check if the edge corresponding to a given letter does not exist?

"""
    removeedge!(a::Automaton, label::Integer, from::Integer, to::Integer)
Removes the edge with a given `label` `from` one state `to` another.
"""
Base.@propagate_inbounds function removeedge!(a::Automaton{N}, label::Integer, from::Integer, to::Integer) where {N}
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
    @boundscheck checkbounds(stateslengths(a), idx)
    @inbounds state = states(a)[idx]
    for σ in outedges(state)
        isnoedge(σ) || deleteat!(inedges(σ), findfirst(isequal(state), inedges(σ)))
    end
    for σ in inedges(state)
        updateoutedges!(σ, noedge(a), findfirst(isequal(state), outedges(σ)))
    end
    @inbounds deleteat!(states(a), idx)
    @inbounds deleteat!(stateslengths(a), idx)
end

"""
    walk(a::AbstractAutomaton, sig::AbstractWord[, state=first(states(a))])
Walk through index automaton according to the path given by the signature `sig`,
starting from `state`. Returns a tuple `(idx, state)` where `idx` is the last
index of the letter from signature used to walk through automaton and `state` is
the resulting state.

Note that if `idx ≠ length(sig)` there is no path corresponding to the full signature.
"""
function walk(a::AbstractAutomaton, sig::AbstractWord, state=first(states(a)))
    idx = 0
    for (i, k) in enumerate(sig)
        next = outedges(state)[k]
        isnoedge(next) ? break : (idx, state) = (i, next)
    end
    return (idx, state)
end

function Base.show(io::IO, a::AbstractAutomaton)
    println(io, "Automaton with $(length(states(a))) states")
    for (i, state) in enumerate(states(a))
        println(io, " $i. Edges leaving state (", string_repr(name(state), alphabet(a)), "):")

        for (i, tostate) in enumerate(outedges(state))
            !isnoedge(tostate) && println(io,
                "   ", " - with label ", alphabet(a)[i], " to state (", string_repr(name(tostate), alphabet(a)), ")")
        end
    end
end

###########################################
# Ad index automata

"""
    makeindexautomaton!(a::Automaton, rws::RewritingSystem, abt::Alphabet)
Takes a given empty automaton (i.e. containing only initial state corresponding
to empty word) and transforms it into index automaton corresponding to a given
rewriting system.
"""
function makeindexautomaton!(a::Automaton, rws::RewritingSystem, abt::Alphabet=alphabet(ordering(rws)))
    # a = Automaton(abt)
    # Determining simple paths
    for (idx, (lhs, rhs)) in enumerate(rules(rws))
        isactive(rws, idx) || continue
        σ = initialstate(a)
        for (i, letter) in enumerate(lhs)
            if !isnoedge(outedges(σ)[letter])
                σ = outedges(σ)[letter]
            else
                push!(a, lhs[1:i])
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
    for (i, state) in enumerate(outedges(initialstate(a)))
        isnoedge(state) && addedge!(a, i, 1, 1)
    end
    i = 1
    indcs = findall(isequal(i), stateslengths(a))
    while !isempty(indcs)
        for idx in indcs
            σ = states(a)[idx]
            τ = walk(a, name(σ)[2:end])[2]
            for (letter, state) in enumerate(outedges(σ))
                isnoedge(state) && addedge!(a, letter, σ, outedges(τ)[letter])
            end
        end
        i += 1
        indcs = findall(isequal(i), stateslengths(a))
    end
    return a
end

"""
    makeindexautomaton(a::Automaton, rws::RewritingSystem, abt::Alphabet)
Creates index automaton corresponding to a given rewriting system.
"""
function makeindexautomaton(rws::RewritingSystem, abt::Alphabet=alphabet(ordering(rws)))
    a = Automaton(abt)
    return makeindexautomaton!(a, rws, abt)
end

"""
    updateautomaton!(a::Automaton, rws::RewritingSystem)
Updates given automaton so it corresponds to a given rewriting system.
"""
function updateautomaton!(a::Automaton, rws::RewritingSystem)
    empty!(a)
    makeindexautomaton!(a, rws)
end

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, a::Automaton)
Rewrites word `w` from left using index automaton `a` and appends the result
to `v`. For standard rewriting `v` should be empty.
"""
function rewrite_from_left!(v::AbstractWord, w::AbstractWord, a::Automaton)
    past_states = a._past_states
    resize!(past_states, length(w) + 1)
    state = initialstate(a)
    past_states[1] = state

    while !isone(w)
        x = popfirst!(w)
        k = length(v) + 1
        state = outedges(past_states[k])[x]

        if !isterminal(state)
            @inbounds past_states[k+1] = state
            push!(v, x)
        else
            lhs, rhs = name(state), rightrule(state)
            w = prepend!(w, rhs)
            resize!(v, length(v) - length(lhs) + 1)
        end
    end
    return v
end
