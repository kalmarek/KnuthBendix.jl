# Example rewriting systems

`KnuthBendix.jl` contains an internal module `ExampleRWS` which stores various rewriting systems used mostly for testing purposes.

```@meta
CurrentModule = KnuthBendix
```

## `ExampleRWS` submodule

```@docs
ExampleRWS.ZxZ
ExampleRWS.ZxZ_nonterminating
ExampleRWS.triangle
ExampleRWS.Sims_Example_5_4
ExampleRWS.Heisenberg
ExampleRWS.Sims_Example_5_5
ExampleRWS.Sims_Example_5_5_recursive
ExampleRWS.triangle_237_quotient
ExampleRWS.Hurwitz4
ExampleRWS.Hurwitz8
ExampleRWS.π₁Surface_recursive
ExampleRWS.π₁Surface
ExampleRWS.Coxeter_cube
ExampleRWS.Baumslag_Solitar
ExampleRWS.Fibonacci2
ExampleRWS.Fibonacci2_recursive
```

## `LenLex` confluent rewriting system for ``\pi_1(\Sigma_g)``

Maybe the only truly mathematically interesting rewriting system contained in `ExampleRWS` is the length-then-lexicographical ordering for the surface groups (i.e. the the fundamental group of orientable surface) which does not seem to be known in the mathematical literature. The author found it by accident while trying to play around and trying to force Dehn-style algorithms to produce something resembling normal forms.

!!! tip "Theorem"
    Let ``\pi_1(\Sigma_g) = \langle a_1,\ldots, a_g, b_1, \ldots, b_g \mid \prod_{i=1}^g a_i^{-1}b_i^{-1}a_i b_i = 1 \rangle`` be the presentation of the fundamental group of ``\Sigma_g``, the orientable surface of genus ``g``. Then the rewriting system consisting of the following ``4g`` pairs

    ```math
    \begin{aligned}
    (a_1^{-1} b_1^{-1}a_1 b_1\cdots a_g^{-1}b_g^{-1}a_g b_g \quad&,\quad 1)\\
    (b_1^{-1}a_1 b_1\cdots a_g^{-1}b_g^{-1}a_g b_g \quad&,\quad a_1)\\
    (a_1 b_1\cdots a_g^{-1}b_g^{-1}a_g b_g \quad&,\quad b_1 a_1)\\
    \vdots\\
    (a_g b_g \quad&,\quad b_g a_g b_{g-1}^{-1} a_{g-1}^{-1} \cdots b_1^{-1} a_1^{-1} b_1 a_1)\\
    (b_g \quad&,\quad a_g^{-1} b_g a_g b_{g-1}^{-1} a_{g-1}^{-1} \cdots b_1^{-1} a_1^{-1} b_1 a_1)\\
    \end{aligned}
    ```

    ordered by length-then-lexicographical ordering induced by

    $$a_1 < a_1^{-1} < a_2 < a_2^{-1} < \cdots < a_g^{-1} < b_1 < b_1^{-1} < \cdots b_g < b_g^{-1}$$

    is reduced and confluent.
