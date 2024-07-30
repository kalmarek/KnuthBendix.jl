using SparseArrays

struct PrefixAutomaton{V} <: Automaton{Int32}
    alphabet_len::Int
    transitions::Vector{SparseVector{Int32,UInt32}}
    __storage::BitSet
    rwrules::V
    # 1 is the initial state
    # 0 is the fail state
    # negative values in transitions indicate pointers to
    # (externally stored) values
    function PrefixAutomaton(
        alphabet_len::Integer,
        rules::V,
    ) where {V<:AbstractVector}
        transitions = Vector{SparseVector{Int32,UInt32}}(undef, 0)
        __storage = BitSet()
        pfxA = new{V}(alphabet_len, transitions, __storage, rules)
        _ = addstate!(pfxA)
        for (i, rule) in pairs(rules)
            add_direct_path!(pfxA, rule.lhs, -i)
        end
        return pfxA
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
isaccepting(pfx::PrefixAutomaton, σ::Integer) = 1 ≤ σ ≤ length(pfx.transitions)

@inline function trace(label::Integer, pfxA::PrefixAutomaton, σ::Integer)
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

function Base.empty!(pfxA::PrefixAutomaton)
    union!(pfxA.__storage, 2:length(pfxA.transitions))
    pfxA.transitions[1] .= 0
    return pfxA
end

function Base.isempty(pfxA::PrefixAutomaton)
    return length(pfxA.transitions) - length(pfxA.__storage) == 1
end

function PrefixAutomaton(rws::AbstractRewritingSystem)
    l = length(alphabet(rws))
    return PrefixAutomaton(l, deepcopy(KnuthBendix.__rawrules(rws)))
end

function Base.show(io::IO, ::MIME"text/plain", pfxA::PrefixAutomaton)
    println(
        io,
        "prefix automaton over alphabet of $(pfxA.alphabet_len) letters:",
    )
    println(io, "  • $(length(pfxA.transitions)) accepting states")
    nrules = mapreduce(+, pairs(pfxA.transitions)) do (i, t)
        return i in pfxA.__storage ? 0 : sum(<(0), t)
    end
    return print(io, "  • $(nrules) non-accepting states (rw rules)")
end
