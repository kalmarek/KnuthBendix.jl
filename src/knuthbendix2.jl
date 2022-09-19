## Naive, i.e. KBS2 implementation

@inline function _iscritical(
    u::AbstractWord,
    v::AbstractWord,
    rewriting,
    work::Workspace,
)
    a = rewrite!(work.iscritical_1p, u, rewriting)
    b = rewrite!(work.iscritical_2p, v, rewriting)
    return a ≠ b, (a, b)
end

"""
    find_critical_pairs!(stack, rewriting, r₁::Rule, r₂::Rule, work::Workspace)
Push to `stack` all critical pairs that
Empty `stack` of (potentially) critical pairs by deriving and adding new rules
to `rs` resolving the pairs, i.e. maintains local confluence of `rs`.

This function may deactivate rules in `rs` if they are deemed redundant (e.g.
follow from the added new rules). See [Sims, p. 76].
"""
function find_critical_pairs!(
    stack,
    rewriting,
    r₁::Rule,
    r₂::Rule,
    work::Workspace,
)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    m = min(length(lhs₁), length(lhs₂)) - 1
    W = word_type(rewriting)

    # TODO: cache suffix automaton for lhs₁ to run this in O(m) (obecnie: O(m²))
    for b in suffixes(lhs₁, 1:m)
        if isprefix(b, lhs₂)
            lb = length(b)
            @views rhs₁_c, a_rhs₂ = Words.store!(
                work.find_critical_p,
                lhs₁[1:end-lb],
                rhs₂,
                rhs₁,
                lhs₂[lb+1:end],
            )
            critical, (a, c) = _iscritical(a_rhs₂, rhs₁_c, rewriting, work)
            # memory of a and c is owned by work.find_critical_p
            # so we need to call constructors
            critical && push!(stack, (W(a, false), W(c, false)))
        end
    end
    return stack
end

"""
    deriverule!(rs::RewritingSystem, stack, work::kbWork
        [, o::Ordering=ordering(rs), deleteinactive::Bool = false])
Empty `stack` of (potentially) critical pairs by deriving and adding new rules
to `rs` resolving the pairs, i.e. maintains local confluence of `rs`.

This function may deactivate rules in `rs` if they are deemed redundant (e.g.
follow from the added new rules). See [Sims, p. 76].
"""
function deriverule!(
    rws::RewritingSystem{W},
    stack,
    work::Workspace,
    o::Ordering = ordering(rws),
) where {W}
    while !isempty(stack)
        u, v = pop!(stack)
        critical, (a, b) = _iscritical(u, v, rws, work)
        if critical
            simplify!(a, b, o)
            new_rule = Rule{W}(W(a, false), W(b, false), o)
            push!(rws, new_rule)
            deactivate_rules!(rws, stack, work, new_rule)
        end
    end
end

function deactivate_rules!(
    rws::RewritingSystem,
    stack,
    work::Workspace,
    new_rule::Rule,
)
    for rule in rules(rws)
        rule == new_rule && continue
        (lhs, rhs) = rule
        if occursin(new_rule.lhs, lhs)
            deactivate!(rule)
            push!(stack, (first(rule), last(rule)))
        elseif occursin(new_rule.lhs, rhs)
            new_rhs = rewrite!(work.iscritical_1p, rhs, rws)
            update_rhs!(rule, new_rhs)
        end
    end
end

"""
    forceconfluence!(rws::RewritingSystem, stack, r₁, r₂, work:kbWork
    [, o::Ordering=ordering(rs)])
Examine overlaps of left hand sides of rules `r₁` and `r₂` to find (potential)
failures to local confluence. New rules are added to assure local confluence if
necessary.

This version assumes the reducedness of `rws` so that failures to local confluence
are of the form `a·b·c` with all `a`, `b`, `c` non trivial and `lhs₁ = a·b` and
`lhs₂ = b·c`.

This version uses `stack` to maintain the reducedness of `rws` and
`work::kbWork` to save allocations and speed-up the process.

See procedure `OVERLAP_2` in [Sims, p. 77].
"""
function forceconfluence!(
    rws::RewritingSystem{W},
    stack,
    r₁,
    r₂,
    work::Workspace = Workspace{eltype(W)}(),
    o::Ordering = ordering(rws),
) where {W}
    stack = find_critical_pairs!(stack, rws, r₁, r₂, work)
    return deriverule!(rws, stack, work, o)
end

"""
    knuthbendix2(rws::RewritingSystem; max_rules::Integer=100)
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termination takes place after the number of rules stored within
the RewritingSystem reaches `max_rules`.
"""
function knuthbendix2(rws::RewritingSystem; max_rules = 100)
    return knuthbendix2!(deepcopy(rws), Settings(; max_rules = max_rules))
end

function knuthbendix2!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    work = Workspace(rws)
    stack = Vector{Tuple{W,W}}()

    for (i, r₁) in enumerate(rules(rws))
        are_we_stopping(rws, settings) && break
        for r₂ in rules(rws)
            isactive(r₁) || break
            forceconfluence!(rws, stack, r₁, r₂, work)

            r₁ === r₂ && break
            isactive(r₁) || break
            isactive(r₂) || break
            forceconfluence!(rws, stack, r₂, r₁, work)
        end
        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            settings.update_progress!(i, n)
        end
    end
    remove_inactive!(rws)
    return rws
end
