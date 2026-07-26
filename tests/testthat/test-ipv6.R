# The IPv6 dialects. See docs/architecture.md sections 3.5 and 5.1.

# --- the divergence table ----------------------------------------------------
#
# Section 3.5, the IPv6 counterpart of section 3.3's table. Spelled out here
# rather than read from the fixture, because if this table ever changes the diff
# should be impossible to miss.

test_that("the section 3.5 divergence table holds", {
  no <- NA_character_
  input <- c(
    "::1", "00001::", "::1.2.3.04", "fe80:abcd::1",
    "fe80::1%lo0", "1.2.3.4", "[::1]"
  )
  one <- "0000:0000:0000:0000:0000:0000:0000:0001"
  wide <- "0001:0000:0000:0000:0000:0000:0000:0000"
  quad <- "0000:0000:0000:0000:0000:0000:0102:0304"
  ll <- "fe80:abcd:0000:0000:0000:0000:0000:0001"
  bare <- "fe80:0000:0000:0000:0000:0000:0000:0001"

  expected <- list(
    strict = c(one, no, no, ll, no, "1.2.3.4", no),
    whatwg = c(one, no, no, ll, no, "1.2.3.4", no),
    pton = c(one, wide, quad, ll, paste0(bare, "%lo0"), "1.2.3.4", no),
    aton = c(no, no, no, no, no, "1.2.3.4", no),
    getaddrinfo = c(
      one, wide, quad, paste0(bare, "%43981"),
      paste0(bare, "%lo0"), "1.2.3.4", no
    ),
    curl = c(one, wide, quad, ll, paste0(bare, "%lo0"), "1.2.3.4", no)
  )

  for (dialect in names(expected)) {
    expect_identical(
      format(dialect_fn(dialect)(input)),
      expected[[dialect]],
      label = dialect
    )
  }
})

# --- the measured dialects, against the recorded oracle ----------------------
#
# data-raw/oracle-ipv6.py and data-raw/oracle-ipv6.R regenerate this fixture
# from Apple libc, from Python's ipaddress and from ada. If a libc upgrade
# changes a row, this fails and the model gets revisited rather than silently
# drifting.
#
# The fixture asks libc about AF_INET6 only, so a colon-free literal is recorded
# as a rejection whatever raddr's family-agnostic dialects make of it. Such
# rows are the IPv4 oracle's business and are filtered out here.

ipv6_oracle <- function() {
  oracle <- read.csv(
    test_path("fixtures", "ipv6-oracle.csv"),
    colClasses = "character",
    na.strings = NULL
  )
  oracle$literal <- unescape_control(oracle$input)
  oracle[grepl(":", oracle$literal, fixed = TRUE), ]
}

# The zone travels in its own field, so the oracle is compared against the
# address alone and the zone is asserted separately below.
address_only <- function(x) sub("%.*$", "", format(x))

test_that("aton has no IPv6 reading at all", {
  # Measured rather than assumed: both compositions in section 3.2 lean on it.
  oracle <- ipv6_oracle()
  expect_true(all(!nzchar(oracle$aton)))
  expect_true(all(is.na(addr_aton(oracle$literal))))
})

test_that("whatwg matches ada", {
  oracle <- ipv6_oracle()
  # "-" marks a row the oracle could not measure, which data-raw/oracle-ipv6.R
  # explains: ada answers about a URL, and the URL layer strips whitespace
  # before the host parser runs.
  keep <- oracle$whatwg != "-"
  expected <- oracle$whatwg[keep]
  expected[!nzchar(expected)] <- NA_character_
  expect_identical(address_only(addr_whatwg(oracle$literal[keep])), expected)
})

test_that("strict matches Python's ipaddress, except about the zone ID", {
  oracle <- ipv6_oracle()
  # raddr's `strict` is the RFC 4291 grammar, which has no zone ID (section
  # 3.5). Python and Go accept one; Rust does not. Every row where the two
  # disagree is a row carrying a "%", and there are no others.
  zoned <- grepl("%", oracle$literal, fixed = TRUE)
  expect_true(all(is.na(addr_strict(oracle$literal[zoned]))))

  expected <- oracle$pyip[!zoned]
  expected[!nzchar(expected)] <- NA_character_
  expect_identical(address_only(addr_strict(oracle$literal[!zoned])), expected)
})

test_that("the two paper dialects agree completely about IPv6", {
  # Which is the opposite of the IPv4 picture, where they are the headline
  # divergence. All of the IPv6 divergence is on the reality side.
  oracle <- ipv6_oracle()
  expect_identical(
    format(addr_strict(oracle$literal)),
    format(addr_whatwg(oracle$literal))
  )
})

