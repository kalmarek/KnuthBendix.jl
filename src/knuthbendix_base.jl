function are_we_stopping(settings::Settings, rws::AbstractRewritingSystem)
    stopping = nrules(rws) > settings.max_rules
    if stopping && settings.verbosity ≥ 1
        @warn """Maximum number of rules ($(settings.max_rules)) reached.
            You may retry `knuthbendix` with a larger `max_rules` kwarg.
            """
    end
    return stopping
end

## General interface
"""
    knuthbendix(rws::AbstractRewritingSystem)
    knuthbendix(settings::Settings, rws::AbstractRewritingSystem)
Perform Knuth-Bendix completion on rewriting system `rws` using algorithm
defined by `method`.

!!! warn
    Rewriting systems returned by the completion algorithm may not be confluent.
    Usually this happens when
     * number of rules stored in `rws` exceeds the one permitted in `settings`,
     * the completion process is manually interrupted,
     * or when the `settings` allow the algorithm to skip the processing of
       certain critical pairs.
    You should always assume that the rewriting system is **not** confluent,
    unless [`isconfluent`](@ref) returns `true`.

Unless manually interrupted the returned rewriting system will be reduced.
"""
function knuthbendix(rws::AbstractRewritingSystem)
    return knuthbendix(Settings(), rws)
end

function knuthbendix(
    settings::Settings,
    rws::AbstractRewritingSystem,
)
    rws_dc = deepcopy(rws)
    isconfluent(rws) && return rws_dc
    try
        prog = Progress(
            length(__rawrules(rws)),
            desc = "Knuth-Bendix completion ($(settings.algorithm)) ",
            showspeed = true,
            enabled = settings.verbosity > 0,
        )

        settings.update_progress = (args...) -> _kb_progress(prog, args...)

        rws_dc = knuthbendix!(settings, rws_dc)
        finish!(prog)

        if isreduced(rws_dc)
            confluent = isconfluent(rws_dc) # sets the confluence flag
            if !confluent && settings.verbosity > 0
                @warn "The returned rws is not confluent"
            end
        end
        return rws_dc
    catch e
        if e isa InterruptException
            @warn """Received user interrupt in Knuth-Bendix completion.
            Returned rws may be not confluent."""
            @info """Attempting to reduce the rewriting system.
            You may skip this by interrupting again."""
            return reduce!(settings.algorithm, rws_dc)
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

word_type(::Type{<:AbstractVector{Tuple{W,W}}}) where {W<:AbstractWord} = W

function __kb__readd_defining_rules!(
    rws::AbstractRewritingSystem,
    settings::Settings,
)
    if settings.verbosity == 2
        @info "KnuthBendix completion has finished, however some rules were dropped; re-adding the defining rules"
    end
    rws_preserved = readd_defining_rules!(rws)
    if rws_preserved
        settings.verbosity == 2 && @info "the congruence have been preserved."
    else
        settings.verbosity == 2 &&
            @info "the rws had to be amended to preserve the congruence"
        settings.verbosity == 1 &&
            @warn "the rws had to be amended to preserve the congruence"
    end
    return rws_preserved
end
