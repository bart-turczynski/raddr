# Longest-prefix-match lookup. See docs/architecture.md sections 7 and 5.3.
#
# The matcher is internal for now; the `raddr_class` record that consumes it
# arrives with the rest of Epic I. These tests pin containment itself, because
# every field of that record is downstream of getting this right.

# Which block a literal lands in, by text, so failures read as prefixes rather
# than as row numbers.
matched_block <- function(x) {
  i <- registry_match(addr_pton(x))
  ifelse(is.na(i), NA_character_, raddr_registry_data$blocks$block[i])
}

test_that("longest prefix wins, not first match", {
  # The carve-out that forces this: two globally reachable /32s inside a
  # non-global /24, inside which sits a /29 as well. A first-match-wins matcher
  # returns 192.0.0.0/24 for all four and reports the opposite policy.
  expect_equal(matched_block("192.0.0.9"), "192.0.0.9/32")
  expect_equal(matched_block("192.0.0.10"), "192.0.0.10/32")
  expect_equal(matched_block("192.0.0.8"), "192.0.0.8/32")
  expect_equal(matched_block("192.0.0.1"), "192.0.0.0/29")
  expect_equal(matched_block("192.0.0.100"), "192.0.0.0/24")

  # And the policy actually differs across that boundary, which is the reason
  # the distinction is worth enforcing.
  reg <- addr_registry()
  expect_true(reg$globally_reachable[reg$block == "192.0.0.9/32"])
  expect_false(reg$globally_reachable[reg$block == "192.0.0.0/24"])

  # 0.0.0.0/32 sits inside 0.0.0.0/8 the same way.
  expect_equal(matched_block("0.0.0.0"), "0.0.0.0/32")
  expect_equal(matched_block("0.1.2.3"), "0.0.0.0/8")

  # As does the well-known NAT64 prefix inside nothing, and the local-use one.
  expect_equal(matched_block("64:ff9b::a9fe:a9fe"), "64:ff9b::/96")
  expect_equal(matched_block("64:ff9b:1::1"), "64:ff9b:1::/48")

  # 2001::/32 (Teredo) is carved out of 2001::/23 (IETF Protocol Assignments).
  expect_equal(matched_block("2001::1"), "2001::/32")
  expect_equal(matched_block("2001:db8::1"), "2001:db8::/32")
  expect_equal(matched_block("2001:1::1"), "2001:1::1/128")
  expect_equal(matched_block("2001:1::4"), "2001::/23")
})

test_that("the 0x80000000 block matches, which a bitwise matcher cannot do", {
  # 2620:4f:8000::/48 stores 0x80000000 in w2 -- the pattern R spends on
  # NA_integer_ (section 5.1.1). `bitwAnd(NA_integer_, x)` is NA, so a matcher
  # written with bit operations silently never matches this block, and the
  # failure is a miss rather than an error.
  blocks <- raddr_registry_data$blocks
  expect_true(is.na(blocks$w2[blocks$block == "2620:4f:8000::/48"]))

  expect_equal(matched_block("2620:4f:8000::1"), "2620:4f:8000::/48")
  expect_equal(matched_block("2620:4f:8000:ffff::ffff"), "2620:4f:8000::/48")

  # Just outside, and it must not be dragged in.
  expect_true(is.na(matched_block("2620:4f:8001::1")))
  expect_true(is.na(matched_block("2620:4f:7fff::1")))

  # The same pattern as an IPv4 address in w4.
  expect_true(is.na(matched_block("128.0.0.0")))
  expect_equal(matched_block("127.255.255.255"), "127.0.0.0/8")
})

test_that("every block contains its own network address", {
  blocks <- raddr_registry_data$blocks
  network <- new_raddr_address(
    w1 = blocks$w1,
    w2 = blocks$w2,
    w3 = blocks$w3,
    w4 = blocks$w4,
    family = factor(
      ifelse(blocks$space == "v4", "v4", "v6"),
      levels = addr_families
    ),
    zone = rep(NA_character_, nrow(blocks))
  )

  hit <- registry_match(network)
  expect_false(anyNA(hit))

  # The match is the block itself, or a longer one nested inside it that also
  # starts at this address -- 192.0.0.0 is the network address of /24 and /29.
  matched <- blocks$block[hit]
  same_or_longer <- matched == blocks$block |
    blocks$prefix_len[hit] > blocks$prefix_len
  expect_true(all(same_or_longer))
})

test_that("the 4-in-6 family matches IPv6 blocks, never IPv4 ones", {
  # `::ffff:127.0.0.1` is an IPv6 address inside ::ffff:0:0/96. That its
  # embedded address is loopback is a different fact, reported by
  # `embedded_scope` (section 5.3). Answering "127.0.0.0/8" here would collapse
  # the two facts raddr exists to keep apart.
  mapped <- addr_pton("::ffff:127.0.0.1")
  expect_equal(as.character(addr_family(mapped)), "v6_4in6")
  expect_equal(matched_block("::ffff:127.0.0.1"), "::ffff:0:0/96")
  expect_equal(matched_block("::ffff:8.8.8.8"), "::ffff:0:0/96")

  # And the reverse: an IPv4 address never matches an IPv6 block, even where
  # the low 32 bits would agree.
  expect_true(is.na(matched_block("8.8.8.8")))
  expect_equal(matched_block("10.0.0.1"), "10.0.0.0/8")
})

test_that("addresses in no special-purpose block match nothing", {
  # Not "global" -- the matcher reports absence, and what absence means is the
  # record's decision, not the lookup's.
  expect_true(is.na(matched_block("8.8.8.8")))
  expect_true(is.na(matched_block("1.1.1.1")))
  expect_true(is.na(matched_block("2606:4700::1111")))
  expect_true(is.na(matched_block("2000::1")))
})

test_that("a missing address matches nothing", {
  # Missingness lives in `family` (section 5.1.1), so a row whose words still
  # hold something must not be matched on those leftover words.
  missing <- raddr_address(0L, 0L, 0L, 2130706433L, NA_character_)
  expect_true(is.na(registry_match(missing)))

  # `addr_pton()` rejects this, and the rejection must not become a loopback.
  expect_true(is.na(registry_match(addr_pton("not an address"))))
})

test_that("the matcher is vectorized and agrees with one-at-a-time", {
  literals <- c(
    "127.0.0.1", "192.0.0.9", "192.0.0.10", "192.0.0.1", "8.8.8.8",
    "10.1.2.3", "255.255.255.255", "0.0.0.0", "128.0.0.0", "nonsense",
    "::1", "::", "fe80::1%en0", "fc00::1", "64:ff9b::a9fe:a9fe",
    "2001::1", "2002::1", "2620:4f:8000::1", "2001:db8::1",
    "2606:4700::1", "::ffff:127.0.0.1", "3fff::1"
  )

  together <- registry_match(addr_pton(literals))
  separately <- vapply(
    literals,
    function(x) registry_match(addr_pton(x)),
    integer(1),
    USE.NAMES = FALSE
  )

  expect_identical(together, separately)
  expect_length(together, length(literals))
})

test_that("the empty vector round-trips", {
  empty <- registry_match(raddr_address())
  expect_type(empty, "integer")
  expect_length(empty, 0L)
})

