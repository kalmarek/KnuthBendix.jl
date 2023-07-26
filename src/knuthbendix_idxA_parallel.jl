using Base.Threads: nthreads, @spawn, threadid
using Base.Iterators: partition, flatten

function kb2idxA_parallel_1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    idxA = IndexAutomaton(rws)
    tasks_per_thread = 1  # TODO: This currently fails for values greater than 1
    # stacks = Channel{Vector{Tuple{W,W}}}(nthreads())
    # foreach(
    #     _ -> put!(stacks, Vector{Tuple{W,W}}()),
    #     1:nthreads()*tasks_per_thread,
    # )
    workspace_type = typeof(Workspace(rws, idxA))
    workspaces = Channel{workspace_type}(2nthreads())
    foreach(
        _ -> put!(workspaces, Workspace(rws, idxA)),
        1:2nthreads()*tasks_per_thread,
    )
    confluence_workspace = Workspace(rws, idxA)

    i = firstindex(rws.rwrules)
    lck = Threads.SpinLock()

    stack = Vector{Tuple{W,W}}()
    while i ≤ lastindex(rws.rwrules)
        ri = rws.rwrules[i]

        confluence_workspace.confluence_timer += 1
        if time_to_check_confluence(rws, confluence_workspace, settings)
            if !isempty(stack)
                rws, idxA, i, _ = Automata.rebuild!(
                    idxA,
                    rws,
                    stack,
                    i,
                    0,
                    confluence_workspace,
                )
                @assert isempty(stack)
            end
            stack = check_confluence!(stack, rws, idxA, confluence_workspace)
            isempty(stack) && return rws
        end

        j = firstindex(rws.rwrules)
        num_found = 0

        stack =
            let chunk_size =
                    max(50, i ÷ (tasks_per_thread * Threads.nthreads())),
                data_chunks = partition(1:i, chunk_size)

                intermediate_results = map(data_chunks) do index_range
                    @spawn begin
                        local_stack = Vector{Tuple{W,W}}()
                        workspace = Workspace(rws, idxA)
                        # workspace = take!(workspaces)
                        for j in index_range
                            rj = rws.rwrules[j]
                            local_stack = find_critical_pairs!(
                                local_stack,
                                idxA,
                                ri,
                                rj,
                                workspace,
                            )
                            if ri !== rj
                                local_stack = find_critical_pairs!(
                                    local_stack,
                                    idxA,
                                    rj,
                                    ri,
                                    workspace,
                                )
                            end
                            # Threads.atomic_add!(num_found, length(local_stack))
                            lock(lck) do
                                return num_found += length(local_stack)
                            end
                        end
                        # put!(workspaces, workspace)
                        # put!(stacks, Vector{Tuple{W,W}}())
                        return local_stack::Vector{Tuple{W,W}}
                    end
                end
                # @info intermediate_results
                stacks = fetch.(intermediate_results)
                # @info length.(stacks)
                append!(stack, stacks...)
            end

        # TODO: This causes allocations that likely are avoidable by changing functions
        # such as deriverule! or instead by defining a datastructure that allows
        # for e.g. pop!

        if num_found[] > 0 && time_to_rebuild(rws, stack, settings)
            rws, idxA, i, j =
                Automata.rebuild!(idxA, rws, stack, i, j, confluence_workspace)
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

    close(workspaces)

    return rws
end
