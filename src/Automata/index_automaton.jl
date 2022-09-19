## particular implementation of Index Automaton

mutable struct IndexAutomaton{S} <: Automaton{S}
    initial::S
    fail::S
    states::Vector{Vector{S}}
end

initial(idxA::IndexAutomaton) = idxA.initial

hasedge(::IndexAutomaton, ::State, ::Integer) = true

addedge!(idxA::IndexAutomaton, src::State, dst::State, label) = src[label] = dst

isfail(idxA::IndexAutomaton, σ::State) = σ === idxA.fail
isterminal(idxA::IndexAutomaton, σ::State) = isdefined(σ, :value)

Base.isempty(idxA::Automaton) = degree(initial(idxA)) == 0

function KnuthBendix.word_type(::IndexAutomaton{<:State{S,D,V}}) where {S,D,V}
    return eltype(V)
end

trace(label::Integer, idxA::IndexAutomaton, σ::State) = σ[label]

function IndexAutomaton(rws::RewritingSystem{W}) where {W}
    id = @view one(W)[1:0]
    S = State{typeof(id),UInt32,eltype(rules(rws))}
    fail = S(Vector{S}(undef, length(alphabet(rws))), id, 0)
    α = State(fail, id, 0)

    idxA = IndexAutomaton(α, fail, Vector{typeof(α)}[])
    idxA = self_complete!(idxA, fail, override = true)
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
    lhs, _ = rule
    σ = initial(idxA)
    σ.data += 1
    for (radius, letter) in enumerate(lhs)
        if isfail(idxA, σ[letter])
            τ = State(idxA.fail, @view(lhs[1:radius]), 0)
            addstate!(idxA, τ)
            addedge!(idxA, σ, τ, letter)
        end
        # @assert id(σ[letter]) == @view lhs[1:radius]

        σ = σ[letter]
        @assert !isfail(idxA, σ)
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

function self_complete!(idxA::IndexAutomaton, σ::State; override = false)
    for label in 1:max_degree(σ)
        if override || isfail(idxA, σ[label])
            addedge!(idxA, σ, σ, label)
        end
    end
    return idxA
end

function iscomplete(σ::State, idxA::IndexAutomaton)
    complete = true
    for label in 1:max_degree(σ)
        complete &= !isfail(idxA, σ[label])
    end
    return complete
end

function skew_edges!(idxA::IndexAutomaton)
    # add missing loops at the root (start of the induction)
    α = initial(idxA)
    if !iscomplete(α, idxA)
        self_complete!(idxA, σ, override = false)
    end

    # this has to be done in breadth-first fashion
    # to ensure that trace(U, idxA) is successful
    for states in idxA.states
        for σ in states # states of particular radius
            if isterminal(idxA, σ)
                self_complete!(idxA, σ, override = true)
                continue
            end

            iscomplete(σ, idxA) && continue
            # so that we don't trace unnecessarily

            τ = let U = @view id(σ)[2:end]
                l, τ = Automata.trace(U, idxA) # we're tracing a shorter word, so...
                @assert l == length(U) # the whole U defines a path in A and
                # by the induction step edges from τ lead to non-fail states
                isterminal(idxA, τ) &&
                    @warn "rws doesn't seem to be reduced!"
                # @assert iscomplete(τ, idxA)
                τ
            end

            for label in 1:max_degree(σ)
                if isfail(idxA, σ[label])
                    addedge!(idxA, σ, τ[label], label)
                end
            end
        end
    end
    return idxA
end