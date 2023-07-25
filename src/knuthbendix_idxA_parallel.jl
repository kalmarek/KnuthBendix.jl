using Base.Threads: nthreads, @spawn, threadid
using Base.Iterators: partition, flatten

function kb2idxA_parallel_1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    idxA = IndexAutomaton(rws)
    stacks = Channel{Vector{Tuple{W,W}}}(Inf)
    foreach(_ -> put!(stacks, Vector{Tuple{W,W}}()), 1:nthreads())
    workspace_type = typeof(Workspace(rws, idxA))
    workspaces = Channel{workspace_type}(Inf)
    foreach(_ -> put!(workspaces, Workspace(rws, idxA)), 1:nthreads())
    confluence_workspace = Workspace(rws, idxA)

    i = firstindex(rws.rwrules)
    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]

        confluence_workspace.confluence_timer += 1
        if time_to_check_confluence(rws, confluence_workspace, settings)
            close(stacks)
            collected_stacks = collect(flatten(stacks))
            if !isempty(collected_stacks)
                rws, idxA, i, _ = Automata.rebuild!(
                    idxA,
                    rws,
                    collected_stacks,
                    i,
                    0,
                    confluence_workspace,
                )
                @assert isempty(collected_stacks)
            end
            local_stack =
                check_confluence!(Tuple{W,W}[], rws, idxA, confluence_workspace)
            isempty(local_stack) && return rws
        end

        j = firstindex(rws.rwrules)
        num_found = Threads.Atomic{Int}(0)

        results =
            let tasks_per_thread = 1,  # TODO: This does not work with more tasks because of the stacks
                chunk_size =
                    max(1, i ÷ (tasks_per_thread * Threads.nthreads())),
                data_chunks = partition(1:i, chunk_size)

                stacks = Channel{Vector{Tuple{W,W}}}(Inf)
                foreach(_ -> put!(stacks, Vector{Tuple{W,W}}()), 1:nthreads())

                intermediate_results = map(data_chunks) do index_range
                    @spawn begin
                        stack::Vector{Tuple{W,W}} = take!(stacks)
                        for j in index_range
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
                            Threads.atomic_add!(num_found, length(stack))
                            put!(workspaces, workspace)
                        end
                        put!(stacks, Vector{Tuple{W,W}}())
                        return stack::Vector{Tuple{W,W}}
                    end
                end
                fetch.(intermediate_results)
            end
        
        # TODO: This causes allocations that likely are avoidable by changing functions
        # such as deriverule! or instead by defining a datastructure that allows
        # for e.g. pop!
        collected_stacks = collect(flatten(results))

        if num_found[] > 0 &&
           time_to_rebuild(rws, 1:length(collected_stacks), settings)
            rws, idxA, i, j = Automata.rebuild!(
                idxA,
                rws,
                collected_stacks,
                i,
                j,
                confluence_workspace,
            )
            @assert isempty(collected_stacks)
        end

        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            s = length(collected_stacks)
            settings.update_progress(i, n, s)
        end

        if i == lastindex(rws.rwrules) && !all(isempty.(results))
            @debug "reached end of rwrules with $(length(collected_stacks)) rules on stack"
            rws, idxA, i, _ = Automata.rebuild!(
                idxA,
                rws,
                collected_stacks,
                i,
                0,
                confluence_workspace,
            )
            @assert isempty(collected_stacks)
        end
        i += 1
    end

    close(workspaces)

    return rws
end