test_that("the zone does not affect the match", {
  # Equality ignores the zone (section 5.1.2), and so must containment.
  expect_equal(matched_block("fe80::1%en0"), "fe80::/10")
  expect_equal(matched_block("fe80::1%lo0"), "fe80::/10")
  expect_equal(matched_block("fe80::1"), "fe80::/10")
})

# --- every block edge, against an independent matcher (section 11.1.6) -------
#
# `block_edges()` and `slow_prefix_match()` live in helper-slow.R with the rest
# of the naive second implementations (section 11.3).

test_that("the matcher agrees with a string matcher on every block edge", {
  # Section 11.1.6 replaced the descending-length walk with blocks grouped by
  # prefix length. The literals above cover the carve-outs a human thought to
  # write down; this covers all 340 blocks of all four tables at both ends,
  # which is the part of the space a random draw never lands on.
  tables <- c("special", "space", "transition", "codes")
  fast <- slow <- stats::setNames(vector("list", length(tables)), tables)

  for (which in tables) {
    table <- prefix_table(which)
    edges <- block_edges(table)

    fast[[which]] <- prefix_match(edges, which)
    slow[[which]] <- slow_prefix_match(edges, table)

    # Not a vacuous comparison: an address at either end of a block is inside
    # that block, so every row has to match something.
    expect_false(anyNA(fast[[which]]))
    expect_length(fast[[which]], 2L * length(table$prefix_len))
  }

  expect_identical(fast, slow)
})

test_that("the grouped matcher keeps the walk's tie-break", {
  # Two blocks of the same length and the same key can only come from a
  # duplicated row, but the rule still has to be stated: the earlier row wins,
  # which is what `order(decreasing = TRUE)` being stable gave the walk.
  table <- prefix_table("transition")
  doubled <- lapply(table, function(col) col[c(seq_along(col), seq_along(col))])

  index <- build_prefix_index(
    doubled$space, doubled$prefix_len,
    doubled$w1, doubled$w2, doubled$w3, doubled$w4
  )
  n <- length(table$prefix_len)
  edges <- block_edges(table)

  hit <- prefix_match_index(edges, index)
  expect_true(all(hit <= n))
  expect_identical(hit, slow_prefix_match(edges, doubled))
})

# --- the address-space fallback and the record (sections 5.3 and 7.3) --------

test_that("classification is total across both address spaces", {
  # The whole point of vendoring a second pair (section 7.3): each half is an
  # exact partition, so every address matches SOME row and `global` is backed by
  # a registry row rather than inferred from an absence.
  v4 <- c(sprintf("%d.0.0.1", 0:255), sprintf("%d.255.255.254", 0:255))
  space <- raddr_registry_data$space
  v6 <- space$block[space$space == "v6"]
  v6 <- sub("/\\d+$", "1", v6)

  cl <- addr_classify(addr_pton(c(v4, v6)))
  expect_false(anyNA(field(cl, "block")))
  expect_false(anyNA(field(cl, "category")))
  expect_false(anyNA(field(cl, "registry")))
  expect_false(anyNA(field(cl, "registry_version")))
})

test_that("the special-purpose registry outranks the address space", {
  # IANA's own instruction, not raddr's preference: the address-space registries
  # carry "For authoritative registration, see [Special-Purpose Address Space]".
  # All five of the doubly-present prefixes must answer from the policy layer.
  both <- c("0.0.0.1", "10.0.0.1", "127.0.0.1", "fc00::1", "fe80::1")
  cl <- addr_classify(addr_pton(both))
  expect_equal(
    as.character(field(cl, "registry")),
    rep("special_purpose", length(both))
  )
  # ... and the policy columns the address-space layer does not have are there.
  expect_false(anyNA(field(cl, "globally_reachable")))

  # A carve-out inside a delegated /8 also answers from the policy layer, even
  # though the /8 around it is an address-space row.
  cl <- addr_classify(addr_pton(c("192.0.0.9", "192.1.2.3")))
  expect_equal(
    as.character(field(cl, "registry")),
    c("special_purpose", "address_space")
  )
  expect_equal(field(cl, "block"), c("192.0.0.9/32", "192.0.0.0/8"))
})

test_that("the two meanings of a missing policy column stay apart", {
  # This is the record's version of the rule that keeps IANA's `N/A` from
  # becoming FALSE. Both rows below have `globally_reachable = NA`, and the two
  # NAs mean different things -- `registry` is what says which.
  cl <- addr_classify(addr_pton(c("192.88.99.1", "8.8.8.8")))
  expect_true(all(is.na(field(cl, "globally_reachable"))))
  expect_equal(
    as.character(field(cl, "registry")),
    c("special_purpose", "address_space")
  )

  # Withheld: a deprecated block IANA gives no policy values for.
  expect_equal(field(cl, "block")[[1]], "192.88.99.0/24")
  # Never asked: that registry has no policy columns at all.
  expect_equal(field(cl, "block")[[2]], "8.0.0.0/8")
})

test_that("every missing policy value carries the column that explains it", {
  # Exactly four special-purpose blocks have one, and they split into three
  # reasons. Reporting all four as a bare NA would merge facts raddr knows to
  # be different, which is the mistake this record exists to refuse.
  reg <- addr_registry()
  policy <- c(
    "source", "destination", "forwardable",
    "globally_reachable", "reserved_by_protocol"
  )
  withheld <- reg$block[apply(reg[policy], 1L, anyNA)]
  expect_setequal(
    withheld,
    c("192.88.99.0/24", "2001:10::/28", "2001::/32", "2002::/16")
  )

  cl <- addr_classify(addr_pton(c("192.88.99.1", "2001:10::1", "2001::1",
                                  "2002::1")))

  # Deprecated: all five gone, and a termination date saying why.
  deprecated <- vec_slice(cl, 1:2)
  expect_false(anyNA(field(deprecated, "termination_date")))
  expect_equal(field(deprecated, "footnotes"), c("", ""))

  # Withheld: policy stated except for reachability, no termination date, and
  # two DIFFERENT footnote markers -- Teredo's [2] is not 6to4's [3].
  declined <- vec_slice(cl, 3:4)
  expect_true(all(is.na(field(declined, "termination_date"))))
  expect_true(all(field(declined, "forwardable")))
  expect_true(all(is.na(field(declined, "globally_reachable"))))
  expect_equal(length(unique(field(declined, "footnotes"))), 2L)
  expect_true(all(nzchar(field(declined, "footnotes"))))
})

test_that("footnotes say whether an absent rfc has a citation elsewhere", {
  # `rfc` is NA for all 256 IPv4 address-space rows, because that registry has
  # no reference column -- but 42 of them cite one in a numeric footnote whose
  # text lives on the registry page. "No citation" and "a citation you have to
  # go and read" are different facts.
  space <- addr_address_space()
  v4 <- space[space$space == "v4", ]
  expect_true(all(is.na(v4$rfc)))
  expect_equal(sum(nzchar(v4$footnotes)), 42L)

  cl <- addr_classify(addr_pton(c("127.0.0.1", "1.1.1.1")))
  expect_true(all(is.na(field(cl, "rfc"))[2]))
  # 127.0.0.0/8 answers from the special-purpose layer, which does cite one.
  expect_false(is.na(field(cl, "rfc")[[1]]))
  # 1.0.0.0/8 is an address-space row carrying neither.
  expect_equal(field(cl, "footnotes")[[2]], "")

  # And one that carries a marker instead of a citation.
  marked <- addr_classify(addr_pton("169.1.2.3"))
  expect_equal(field(marked, "block"), "169.0.0.0/8")
  expect_true(is.na(field(marked, "rfc")))
  expect_true(nzchar(field(marked, "footnotes")))
})

