# The transition-prefix overlay. See docs/architecture.md sections 7.2 and 8.1.
#
# The bit offsets here are transcribed from RFCs by hand, which is exactly the
# kind of data that is wrong in a way no amount of reading catches. So these
# tests check the geometry against RFC 6052's own rules -- segments totalling
# 32 bits, ordered, disjoint, and clear of the reserved u-byte -- rather than
# only restating the numbers a second time.

test_that("the overlay covers the wrapper matrix and nothing else", {
  prefixes <- addr_transition_registry()

  expect_s3_class(prefixes, "data.frame")
  expect_named(prefixes, c("block", "kind", "rfc", "note"))
  expect_setequal(
    prefixes$kind,
    c(
      "ipv4_mapped", "ipv4_compatible", "ipv4_translated",
      "6to4", "teredo", "6to4_relay_anycast", "nat64_wk", "nat64_local"
    )
  )
  expect_equal(anyDuplicated(prefixes$block), 0L)
  expect_true(all(nzchar(prefixes$rfc)))
})

test_that("every overlay prefix is a well-formed block", {
  prefixes <- addr_transition_registry()

  expect_true(all(grepl("/", prefixes$block, fixed = TRUE)))
  base <- addr_strict(sub("/.*", "", prefixes$block))
  expect_false(anyNA(addr_family(base)))

  plen <- as.integer(sub(".*/", "", prefixes$block))
  width <- ifelse(addr_family(base) == "v4", 32L, 128L)
  expect_true(all(plen >= 0L & plen <= width))
})

test_that("the overlay agrees with the IANA table where they overlap", {
  prefixes <- addr_transition_registry()
  iana <- addr_registry()

  shared <- intersect(prefixes$block, iana$block)
  # The overlay annotates the IANA table far more than it extends it.
  expect_true(length(shared) >= 5L)

  # And the two forms it annotates hardest are exactly the ones IANA declined
  # to answer for -- the overlay exists to pick up where the table stops.
  withheld <- iana$block[
    is.na(iana$globally_reachable) & is.na(iana$termination_date)
  ]
  expect_setequal(withheld, c("2001::/32", "2002::/16"))
  expect_true(all(withheld %in% prefixes$block))
  expect_setequal(
    prefixes$kind[prefixes$block %in% withheld],
    c("teredo", "6to4")
  )
})

test_that("every embedded address totals 32 bits, ordered and disjoint", {
  emb <- addr_transition_registry("embeddings")
  key <- paste(emb$kind, emb$role, emb$prefix_len)

  for (k in unique(key)) {
    segs <- emb[key == k, ]
    segs <- segs[order(segs$offset), ]

    expect_equal(sum(segs$length), 32L, info = k)
    expect_true(all(segs$offset >= 0L), info = k)
    expect_true(all(segs$offset + segs$length <= 128L), info = k)

    if (nrow(segs) > 1L) {
      # Disjoint, and in most-significant-first order as stored.
      ends <- segs$offset + segs$length
      expect_true(all(ends[-nrow(segs)] <= segs$offset[-1]), info = k)
      expect_identical(segs$offset, emb$offset[key == k], info = k)
    }
  }
})

test_that("no embedded segment overlaps RFC 6052's reserved u-byte", {
  emb <- addr_transition_registry("embeddings")
  u_start <- 64L
  u_end <- 72L

  overlaps <- emb$offset < u_end & (emb$offset + emb$length) > u_start
  expect_false(
    any(overlaps),
    info = paste(
      "segments straddling bits 64-71:",
      paste(emb$kind[overlaps], emb$prefix_len[overlaps], collapse = ", ")
    )
  )
})