test_that("pton matches Apple libc, except for the interface-index fold", {
  oracle <- ipv6_oracle()
  # Apple `inet_pton` writes the interface index into the second hextet of a
  # link-local address when the zone ID names a resolvable interface. raddr does
  # not reproduce that, because it is not a function of the input: the same
  # string means different bits on a machine with a different interface table,
  # and raddr is pure and offline (section 3.5). The rows are named here rather
  # than filtered by a pattern, so that a change to the set is visible.
  folded <- c(
    "fe80::1%lo0", "fe80::1%en0", "fe80:abcd::1%lo0",
    "fe80::1:2:3:4%lo0", "fe80::%lo0", "fe80:abcd::1%1"
  )
  keep <- !oracle$literal %in% folded
  expected <- oracle$pton[keep]
  expected[!nzchar(expected)] <- NA_character_
  expect_identical(address_only(addr_pton(oracle$literal[keep])), expected)

  # And the fold rows still parse; it is only the bits that differ.
  expect_false(any(is.na(addr_pton(folded))))
})

test_that("getaddrinfo matches Apple libc bit for bit", {
  oracle <- ipv6_oracle()
  expected <- oracle$getaddrinfo
  expected[!nzchar(expected)] <- NA_character_
  expect_identical(address_only(addr_getaddrinfo(oracle$literal)), expected)
})

# --- the core parser: hextets and the "::" elision ---------------------------

test_that("the elision expands at either end and in the middle", {
  expect_identical(
    format(addr_strict(c("::", "::1", "1::", "1::8", "1:2::7:8"))),
    c(
      "0000:0000:0000:0000:0000:0000:0000:0000",
      "0000:0000:0000:0000:0000:0000:0000:0001",
      "0001:0000:0000:0000:0000:0000:0000:0000",
      "0001:0000:0000:0000:0000:0000:0000:0008",
      "0001:0002:0000:0000:0000:0000:0007:0008"
    )
  )
})

test_that("the elision must stand for at least one group", {
  # Seven groups plus "::" is fine; eight plus "::" is not, because the groups
  # are already spoken for.
  expect_false(is.na(addr_strict("1:2:3:4:5:6:7::")))
  expect_false(is.na(addr_strict("::1:2:3:4:5:6:7")))
  expect_true(is.na(addr_strict("1:2:3:4:5:6:7:8::")))
  expect_true(is.na(addr_strict("::1:2:3:4:5:6:7:8")))
})

test_that("there may be only one elision", {
  expect_true(all(is.na(addr_strict(c("1::2::3", "::1::", ":::", "::::")))))
})

test_that("a stray colon is a rejection", {
  strays <- c(":", ":1", "1:", ":1:2", "1:2:", "1:::2", "::1:", ":1::")
  expect_true(all(is.na(addr_strict(strays))))
  expect_true(all(is.na(addr_pton(strays))))
})

test_that("without an elision there must be exactly eight groups", {
  expect_false(is.na(addr_strict("1:2:3:4:5:6:7:8")))
  expect_true(is.na(addr_strict("1:2:3:4:5:6:7")))
  expect_true(is.na(addr_strict("1:2:3:4:5:6:7:8:9")))
})

test_that("a hextet is four hex digits on paper, four significant to libc", {
  # [verified 2026-07-26] against Apple libc: it puts no width limit on leading
  # zeros, exactly as its IPv4 reading does not.
  expect_true(all(is.na(addr_strict(c("00001::", "01234::", "0abcd::")))))
  expect_identical(
    format(addr_pton(c("00001::", "01234::", "0000000000001::"))),
    c(
      "0001:0000:0000:0000:0000:0000:0000:0000",
      "1234:0000:0000:0000:0000:0000:0000:0000",
      "0001:0000:0000:0000:0000:0000:0000:0000"
    )
  )

  # Four *significant* digits is still the cap, so a fifth is a rejection under
  # every dialect.
  wide <- c("12345::", "abcde::", "ffff1::", "0000000000012345::")
  expect_true(all(is.na(addr_pton(wide))))
  expect_true(all(is.na(addr_strict(wide))))
})

test_that("hextets are case-insensitive and non-hex digits are rejected", {
  expect_identical(
    format(addr_strict("FE80::1")),
    format(addr_strict("fe80::1"))
  )
  expect_true(all(is.na(addr_strict(c("::g", "::1g", "::-1", "::+1")))))
})

test_that("brackets belong to the URL layer, not the address layer", {
  # The WHATWG host parser is handed the text between the brackets, and libc
  # rejects them outright [verified 2026-07-26].
  brackets <- c("[::1]", "[::1", "::1]")
  for (dialect in c("strict", "whatwg", "pton", "getaddrinfo", "curl")) {
    expect_true(all(is.na(dialect_fn(dialect)(brackets))), label = dialect)
  }
})