test_that("Teredo's and 6to4's N/A survive into the record, still separate", {
  cl <- addr_classify(addr_pton(c("2001::1", "2002::1")))
  expect_equal(field(cl, "block"), c("2001::/32", "2002::/16"))
  expect_true(all(is.na(field(cl, "globally_reachable"))))
  expect_equal(
    as.character(field(cl, "registry")),
    c("special_purpose", "special_purpose")
  )
  # The two reasons carry two different IANA footnotes, which stay in the
  # registry rather than being restated as one.
  reg <- addr_registry()
  footnotes <- reg$footnotes[match(c("2001::/32", "2002::/16"), reg$block)]
  expect_false(identical(footnotes[[1]], footnotes[[2]]))
})

test_that("registry_version is the stamp of the layer that answered", {
  # P7, per row. The two pairs are stamped separately (section 7.3), so one
  # date across both would make each assert something about a table it says
  # nothing about.
  cl <- addr_classify(addr_pton(c("127.0.0.1", "8.8.8.8")))
  expect_equal(
    field(cl, "registry_version"),
    c(addr_registry_version(), addr_address_space_version())
  )
})

test_that("special, global and unallocated are three different answers", {
  # Section 5.3.2: they must never be collapsed into each other.
  cl <- addr_classify(addr_pton(c("5f00::1", "2606:4700::1111", "4000::1")))
  expect_equal(
    as.character(field(cl, "category")),
    c("special", "global", "unallocated")
  )
  expect_equal(field(cl, "block"), c("5f00::/16", "2000::/3", "4000::/3"))
})

test_that("the 0x80000000 blocks classify, in both registries", {
  # Section 5.1.1 recurs at a larger scale in the address-space pair: 8000::/3
  # stores w1 as the NA_integer_ bit pattern, and it is an eighth of the IPv6
  # address space rather than a /48.
  space <- raddr_registry_data$space
  expect_true(is.na(space$w1[space$block == "8000::/3"]))

  cl <- addr_classify(addr_pton(c("8000::1", "2620:4f:8000::1")))
  expect_equal(field(cl, "block"), c("8000::/3", "2620:4f:8000::/48"))
  expect_equal(
    as.character(field(cl, "category")),
    c("unallocated", "anycast")
  )
})

test_that("the 4-in-6 family is classified as an IPv6 block", {
  # The CVE-shaped mistake this refuses: answering `loopback` here would
  # collapse the outer address and its embedded one into a single fact.
  cl <- addr_classify(addr_pton("::ffff:127.0.0.1"))
  expect_equal(field(cl, "block"), "::ffff:0:0/96")
  expect_equal(as.character(field(cl, "category")), "protocol")
  expect_equal(as.character(field(cl, "embedded_kind")), "ipv4_mapped")
})

test_that("the NAT64 worked example reports every fact separately", {
  # Section 5.3.2's own example. The mechanism is not the category, and the
  # registry's answer is not overridden by either.
  cl <- addr_classify(addr_pton("64:ff9b::a9fe:a9fe"))
  expect_equal(as.character(field(cl, "category")), "protocol")
  expect_equal(as.character(field(cl, "embedded_kind")), "nat64_wk")
  expect_true(field(cl, "globally_reachable"))
  expect_equal(field(cl, "block"), "64:ff9b::/96")
})

test_that("a missing address classifies to nothing, in every field", {
  cl <- addr_classify(addr_pton("not an address"))
  expect_true(is.na(field(cl, "block")))
  expect_true(is.na(field(cl, "category")))
  expect_true(is.na(field(cl, "registry")))
  expect_true(is.na(field(cl, "registry_version")))
  expect_true(is.na(field(cl, "embedded_kind")))
  expect_true(is.na(field(cl, "globally_reachable")))
  # The typed columns stay typed rather than becoming NA.
  expect_equal(vec_size(field(cl, "embeddings")[[1]]), 0L)
  expect_equal(field(cl, "codes")[[1]], character())
})

# --- embedded_kind (sections 5.3 and 8.1) ------------------------------------

test_that("every mechanism prefix reports its kind", {
  kinds <- as.character(addr_embedded_kind(addr_pton(c(
    "::ffff:1.2.3.4", "::2", "::ffff:0:1.2.3.4",
    "2002::1", "2001::1", "64:ff9b::1", "64:ff9b:1::1"
  ))))
  expect_equal(
    kinds,
    c(
      "ipv4_mapped", "ipv4_compatible", "ipv4_translated",
      "6to4", "teredo", "nat64_wk", "nat64_local"
    )
  )
})

test_that("`::` and `::1` are not read as IPv4-compatible addresses", {
  # RFC 4291 section 2.5.5.1's tail32 > 1 carve-out. Reading the low 32 bits
  # here would report an embedded 0.0.0.0 or 0.0.0.1 for the unspecified
  # address and for loopback. Both shipped in-house guards use this threshold.
  expect_true(all(is.na(addr_embedded_kind(addr_pton(c("::", "::1"))))))
  expect_equal(as.character(addr_embedded_kind(addr_pton("::2"))),
               "ipv4_compatible")

  # And the outer classification is untouched by the carve-out.
  expect_equal(
    as.character(addr_category(addr_pton(c("::", "::1")))),
    c("unspecified", "loopback")
  )
})

test_that("6to4 relay anycast has no embedded kind, because nothing is in it", {
  # It is in the overlay's prefix table and has no geometry row: the converse
  # mapping exists (192.88.99.1 has a 6to4 image) but that is a mapping OUT.
  # The fact itself is carried by `name` and `category`.
  cl <- addr_classify(addr_pton("192.88.99.1"))
  expect_true(is.na(field(cl, "embedded_kind")))
  expect_equal(as.character(field(cl, "category")), "anycast")
  expect_match(field(cl, "name"), "6to4")
})

test_that("ISATAP is matched by its interface identifier, under any prefix", {
  # RFC 5214 section 6.1: a pattern, not a prefix, so the outer category varies
  # while the mechanism does not.
  lits <- c(
    "::0:5efe:1.2.3.4",
    "fe80::5efe:192.0.2.1",
    "2001:db8::200:5efe:1.2.3.4"
  )
  cl <- addr_classify(addr_pton(lits))
  expect_equal(
    as.character(field(cl, "embedded_kind")),
    rep("isatap", 3)
  )
  expect_equal(
    as.character(field(cl, "category")),
    c("unallocated", "link_local", "documentation")
  )

  # Both RFC 5214 forms, and nothing else.
  expect_true(is.na(addr_embedded_kind(addr_pton("fe80::5eff:192.0.2.1"))))

  # An IPv4 address never matches the pattern, whatever its leftover words say.
  v4 <- raddr_address(0L, 0L, isatap_iid$permitted[[1]], 1L, "v4")
  expect_true(is.na(addr_embedded_kind(v4)))
})

test_that("a mechanism prefix outranks the ISATAP interface identifier", {
  # A prefix is an assignment; an interface identifier is a convention within
  # one, and it can sit under a /64 already assigned to another mechanism.
  under_6to4 <- addr_pton("2002:c000:201:0:0:5efe:1.2.3.4")
  expect_equal(as.character(addr_embedded_kind(under_6to4)), "6to4")
})

