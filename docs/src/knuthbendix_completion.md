# Confluence and the Knuth-Bendix completion

Confluence is a notion that describes in a formal way the independence of the
result of the rewriting procedure (w.r.t. $\mathcal{R}$) on particular choices
made in the process (without specifying any algorithm!). In colloquial form it
goes like this: whenever the rewrite paths of any word $w$ diverge, there is a
common point later where they agree again. In more formal way

!!! info "Confluence"
    We say that a rewriting system $\mathcal{R}$ is **confulent** if for every
    word $w \in \mathcal{A}^*$ and two rewrites $p_1, p_2 \in \mathcal{A}^*$ of
    $w$ there exist a common rewrite $q \in \mathcal{A}^*$ for both of them.

Let us denote by $w \xrightarrow{}_{\mathcal{R}} p$ that $p$ is the result of
applying a **single** rewriting rule from $\mathcal{R}$ **once** to $w$, and
by $w \xrightarrow{*}_{\mathcal{R}} p$ that $p$ is the result of rewriting
of $w$ with any number of rules from $\mathcal{R}$. Confluence can be
succintly phrased as

```math
\forall{w} \left(\;
(p_1 {\,}_{\mathcal{R}}{\xleftarrow{*}}\; w \xrightarrow{*}_{\mathcal{R}} p_2)
\implies \exists q \;
p_1 \xrightarrow{*}_{\mathcal{R}} q {\,}_{\mathcal{R}}{\xleftarrow{*}}\; p_2\right).
```

## Local confluence and suffix-prefix words

It turns out that confluence is equivalent to **local confluence**. What does
_local_ mean? That we allow only a single rewrite by a rule of $\mathcal{R}$ to
arrive at $p_1$ or $p_2$ ($q$ can be still arrived at by arbitrary number of
rewrties):

```math
\forall{w} \left(\;
(p_1 {\,}_{\mathcal{R}}{\xleftarrow{}}\; w \xrightarrow{}_{\mathcal{R}} p_2)
\implies \exists q \;
p_1 \xrightarrow{*}_{\mathcal{R}} q {\,}_{\mathcal{R}}{\xleftarrow{*}}\; p_2\right).
```

Local confluence seems a much weaker condition than normal confluence and yet
they are equivalent and the former is **much easier** to check!
While the set of words for which local confluence fails may be infinite,
the shortest among them, i.e. the ones where local confluence holds for all
proper subwords, can be characterized in terms of $\mathcal{R}$ explicitly!
They are formed from pairs of rules where a suffix of the left-hand-side of
one rule is a prefix of the left-hand-side of the other. Suppose we have two
rules $p_i \to q_i$ ($i = 1,2$) and that $p_1 = a\cdot b$
and $p_2 = b\cdot c$ ($b \neq \varepsilon$), we can rewrite
$w = a\cdot b \cdot c$

```math
q_1 \cdot c {\,}_{\mathcal{R}}{\xleftarrow{}}\;
p_1 \cdot c = w = a\cdot p_2
\xrightarrow{}_{\mathcal{R}} A\cdot q_2
```

in two (potentially) different ways.
If we can show that none of the candidates fails local confluence the rewriting
system $\mathcal{R}$ is confluent and hence can be used to solve the word problem!

Note, however, that as we check a pair of rules for failure to local confluence,
new rewriting rules are often discovered and added to $\mathcal{R}$ hence new
additional pairs of rules need to be checked and the whole process becomes
potentially infinite.

## Knuth Bendix completion -- an example

Let us work out an example. We begin with alphabet $\mathcal{A} = \{a, A, b\}$
ordered by the length-then-lexicographical order on $\mathcal{A}^*$ defined by
$a < A < b$.

Here are our generating pairs for the congruence:

> $R = \{(aA, \varepsilon), (Aa, \varepsilon), (bbb, \varepsilon), (ab, ba)\}.$

We note that in the last pair we have $ab < ba$, so we will need to reverse the
pair while the initial rewriting system $\mathcal{R}$. It consists of the
following rules:

