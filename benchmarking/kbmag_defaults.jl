using KnuthBendix

# The default parameters were obtained from
# gap-packages.github.io/kbmag/doc/chap2_mj.html#X7BB411528630D4E9
const kbmag_settings = KnuthBendix.Settings(
    max_rules           = 32767,    # maxeqns
    confluence_delay    = 500,      # confnum
    max_length_rhs      = 0,        # (max_rhs, _)
    max_length_lhs      = 0,        # (_, max_lhs)
    max_length_overlap  = 0,        # maxoverlaplen
)