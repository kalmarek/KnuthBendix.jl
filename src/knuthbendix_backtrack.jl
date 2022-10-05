"""
    find_critical_pairs!(stack, bts, rule, work[, max_age])
Find critical pairs by completing lhs of `rule` by backtrack search on index automaton.

If `rule` can be written as `P → Q` this function performs a backtrack
search on `bts.automaton` to find possible completions of `P[2:end]` to a word
which ends with `P'` where `P' → Q'` is another rule.
The search backtracks whenever
 * the depth exceeds length of `P'` to make sure that `P` and `P'` overlap
(i.e. a suffix of `P` is a prefix of `P'`)
 * the path leads to a rule older than `max_age`. If no `max_age` is given it
is determined as the age of `rule`.
"""
function find_critical_pairs!(
    stack,
    search::Automata.BacktrackSearch,
    rule::Rule,
    work::Workspace
)
    lhs₁, _ = rule

    _, β = Automata.trace(lhs₁, search.automaton)
    max_age = β.data
    return find_critical_pairs!(stack, search, rule, work, max_age)
end

function find_critical_pairs!(
    stack,
    search::Automata.BacktrackSearch,
    rule::Rule,
    work::Workspace,
    max_age
)
    lhs₁, rhs₁ = rule

    W = word_type(search.automaton)

    for β in search(@view(lhs₁[2:end]), max_age)
        # produce a critical pair:
        @assert β.data ≤ max_age
        @assert Automata.isterminal(search.automaton, β)
        lhs₂, rhs₂ = Automata.value(β)
        lb = length(lhs₂) - length(search.stack)

        if @views lhs₁[end-lb+1:end] != lhs₂[1:lb]
            @error lb lhs₁[end-lb+1:end] lhs₂[1:lb]
            throw("Backtrack returned rules with inconsistent prefix-suffix.")
        end

        @views rhs₁_c, a_rhs₂ = Words.store!(
            work.find_critical_p,
            lhs₁[1:end-lb],
            rhs₂,
            rhs₁,
            lhs₂[lb+1:end],
        )
        critical, (a, c) = _iscritical(a_rhs₂, rhs₁_c, search.automaton, work)
        # memory of a and c is owned by work.find_critical_p
        # so we need to call constructors
        critical && push!(stack, (W(a, false), W(c, false)))
    end

    return stack
end

"""
    check_confluence(rws::RewritingSystem)
Check if `rws` is a confluent rewriting system.

Return a boolean flag and a stack of critical pairs discovered in the process.
"""
function check_confluence(rws::RewritingSystem{W}) where W
    stack = Vector{Tuple{W,W}}()
    return check_confluence!(stack, rws)
end

function check_confluence!(
    stack,
    rws::RewritingSystem{W},
    idxA::IndexAutomaton = IndexAutomaton(rws),
    work::Workspace = Workspace(rws, idxA),
    i = firstindex(rws.rwrules)
) where W
    work.confluence_timer = 0
    backtrack = Automata.BacktrackSearch(idxA)
    @assert isempty(stack)

    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]
        isactive(ri) || continue
        stack = find_critical_pairs!(stack, backtrack, ri, work, typemax(UInt32))
        if !isempty(stack)
            work.confluence_timer = 0
            return false, stack
        end
        i += 1
    end

    return true, stack
end

function time_to_check_confluence(
    rws::RewritingSystem,
    work::Workspace,
    settings::Settings,
)
    return work.confluence_timer > settings.confluence_delay
end

