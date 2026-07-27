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
      "block", "name", "rfc", "category",
      "globally_reachable", "forwardable", "source", "destination",
      "reserved_by_protocol", "embedded_kind", "embeddings", "codes",
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
  # Nothing produces a non-empty embedding until the extractor lands, so the
  # type is exercised directly here.
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
