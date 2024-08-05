"""
    KBPrefix
Use `PrefixAutomaton` so that we don't need to maintain the reducedness of the
rewriting system all the time. We use on the other hand the non-deterministic
prefix automaton for (slower) rewrites.
"""
struct KBPrefix <: CompletionAlgorithm end

__rawrules(pfxA::PrefixAutomaton) = pfxA.rwrules

function reduce!(::KBPrefix, rws::AbstractRewritingSystem, work::Workspace)
    if !isreduced(rws)
        pfxA = PrefixAutomaton(rws)
        pfxA_work = Workspace(pfxA, work.settings)
        reduce!(rws, pfxA, pfxA_work)
        merge!(work, pfxA_work)
    end
    return rws
end

function reduce!(
    ::KBPrefix,
    rws::AbstractRewritingSystem,
    stack,
    i::Integer,
    j::Integer,
    work::Workspace,
)
    pfxA = PrefixAutomaton(rws) # pfxA shares rules with rws
    pfxA_work = Workspace(pfxA, work.settings)
    # shortest rules at the top of the stack
    sort!(stack, by = length ∘ first, rev = true)
    pfxA, changed = merge!(pfxA, stack, pfxA_work)
    if changed || !isreduced(rws)
        rws, (i, j) = reduce!(rws, pfxA, i, j, pfxA_work)
    end
    merge!(work, pfxA_work)
    return rws, (i, j)
end

function reduce!(
    rws::AbstractRewritingSystem,
    pfxA::PrefixAutomaton,
    i::Integer,
    j::Integer,
    work::Workspace;
    reduce_passes = typemax(Int),
)
    rwrules = __rawrules(pfxA)
    work.settings.verbosity == 2 &&
        @info "before reduction" (i, j) length(rwrules)

    reduced = reduce!(pfxA, work; reduce_passes = reduce_passes)
    i, j = remove_inactive!(rws, i, j)
    __rebuild!(pfxA)

    work.settings.verbosity == 2 &&
        @info "after reduction" (i, j) length(rwrules)

    rws.reduced = reduced
    return rws, (i, j)
end

function reduce!(
    rws::AbstractRewritingSystem,
    pfxA::PrefixAutomaton,
    work::Workspace,
)
    rws, _ = reduce!(rws, pfxA, 1, 1, work)
    return rws
end

function remove_inactive!(pfxA::PrefixAutomaton, i::Integer, j::Integer)
    _, (i, j) = remove_inactive!(__rawrules(pfxA), i, j)
    Automata.rebuild!(pfxA)
    return pfxA, (i, j)
end

function Base.merge!(pfxA::PrefixAutomaton, stack, work::Workspace)
    W = word_type(pfxA)
    any_critical = false
    for (u, v) in stack
        critical, (lhs, rhs) = _iscritical(work, pfxA, (u,), (v,))
        admissible = isadmissible(lhs, rhs, work.settings)
        if critical && admissible
            any_critical = true
            # a, b = simplify!(a, b, ord, balance = false)
            new_rule = Rule{W}(lhs => rhs)
            # @info "pushing" (u, v) (a, b) new_rule
            push!(pfxA, new_rule)
            @assert last(__rawrules(pfxA)) == new_rule __rawrules(pfxA)
        elseif !admissible
            work.dropped_rules += 1
            push!(work.dropped_stack, (lhs, rhs))
        end
    end
    # pfxA.reduced &= !any_critical
    empty!(stack)
    return pfxA, any_critical
end

function reduce!(
    pfxA::PrefixAutomaton,
    work::Workspace;
    reduce_passes::Integer = typemax(Int),
)
    changed, deactivated = true, true
    itr = 0
    new_rules = Vector{Tuple{Int,eltype(pfxA.rwrules)}}()

    while changed || deactivated
        changed, deactivated = reduce_once!(pfxA, work, new_rules)
        itr += 1
        itr == reduce_passes && break
        # @info "reducing: $itr:" (
        #     changed,
        #     deactivated,
        #     count(isactive, pfxA.rwrules),
        # )
    end

    if work.settings.verbosity == 2
        if !(changed || deactivated)
            @info "pfxA is reduced after $itr passes"
        else
            @info "pfxA is NOT reduced after $reduce_passes passes"
        end
    end
    return !(changed || deactivated)
end

function reduce_once!(
    pfxA::PrefixAutomaton,
    work::Workspace,
    new_rules = Vector{Tuple{Int,eltype(pfxA.rwrules)}}(),
)
    some_changed = false
    some_deactivated = false
    W = word_type(pfxA)
    resize!(new_rules, 0)

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
                work.dropped_rules += 1
                push!(work.dropped_stack, (lhs_r, rhs_r))
            end
        else
            some_deactivated = true
            deactivate!(rule)
        end
    end
    if some_changed || some_deactivated
        rls = __rawrules(pfxA)
        for (idx, rule) in changed_rules
            rls[idx] = rule
        end
        Automata.rebuild!(pfxA)
    end

    return some_changed, some_deactivated
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
