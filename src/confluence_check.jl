"""
    find_critical_pairs!(stack, bts, rule, work)
Find critical pairs by completing lhs of `rule` by backtrack search on index automaton.

If `rule` can be written as `P → Q` this function performs a backtrack
search on `bts.automaton` to find possible completions of `P[2:end]` to a word
which ends with `P'` where `P' → Q'` is another rule.
The search backtracks when its depth is greater than or equal to the length of
`P'` to make sure that `P` and `P'` share an overlap (i.e. a nonempty suffix of
`P` is a prefix of `P'`)
"""
function find_critical_pairs!(
    stack,
    btsearch::Automata.BacktrackSearch,
    rule::Rule,
    work::Workspace;
)
    lhs₁, rhs₁ = rule
    W = word_type(stack)

    for (lhs₂, rhs₂) in btsearch(@view(lhs₁[2:end]))
        # produce a critical pair:
        lb = length(lhs₂) - length(btsearch.history) + 1
        @assert lb > 0
        @assert @views lhs₁[end-lb+1:end] == lhs₂[1:lb]

        critical, (P, Q) = @views _iscritical(
            work,
            btsearch.automaton,
            (lhs₁[1:end-lb], rhs₂),
            (rhs₁, lhs₂[lb+1:end]),
        )

        # memory of P and Q is owned by work struct so we take ownership here
        critical && push!(stack, (W(P), W(Q)))
    end

    return stack
end

"""
    check_confluence(rws::AbstractRewritingSystem)
Check if a **reduced** rewriting system is confluent.

The check constructs index automaton for `rws` and runs a backtrack search for
all rules of the system. Return a stack of critical pairs and an index of the
rule for which local confluence failed. The returned stack is empty if and only
if `rws` is confluent.
"""
function check_confluence(
    rws::AbstractRewritingSystem;
    is_reduced = isreduced(rws),
)
    W = word_type(rws)
    stack = Vector{Tuple{W,W}}()
    return check_confluence!(stack, rws; is_reduced = is_reduced)
end

function check_confluence!(stack, rws::AbstractRewritingSystem; is_reduced)
    if !is_reduced
        throw(
            ArgumentError(
                """Confluence check is implemented for reduced rewriting systems only.
                You need to call `reduce!(rws)` on your rewriting system first, then try again.""",
            ),
        )
    end
    idxA = IndexAutomaton(rws)
    stack, _ = check_confluence!(stack, rws, idxA, Workspace(idxA))
    return stack
end

function check_confluence!(
    stack,
    rws::AbstractRewritingSystem,
    idxA::IndexAutomaton,
    work::Workspace = Workspace(idxA),
)
    l = length(stack)
    work.confluence_timer = 0
    backtrack = Automata.BacktrackSearch(idxA, Automata.ConfluenceOracle())
    for (i, ri) in pairs(__rawrules(rws))
        isactive(ri) || continue
        stack = find_critical_pairs!(stack, backtrack, ri, work)
        length(stack) > l && return stack, i
    end
    return stack, 0
end

function time_to_check_confluence(
    ::AbstractRewritingSystem,
    work::Workspace,
)
    its_time = work.confluence_timer ≥ work.settings.confluence_delay
    if its_time
        work.confluence_timer = 0
    end
    return its_time
end
