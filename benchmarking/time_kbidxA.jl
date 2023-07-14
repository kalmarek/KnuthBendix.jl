using KnuthBendix
using BenchmarkTools
using Test
include("BenchmarkRun.jl")
include("tools.jl")
include("kbmag_defaults.jl")


let kb_data = joinpath(@__DIR__, "..", "kb_data")
    hard_examples = [
        "237",
        "237_8",
        "e8",
        "f27",
        "f27_2gen",
        "freenilpc3",
        "funny3",
        "l32ext",
        "m11",
        "heinnilp",
    ]

    for filename in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, filename)))
            method = (filename == "a4" ? :string : :ast)
            rws = KnuthBendix.parse_kbmag(file_content, method = method)
            rws
        end

        @info filename
        filename ∉ hard_examples && continue
        R = RewritingSystem(rwsgap)
        kb() = knuthbendix(R, kbmag_settings; implementation=:index_automaton)
        elapsed = @elapsed kb()
        allocated = @allocated kb()
        benchmark_run = BenchmarkRun(computer_name="Robin's Desktop",
                                     algorithm_name="knuthbendix_idxA",
                                     problem_name=filename,
                                     threads_used=1,
                                     memory_used=allocated,
                                     time_elapsed=elapsed,
                                     comment="The default settings of kbmag were used")
        benchmark_path = joinpath(@__DIR__, "benchmarks_knuthbendix_idxA_kbmagsettings.csv")
        append_benchmark_run(benchmark_path, benchmark_run)
    end
end