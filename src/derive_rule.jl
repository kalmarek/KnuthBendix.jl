##################################
# Crude, i.e., KBS1 implementation
##################################

function _iscritical(u::AbstractWord, v::AbstractWord, rewriting)
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

# As of now: default implementation

function _iscritical(u::AbstractWord, v::AbstractWord, rewriting, work::kbWork)
    a = rewrite_from_left!(work.lhsPair, u, rewriting)
    b = rewrite_from_left!(work.rhsPair, v, rewriting)
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
    work::kbWork,
    o::Ordering = ordering(rws),
) where {W}
    while !isempty(stack)
        u, v = pop!(stack)
        critical, (a, b) = _iscritical(u, v, rws, work)
        if critical
            simplifyrule!(a, b, o)
            new_rule = Rule{W}(W(a), W(b), o)
            deactivate_rules!(rws, stack, work, new_rule)
            push!(rws, new_rule)
        end
    end
end

function deactivate_rules!(
    rws::RewritingSystem,
    stack,
    work::kbWork,
    new_rule::Rule,
)
    for rule in rules(rws)
        rule == new_rule && continue
        (lhs, rhs) = rule
        if occursin(new_rule.lhs, lhs)
            deactivate!(rule)
            push!(stack, (first(rule), last(rule)))
        elseif occursin(new_rule.lhs, rhs)
            new_rhs = rewrite_from_left!(work.rhsPair, rhs, rws)
            update_rhs!(rule, new_rhs)
        end
    end
end

########################################
# KBS using index automata for rewriting
########################################

"""
    deriverule!(rs::RewritingSystem, at::Automaton, stack
    [,work = nothing, o::Ordering=ordering(rs))])
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintaining local confluence.
See [Sims, p. 76].
"""
function deriverule!(
    rs::RewritingSystem{W},
    stack,
    work::kbWork,
    at::Automaton,
    o::Ordering = ordering(rs),
) where {W<:AbstractWord}
    while !isempty(stack)
        u, v = pop!(stack)
        critical, (a, b) = _iscritical(u, v, at, work)

        if critical
            simplifyrule!(a, b, o)
            new_rule = Rule{W}(a, b, o)
            push!(rs, new_rule)
            # TODO: push!(at, new_rule)
            updateautomaton!(at, rs)

            for rule in rules(rs)
                rule == new_rule && break
                (lhs, rhs) = rule
                if occursin(new_rule.lhs, lhs)
                    deactivate!(rule)
                    push!(stack, (first(rule), last(rule)))
                    # TODO: delete!(at, rule)
                    updateautomaton!(at, rs)
                elseif occursin(new_rule.lhs, rhs)
                    new_rhs = rewrite_from_left!(work.rhsPair, rhs, at)
                    update_rhs!(rule, new_rhs)
                    # TODO: push!(at, rule)
                    updateautomaton!(at, rs)
                end
            end
        end
    end
end
