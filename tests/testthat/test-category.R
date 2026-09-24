# raddr's block -> category map. See docs/architecture.md sections 5.3.2-5.3.4.
#
# These are section 5.3.4's four tests. Their job is to keep the map TOTAL and
# UNAMBIGUOUS over whatever the vendored registries currently contain, so that
# a registry update cannot quietly land a new block in `global`.

registry_rows <- function() {
  rbind(
    raddr_registry_data$blocks[c("block", "space", "name")],
    raddr_registry_data$space[c("block", "space", "name")]
  )
}

test_that("test 1: every registry block resolves to exactly one level", {
  rows <- registry_rows()
  map <- addr_category_map()

  # Total. This is the check that was asserted rather than measured until the
  # address-space pair landed, and it is the reason the map exists.
  unmapped <- setdiff(rows$block, map$block)
  expect_equal(unmapped, character(0))

  # Exactly one: a named vector cannot hold a block twice with two levels, so
  # duplicate keys are the failure to guard against.
  expect_equal(anyDuplicated(map$block), 0L)
  expect_true(all(map$category %in% raddr_category_levels))

  # And the map maps nothing that is not in a registry -- a stale entry left
  # behind by an upstream removal is as much a defect as a missing one.
  expect_equal(setdiff(map$block, rows$block), character(0))
})

test_that("test 2: every declared level is used by at least one block", {
  map <- addr_category_map()

  unused <- setdiff(raddr_category_levels, unique(map$category))
  expect_equal(unused, character(0))
  expect_length(raddr_category_levels, 19L)
})

test_that("test 2a: two levels need the address-space pair to exist", {
  # Recorded because section 5.3.2 asserted the levels were total over the 51
  # special-purpose blocks, and they never were. `multicast` and `global` have
  # no special-purpose block at all, so test 2 was unsatisfiable until the
  # address-space registries were vendored. This pins WHY the second pair is
  # load-bearing rather than convenient.
  special_only <- raddr_registry_data$blocks$block
  map <- addr_category_map()
  reachable <- unique(map$category[map$block %in% special_only])

  expect_false("multicast" %in% reachable)
  expect_false("global" %in% reachable)
  expect_false("unallocated" %in% reachable)
  expect_setequal(setdiff(raddr_category_levels, reachable),
                  c("multicast", "global", "unallocated"))
})

test_that("test 3: blocks sharing an IANA name resolve to the same level", {
  rows <- registry_rows()
  map <- addr_category_map()
  rows$category <- map$category[match(rows$block, map$block)]

  by_name <- split(rows, rows$name)
  offenders <- Filter(
    function(group) length(unique(group$category)) > 1L,
    by_name
  )
  offenders <- setdiff(names(offenders), raddr_category_name_splits)

  # An upstream name resolving to two levels is either a real distinction that
  # belongs in `raddr_category_name_splits` with a reason, or a mistake. It is
  # never allowed to pass silently.
  expect_equal(offenders, character(0))

  # The split list is empty today: `IPv4-IPv6 Translat.` was its only candidate
  # and both its blocks are `protocol` now that the mechanism moved to
  # `embedded_kind`. Kept so the name arithmetic stays a mechanical check.
  expect_equal(raddr_category_name_splits, character(0))
})

test_that("test 4: an unmapped row fails, never defaulting to global", {
  # The failure mode this is the whole defence against: a registry update adds
  # a block, nobody classifies it, and it silently reads as ordinary public
  # space. Simulated here, because the real event is an upstream change.
  rows <- registry_rows()
  invented <- rbind(
    rows,
    data.frame(
      block = "0100::/24", space = "v6", name = "Newly Assigned Thing",
      stringsAsFactors = FALSE
    )
  )
  map <- addr_category_map()

  unmapped <- setdiff(invented$block, map$block)
  expect_equal(unmapped, "0100::/24")

  # There is no default level and no fallthrough: `special` is an assignment,
  # not a catch-all, and `global` is what an unmapped block must never become.
  expect_false("0100::/24" %in% map$block)
})

