## KBS using index automata for rewriting

struct KBS2AlgIndexAut <: KBS2AlgAbstract end

function time_to_rebuild(::RewritingSystem, stack, settings::Settings)
    ss = settings.stack_size
    return ss <= 0 || length(stack) > ss
end

function Automata.rebuild!(
    idxA::Automata.IndexAutomaton,
    rws::RewritingSystem,
    stack,
    i::Integer = 1,
    j::Integer = 1,
    work::Workspace = Workspace(rws, idxA),
)
    # this function does a few things at the same time:
    # 1. empty stack by appending new rules to rws maintaining its reducibility;
    # 2. compute shifts of rules indices/iterators `i` and `j` which allow to
    #    maintain consistency if this function is called during completion;
    # 3. re-sync the index automaton with rws

    # TODO: figure out how to combine 1 and 3 so that index can be just modified

    # QUESTIONS:
    # is is beneficial to sort stack here?
    # sort!(stack, by = length ∘ first, rev = true)

    # 1. adding/deactivating new rules to rws
    # Note: can't use index automaton, as we're modifying rws here
    deriverule!(rws, stack, work)

    # 2. compute the shifts for iteration indices
    lte_i = 0 # less than or equal to i
    lte_j = 0
    for (idx, r) in pairs(rws.rwrules)
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
    i = max(i, firstindex(rws.rwrules))
    j = max(j, firstindex(rws.rwrules))

    @assert i ≥ j ≥ 1

    remove_inactive!(rws)
    # 3. re-sync the automaton with rws
    idxA = Automata.rebuild!(idxA, rws)
    work.confluence_timer = 0

    return rws, idxA, i, j
end

function knuthbendix!(
    method::KBS2AlgIndexAut,
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(method, rws)
    # rws is reduced now so we can create its index
    idxA = IndexAutomaton(rws)
    work = Workspace(rws, idxA)
    stack = Vector{Tuple{W,W}}()

    i = 1
    while i ≤ length(rws.rwrules)
        ri = rws.rwrules[i]

        work.confluence_timer += 1
        if time_to_check_confluence(rws, work, settings)
            if settings.verbosity == 2
                @info "no new rules found for $(settings.confluence_delay) itrs, attempting a confluence check at" i
            end
            stack = check_confluence!(stack, rws, idxA, work)
            isempty(stack) && return rws # yey, we're done!
            if settings.verbosity == 2
                l = length(stack)
                @info "confluence check failed: found $(l) new rule$(l==1 ? "" : "s") while processing" ri
            end
        end
        j = firstindex(rws.rwrules)
        while j ≤ i
            if are_we_stopping(rws, settings)
                return reduce!(method, rws, work)
            end

            # TODO: can we multithread this part?
            # Note:
            #   1. each thread needs its own stack, work;
            #   2. idxA stores path which makes rewriting with it thread unsafe

            rj = rws.rwrules[j]
            l = length(stack)
            stack = find_critical_pairs!(stack, idxA, ri, rj, work)
            if ri !== rj
                stack = find_critical_pairs!(stack, idxA, rj, ri, work)
            end

            if length(stack) - l > 0 && time_to_rebuild(rws, stack, settings)
                rws, idxA, i, j =
                    Automata.rebuild!(idxA, rws, stack, i, j, work)
                @assert isempty(stack)
                # rws is reduced by now
            end
            if settings.verbosity == 1
                total = nrules(rws)
                stack_size = length(stack)
                settings.update_progress(total, i, stack_size)
            end
            j += 1
        end

        # we finished processing all rules but the stack is nonempty
        if i == lastindex(rws.rwrules) && !isempty(stack)
            if settings.verbosity == 2
                @info "reached end of rwrules with $(length(stack)) rules on stack"
            end
            rws, idxA, i, _ = Automata.rebuild!(idxA, rws, stack, i, 0, work)
        end
        i += 1
    end
    return rws # so the rws is reduced here as well
end