test_that("NAT64 covers all six RFC 6052 prefix lengths, and only those", {
  emb <- addr_transition_registry("embeddings")
  nat64 <- emb[emb$kind == "nat64", ]

  expect_setequal(unique(nat64$prefix_len), c(32L, 40L, 48L, 56L, 64L, 96L))

  # The embedded address starts immediately after the prefix -- except at /64,
  # where the reserved u-byte sits between them. That single exception is the
  # whole reason the geometry cannot be computed from the prefix length alone.
  for (plen in unique(nat64$prefix_len)) {
    segs <- nat64[nat64$prefix_len == plen, ]
    first <- min(segs$offset)
    expected <- if (plen == 64L) 72L else plen
    expect_equal(first, expected, info = paste("/", plen))
  }

  # Four of the six are split by the u-byte; /32 and /96 clear it entirely.
  split <- vapply(
    split(nat64, nat64$prefix_len), nrow, integer(1)
  )
  expect_equal(as.integer(split[c("32", "96")]), c(1L, 1L))
  expect_equal(as.integer(split[c("40", "48", "56")]), c(2L, 2L, 2L))
  expect_equal(as.integer(split[["64"]]), 1L)
})

test_that("Teredo carries two addresses and complements exactly one", {
  emb <- addr_transition_registry("embeddings")
  teredo <- emb[emb$kind == "teredo", ]

  expect_setequal(teredo$role, c("server", "client"))
  expect_false(teredo$complement[teredo$role == "server"])
  expect_true(teredo$complement[teredo$role == "client"])

  # It is the only complemented field in the overlay.
  expect_equal(sum(emb$complement), 1L)
  expect_type(emb$complement, "logical")
})

test_that("every embedding resolves to a prefix, a length, or ISATAP", {
  prefixes <- addr_transition_registry()
  emb <- addr_transition_registry("embeddings")

  # ISATAP and NAT64 are the two forms with no fixed prefix of their own:
  # ISATAP is an interface-identifier pattern under any /64, and a
  # network-specific NAT64 prefix may be any prefix of a permitted length.
  unanchored <- c("isatap", "nat64")
  expect_setequal(
    setdiff(emb$kind, unanchored),
    setdiff(prefixes$kind, c("6to4_relay_anycast", "nat64_wk", "nat64_local"))
  )

  # The relay anycast block classifies but embeds nothing.
  expect_false("6to4_relay_anycast" %in% emb$kind)

  # The two named NAT64 prefixes are covered by the nat64 geometry.
  named <- prefixes$block[prefixes$kind %in% c("nat64_wk", "nat64_local")]
  named_len <- as.integer(sub(".*/", "", named))
  expect_true(all(named_len %in% emb$prefix_len[emb$kind == "nat64"]))
})

test_that("the ISATAP interface identifier admits both permitted forms", {
  iid <- raddr:::isatap_iid

  expect_equal(iid$offset, 64L)
  expect_equal(iid$length, 32L)
  # RFC 5214 section 6.1: 0000:5efe, or 0200:5efe when built from a globally
  # unique IPv4. The mask must fold the second onto the first and nothing else.
  expect_setequal(iid$permitted, c(0x00005efeL, 0x02005efeL))
  expect_true(all(bitwAnd(iid$permitted, iid$mask) == iid$value))
  expect_false(bitwAnd(0x03005efeL, iid$mask) == iid$value)
  expect_false(bitwAnd(0x00005effL, iid$mask) == iid$value)

  # The mask must not itself be an out-of-range literal: 0xfdffffff is a double
  # above 2^31, and bitwAnd() returns NA for it without complaint.
  expect_type(iid$mask, "integer")
  expect_false(anyNA(bitwAnd(iid$permitted, iid$mask)))
})

test_that("the overlay is stamped independently of the IANA snapshot", {
  version <- addr_transition_version()

  expect_type(version, "character")
  expect_length(version, 1L)
  expect_match(version, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_false(is.na(as.Date(version)))

  # Two tables, two reasons to change, two stamps. There is no
  # addr_transition_outdated(): the RFCs do not expire.
  expect_false(exists("addr_transition_outdated", asNamespace("raddr")))
})

test_that("addr_transition_registry() rejects an unknown table", {
  expect_error(addr_transition_registry("blocks"))
})
