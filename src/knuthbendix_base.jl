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

function reduce!(
    rws::RewritingSystem,
    work::Workspace = Workspace(rws);
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
        sort!(rws.rwrules, by = length ∘ first, alg = Base.Sort.InsertionSort)
    end

    return rws
end

## General interface

function knuthbendix(
    rws::RewritingSystem,
    settings::Settings = Settings();
    implementation::Symbol = :index_automaton,
)
    R = deepcopy(rws)
    try
        return knuthbendix!(R, settings; implementation = implementation)
    catch e
        if e == InterruptException()
            @warn "Received user interrupt in Knuth-Bendix completion.
            Returned rws is reduced, but not confluent"
            return reduce!(R)
        else
            rethrow(e)
        end
    end
end

function _kb_progress(prog::Progress, total, current)
    prog.n = total
    update!(
        prog,
        current,
        showvalues = [(
            Symbol("processing rules (done/total)"),
            "$(current)/$(total)",
        )],
    )
    return prog
end

function _kb_progress(prog::Progress, total, current, on_stack)
    prog.n = total
    update!(
        prog,
        current,
        showvalues = [(
            Symbol("processing rules (done/total/on stack)"),
            "$(current)/$(total)/$(on_stack)",
        )],
    )
    return prog
end

function knuthbendix!(
    rws::RewritingSystem,
    settings::Settings;
    implementation::Symbol = :index_automaton,
)
    impl_list = (:naive_kbs1, :naive_kbs2, :rule_deletion, :index_automaton)
    implementation in impl_list || throw(
        ArgumentError(
            "Implementation \"$implementation\" of Knuth-Bendix completion is not defined.\n Possible choices are: $(join(impl_list, ", ", " and ")).",
        ),
    )

    if implementation == :naive_kbs1
        if settings.verbosity > 0
            @info "knuthbendix1 is a simplistic implementation for educational purposes only."
        end
        return knuthbendix1!(rws, settings)
    end

    prog = Progress(
        count(isactive, rws.rwrules),
        desc = "Knuth-Bendix completion ",
        showspeed = true,
        enabled = settings.verbosity > 0,
    )

    settings.update_progress = (args...) -> _kb_progress(prog, args...)

    kb_impl! = if implementation == :naive_kbs2
        knuthbendix2!
    elseif implementation == :rule_deletion
        knuthbendix2deleteinactive!
    elseif implementation == :index_automaton
        knuthbendix2automaton!
    end

    reduce!(rws)
    rws = kb_impl!(rws, settings)
    finish!(prog)
    return rws
end
