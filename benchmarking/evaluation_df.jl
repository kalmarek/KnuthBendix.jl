using CSV
using DataFrames
using Statistics
using Plots
using StatsPlots

kbmag_csv = joinpath(@__DIR__, "benchmarks_kbmag.csv")
KBidxA_csv = joinpath(@__DIR__, "benchmarks_knuthbendix_idxA.csv")

@assert isfile(kbmag_csv)
@assert isfile(KBidxA_csv)

results = let kbmag_csv = kbmag_csv, KBidxA_csv = KBidxA_csv
    kbmag_df = CSV.read(kbmag_csv, DataFrame)
    KBidxA_df = CSV.read(KBidxA_csv, DataFrame)
    a = select(
        kbmag_df,
        :problem_name,
        :time_elapsed => :time_kbmag,
        copycols = false,
    )
    b = select(
        KBidxA_df,
        :problem_name,
        :time_elapsed => :time_KBidxA,
        copycols = false,
    )
    df = outerjoin(a, b, on = :problem_name)
    df = select(
        df,
        :problem_name => :name,
        Not(:problem_name),
        copycols = false,
    )
    df = select(
        df,
        All(),
        [:time_KBidxA, :time_kbmag] => ByRow(/) => :KBidxA_ratio_kbmag,
        copycols = false,
    )
    df
end

let results = subset(results, :time_KBidxA => x -> .!ismissing.(x) .&& x .> 0.1)
    plt_time = @df results scatter(
        :name,
        [:time_kbmag, :time_KBidxA],
        yaxis = :log,
        labels = ["kbmag" "KBidxA"],
        legend = :topleft,
        xticks = ((1:length(:name)) .- 0.5, :name),
        xrotation = 90,
        showall = true,
    )

    plt_ratio = @df results scatter(
        :name,
        :KBidxA_ratio_kbmag, # :time_KBidxA ./ :time_kbmag
        yaxis = :log,
        label = "KB/kbmag",
        legend = :topleft,
        xticks = ((1:length(:name)) .- 0.5, :name),
        xrotation = 90,
        showall = true,
    )

    plt = plot(
        plt_time,
        plt_ratio,
        layout = (2, 1),
        yminorticks = 10,
        size = (600, 1200),
        margin = (5, :mm),
    )

    savefig(plt, joinpath(@__DIR__, "evaluation.png"))
    plt
end
