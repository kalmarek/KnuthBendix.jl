using CSV
using DataFrames
using Statistics
using Plots

file1 = joinpath(@__DIR__, "benchmarks_kbmag.csv")
file2 = joinpath(@__DIR__, "benchmarks_knuthbendix_idxA.csv")

df1 = CSV.read(file1, DataFrame)
df2 = CSV.read(file2, DataFrame)

exclude = ["l32ext"]
common_problems = setdiff(intersect(df1.problem_name, df2.problem_name), Set(exclude))
time_elapsed_1 = [(row.problem_name, row.time_elapsed) for row in eachrow(df1) if row.problem_name in common_problems]
time_elapsed_2 = [(row.problem_name, row.time_elapsed) for row in eachrow(df2) if row.problem_name in common_problems]
ratios = [time_2[2] / time_1[2] for (time_1, time_2) in zip(time_elapsed_1, time_elapsed_2)]
x = [time[1] for time in time_elapsed_1]

timings_plot = scatter(time_elapsed_1, label="kbmag", xrotation=90, showall=true)
scatter!(time_elapsed_2, label="idxA", xrotation=90, showall=true)
xticks!(collect(1:length(common_problems)), common_problems, rotation=90, showall=true)
xlabel!("Problem Name")
ylabel!("Time Elapsed (s)")
title!("Timings for Common Problem")

ratios_plot = scatter(x, ratios, label="idxA / kbmag", xrotation=90, showall=true)
xticks!(collect(1:length(common_problems)), common_problems, rotation=90, showall=true)
xlabel!("Problem Name")
ylabel!("Ratio")
title!("Ratios of Time Elapsed")

@info collect(zip(common_problems, ratios))
@info "Average ratio: " mean(ratios)
plot(timings_plot, ratios_plot, layout=(2, 1), yminorticks=10, size=(600, 1200))