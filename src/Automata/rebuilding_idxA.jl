function _rebuild!(idxA::IndexAutomaton, rws::RewritingSystem)
    # Most of the information in idxA can be reused;
    # however here we just rebuild it from scratch
    at = IndexAutomaton(rws)
    idxA.initial = at.initial
    idxA.fail = at.fail
    idxA.states = at.states
    return idxA
end

function rebuild!(idxA::IndexAutomaton, rws::RewritingSystem)
    # mark all states as not up to date
    for states in idxA.states
        for σ in states
            σ.uptodate = false
            σ.data = 0
        end
    end

    # rebuild direct edges
    for rule in rules(rws)
        rebuild_direct_path!(idxA, rule)
    end

    # remove redundant states
    for states in idxA.states
        filter!(s -> s.uptodate, states)
    end

    # recompute skew edges if they lead to redundant states
    idxA = rebuild_skew_edges!(idxA)
    return idxA
end

function rebuild_direct_path!(idxA::IndexAutomaton, rule::Rule)
    lhs, _ = rule
    σ = initial(idxA)
    σ.data += 1
    for (radius, letter) in enumerate(lhs)
        if isfail(idxA, σ[letter])
            τ = State(idxA.fail, @view(lhs[1:radius]), 0)
            addstate!(idxA, τ)
            addedge!(idxA, σ, τ, letter)
        else # σ[letter] is already defined
            # we're rebuilding so there's still some work to do
            σl = σ[letter]
            if length(id(σl)) < radius
                # the edge is skew instead of direct
                τ = State(idxA.fail, @view(lhs[1:radius]), 0)
                addstate!(idxA, τ)
                addedge!(idxA, σ, τ, letter)
            elseif isterminal(idxA, σl) && id(σl) ≠ lhs
                # the edge leads to a redundant terminal state
                @warn "terminal state in the middle of the direct path found:" rule σl
                τ = typeof(α)(σl.transitions, id(σl), 0)
                addstate!(idxA, τ)
                addedge!(idxA, σ, τ, letter)
            else # finally it's a good one, so we keep it!
                σl.uptodate = true
                if @view(id(σl)[1:end-1]) ≠ id(σ) && id(σl)[end] == letter
                    @error "While producing direct edges" rule radius σ σ[letter]
                    throw("This shouldn't happen")
                end
            end
        end
        @assert id(σ[letter]) == @view lhs[1:radius]

        σ = σ[letter]
        σ.data += 1
    end
    setvalue!(σ, rule)
    return idxA
end

function _is_valid_direct_edge(σ, label)
    return σ[label].uptodate && length(id(σ[label])) == length(id(σ)) + 1
end

function rebuild_skew_edges!(idxA::IndexAutomaton)
    # rebuilding has to be done in breadth-first fashion
    # to ensure that trace(U, idxA) is successful
    # since we're rebuilding idxA the induction step is already done
    for states in idxA.states
        for σ in states # states of particular radius
            if isterminal(idxA, σ)
                self_complete!(idxA, σ, override = true)
                continue
            end

            σ_is_done = true
            for label in 1:max_degree(σ)
                σ_is_done &=
                    !isfail(idxA, σ[label]) && _is_valid_direct_edge(σ, label)
            end
            σ_is_done && continue
            # so that we don't trace unnecessarily

            # IDEA: if we have suffix(parent(σ)), then τ could be computed as
            # τ = suffix(parent(σ))[last(id(σ))]
            # pros: τ in constant time (independent of length(id(σ)))
            # cons: enlarge State by 2 words (pointers)
            τ = let U = @view id(σ)[2:end]
                l, τ = trace(U, idxA) # we're tracing a shorter word, so...
                @assert l == length(U) # the whole U defines a path in A and
                @assert !has_fail_edges(τ, idxA) # (by the induction step)
                τ
            end

            for label in 1:max_degree(σ)
                if isfail(idxA, σ[label]) || !_is_valid_direct_edge(σ, label)
                    addedge!(idxA, σ, τ[label], label)
                end
            end
        end
    end
    return idxA
end
