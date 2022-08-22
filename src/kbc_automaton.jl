########################################
# KBS using index automata for rewriting
########################################

"""
    check_local_confluence!(stack, rewriting, r₁::Rule, r₂::Rule, work::kbWork)
Check if `rewriting` object satisfies local confluence at rules `r₁` and `r₂`.
Critical pairs derived from lhs'es of the rules will be pushed onto `stack`.

Return the number of new critical pairs.
"""
function check_local_confluence!(
    stack,
    rewriting,
    r₁::Rule,
    r₂::Rule,
    work::kbWork,
)
    l = length(stack)
    stack = find_critical_pairs!(stack, rewriting, r₁, r₂, work)
    if r₁ !== r₂
        stack = find_critical_pairs!(stack, rewriting, r₂, r₁, work)
    end
    return length(stack) - l
end

function find_critical_pairs!(
    stack,
    idxA::IndexAutomaton,
    r₁::Rule,
    r₂::Rule,
    work::kbWork,
)
    lhs₁, rhs₁ = r₁
    lhs₂, rhs₂ = r₂
    m = min(length(lhs₁), length(lhs₂))
    W = word_type(idxA)

    for b in suffixes(lhs₁, 1:m)
        if isprefix(b, lhs₂)
            lb = length(b)
            @views rhs₁_c, a_rhs₂ = @inline _store!(
                work,
                lhs₁[1:end-lb],
                rhs₂,
                rhs₁,
                lhs₂[lb+1:end],
            )
            critical, (a, c) = @inline _iscritical(a_rhs₂, rhs₁_c, idxA, work)
            critical && push!(stack, (W(a), W(c)))
        end
    end
    return stack
end

function time_to_rebuild(rws::RewritingSystem, stack, settings::Settings)
    ss = settings.stack_size
    return ss <= 0 || length(stack) > ss
end

function rebuild!(
    idxA::IndexAutomaton,
    rws::RewritingSystem,
    stack,
    i::Integer = 1,
    j::Integer = 1,
    work::kbWork = kbWork(rws),
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
    for (idx, r) in enumerate(rws.rwrules)
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
    @assert i ≥ j

    remove_inactive!(rws)
    # 3. re-sync the automaton with rws
    idxA = rebuild!(idxA, rws)
    return rws, idxA, i, j
end

function knuthbendix2automaton!(
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

        # rws is reduced now so we can create its index
        idxA = IndexAutomaton(rws)
        stack = Vector{Tuple{W,W}}()

        i = 1
        while i ≤ length(rws.rwrules)
            ri = rws.rwrules[i]
            # TODO: use backtracking to complete the lhs of ri
            j = 1
            while j ≤ i
                if are_we_stopping(rws, settings)
                    return reduce!(rws, work)
                end
                rj = rws.rwrules[j]

                # TODO: can we multithread this part?
                # Note:
                #   1. each thread needs its own stack, work;
                #   2. idxA stores path which makes rewriting with it thread unsafe

                num_new = check_local_confluence!(stack, idxA, ri, rj, work)

                if num_new > 0 && time_to_rebuild(rws, stack, settings)
                    rws, idxA, i, j = rebuild!(idxA, rws, stack, i, j, work)
                    @assert isempty(stack)
                    # rws is reduced by now
                end
                j += 1
            end

            prog.n = count(isactive, rws.rwrules)
            update!(
                prog,
                i,
                showvalues = [(
                    Symbol("processing rules (done/total/stack)"),
                    "$(prog.counter)/$(prog.n)/$(length(stack))",
                )],
            )

            # we finished processing all rules but the stack is nonempty
            if i == length(rws.rwrules) && !isempty(stack)
                @debug "reached end of rwrules with $(length(stack)) rules on stack"
                rws, idxA, i, _ = rebuild!(idxA, rws, stack, i, 1, work)
                @assert isempty(stack)
            end
            i += 1
        end
        finish!(prog)
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
