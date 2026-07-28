# Reverse DNS pointer names. See docs/architecture.md section 6.2.1, and the
# research note docs/research/08-encoding-reverse.md it is graded against.
#
# Both RFCs publish a worked example, so the first two tests are those examples
# verbatim and everything after them is one section per hazard the research
# document names -- the gotchas about granularity and label count, and the
# round-trip failures about the trailing dot and case.

reverse_corpus <- c(
  "0.0.0.0",
  "10.2.0.52",
  "127.0.0.1",
  "192.0.2.1",
  "128.0.0.0",
  "255.255.255.255",
  "::",
  "::1",
  "2001:db8::1",
  "4321:0:1:2:3:4:567:89ab",
  "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
  # 0x80000000 in each of the four words in turn (section 5.1.1)
  "8000::",
  "0:0:8000:0:0:0:0:0",
  "0:0:0:0:8000:0:0:0",
  "::8000:0",
  # The three forms that share their low 32 bits
  "::ffff:192.0.2.1",
  "::192.0.2.1",
  "64:ff9b::192.0.2.33"
)

# --- the two RFC examples ----------------------------------------------------

test_that("RFC 1035 section 3.5's own example", {
  # "Thus data for Internet address 10.2.0.52 is located at domain name
  # 52.0.2.10.IN-ADDR.ARPA."
  expect_identical(
    addr_reverse_pointer(addr_pton("10.2.0.52")),
    "52.0.2.10.in-addr.arpa."
  )
})

test_that("RFC 3596 section 2.5's own example", {
  # The RFC prints the address 4321:0:1:2:3:4:567:89ab as
  # b.a.9.8.7.6.5.0.4.0.0.0.3.0.0.0.2.0.0.0.1.0.0.0.0.0.0.0.1.2.3.4.IP6.ARPA.
  # -- the same digits, and the case is raddr's choice (RFC 1035 section 3.1
  # compares labels case-insensitively).
  expect_identical(
    addr_reverse_pointer(addr_pton("4321:0:1:2:3:4:567:89ab")),
    paste0(
      "b.a.9.8.7.6.5.0.4.0.0.0.3.0.0.0.",
      "2.0.0.0.1.0.0.0.0.0.0.0.1.2.3.4.ip6.arpa."
    )
  )
})

test_that("the research document's worked examples", {
  expect_identical(
    addr_reverse_pointer(addr_pton(c(
      "192.0.2.1",
      "0.0.0.0",
      "255.255.255.255",
      "127.0.0.1"
    ))),
    c(
      "1.2.0.192.in-addr.arpa.",
      "0.0.0.0.in-addr.arpa.",
      "255.255.255.255.in-addr.arpa.",
      "1.0.0.127.in-addr.arpa."
    )
  )
  expect_identical(
    addr_reverse_pointer(addr_pton("::1")),
    paste0("1.", strrep("0.", 31L), "ip6.arpa.")
  )
  expect_identical(
    addr_reverse_pointer(addr_pton("::")),
    paste0(strrep("0.", 32L), "ip6.arpa.")
  )
  expect_identical(
    addr_reverse_pointer(addr_pton("2001:db8::1")),
    paste0("1.", strrep("0.", 23L), "8.b.d.0.1.0.0.2.ip6.arpa.")
  )
})

test_that("the name is the reversed nibbles of the expanded form", {
  # An independent construction over the whole corpus. Building the name out of
  # `addr_expand()` is exactly what gotcha 2 says an *implementation* must not
  # do -- it works only because the expanded form is fixed width and
  # uncompressed, which is a property of that one renderer and not of the text
  # form in general. As a second opinion in a test it is worth having, because
  # it shares no code with the thing it checks.
  a <- addr_pton(reverse_corpus)
  is_v6 <- as.character(addr_family(a)) != "v4"

  by_hand <- vapply(
    addr_expand(a[is_v6]),
    function(text) {
      nibbles <- strsplit(gsub(":", "", text, fixed = TRUE), "")[[1L]]
      paste0(paste(rev(nibbles), collapse = "."), ".ip6.arpa.")
    },
    character(1L),
    USE.NAMES = FALSE
  )
  expect_identical(addr_reverse_pointer(a[is_v6]), by_hand)

  quads <- vapply(
    addr_expand(a[!is_v6]),
    function(text) {
      octets <- strsplit(text, ".", fixed = TRUE)[[1L]]
      paste0(paste(rev(octets), collapse = "."), ".in-addr.arpa.")
    },
    character(1L),
    USE.NAMES = FALSE
  )
  expect_identical(addr_reverse_pointer(a[!is_v6]), quads)
})

