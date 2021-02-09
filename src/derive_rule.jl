##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    deriverule!(rws::RewritingSystem, u::Word, v::Word[, o::Ordering=ordering(rws)])
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 69].
"""
function deriverule!(rws::RewritingSystem{W}, u::W, v::W,
    o::Ordering = ordering(rws)) where W

    a = rewrite_from_left(u, rws)
    b = rewrite_from_left(v, rws)
    if a != b
        lt(o, a, b) ? push!(rws, b => a) : push!(rws, a => b)
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

"""
    deriverule!(rs::RewritingSystem, stack [, o::Ordering=ordering(rs),)
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem, stack, o::Ordering = ordering(rs))
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, rs)
        b = rewrite_from_left(rr, rs)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = b => a : rule = a => b
            push!(rs, rule)

            for i in 1:length(rules(rs))-1
                isactive(rs, i) || continue
                (lhs, rhs) = rules(rs)[i]
                if occursin(rule.first, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                elseif occursin(rule.first, rhs)
                    new_rhs = rewrite_from_left(rhs, rule)
                    rules(rs)[i] = (lhs => rewrite_from_left(new_rhs, rs))
                end
            end
        end
    end
end

#####################################
# KBS with delation of inactive rules
#####################################

# As of now: default implementation

"""
    deriverule!(rs::RewritingSystem, stack, work::kbWork
        [, o::Ordering=ordering(rs), deleteinactive::Bool = false])
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem{W}, stack, work::kbWork,
    o::Ordering = ordering(rs)) where {W<:AbstractWord}
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left!(work.lhsPair, lr, rs)
        b = rewrite_from_left!(work.rhsPair, rr, rs)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = W(b) => W(a) : rule = W(a) => W(b)
            push!(rs, rule)

            for i in 1:length(rules(rs))-1
                isactive(rs, i) || continue
                (lhs, rhs) = rules(rs)[i]
                if occursin(rule.first, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                    push!(work._inactiverules, i)
                elseif occursin(rule.first, rhs)
                    rules(rs)[i] = (lhs => W(rewrite_from_left!(work.rhsPair, rhs, rs)))
                end
            end
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
insures that the set of rules is reduced while maintining local confluence.
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
