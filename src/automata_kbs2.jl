"""
    deriverule!(rs::RewritingSystem, at::Automaton, stack
    [,work = nothing, o::Ordering=ordering(rs))])
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem, at::Automaton, stack,
        work = nothing, o::Ordering = ordering(rs))
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, work, at)
        b = rewrite_from_left(rr, work, at)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = b => a : rule = a => b
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
                    rules(rs)[i] = (lhs => rewrite_from_left(rhs, at))
                    updateautomaton!(at, rs)
                end
            end
        end
    end
end

"""
    forceconfluence!(rs::RewritingSystem, at::Automaton, stack, i::Integer, j::Integer
    [, o::Ordering=ordering(rs)], work = nothing)
Checks the proper overlaps of right sides of active rules at position i and j
in the rewriting system. When failures of local confluence are found, new rules
are added. See [Sims, p. 77].
"""
function forceconfluence!(rs::RewritingSystem, at::Automaton, stack, i::Integer, j::Integer,
    o::Ordering = ordering(rs), work = nothing)
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        if issuffix(lhs_j, lhs_i, k)
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            deriverule!(rs, at, stack, work, o)
        end
        k += 1
    end
end

"""
    knuthbendix2automaton!((rws::RewritingSystem[, o::Ordering=ordering(rws);
    maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termiantion takes place after the number of rules stored within
the RewritngSystem reaches `maxrules`.
"""
function knuthbendix2automaton!(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    at = Automaton(alphabet(o))
    work = kbWork(1, 0)
    deriverule!(rws, at, stack, work)

    while get_i(work) ≤ length(rws)
        # @debug "number_of_active_rules" sum(active(rws))
        if sum(active(rws)) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        work.j = 1
        while (get_j(work) ≤ get_i(work))
            if isactive(rws, get_j(work))
                forceconfluence!(rws, at, stack, get_i(work), get_j(work), o, work)
                if get_j(work) < get_i(work) && isactive(rws, get_i(work)) && isactive(rws, get_j(work))
                    forceconfluence!(rws, at, stack, get_j(work), get_i(work), o, work)
                end
            end
            removeinactive!(rws, work)
            work.j += 1
        end
        work.i += 1
    end
    return rws
end

function knuthbendix2automaton(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix2automaton!(deepcopy(rws), maxrules=maxrules)
end
