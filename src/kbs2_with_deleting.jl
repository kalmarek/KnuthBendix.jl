"""
    knuthbendix2delinactive!(rws::RewritingSystem[, o::Ordering=ordering(rws);
    maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termiantion takes place after the number of rules stored within
the RewritngSystem reaches `maxrules`.
"""
function knuthbendix2delinactive!(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    deriverule!(rws, stack, o, true)

    rws._i.x = 1
    while rws._i[] ≤ length(rws)
        # @debug "number_of_active_rules" sum(active(rws))
        if length(rws) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        rws._j.x  = 1
        while (rws._j[] ≤ rws._i[])
            forceconfluence!(rws, stack, rws._i[], rws._j[], o, true)
            if rws._j[] < rws._i[] && isactive(rws, rws._i[]) && isactive(rws, rws._j[])
                forceconfluence!(rws, stack, rws._j[], rws._i[], o, true)
            end
            removeinactive!(rws)
            rws._j.x += 1
        end
        rws._i.x += 1
    end
    return rws
end

function knuthbendix2delinactive(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix2delinactive!(deepcopy(rws), maxrules=maxrules)
end
