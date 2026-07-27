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
