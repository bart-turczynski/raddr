# The two renderers. See docs/architecture.md sections 5.1 and 6.2.
#
# RFC 5952 publishes no test vectors (O8), so raddr authors its own. The table
# below is organized by the RFC's own section numbers, and each row is a
# spelling of an address paired with the one canonical spelling of it. Where the
# RFC's prose gives an example, that example is the row.

# --- RFC 5952 section 4.1: leading zeros are suppressed ----------------------

test_that("4.1: leading zeros in a field are suppressed", {
  expect_identical(
    addr_format(addr_strict(c(
      "2001:0db8:0000:0000:0000:0000:0000:0001",
      "2001:db8:aaaa:bbbb:cccc:dddd:eeee:0001",
      "0001:0002:0003:0004:0005:0006:0007:0008"
    ))),
    c(
      "2001:db8::1",
      "2001:db8:aaaa:bbbb:cccc:dddd:eeee:1",
      "1:2:3:4:5:6:7:8"
    )
  )
})

test_that("4.1: an all-zero field is \"0\", never \"\"", {
  # The RFC is explicit that the field is not omitted, only shortened.
  expect_identical(
    addr_format(addr_strict("2001:db8:aaaa:bbbb:cccc:dddd:0000:0001")),
    "2001:db8:aaaa:bbbb:cccc:dddd:0:1"
  )
})

# --- RFC 5952 section 4.2.1: "::" is used wherever it can be -----------------

test_that("4.2.1: the zero run is compressed at either end and in the middle", {
  expect_identical(
    addr_format(addr_strict(c(
      "2001:db8:0:0:0:0:2:1",
      "0:0:0:0:0:0:0:0",
      "0:0:0:0:0:0:0:1",
      "1:0:0:0:0:0:0:0",
      "1:0:0:0:0:0:0:8"
    ))),
    c("2001:db8::2:1", "::", "::1", "1::", "1::8")
  )
})

test_that("4.2.1: a run reaching either edge leaves no stray colon", {
  expect_identical(
    addr_format(addr_strict(c("1:2:3:4:5:6:0:0", "0:0:3:4:5:6:7:8"))),
    c("1:2:3:4:5:6::", "::3:4:5:6:7:8")
  )
})

# --- RFC 5952 section 4.2.2: never "::" for a single field -------------------

test_that("4.2.2: a lone zero field is spelled out", {
  # The RFC's own example, and the reason the run length is tested against 2
  # rather than 1.
  expect_identical(
    addr_format(addr_strict("2001:db8:0:1:1:1:1:1")),
    "2001:db8:0:1:1:1:1:1"
  )
  expect_identical(
    addr_format(addr_strict("2001:0:1:2:3:4:5:6")),
    "2001:0:1:2:3:4:5:6"
  )
})

test_that("4.2.2: two separated lone zeros both stay spelled out", {
  expect_identical(
    addr_format(addr_strict("1:0:2:3:0:4:5:6")),
    "1:0:2:3:0:4:5:6"
  )
})

# --- RFC 5952 section 4.2.3: the longest run, and ties go left ---------------

test_that("4.2.3: the longest run is the one compressed", {
  # The RFC's own example: the run of three wins over the run of two, even
  # though the run of two comes first.
  expect_identical(
    addr_format(addr_strict("2001:0:0:1:0:0:0:1")),
    "2001:0:0:1::1"
  )
  expect_identical(
    addr_format(addr_strict("0:0:1:0:0:0:0:1")),
    "0:0:1::1"
  )
})

test_that("4.2.3: the first of two equally long runs wins", {
  expect_identical(
    addr_format(addr_strict(c(
      "1:0:0:2:0:0:3:4",
      "0:0:1:2:0:0:3:4",
      "1:2:0:0:3:4:0:0"
    ))),
    c("1::2:0:0:3:4", "::1:2:0:0:3:4", "1:2::3:4:0:0")
  )
})

# --- RFC 5952 section 4.3: lowercase -----------------------------------------

test_that("4.3: hex digits are lowercase whatever the input was", {
  expect_identical(
    addr_format(addr_strict(c("2001:DB8:AAAA::EEEE", "FE80::ABCD"))),
    c("2001:db8:aaaa::eeee", "fe80::abcd")
  )
})

# --- RFC 5952 section 5: the mixed form --------------------------------------

test_that("5: a 4-in-6 address renders in the mixed form", {
  # Both spellings are the same address and the same family (section 5.1), so
  # both render the same way.
  expect_identical(
    addr_format(addr_strict(c(
      "::ffff:192.0.2.1",
      "::ffff:c000:201",
      "::ffff:0.0.0.0",
      "::ffff:255.255.255.255"
    ))),
    c(
      "::ffff:192.0.2.1",
      "::ffff:192.0.2.1",
      "::ffff:0.0.0.0",
      "::ffff:255.255.255.255"
    )
  )
})

test_that("5: the mixed form is the family's, not the spelling's", {
  # The deprecated v4-compatible form sits in ::/96, is family v6, and so
  # renders as hex. raddr decides by the bits, never by how it was written.
  expect_identical(
    addr_format(addr_strict(c("::1.2.3.4", "::0102:0304"))),
    c("::102:304", "::102:304")
  )
})

