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

        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            settings.update_progress(i, n)
        end
        i += 1
    end
    remove_inactive!(rws)
    return rws
end
