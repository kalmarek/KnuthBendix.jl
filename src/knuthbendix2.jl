## Naive, i.e. KBS2 implementation

abstract type KBS2Alg <: CompletionAlgorithm end

Settings(::KBS2Alg) = Settings(; max_rules = 500)

"""
    KBStack <: KBS2Alg <: CompletionAlgorithm
The Knuth-Bendix completion algorithm that (if successful) yields the reduced,
confluent rewriting system generated by rules of `rws`.

`KBStack` uses a stack of new rules and with each addition of a new
rule to the rewriting system all rules potentially redundant are moved onto the
stack. This way the rewriting system is always reduced and only the
non-redundant rules are considered for finding critical pairs.

This implementation follows closely `KBS_2` procedure as described in
**Section 2.6**[^Sims1994], p. 76.

!!! warning
    Forced termination takes place after the number of **active** rules
    stored in the `RewritingSystem` reaches `max_rules`.

[^Sims1994]: Charles C. Sims _Computation with finitely presented groups_,
             Cambridge University Press, 1994.
"""
struct KBStack <: KBS2Alg end

function _iscritical(work::Workspace, rewriting, lhs::Tuple, rhs::Tuple)
    L = let rws = rewriting, rwbuffer = work.rewrite1, words = lhs
        Words.store!(rwbuffer, words...)
        rewrite!(rwbuffer, rws)
    end
    R = let rws = rewriting, rwbuffer = work.rewrite2, words = rhs
        Words.store!(rwbuffer, words...)
        rewrite!(rwbuffer, rws)
    end
    L, R = simplify!(L, R, ordering(rewriting), balance = true)
    return L ≠ R, (L, R)
end

"""
    find_critical_pairs!(stack, rws, r₁::Rule, r₂::Rule[, work=Workspace(rws))
Find critical pairs derived from suffix-prefix overlaps of lhses of `r₁` and `r₂`.

Such failures (i.e. failures to local confluence) arise as `W = ABC` where
`AB`, `BC` are the left-hand-sides of rules `r₁` and `r₂`, respectively.
It is assumed that all `A`, `B` and `C` are nonempty.
"""
function find_critical_pairs!(
    stack,
    rewriting,
    r₁::Rule,
    r₂::Rule,
    work::Workspace = Workspace(rewriting),
)
    @assert isreduced(rewriting)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    m = min(length(lhs₁), length(lhs₂)) - 1
    W = word_type(stack)

    # TODO: cache suffix automaton for lhs₁ to run this in O(m) (currently: O(m²))
    for b in suffixes(lhs₁, 1:m)
        if isprefix(b, lhs₂)
            lb = length(b)
            critical, (P, Q) = @views _iscritical(
                work,
                rewriting,
                (lhs₁[1:end-lb], rhs₂),
                (rhs₁, lhs₂[lb+1:end]),
            )

            # memory of P and Q is owned by work struct so we take ownership here
            critical && push!(stack, (P, Q))
        end
    end
    return stack
end

"""
    deriverule!(rws::RewritingSystem, stack[, work = Workspace(rws)])
Empty `stack` of (potentially) critical pairs by deriving and adding new rules
to `rws` resolving the pairs, i.e. maintains local confluence of `rws`.

This function may deactivate rules in `rws` if they are deemed redundant (e.g.
follow from the added new rules). See [Sims, p. 76].
"""
function deriverule!(
    rws::AbstractRewritingSystem,
    stack,
    work::Workspace = Workspace(rws),
)
    W = word_type(rws)
    while !isempty(stack)
        u, v = pop!(stack)
        critical, (a, b) = _iscritical(work, rws, (u,), (v,))
        if critical
            new_rule = Rule{W}(a => b)
            push!(rws, new_rule)
            deactivate_rules!(rws, stack, new_rule, work)
        end
    end
end

