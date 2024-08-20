using BenchmarkTools
using KnuthBendix
import KnuthBendix as KB

kbmag_ex_dir =
    joinpath(dirname(dirname(pathof(KnuthBendix))), "benchmark/kb_data")
@assert isdir(kbmag_ex_dir)

const SUITE = BenchmarkGroup()
problems = (
    "237_8",
    "degen4b",
    "e8",
    "f27",
    "f27_2gen",
    "f27monoid",
    "funny3",
    "heinnilp",
    "l32ext",
    "m11",
    "verifynilp",
)

options = Dict([
    "237_8" => (reduce_delay = 500,),
    "degen4b" => (max_length_lhs = 20,),
    "e8" => (confluence_delay = 100,),
    "f27" => (reduce_delay = 500,),
    "f27_2gen" => (reduce_delay = 500,),
    "f27monoid" =>
        (reduce_delay = 500, max_length_lhs = 30, max_length_rhs = 30),
    # kb_data file sets max_length to to [15, 15];
    # since a^30 → a is a rule kbmag fails on thi example
    "funny3" => (reduce_delay = 500,),
    "heinnilp" => (reduce_delay = 500,),
])

SUITE["KBIndex"] = BenchmarkGroup()
SUITE["KBPrefix"] = BenchmarkGroup()

rws = Dict()

for fn in problems
    rwsgap = let file_content = String(read(joinpath(kbmag_ex_dir, fn)))
        KB.parse_kbmag(file_content)
    end
    sett_idx = KB.Settings(KB.KBIndex(), rwsgap; get(options, fn, (;))...)
    sett_pfx = KB.Settings(KB.KBPrefix(), rwsgap; get(options, fn, (;))...)
    sett_idx.max_rules = sett_pfx.max_rules = 1 << 15

    rws[fn] = (idx = sett_idx, pfx = sett_pfx, rws = KB.RewritingSystem(rwsgap))

    SUITE["KBPrefix"]["$fn"] = @benchmarkable KB.knuthbendix(sett, R) setup =
        (sett = rws[$fn].pfx; R = rws[$fn].rws) seconds = 2.0
    SUITE["KBIndex"]["$fn"] = @benchmarkable KB.knuthbendix(sett, R) setup =
        (sett = rws[$fn].idx; R = rws[$fn].rws) seconds = 2.0
end

# tune!(SUITE)
