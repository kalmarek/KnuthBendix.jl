using PrecompileTools
@setup_workload begin
    @compile_workload begin
        n = 6
        R = ExampleRWS.triangle_237_quotient(n)
        RC = knuthbendix(R)
        M = FPMonoids.FPMonoid(RC)
        collect(M)
    end
end
