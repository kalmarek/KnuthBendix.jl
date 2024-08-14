mutable struct PrefixAutomaton{O<:RewritingOrdering,RV,T} <: Automaton{Int32}
    ordering::O
    transitions::T
    max_state::Int32
    rwrules::RV
    # reduced::Bool
    # 1 is the initial state
    # 0 is the fail state
    # negative values in transitions indicate indices to values stored in rwrules

    function PrefixAutomaton(
        ordering::RewritingOrdering,
        rwrules::RV,
    ) where {RV<:AbstractVector{<:KnuthBendix.Rule}}
        transitions = Vector{Vector{Int32}}(undef, 0)
        max_state = 0
        pfxA = new{typeof(ordering),RV,typeof(transitions)}(
            ordering,
            transitions,
            max_state,
            rwrules,
        )
        _ = addstate!(pfxA)
        for (i, rule) in pairs(rwrules)
            KnuthBendix.isactive(rule) || continue
            add_direct_path!(pfxA, rule.lhs, -i)
        end
        return pfxA
    end
end

initial(::PrefixAutomaton) = one(Int32)
fail(::PrefixAutomaton) = zero(Int32)
isfail(::PrefixAutomaton, σ::Integer) = iszero(σ)
isaccepting(pfx::PrefixAutomaton, σ::Integer) = 1 ≤ σ ≤ length(pfx.transitions)

function hasedge(pfxA::PrefixAutomaton, σ::Integer, lab)
    return if isaccepting(pfxA, σ)
        @inbounds pfxA.transitions[σ][lab] ≠ 0
    else
        false
    end
end

function addedge!(
    pfxA::PrefixAutomaton,
    src::Integer,
    dst::Integer,
    label,
)
    pfxA.transitions[src][label] = dst
    return pfxA
end

function trace(
    label::Integer,
    pfxA::PrefixAutomaton,
    σ::Integer,
)
    return if isaccepting(pfxA, σ)
        @inbounds pfxA.transitions[σ][label]
    else
        fail(pfxA)
    end
end

function Base.isempty(pfxA::PrefixAutomaton)
    return all(iszero, pfxA.transitions[initial(pfxA)])
end

function Base.empty!(pfxA::PrefixAutomaton)
    pfxA.max_state = 1
    pfxA.transitions[1] .= fail(pfxA)
    return pfxA
end

# construction/modification

function addstate!(pfxA::PrefixAutomaton)
    pfxA.max_state += 1
    st = pfxA.max_state
    if pfxA.max_state ≤ length(pfxA.transitions)
        @inbounds pfxA.transitions[st] .= fail(pfxA)
    else
        l = length(alphabet(ordering(pfxA)))
        vec = fill(fail(pfxA), l)
        push!(pfxA.transitions, vec)
    end
    return st
end

function add_direct_path!(
    pfxA::PrefixAutomaton,
    lhs::AbstractWord,
    val::Integer,
)
    @assert val ≤ 0
    σ = initial(pfxA)
    for (i, letter) in pairs(lhs)
        if i == lastindex(lhs)
            addedge!(pfxA, σ, val, letter)
            return true, pfxA
        elseif hasedge(pfxA, σ, letter)
            τ = trace(letter, pfxA, σ)
            if !isaccepting(pfxA, τ)
                @debug "prefix of length $i of $lhs is aready a lhs:" __rawrules(
                    pfxA,
                )[-τ]
                # this may happen if the rule.lhs we push into pfxA
                # has a prefix that is reducible; then we return false,
                # and we don't enlarge pfxA
                return false, pfxA
            end
        else # !hasedge(pfx, σ, letter)
            τ = addstate!(pfxA)
            addedge!(pfxA, σ, τ, letter)
        end
        σ = τ
    end
    @error "unintended exit with" lhs
    return false, pfxA
end

function Base.show(io::IO, ::MIME"text/plain", pfxA::PrefixAutomaton)
    ord = ordering(pfxA)
    A = alphabet(ord)
    println(
        io,
        "prefix automaton over $(typeof(ord)) with $(length(A)) letters",
    )
    accept_states = pfxA.max_state
    nrules = sum(count(<(0), pfxA.transitions[st]) for st in 1:pfxA.max_state)
    println(io, "  • $(accept_states+nrules) states")
    return print(io, "  • $(nrules) non-accepting states (rw rules)")
end

function Base.push!(pfxA::PrefixAutomaton, rule::KnuthBendix.Rule)
    n = length(pfxA.rwrules) + 1
    added, pfxA = add_direct_path!(pfxA, rule.lhs, -n)
    if added
        push!(pfxA.rwrules, rule)
    end
    return pfxA
end

# for using IndexAutomaton as rewriting struct in KnuthBendix
KnuthBendix.ordering(pfxA::PrefixAutomaton) = pfxA.ordering

function KnuthBendix.word_type(::Type{<:PrefixAutomaton{O,RV}}) where {O,RV}
    return KnuthBendix.word_type(eltype(RV))
end

function PrefixAutomaton(rws::AbstractRewritingSystem)
    return PrefixAutomaton(ordering(rws), KnuthBendix.__rawrules(rws))
end
