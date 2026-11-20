# Repeat cross-validation of sim.bed (K=4) from a fixed full-data fit, one new CV
# seed per pass, with the fold fits' output either suppressed (Suppressor, as the
# CLI does) or printed normally (redirect it to /dev/null from the shell).
#   julia -t 14,0 --project=<OpenADMIXTURE.jl> cv_loop.jl <quiet::Bool> <first seed> <passes>
using OpenADMIXTURE, SnpArrays, DelimitedFiles, Printf
const OA = OpenADMIXTURE
quiet = parse(Bool, ARGS[1]); seed0 = parse(Int, ARGS[2]); passes = parse(Int, ARGS[3])
crash = "/Users/loic/admixture/validation/stress/crashes/sim_K4_s2109_w1_1794844689"
g = SnpArray("/Users/loic/admixture/validation/data/sim.bed")
q0 = permutedims(readdlm(joinpath(crash, "sim.4.Q")))
p0 = permutedims(readdlm(joinpath(crash, "sim.4.P")))
for s in seed0:(seed0 + passes - 1)
    t = @elapsed err = OA.cv_error(g, 4, q0, p0; folds=5, seed=s, quiet=quiet, Q=3,
                                   n_iter=1000, rtol=1e-7, atol=1e-4)
    @printf(stderr, "PASS seed=%d cv=%.5f %.0fs\n", s, err, t); flush(stderr)
end