test_that("every embedded_kind level has a geometry to extract with", {
  # The vocabulary is derived from the geometry table rather than restated, so
  # a kind can be named only where raddr knows where the bits are. This is the
  # mechanical half of "raddr never says nat64 without meaning it".
  geometry <- transition_geometry_kind[raddr_embedded_kinds]
  expect_false(anyNA(geometry))
  expect_true(all(geometry %in% addr_transition_registry("embeddings")$kind))

  # 6to4_relay_anycast is the one prefix kind that is deliberately absent.
  expect_false("6to4_relay_anycast" %in% raddr_embedded_kinds)
  expect_true("6to4_relay_anycast" %in% addr_transition_registry()$kind)
})

# --- extraction, the wrapper matrix of section 8.1 ---------------------------
#
# The mechanisms end to end, through the record. The bit machinery underneath
# is tested on its own in test-embedding.R.

embedded_of <- function(literal) {
  field(addr_classify(addr_pton(literal)), "embeddings")[[1L]]
}

test_that("the three /96 wrapper forms carry their address verbatim", {
  # RADD-wslnuhwa. RFC 4291 sections 2.5.5.1 and 2.5.5.2, and the historic
  # RFC 2765 form. All three put the address at bits 96-127 and differ only in
  # which hextet holds `ffff` -- which is why an extractor keyed on the trailing
  # 32 bits alone gets the right address and the wrong mechanism.
  expect_equal(format(embedded_of("::ffff:127.0.0.1")),
               "ipv4_mapped/embedded 127.0.0.1 loopback")
  expect_equal(format(embedded_of("::1.2.3.4")),
               "ipv4_compatible/embedded 1.2.3.4 global")
  expect_equal(format(embedded_of("::ffff:0:c000:221")),
               "ipv4_translated/embedded 192.0.2.33 documentation")

  # Two textual spellings of one 128-bit value take one code path. Node's URL
  # parser normalising `::ffff:169.254.169.254` to the hex form while the range
  # check only read the dotted one is the root cause docs/research/04 records
  # behind CVE-2024-29415 and six others.
  expect_equal(embedded_of("::ffff:7f00:1"), embedded_of("::ffff:127.0.0.1"))
})

test_that("`::` and `::1` extract nothing, and `::2` does", {
  # The `tail32 > 1` carve-out, which both shipped in-house guards use: reading
  # the low bits of the unspecified or loopback address would report an
  # embedded 0.0.0.0 or 0.0.0.1 and misclassify two higher-priority IANA rows.
  expect_equal(vec_size(embedded_of("::")), 0L)
  expect_equal(vec_size(embedded_of("::1")), 0L)
  expect_equal(format(embedded_of("::2")),
               "ipv4_compatible/embedded 0.0.0.2 this_network")
})

test_that("6to4 reads V4ADDR at bits 16-47, not from the interface id", {
  # RADD-upovkbfc. RFC 3056 section 2's diagram: FP | TLA | V4ADDR | SLA | IID.
  expect_equal(format(embedded_of("2002:c000:204::")),
               "6to4/embedded 192.0.2.4 documentation")

  # The 6to4 image of the deprecated relay anycast address, which is the one
  # place the mapping runs the other way (section 5.3.7 rule 1).
  expect_equal(format(embedded_of("2002:c058:6301::")),
               "6to4/embedded 192.88.99.1 anycast")

  # And 192.88.99.0/24 itself embeds nothing: it is IPv4, and classify-only.
  expect_equal(vec_size(embedded_of("192.88.99.1")), 0L)
  expect_true(is.na(addr_embedded_kind(addr_pton("192.88.99.1"))))
})

test_that("Teredo reports both addresses, and complements exactly one", {
  # RADD-upovkbfc, and RFC 4380 section 4's own example address. Two rows in
  # the RFC's order, both classified, neither ranked -- section 5.3.5.
  rows <- embedded_of("2001:0:4136:e378:8000:63bf:3fff:fdd2")
  expect_equal(vec_size(rows), 2L)
  expect_equal(
    format(rows),
    c(
      "teredo/server 65.54.227.120 global",
      "teredo/client 192.0.2.45 documentation"
    )
  )

  # The two symmetric failures docs/research/04 records, each of which produces
  # a wrong-but-routable-looking address with no error: reporting the raw
  # client bits, or complementing the server too.
  addresses <- field(rows, "address")
  expect_false(any(addresses == addr_pton("63.255.253.210")))
  expect_false(any(addresses == addr_pton("63.255.253.254")))
})

test_that("Teredo is the only form with two rows", {
  lits <- c(
    "::ffff:1.2.3.4", "::2", "::ffff:0:1.2.3.4", "2002:102:304::",
    "2001:0:4136:e378:8000:63bf:3fff:fdd2", "64:ff9b::1.2.3.4",
    "64:ff9b:1:102:3:400::", "2001:db8::5efe:1.2.3.4"
  )
  sizes <- vapply(
    field(addr_classify(addr_pton(lits)), "embeddings"),
    vec_size,
    integer(1L)
  )
  expect_equal(sizes, c(1L, 1L, 1L, 1L, 2L, 1L, 1L, 1L))
})

test_that("NAT64 reads the well-known prefix and the local-use prefix", {
  # RADD-dgdptgoc, and the worked example section 5.3.5 is built on: four
  # simultaneously true facts about `64:ff9b::a9fe:a9fe`, none collapsed.
  cl <- addr_classify(addr_pton("64:ff9b::a9fe:a9fe"))
  expect_equal(field(cl, "block"), "64:ff9b::/96")
  expect_equal(as.character(field(cl, "category")), "protocol")
  expect_true(field(cl, "globally_reachable"))
  expect_equal(format(field(cl, "embeddings")[[1L]]),
               "nat64_wk/embedded 169.254.169.254 link_local")

  # RFC 8215's local-use prefix reads RFC 6052 /48 geometry, where the address
  # straddles the reserved u-byte. A contiguous read here gives 192.0.0.2.
  expect_equal(format(embedded_of("64:ff9b:1:c000:2:2100::")),
               "nat64_local/embedded 192.0.2.33 documentation")

  # The extraction is contested rather than implied, and says so.
  expect_true(
    "nat64_local_layout_unspecified" %in%
      field(addr_classify(addr_pton("64:ff9b:1:c000:2:2100::")), "codes")[[1L]]
  )
})

test_that("a network-specific NAT64 prefix is invisible, and says nothing", {
  # Section 5.3.7: `embedded_kind` is affirmative only. RFC 6052's own /48
  # example under a documentation prefix is a real NAT64 address that no prefix
  # table can see, so raddr reports no kind and extracts nothing -- it does NOT
  # report "not NAT64".
  nsp <- addr_pton("2001:db8:122:c000:2:2100::")
  expect_true(is.na(addr_embedded_kind(nsp)))
  expect_equal(vec_size(addr_embeddings(nsp)[[1L]]), 0L)
})