test_that("5: the mixed form compresses its hex fields like any other", {
  # A 4-in-6 family with a prefix other than ::ffff: is only reachable through
  # the low-level constructor, but the renderer must not assume the prefix.
  expect_identical(
    addr_format(raddr_address(1L, 2L, 3L, 4L, "v6_4in6")),
    "0:1:0:2:0:3:0.0.0.4"
  )
  expect_identical(
    addr_format(raddr_address(0L, 0L, 0L, 16909060L, "v6_4in6")),
    "::1.2.3.4"
  )
})

# --- IPv4, the zone, and the missing address ---------------------------------

test_that("an IPv4 address is a dotted quad under both renderers", {
  a <- addr_strict(c("0.0.0.0", "192.0.2.1", "255.255.255.255"))
  expect_identical(addr_format(a), c("0.0.0.0", "192.0.2.1", "255.255.255.255"))
  expect_identical(addr_expand(a), addr_format(a))
})

test_that("the zone is appended by both renderers", {
  # Not a formality. CPython's ipaddress raises AddressValueError from
  # .exploded and .reverse_pointer on any address carrying a scope_id, because
  # the renderer re-parses str(self) -- zone included -- through a parser that
  # rejects it (section 3.5.2, verified on 3.9.6, 3.12.13 and 3.14.6). raddr's
  # renderers never re-parse: they read the fields and append the zone last.
  a <- addr_pton(c("fe80::1%lo0", "::ffff:192.0.2.1%en0", "fe80::1%"))
  expect_identical(
    addr_format(a),
    c("fe80::1%lo0", "::ffff:192.0.2.1%en0", "fe80::1%")
  )
  expect_identical(
    addr_expand(a),
    c(
      "fe80:0000:0000:0000:0000:0000:0000:0001%lo0",
      "0000:0000:0000:0000:0000:ffff:c000:0201%en0",
      "fe80:0000:0000:0000:0000:0000:0000:0001%"
    )
  )
})

test_that("a missing address renders as NA, zone or no zone", {
  expect_identical(addr_format(addr_strict(NA_character_)), NA_character_)
  expect_identical(addr_expand(addr_strict("nonsense")), NA_character_)
  expect_identical(
    addr_format(raddr_address(0L, 0L, 0L, 1L, NA_character_, "lo0")),
    NA_character_
  )
})

test_that("empty input comes back empty", {
  empty <- addr_strict(character())
  expect_identical(addr_format(empty), character())
  expect_identical(addr_expand(empty), character())
})

test_that("both renderers reject anything that is not an address", {
  expect_error(addr_format("::1"), class = "raddr_error_type")
  expect_error(addr_expand("::1"), class = "raddr_error_type")
})

# --- the 0x80000000 word, through the renderers ------------------------------

test_that("a word holding 0x80000000 renders as its bits", {
  # Section 5.1.1: NA_integer_ in a word means the pattern, not missingness, so
  # the renderers must widen rather than propagate NA.
  expect_identical(
    addr_format(addr_strict(c("8000::", "::8000:0", "128.0.0.0"))),
    c("8000::", "::8000:0", "128.0.0.0")
  )
  expect_identical(
    addr_expand(addr_strict("8000::")),
    "8000:0000:0000:0000:0000:0000:0000:0000"
  )
})

# --- the properties that matter ----------------------------------------------

format_corpus <- function() {
  c(
    "::", "::1", "1::", "1::8", "1:2:3:4:5:6:7:8", "2001:db8::1",
    "2001:0:0:1:0:0:0:1", "1:0:0:2:0:0:3:4", "2001:db8:0:1:1:1:1:1",
    "fe80::1", "ff02::1", "::ffff:192.0.2.1", "::ffff:0.0.0.0",
    "::1.2.3.4", "8000::", "::8000:0", "0:0:0:0:0:0:0:0",
    "0.0.0.0", "127.0.0.1", "128.0.0.0", "255.255.255.255", "192.0.2.1"
  )
}

test_that("the canonical form round-trips through the parser", {
  # Section 5.1: this is what the three-state family buys, and it is the reason
  # the 4-in-6 form must render as ::ffff:x.x.x.x rather than collapsing onto
  # the bare IPv4 address.
  a <- addr_strict(format_corpus())
  expect_false(anyNA(a))
  expect_true(all(addr_strict(addr_format(a)) == a))
  expect_identical(addr_family(addr_strict(addr_format(a))), addr_family(a))
})

test_that("the expanded form round-trips through the parser", {
  a <- addr_strict(format_corpus())
  expect_true(all(addr_strict(addr_expand(a)) == a))
})

test_that("the canonical form is a fixed point", {
  a <- addr_strict(format_corpus())
  expect_identical(addr_format(addr_strict(addr_format(a))), addr_format(a))
})

test_that("equal addresses format identically, and unequal ones do not", {
  a <- addr_strict(format_corpus())
  expect_identical(
    length(unique(addr_format(a))),
    length(unique(a))
  )
})

test_that("the rendering is per-row, not per-vector", {
  # The same invariant test-ipv6.R asserts of the parser: the renderers work on
  # an 8 x n matrix, so a bug that leaks across columns would be invisible to
  # any test that only ever renders one address at a time.
  corpus <- c(format_corpus(), NA_character_, "nonsense")
  a <- addr_pton(corpus)
  for (renderer in list(addr_format, addr_expand)) {
    expect_identical(
      renderer(a),
      vapply(
        seq_along(a),
        function(i) renderer(a[i]),
        character(1)
      )
    )
  }
})

test_that("format() and as.character() are the canonical rendering", {
  a <- addr_strict(format_corpus())
  expect_identical(format(a), addr_format(a))
  expect_identical(as.character(a), addr_format(a))
})
