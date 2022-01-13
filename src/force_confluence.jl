##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    forceconfluence!(rws::RewritingSystem, r₁, r₂[, o::Ordering=ordering(rws)])
Examine overlaps of left hand sides of rules `r₁` and `r₂` to find (potential)
failures to local confluence. New rules are added to assure local confluence if
necessary.

Suppose that `r₁ = (lhs₁ → rhs₂)` and `r₂ = (lhs₂ → rhs₂)`. This function
tries to write `lhs₁ = a·b` and `lhs₂ = b·c` so that word `a·b·c` can be
rewritten in two potentially different ways:

>            a·b·c
>            /   \\
>           /     \\
>     rhs₁·c    a·rhs₂

thus a (potentially) critical pair `(rhs₁·c, a·rhs₂)` needs to be resolved in
the rewriting system.

It is not assumed that `rws` is reduced, and therefore also the case when
`lhs₁ = a·lhs₂·c` with non-trivial `c` is examined.

See procedure `OVERLAP_1` in [Sims, p. 69].
"""
function forceconfluence!(
    rws::RewritingSystem,
    r₁,
    r₂,
    o::Ordering = ordering(rws),
)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    for b in suffixes(lhs₁)
        k = length(b)
        n = longestcommonprefix(b, lhs₂)
        if length(b) == n
            # b is a prefix of lhs₂, i.e. lhs₁ = a*b, lhs₂ = b*c
            # so a*b*c rewrites as Q₁ = rhs₁*c or Q₂ = a*rhs₂
            Q₁ = let c = @view lhs₂[n+1:end]
                rhs₁*c
            end
            Q₂ = let a = @view lhs₁[1:end-k]
                a*rhs₂
            end
            deriverule!(rws, Q₁, Q₂, o)
        elseif length(lhs₂) == n # lhs_₂ is a subword of b (and hence of lhs₁):
            # c = b[n+1:end]; lhs₁ = a*lhs₂*c
            # so lsh₁ rewrites as Q₁ = rhs₁ or Q₂ = a*rhs₂*c
            Q₁ = rhs₁
            @views Q₂ = let a = lhs₁[1:end-k], c = b[n+1:end]
                append!(a*rhs₂, c) # saves one allocation compared to a*rhs₂*c
            end

            deriverule!(rws, Q₁, Q₂, o)
        end
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

# As of now: default implementation

"""
    forceconfluence!(rws::RewritingSystem, stack, work:kbWork,
        ri, rj[, o::Ordering=ordering(rs)])
Produce (potentially critical) pairs from overlaps of left hand sides of rules
`ri` and `rj`. When failures of local confluence are found, new rules are added
to `rws`.

This version uses `stack` and `work::kbWork` to save allocations and speed-up
the process. See [Sims, p. 77].
"""
function forceconfluence!(
    rws::RewritingSystem{W},
    stack,
    ri,
    rj,
    work::kbWork = kbWork{eltype(W)}(),
    o::Ordering = ordering(rs),
) where {W}
    lhs_i, rhs_i = ri
    lhs_j, rhs_j = rj
    m = min(length(lhs_i), length(lhs_j)) - 1

    for k in 1:m
        if issuffix(@view(lhs_j[1:k]), lhs_i)
            a = store!(work.tmpPair._vWord, @view lhs_i[1:end-k])
            a = append!(a, rhs_j)

            c = store!(work.tmpPair._wWord, rhs_i)
            c = append!(c, @view lhs_j[k+1:end])

            critical, (a, c) = _iscritical(a, c, rws, work)
            if critical
                push!(stack, (a, c))
            end
        end
    end
    deriverule!(rws, stack, work, o)
end

########################################
# KBS using index automata for rewriting
########################################

"""
    forceconfluence!(rws::RewritingSystem, stack, work::kbWork, at::Automaton,
        ri, rj[, o::Ordering=ordering(rws)])
Produce (potentially critical) pairs from overlaps of left hand sides of rules
`ri` and `rj`. When failures of local confluence are found, new rules are added
to `rws`.

This version uses `stack`, `work::kbWork` to save allocations and `at::Automaton`
to speed-up the rewriting process. See [Sims, p. 77].
"""
function forceconfluence!(
    rws::RewritingSystem{W},
    stack,
    at::Automaton,
    ri,
    rj,
    work::kbWork = kbWork{eltype(W)}(),
    o::Ordering = ordering(rws),
) where {W}
    lhs_i, rhs_i = ri
    lhs_j, rhs_j = rj

    m = min(length(lhs_i), length(lhs_j)) - 1

    for b in suffixes(lhs_i, 1:m)
        if isprefix(b, lhs_j)
            lb = length(b)
            a_rhs_j = let a = store!(work.tmpPair._vWord, @view lhs_i[1:end-lb])
                append!(a, rhs_j)
            end
            rhs_i_c = let c = store!(work.tmpPair._wWord, rhs_i)
                append!(c, @view lhs_j[lb+1:end])
            end
            critical, (a, c) = _iscritical(a_rhs_j, rhs_i_c, at, work)
            critical && push!(stack, (W(a), W(c)))
        end
    end
    return deriverule!(rws, stack, work, at, o)
end
