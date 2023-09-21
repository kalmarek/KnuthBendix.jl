using BenchmarkTools
using Test
include("tools.jl")
include("BenchmarkRun.jl")

const kbprog = joinpath(@__DIR__, "..", "deps", "kbmag", "usr", "bin", "kbprog")
@assert isfile(kbprog)

let kb_data = joinpath(@__DIR__, "..", "kb_data")
    benchmark_path = joinpath(@__DIR__, "kbmag_$(now()).csv")
    results = BenchmarkRun[]
    for rwsname in rwsfiles(kb_data)
        if rwsname in [
            "degen4c", # too hard for kbmag
            "heinnilp", # ProcessExited(1)
            "f27monoid", # ProcessExited(2): #System is not confluent - halting because new equations are too long.
            "verifynilp", # ProcessExited(1)
        ]
            @info "$rwsname: skipping"
            continue
        end

        file = joinpath(kb_data, rwsname)
        @assert isfile(file)

        command = `$kbprog -silent $file`
        @info "$rwsname: running" command
        kb() = run(command)

        clean_kbprog(file)
        elapsed = @elapsed kb()

        clean_kbprog(file)
        allocated = @allocated kb()

        clean_kbprog(file)
        @info "" elapsed allocated
        clean_kbprog(file)

        benchmark_run = BenchmarkRun(;
            algorithm_name = "kbmag",
            problem_name = rwsname,
            threads_used = 1,
            memory_allocated = allocated,
            time_elapsed = elapsed,
            comment = "Default parameters were used",
        )
        push!(results, benchmark_run)
    end
    @info "writing the results to $benchmark_path"
    CSV.write(benchmark_path, data_frame(results))
    nothing
end
