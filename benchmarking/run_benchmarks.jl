using Pkg
Pkg.activate(@__DIR__)
using Dates

include(joinpath(@__DIR__, "Benchmark.jl"))
using .Benchmark

now_ = now()
@info "running kbmag and KnuthBendix benchmarks at $(now_)"

kbmag_csv =
    Benchmark.run(Benchmark.kbmag_run, results_fname = "kbmag_test_$(now_)")

KBidxA_csv = Benchmark.run(
    # Benchmark.KB_idxA_run_fast,
    Benchmark.KB_idxA_run_all,
    results_fname = "KB_idxA_test_$(now_)",
)

include(joinpath(@__DIR__, "evaluation_df.jl"))

results = comparison_df(kbmag_csv, KBidxA_csv)
plt = comparison_plot(
    subset(results, :time_KBidxA => x -> .!ismissing.(x) .&& x .> 0.1),
)
# plt = comparison_plot(results)
title!(plt, "$(now_)")
savefig(plt, joinpath(Benchmark.RESULTSDIR, "evaluation_$(now_).png"))
display(plt)
