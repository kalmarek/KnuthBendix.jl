function are_we_stopping(rws::RewritingSystem, settings::Settings)
    if nrules(rws) > settings.max_rules
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

## General interface

abstract type CompletionAlgorithm end

end

"""
    knuthbendix(rws::RewritingSystem[, settings=Settings()])
    knuthbendix(method::CompletionAlgorithm, rws::RewritingSystem[, settings:Settings()])
Perform Knuth-Bendix completion on rewriting system `rws` using algorithm
defined by `method`.

A reduced rewriting system is returned.
"""
function knuthbendix(
    method::CompletionAlgorithm,
    rws::RewritingSystem,
    settings = Settings();
)
    rws_dc = deepcopy(rws)
    try
        prog = Progress(
            length(rws.rwrules),
            desc = "Knuth-Bendix completion ",
            showspeed = true,
            enabled = settings.verbosity > 0,
        )

        settings.update_progress = (args...) -> _kb_progress(prog, args...)

        rws_dc = knuthbendix!(method, rws_dc, settings)
        finish!(prog)

        return rws_dc
    catch e
        if e isa InterruptException
            @warn "Received user interrupt in Knuth-Bendix completion.
            Returned rws is reduced, but not confluent"
            return reduce!(method, rws_dc)
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
