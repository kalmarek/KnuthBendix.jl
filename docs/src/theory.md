# Monoids and the word problem

This package implements Knuth-Bendix completion of a rewriting system derived
from a presentation of a monoid.

## Monoids and their presentations

In general one starts with an alphabet $\mathcal{A}$, creates a free monoid
$\mathcal{A}^*$ (the set of all words over the alphabet, with concatenation)
and then forms a quotient of $\mathcal{A}^*$ by a _congruence_
$$R ⊂ \mathcal{A}^*\times \mathcal{A}^*$$
Recall that a _congruence_ on a monoid is an equivalence relation whose
equivalence classes are preserved by monoid multiplication.
Under this assumption the quotient inherits the structure of a
_quotient monoid_ $Q = \mathcal{A}^*/R$.

In the case of a congruence on a group, the equivalence class of the (group)
identity $[1]$ is a normal subgroup, and each equivalence class of $R$ is a
shift of it (these are cosets). As it is well known, the quotient $Q$ inherits
the group structure. In monoids, however, congruences are not necessarily
determined by $[1]$ only.

One usually does not have the full set of equivalence classes at their disposal,
but only a small set of pairs in relation that _generate_ the congruence. This
is traditionally written as a _monoid presentation_
$\langle \mathcal{A} \mid R \rangle$, e.g.:
$$M = \langle x, X, y \mid x\cdot X = X\cdot x =\varepsilon, xy = yx \rangle.$$
Here by $x\cdot X = \varepsilon$ we mean that $R$ contains the pair
$(x\cdot X, \varepsilon)$ (the latter denoting the trivial element of
$\mathcal{A}^*$, i.e. the empty word) and $R$ is the smallest congruence on
$\mathcal{A}^*$ which contains the pairs indicated by the equations.

## Word Problem

One of the most natural problems in this setting is to determine when do two
words in $\mathcal{A}^*$ represent the same element of $M$, i.e. belong to the
same congruence class of $R$. This is the famous (unsolvable in general) word
problem:

!!! note "Word Problem"
    When do words $v$ and $w$ from $\mathcal{A}^*$ represent the same
    element of $M$?

Is it unsolvable though? Here is a somehow trivial solution of the word problem
using the axiom of choice:

!!! tip "Solution using AC"
    By the axiom of choice we could pick a distinguished element from
    every congruence class of $R$. Given $v$ let $[v] \subset \mathcal{A}^*$
    denote its congruence class and $v_0$ the corresponding distinguished
    element. Similarly we could find the element $w_0 \in [w]$ in the
    congruence class of $w$. The words represent the same element if and only
    if $v_0 = w_0$.

The _unsolvability_ of the Word Problem is rather caused by the very specific model
of computations (i.e. Turing machine) rather than unsolvability in the sense of
providing a solution using broadly accepted mathematics.

## Normal forms and rewriting systems

The choice of a distinguished element from each congruence class is sometimes
referred to as the choice of a _normal form_ (or _canonical form_) for $R$.
If we could compute the normal form without referring to axiom of choice, we
could solve the word problem.

A particular approach to normal forms is given by rewriting systems.
To begin we need not only the set of pairs but also a _rewriting ordering_
i.e. a bi-invariant well-ordering of $\mathcal{A}^*$. For the first reading
you may think of ordering words by length and then by lexicographical order -
it is a valid example of rewriting ordering. Such set of pairs and the order
is called the rewriting system $\mathcal{R}(R, <)$.
One usually thinks in this context of element of $R$ as rewriting equations
$p \to q$, where $p$ is always greater than $q$ according to the order.

The process of rewriting then follows by finding in $w = w_n$ any word $p$
(as a subword) which is a left hand side of a rule $p \to q \in \mathcal{R}$
and replacing it with $q$ to obtain $w_{n-1}$. By the bi-invariance
this process forms a decreasing sequence of words

```math
w=w_n > w_{n-1} > \cdots > w_1 > w_0
```

which must end after a finite number of rewrites (since $<$ is a well-ordering).
Since applying rewriting rules doesn't change the congruence class $w_0$ is
congruent to the initial $w$. Then we could proclaim $w_0$ to be the normal
form for $w$. Unfortunately things are not so simple.
The process of rewriting depends heavily on the order in which rules were used
and on the positions where the matches of the left hand sides were found
(note also that matches may overlap).

A rewriting system for which those choices don't matter is called **confluent**.
Confluence of $\mathcal{R}$ means that effectively $w_0$ is the **least element**
in the congruence class, which makes it a perfect choice for normal form!

The main purpose of the Knuth-Bendix completion is to bring any
rewriting system $\mathcal{R}$ to confluence (see the next chapter).
In other words the Knuth-Bendix completion transforms the initial set of
pairs generating congruence $R$ (and an order $<$ on $\mathcal{A}^*$) into a
rewriting system $\mathcal{R}$ that computes the normal form in a
constructive, deterministic fashion.
