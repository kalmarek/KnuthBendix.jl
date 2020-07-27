

abstract type AbstractState{T} end

mutable struct State{T} <: AbstractState{T}
    name::Union{Word{T}, SubWord{T}}
    term::Bool
    rrule::Union{Word{T}, SubWord{T}, Nothing}
    ined::Vector{Union{State{T}, Nothing}}
    outed::Vector{Union{State{T}, Nothing}} # LinkedList?
end


State(name::Union{Word{T}, SubWord{T}}, absize::Int) where {T} = State(name, false, nothing, Vector{Union{State{T}, Nothing}}(nothing, absize), Vector{Union{State{T}, Nothing}}(nothing, absize))
State(name::Union{Word{T}, SubWord{T}}, rrule::Union{Word{T}, SubWord{T}, Nothing}) where T = State(name, true, rrule, State{T}[], State{T}[])
State(name::Union{Word{T}, SubWord{T}}) where T = State(name, false, nothing, State{T}[], State{T}[])

inedges(s::State) = s.ined
outedges(s::State) = s.outed
isterminal(s::State) = s.term
rightrule(s::State) = s.rrule
name(s::State) = s.name
Base.length(s::State) = length(name(s))


abstract type AbstractAutomaton end

mutable struct Automaton{T} <: AbstractAutomaton
    states::Vector{State{T}} # Linked List?  # first element is initial state
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

function Base.push!(a::Automaton{T}, name::Union{Word{T}, SubWord{T}}) where {T}
    push!(states(a), State(name, length(a.abt)))
end

function addedge!(a::Automaton, letter::Int, from::Int, to::Int)
    @assert 0 < letter <= length(a.abt) "Edge must be a valid pointer to the letter"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[letter] = states(a)[to]
    inedges(states(a)[to])[letter] = states(a)[from]
end
# Should we also check if the edge corresponding to a given letter does not exist?

function removeedge!(a::Automaton, letter::Int, from::Int, to::Int)
    @assert 0 < letter <= length(a.abt) "Edge must be a valid pointer to the letter"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[letter] = undef
    inedges(states(a)[to])[letter] = undef
end


function Base.deleteat!(a::Automaton, idx::Int)
    for (i, state) in enumerate(outedges(states(a)[idx]))
        inedges(state)[i] = undef
    end
    for (i, state) in enumerate(inedges(states(a)[idx]))
        outedges(state)[i] = undef
    end
    deleteat!(states, idx)
end



function walk(a::Automaton{T}, w::Union{Word{T}, SubWord{T}}, first::Int) where {T}
    current = states(a)[first]
    for i in w
        next = outedges(current)[i]
        next === nothing ? error("No path corresponding to a given word exists") :  current = next
    end
    return current
end

walk(a::Automaton{T}, w::Union{Word{T}, SubWord{T}}) where{T} = walk(a, w, 1)

# Additional walk declarations?


function Base.show(io::IO, a::Automaton)
    println(io, "Automaton with $(length(states(a))) states")
    abt = a.abt
    for (i, state) in enumerate(states(a))
        println(io, " $i. Edges leaving state (", constructword(name(state), abt), "):")

        for (i, tostate) in enumerate(outedges(state))
            !isnothing(tostate) && println(io, "   ", " - with label ", abt[i], " to state (", constructword(name(tostate), abt), ")")
        end
    end
end

function constructword(w::AbstractWord, abt::Alphabet)
    if isone(w)
        word = "ε"
    else
        word = ""
        for letter in w
            word *= abt[letter]
        end
    end
    return word
end

# Move that
Base.length(abt::Alphabet) = length(abt.alphabet)


# Move to rewriting

function index_rewrite(u::AbstractWord{T}, a::Automaton{T}, rws::RewritingSystem) where {T}
    v = one(u)
    w = copy(u)
    states = Vector{State{T}}(undef, length(w))
    state = states(a)[1]

    while !isone(w)
        x = popfirst!(w)
        k = length(v) + 1
        state = outedges(state)[x]

        if !isterminal(state)
            @inbounds states[k] = state
            push!(v, x)
        else
            v = c[begin:length(state)-1]
            w = prepend!(w, rightrule(state))
        end
    end
end

