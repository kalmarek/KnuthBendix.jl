using KnuthBendix
using BenchmarkTools
using Test
include("BenchmarkRun.jl")

function rwsfromfile(filepath)
    filecontent = String(read(filepath))
    return RewritingSystem(KnuthBendix.parse_kbmag(filecontent, method = :string))
end

# let kb_data = joinpath(@__DIR__, "..", "..", "kb_data")
#     for filename in readdir(kb_data)
#         @info filename
#         if filename in ("degen4c", "f27monoid", "heinnilp", "verifynilp")
#             @info "skipping"
#             continue
#         end
# 
#         file = joinpath(kb_data, filename)
#         R = rwsfromfile(file)
#         kb() = knuthbendix(R, implementation=:index_automaton)
#         elapsed = @elapsed kb()
#         allocated = @allocated kb()
#         benchmark_run = BenchmarkRun(computer_name="Robin's Desktop",
#                                      algorithm_name="knuthbendix_idxA",
#                                      problem_name=filename,
#                                      threads_used=1,
#                                      memory_used=allocated,
#                                      time_elapsed=elapsed,
#                                      comment="Default parameters were used")
#         benchmark_path = joinpath(@__DIR__, "benchmarks_knuthbendix_idxA.csv")
#         append_benchmark_run(benchmark_path, benchmark_run)
#     end
# end
let kb_data = joinpath(@__DIR__, "..", "..", "kb_data")
    failed_examples = [
        "degen4b", # too hard
        "degen4c", # too hard
        "e8", # 3.229832 seconds (106.80 k allocations: 14.409 MiB)
        "f27", # 46.193392 seconds (217.63 k allocations: 44.759 MiB)
        "f27_2gen", # 21.226852 seconds (183.67 k allocations: 24.295 MiB)
        "f27monoid", # ordering := "recursive",
        "freenilpc3", # ordering := "recursive",
        "funny3", # 10.782928 seconds (176.58 k allocations: 22.722 MiB, 1.02% gc time)
        "heinnilp", # ordering := "recursive",
        "m11", # 27.482646 seconds (256.87 k allocations: 31.985 MiB, 0.04% gc time)
        "nilp2", # ordering := "recursive",
        "nonhopf", # ordering := "recursive",
        "verifynilp", # ordering := "recursive",
    ]

    for filename in readdir(kb_data)
        rwsgap = let file_content = String(read(joinpath(kb_data, filename)))
            method = (filename == "a4" ? :string : :ast)
            rws = KnuthBendix.parse_kbmag(file_content, method = method)
            rws
        end

        # sett = KnuthBendix.Settings(
        #     max_rules = 2000,
        #     verbosity = 1,
        #     stack_size = 50,
        # )

        @info filename
        filename in failed_examples && continue
        R = RewritingSystem(rwsgap)
        kb() = knuthbendix(R, implementation=:index_automaton)
        elapsed = @elapsed kb()
        allocated = @allocated kb()
        benchmark_run = BenchmarkRun(computer_name="Robin's Desktop",
                                     algorithm_name="knuthbendix_idxA",
                                     problem_name=filename,
                                     threads_used=1,
                                     memory_used=allocated,
                                     time_elapsed=elapsed,
                                     comment="Default parameters were used")
        benchmark_path = joinpath(@__DIR__, "benchmarks_knuthbendix_idxA.csv")
        append_benchmark_run(benchmark_path, benchmark_run)
    end
end