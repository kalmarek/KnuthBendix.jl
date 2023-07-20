struct RuleStacks{W}
    stacks::Vector{Vector{Tuple{W,W}}}
end

RuleStacks{W}(n::Int) where {W} = RuleStacks{W}([Vector{Tuple{W,W}}() for _ in 1:n])

Base.isempty(s::RuleStacks) = all(isempty.(s.stacks))
Base.length(s::RuleStacks) = sum(length.(s.stacks))

# TODO: This assume at least one element in one stack, otherwise it returns nothing.
# Does this behaviour match other pop! implementations?
function Base.pop!(s::RuleStacks)
    for stack in Iterators.reverse(s.stacks)
        if !isempty(stack)
            return pop!(stack)
        end
    end
end

Base.push!(stacks::RuleStacks{W}, s::Tuple{W,W}) where {W} = push!(last(stacks, s))
getstack(s::RuleStacks, i::Int) = s.stacks[i]

function getindex(s::RuleStacks, i::Int)
    for stack in s.stacks
        if i ≤ length(stack)
            return stack[i]
        else
            i -= length(stack)
        end
    end
end

"""
Notes:
    1. This should probably be called with stacksize = stacksize / nthreads()
"""
function kb2idxA_parallel_1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    idxA = IndexAutomaton(rws)
    stacks = RuleStacks{W}(Threads.nthreads())
    work = Workspace(rws, idxA)

    i = firstindex(rws.rwrules)
    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]

        work.confluence_timer += 1
        if time_to_check_confluence(rws, work, settings)
            if !isempty(stacks)
                rws, idxA, i, _ =
                    Automata.rebuild!(idxA, rws, stacks, i, 0, work)
                @assert isempty(stacks)
            end
            stack = check_confluence!(Tuple{W,W}[], rws, idxA, work)
            isempty(stack) && return rws
        end
        j = firstindex(rws.rwrules)

        l = Threads.Atomic{Int}(length(stacks))

        Threads.@sync while j ≤ i
            if are_we_stopping(rws, settings)
                return reduce!(rws, work)
            end

            Threads.@spawn begin
                stack = getstack(stacks, Threads.threadid())
                rj = rws.rwrules[j]
                stack = find_critical_pairs!(stack, idxA, ri, rj, work)
                if ri !== rj
                    stack = find_critical_pairs!(stack, idxA, rj, ri, work)
                end
                Threads.atomic_add!(l, length(stack))
            end
            j += 1
        end

        if length(stacks) - l[] > 0 && time_to_rebuild(rws, stacks, settings)
            rws, idxA, i, j = Automata.rebuild!(idxA, rws, stacks, i, j, work)
            @assert isempty(stack)
        end

        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            s = length(stack)
            settings.update_progress(i, n, s)
        end

        if i == lastindex(rws.rwrules) && !isempty(stack)
            @debug "reached end of rwrules with $(length(stack)) rules on stack"
            rws, idxA, i, _ = Automata.rebuild!(idxA, rws, stack, i, 0, work)
            @assert isempty(stack)
        end
        i += 1
    end
    return rws
end
