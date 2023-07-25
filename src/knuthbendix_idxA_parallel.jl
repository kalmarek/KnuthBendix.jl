using Base.Threads: nthreads, @spawn, threadid

struct RuleStacks{W}
    stacks::Vector{Vector{Tuple{W,W}}}
end

function RuleStacks{W}(n::Int) where {W}
    return RuleStacks{W}([Vector{Tuple{W,W}}() for _ in 1:n])
end

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

function Base.push!(stacks::RuleStacks{W}, s::Tuple{W,W}) where {W}
    return push!(last(stacks, s))
end
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

function kb2idxA_parallel_1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    idxA = IndexAutomaton(rws)
    stacks = Channel{Vector{Tuple{W,W}}}(nthreads())
    foreach(_ -> put!(stacks, Vector{Tuple{W,W}}()), 1:nthreads())
    workspace_type = typeof(Workspace(rws, idxA))
    workspaces = Channel{workspace_type}(nthreads())
    foreach(_ -> put!(workspaces, Workspace(rws, idxA)), 1:nthreads())
    confluence_workspace = Workspace(rws, idxA)

    i = firstindex(rws.rwrules)
    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]

        confluence_workspace.confluence_timer += 1
        if time_to_check_confluence(rws, confluence_workspace, settings)
            if !isempty(stacks)
                rws, idxA, i, _ = Automata.rebuild!(
                    idxA,
                    rws,
                    stacks,
                    i,
                    0,
                    confluence_workspace,
                )
                @assert isempty(stacks)
            end
            stack =
                check_confluence!(Tuple{W,W}[], rws, idxA, confluence_workspace)
            isempty(stack) && return rws
        end
        j = firstindex(rws.rwrules)

        @info "Hi, got here!"
        l = Threads.Atomic{Int}(length(stacks))

        results =
            let tasks_per_thread = 1,  # TODO: This does not work with more tasks because of the stacks
                chunk_size =
                    max(1, i ÷ (tasks_per_thread * Threads.nthreads())),
                data_chunks = partition(1:i, chunk_size)

                tasks = map(data_chunks) do index_range
                    Threads.@spawn begin
                        for j in index_range
                            @info j, threadid()
                            stack = take!(stacks)
                            workspace = take!(workspaces)
                            rj = rws.rwrules[j]
                            stack = find_critical_pairs!(
                                stack,
                                idxA,
                                ri,
                                rj,
                                workspace,
                            )
                            if ri !== rj
                                stack = find_critical_pairs!(
                                    stack,
                                    idxA,
                                    rj,
                                    ri,
                                    workspace,
                                )
                            end
                            Threads.atomic_add!(l, length(stack))
                        end
                        put!(stacks, Vector{Tuple{W,W}}())
                        put!(workspaces, Workspace(rws, idxA))
                        return stack
                    end
                end
                fetch.(tasks)
            end

        @info results

        Threads.@sync while j ≤ i
            if are_we_stopping(rws, settings)
                return reduce!(rws, confluence_workspace)
            end

            Threads.@spawn begin
                stack = getstack(stacks, Threads.threadid())
                rj = rws.rwrules[j]
                stack = find_critical_pairs!(
                    stack,
                    idxA,
                    ri,
                    rj,
                    confluence_workspace,
                )
                if ri !== rj
                    stack = find_critical_pairs!(
                        stack,
                        idxA,
                        rj,
                        ri,
                        confluence_workspace,
                    )
                end
                Threads.atomic_add!(l, length(stack))
            end
            # put local work in global work queue
            j += 1
        end

        if length(stacks) - l[] > 0 && time_to_rebuild(rws, stacks, settings)
            rws, idxA, i, j =
                Automata.rebuild!(idxA, rws, stacks, i, j, confluence_workspace)
            @assert isempty(stack)
        end

        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            s = length(stack)
            settings.update_progress(i, n, s)
        end

        if i == lastindex(rws.rwrules) && !isempty(stack)
            @debug "reached end of rwrules with $(length(stack)) rules on stack"
            rws, idxA, i, _ =
                Automata.rebuild!(idxA, rws, stack, i, 0, confluence_workspace)
            @assert isempty(stack)
        end
        i += 1
    end
    return rws
end
