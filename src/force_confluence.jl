##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    forceconfluence!(rws::RewritingSystem, ri, rj,
    [, o::Ordering=ordering(rws)])
Produce (potentially critical) pairs from overlaps of left hand sides of rules
`ri` and `rj`. When failures of local confluence are found, new rules are added
to `rws`.

See [Sims, p. 69].
"""
function forceconfluence!(rws::RewritingSystem, ri, rj, o::Ordering = ordering(rws))
    lhs_i, rhs_i = ri
    lhs_j, rhs_j = rj
    for k in 1:length(lhs_i)
        b = @view lhs_i[end-k+1:end]
        n = longestcommonprefix(b, lhs_j)
        if isone(@view b[n+1:end]) || isone(@view lhs_j[n+1:end])
            a = lhs_i[1:end-k]
            append!(a, rhs_j)
            append!(a, @view b[n+1:end])

            c = rhs_i * @view lhs_j[n+1:end]

            deriverule!(rws, a, c, o)
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
    rws::RewritingSystem,
    stack,
    at::Automaton,
    ri,
    rj,
    work::kbWork = kbWork{eltype(W)}(),
    o::Ordering = ordering(rws),
)
    lhs_i, rhs_i = ri
    lhs_j, rhs_j = rj

    m = min(length(lhs_i), length(lhs_j)) - 1

    for k in 1:m
        if issuffix(@view(lhs_j[1:k]), lhs_i)
            a = store!(work.tmpPair._vWord, @view lhs_i[1:end-k])
            a = append!(a, rhs_j)

            c = store!(work.tmpPair._wWord, rhs_i)
            c = append!(c, @view lhs_j[k+1:end])

            critical, (a, c) = _iscritical(a, c, at, work)
            if critical
                push!(stack, (a, c))
            end
        end
    end
    deriverule!(rws, stack, work, at, o)
end