test_that("whitespace is rejected outright, unlike in the IPv4 dialects", {
  # inet_aton's stop-at-whitespace quirk has no IPv6 counterpart, because
  # inet_aton has no IPv6 reading.
  space <- c("::1 ", " ::1", "::1\t", "::1 x", "::1junk")
  expect_true(all(is.na(addr_pton(space))))
  expect_true(all(is.na(addr_getaddrinfo(space))))
  expect_true(all(is.na(addr_curl(space))))
})

# --- the dotted-quad tail ----------------------------------------------------

test_that("the tail is read under the dialect's own IPv4 rules", {
  # This is the finding, and the reason no new number parser appears in
  # R/ipv6.R: the tail is not a grammar of its own.
  expect_identical(
    format(addr_strict(c("::1.2.3.4", "1:2:3:4:5:6:1.2.3.4"))),
    c(
      "0000:0000:0000:0000:0000:0000:0102:0304",
      "0001:0002:0003:0004:0005:0006:0102:0304"
    )
  )

  # Leading zeros: rejected on paper, accepted by libc, at any width -- the
  # same split as the standalone IPv4 dialects [verified 2026-07-26].
  zeros <- c("::1.2.3.04", "::01.2.3.4", "::00000000001.2.3.4", "::1.02.3.4")
  expect_true(all(is.na(addr_strict(zeros))))
  expect_identical(
    format(addr_pton(zeros)),
    rep("0000:0000:0000:0000:0000:0000:0102:0304", length(zeros))
  )
})

test_that("the tail is four decimal parts and nothing else", {
  # No hex, no octal, no short form, no trailing dot -- none of the WHATWG IPv4
  # leniencies reach it, under any dialect.
  bad <- c("::1.2.3", "::1.2.3.4.5", "::1.2.3.", "::.1.2.3", "::0x1.2.3.4",
           "::1.2.3.256", "::1.2.3.999", "::1.2.3.4:5")
  expect_true(all(is.na(addr_strict(bad))))
  expect_true(all(is.na(addr_whatwg(bad))))
  expect_true(all(is.na(addr_pton(bad))))
})

test_that("the tail occupies the last two groups, so six may precede it", {
  expect_false(is.na(addr_strict("1:2:3:4:5:6:1.2.3.4")))
  expect_true(is.na(addr_strict("1:2:3:4:5:6:7:1.2.3.4")))
})

test_that("a 4-in-6 literal is its own family, whatever it was spelled as", {
  # Go's net/netip lesson (section 5.1): the family is decided by the bits, so
  # the hex spelling and the dotted spelling agree with each other and neither
  # equals the bare IPv4 address.
  mapped <- addr_strict(c("::ffff:127.0.0.1", "::ffff:7f00:1"))
  expect_identical(
    as.character(addr_family(mapped)),
    c("v6_4in6", "v6_4in6")
  )
  expect_true(mapped[[1]] == mapped[[2]])
  expect_false(mapped[[1]] == addr_strict("127.0.0.1"))

  # The deprecated v4-compatible form sits in ::/96 and is not 4-in-6.
  expect_identical(
    as.character(addr_family(addr_strict(c("::1.2.3.4", "::", "::1")))),
    rep("v6", 3)
  )
})

# --- the zone ID -------------------------------------------------------------

test_that("the paper dialects have no zone ID at all", {
  # RFC 4291's grammar does not admit one, and the WHATWG parser sends "%" to
  # its catch-all. Python and Go accept a zone; Rust does not; the paper is the
  # tie-break (section 3.5).
  expect_true(all(is.na(addr_strict(c("fe80::1%lo0", "::1%1", "fe80::1%")))))
  expect_true(all(is.na(addr_whatwg(c("fe80::1%lo0", "::1%1", "fe80::1%")))))
})

test_that("the reality dialects keep the zone beside the bits, never inside", {
  a <- addr_pton(c("fe80::1%lo0", "::1%lo0", "2001:db8::1%lo0", "fe80::1"))
  expect_identical(addr_zone(a), c("lo0", "lo0", "lo0", NA_character_))
  # The bits are the same with and without the zone.
  expect_true(a[[1]] == addr_pton("fe80::1"))
})

test_that("a zone ID is accepted on any address, and may be empty or bogus", {
  # [verified 2026-07-26] against Apple libc, which resolves nothing at parse
  # time and so has no opinion about whether the interface exists.
  a <- addr_pton(c("fe80::1%", "fe80::1%bogus0", "fe80::1%99999999999",
                   "1:2:3:4:5:6:7:8%lo0", "::ffff:1.2.3.4%lo0"))
  expect_false(any(is.na(a)))
  expect_identical(
    addr_zone(a),
    c("", "bogus0", "99999999999", "lo0", "lo0")
  )
})

test_that("a second % is a rejection, and a bare zone is not an address", {
  expect_true(is.na(addr_pton("fe80::1%lo0%en0")))
  expect_true(is.na(addr_pton("%lo0")))
})

