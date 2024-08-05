"""
    KBSPrefix
Use `PrefixAutomaton` so that we don't need to maintain the reducedness of the
rewriting system all the time. We use on the other hand the non-deterministic
prefix automaton for (slower) rewrites.
"""
struct KBPrefix <: CompletionAlgorithm end

__rawrules(pfxA::PrefixAutomaton) = pfxA.rwrules

function reduce!(
    ::KBPrefix,
    rws::RewritingSystem,
    stack,
    i::Integer,
    j::Integer,
    _work::Workspace,
)
    pfxA = PrefixAutomaton(rws) # pfxA shares rules with rws
    work = Workspace(pfxA, _work.settings)
    pfxA, changed = merge!(pfxA, stack, work)

    if changed
        if work.settings.verbosity == 2
            @info "before reduction" (i, j) length(__rawrules(pfxA))
        end
        reduce!(pfxA, work)
        i, j = remove_inactive!(rws, i, j)
        if work.settings.verbosity == 2
            @info "after reduction" (i, j) length(__rawrules(pfxA))
        end
    end

    rws.reduced = true
    return rws, (i, j)
end

function Base.merge!(pfxA::PrefixAutomaton, stack, work::Workspace)
    W = word_type(pfxA)
    any_critical = false
    for (u, v) in stack
        critical, (lhs, rhs) = _iscritical(work, pfxA, (u,), (v,))
        if critical
            any_critical = true
            # a, b = simplify!(a, b, ord, balance = false)
            new_rule = Rule{W}(lhs => rhs)
            # @info "pushing" (u, v) (a, b) new_rule
            push!(pfxA, new_rule)
            @assert last(__rawrules(pfxA)) == new_rule __rawrules(pfxA)
        end
    end
    # pfxA.reduced &= !any_critical
    empty!(stack)
    return pfxA, any_critical
end

function reduce!(pfxA::PrefixAutomaton, work::Workspace)
    changed, deactivated = true, true
    itr = 0
    new_rules = Vector{Tuple{Int,eltype(pfxA.rwrules)}}()

    while changed || deactivated
        changed, deactivated = reduce_once!(pfxA, work, new_rules)
        itr += 1
        # @info "reducing: $itr:" (
        #     changed,
        #     deactivated,
        #     count(isactive, pfxA.rwrules),
        # )
    end

    if work.settings.verbosity == 2
        @info "pfxA is reduced after $itr passes"
    end

    @assert !any(reduce_once!(pfxA, work))
    # pfxA.reduced = true
    return pfxA
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
        # @info "reduced:" idx, (lhs, rhs) (lhs_r, rhs_r)
        @assert lhs ≠ lhs_r || rhs ≠ rhs_r

        if critical
            # @info "reducing rule:" idx, (lhs, rhs) (lhs_irr, rhs_irr) (
            #     lhs_r,
            #     rhs_r,
            # )
            some_changed = true
            rule = Rule{W}(lhs_r => rhs_r)
            push!(new_rules, (idx, rule))
        else
            some_deactivated = true
            deactivate!(rule)
        end
    end
    if some_changed || some_deactivated
        rls = __rawrules(pfxA)
        # @info length(new_rules), length(rls) length(new_rules) / length(rls)
        for (idx, rule) in new_rules
            rls[idx] = rule
        end
        __rebuild!(pfxA)
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

function __rebuild!(pfxA::PrefixAutomaton)
    empty!(pfxA)
    for (n, r) in pairs(__rawrules(pfxA))
        isactive(r) || continue
        Automata.add_direct_path!(pfxA, r.lhs, -n)
    end
    return pfxA
end
