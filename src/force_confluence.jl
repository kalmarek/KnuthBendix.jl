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
                rhs₁ * c
            end
            Q₂ = let a = @view lhs₁[1:end-k]
                a * rhs₂
            end
            deriverule!(rws, Q₁, Q₂, o)
        elseif length(lhs₂) == n # lhs_₂ is a subword of b (and hence of lhs₁):
            # c = b[n+1:end]; lhs₁ = a*lhs₂*c
            # so lsh₁ rewrites as Q₁ = rhs₁ or Q₂ = a*rhs₂*c
            Q₁ = rhs₁
            @views Q₂ = let a = lhs₁[1:end-k], c = b[n+1:end]
                append!(a * rhs₂, c) # saves one allocation compared to a*rhs₂*c
            end

            deriverule!(rws, Q₁, Q₂, o)
        end
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

@inline function _store!(
    work::kbWork,
    a::AbstractWord,
    rhs₂::AbstractWord,
    rhs₁::AbstractWord,
    c::AbstractWord,
)
    rhs₁_c = let Q = store!(work.tmpPair._wWord, rhs₁)
        append!(Q, c)
    end

    a_rhs₂ = let Q = store!(work.tmpPair._vWord, a)
        append!(Q, rhs₂)
    end

    return rhs₁_c, a_rhs₂
end

function find_critical_pairs!(
    stack,
    rewriting,
    r₁::Rule,
    r₂::Rule,
    work::kbWork,
)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    m = min(length(lhs₁), length(lhs₂)) - 1
    W = word_type(rewriting)

    for b in suffixes(lhs₁, 1:m)
        if isprefix(b, lhs₂)
            lb = length(b)
            @views rhs₁_c, a_rhs₂ =
                _store!(work, lhs₁[1:end-lb], rhs₂, rhs₁, lhs₂[lb+1:end])
            critical, (a, c) = _iscritical(a_rhs₂, rhs₁_c, rewriting, work)
            # a and c memory is owned by work!
            critical && push!(stack, (W(a), W(c)))
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
    work::kbWork = kbWork{eltype(W)}(),
    o::Ordering = ordering(rws),
) where {W}
    stack = find_critical_pairs!(stack, rws, r₁, r₂, work)
    return deriverule!(rws, stack, work, o)
end
