using SparseArrays

struct PrefixAutomaton{O<:RewritingOrdering,V} <: Automaton{Int32}
    ordering::O
    transitions::Vector{SparseVector{Int32,UInt32}}
    __storage::BitSet
    rwrules::V
    # 1 is the initial state
    # 0 is the fail state
    # negative values in transitions indicate indices to values stored in rwrules

    function PrefixAutomaton(
        ordering::RewritingOrdering,
        rules::V,
    ) where {V<:AbstractVector}
        transitions = Vector{SparseVector{Int32,UInt32}}(undef, 0)
        __storage = BitSet()
        pfxA = new{typeof(ordering),V}(ordering, transitions, __storage, rules)
        _ = addstate!(pfxA)
        for (i, rule) in pairs(rules)
            add_direct_path!(pfxA, rule.lhs, -i)
        end
        return pfxA
    end
end

initial(::PrefixAutomaton) = one(Int32)
isfail(::PrefixAutomaton, σ::Integer) = iszero(σ)
isaccepting(pfx::PrefixAutomaton, σ::Integer) = 1 ≤ σ ≤ length(pfx.transitions)

hasedge(pfxA::PrefixAutomaton, σ::Integer, lab) = pfxA.transitions[σ][lab] ≠ 0

function addedge!(
    pfxA::PrefixAutomaton,
    src::Integer,
    dst::Integer,
    label,
)
    pfxA.transitions[src][label] = dst
    return pfxA
end

function trace(label::Integer, pfxA::PrefixAutomaton, σ::Integer)
    return pfxA.transitions[σ][label]
end

function Base.isempty(pfxA::PrefixAutomaton)
    return all(iszero, pfxA.transitions[initial(pfxA)])
end

function Base.empty!(pfxA::PrefixAutomaton)
    union!(pfxA.__storage, 2:length(pfxA.transitions))
    pfxA.transitions[1] .= 0
    return pfxA
end

# construction/modification

function addstate!(pfxA::PrefixAutomaton)
    if !isempty(pfxA.__storage)
        st = popfirst!(pfxA.__storage)
        pfxA.transitions[st] .= 0
        # dropzeros!(pfxA.transitions[st])
        return st
    else
        l = length(alphabet(ordering(pfxA)))
        vec = SparseVector(l, UInt32[], Int32[])
        push!(pfxA.transitions, vec)
        return length(pfxA.transitions)
    end
end

function add_direct_path!(
    pfxA::PrefixAutomaton,
    lhs::AbstractWord,
    val::Integer,
)
    @assert val ≤ 0
    σ = initial(pfxA)
    for (i, letter) in pairs(lhs)
        τ = trace(letter, pfxA, σ)
        # @info "idx = $i" letter τ
        if i == lastindex(lhs)
            addedge!(pfxA, σ, val, letter)
            return true, pfxA
        elseif isfail(pfxA, τ)
            τ = addstate!(pfxA)
            addedge!(pfxA, σ, τ, letter)
        end
        σ = τ
        if !isaccepting(pfxA, σ)
            @debug "prefix of length $i of $lhs is aready a lhs of a rule" σ

            # this may happen if the rule.lhs we push into pfxA
            # has a prefix that is reducible; then we return false,
            # and we don't enlarge pfxA
            return false, pfxA
        end
    end
    @error "unintended exit"
    return false, pfxA
end

function remove_direct_path!(pfxA::PrefixAutomaton, lhs::AbstractWord)
    σ = initial(pfxA)
    on_leaf = false
    leaf_start = (σ, 0)

    for (i, letter) in enumerate(lhs)
        # analyze edge with (src=σ, label=letter, dst=τ)
        τ = trace(letter, pfxA, σ)
        isfail(pfxA, τ) && return pfxA
        if !isaccepting(pfxA, τ)
            if i == length(lhs)
                break # we reached the leaf corresponding to lhs
            end
            # reached a leaf node before lhs is completed
            # i.e. lhs does not define a leaf, so there's nothing to remove
            return pfxA
        end
        if degree(pfxA, τ) > 1
            on_leaf = false
        elseif !on_leaf
            on_leaf = true
            leaf_start = (σ, i)
        end
        σ = τ
    end

    σ, i = leaf_start
    for letter in @view lhs[i+1:end-1]
        # we're on the "long-leaf" part
        τ = trace(letter, pfxA, σ)
        # by the early exit above we know there's something to remove
        @assert isaccepting(pfxA, τ)
        pfxA.transitions[σ][letter] = 0
        push!(pfxA.__storage, τ)
        σ = τ
    end

    return pfxA
end

function Base.show(io::IO, ::MIME"text/plain", pfxA::PrefixAutomaton)
    ord = ordering(pfxA)
    A = alphabet(ord)
    println(
        io,
        "prefix automaton over $(typeof(ord)) with $(length(A)) letters",
    )
    accept_states = length(pfxA.transitions) - length(pfxA.__storage)
    nrules = mapreduce(+, pairs(pfxA.transitions)) do (i, t)
        return i in pfxA.__storage ? 0 : sum(<(0), t)
    end
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

function KnuthBendix.word_type(::Type{<:PrefixAutomaton{O,V}}) where {O,V}
    return KnuthBendix.word_type(eltype(V))
end

function PrefixAutomaton(rws::AbstractRewritingSystem)
    return PrefixAutomaton(ordering(rws), KnuthBendix.__rawrules(rws))
end
