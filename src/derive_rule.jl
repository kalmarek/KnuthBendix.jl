##################################
# Crude, i.e., KBS1 implementation
##################################

@inline function _iscritical(u::AbstractWord, v::AbstractWord, rewriting)
    a = rewrite_from_left(u, rewriting)
    b = rewrite_from_left(v, rewriting)
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
        simplifyrule!(a, b, o)
        push!(rws, Rule{W}(a, b, o))
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

@inline function _iscritical(
    u::AbstractWord,
    v::AbstractWord,
    rewriting,
    work::Workspace,
)
    a = rewrite_from_left!(work.iscritical_1p, u, rewriting)
    b = rewrite_from_left!(work.iscritical_2p, v, rewriting)
    return a ≠ b, (a, b)
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
            simplifyrule!(a, b, o)
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
            new_rhs = rewrite_from_left!(work.iscritical_1p, rhs, rws)
            update_rhs!(rule, new_rhs)
        end
    end
end
