## Crude, i.e., KBS1 implementation

@inline function _iscritical(u::AbstractWord, v::AbstractWord, rewriting)
    a = rewrite(u, rewriting)
    b = rewrite(v, rewriting)
    return a ≠ b, (a, b)
end

"""
    deriverule!(rws::RewritingSystem, u::Word, v::Word[, o::Ordering=ordering(rws)])
Given a critical pair `(u, v)` with respect to `rws` adds a rule to `rws`
(if necessary) that solves the pair, i.e. makes `rws` locally confluent with
respect to `(u,v)`. See [Sims, p. 69].
"""
function deriverule!(
    rws::RewritingSystem{W},
    u::AbstractWord,
    v::AbstractWord,
    o::Ordering = ordering(rws),
) where {W}
    critical, (a, b) = _iscritical(u, v, rws)
    if critical
        simplify!(a, b, o)
        push!(rws, Rule{W}(a, b, o))
    end
    return rws
end

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
        n = Words.longestcommonprefix(b, lhs₂)
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

"""
    knuthbendix1(rws::RewritingSystem; max_rules=100)
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].
"""
function knuthbendix1(rws::RewritingSystem; max_rules = 100)
    return knuthbendix1!(deepcopy(rws), Settings(; max_rules = max_rules))
end

function knuthbendix1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs)
    end

    prog = Progress(
        count(isactive, ss.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = settings.verbosity > 0,
    )

    for r₁ in rules(ss)
        are_we_stopping(ss, settings) && break
        for r₂ in rules(ss)
            forceconfluence!(ss, r₁, r₂)
            r₁ === r₂ && break
            forceconfluence!(ss, r₂, r₁)
        end
        prog.n = count(isactive, rws.rwrules)
        next!(
            prog,
            showvalues = [(
                Symbol("processing rules (done/total)"),
                "$(prog.counter)/$(prog.n)",
            )],
        )
    end

    finish!(prog)

    p = irreduciblesubsystem(ss)
    rws = empty!(rws)

    for lside in p
        push!(rws, (lside, rewrite(lside, ss)))
    end
    return rws
end