test_that("the zone does not participate in equality (O2)", {
  a <- addr_pton("fe80::1%lo0")
  b <- addr_pton("fe80::1%en0")
  expect_true(a == b)
  expect_false(addr_zone(a) == addr_zone(b))
  expect_identical(length(unique(c(a, b))), 1L)
})

test_that("getaddrinfo lifts an embedded scope out of a link-local address", {
  # The second leak in the section 3.2 composition, and IPv6-only. Apple's
  # getaddrinfo runs the KAME embedding in reverse on fe80::/10: the second
  # hextet becomes the scope ID and is cleared from the bytes, zone ID or no
  # zone ID [verified 2026-07-26]. Unlike inet_pton's forward fold, this is a
  # pure function of the input, so raddr models it.
  a <- addr_getaddrinfo("fe80:abcd::1")
  expect_identical(format(a), "fe80:0000:0000:0000:0000:0000:0000:0001%43981")
  expect_identical(
    format(addr_pton("fe80:abcd::1")),
    format(addr_curl("fe80:abcd::1"))
  )
  expect_false(format(addr_pton("fe80:abcd::1")) == format(a))

  # An explicit zone wins, but the hextet is cleared either way.
  expect_identical(
    format(addr_getaddrinfo("fe80:abcd::1%1")),
    "fe80:0000:0000:0000:0000:0000:0000:0001%1"
  )
})

test_that("the scope lift is fe80::/10 and nothing else", {
  # [verified 2026-07-26]: fe80 through febf, and not the multicast link-local
  # scopes, which is Apple's IN6_IS_ADDR_LINKLOCAL and not a broader rule.
  lifted <- c("fe80:1::1", "fe81:1::1", "fe8f:1::1", "fe90:1::1", "fea0:1::1",
              "febf:1::1")
  expect_true(all(!is.na(addr_zone(addr_getaddrinfo(lifted)))))

  untouched <- c("fe7f:1::1", "fec0:1::1", "ff02:1::1", "2001:abcd::1")
  a <- addr_getaddrinfo(untouched)
  expect_true(all(is.na(addr_zone(a))))
  expect_identical(format(a), format(addr_pton(untouched)))
})

test_that("a zero second hextet leaves the address without a zone", {
  # Scope zero is the absence of a scope, so it must not become the string "0"
  # -- which is what an explicit "%0" means.
  expect_true(is.na(addr_zone(addr_getaddrinfo("fe80::1"))))
  expect_identical(addr_zone(addr_getaddrinfo("fe80::1%0")), "0")
})

test_that("getaddrinfo's whitespace gate covers the address, not the zone", {
  # [verified 2026-07-26]: "fe80::1%lo0 " is accepted and "fe80::1 %lo0" is not.
  expect_false(is.na(addr_getaddrinfo("fe80::1%lo0 ")))
  expect_identical(addr_zone(addr_getaddrinfo("fe80::1%lo0 ")), "lo0 ")
  expect_true(is.na(addr_getaddrinfo("fe80::1 %lo0")))
})

# --- the 0x80000000 collision, at every word position ------------------------

test_that("an address parses equal to itself in every word position", {
  # Section 5.1.1. A word holding the pattern 0x80000000 is NA_integer_ at the
  # R level, and it means the pattern rather than missingness. test-address.R
  # asserts this on constructed values; here it is asserted through the parser.
  collide <- c("8000::", "0:0:8000::", "::8000:0:0:0", "::8000:0")
  a <- addr_strict(collide)
  expect_false(any(is.na(a)))
  expect_true(all(a == a))
  expect_identical(length(unique(a)), 4L)
})

# --- the families sort and compare as section 5.1.2 says ---------------------

test_that("IPv4 sorts before IPv6, and 4-in-6 sorts with IPv6 (O3)", {
  mixed <- c(addr_strict("255.255.255.255"), addr_strict("::"),
             addr_strict("::ffff:1.2.3.4"), addr_strict("0.0.0.0"))
  sorted <- sort(mixed)
  expect_identical(
    as.character(addr_family(sorted)),
    c("v4", "v4", "v6", "v6_4in6")
  )
})

# --- the vectorized engine agrees with itself one row at a time --------------

test_that("the parse is per-row, not per-vector", {
  oracle <- ipv6_oracle()
  one_at_a_time <- vapply(
    oracle$literal,
    function(s) format(addr_pton(s)),
    character(1),
    USE.NAMES = FALSE
  )
  expect_identical(format(addr_pton(oracle$literal)), one_at_a_time)
})

test_that("empty and missing input come back empty and missing", {
  expect_identical(length(addr_pton(character())), 0L)
  expect_true(is.na(addr_pton(NA_character_)))
  expect_true(is.na(addr_pton("")))
})
