"""
    find_critical_pairs!(pfxA::PrefixAutomaton, r₁::Rule, r₂::Rule[, work=Workspace(rws))
Find critical pairs derived from suffix-prefix overlaps of lhses of `r₁` and `r₂`.

It is not assumed that `pfxA` is reduced, hence such critical pairs (i.e. failures to
local confluence) arise as `W = ABC` where the left hand sides of the rules are
either
* `AB` and `BC` (we assume that `A`, `B`, `C` are non-empty), or
* `ABC` and `B` (either `A` or `C` are non-empty).

See [Sims, Proposition 3.1, p. 58].
"""
function find_critical_pairs!(
    pfxA::PrefixAutomaton,
    r₁::Rule,
    r₂::Rule,
    work::Workspace = Workspace(pfxA),
)
    W = word_type(pfxA)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    m = min(length(lhs₁), length(lhs₂))
    if m > work.settings.max_length_overlap
        m = work.settings.max_length_overlap
        _add_dropped!(work)
    end
    new_rules = 0
    for B in suffixes(lhs₁, 1:m)
        l = Words.longestcommonprefix(B, lhs₂)
        critical, (P, Q) = if l == length(B) # suffix of lhs₁ is a prefix of lhs₂
            A = @view lhs₁[1:end-length(B)] # lhs₁ = A·B
            C = @view lhs₂[length(B)+1:end] # lhs₂ = B·C
            # rhs₁·C ← A·B·C → A·rhs₂
            _iscritical(work, pfxA, (A, rhs₂), (rhs₁, C))
        elseif l == length(lhs₂) # lhs₂ is a prefix of a suffix of lhs₁
            # i.e. lhs₂ is a subword of lhs₁
            A = @view lhs₁[1:end-length(B)]
            D = @view lhs₁[length(A)+length(lhs₂)+1:end]
            @assert lhs₁ == A * lhs₂ * D
            # lhs₁ = A·lhs₂·D
            _iscritical(work, pfxA, (A, rhs₂, D), rhs₁)
        else
            continue # to the next suffix
        end
        if critical
            admissible = isadmissible(P, Q, work.settings)
            if admissible
                # memory of P and Q is owned by work struct;
                # pushing to stack involves converting and we take ownership
                critical && push!(pfxA, Rule{W}(P => Q))
                new_rules += 1
            else
                _add_dropped!(work, (P, Q))
            end
        end
    end
    return new_rules
end

function knuthbendix!(
    settings::Settings{KBPrefix},
    rws::RewritingSystem{W},
) where {W}
    pfxA = PrefixAutomaton(rws)
    work = Workspace(pfxA, settings)

    rws, pfxA, work = knuthbendix!(rws, pfxA, work)
    if work.dropped_rules > 0
        __kb__readd_defining_rules!(rws, settings)
    end
    return rws
end

function knuthbendix!(
    rws::AbstractRewritingSystem,
    pfxA::PrefixAutomaton,
    work::Workspace{KBPrefix},
)
    rwrules = __rawrules(pfxA)
    settings = work.settings

    nnew_rules = 0
    i = firstindex(rwrules)
    while i ≤ lastindex(rwrules)
        if time_to_check_confluence(rws, work)
            success, i = __kb__check_confluence(rws, pfxA, i, work)
            success && return rws, pfxA, work
            nnew_rules = 0
        end

        ri = rwrules[i]
        j = firstindex(rwrules)
        while j ≤ i
            rj = rwrules[j]
            before = nnew_rules
            nnew_rules += find_critical_pairs!(pfxA, ri, rj, work)
            if ri !== rj
                nnew_rules += find_critical_pairs!(pfxA, rj, ri, work)
            end

            after_rwrules = length(rwrules)
            before_rwrules = length(rwrules) - nnew_rules + before

            for r in rws.rules_alphabet
                for k in (before_rwrules+1):after_rwrules
                    new_rule = rwrules[k]
                    nnew_rules += find_critical_pairs!(pfxA, r, new_rule, work)
                    nnew_rules += find_critical_pairs!(pfxA, new_rule, r, work)
                end
            end

            if time_to_rebuild(settings, rws, nnew_rules)
                if settings.verbosity == 2
                    @info "rebuilding at i = $i with $nnew_rules new rules"
                end
                # stop reducing if fewer than 10% of active rules are altered
                reduced, (i, j) = reduce!(pfxA, work, i, j, reduce_passes = 0.1)
                rws.reduced = reduced
                nnew_rules = 0
            end

            if are_we_stopping(settings, rws)
                reduced = reduce!(pfxA, work)
                rws.reduced = reduced
                return rws, pfxA, work
            end

            work.confluence_timer =
                before == nnew_rules ? work.confluence_timer + 1 : 0

            if settings.verbosity == 1 && i ≠ lastindex(rwrules)
                total = length(rwrules)
                settings.update_progress(total, i, nnew_rules)
            end

            j += 1
        end
        i += 1
    end
    reduced = reduce!(pfxA, work)
    rws.reduced = reduced
    return rws, pfxA, work
end

function __kb__check_confluence(
    rws::AbstractRewritingSystem,
    pfxA::PrefixAutomaton,
    i::Integer,
    work::Workspace,
)
    if work.settings.verbosity == 2
        @info "no new rules found for $(work.settings.confluence_delay) itrs, attempting a confluence check at" i,
        pfxA.rwrules[i]
    end
    reduced, (i, _) = reduce!(pfxA, work, i, 0)
    rws.reduced = reduced
    idxA = IndexAutomaton(rws)
    # @info "no new rules found for $(settings.confluence_delay) itrs, attempting a confluence check" i
    W = word_type(rws)
    stack = Vector{Tuple{W,W}}()
    stack, i_after = check_confluence!(stack, rws, idxA)
    success = if isempty(stack)
        work.settings.verbosity == 2 &&
            @info "confluence check succeeded, found confluent rws!"
        true
    else
        if work.settings.verbosity == 2
            l = length(stack)
            @info "confluence check failed: found $(l) new rule$(l==1 ? "" : "s") at i = $i_after"
        end

        merge!(pfxA, stack, work)
        false
    end

    return success, max(i, i_after)
end

function time_to_rebuild(
    settings::Settings,
    ::AbstractRewritingSystem,
    nnew_rules::Integer,
)
    return nnew_rules > settings.reduce_delay
end
