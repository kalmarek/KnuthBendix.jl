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
    forceconfluence!(rws::RewritingSystem, stack, r₁, r₂, work:kbWork
    [, o::Ordering=ordering(rs)])
Examine overlaps of left hand sides of rules `r₁` and `r₂` to find (potential)
failures to local confluence. New rules are added to assure local confluence if
necessary.

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