test_that("the map is raddr's judgment, kept out of the IANA tables", {
  # Section 5.3.4: the map must not become a column of addr_registry(), whose
  # promise is the IANA data exactly as vendored.
  expect_false("category" %in% names(addr_registry()))
  expect_false("category" %in% names(addr_address_space()))

  expect_match(addr_category_version(), "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_false(identical(addr_category_version(), addr_registry_version()))
})

test_that("the five doubly-vendored blocks are mapped once and agree", {
  map <- addr_category_map()
  both <- intersect(
    raddr_registry_data$blocks$block, raddr_registry_data$space$block
  )

  expect_setequal(
    both,
    c("0.0.0.0/8", "10.0.0.0/8", "127.0.0.0/8", "fc00::/7", "fe80::/10")
  )
  for (block in both) {
    expect_equal(sum(map$block == block), 1L)
  }
  expect_equal(
    map$category[match(both, map$block)],
    c("this_network", "private", "loopback", "private", "link_local")
  )
})

test_that("the contested calls of section 5.3.2 are pinned", {
  map <- addr_category_map()
  level <- function(block) map$category[map$block == block]

  # Mechanisms are embedded_kind values, not categories. The outer level comes
  # from 5.3.2's own worked example: 64:ff9b::/96 is `protocol`, and the other
  # three wrapper prefixes are the same kind of thing.
  expect_equal(level("64:ff9b::/96"), "protocol")
  expect_equal(level("64:ff9b:1::/48"), "protocol")
  expect_equal(level("::ffff:0:0/96"), "protocol")
  expect_equal(level("2001::/32"), "protocol")
  expect_equal(level("2002::/16"), "protocol")

  # Addressing style, never reachability: 192.88.99.2/32 is Globally
  # Reachable = False and 192.88.99.0/24 has no policy values at all.
  expect_equal(level("192.88.99.2/32"), "anycast")
  expect_equal(level("192.31.196.0/24"), "anycast")
  expect_equal(level("2001:3::/32"), "anycast")

  # ULA is private, settled by the consumer (ssrfr ADR 0001 section 2.1).
  expect_equal(level("fc00::/7"), "private")

  # `special` is an assignment, not a fallthrough.
  expect_equal(level("5f00::/16"), "special")
  expect_equal(level("2001:20::/28"), "special")

  # RFC 1122's own term, and not `unspecified` -- only the /32 is that.
  expect_equal(level("0.0.0.0/8"), "this_network")
  expect_equal(level("0.0.0.0/32"), "unspecified")

  # `reserved` was deleted and must stay deleted: it means four different
  # things across the ecosystem and would shadow reserved_by_protocol.
  expect_false("reserved" %in% raddr_category_levels)
  expect_false("identifier" %in% raddr_category_levels)
})

test_that("unallocated names what three other tools get wrong", {
  map <- addr_category_map()
  level <- function(block) map$category[map$block == block]

  # Measured 2026-07-27: CPython ipaddress and R ipaddress both report this
  # space as is_reserved AND is_global = TRUE; ipaddr.js labels it `unicast`,
  # the same label it gives real global unicast. raddr says neither.
  expect_equal(level("4000::/3"), "unallocated")
  expect_equal(level("8000::/3"), "unallocated")
  expect_equal(level("::/8"), "unallocated")

  # fec0::/10 is the row the three tools disagree about most. It is currently
  # "Reserved by IETF"; its deprecating RFC 3879 stays in the address-space
  # notes column rather than becoming a level.
  expect_equal(level("fec0::/10"), "unallocated")
  space <- addr_address_space()
  expect_match(space$notes[space$block == "fec0::/10"], "RFC3879")
  expect_match(space$notes[space$block == "200::/7"], "RFC4048")

  # 2000::/3 is the only IPv6 block IANA assigns unicast from, so it is the
  # only IPv6 block that may be `global`.
  expect_equal(level("2000::/3"), "global")
  expect_equal(sum(map$category == "unallocated"), 16L)
})
