##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    knuthbendix1(rws::RewritingSystem[, o::Ordering=ordering(rs); maxrules=100])
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].
"""
function knuthbendix1!(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs, o)
    end

    i = 1
    while i ≤ length(ss)
        @debug "at iteration $i rws contains $(length(ss.rwrules)) rules"
        if length(ss) >= maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        for j in 1:i
            forceconfluence!(ss, i, j, o)
            j < i && forceconfluence!(ss, j, i, o)
        end
        i += 1
    end

    p = getirreduciblesubsystem(ss)
    rs = empty!(rws)

    for rside in p
        push!(rws, rside => rewrite_from_left(rside, ss))
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
function knuthbendix2!(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    deriverule!(rws, stack)

    i = 1
    while i ≤ length(rules(rws))
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
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    T = eltype(W)
    work = kbWork{T}(1, 0)
    deriverule!(rws, stack, work, o)

    while get_i(work) ≤ length(rules(rws))
        # @debug "number_of_active_rules" sum(active(rws))
        if sum(active(rws)) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        work.j = 1
        while (get_j(work) ≤ get_i(work))
            forceconfluence!(rws, stack, work, get_i(work), get_j(work), o)
            if get_j(work) < get_i(work) && isactive(rws, get_i(work)) && isactive(rws, get_j(work))
                forceconfluence!(rws, stack, work, get_j(work), get_i(work), o)
            end
            removeinactive!(rws, work)
            work.j += 1
        end
        work.i += 1
    end
    return rws
end

function knuthbendix2deleteinactive(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
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
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
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
    implementation = :deletion,
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
