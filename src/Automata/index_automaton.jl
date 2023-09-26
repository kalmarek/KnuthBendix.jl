## particular implementation of Index Automaton

mutable struct IndexAutomaton{S,O<:RewritingOrdering} <: Automaton{S}
    ordering::O
    initial::S
    fail::S
    states::Vector{Vector{S}}
end

initial(idxA::IndexAutomaton) = idxA.initial
KnuthBendix.ordering(idxA::IndexAutomaton) = idxA.ordering

hasedge(::IndexAutomaton, ::State, ::Integer) = true

addedge!(idxA::IndexAutomaton, src::State, dst::State, label) = src[label] = dst

isfail(idxA::IndexAutomaton, σ::State) = σ === idxA.fail
isterminal(idxA::IndexAutomaton, σ::State) = isdefined(σ, :value)

signature(idxA::IndexAutomaton, σ::State) = id(σ)

Base.isempty(idxA::Automaton) = degree(initial(idxA)) == 0

function KnuthBendix.word_type(::IndexAutomaton{<:State{S,D,V}}) where {S,D,V}
    return eltype(V)
end

Base.Base.@propagate_inbounds function trace(
    label::Integer,
    ::IndexAutomaton,
    σ::State,
)
    return σ[label]
end

function IndexAutomaton(rws::RewritingSystem{W}) where {W}
    id = @view one(W)[1:0]
    S = State{typeof(id),UInt32,eltype(rules(rws))}
    ord = KnuthBendix.ordering(rws)
    A = alphabet(ord)
    fail = S(Vector{S}(undef, length(A)), id, 0)
    α = State(fail, id, 0)

    idxA = IndexAutomaton(ord, α, fail, Vector{typeof(α)}[])
    idxA = self_complete!(idxA, fail, override = true)
    idxA = direct_edges!(idxA, rules(rws))
    idxA = skew_edges!(idxA)

    return idxA
end

function direct_edges!(idxA::IndexAutomaton, rwrules)
    for (idx, rule) in enumerate(rwrules)
        add_direct_path!(idxA, rule, idx)
    end
    return idxA
end

function add_direct_path!(idxA::IndexAutomaton, rule, age)
    lhs, _ = rule
    σ = initial(idxA)
    for (radius, letter) in enumerate(lhs)
        if isfail(idxA, trace(letter, idxA, σ))
            τ = State(idxA.fail, @view(lhs[1:radius]), age)
            addstate!(idxA, τ)
            addedge!(idxA, σ, τ, letter)
        end

        σ = trace(letter, idxA, σ)
        @assert !isnothing(σ)
        @assert !isfail(idxA, σ)
        @assert signature(idxA, σ) == @view lhs[1:radius]
    end
    setvalue!(σ, rule)
    return idxA
end

function addstate!(idxA::IndexAutomaton, σ::State)
    radius = length(signature(idxA, σ))
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
        if override || isfail(idxA, trace(label, idxA, σ))
            addedge!(idxA, σ, σ, label)
        end
    end
    return idxA
end

function has_fail_edges(σ::State, idxA::IndexAutomaton)
    fail_edges = false
    for label in 1:max_degree(σ)
        fail_edges |= isfail(idxA, trace(label, idxA, σ))
    end
    return fail_edges
end

function skew_edges!(idxA::IndexAutomaton)
    # add missing loops at the root (start of the induction)
    α = initial(idxA)
    if has_fail_edges(α, idxA)
        self_complete!(idxA, α, override = false)
    end

    # this has to be done in breadth-first fashion
    # to ensure that trace(U, idxA) is successful
    for states in idxA.states
        for σ in states # states of particular radius
            if isterminal(idxA, σ)
                self_complete!(idxA, σ, override = true)
                continue
            end
            # now check if σ has any failed edges
            has_fail_edges(σ, idxA) || continue
            # so that we don't trace unnecessarily

            τ = let U = @view signature(idxA, σ)[2:end]
                l, τ = Automata.trace(U, idxA) # we're tracing a shorter word, so...
                @assert l == length(U) # the whole U defines a path in A and
                # by the induction step edges from τ lead to non-fail states
                isterminal(idxA, τ) &&
                    @warn "rws doesn't seem to be reduced!"
                # @assert iscomplete(τ, idxA)
                τ
            end

            for label in 1:max_degree(σ)
                if isfail(idxA, trace(label, idxA, σ))
                    addedge!(idxA, σ, τ[label], label)
                end
            end
        end
    end
    return idxA
end

function Base.show(io::IO, idxA::IndexAutomaton)
    terminal_count = [
        count(st -> Automata.isterminal(idxA, st), states) for
        states in idxA.states
    ]
    ord = KnuthBendix.ordering(idxA)
    A = alphabet(ord)
    println(io, "index automaton over $(typeof(ord)) with $(length(A)) letters")
    nstates = sum(length, idxA.states)
    println(io, "  • ", nstates, " state" * (nstates == 1 ? "" : "s"))
    print(io, "  • ", sum(terminal_count), " accepting states (rw rules)")
    return
end
