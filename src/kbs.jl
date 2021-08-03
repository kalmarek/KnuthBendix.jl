##################################
# Crude, i.e., KBS1 implementation
##################################

function _kb_maxrules_check(rws, maxrules)
    if count(isactive, rws.rwrules) > maxrules
        @warn("Maximum number of rules ($maxrules) reached. The rewriting system may not be confluent.
        You may retry `knuthbendix` with a larger `maxrules` kwarg.")
        return true
    end
    return false
end

"""
    knuthbendix1(rws::RewritingSystem[, o::Ordering=ordering(rs); maxrules=100])
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].
"""
function knuthbendix1!(rws::RewritingSystem{W}, o::Ordering = ordering(rws); maxrules::Integer = 100) where W
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs, o)
    end

    for ri in rules(ss)
        _kb_maxrules_check(ss, maxrules) && break
        for rj in rules(ss)
            forceconfluence!(ss, ri, rj, o)
            ri == rj && break
            forceconfluence!(ss, rj, ri, o)
        end
    end

    p = getirreduciblesubsystem(ss)
    rs = empty!(rws)

    for rside in p
        push!(rws, Rule{W}(rside, rewrite_from_left(rside, ss), o))
    end
    return rws
end

function knuthbendix1(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    knuthbendix1!(deepcopy(rws), o, maxrules=maxrules)
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
function knuthbendix2!(rws::RewritingSystem{W},
    o::Ordering = ordering(rws); maxrules::Integer = 100) where W
    stack = collect(rules(rws))
    rws = empty!(rws)
    work = kbWork{eltype(W)}()
    deriverule!(rws, stack, work, o)

    for ri in rules(rws)
        _kb_maxrules_check(rws, maxrules) && break
        for rj in rules(rws)
            isactive(ri) || break
            forceconfluence!(rws, stack, work, ri, rj, o)
            isactive(rj) || break
            ri == rj && break
            forceconfluence!(rws, stack, work, rj, ri, o)
        end
    end
    filter!(isactive, rws.rwrules)
    return rws
end

function knuthbendix2(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    knuthbendix2!(deepcopy(rws), o, maxrules=maxrules)
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
function knuthbendix2deleteinactive!(rws::RewritingSystem{W},
    o::Ordering = ordering(rws); maxrules::Integer = 100) where {W<:AbstractWord}
    stack = collect(rules(rws))
    rws = empty!(rws)
    work = kbWork{eltype(W)}()
    deriverule!(rws, stack, work, o)

    RI = RulesIter(rws.rwrules, 1)

    for ri in RI
        _kb_maxrules_check(rws, maxrules) && break
        RJ = RulesIter(rws.rwrules, 1)
        for rj in RJ
            isactive(ri) || break
            forceconfluence!(rws, stack, work, ri, rj, o)
            isactive(rj) || break
            ri == rj && break
            forceconfluence!(rws, stack, work, rj, ri, o)

            remove_inactive!(rws, RI, RJ)
            # remove_inactive!(rws, work)
        end
    end
    filter!(isactive, rws.rwrules)
    return rws
end

function knuthbendix2deleteinactive(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    knuthbendix2deleteinactive!(deepcopy(rws), o, maxrules=maxrules)
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
function knuthbendix2automaton!(rws::RewritingSystem{W},
    o::Ordering = ordering(rws); maxrules::Integer = 100) where {W<:AbstractWord}
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    at = Automaton(alphabet(rws))
    T = eltype(W)
    work = kbWork{T}(1, 0)
    deriverule!(rws, stack, work, at)

    while get_i(work) ≤ length(rws)
        # @debug "number_of_active_rules" sum(active(rws))
        if sum(active(rws)) > maxrules
            _kb_maxrules_warning(maxrules)
            break
        end
        work.j = 1
        while (get_j(work) ≤ get_i(work))
            if isactive(rws, get_j(work))
                forceconfluence!(rws, stack, work, at, get_i(work), get_j(work), o)
                if get_j(work) < get_i(work) && isactive(rws, get_i(work)) && isactive(rws, get_j(work))
                    forceconfluence!(rws, stack, work, at, get_j(work), get_i(work), o)
                end
            end
            removeinactive!(rws, work)
            work.j += 1
        end
        work.i += 1
    end
    return rws
end

function knuthbendix2automaton(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    knuthbendix2automaton!(deepcopy(rws), o, maxrules=maxrules)
end

###################
# General interface
###################

function knuthbendix!(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    implementation = :naive_kbs2,
)

    impl_list = (:naive_kbs1, :naive_kbs2, :deletion, :automata)
    implementation in impl_list || throw(
        ArgumentError(
            "Implementation \"$implementation\" of Knuth-Bendix completion is not defined.\n Possible choices are: $(join(impl_list, ", ", " and ")).",
        ),
    )

    if implementation == :naive_kbs1
        return knuthbendix1!(rws, o, maxrules = maxrules)
    elseif implementation == :naive_kbs2
        return knuthbendix2!(rws, o, maxrules = maxrules)
    elseif implementation == :deletion
        return knuthbendix2deleteinactive!(rws, o, maxrules = maxrules)
    elseif implementation == :automata
        throw("There are known bugs in the current automaton implementation.\nIf you know what you are doing call `knuthbendix2automaton!` at your peril.")
        return knuthbendix2automaton!(rws, o, maxrules = maxrules)
    end
end

function knuthbendix(
    rws::RewritingSystem,
    o::Ordering = ordering(rws);
    maxrules::Integer = 100,
    implementation = :deletion,
)
    return knuthbendix!(
        deepcopy(rws),
        o,
        maxrules = maxrules,
        implementation = implementation,
    )
end
