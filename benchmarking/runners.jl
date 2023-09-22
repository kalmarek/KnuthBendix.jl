KB_idxA_run_fast(file) = KB_idxA_run(file, false)
KB_idxA_run_all(file) = KB_idxA_run(file, true)

function KB_idxA_run(file, all::Bool)
    @assert isfile(file)
    rwsname = basename(file)

    skiplist = [
        "degen4b", # doesn't finish
        "degen4c", # doesn't finish
        "f27monoid", # doesn't finish
        "verifynilp", # doesn't finish
    ]

    if !all
        append!(skiplist, [
            "f27", # 13 s
            "f27_2gen", # 12 s
            "funny3", # 11s
            "m11", # 22s
        ])
    end

    if rwsname in skiplist
        return nothing
    end
    rws = rwsfromfile(file, method = (rwsname == "a4" ? :string : :ast))

    settings = KnuthBendix.Settings(verbosity = 1)
    elapsed =
        @elapsed knuthbendix(rws, settings; implementation = :index_automaton)
    allocated =
        @allocated knuthbendix(rws, settings; implementation = :index_automaton)
    return KBPerfMetrics(
        algorithm_name = "knuthbendix_idxA",
        problem_name = rwsname,
        threads_used = 1,
        memory_allocated = allocated,
        time_elapsed = elapsed,
        comment = "The default settings of KnuthBendix were used.",
    )
end

function kbmag_run(file)
    @assert isfile(file)
    rwsname = basename(file)

    if rwsname in (
        "degen4c", # too hard for kbmag
        "heinnilp", # ProcessExited(1)
        "f27monoid", # ProcessExited(2): #System is not confluent - halting because new equations are too long.
        "verifynilp", # ProcessExited(1)
    )
        return nothing
    end

    kbprog_cmd = `$(kbprog()) -silent $file`

    caught = false

    elapsed, allocated = try
        clean_kbprog(file)
        elapsed = @elapsed Base.run(kbprog_cmd)
        clean_kbprog(file)
        allocated = @allocated Base.run(kbprog_cmd)
        elapsed, allocated
    catch e
        if e isa InterruptException
            @warn "Recived user interrupt; skipping $rwsname"
            caught = true
        end
        rethrow(e)
    finally
        clean_kbprog(file)
    end
    caught && return nothing

    return KBPerfMetrics(;
        algorithm_name = "kbmag",
        problem_name = rwsname,
        threads_used = 1,
        memory_allocated = allocated,
        time_elapsed = elapsed,
        comment = "Default parameters were used",
    )
end
