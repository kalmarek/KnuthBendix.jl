using PrecompileTools
@setup_workload begin
    @compile_workload begin
        n = 6
        R = ExampleRWS.triangle_237_quotient(n)
        knuthbendix(R)
    end
end
