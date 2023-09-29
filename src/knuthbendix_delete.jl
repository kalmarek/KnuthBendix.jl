## KBS2 with deletion of inactive
struct KBS2AlgRuleDel <: KBS2AlgAbstract end

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

function knuthbendix!(
    method::KBS2AlgRuleDel,
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    work = Workspace(rws)
    stack = Vector{Tuple{W,W}}()
    rws = reduce!(method, rws, work) # we begin with a reduced system

    i = 1
    while i ≤ length(rws.rwrules)
        are_we_stopping(rws, settings) && break
        ri = rws.rwrules[i]
        for rj in rules(rws)
            isactive(ri) || break
            forceconfluence!(rws, stack, ri, rj, work)

            ri === rj && break
            isactive(ri) || break
            isactive(rj) || continue
            forceconfluence!(rws, stack, rj, ri, work)
        end
        rws, i = remove_inactive!(rws, i)

        if settings.verbosity > 0
            total = count(isactive, rws.rwrules)
            settings.update_progress(total, i)
        end
        i += 1
    end
    return rws # so the rws is reduced here as well
end
