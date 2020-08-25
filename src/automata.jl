abstract type AbstractState{T} end

mutable struct State{T} <: AbstractState{T}
    name::AbstractWord{T}
    terminal::Bool
    rrule::Union{AbstractWord{T}, Nothing}
    ined::Vector{Union{State{T}, Nothing}}
    outed::Vector{Union{State{T}, Nothing}} # LinkedList?
end


State(name::AbstractWord{T}, absize::Int) where {T} = State(name, false, nothing, Vector{Union{State{T}, Nothing}}(nothing, absize), Vector{Union{State{T}, Nothing}}(nothing, absize))
State(name::AbstractWord{T}, rrule::Union{AbstractWord{T}, Nothing}) where T = State(name, true, rrule, State{T}[], State{T}[])
State(name::AbstractWord{T}) where T = State(name, false, nothing, State{T}[], State{T}[])

inedges(s::State) = s.ined
outedges(s::State) = s.outed
isterminal(s::State) = s.terminal
rightrule(s::State) = s.rrule
name(s::State) = s.name
Base.length(s::State) = length(name(s))

function declarerightrule!(s::State, rrule::AbstractWord)
    rightrule(s) = rrule
    isterminal(s) = true
end

function Base.show(io::IO, s::State)
    if isterminal(s)
        println(io, "Terminal state $(name(s))")
        println(io, "Right rule: $(rightrule(s))")
        println(io, " Edges entering:")
        for (i, e) in enumerate(inedges(s))
            !isnothing(e) && println(io, "   ", " - with label $(i) from state $(name(e))")
        end
    else
        println(io, "State $(name(s))")
        println(io, " Edges entering:")
        for (i, fromst) in enumerate(inedges(s))
            !isnothing(fromst) && println(io, "   ", " - with label $(i) from state $(name(fromst))")
        end
        println(io, " Edges leaving:")
        for (i, tost) in enumerate(outedges(s))
            !isnothing(tost) && println(io, "   ", " - with label $(i) from state $(name(tost))")
        end
    end
end




abstract type AbstractAutomaton end

mutable struct Automaton{T} <: AbstractAutomaton
    states::Vector{State{T}} # Linked List?  # first element is initial state
    nameidx::Vector{<:AbstractWord{T}} # To facilitate the fast search over names
    abt::Alphabet
end

# setting the default type to UInt16
Automaton(states::Vector{Union{State{T}, AbstractState{T}}}, idx::Vector{AbstractWord{T}}, abt::Alphabet) where {T<:Integer} = Automaton{UInt16}(states, idx, abt)

Automaton(abt::Alphabet) = Automaton([State(Word(Int[]), length(abt))], [Word(Int[])], abt)

states(a::Automaton) = a.states
names(a::Automaton) = a.nameidx
initialstate(a::Automaton) = states(a)[1]

function Base.push!(a::Automaton{T}, s::State{T}) where {T}
    @assert (length(s.ined) == length(a)) && (length(s.outed) == length(a)) "Tables of in and out edges must have the same length as alphabet"
    push!(a.states, s); push!(names(a), name(s))
end

function Base.push!(a::Automaton{T}, name::AbstractWord{T}) where {T}
    push!(states(a), State(name, length(a.abt))); push!(names(a), name)
end

function addedge!(a::Automaton, letter::Integer, from::Integer, to::Integer)
    @assert 0 < letter <= length(a.abt) "Edge must be a valid pointer to the letter"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[letter] = states(a)[to]
    inedges(states(a)[to])[letter] = states(a)[from]
end

function addedge!(a::Automaton{T}, letter::Integer, from::State{T}, to::State{T}) where {T}
    @assert from in states(a) "State from which the edge is added must be inside automaton"
    @assert to in states(a) "State to which the edge is added must be inside automaton"
    outedges(from)[letter] = to
    inedges(to)[letter] = from
end
# Should we also check if the edge corresponding to a given letter does not exist?

# Should we assume that we are adding simple paths?
# function addpath!(a::Automaton{T}, w::AbstractWord{T}) where {T}
#     σ = states(a)[1]
#     for (i, letter) in enumerate(w)
#         if σ[letter] === nothing  # this is wrong condition
#             push!(a, @view(w[1:i]))
#             addedge!(a, letter, σ, states(a)[end])
#         else σ = σ[letter]
#         end
#     end
# end

function removeedge!(a::Automaton, letter::Int, from::Int, to::Int)
    @assert 0 < letter <= length(a.abt) "Edge must be a valid pointer to the letter"
    @assert 0 < from <= length(states(a)) "Edges can be added only between states inside automaton"
    @assert 0 < to <= length(states(a)) "Edges can be added only between states inside automaton"
    outedges(states(a)[from])[letter] = undef
    inedges(states(a)[to])[letter] = undef
end


function Base.deleteat!(a::Automaton, idx::Int)
    for (i, σ) in enumerate(outedges(states(a)[idx]))
        inedges(σ)[i] = undef
    end
    for (i, σ) in enumerate(inedges(states(a)[idx]))
        outedges(σ)[i] = undef
    end
    deleteat!(states, idx)
end



function walk(a::Automaton{T}, w::Union{Word{T}, SubWord{T}}, first::Int) where {T}
    σ = states(a)[first]
    for i in w
        next = outedges(σ)[i]
        next === nothing ? error("No path corresponding to a given word exists") :  σ = next
    end
    return σ
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

function makeindexautomaton(rws::RewritingSystem, abt::Alphabet)
    Σᵢ = Int[0]
    a = Automaton(abt)
    # Determining simple paths
    for (lhs, rhs) in rules(rws)
        σ = states(a)[1]
        for (i, letter) in enumerate(lhs)
            if !isnothing(outedges(σ)[letter])
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
    for letter in outedges(states(a)[1])
        isnothing(letter) && addedge!(a, letter, 1, 1)
    end
    i = 1
    indcs = findall(isequal(i), Σᵢ)
    while !isempty(indcs)
        for idx in indcs
            σ = states(a)[idx]
            τ = walk(a, name(σ)[2:end])
            for (i, letter) in enumerate(outedges(σ))
                isnothing(letter) && addedge!(a, i, σ, τ)
            end
        end
        i += 1
        indcs = findall(isequal(i), Σᵢ)
    end
    return a
end



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
    return v
end

