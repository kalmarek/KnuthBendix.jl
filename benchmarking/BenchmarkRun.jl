using CSV
using DataFrames
using Dates

struct BenchmarkRun
    """
        struct BenchmarkRun

    A struct representing a benchmark run with various measured parameters.

    # Fields

    - `datetime::DateTime`: The date and time of the benchmark run.
    - `computer_name::String`: The name of the computer where the benchmark was executed.
    - `algorithm_name::String`: The name of the algorithm being benchmarked.
    - `problem_name::String`: The name of the problem or task being benchmarked.
    - `cpu_name::String`: The name of the CPU used for the benchmark.
    - `threads_enabled::Int`: The total number of threads cores available.
    - `threads_used::Int`: The number of threads used during the benchmark.
    - `total_memory_available::Float64`: The total memory available to the system in bytes.
    - `memory_used::Float64`: The amount of memory used during the benchmark in GiB.
    - `time_elapsed::Float64`: The time taken to complete the benchmark in ns.
    - `comment::String`: Additional comments or notes regarding the benchmark run,
       e.g parameters like stacksize.
    """

    datetime::DateTime
    computer_name::String
    algorithm_name::String
    problem_name::String
    cpu_name::String
    threads_enabled::Int
    threads_used::Int
    total_memory_available::Float64
    memory_used::Int
    time_elapsed::Float64
    comment::String

    function BenchmarkRun(; computer_name::String,
                          algorithm_name::String,
                          problem_name::String,
                          threads_used::Int,
                          memory_used::Int,
                          time_elapsed::Float64,
                          comment::String="")

        datetime = now()
        threads_enabled = Threads.nthreads()
        cpu_name = Sys.cpu_info()[1].model
        total_memory_available = Sys.total_memory() / 1024^3

        return new(datetime,
                   computer_name,
                   algorithm_name,
                   problem_name,
                   cpu_name,
                   threads_enabled,
                   threads_used,
                   total_memory_available,
                   memory_used,
                   time_elapsed,
                   comment)
    end

    function BenchmarkRun(datetime::DateTime,
                          computer_name::String,
                          algorithm_name::String,
                          problem_name::String,
                          cpu_name::String,
                          threads_enabled::Int,
                          threads_used::Int,
                          total_memory_available::Float64,
                          memory_used::Float64,
                          time_elapsed::Float64,
                          comment::String="")

    return new(datetime,
               computer_name,
               algorithm_name,
               problem_name,
               cpu_name,
               threads_enabled,
               threads_used,
               total_memory_available,
               memory_used,
               time_elapsed,
               comment)
    end
end

function get_field_types(struct_type::Type)
    field_types = Vector{Type}()

    for field in fieldnames(struct_type)
        push!(field_types, Base.fieldtype(struct_type, field))
    end

    return field_types
end


function toDataFrame(benchmarkrun::BenchmarkRun)
    fields = fieldnames(typeof(benchmarkrun))
    values = [getfield(benchmarkrun, field) for field in fields]
    return DataFrame((field => [value] for (field, value) in zip(fields, values))...)
end

function append_benchmark_run(filename::AbstractString, benchmarkrun::BenchmarkRun)
    if !isfile(filename)
        CSV.write(filename, toDataFrame(benchmarkrun))
    else
        dataframe = CSV.read(filename,
                             DataFrame,
                             types=get_field_types(typeof(benchmarkrun)))
        append!(dataframe, toDataFrame(benchmarkrun))
        CSV.write(filename, dataframe)
    end
end

