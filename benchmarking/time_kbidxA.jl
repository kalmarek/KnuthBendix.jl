using KnuthBendix
using BenchmarkTools
using Test
include("BenchmarkRun.jl")
include("tools.jl")
include("kbmag_defaults.jl")

let kb_data = joinpath(@__DIR__, "..", "kb_data")
    benchmark_path = joinpath(@__DIR__, "idxA_$(now()).csv")
    results = BenchmarkRun[]
    for rwsname in rwsfiles(kb_data)
        if rwsname in [
            # "237",
            # "237_8", # 2s
            "degen4b", # doesn't finish
            "degen4c", # doesn't finish
            # "e8", # 1s
            "f27", # 13 s
            "f27_2gen", # 12 s
            "f27monoid", # doesn't finish
            # "freenilpc3",
            "funny3", # 11s
            # "heinnilp", # 3.5s
            # "l32ext", # 2s
            "m11", # 22s
            "verifynilp", # doesn't finish
        ]
            @info "$rwsname: skipping"
            continue
        end

        file = joinpath(kb_data, rwsname)
        @assert isfile(file)

        rws = rwsfromfile(file, method = (rwsname == "a4" ? :string : :ast))
        settings = KnuthBendix.Settings(verbosity = 1)
        @info "$rwsname: running"
        kb() = knuthbendix(rws, settings; implementation = :index_automaton)

        elapsed = @elapsed kb()
        allocated = @allocated kb()
        @info "" elapsed allocated
        benchmark_run = BenchmarkRun(
            algorithm_name = "knuthbendix_idxA",
            problem_name = rwsname,
            threads_used = 1,
            memory_allocated = allocated,
            time_elapsed = elapsed,
            comment = "The default settings of KnuthBendix were used.",
        )
        push!(results, benchmark_run)
    end
    @info "writing the results to $benchmark_path"
    CSV.write(benchmark_path, data_frame(results))
    nothing
end
