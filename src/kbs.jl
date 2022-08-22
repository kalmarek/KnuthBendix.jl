function are_we_stopping(rws::RewritingSystem, settings::Settings)
    if count(isactive, rws.rwrules) > settings.max_rules
        msg = (
            "Maximum number of rules ($(settings.max_rules)) reached.",
            "The rewriting system may not be confluent.",
            "You may retry `knuthbendix` with a larger `max_rules` kwarg.",
        )
        @warn(join(msg, "\n"))
        return true
    end
    return false
end

remove_inactive!(rws) = (filter!(isactive, rws.rwrules); rws)

function reduce!(
    rws::RewritingSystem,
    work::kbWork = kbWork(rws);
    sort_rules = true,
)
    remove_inactive!(rws)
    if sort_rules
        sort!(rws.rwrules, by = length ∘ first, rev = true)
        # shortest rules are at the end of rwrules...
    end
    # ...so that they endup on the top of the stack
    stack = [(first(r), last(r)) for r in rws.rwrules]
    empty!(rws)

    deriverule!(rws, stack, work)
    @assert isempty(stack)

    if sort_rules
        reverse!(rws.rwrules)
        sort!(rws.rwrules, by = length ∘ first)
    end

    return rws
end

##################################
# Crude, i.e., KBS1 implementation
##################################

"""
    knuthbendix1(rws::RewritingSystem; max_rules=100)
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].
"""
function knuthbendix1(rws::RewritingSystem; max_rules = 100)
    return knuthbendix1!(deepcopy(rws), Settings(; max_rules = max_rules))
end

function knuthbendix1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs)
    end

    prog = Progress(
        count(isactive, ss.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = settings.verbosity > 0,
    )

    for ri in rules(ss)
        are_we_stopping(ss, settings) && break
        for rj in rules(ss)
            forceconfluence!(ss, ri, rj)
            ri === rj && break
            forceconfluence!(ss, rj, ri)
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
        push!(rws, (lside, rewrite_from_left(lside, ss)))
    end
    return rws
end

##########################
# Naive KBS implementation
##########################

"""
    knuthbendix2(rws::RewritingSystem; max_rules::Integer=100)
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termination takes place after the number of rules stored within
the RewritingSystem reaches `max_rules`.
"""
function knuthbendix2(rws::RewritingSystem; max_rules = 100)
    return knuthbendix2!(deepcopy(rws), Settings(; max_rules = max_rules))
end

function knuthbendix2!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    work = kbWork(rws)
    rws = reduce!(rws, work)

    try
        prog = Progress(
            count(isactive, rws.rwrules),
            desc = "Knuth-Bendix completion ",
            showspeed = true,
            enabled = settings.verbosity > 0,
        )
        stack = Vector{Tuple{W,W}}()

        for ri in rules(rws)
            are_we_stopping(rws, settings) && break
            for rj in rules(rws)
                isactive(ri) || break
                forceconfluence!(rws, stack, ri, rj, work)

                ri === rj && break
                isactive(ri) || break
                isactive(rj) || break
                forceconfluence!(rws, stack, rj, ri, work)
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
    catch e
        if e == InterruptException()
            @warn "Received user interrupt in Knuth-Bendix completion.
            Returned rws is reduced, but not confluent"
            return reduce!(rws)
        else
            rethrow(e)
        end
    end
end

#####################################
# KBS with deletion of inactive rules
#####################################

function remove_inactive!(rws::RewritingSystem, i::Integer)
    lte_i = 0 # less than or equal to i
    for (idx, r) in enumerate(rws.rwrules)
        if !isactive(r)
            if idx ≤ i
                lte_i += 1
            end
        end
        idx ≥ i && break
    end
    i -= lte_i
    remove_inactive!(rws)
    return rws, i
end

function knuthbendix2deleteinactive!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    work = kbWork{eltype(W)}()
    rws = reduce!(rws, work)

    try
        prog = Progress(
            count(isactive, rws.rwrules),
            desc = "Knuth-Bendix completion ",
            showspeed = true,
            enabled = settings.verbosity > 0,
        )

        stack = Vector{Tuple{W,W}}()
        i = 1
        while i ≤ length(rws.rwrules)
            are_we_stopping(rws, settings) && break
            ri = rws.rwrules[i]
            j = 1
            while j ≤ i
                rj = rws.rwrules[j]

                isactive(ri) || break
                isactive(rj) || break
                forceconfluence!(rws, stack, ri, rj, work)

                ri === rj && break
                isactive(ri) || break
                isactive(rj) || break
                forceconfluence!(rws, stack, rj, ri, work)
                j += 1
            end
            rws, i = remove_inactive!(rws, i)

            prog.n = count(isactive, rws.rwrules)
            update!(
                prog,
                i,
                showvalues = [(
                    Symbol("processing rules (done/total)"),
                    "$(prog.counter)/$(prog.n)",
                )],
            )
            i += 1
        end
        finish!(prog)
        remove_inactive!(rws)
        return rws
    catch e
        if e == InterruptException()
            @warn "Received user interrupt in Knuth-Bendix completion.
            Returned rws is reduced, but not confluent"
            return reduce!(rws)
        else
            rethrow(e)
        end
    end
end

###################
# General interface
###################

function knuthbendix(
    rws::RewritingSystem;
    max_rules::Integer = 100,
    stack_size::Integer = 100,
    progress::Bool = true,
    implementation::Symbol = :index_automaton,
)
    return knuthbendix(
        rws,
        Settings(
            max_rules = max_rules,
            stack_size = stack_size,
            verbosity = progress,
        );
        implementation = implementation,
    )
end

function knuthbendix(
    rws::RewritingSystem,
    settings::Settings = Settings();
    implementation::Symbol = :index_automaton,
)
    return knuthbendix!(
        deepcopy(rws),
        settings;
        implementation = implementation,
    )
end

function knuthbendix!(
    rws::RewritingSystem,
    settings::Settings;
    implementation::Symbol = :index_automaton,
)
    kb_implementation! = if implementation == :naive_kbs1
        knuthbendix1!
    elseif implementation == :naive_kbs2
        knuthbendix2!
    elseif implementation == :rule_deletion
        knuthbendix2deleteinactive!
    elseif implementation == :index_automaton
        knuthbendix2automaton!
    else
        impl_list = (:naive_kbs1, :naive_kbs2, :rule_deletion, :index_automaton)
        implementation in impl_list || throw(
            ArgumentError(
                "Implementation \"$implementation\" of Knuth-Bendix completion is not defined.\n Possible choices are: $(join(impl_list, ", ", " and ")).",
            ),
        )
    end
    return kb_implementation!(rws, settings)
end
