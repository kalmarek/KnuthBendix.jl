function are_we_stopping(rws::AbstractRewritingSystem, settings::Settings)
    if nrules(rws) > settings.max_rules
        if settings.verbosity ≥ 1
            @warn """Maximum number of rules ($(settings.max_rules)) reached.
            The rewriting system may not be confluent.
            You may retry `knuthbendix` with a larger `max_rules` kwarg.
            """
        end
        return true
    end
    return false
end

## General interface

abstract type CompletionAlgorithm end

"""
    knuthbendix(rws::AbstractRewritingSystem[, settings=Settings()])
    knuthbendix(method::CompletionAlgorithm, rws::AbstractRewritingSystem[, settings:Settings()])
Perform Knuth-Bendix completion on rewriting system `rws` using algorithm
defined by `method`.

!!! warn
    Rewriting systems returned by the completion algorithm may not be confluent.
    Usually this happens when the completion process is manually interrupted,
    or when the `settings` allow the algorithm to skip the processing of
    certain critical pairs. You should always assume that the rewriting system
    is **not** confluent, unless [`isconfluent`](@ref) returns `true`.

Unless manually interrupted the returned rewriting system will be reduced.

By default `method = KBS2AlgIndexAut()` is used.
"""
function knuthbendix(
    rws::AbstractRewritingSystem,
    settings::Settings = Settings();
)
    return knuthbendix(KBS2AlgIndexAut(), rws, settings)
end

function knuthbendix(
    method::CompletionAlgorithm,
    rws::AbstractRewritingSystem,
    settings = Settings();
)
    rws_dc = deepcopy(rws)
    isconfluent(rws) && return rws_dc
    try
        prog = Progress(
            length(__rawrules(rws)),
            desc = "Knuth-Bendix completion ($method) ",
            showspeed = true,
            enabled = settings.verbosity > 0,
        )

        settings.update_progress = (args...) -> _kb_progress(prog, args...)

        rws_dc = knuthbendix!(method, rws_dc, settings)
        finish!(prog)

        return rws_dc
    catch e
        if e isa InterruptException
            @warn """Received user interrupt in Knuth-Bendix completion.
            Returned rws may be not confluent."""
            @info """Attempting to reduce the rewriting system.
            You may skip this by interrupting again."""
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