test_that("ISATAP extracts from both permitted interface identifiers", {
  # RADD-mwjduppi. RFC 5214 section 6.1: `0000:5efe` or `0200:5efe`, the second
  # when the IPv4 address is known globally unique. Matching only one form
  # misses half the mechanism.
  expect_equal(format(embedded_of("2001:db8::5efe:c000:221")),
               "isatap/embedded 192.0.2.33 documentation")
  expect_equal(format(embedded_of("2001:db8::200:5efe:c000:221")),
               "isatap/embedded 192.0.2.33 documentation")

  # A private embedded address is expected, not anomalous: RFC 5214 section 6.1
  # says ISATAP works "whether global or private IPv4 addresses are used".
  expect_equal(format(embedded_of("fe80::5efe:a00:1")),
               "isatap/embedded 10.0.0.1 private")

  # A prefix outranks the pattern, and the extraction follows the prefix: this
  # is a 6to4 address, so the bits read are 16-47 and not 96-127.
  expect_equal(format(embedded_of("2002:c000:201:0:0:5efe:1.2.3.4")),
               "6to4/embedded 192.0.2.1 documentation")
})

test_that("extraction is vectorized and agrees with one-at-a-time", {
  lits <- c(
    "::ffff:127.0.0.1", "8.8.8.8", "2001:0:4136:e378:8000:63bf:3fff:fdd2",
    "not an address", "64:ff9b::a9fe:a9fe", "::1", "2002:c058:6301::"
  )
  together <- field(addr_classify(addr_pton(lits)), "embeddings")
  apart <- lapply(lits, embedded_of)

  expect_length(together, length(lits))
  for (i in seq_along(lits)) {
    expect_equal(together[[i]], apart[[i]], info = lits[[i]])
  }
})

test_that("an extracted address never inherits the outer zone", {
  # The zone is storage alongside the bits, never inside them, and it names an
  # interface on the OUTER address. Carrying it into an extracted IPv4 address
  # would assert a scope for a value that was read out of 32 bits.
  rows <- embedded_of("fe80::5efe:a00:1%en0")
  expect_true(is.na(addr_zone(field(rows, "address"))))
  expect_equal(rows, embedded_of("fe80::5efe:a00:1"))
})

test_that("extraction survives the 0x80000000 word, in both directions", {
  # Section 5.1.1's pattern, reached through the geometry rather than built by
  # hand. `2001::8000:0` is a Teredo client at 127.255.255.255 once
  # complemented; `::ffff:128.0.0.0` stores the pattern directly.
  client <- field(embedded_of("2001::8000:0"), "address")[[2L]]
  expect_equal(client, addr_pton("127.255.255.255"))

  mapped <- field(embedded_of("::ffff:128.0.0.0"), "address")
  expect_equal(mapped, addr_pton("128.0.0.0"))
  expect_true(is.na(field(mapped, "w4")))
  expect_true(mapped == mapped)
})

# --- the record's shape and API ----------------------------------------------

test_that("a string may never be classified, and neither may a raddr_parse", {
  # P1, and section 4: raddr chooses a dialect by function name, never silently.
  expect_error(addr_classify("127.0.0.1"), class = "raddr_error_type")
  expect_error(
    addr_classify(addr_parse("127.0.0.1")),
    class = "raddr_error_type"
  )
  expect_error(addr_classify(addr_parse("0177.0.0.1")), "four readings")
})

test_that("the record is size-stable and one type", {
  # Section 5.3.5: `embeddings` is a list_of with exactly one element per row,
  # so rows multiply only when a caller explicitly unnests.
  lits <- c("127.0.0.1", "2001::1", "8.8.8.8", "not an address")
  cl <- addr_classify(addr_pton(lits))
  expect_s3_class(cl, "raddr_class")
  expect_true(is_raddr_class(cl))
  expect_equal(vec_size(cl), length(lits))

  embeddings <- field(cl, "embeddings")
  expect_equal(length(embeddings), length(lits))
  expect_true(all(vapply(embeddings, is_raddr_embedding, logical(1))))
  expect_equal(
    vctrs::vec_ptype(embeddings),
    vctrs::vec_ptype(field(addr_classify(addr_pton("::1")), "embeddings"))
  )

  # Slicing keeps the type.
  expect_true(is_raddr_class(vec_slice(cl, 2)))
  expect_equal(field(vec_slice(cl, 2), "block"), "2001::/32")
})

test_that("the empty vector round-trips", {
  cl <- addr_classify(raddr_address())
  expect_true(is_raddr_class(cl))
  expect_equal(vec_size(cl), 0L)
  expect_equal(format(cl), character())
  expect_equal(nrow(as.data.frame(cl)), 0L)
})

test_that("as.data.frame exposes every field", {
  cl <- addr_classify(addr_pton("127.0.0.1"))
  df <- as.data.frame(cl)
  expect_s3_class(df, "data.frame")
  expect_equal(
    names(df),
    c(
      "block", "name", "rfc", "footnotes", "category",
      "globally_reachable", "forwardable", "source", "destination",
      "reserved_by_protocol", "termination_date",
      "embedded_kind", "embeddings", "codes",
      "registry", "registry_version"
    )
  )
  expect_equal(nrow(df), 1L)
})

test_that("the accessors read an address or a classification alike", {
  a <- addr_pton(c("127.0.0.1", "64:ff9b::1"))
  cl <- addr_classify(a)
  expect_equal(addr_category(a), addr_category(cl))
  expect_equal(addr_embedded_kind(a), addr_embedded_kind(cl))
  expect_equal(addr_embeddings(a), addr_embeddings(cl))
  expect_equal(levels(addr_category(a)), raddr_category_levels)
})

test_that("classification is vectorized and agrees with one-at-a-time", {
  literals <- c(
    "127.0.0.1", "192.0.0.9", "8.8.8.8", "10.1.2.3", "255.255.255.255",
    "0.0.0.0", "128.0.0.0", "224.0.0.1", "nonsense", "240.0.0.1",
    "::1", "::", "fe80::1%en0", "fc00::1", "64:ff9b::a9fe:a9fe",
    "2001::1", "2002::1", "2620:4f:8000::1", "8000::1", "2001:db8::1",
    "2606:4700::1", "::ffff:127.0.0.1", "3fff::1", "5f00::1"
  )
  together <- addr_classify(addr_pton(literals))
  separately <- vapply(
    literals,
    function(x) field(addr_classify(addr_pton(x)), "block"),
    character(1),
    USE.NAMES = FALSE
  )
  expect_equal(field(together, "block"), separately)
})

test_that("the zone does not affect classification", {
  cl <- addr_classify(addr_pton(c("fe80::1%en0", "fe80::1%lo0", "fe80::1")))
  expect_equal(field(cl, "block"), rep("fe80::/10", 3))
})

test_that("printing names every snapshot that answered", {
  both <- addr_classify(addr_pton(c("127.0.0.1", "8.8.8.8")))
  expect_output(print(both), "Registry: special-purpose .* address space")
  expect_output(print(both), "loopback 127\\.0\\.0\\.0/8")

  # One layer, so no counts to disambiguate.
  one <- addr_classify(addr_pton("127.0.0.1"))
  expect_output(print(one), "Registry: special-purpose [0-9-]+$")

  # Nothing classified, so nothing to say about provenance.
  none <- addr_classify(addr_pton("not an address"))
  expect_output(print(none), "NA")
  expect_failure(expect_output(print(none), "Registry:"))
})

test_that("an embedding formats as its kind, role, address and category", {
  # Built by hand rather than extracted, so the format is pinned to the type
  # rather than to whatever the extractor happens to produce.
  e <- new_raddr_embedding(
    kind = factor("teredo", levels = raddr_embedded_kinds),
    role = factor("server", levels = raddr_embedding_roles),
    address = addr_pton("192.0.2.45"),
    category = factor("global", levels = raddr_category_levels)
  )
  expect_true(is_raddr_embedding(e))
  expect_equal(format(e), "teredo/server 192.0.2.45 global")
  expect_equal(format(empty_raddr_embedding()), character())
})

