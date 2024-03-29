"""
    struct KBPerfMetrics

A struct storing performance metrics for a particular run of Knuth-Bendix completion.

# Fields

- `datetime::DateTime`: The date and time of the benchmark run.
- `computer_name::String`: The name of the computer where the benchmark was executed.
- `algorithm_name::String`: The name of the algorithm being benchmarked.
- `problem_name::String`: The name of the problem or task being benchmarked.
- `cpu_name::String`: The name of the CPU used for the benchmark.
- `threads_enabled::Int`: The total number of threads cores available.
- `threads_used::Int`: The number of threads used during the benchmark.
- `total_memory_available::Float64`: The total memory available to the system in bytes.
- `memory_allocated::Float64`: The amount of memory used during the benchmark in GiB.
- `time_elapsed::Float64`: The time taken to complete the benchmark in ns.
- `comment::String`: Additional comments or notes regarding the benchmark run,
e.g parameters like stacksize.
"""

struct KBPerfMetrics
    datetime::DateTime
    computer_name::String
    algorithm_name::String
    problem_name::String
    cpu_name::String
    threads_enabled::Int
    threads_used::Int
    total_memory_available::Float64
    memory_allocated::Int
    time_elapsed::Float64
    comment::String

    function KBPerfMetrics(;
        computer_name::String = string(readchomp(`hostname`)),
        algorithm_name::String,
        problem_name::String,
        threads_used::Int,
        memory_allocated::Int,
        time_elapsed::Float64,
        comment::String = "",
    )
        datetime = now()
        threads_enabled = Threads.nthreads()
        cpu_name = Sys.cpu_info()[1].model
        total_memory_available = Sys.total_memory() / 1024^3

        return new(
            datetime,
            computer_name,
            algorithm_name,
            problem_name,
            cpu_name,
            threads_enabled,
            threads_used,
            total_memory_available,
            memory_allocated,
            time_elapsed,
            comment,
        )
    end

    function KBPerfMetrics(
        datetime::DateTime,
        computer_name::String,
        algorithm_name::String,
        problem_name::String,
        cpu_name::String,
        threads_enabled::Int,
        threads_used::Int,
        total_memory_available::Float64,
        memory_allocated::Float64,
        time_elapsed::Float64,
        comment::String = "",
    )
        return new(
            datetime,
            computer_name,
            algorithm_name,
            problem_name,
            cpu_name,
            threads_enabled,
            threads_used,
            total_memory_available,
            memory_allocated,
            time_elapsed,
            comment,
        )
    end
end

function data_frame(res::AbstractVector{<:KBPerfMetrics})
    B = eltype(res)
    df = DataFrame((fn => fieldtype(B, fn)[] for fn in fieldnames(B))...)

    function __tuple(t::T) where {T}
        return tuple((getfield(t, fn) for fn in fieldnames(T))...)
    end

    for elt in res
        push!(df, __tuple(elt))
    end
    return df
end

function append_benchmark_run(
    filename::AbstractString,
    benchmarkrun::KBPerfMetrics,
)
    if !isfile(filename)
        CSV.write(filename, toDataFrame(benchmarkrun))
    else
        dataframe = CSV.read(
            filename,
            DataFrame,
            types = Base.fieldtypes(typeof(benchmarkrun)),
        )
        append!(dataframe, toDataFrame(benchmarkrun))
        CSV.write(filename, dataframe)
    end
end