1. ``aA \to \varepsilon``,
2. ``Aa \to \varepsilon``,
3. ``bbb \to \varepsilon``,
4. ``ba \to ab``.

   Is this system confluent? As one indication of non-confluence we could observe
   that while $b$ commutes with $a$, we have no idea so far if $b$ commutes with
   $A$. Well we know that it should, since $A$ smells like an "inverse" of $a$ but
   the rewriting system doesn't know this yet!
   Let us proceed through the Knuth-Bendix procedure of discovering new rules
   through suffix-prefix 'intersections' of rules left-hand-sides.

   * Analyzing pair (1,1) gives no suffix-prefix word, hence no candidates for
     failure of local confluence.
   * Analyzing rule (1,2) we see that with suffix-prefix equal to $A$ we can
     rewrite $a\cdot A\cdot a$ by either rule 1 or rule 2
     (we used $\cdot$ to separate the suffix-prefix word).
     Both rewrites result in $\varepsilon \cdot a = a = a \cdot\varepsilon$, so
     the local confluence holds here (and similarly for (2,1)).
   * Pair (2,2) gives no candidates and so do pairs (3,1) and (3,2).
   * Pair (3,3) results in candidates $bb\cdot b \cdot bb$ and
     $b\cdot bb\cdot b$. Both of rewrites of these words lead to the same result
     (either $bb$, or $b$), so local confluence still holds here.
   * No further candidates are uncoverd considering pairs (3, 1) and (3, 2).
   * Finally moving to rule 4 we see something interesting:
     * pairs (1,4) and (2,4) give no candidates;
     * pair (3,4) results in word $bb\cdot b\cdot a$ which can be rewritten in
       two essentially different ways: ``p_1 = \varepsilon \cdot a = a``, or
       ``p_2 = bb\cdot ab``. However applying rule 4 two more times rewrites the
       latter to $p_2' = a\cdot bbb$ and after the final rewrite with rule 3 we
       obtain $q = a\cdot \varepsilon = a$. Thus
       $p_2 \xrightarrow{*}_\mathcal{R} q = p_1$ and local confluence holds here
        as well.
     * pair (4,4) gives no candidates
     * pair (4,1) results in word $b\cdot a\cdot A$ with two essentially
       different rewrites: $p_1 = ab\cdot A$ and $p_2 = b \cdot \varepsilon = b$.
       None of $p_1$ and $p_2$ can be rewritten any further, so we found the
       first failure to the local confluence and in the process we discovered a
       new rewriting rule which we add to $\mathcal{R}$ (after the appropriate
       reordering) as
5. ``abA \to b``.

   Further pairs (4,2) and (4,3) give no candidates for local confluence.
   However, we are not finished yet, since we've added rule 5 and we have 9 more
   pairs of rules to check. For brevity let's discuss onlt those pairs which give
   candidates:
   * (2,5): the candidate word $A\cdot a\cdot bA$ rewrites as $bA$ (rule 2) or as
     $Ab$ (rule 5), which leads to new rule

6. ``bA \to Ab``

   * (4,5): the candidate word $b\cdot a \cdot bA$ rewrites as $bb$ (rule 5) or
     as $abbA$ (rule 4) which rewrites further to $bb$ (twice applying newly
     discovered rule 6 then rule 1). Local confluence holds for this pair.

   At this point we have finished processing rule 5, but now we have 11 more
   pairs to check with our newly added rule 6. Processing those we arrive at
   three candidates (from pairs (3,6), (5,6), and (6,2)). None of these fails
   local confluence, hence we stop and report the rewriting system with rules
   1-6 as confluent.

!!! warning
    Note that had we chosen a different order of processing the pairs we could
    have ended with an infinite sequence of rules of the form $a^n b A^n \to b$
    and the process might have never stopped. This order in particular is
    dependent on the ordering of $\mathcal{A}^*$ as we have essentially reduced
    the word problem to the problem of finding an order on which Knuth-Bendix
    completion terminates.

One may observe that once we discver rule 6, rule 5 becomes redundant: we can
apply rule 6 to the left-hand-side of rule 5 which leads to
$abA \xrightarrow{} aAb \xrightarrow{} b$, i.e. rule 5 is a consequence of
rules 1 and 6, and as such can be removed. The minimal set of rules forms
the (unique!) **reduced confluent rewriting system** $\mathcal{RC}(R, <)$,
which in this case consists of

> 1. ``aA \to \varepsilon``,
> 2. ``Aa \to \varepsilon``,
> 3. ``bbb \to \varepsilon``,
> 4. ``ba \to ab``,
> 5. ``bA \to Ab``.
