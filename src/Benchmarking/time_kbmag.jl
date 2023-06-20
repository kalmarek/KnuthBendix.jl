using BenchmarkTools
using Test
include("BenchmarkRun.jl")

kbprog = joinpath(@__DIR__, "..", "..", "deps", "kbmag", "usr", "bin", "kbprog")
@assert isfile(kbprog)

function clean_kbprog(file)
    for fn in ("$file.kbprog", "$file.kbprog.ec", "$file.reduce")
        isfile(fn) && rm(fn)
    end
end

kb_data = joinpath(@__DIR__, "..", "..", "kb_data")
@assert isdir(kb_data)
for fn in readdir(kb_data)
    if endswith(fn, "kbprog") || endswith(fn, "ec") || endswith(fn, "reduce")
        continue
    end
    @info fn
    if fn in ("degen4c", "f27monoid", "heinnilp", "verifynilp")
        @info "skipping"
        continue
    end

    file = joinpath(kb_data, fn)
    @assert isfile(file)
    clean_kbprog(file)
    command = `$kbprog $file`
    elapsed = @elapsed run(command)
    allocated = @allocated run(command)
    min_trial = minimum(elapsed)
    benchmark_run = BenchmarkRun(computer_name="Robin's Desktop",
                                 algorithm_name="kbmag",
                                 problem_name=fn,
                                 threads_used=1,
                                 memory_used=allocated,
                                 time_elapsed=elapsed,
                                 comment="Default parameters were used")
    benchmark_path = joinpath(@__DIR__, "benchmarks.csv")
    append_benchmark_run(benchmark_path, benchmark_run)
    clean_kbprog(file)
end