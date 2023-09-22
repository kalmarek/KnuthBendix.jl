module Benchmark

using CSV
using BenchmarkTools
using DataFrames
using Dates
using KnuthBendix
using ProgressMeter

const KB_DATA = joinpath(@__DIR__, "kb_data")
const RESULTSDIR = joinpath(@__DIR__, "results")
const KBMAG = joinpath(@__DIR__, "..", "deps", "kbmag")

function kbprog(dir = KBMAG)
    prog = joinpath(dir, "usr", "bin", "kbprog")
    if !isfile(prog)
        throw("You need to build kbprog form kbmag gap package")
    end
    return prog
end

include("completion_perf.jl")
include("tools.jl")
include("runners.jl")

function run(f; pathtoresults = RESULTSDIR, results_fname)
    isdir(pathtoresults) || mkpath(pathtoresults)
    results_csv = joinpath(pathtoresults, "$results_fname.csv")
    results = KBPerfMetrics[]

    rws_example_f = rwsfiles(KB_DATA)

    p = Progress(length(rws_example_f), 0.01)
    for rwsname in rws_example_f
        next!(p; showvalues = [(Symbol("current rws"), rwsname)])
        res = f(joinpath(KB_DATA, rwsname))
        isnothing(res) && continue
        push!(results, res)
    end
    finish!(p)
    return CSV.write(results_csv, data_frame(results))
end

end
