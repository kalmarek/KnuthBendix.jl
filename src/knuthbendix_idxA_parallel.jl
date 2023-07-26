using Base.Threads: nthreads, @spawn, threadid
using Base.Iterators: partition, flatten

function kb2idxA_parallel_1!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    idxA = IndexAutomaton(rws)
    tasks_per_thread = 1

    confl_workspace = Workspace(rws, idxA)
    workspace_type = typeof(confl_workspace)
    workspaces = Channel{workspace_type}(2nthreads())
    for _ in 1:2nthreads()*tasks_per_thread
        w = Workspace(rws, idxA)
        put!(workspaces, w)
    end

    stack = Vector{Tuple{W,W}}()

    i = firstindex(rws.rwrules)
    while i ≤ lastindex(rws.rwrules)
        @info i
        ri = rws.rwrules[i]

        confl_workspace.confluence_timer += 1
        if time_to_check_confluence(rws, confl_workspace, settings)
            if !isempty(stack)
                rws, idxA, i, _ =
                    Automata.rebuild!(idxA, rws, stack, i, 0, confl_workspace)
                @assert isempty(stack)
            end
            stack = check_confluence!(stack, rws, idxA, confl_workspace)
            isempty(stack) && return rws
        end

        begin
            chunk_size = max(50, i ÷ (tasks_per_thread * Threads.nthreads()))
            chunks = partition(1:i, chunk_size)
            local_stacks = map(chunks) do index_range
                @spawn begin
                    tl_stack = Vector{Tuple{W,W}}()
                    # workspace = Workspace(rws, idxA)
                    workspace = take!(workspaces)
                    for j in index_range
                        rj = rws.rwrules[j]
                        find_critical_pairs!(tl_stack, idxA, ri, rj, workspace)
                        if ri !== rj
                            find_critical_pairs!(tl_stack, idxA, rj, ri, workspace)
                        end
                    end
                    put!(workspaces, workspace)
                    return tl_stack::Vector{Tuple{W,W}}
                end
            end

            stacks = fetch.(local_stacks)
        end
        # @info length.(stacks)
        append!(stack, stacks...)

        if length(stack) > 0 && time_to_rebuild(rws, stack, settings)
            wrkspce = take!(workspaces)
            @time rws, idxA, i, j =
                Automata.rebuild!(idxA, rws, stack, i, 0, wrkspce)
            @assert isempty(stack)
            put!(workspaces, wrkspce)
        end

        if settings.verbosity > 0
            n = count(isactive, rws.rwrules)
            s = length(stack)
            settings.update_progress(i, n, s)
        end

        if i == lastindex(rws.rwrules) && !isempty(stack)
            @info "reached end of rwrules with $(length(stack)) rules on stack"
            wrkspce = take!(workspaces)
            rws, idxA, i, _ = Automata.rebuild!(idxA, rws, stack, i, 0, wrkspce)
            @assert isempty(stack)
            put!(workspaces, wrkspce)
        end
        i += 1
    end

    close(workspaces)

    return rws
end
