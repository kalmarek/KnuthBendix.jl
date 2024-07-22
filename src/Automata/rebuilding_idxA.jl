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
    for (idx, rule) in enumerate(rules(rws))
        rebuild_direct_path!(idxA, rule, idx)
    end

    # remove redundant states
    for states in idxA.states
        filter!(s -> s.uptodate, states)
    end

    # recompute skew edges if they lead to redundant states
    idxA = rebuild_skew_edges!(idxA)
    return idxA
end

function rebuild_direct_path!(idxA::IndexAutomaton, rule::Rule, age)
    lhs, _ = rule
    σ = initial(idxA)
    for (radius, letter) in enumerate(lhs)
        σl = trace(letter, idxA, σ)
        @assert !isnothing(σl)
        if isfail(idxA, σl) || length(signature(idxA, σl)) < radius
            # edge leads to fail or is skew
            τ = State(idxA.fail, @view(lhs[1:radius]), age)
            addstate!(idxA, τ)
            addedge!(idxA, σ, τ, letter)
        else # σ[letter] is already defined
            # we're rebuilding so there's still some work to do
            if !isaccepting(idxA, σl) && signature(idxA, σl) ≠ lhs
                # the edge leads to a redundant non-accepting state
                # @warn "non-accepting state in the middle of the direct path found:" rule σl
                τ = typeof(σ)(σl.transitions, signature(idxA, σl), age)
                addstate!(idxA, τ)
                addedge!(idxA, σ, τ, letter)
            else # finally it's a good one, so we keep it!
                σl.uptodate = true
                σl.data = min(σl.data, age)
                # if @view(signature(idxA, σl)[1:end-1]) ≠ signature(idxA, σ) && signature(idxA, σl)[end] == letter
                #     @error "While producing direct edges" rule radius σ trace(letter, idxA, σ)
                #     throw("This shouldn't happen")
                # end
            end
        end

        σ = trace(letter, idxA, σ)
        @assert !isnothing(σ)
        # @assert !isfail(idxA, σ)
        # @assert signature(idxA, σ) == @view lhs[1:radius]
        # @assert σ.data ≤ age
    end
    setvalue!(σ, rule)
    return idxA
end

function _is_valid_direct_edge(idxA::IndexAutomaton, σ, label)
    σl = trace(label, idxA, σ)
    return !isfail(idxA, σl) && σl.uptodate &&
        length(signature(idxA, σl)) == length(signature(idxA, σ)) + 1
end

function rebuild_skew_edges!(idxA::IndexAutomaton)
    # rebuilding has to be done in breadth-first fashion
    # to ensure that trace(U, idxA) is successful
    # since we're rebuilding idxA the induction step is already done
    for states in idxA.states
        for σ in states # states of particular radius
            if !isaccepting(idxA, σ)
                self_complete!(idxA, σ, override = true)
                continue
            end

            σ_is_done = true
            for label in 1:max_degree(σ)
                σ_is_done &= _is_valid_direct_edge(idxA, σ, label)
            end
            σ_is_done && continue
            # so that we don't trace unnecessarily

            # IDEA: if we have suffix(parent(σ)), then τ could be computed as
            # τ = suffix(parent(σ))[last(signature(idxA, σ))]
            # pros: τ in constant time (independent of length(signature(idxA, σ)))
            # cons: enlarge State by 2 words (pointers)
            τ = let U = @view signature(idxA, σ)[2:end]
                l, τ = trace(U, idxA) # we're tracing a shorter word, so...
                @assert l == length(U) # the whole U defines a path in A and
                @assert !has_fail_edges(τ, idxA) # (by the induction step)
                τ
            end

            for label in 1:max_degree(σ)
                if !_is_valid_direct_edge(idxA, σ, label)
                    addedge!(idxA, σ, τ[label], label)
                end
            end
        end
    end
    return idxA
end