# --- gotcha 1: the two granularities are different ---------------------------
#
# IPv4 reverses whole octets (RFC 1035 section 3.5), IPv6 reverses nibbles
# (RFC 3596 section 2.5). The research document calls reversing IPv6 by octet a
# classic bug that produces a plausible-looking but wrong name.

test_that("IPv6 reverses nibbles, not octets", {
  # 0x12 as an octet is the labels "2.1", never "1.2". An address whose octets
  # are all asymmetric catches the whole-octet reversal on every one of them.
  got <- addr_reverse_pointer(
    addr_pton("1234:5678:9abc:def0:1234:5678:9abc:def0")
  )
  expect_identical(
    got,
    paste0(
      "0.f.e.d.c.b.a.9.8.7.6.5.4.3.2.1.",
      "0.f.e.d.c.b.a.9.8.7.6.5.4.3.2.1.ip6.arpa."
    )
  )

  # What the octet-reversing bug would have produced, spelled out so the
  # difference is visible rather than asserted in the abstract.
  by_octet <- paste0(
    "f.0.d.e.b.c.9.a.7.8.5.6.3.4.1.2.",
    "f.0.d.e.b.c.9.a.7.8.5.6.3.4.1.2.ip6.arpa."
  )
  expect_false(identical(got, by_octet))
  # Both are 32 legal labels, which is why the bug survives a length check.
  expect_identical(
    lengths(strsplit(c(got, by_octet), ".", fixed = TRUE)),
    c(34L, 34L)
  )
})

# --- gotcha 2: an ip6.arpa name is always 32 labels --------------------------

test_that("every IPv6 name is 32 labels and every IPv4 name is 4", {
  a <- addr_pton(reverse_corpus)
  is_v6 <- as.character(addr_family(a)) != "v4"
  labels <- lengths(strsplit(addr_reverse_pointer(a), ".", fixed = TRUE))

  # Plus "ip6"/"arpa" or "in-addr"/"arpa"; the trailing dot adds no field.
  expect_true(all(labels[is_v6] == 34L))
  expect_true(all(labels[!is_v6] == 6L))
})

test_that("nothing is compressed and no zero is suppressed", {
  # The three spellings of one address produce one name, and the name is not
  # shorter for the compressible one. `::` never appears.
  a <- addr_pton(c(
    "2001:0db8:0000:0000:0000:0000:0000:0001",
    "2001:db8::1",
    "2001:DB8:0:0:0:0:0:1"
  ))
  got <- addr_reverse_pointer(a)
  expect_identical(got, rep(got[[1L]], 3L))
  expect_false(any(grepl("::", got, fixed = TRUE)))
  expect_false(any(grepl("..", got, fixed = TRUE)))
})

test_that("the name is not built from the canonical text form", {
  # `addr_format()` renders a 4-in-6 address in the mixed form, with a dotted
  # quad in it. A name derived from that text would carry decimal labels.
  a <- addr_pton("::ffff:192.0.2.1")
  expect_true(grepl(".", addr_format(a), fixed = TRUE))
  expect_false(grepl("192", addr_reverse_pointer(a), fixed = TRUE))
  expect_identical(
    lengths(strsplit(addr_reverse_pointer(a), ".", fixed = TRUE)),
    34L
  )
})

# --- RFC 1035 section 3.5: decimal labels, leading zeros omitted -------------

test_that("IPv4 labels are decimal with no padding, zero being a single 0", {
  # "expressed as a character string for a decimal value in the range 0-255
  # (with leading zeros omitted except in the case of a zero octet which is
  # represented by a single zero)".
  expect_identical(
    addr_reverse_pointer(addr_pton("10.0.1.100")),
    "100.1.0.10.in-addr.arpa."
  )
  padded <- addr_reverse_pointer(addr_pton(c("10.10.10.10", "0.0.0.0")))
  expect_false(any(grepl("010", padded, fixed = TRUE)))
  expect_false(any(grepl("00", padded, fixed = TRUE)))
})

test_that("gotcha 9: one tree's labels are decimal and the other's are hex", {
  # A label `9` is legal in both trees and means octet 9 in one, nibble 9 in the
  # other, so the suffix is the only thing that can say which. Every ip6.arpa
  # label is a single hex digit; the in-addr.arpa labels are up to three digits.
  a <- addr_pton(reverse_corpus)
  is_v6 <- as.character(addr_family(a)) != "v4"

  body <- function(name, suffix) {
    sub(suffix, "", name, fixed = TRUE)
  }
  v6_labels <- strsplit(
    body(addr_reverse_pointer(a[is_v6]), "ip6.arpa."),
    ".",
    fixed = TRUE
  )
  expect_true(all(grepl("^[0-9a-f]$", unlist(v6_labels))))

  v4_labels <- strsplit(
    body(addr_reverse_pointer(a[!is_v6]), "in-addr.arpa."),
    ".",
    fixed = TRUE
  )
  expect_true(all(grepl("^(0|[1-9][0-9]{0,2})$", unlist(v4_labels))))
})