# --- The classify-layer codes (RADD-wglsdrmu) --------------------------------
#
# All eight rules are graded in R/codes.R; these pin the five that need nothing
# but the address. See docs/architecture.md section 5.2.3.

codes_of <- function(x) {
  field(addr_classify(addr_pton(x)), "codes")
}

test_that("the record carries codes for every row, empty where none fire", {
  cl <- addr_classify(addr_pton(c("8.8.8.8", "febf::1", "not an address")))
  codes <- field(cl, "codes")
  expect_s3_class(codes, "vctrs_list_of")
  expect_length(codes, 3L)
  expect_identical(codes[[1L]], character())
  expect_identical(codes[[3L]], character())
})

test_that("fe80::/10 outside fe80::/64 is not a link-local address", {
  # RFC 4291 section 2.5.6 fixes the 54 bits after the prefix to zero, so the
  # registry row and the format disagree. Both CPython's `ipaddress` and R's
  # `ipaddress` answer `is_link_local = TRUE` here with nothing attached
  # [measured 2026-07-27], which is the divergence this code exists to state.
  expect_identical(codes_of("febf::1")[[1L]], "link_local_outside_fe80_64")
  expect_identical(codes_of("fe80::1")[[1L]], character())

  # The boundary in both directions, and the /64 shadow row emits nothing.
  expect_identical(codes_of("fe80:0:0:1::")[[1L]], "link_local_outside_fe80_64")
  expect_identical(codes_of("fe80::ffff:ffff:ffff:ffff")[[1L]], character())
  expect_identical(codes_of("febf:ffff::1")[[1L]], "link_local_outside_fe80_64")

  # Just outside the reservation on either side: no rule, and no code.
  expect_identical(codes_of("fe7f::1")[[1L]], character())
  expect_identical(codes_of("fec0::1")[[1L]], character())
})

test_that("the two reserved IPv4 link-local /24s are reported", {
  # RFC 3927 section 2.1. Neither has a registry row, so without the code they
  # are indistinguishable from any other 169.254.0.0/16 address.
  expect_identical(codes_of("169.254.0.5")[[1L]], "link_local_reserved_range")
  expect_identical(codes_of("169.254.255.5")[[1L]], "link_local_reserved_range")
  expect_identical(codes_of("169.254.1.0")[[1L]], character())
  expect_identical(codes_of("169.254.254.255")[[1L]], character())

  # It is still a 169.254.0.0/16 address: the code adds a fact, it does not
  # replace the classification.
  expect_identical(addr_category(addr_pton("169.254.0.5")), addr_category(
    addr_pton("169.254.1.5")
  ))
})

test_that("fc00::/8 is the undefined half of the ULA prefix", {
  # RFC 4193 section 3.1 defines only L = 1. raddr stores the /7, so this is
  # the only place the two halves are told apart.
  expect_identical(codes_of("fc00::1")[[1L]], "ula_l_bit_unset")
  expect_identical(codes_of("fcff:ffff::1")[[1L]], "ula_l_bit_unset")
  expect_identical(codes_of("fd00::1")[[1L]], character())
  expect_identical(codes_of("fdff:ffff::1")[[1L]], character())
})

test_that("the 64:ff9b:1::/48 layout is reported as contested", {
  # RFC 8215 section 5 leaves the syntax unspecified and tells nodes not to
  # assume one; raddr reads RFC 6052 /48 geometry anyway, so it says so.
  expect_identical(
    codes_of("64:ff9b:1::c000:201")[[1L]],
    "nat64_local_layout_unspecified"
  )
  # The rule is about the local-use prefix only. RFC 8215 section 5 says the
  # well-known prefix's own restrictions do not reach it, and the converse
  # holds too -- the WKP's geometry is not contested. The WKP address carries
  # its own MUST instead, which is the other half of the same section.
  expect_false(
    "nat64_local_layout_unspecified" %in% codes_of("64:ff9b::c000:201")[[1L]]
  )
  expect_identical(
    codes_of("64:ff9b::c000:201")[[1L]], "nat64_wk_embedded_not_global"
  )
})

test_that("an IPv4-compatible tail below 1.0.0.0 is flagged, not suppressed", {
  # The `tail32 > 1` carve-out is a registry fact and is unchanged; this is the
  # `may`-strength report layered on top of it, so a consumer can apply the
  # heuristic without raddr having applied it first.
  expect_identical(codes_of("::2")[[1L]], "ipv4_compatible_low_tail")
  expect_identical(codes_of("::ffff")[[1L]], "ipv4_compatible_low_tail")
  expect_identical(
    codes_of("::0.255.255.255")[[1L]], "ipv4_compatible_low_tail"
  )
  expect_identical(codes_of("::1.0.0.0")[[1L]], character())
  expect_identical(codes_of("::1.2.3.4")[[1L]], character())

  # `::` and `::1` have no kind at all, so no code either -- the carve-out
  # comes first and this rule never re-decides it.
  expect_identical(codes_of("::")[[1L]], character())
  expect_identical(codes_of("::1")[[1L]], character())
  expect_true(all(is.na(addr_embedded_kind(addr_pton(c("::", "::1"))))))
})

test_that("codes accumulate and are reported strongest first", {
  # A Teredo-format link-local address sits in fe80::/64, so the /10 rule does
  # not fire on it; the ordering guarantee is exercised on the vocabulary.
  expect_identical(
    codes_from_mask(
      sum(classify_code_bits), classify_code_levels, classify_code_bits
    )[[1L]],
    classify_code_levels
  )
})

test_that("classifying nothing produces a typed, empty codes column", {
  codes <- field(addr_classify(addr_pton(character())), "codes")
  expect_s3_class(codes, "vctrs_list_of")
  expect_length(codes, 0L)
})

# --- the three rules stated about the EMBEDDED address (RADD-twrpcrhk) -------

test_that("the well-known prefix's MUST-drop binds it and nothing else", {
  # RFC 6052 section 3.1: translators MUST drop a packet whose address is the
  # WKP plus a non-global IPv4 address.
  expect_true(
    "nat64_wk_embedded_not_global" %in% codes_of("64:ff9b::a9fe:a9fe")[[1L]]
  )
  expect_identical(codes_of("64:ff9b::8.8.8.8")[[1L]], character())

  # It binds 64:ff9b::/96 ALONE. RFC 8215 section 5 removes 64:ff9b:1::/48 from
  # its reach in terms, and a network-specific prefix was never in it -- the
  # same embedded address under a documentation prefix draws no code at all.
  expect_equal(
    format(embedded_of("64:ff9b:1:a9fe:a9:fe00::")),
    "nat64_local/embedded 169.254.169.254 link_local"
  )
  expect_false(
    "nat64_wk_embedded_not_global" %in%
      codes_of("64:ff9b:1:a9fe:a9:fe00::")[[1L]]
  )
  expect_identical(codes_of("2001:db8:122:c000:2:2100::")[[1L]], character())
})

