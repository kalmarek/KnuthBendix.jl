## KBS2 with deletion of inactive
struct KBS2AlgRuleDel <: KBS2Alg end

function remove_inactive!(rws::RewritingSystem, i::Integer)
    rws, (i, _) = remove_inactive!(rws, i, 0)
    return rws, i
end

function remove_inactive!(rws::RewritingSystem, i::Integer, j::Integer)
    _, (i, j) = remove_inactive!(__rawrules(rws), i, j)
    return rws, (i, j)
end

function remove_inactive!(v::AbstractVector{<:Rule}, i::Integer, j::Integer)
    # compute the shifts for iteration indices
    lte_i = 0 # less than or equal to i
    lte_j = 0
    for (idx, r) in pairs(v)
        if !isactive(r)
            if idx ≤ i
                lte_i += 1
            end
            if idx ≤ j
                lte_j += 1
            end
        end
        idx ≥ max(i, j) && break
    end
    i -= lte_i
    j -= lte_j
    i = max(i, firstindex(v))
    j = max(j, firstindex(v))

    filter!(isactive, v)
    return v, (i, j)
end

function knuthbendix!(
    settings::Settings{KBS2AlgRuleDel},
    rws::RewritingSystem{W},
) where {W}
    work = Workspace(rws, settings)
    stack = Vector{Tuple{W,W}}()
    rws = reduce!(settings.algorithm, rws, work) # we begin with a reduced system

    rwrules = __rawrules(rws)

    i = firstindex(rwrules)
    while i ≤ lastindex(rwrules)
        are_we_stopping(settings, rws) && break
        ri = rwrules[i]
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
            total = nrules(rws)
            settings.update_progress(total, i)
        end
        i += 1
    end
    return rws # so the rws is reduced here as well
end