# --- round-trip failure 9: the trailing dot ----------------------------------
#
# `1.2.0.192.in-addr.arpa` and `1.2.0.192.in-addr.arpa.` denote the same name
# (RFC 1035 section 3.1) but are not the same string. The document's rule is to
# pick the absolute form on output.

test_that("every name is emitted fully qualified", {
  got <- addr_reverse_pointer(addr_pton(reverse_corpus))
  expect_true(all(endsWith(got, ".arpa.")))
  expect_true(all(endsWith(got, ".")))
})

# --- round-trip failure 8: case ----------------------------------------------

test_that("hex labels and the suffix are lowercase", {
  got <- addr_reverse_pointer(addr_pton(c(
    "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
    "2001:DB8::ABCD",
    "192.0.2.1"
  )))
  expect_identical(got, tolower(got))
  expect_false(any(grepl("[A-Z]", got)))
})

# --- gotcha 24: the 4-in-6 form has no specified answer ----------------------
#
# Neither RFC 3596 nor RFC 4291 says whether `::ffff:192.0.2.1` maps into
# ip6.arpa or into in-addr.arpa. raddr returns the mechanical answer -- it is an
# IPv6 address -- and the useful one is reachable by naming the address it
# embeds.

test_that("a 4-in-6 address gets the mechanical ip6.arpa name", {
  a <- addr_pton(c("::ffff:192.0.2.1", "192.0.2.1"))
  got <- addr_reverse_pointer(a)

  expect_true(endsWith(got[[1L]], "ip6.arpa."))
  expect_true(endsWith(got[[2L]], "in-addr.arpa."))
  # The mapped name ends in the ffff prefix's nibbles, read backwards.
  expect_identical(
    got[[1L]],
    paste0("1.0.2.0.0.0.0.c.f.f.f.f.", strrep("0.", 20L), "ip6.arpa.")
  )
  # The useful name is the embedded address's own, and it is not this one.
  expect_false(identical(got[[1L]], got[[2L]]))
})

test_that("the deprecated IPv4-compatible form is also an IPv6 name", {
  # RFC 4291 section 2.5.5 marks `::192.0.2.1` deprecated, not IPv4.
  expect_identical(
    addr_reverse_pointer(addr_pton("::192.0.2.1")),
    paste0("1.0.2.0.0.0.0.c.", strrep("0.", 24L), "ip6.arpa.")
  )
})

# --- the zone -----------------------------------------------------------------
#
# RFC 4007 section 6: a zone index is strictly local to a node, so it has no
# meaning in a DNS name and there is nowhere in the grammar to put it. Section
# 3.5.2 records the Python bug this is the counterpart of: CPython's
# `.reverse_pointer` raises on a zoned address rather than dropping the zone.

test_that("the zone is dropped and a zoned address still renders", {
  a <- addr_pton(c("fe80::1", "fe80::1%eth0", "fe80::1%1"))
  got <- addr_reverse_pointer(a)

  expect_identical(got, rep(got[[1L]], 3L))
  expect_false(any(grepl("%", got, fixed = TRUE)))
  expect_false(any(grepl("eth0", got, fixed = TRUE)))
})

# --- the forms raddr never emits ---------------------------------------------

test_that("no ip6.int, no bitstring label, no RFC 2317 separator", {
  got <- addr_reverse_pointer(addr_pton(reverse_corpus))

  # RFC 4159: "the DNS domain 'ip6.int' should no longer be used".
  expect_false(any(grepl("ip6.int", got, fixed = TRUE)))
  # RFC 2673 bitstring labels, made Experimental by RFC 3363.
  expect_false(any(grepl("\\[", got)))
  # RFC 2317 classless delegation names, which are generate-only.
  expect_false(any(grepl("/", got, fixed = TRUE)))
})

# --- missingness, the empty vector, and the type check ------------------------

test_that("a missing address has a missing name", {
  a <- addr_pton(c("192.0.2.1", "not an address", "2001:db8::1"))
  expect_identical(is.na(addr_reverse_pointer(a)), c(FALSE, TRUE, FALSE))
})

test_that("the empty vector answers the empty character vector", {
  expect_identical(
    addr_reverse_pointer(addr_pton(character())),
    character()
  )
})

test_that("a character vector is a type error, not a parse", {
  expect_error(addr_reverse_pointer("192.0.2.1"), class = "raddr_error_type")
  expect_error(addr_reverse_pointer(NULL), class = "raddr_error_type")
})
