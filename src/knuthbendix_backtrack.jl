"""
    find_critical_pairs!(stack, bts, rule, work[; max_age])
Find critical pairs by completing lhs of `rule` by backtrack search on index automaton.

If `rule` can be written as `P → Q` this function performs a backtrack
search on `bts.automaton` to find possible completions of `P[2:end]` to a word
which ends with `P'` where `P' → Q'` is another rule.
The search backtracks whenever
 * the depth is greater than or equal to the length of `P'` to make sure that
 `P` and `P'` share an overlap (i.e. a nonempty suffix of `P` is a prefix of `P'`)
 * the path leads to a rule older than `max_age`. To specify unlimited search
one can pass `typemax(UInt)` here.
"""
function find_critical_pairs!(
    stack,
    search::Automata.BacktrackSearch,
    rule::Rule,
    work::Workspace;
    max_age,
)
    lhs₁, rhs₁ = rule

    W = word_type(search.automaton)

    for β in search(@view(lhs₁[2:end]), max_age=max_age)
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

isconfluent(rws::RewritingSystem) = isempty(check_confluence(rws))

"""
    check_confluence(rws::RewritingSystem)
Check if `rws` is confluent and return a stack of critical pairs discovered.

While the stack is by no means an exhaustive list of critical pairs, empty stack
is returned if and only if `rws` is confluent.
"""
function check_confluence(rws::RewritingSystem{W}) where {W}
    stack = Vector{Tuple{W,W}}()
    return check_confluence!(stack, rws)
end

function check_confluence!(
    stack,
    rws::RewritingSystem{W},
    idxA::IndexAutomaton = IndexAutomaton(rws),
    work::Workspace = Workspace(rws, idxA),
    i = firstindex(rws.rwrules),
) where {W}
    work.confluence_timer = 0
    backtrack = Automata.BacktrackSearch(idxA)
    @assert isempty(stack)

    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]
        isactive(ri) || continue
        stack = find_critical_pairs!(
            stack,
            backtrack,
            ri,
            work,
            max_age = typemax(UInt32),
        )
        if !isempty(stack)
            work.confluence_timer = 0
            return stack
        end
        i += 1
    end

    return stack
end

function time_to_check_confluence(
    rws::RewritingSystem,
    work::Workspace,
    settings::Settings,
)
    return work.confluence_timer > settings.confluence_delay
end

