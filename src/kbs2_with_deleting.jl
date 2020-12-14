"""
    knuthbendix2delinactive!(rws::RewritingSystem[, o::Ordering=ordering(rws);
    maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termiantion takes place after the number of rules stored within
the RewritngSystem reaches `maxrules`.
"""
# function knuthbendix2delinactive!(rws::RewritingSystem,
#     o::Ordering = ordering(rws); maxrules::Integer = 100)
#     stack = copy(rules(rws)[active(rws)])
#     rws = empty!(rws)
#     deriverule!(rws, stack, o, true)

#     rws._i.x = 1
#     while rws._i[] ≤ length(rws)
#         # @debug "number_of_active_rules" sum(active(rws))
#         if length(rws) > maxrules
#             @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
#                 You may retry with `maxrules` kwarg set to higher value.")
#             break
#         end
#         rws._j.x  = 1
#         while (rws._j[] ≤ rws._i[])
#             forceconfluence!(rws, stack, rws._i[], rws._j[], o, true)
#             if rws._j[] < rws._i[] && isactive(rws, rws._i[]) && isactive(rws, rws._j[])
#                 forceconfluence!(rws, stack, rws._j[], rws._i[], o, true)
#             end
#             removeinactive!(rws)
#             rws._j.x += 1
#         end
#         rws._i.x += 1
#     end
#     return rws
# end



function knuthbendix2delinactive!(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    deriverule!(rws, stack, o, true)
    work = kbWork(Ref(length(rws)), Ref(1), Ref(1))

    while get_i(work) ≤ get_n(work)
        # @debug "number_of_active_rules" sum(active(rws))
        if get_n(work) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        work.j.x = 1
        while (get_j(work) ≤ get_i(work))
            forceconfluence!(rws, stack, get_i(work), get_j(work), o, true, work)
            if get_j(work) < get_i(work) && isactive(rws, get_i(work)) && isactive(rws, get_j(work))
                forceconfluence!(rws, stack, get_j(work), get_i(work), o, true, work)
            end
            removeinactive!(rws, work)
            work.j.x += 1
        end
        work.i.x += 1
    end
    return rws
end

function knuthbendix2delinactive(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix2delinactive!(deepcopy(rws), maxrules=maxrules)
end

# abstract type AbstractkbWork end

struct kbWork #<: AbstractkbWork
    n::Base.RefValue{Int}
    i::Base.RefValue{Int}
    j::Base.RefValue{Int}
end

get_i(wrk::kbWork) = wrk.i[]
get_j(wrk::kbWork) = wrk.j[]
get_n(wrk::kbWork) = wrk.n[]


function removeinactive!(rws::RewritingSystem, work::kbWork)
    hasinactiverules(rws) || return
    isempty(rws) && return
    sort!(rws._inactiverules)

    while !isempty(rws._inactiverules)
        idx = pop!(rws._inactiverules)
        deleteat!(rws, idx)
        idx ≤ get_i(work) && (work.i.x = work.i .- 1)
        idx ≤ get_j(work) && (work.j.x = work.j .- 1)
        work.n.x = work.n .- 1
    end
end