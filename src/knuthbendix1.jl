"""
    KBPlain <: CompletionAlgorithm
Run the Knuth-Bendix procedure that (if successful) yields the reduced,
confluent rewriting system generated by rules of `rws`.

This is a simplistic algorithm for educational purposes only. It follows
closely `KBS_1` procedure as described in **Section 2.5**[^Sims1994], p. 68.

!!! warning
    Forced termination takes place after the number of rules stored in the
    `RewritingSystem` exceeds `max_rules`.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
struct KBPlain <: CompletionAlgorithm end

Settings(::KBPlain) = Settings(; max_rules = 100, verbosity = 2)

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
    rws::RewritingSystem,
    u::AbstractWord,
    v::AbstractWord;
    verbose::Bool = false,
)
    critical, (a, b) = _iscritical(u, v, rws)
    if critical
        if verbose
            @info "pair fails local confluence, rewrites to $a ≠ $b"
        end
        lhs, rhs = simplify!(a, b, ordering(rws), balance = true)
        rule = Rule{word_type(rws)}(lhs => rhs)
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
    r₁::Rule,
    r₂::Rule;
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
            deriverule!(rws, Q₁, Q₂, verbose = verbose)
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
            deriverule!(rws, Q₁, Q₂, verbose = verbose)
        end
    end
    return rws
end

function knuthbendix!(
    alg::KBPlain,
    rws::RewritingSystem,
    settings::Settings = Settings(; max_rules = 100, verbosity = 2),
)
    if settings.verbosity > 0
        @warn "KBPlain is a simplistic completion algorithm for educational purposes only."
    end

    very_verbose = settings.verbosity ≥ 2

    for (i, r₁) in enumerate(rules(rws))
        are_we_stopping(rws, settings) && break
        for (j, r₂) in enumerate(rules(rws))
            if very_verbose
                @info "considering $((i, j)) for critical pairs"
            end
            forceconfluence!(rws, r₁, r₂, verbose = very_verbose)
            r₁ === r₂ && break
            if very_verbose
                @info "considering $((j, i)) for critical pairs"
            end
            forceconfluence!(rws, r₂, r₁, verbose = very_verbose)
        end
        if settings.verbosity == 1
            total = nrules(rws)
            settings.update_progress(total, i)
        end
    end

    return reduce!(alg, rws)
end

"""
    reduce!(::NaiveKBS1Alg, rws::RewritingSystem)
Bring `rws` to its reduced form using the naive algorithm.

The returned system consists of rules `p → rewrite(p, rws)` for `p` in
[`irreducible_subsystem(rws)`](@ref).
"""
function reduce!(::KBPlain, rws::RewritingSystem)
    W = word_type(rws)
    rws_dc = deepcopy(rws)
    P = irreducible_subsystem(rws)
    new_rules =
        [Rule{W}(lhs, rewrite(lhs, rws_dc), ordering(rws)) for lhs in P]
    rws = empty!(rws)
    append!(rws.rwrules, new_rules)
    rws.reduced = true
    return rws
end

"""
    subwords(w::AbstractWord[, minlength=1, maxlength=length(w)])
Return an iterator over all `SubWord`s of `w` of length between `minlength` and `maxlength`.
"""
function subwords(w::AbstractWord, minlength = 1, maxlength = length(w))
    n = length(w)
    return (
        @view(w[i:j]) for i in 1:n for
        j in i:n if minlength <= j - i + 1 <= maxlength
    )
end

"""
    irreducible_subsystem(rws::AbstractRewritingSystem)
Return an array of left sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function irreducible_subsystem(rws::AbstractRewritingSystem)
    lsides = Vector{word_type(rws)}()
    for rule in rules(rws)
        lhs = first(rule)
        length(lhs) >= 2 || break
        for sw in subwords(lhs, 2, length(lhs) - 1)
            if !isirreducible(sw, rws)
                @debug "subword $sw of $lhs is reducible. skipping!"
                break
            end
        end
        if all(sw -> isirreducible(sw, rws), subwords(lhs, 2, length(lhs) - 1))
            @debug "all subwords are irreducible; pushing $lhs"
            push!(lsides, lhs)
        end
    end
    return unique!(lsides)
end
