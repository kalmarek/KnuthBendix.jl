## KBS with deletion of inactive rules

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
    work = Workspace(rws)
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