test_that("6to4 requires a global unicast V4ADDR, and Teredo its client", {
  # RFC 3056 section 9, and RFC 4380 section 4.
  expect_identical(
    codes_of("2002:a00:1::")[[1L]], "sixtofour_embedded_not_global"
  )
  expect_identical(codes_of("2002:808:808::")[[1L]], character())

  private_client <- "2001:0:4136:e378:8000:63bf:f5ff:fffe"
  expect_identical(
    codes_of(private_client)[[1L]], "teredo_client_not_global"
  )
  expect_identical(
    codes_of("2001:0:808:808:8000:63bf:f7ff:f7f7")[[1L]], character()
  )

  # The SERVER is not graded, and that asymmetry is RFC 4380's, not raddr's:
  # section 5.2.3 validates the client against the packet source and specifies
  # no check of the server anywhere. A private server with a global client
  # draws nothing.
  rows <- addr_embeddings(addr_pton("2001:0:a00:1:8000:63bf:f7ff:f7f7"))[[1L]]
  expect_equal(as.character(field(rows, "category")), c("private", "global"))
  expect_identical(codes_of("2001:0:a00:1:8000:63bf:f7ff:f7f7")[[1L]],
                   character())
})

test_that("IANA's declined policy stays declined, and fires no MUST", {
  # 192.88.99.0/24 is the ONE IPv4 block where "is this global" has no answer:
  # IANA withdrew it and published no policy column at all. Its 6to4 image is
  # therefore not affirmatively non-global, and asserting the MUST-drop for it
  # would be reading that silence as a FALSE one level down.
  expect_identical(codes_of("2002:c058:6301::")[[1L]], character())

  # What raddr reports instead is the fact, one level in: the extracted address
  # with its own record, which says why the question has no answer.
  embedded <- field(embedded_of("2002:c058:6301::"), "address")
  inner <- addr_classify(embedded)
  expect_equal(field(inner, "block"), "192.88.99.0/24")
  expect_true(is.na(field(inner, "globally_reachable")))
  expect_equal(field(inner, "termination_date"), "2015-03")

  # And the affirmative FALSE next door still fires: 192.88.99.2/32 is a
  # separate, longer row that IANA does answer for.
  expect_identical(
    codes_of("2002:c058:6302::")[[1L]], "sixtofour_embedded_not_global"
  )
})

test_that("no rule fires where nothing was extracted", {
  # Silence is not a clean bill of health. A caller-supplied NAT64 prefix is
  # invisible to a prefix table, and `embedded_kind = NA` is why.
  quiet <- c("8.8.8.8", "10.0.0.1", "2001:db8::1", "::1", "not an address")
  codes <- field(addr_classify(addr_pton(quiet)), "codes")
  embedded_rules <- c(
    "nat64_wk_embedded_not_global", "sixtofour_embedded_not_global",
    "teredo_client_not_global"
  )
  for (i in seq_along(quiet)) {
    expect_false(any(embedded_rules %in% codes[[i]]), info = quiet[[i]])
  }
})

# --- the CVE-2024-24790 invariant --------------------------------------------

test_that("an embedded address classifies as itself, in every wrapper", {
  # CVE-2024-24790 was Go's netip predicates answering differently for
  # `127.0.0.1` and for the IPv4-mapped form of the same address. The invariant
  # that catches it is not that the two RECORDS agree -- they must not, the
  # outer one is an IPv6 address in ::ffff:0:0/96 -- but that the embedded
  # address is classified as the address it is.
  #
  # Run over the whole IPv4 space at /8 granularity plus every IPv4 block raddr
  # maps, so a level that classifies differently through a wrapper fails here
  # rather than in a consumer.
  map <- addr_category_map()
  blocks <- map$block[!grepl(":", map$block, fixed = TRUE)]
  bare <- addr_pton(sub("/.*", "", blocks))

  direct <- addr_category(bare)
  quads <- addr_format(bare)

  for (prefix in c("::ffff:", "::")) {
    wrapped <- addr_classify(addr_pton(paste0(prefix, quads)))
    rows <- field(wrapped, "embeddings")
    # `::0.0.0.0` and `::0.0.0.1` are the carve-out and extract nothing.
    extracted <- vapply(rows, vec_size, integer(1L)) == 1L
    through <- vapply(
      rows[extracted],
      function(row) as.character(field(row, "category")),
      character(1L)
    )
    expect_equal(
      through, as.character(direct)[extracted],
      info = prefix
    )
  }
})

test_that("the wrapper's own record is not the embedded address's", {
  # The other half of the invariant, and the reason raddr keeps two facts where
  # the CVEs kept one. Collapsing these is the SSRF class in docs/research/04.
  outer <- addr_classify(addr_pton("::ffff:127.0.0.1"))
  inner <- addr_classify(addr_pton("127.0.0.1"))

  expect_equal(field(outer, "block"), "::ffff:0:0/96")
  expect_equal(field(inner, "block"), "127.0.0.0/8")
  expect_equal(as.character(field(outer, "category")), "protocol")
  expect_equal(as.character(field(inner, "category")), "loopback")

  # And the loopback fact is not lost -- it is reported where it belongs.
  rows <- field(outer, "embeddings")[[1L]]
  expect_equal(as.character(field(rows, "category")), "loopback")
  expect_equal(field(rows, "address"), addr_pton("127.0.0.1"))
})

test_that("the same 128 bits classify alike whatever the literal said", {
  # The root cause behind CVE-2024-29415 and six more: Node's URL parser
  # normalizes `::ffff:169.254.169.254` to the hex form while the range check
  # reads only the dotted one, so two spellings of one value take two paths.
  spellings <- c(
    "::ffff:169.254.169.254", "::ffff:a9fe:a9fe", "::FFFF:A9FE:A9FE",
    "0000:0000:0000:0000:0000:ffff:169.254.169.254"
  )
  rows <- field(addr_classify(addr_pton(spellings)), "embeddings")
  for (i in seq_along(spellings)) {
    expect_equal(rows[[i]], rows[[1L]], info = spellings[[i]])
  }
  expect_equal(format(rows[[1L]]),
               "ipv4_mapped/embedded 169.254.169.254 link_local")
})

test_that("the recursion is one level deep, and stops on its own", {
  # An extracted address is IPv4, and the only IPv4 row in the overlay --
  # 192.88.99.0/24 -- has no geometry, so the inner classification finds no
  # kind and extracts nothing. There is no depth guard because none is needed.
  outer <- c("2002:c058:6301::", "::ffff:192.88.99.1", "64:ff9b::c058:6301")
  for (literal in outer) {
    inner <- addr_classify(field(embedded_of(literal), "address"))
    expect_true(is.na(field(inner, "embedded_kind")), info = literal)
    expect_equal(vec_size(field(inner, "embeddings")[[1L]]), 0L, info = literal)
  }
})

# --- addr_global_reachability() ----------------------------------------------

test_that("each registry layer answers in its own terms", {
  # The two halves of the rule, and the case each one exists for. Without the
  # special-purpose column 192.0.0.9 takes a MUST-drop it does not deserve;
  # without `category = global` the address-space layer has nothing to say
  # about 8.8.8.8 at all.
  expect_identical(
    addr_global_reachability(addr_pton(c(
      "8.8.8.8", "192.0.0.9", "127.0.0.1", "224.0.0.1", "192.88.99.1"
    ))),
    c(TRUE, TRUE, FALSE, FALSE, NA)
  )

  # One rule, both families.
  expect_identical(
    addr_global_reachability(addr_pton(c(
      "2001:4860:4860::8888", "fe80::1", "fc00::1", "2002:c058:6301::"
    ))),
    c(TRUE, FALSE, FALSE, NA)
  )
})