function deactivate_rules!(
    rws::AbstractRewritingSystem,
    stack,
    new_rule::Rule,
    work::Workspace = Workspace(rws),
)
    for rule in rules(rws)
        rule == new_rule && continue
        (lhs, rhs) = rule
        if occursin(first(new_rule), lhs)
            deactivate!(rule)
            push!(stack, (lhs, rhs))
        elseif occursin(first(new_rule), rhs)
            buffer = work.iscritical_1p
            Words.store!(buffer, rhs)
            new_rhs = rewrite!(buffer, rws)
            Words.store!(rule, new_rhs)
        end
    end
end

"""
    forceconfluence!(rws::RewritingSystem, stack, r₁, r₂[, work = Workspace(rws)])
Examine overlaps of left hand sides of rules `r₁` and `r₂` to find (potential)
failures to local confluence. New rules are added to assure local confluence if
necessary.

This version assumes the reducedness of `rws` so that failures to local confluence
are of the form `a·b·c` with all `a`, `b`, `c` non trivial and `lhs₁ = a·b` and
`lhs₂ = b·c`.

This version uses `stack` to maintain the reducedness of `rws` and
`work::Workspace` to save allocations in the rewriting.

See procedure `OVERLAP_2` in [Sims, p. 77].
"""
function forceconfluence!(
    rws::RewritingSystem{W},
    stack,
    r₁,
    r₂,
    work::Workspace = Workspace(rws),
) where {W}
    stack = find_critical_pairs!(stack, rws, r₁, r₂, work)
    return deriverule!(rws, stack, work)
end

function knuthbendix!(
    method::KBStack,
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    work = Workspace(rws, settings)
    stack = Vector{Tuple{W,W}}()
    if !isreduced(rws)
        rws = reduce!(settings.algorithm, rws, work) # we begin with a reduced system
    end

    for (i, ri) in enumerate(rules(rws))
        are_we_stopping(settings, rws) && break
        for rj in rules(rws)
            isactive(ri) || break
            forceconfluence!(rws, stack, ri, rj, work)

            ri === rj && break
            isactive(ri) || break
            isactive(rj) || continue
            forceconfluence!(rws, stack, rj, ri, work)
        end

        if settings.verbosity > 0
            total = count(isactive, rws.rwrules)
            settings.update_progress(total, i)
        end
    end
    remove_inactive!(rws)
    return rws # so the rws is reduced here as well
end

"""
    reduce!(::KBS2Alg, rws::RewritingSystem)
Bring `rws` to its reduced form using the stack-based algorithm.

For details see
[`reduce!`](@ref reduce!(::KBS2Alg, ::RewritingSystem, ::Any)).
"""
function reduce!(
    method::KBS2Alg,
    rws::RewritingSystem,
    work::Workspace = Workspace(rws);
    sort_rules = true,
)
    try
        if !isreduced(rws)
            remove_inactive!(rws)
            stack = [(first(r), last(r)) for r in rules(rws)]
            R = empty(rws)
            R.reduced = true # well R is empty ;)
            R, _ = reduce!(method, R, stack, 0, 0, work)
            resize!(rws.rwrules, nrules(R))
            copyto!(rws.rwrules, R.rwrules)
        end
        if sort_rules
            reverse!(rws.rwrules)
            sort!(rws.rwrules, by = length ∘ first)
        end
        rws.reduced = true
    catch e
        if e isa InterruptException
            @warn "Received user interrupt: returned rws may be not reduced"
            return rws
        end
        rethrow(e)
    end

    return rws
end

"""
    reduce!(rws::RewritingSystem[, work=Workspace(rws); kwargs...])
Reduce the rewriting system in-place using the default algorithm

Currently the default algorithm is KBStack(), see
[`reduce!(::KBStack, ...)`](@ref
reduce!(::KBStack, ::RewritingSystem, work::Workspace)).
"""
function reduce!(
    rws::RewritingSystem,
    work::Workspace = Workspace(rws);
    kwargs...,
)
    rws = reduce!(KBStack(), rws, work; kwargs...)
    remove_inactive!(rws)
    return rws
end
