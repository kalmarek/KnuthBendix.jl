"""
    deriverule!(rs::RewritingSystem, stack, o::Ordering)
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem, stack, o::Ordering = ordering(rs))
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, rs)
        b = rewrite_from_left(rr, rs)
        if a != b
            if lt(o, a, b)
                a, b = b, a
            end

            for (i, (lhs, rhs)) in enumerate(rules(rs))
                isactive(rs, i) || continue
                if occursin(a, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                else occursin(a, rhs)
                    rules(rs)[i] = (lhs => rewrite_from_left(rhs, rs))
                end
            end

            push!(rs, a => b)
        end
    end
end

"""
    forceconfluence!(rs::RewritingSystem, stack, i::Integer, j::Integer, o::Ordering)
Checks the proper overlaps of right sides of active rules at position i and j
in the rewriting system. When failures of local confluence are found, new rules
are added. See [Sims, p. 77].
"""
function forceconfluence!(rs::RewritingSystem, stack, i::Integer, j::Integer, o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        if issuffix(lhs_j, lhs_i, k)
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            deriverule!(rs, stack, o)
        end
        k += 1
    end
end

"""
    knuthbendix2!(rws::RewritingSystem, o::Ordering, maxrules::Integer)
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termiantion takes place after the number of rules stored within
the RewritngSystem reaches `maxrules`.
"""
function knuthbendix2!(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    deriverule!(rws, stack)

    i = 1
    while i ≤ (length(rules(rws)))
        # @debug "number_of_active_rules" sum(active(rws))
        if sum(active(rws)) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        j = 1
        while (j ≤ i && isactive(rws, i))
            if isactive(rws, j)
                forceconfluence!(rws, stack, i, j, o)
                if j < i && isactive(rws, i) && isactive(rws, j)
                    forceconfluence!(rws, stack, j, i, o)
                end
            end
            j += 1
        end
        i += 1
    end
    deleteat!(rules(rws), .!active(rws))
    resize!(active(rws), length(rules(rws)))
    active(rws) .= true
    return rws
end

function knuthbendix2(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix2!(deepcopy(rws), maxrules=maxrules)
end