test_that("where the special-purpose layer answered, it is IANA's column", {
  # Not a re-derivation: the same value the record carries, unmodified.
  a <- addr_pton(c(
    "127.0.0.1", "192.0.0.9", "192.0.0.170", "fe80::1", "64:ff9b::1", "100::1"
  ))
  cl <- addr_classify(a)
  at <- field(cl, "registry") %in% "special_purpose"

  expect_true(all(at))
  expect_identical(
    addr_global_reachability(cl),
    field(cl, "globally_reachable")
  )
})

test_that("the NA tier is exactly the blocks IANA left open", {
  # The docs claim one block, measured. If IANA ever fills it in, or a new row
  # arrives with no policy, this is where that shows up rather than in a
  # consumer silently reading NA as FALSE.
  reg <- addr_registry()
  open <- reg[is.na(reg$globally_reachable), "block"]

  # Four rows across both families, and they are open for three unrelated
  # reasons -- two withdrawn blocks, one whose answer follows the embedded IPv4
  # and one whose relay advertisement is per-deployment. None of them may be
  # read as FALSE.
  expect_identical(
    open,
    c("192.88.99.0/24", "2001::/32", "2001:10::/28", "2002::/16")
  )

  # The measured claim the rule is written against is about IPv4 specifically:
  # exactly one block leaves the question open there.
  expect_identical(reg[is.na(reg$globally_reachable) & reg$space == "v4",
                       "block"], "192.88.99.0/24")

  # And its 6to4 image one level down, which is the reason the tier is not
  # hypothetical.
  expect_true(is.na(addr_global_reachability(addr_pton("192.88.99.1"))))
  expect_true(is.na(addr_global_reachability(addr_pton("2002:c058:6301::"))))
})

test_that("every IPv4 /8 gets an answer from one layer or the other", {
  # The address-space layer covers all 256, so no ordinary IPv4 address can
  # fall through both layers and read NA for want of a row.
  eights <- addr_pton(sprintf("%d.0.0.1", 0:255))
  got <- addr_global_reachability(eights)

  expect_length(got, 256L)
  expect_false(anyNA(got))
  expect_identical(sum(got), 220L)
})

test_that("the accessor takes an address, a classification or an embedding", {
  a <- addr_pton("64:ff9b::a9fe:a9fe")

  # The outer block is globally reachable and the IPv4 inside it is not. Both
  # facts, neither collapsed into the other.
  expect_true(addr_global_reachability(a))
  expect_false(addr_global_reachability(addr_embeddings(a)[[1L]]))

  expect_identical(
    addr_global_reachability(addr_classify(a)),
    addr_global_reachability(a)
  )

  # Teredo's two rows are answered independently -- a private server with a
  # global client is two different answers in one address, and reducing them to
  # one is the decision raddr does not make.
  rows <- addr_embeddings(addr_pton("2001:0:a00:1:8000:63bf:f7ff:f7f7"))[[1L]]
  expect_identical(as.character(field(rows, "role")), c("server", "client"))
  expect_identical(addr_global_reachability(rows), c(FALSE, TRUE))
})

test_that("it agrees with the fact the code layer already graded on", {
  # The MUST rules fire on an affirmative FALSE and nowhere else, so the
  # exported accessor and the internal grading cannot be allowed to drift.
  literals <- c(
    "64:ff9b::a9fe:a9fe",    # non-global embedded: the rule fires
    "64:ff9b::c01f:c401",    # 192.31.196.1, an AMT carve-out IANA marks global
    "2002:c058:6301::"       # the NA tier: no rule may fire
  )
  a <- addr_pton(literals)
  inner <- lapply(addr_embeddings(a), addr_global_reachability)

  expect_identical(unlist(inner), c(FALSE, TRUE, NA))

  fired <- vapply(
    literals,
    function(literal) {
      "nat64_wk_embedded_not_global" %in% codes_of(literal)[[1L]]
    },
    logical(1)
  )
  expect_identical(unname(fired), c(TRUE, FALSE, FALSE))
})

test_that("it is a fact accessor, not a verdict, and refuses a raddr_parse", {
  expect_error(
    addr_global_reachability(addr_parse("127.0.0.1")),
    class = "raddr_error_type"
  )
  expect_error(
    addr_global_reachability("127.0.0.1"),
    class = "raddr_error_type"
  )

  expect_identical(addr_global_reachability(addr_pton(character())), logical())
  expect_true(is.na(addr_global_reachability(addr_pton(NA_character_))))
})

# --- the reserved u-byte (RFC 6052 section 2.2) ------------------------------

test_that("a non-zero reserved u-byte is reported, and changes no reading", {
  # Section 2.2 reserves bits 64-71 and says they MUST be set to zero. Section
  # 2.3 says to remove that octet before reading the embedded address, which is
  # what the two-segment geometry does -- so the violation is about the
  # container, and the extracted address must come back identical either way.
  clean <- "64:ff9b:1:c000:2:2100::"
  dirty <- "64:ff9b:1:c000:ff02:2100::"

  expect_false("nat64_u_byte_nonzero" %in% codes_of(clean)[[1L]])
  expect_true("nat64_u_byte_nonzero" %in% codes_of(dirty)[[1L]])

  expect_equal(
    field(addr_embeddings(addr_pton(dirty))[[1L]], "address"),
    field(addr_embeddings(addr_pton(clean))[[1L]], "address")
  )
  expect_equal(
    field(addr_embeddings(addr_pton(dirty))[[1L]], "address"),
    addr_pton("192.0.2.33")
  )
})

test_that("the well-known prefix cannot violate the u-byte", {
  # Under 64:ff9b::/96 the reserved octet is INSIDE the prefix, so it is zero by
  # construction and the rule is unreachable there. Asserted rather than
  # assumed: if a prefix at another length is ever added, this is what says the
  # reasoning has to be redone.
  every <- addr_pton(sprintf("64:ff9b::%x:%x", 0:255, 0:255))
  fired <- vapply(
    field(addr_classify(every), "codes"),
    function(codes) "nat64_u_byte_nonzero" %in% codes,
    logical(1)
  )
  expect_false(any(fired))

  # And the octet the rule reads is genuinely inside that prefix.
  expect_true(addr_within(addr_pton("64:ff9b::ffff:ffff"), "64:ff9b::/96"))
})

test_that("the u-byte rule is graded must and fires on no other mechanism", {
  entry <- addr_codes_registry()
  entry <- entry[entry$code == "nat64_u_byte_nonzero", ]
  expect_identical(entry$strength, "must")
  expect_identical(entry$layer, "classify")
  expect_identical(entry$rfc, "RFC 6052 section 2.2")

  # The same bits set under a mechanism that is not NAT64 draw nothing: the
  # reservation is RFC 6052's, and it binds IPv4-embedded IPv6 addresses only.
  others <- addr_pton(c(
    "2002:c000:201:ff00::",              # 6to4
    "2001:0:4136:e378:ff00:63bf:3fff:fdd2", # Teredo
    "::ffff:192.0.2.33"                   # IPv4-mapped
  ))
  fired <- vapply(
    field(addr_classify(others), "codes"),
    function(codes) "nat64_u_byte_nonzero" %in% codes,
    logical(1)
  )
  expect_false(any(fired))
})
