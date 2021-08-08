##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    deriverule!(rws::RewritingSystem, u::Word, v::Word[, o::Ordering=ordering(rws)])
Given a critical pair `(u, v)` with respect to `rws` adds a rule to `rws`
(if necessary) that solves the pair, i.e. makes `rws` locally confluent with
respect to `(u,v)`. See [Sims, p. 69].
"""
function deriverule!(rws::RewritingSystem{W}, u::AbstractWord, v::AbstractWord,
    o::Ordering = ordering(rws)) where W

    a = rewrite_from_left(u, rws)
    b = rewrite_from_left(v, rws)
    if a != b
        simplifyrule!(a, b, o)
        push!(rws, Rule{W}(a, b, o))
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

# As of now: default implementation

"""
    deriverule!(rs::RewritingSystem, stack, work::kbWork
        [, o::Ordering=ordering(rs), deleteinactive::Bool = false])
Empty `stack` of (potentially) critical pairs by deriving and adding new rules
to `rs` resolving the pairs, i.e. maintains local confluence of `rs`.

This function may deactivate rules in `rs` if they are deemed redundant (e.g.
follow from the added new rules). See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem{W}, stack, work::kbWork,
    o::Ordering = ordering(rs)) where W
    while !isempty(stack)
        lhs, rhs = pop!(stack)
        a = rewrite_from_left!(work.lhsPair, lhs, rs)
        b = rewrite_from_left!(work.rhsPair, rhs, rs)
        if a != b
            simplifyrule!(a, b, o)
            new_rule = Rule{W}(a, b, o)
            deactivate_rules!(rs, stack, work, new_rule)
            push!(rs, new_rule)
        end
    end
end

function deactivate_rules!(rws::RewritingSystem, stack, work::kbWork, new_rule::Rule)
    for rule in rules(rws)
        rule == new_rule && continue
        (lhs, rhs) = rule
        if occursin(new_rule.lhs, lhs)
            deactivate!(rule)
            push!(stack, rule)
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
function deriverule!(rs::RewritingSystem{W}, stack,
        work::kbWork, at::Automaton, o::Ordering = ordering(rs)) where {W<:AbstractWord}
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left!(work.lhsPair, lr, at)
        b = rewrite_from_left!(work.rhsPair, rr, at)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = W(b) => W(a) : rule = W(a) => W(b)
            push!(rs, rule)
            updateautomaton!(at, rs)

            for i in 1:length(rules(rs))-1
                isactive(rs, i) || continue
                (lhs, rhs) = rules(rs)[i]
                if occursin(rule.first, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                    updateautomaton!(at, rs)
                    push!(work._inactiverules, i)
                elseif occursin(rule.first, rhs)
                    rules(rs)[i] = (lhs => W(rewrite_from_left!(work.rhsPair, rhs, at)))
                    updateautomaton!(at, rs)
                end
            end
        end
    end
end
