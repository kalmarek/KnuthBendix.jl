## Crude, i.e., KBS1 implementation

struct KBS1AlgPlain <: CompletionAlgorithm end

@inline function _iscritical(u::AbstractWord, v::AbstractWord, rewriting)
    u == v && return false, (u, v)
    a = rewrite(u, rewriting)
    b = rewrite(v, rewriting)
    return a ≠ b, (a, b)
end

"""
    deriverule!(rws::RewritingSystem, u::AbstractWord, v::AbstractWord)
Given a critical pair `(u, v)` with respect to `rws` adds a rule to `rws`
(if necessary) that resolves the pair, i.e. makes `rws` locally confluent with
respect to `(u,v)`. See [^Sims1994], p. 69.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function deriverule!(
    rws::RewritingSystem{W},
    u::AbstractWord,
    v::AbstractWord,
    verbose::Bool = false,
) where {W}
    critical, (a, b) = _iscritical(u, v, rws)
    if critical
        if verbose
            @info "pair fails local confluence, rewrites to $a ≠ $b"
        end
        simplify!(a, b, ordering(rws))
        rule = Rule{W}(a, b, ordering(rws))
        if verbose
            rule_str = sprint(_print_rule, nrules(rws) + 1, rule, alphabet(rws))
            @info "adding rule [ $rule_str ] to rws"
        end
        push!(rws, rule)
    else
        if verbose
            @info "pair does not fail local confluence, both sides rewrite to $a"
        end
    end
    return rws
end

"""
    forceconfluence!(rws::RewritingSystem, r₁, r₂)
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

See procedure `OVERLAP_1` in [^Sims1994], p. 69.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function forceconfluence!(
    rws::RewritingSystem,
    r₁,
    r₂,
    verbose::Bool = false,
)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    for b in suffixes(lhs₁)
        k = length(b)
        n = Words.longestcommonprefix(b, lhs₂)
        if length(b) == n
            n == length(lhs₁) && r₁ == r₂ && continue
            # b is a prefix of lhs₂, i.e. lhs₁ = a*b, lhs₂ = b*c
            # so a*b*c rewrites as Q₁ = rhs₁*c or Q₂ = a*rhs₂
            Q₁ = let c = @view lhs₂[n+1:end]
                rhs₁ * c
            end
            Q₂ = let a = @view lhs₁[1:end-k]
                a * rhs₂
            end
            if verbose
                @info "lhs₁ suffix-prefix lhs₂:" rules = (r₁, r₂) (a, b, c) =
                    (lhs₁[1:end-k], b, lhs₂[n+1:end]) pair = (Q₁, Q₂)
            end
            deriverule!(rws, Q₁, Q₂, verbose)
        elseif length(lhs₂) == n # lhs₂ is a subword of b (and hence of lhs₁):
            # c = b[n+1:end]; lhs₁ = a*lhs₂*c
            # so lsh₁ rewrites as Q₁ = rhs₁ or Q₂ = a*rhs₂*c
            Q₁ = rhs₁
            @views Q₂ = let a = lhs₁[1:end-k], c = b[n+1:end]
                append!(a * rhs₂, c) # saves two allocations compared to a*rhs₂*c
            end
            if verbose
                @info "lhs₂ is a subword of lhs₁" rules = (r₁, r₂) (a, b, c) =
                    (lhs₁[1:end-k], lhs₂, b[n+1:end]) pair = (Q₁, Q₂)
            end
            deriverule!(rws, Q₁, Q₂, verbose)
        end
    end
    return rws
end

"""
    knuthbendix1(rws::RewritingSystem; max_rules=100, kwargs...)
Run the Knuth-Bendix procedure that (if successful) yields the reduced,
confluent rewriting system generated by rules of `rws`.

This is a simplistic implementation for educational purposes only. It follows
closely `KBS_1` procedure as described in **Section 2.5**[^Sims1994], p. 68.

!!! warning
    Forced termination takes place after the number of rules stored in the
    `RewritingSystem` exceeds `max_rules`.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
function knuthbendix1(rws::RewritingSystem; max_rules = 100, kwargs...)
    return knuthbendix!(
        KBS1AlgPlain(),
        deepcopy(rws),
        Settings(; max_rules = max_rules, kwargs...),
    )
end

function knuthbendix!(
    method::KBS1AlgPlain,
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}

    if settings.verbosity > 0
        @warn "knuthbendix1 is a simplistic implementation for educational purposes only."
    end

    show_info = settings.verbosity ≥ 2

    for (i, r₁) in enumerate(rules(rws))
        are_we_stopping(rws, settings) && break
        for (j, r₂) in enumerate(rules(rws))
            if show_info
                @info "consider $((i, j)) for critical pairs"
            end
            forceconfluence!(rws, r₁, r₂, show_info)
            r₁ === r₂ && break
            if show_info
                @info "consider $((j, i)) for critical pairs"
            end
            forceconfluence!(rws, r₂, r₁, show_info)
        end
        if settings.verbosity == 1
            total = nrules(rws)
            settings.update_progress(total, i)
        end
    end

    return reduce!(method, rws)
end

"""
    reduce!(::NaiveKBS1Alg, rws::RewritingSystem)
Bring `rws` to its reduced form using the naive algorithm.

The returned system consists of rules `p → rewrite(p, rws)` for `p` in
[`irreduciblesubsystem(rws)`](@ref).
"""
function reduce!(::KBS1AlgPlain, rws::RewritingSystem)
    P = irreduciblesubsystem(rws)
    rws_dc = deepcopy(rws) # a deepcopy
    rws = empty!(rws)
    for lside in P
        push!(rws, (lside, rewrite(lside, rws_dc)))
    end
    return rws
end