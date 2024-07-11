using SparseArrays

struct PrefixAutomaton <: Automaton{Int32}
    alphabet_len::Int
    transitions::Vector{SparseVector{Int32,UInt32}}
    __storage::BitSet
    # 1 is the initial state
    # 0 is the fail state
    # negative values in transitions indicate pointers to
    # (externally stored) values
    function PrefixAutomaton(alphabet_len::Integer)
        transitions = Vector{SparseVector{Int32,UInt32}}(undef, 0)
        __storage = BitSet()
        at = new(alphabet_len, transitions, __storage)
        _ = addstate!(at)
        return at
    end
end

initial(::PrefixAutomaton) = one(Int32)

Base.@propagate_inbounds function hasedge(
    pfxA::PrefixAutomaton,
    σ::Integer,
    label,
)
    return pfxA.transitions[σ][label] ≠ 0
end

Base.@propagate_inbounds function addedge!(
    pfxA::PrefixAutomaton,
    src::Integer,
    dst::Integer,
    label,
)
    pfxA.transitions[src][label] = dst
    return pfxA
end

isfail(::PrefixAutomaton, σ::Integer) = iszero(σ)
isterminal(::PrefixAutomaton, σ::Integer) = σ < 0
Base.@propagate_inbounds function trace(
    label::Integer,
    pfxA::PrefixAutomaton,
    σ::Integer,
)
    return pfxA.transitions[σ][label]
end

degree(pfxA::PrefixAutomaton, σ::Int32) = nnz(pfxA.transitions[σ])

function addstate!(pfxA::PrefixAutomaton)
    if !isempty(pfxA.__storage)
        st = popfirst!(pfxA.__storage)
        pfxA.transitions[st] .= 0
        dropzeros!(pfxA.transitions[st])
        return st
    else
        vec = SparseVector{Int32,UInt32}(pfxA.alphabet_len, UInt32[], Int32[])
        push!(pfxA.transitions, vec)
        return length(pfxA.transitions)
    end
end

function add_direct_path!(pfxA::PrefixAutomaton, rule, val::Integer)
    @assert val ≤ 0
    lhs, _ = rule
    σ = initial(pfxA)
    for (i, letter) in pairs(lhs)
        τ = trace(letter, pfxA, σ)
        # @info "idx = $i" letter τ
        if i == lastindex(lhs)
            # if !isfail(pfxA, τ)
            #     @warn "replacing value $lhs => $σ with" val
            # end
            addedge!(pfxA, σ, val, letter)
            return true, pfxA
        elseif isfail(pfxA, τ)
            τ = addstate!(pfxA)
            addedge!(pfxA, σ, τ, letter)
        end
        σ = τ
        if isterminal(pfxA, σ)
            @warn "prefix of length $i of $lhs is aready terminal:" σ

            # this may happen if the rule.lhs we push into pfxA
            # has a prefix that is already in the language of pfxA
            # then we return false, and we don't enlarge pfxA
            return false, pfxA
        end
    end
    @error "unintended exit"
    return false, pfxA
end

function remove_direct_path!(pfxA::PrefixAutomaton, rule)
    lhs, _ = rule
    σ = initial(pfxA)
    just_before_leaf = σ
    on_leaf = false
    k = 0

    for (i, letter) in enumerate(lhs)
        τ = trace(letter, pfxA, σ)
        isfail(pfxA, τ) && return pfxA
        isterminal(pfxA, τ) && i ≠ length(lhs) && return pfxA
        isterminal(pfxA, τ) && break
        if degree(pfxA, τ) == 1 && !on_leaf
            just_before_leaf = σ
            on_leaf = true
            k = i
        end
        if on_leaf && degree(pfxA, τ) > 1
            on_leaf = false
        end
        σ = τ
    end

    σ = just_before_leaf
    for letter in @view lhs[k:end-1]
        # we're on the "long-leaf" part
        τ = trace(letter, pfxA, σ)
        pfxA.transitions[σ][letter] = 0
        dropzeros!(pfxA.transitions[σ])
        push!(pfxA.__storage, τ)
        σ = τ
    end

    return pfxA
end

function Base.empty!(pfxA::PrefixAutomaton)
    union!(pfxA.__storage, 2:length(pfxA.transitions))
    pfxA.transitions[1] .= 0
    dropzeros!(pfxA.transitions[1])
    return pfxA
end

function Base.isempty(pfxA::PrefixAutomaton)
    return length(pfxA.transitions) - length(pfxA.__storage) == 1
end
