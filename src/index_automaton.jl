## particular implementation of Index Automaton

mutable struct IndexAutomaton{S} <: Automaton{S}
    initial::S
    states::Vector{Vector{S}}
end

initial(idxA::IndexAutomaton) = idxA.initial

hasedge(idxA::IndexAutomaton, σ::State, label::Integer) = hasedge(σ, label)
addedge!(idxA::IndexAutomaton, src::State, dst::State, label) = src[label] = dst

Base.isempty(idxA::Automaton) = degree(initial(idxA)) == 0

word_type(::IndexAutomaton{<:State{S,D,V}}) where {S,D,V} = eltype(V)

trace(label::Integer, idxA::IndexAutomaton, σ::State) = σ[label]

function IndexAutomaton(rws::RewritingSystem{W}) where {W}
    id = @view one(W)[1:0]
    α = State{typeof(id),UInt32,eltype(rules(rws))}(
        id,
        0,
        max_degree = length(alphabet(rws)),
    )

    idxA = IndexAutomaton(α, Vector{typeof(α)}[])
    idxA = direct_edges!(idxA, rules(rws))
    idxA = skew_edges!(idxA)

    return idxA
end

function direct_edges!(idxA::IndexAutomaton, rwrules)
    for rule in rwrules
        add_direct_path!(idxA, rule)
    end
    return idxA
end

function add_direct_path!(idxA::IndexAutomaton, rule)
    α = initial(idxA)
    S = typeof(α)
    lhs, _ = rule

    σ = α
    α.data += 1
    for (radius, letter) in enumerate(lhs)
        if !hasedge(idxA, σ, letter)
            τ = S(@view(lhs[1:radius]), 0, max_degree = max_degree(α))
            addstate!(idxA, τ)
            addedge!(idxA, σ, τ, letter)
        end
        # @assert id(σ[letter]) == @view lhs[1:radius]

        σ = σ[letter]
        σ.data += 1
    end
    setvalue!(σ, rule)
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
    σ.uptodate = true
    return push!(idxA.states[radius], σ)
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
            isterminal(σ) && continue

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

function rewrite!(
    v::AbstractWord,
    w::AbstractWord,
    idxA::IndexAutomaton{S};
    history_tape = S[],
) where {S}
    resize!(history_tape, 1)
    history_tape[1] = initial(idxA)

    resize!(v, 0)
    while !isone(w)
        x = popfirst!(w)
        σ = last(history_tape) # current state
        τ = σ[x] # next state
        @assert !isnothing(τ) "idxA doesn't seem to be complete!; $σ"

        if isterminal(τ)
            lhs, rhs = value(τ)
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
