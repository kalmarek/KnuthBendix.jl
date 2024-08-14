"""
    KBPrefix
Use `PrefixAutomaton` so that we don't need to maintain the reducedness of the
rewriting system all the time. We use on the other hand the non-deterministic
prefix automaton for (slower) rewrites.
"""
struct KBPrefix <: CompletionAlgorithm end

function Settings(m::KBPrefix; kwargs...)
    return __Settings(
        m;
        max_rules = 65536,
        reduce_delay = 500,
        confluence_delay = 500,
        kwargs...,
    )
end

__rawrules(pfxA::PrefixAutomaton) = pfxA.rwrules

function reduce!(
    ::KBPrefix,
    rws::RewritingSystem,
    settings = Settings(KBPrefix()),
)
    pfxA = PrefixAutomaton(rws)
    reduced = reduce!(rws, pfxA, Workspace(pfxA, settings))
    return rws
end

function reduce!(
    rws::AbstractRewritingSystem,
    pfxA::PrefixAutomaton,
    work::Workspace,
)
    reduced, _ = reduce!(pfxA, work, 0, 0)
    rws.reduced = reduced
    return isreduced(rws)
end

function reduce!(pfxA::PrefixAutomaton, work::Workspace{KBPrefix}; kwargs...)
    reduced, _ = reduce!(pfxA, work, 0, 0; kwargs...)
    return reduced
end

# this one is used for reduction in KBIndex and after checking confluence
function reduce!(
    pfxA::PrefixAutomaton,
    work::Workspace{KBPrefix},
    stack,
    i::Integer = 0,
    j::Integer = 0,
)
    pfxA, changed = merge!(pfxA, stack, work)
    if changed
        reduced, (i, j) = reduce!(pfxA, work, i, j)
        return reduced, (i, j)
    end
    return true, (i, j)
end

function reduce!(
    pfxA::PrefixAutomaton,
    work::Workspace{KBPrefix},
    i::Integer,
    j::Integer;
    reduce_passes = typemax(Int),
)
    rwrules = __rawrules(pfxA)
    work.settings.verbosity == 2 &&
        @info "before reduction" (i, j) length(rwrules)

    reduced = _reduce!(pfxA, work; reduce_passes = reduce_passes)
    _, (i, j) = remove_inactive!(pfxA, i, j)

    work.settings.verbosity == 2 &&
        @info "after reduction" (i, j) length(rwrules)

    return reduced, (i, j)
end

function remove_inactive!(pfxA::PrefixAutomaton, i::Integer, j::Integer)
    _, (i, j) = remove_inactive!(__rawrules(pfxA), i, j)
    Automata.rebuild!(pfxA)
    return pfxA, (i, j)
end

function Base.merge!(pfxA::PrefixAutomaton, stack, work::Workspace{KBPrefix})
    W = word_type(pfxA)
    any_critical = false
    for (u, v) in stack
        critical, (lhs, rhs) = _iscritical(work, pfxA, (u,), (v,))
        admissible = isadmissible(lhs, rhs, work.settings)
        if critical && admissible
            any_critical = true
            new_rule = Rule{W}(lhs => rhs)
            push!(pfxA, new_rule)
            @assert last(__rawrules(pfxA)) == new_rule __rawrules(pfxA)
        elseif !admissible
            _add_dropped!(work, (lhs, rhs))
        end
    end
    empty!(stack)
    return pfxA, any_critical
end

function _reduce!(
    pfxA::PrefixAutomaton,
    work::Workspace{KBPrefix};
    reduce_passes = typemax(Int),
)
    itr = 1
    reduced = false
    changed_rules = Vector{Tuple{Int,eltype(pfxA.rwrules)}}()

    while !reduced
        status = reduce_once!(pfxA, work, changed_rules)
        reduced = status.changed == 0 && status.deactivated == 0
        itr > reduce_passes && break
        itr += 1
    end
    if work.settings.verbosity == 2
        @info "pfxA is $(reduced ? "" : "NOT") reduced after $itr passes"
    end
    return reduced
end

function reduce_once!(
    pfxA::PrefixAutomaton,
    work::Workspace,
    changed_rules = Vector{Tuple{Int,eltype(pfxA.rwrules)}}(),
)
    nchanged = 0
    ndeactivated = 0
    W = word_type(pfxA)
    resize!(changed_rules, 0)

    for (idx, rule) in pairs(__rawrules(pfxA))
        isactive(rule) || continue
        lhs, rhs = rule

        h1 = work.rewrite1.history
        h2 = work.rewrite2.history

        lhs_red = isreducible(lhs, pfxA; skipping = idx, history = h1)
        rhs_red = isreducible(rhs, pfxA; skipping = nothing, history = h2)

        !lhs_red && !rhs_red && continue

        critical, (lhs_r, rhs_r) =
            _iscritical(work, pfxA, (lhs,), (rhs,); skipping = idx)

        @assert lhs ≠ lhs_r || rhs ≠ rhs_r

        admissible = isadmissible(lhs_r, rhs_r, work.settings)
        if critical
            # @info "reducing rule:" idx, (lhs, rhs) (lhs_irr, rhs_irr) (
            #     lhs_r,
            #     rhs_r,
            # )
            if admissible
                nchanged += 1
                rule = Rule{W}(lhs_r => rhs_r)
                push!(changed_rules, (idx, rule))
            else
                # We cannot retain the original rule as that would prohibit
                # reducedness. Instead we need to drop it here.
                ndeactivated += 1
                deactivate!(rule)
                _add_dropped!(work, (lhs_r, rhs_r))
            end
        else
            ndeactivated += 1
            deactivate!(rule)
        end
    end
    if nchanged > 0 || ndeactivated > 0
        rls = __rawrules(pfxA)
        for (idx, rule) in changed_rules
            rls[idx] = rule
        end
        Automata.rebuild!(pfxA)
    end

    return (changed = nchanged, deactivated = ndeactivated)
end

function isreducible(
    w::AbstractWord,
    pfxA::PrefixAutomaton;
    skipping = nothing,
    history::PackedVector = PackedVector{UInt32}(),
)
    resize!(history, 0)
    __unsafe_push!(history, Automata.initial(pfxA))
    __unsafe_finalize!(history)
    for letter in w
        # @info "letter = $letter" last(history)
        for σ in last(history)
            Automata.hasedge(pfxA, σ, letter) || continue
            τ = Automata.trace(letter, pfxA, σ)
            # @info σ, letter, τ
            if !Automata.isaccepting(pfxA, τ)
                -τ == skipping && continue
                return true
            end
            __unsafe_push!(history, τ)
        end
        __unsafe_push!(history, Automata.initial(pfxA))
        __unsafe_finalize!(history)
    end
    return false
end

function Automata.rebuild!(pfxA::PrefixAutomaton)
    empty!(pfxA)
    for (n, r) in pairs(__rawrules(pfxA))
        isactive(r) || continue
        Automata.add_direct_path!(pfxA, r.lhs, -n)
    end
    return pfxA
end
