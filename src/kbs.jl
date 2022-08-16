##################################
# Crude, i.e., KBS1 implementation
##################################

function _kb_maxrules_check(rws, maxrules)
    if count(isactive, rws.rwrules) > maxrules
        @warn(
            "Maximum number of rules ($maxrules) reached. The rewriting system may not be confluent.
      You may retry `knuthbendix` with a larger `maxrules` kwarg."
        )
        return true
    end
    return false
end

"""
    knuthbendix1(rws::RewritingSystem[, o::Ordering=ordering(rs); maxrules=100])
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].
"""
function knuthbendix1!(
    rws::RewritingSystem{W},
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    progress = true,
) where {W}
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs, o)
    end

    prog = Progress(
        count(isactive, rws.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = progress,
    )

    for ri in rules(ss)
        _kb_maxrules_check(ss, maxrules) && break
        for rj in rules(ss)
            forceconfluence!(ss, ri, rj, o)
            ri == rj && break
            forceconfluence!(ss, rj, ri, o)
        end
        prog.n = count(isactive, rws.rwrules)
        next!(
            prog,
            showvalues = [(
                Symbol("processing rules (done/total)"),
                "$(prog.counter)/$(prog.n)",
            )],
        )
    end

    finish!(prog)

    p = irreduciblesubsystem(ss)
    rws = empty!(rws)

    for lside in p
        push!(rws, Rule{W}(lside, rewrite_from_left(lside, ss), o))
    end
    return rws
end

function knuthbendix1(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    kwargs...,
)
    return knuthbendix1!(deepcopy(rws), o; kwargs...)
end

##########################
# Naive KBS implementation
##########################

"""
    knuthbendix2!(rws::RewritingSystem[, o::Ordering=ordering(rws);
    maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termination takes place after the number of rules stored within
the RewritingSystem reaches `maxrules`.
"""
function knuthbendix2!(
    rws::RewritingSystem{W},
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    progress = true,
) where {W}
    stack = [(first(r), last(r)) for r in rules(rws)]
    rws = empty!(rws)
    work = kbWork{eltype(W)}()
    deriverule!(rws, stack, work, o)

    prog = Progress(
        count(isactive, rws.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = progress,
    )

    for ri in rules(rws)
        _kb_maxrules_check(rws, maxrules) && break
        for rj in rules(rws)
            total = length(rws.rwrules)

            isactive(ri) || break
            forceconfluence!(rws, stack, ri, rj, work, o)
            isactive(rj) || break
            ri == rj && break
            forceconfluence!(rws, stack, rj, ri, work, o)

            new_total = length(rws.rwrules)
            change = new_total - total

            if change > 0
                @debug "after processing:" new_total added = change active =
                    sum(isactive, rws.rwrules)
            end
        end
        prog.n = count(isactive, rws.rwrules)
        next!(
            prog,
            showvalues = [(
                Symbol("processing rules (done/total)"),
                "$(prog.counter)/$(prog.n)",
            )],
        )
    end
    finish!(prog)
    remove_inactive!(rws)
    return rws
end

function knuthbendix2(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    kwargs...,
)
    return knuthbendix2!(deepcopy(rws), o; kwargs...)
end

#####################################
# KBS with deletion of inactive rules
#####################################

# As of now: default implementation

"""
    knuthbendix2deleteinactive!(rws::RewritingSystem[, o::Ordering=ordering(rws);
        maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termination takes place after the number of rules stored within
the RewritingSystem reaches `maxrules`.
"""
function knuthbendix2deleteinactive!(
    rws::RewritingSystem{W},
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    progress = true,
) where {W<:AbstractWord}
    stack = [(first(r), last(r)) for r in rules(rws)]
    rws = empty!(rws)
    work = kbWork{eltype(W)}()
    deriverule!(rws, stack, work, o)

    prog = Progress(
        count(isactive, rws.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = progress,
    )

    RI = RulesIter(rws.rwrules, 1)

    for ri in RI
        _kb_maxrules_check(rws, maxrules) && break
        for rj in rules(rws)
            total = length(rws.rwrules)

            isactive(ri) || break
            forceconfluence!(rws, stack, ri, rj, work, o)
            isactive(rj) || break
            ri == rj && break
            forceconfluence!(rws, stack, rj, ri, work, o)

            # remove_inactive!(rws, RI, RJ)
            # remove_inactive!(rws, work)

            new_total = length(rws.rwrules)
            change = new_total - total
            if change > 0
                @debug "after processing:" new_total added = change active =
                    sum(isactive, rws.rwrules)
            end
        end
        remove_inactive!(rws, RI)

        prog.n = count(isactive, rws.rwrules)
        update!(
            prog,
            RI.inner_state,
            showvalues = [(
                Symbol("processing rules (done/total)"),
                "$(prog.counter)/$(prog.n)",
            )],
        )
    end
    finish!(prog)
    remove_inactive!(rws)
    return rws
end

function knuthbendix2deleteinactive(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    kwargs...,
)
    return knuthbendix2deleteinactive!(deepcopy(rws), o; kwargs...)
end

########################################
# KBS using index automata for rewriting
########################################

"""
    knuthbendix2automaton!((rws::RewritingSystem[, o::Ordering=ordering(rws);
    maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termination takes place after the number of rules stored within
the RewritingSystem reaches `maxrules`.
"""
function knuthbendix2automaton!(
    rws::RewritingSystem{W},
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    progress = true,
) where {W<:AbstractWord}
    stack = [(first(r), last(r)) for r in rules(rws)]
    rws = empty!(rws)
    idxA = IndexAutomaton(rws)
    work = kbWork{eltype(W)}()
    deriverule!(rws, stack, work, idxA, o)

    prog = Progress(
        count(isactive, rws.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = progress,
    )

    RI = RulesIter(rws.rwrules, 1)

    for ri in RI
        _kb_maxrules_check(rws, maxrules) && break
        for rj in rules(rws)
            total = length(rws.rwrules)

            isactive(ri) || break
            forceconfluence!(rws, stack, idxA, ri, rj, work, o)
            isactive(rj) || break
            ri == rj && break
            forceconfluence!(rws, stack, idxA, rj, ri, work, o)

            new_total = length(rws.rwrules)
            prog.n = count(isactive, rws.rwrules)

            if (chng = (new_total - total)) > 0
                @debug "after processing:" new_total added = chng active = prog.n
            end

            update!(
                prog,
                RI.inner_state,
                showvalues = [(
                    Symbol("processing rules (done/total)"),
                    "$(prog.counter)/$(prog.n)",
                )],
            )
        end
    end
    finish!(prog)
    remove_inactive!(rws)
    return rws
end

function knuthbendix2automaton(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    kwargs...,
)
    return knuthbendix2automaton!(deepcopy(rws), o; kwargs...)
end

###################
# General interface
###################

function knuthbendix!(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    implementation = :naive_kbs2,
    kwargs...,
)

    kb_implementation! = if implementation == :naive_kbs1
        knuthbendix1!
    elseif implementation == :naive_kbs2
        knuthbendix2!
    elseif implementation == :deletion
        knuthbendix2deleteinactive!
    elseif implementation == :automata
        # throw(
        #     "There are known bugs in the current automaton implementation.\nIf you know what you are doing call `knuthbendix2automaton!` at your peril.",
        # )
        knuthbendix2automaton!
    else
        impl_list = (:naive_kbs1, :naive_kbs2, :deletion, :automata)
        implementation in impl_list || throw(
            ArgumentError(
                "Implementation \"$implementation\" of Knuth-Bendix completion is not defined.\n Possible choices are: $(join(impl_list, ", ", " and ")).",
            ),
        )
    end
    return kb_implementation!(rws, o; kwargs...)
end

function knuthbendix(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    implementation = :naive_kbs2,
    maxrules::Integer = 100,
    progress::Bool = true,
)
    return knuthbendix!(
        deepcopy(rws),
        o;
        implementation = implementation,
        maxrules = maxrules,
        progress = progress,
    )
end
