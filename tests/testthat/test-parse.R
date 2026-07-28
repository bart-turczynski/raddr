# addr_parse() and the raddr_parse record.
# See docs/architecture.md sections 4, 5.2, 5.2.1 and 6.1.

# --- The record ---------------------------------------------------------------

test_that("addr_parse() returns one element per input", {
  p <- addr_parse(c("127.0.0.1", "::1", "nonsense"))
  expect_true(is_raddr_parse(p))
  expect_identical(vctrs::vec_size(p), 3L)
  expect_false(is_raddr_parse("127.0.0.1"))
})

test_that("the record carries the fields section 5.2 lists", {
  p <- addr_parse("127.0.0.1")
  expect_setequal(
    vctrs::fields(p),
    c("input", raddr_primitives, "outcome", "codes", "status")
  )
  expect_identical(addr_input(p), "127.0.0.1")
})

test_that("outcome and codes are four columns, one per primitive", {
  p <- addr_parse(c("127.0.0.1", "nonsense"))
  outcome <- vctrs::field(p, "outcome")
  codes <- vctrs::field(p, "codes")
  expect_named(outcome, raddr_primitives)
  expect_named(codes, raddr_primitives)
  expect_identical(nrow(outcome), 2L)
  expect_true(all(vapply(outcome, is.factor, logical(1L))))
  expect_identical(levels(outcome$strict), raddr_outcomes)
})

test_that("the empty vector parses to an empty record", {
  p <- addr_parse(character())
  expect_identical(vctrs::vec_size(p), 0L)
  expect_identical(addr_status(p), factor(levels = raddr_statuses))
  expect_output(print(p), "raddr_parse")
})

test_that("a missing input is missing everywhere", {
  p <- addr_parse(c("127.0.0.1", NA))
  expect_true(is.na(addr_status(p)[[2L]]))
  expect_true(is.na(addr_outcome(p, "strict")[[2L]]))
  expect_true(is.na(addr_family(addr_reading(p, "whatwg"))[[2L]]))
  expect_identical(addr_codes(p)[[2L]], character())
})

test_that("addr_parse() casts rather than demanding character", {
  expect_error(addr_parse(list(1)), class = "vctrs_error_cast")
})

# --- Per-dialect outcomes: the case a scalar status cannot express ------------

test_that("4294967296 is three different rejections and one acceptance", {
  p <- addr_parse("4294967296")

  expect_identical(as.character(addr_outcome(p, "aton")), "ok")
  expect_identical(addr_format(addr_reading(p, "aton")), "0.0.0.0")

  expect_identical(as.character(addr_outcome(p, "whatwg")), "rejected")
  expect_identical(addr_codes(p, "whatwg")[[1L]], "out_of_range")

  expect_identical(as.character(addr_outcome(p, "strict")), "rejected")
  expect_true("wrong_part_count" %in% addr_codes(p, "strict")[[1L]])

  # And out_of_range is a code on the dialect that overflowed, never a status.
  expect_identical(as.character(addr_status(p)), "divergent")
  expect_false("out_of_range" %in% raddr_statuses)
})

test_that("0177.0.0.1 is one string and three hosts", {
  p <- addr_parse("0177.0.0.1")
  expect_identical(addr_codes(p, "strict")[[1L]], "leading_zero")
  expect_identical(addr_format(addr_reading(p, "whatwg")), "127.0.0.1")
  expect_identical(addr_format(addr_reading(p, "pton")), "177.0.0.1")
  expect_identical(addr_format(addr_reading(p, "aton")), "127.0.0.1")
  expect_true(addr_is_divergent(p))
})

test_that("the zone is a rejection on paper and a reading in reality", {
  p <- addr_parse("fe80::1%lo0")
  expect_identical(addr_codes(p, "strict")[[1L]], "zone_not_permitted")
  expect_identical(addr_codes(p, "whatwg")[[1L]], "zone_not_permitted")
  expect_identical(addr_zone(addr_reading(p, "pton")), "lo0")
  expect_identical(as.character(addr_status(p)), "divergent")
})

# --- The derived status -------------------------------------------------------

test_that("the derived status is what section 5.2 says it is", {
  rows <- rows_table(
    c("input", "status"),
    "127.0.0.1", "ok",
    "::1", "ok",
    "::ffff:127.0.0.1", "ok",
    "0177.0.0.1", "divergent",
    "4294967296", "divergent",
    "192.0.048.1", "divergent",
    "1.2.3.4 junk", "divergent",
    "fe80::1%lo0", "divergent",
    "example.com", "not_an_address",
    "", "not_an_address",
    "1.2.3.4.5", "malformed",
    "1:2:3:4:5:6:7", "malformed",
    "256.256.256.256", "malformed"
  )
  status <- as.character(addr_status(addr_parse(rows$input)))
  expect_identical(status, rows$status)
})

test_that("an IPv6 address is not divergent merely because aton is AF_INET", {
  # The whole point of section 5.2.1: a dialect with no grammar for the family
  # has no reading to withhold, so its silence is not dissent. Otherwise every
  # IPv6 address on earth is `divergent`.
  p <- addr_parse(c("::1", "::ffff:1.2.3.4", "2001:db8::1"))
  expect_true(all(addr_status(p) == "ok"))
  expect_true(all(addr_outcome(p, "aton") == "not_an_address"))
  expect_true(all(lengths(addr_codes(p, "aton")) == 0L))
})

test_that("aton's outcome does not depend on how the tail is spelled", {
  p <- addr_parse(c("::ffff:1.2.3.4", "::ffff:102:304"))
  expect_identical(
    as.character(addr_outcome(p, "aton")),
    c("not_an_address", "not_an_address")
  )
})

test_that("a lone acceptance still makes the row divergent", {
  # `aton` stops at the first space and finds an address the other three do not
  # see at all. That is a real disagreement, unlike the case above.
  p <- addr_parse("1.2.3.4 junk")
  expect_identical(as.character(addr_status(p)), "divergent")
  expect_identical(addr_format(addr_reading(p, "aton")), "1.2.3.4")
  expect_identical(as.character(addr_outcome(p, "strict")), "not_an_address")
})

test_that("unanimous acceptance of different values is still divergent", {
  # All four accept "1.1", and they do not agree about what it is.
  p <- addr_parse("1.1")
  expect_identical(as.character(addr_status(p)), "divergent")
})

test_that("agreement on the value must include the family", {
  p <- addr_parse("::ffff:127.0.0.1")
  expect_identical(
    addr_family(addr_reading(p, "whatwg")),
    factor("v6_4in6", levels = addr_families)
  )
  expect_false(addr_reading(p, "whatwg") == addr_strict("127.0.0.1"))
})

# --- Accessors ----------------------------------------------------------------

test_that("the accessors admit all six dialect names", {
  p <- addr_parse("0177.0.0.1")
  for (dialect in raddr_dialects) {
    expect_true(is_raddr_address(addr_reading(p, dialect)))
    expect_s3_class(addr_outcome(p, dialect), "factor")
    expect_type(addr_codes(p, dialect), "list")
  }
})

test_that("an unknown dialect is an error, not a silent default", {
  p <- addr_parse("127.0.0.1")
  expect_error(addr_reading(p, "browser"), class = "raddr_error_dialect")
  expect_error(addr_outcome(p, NA), class = "raddr_error_dialect")
  expect_error(
    addr_codes(p, c("strict", "whatwg")),
    class = "raddr_error_dialect"
  )
})

test_that("the accessors reject anything that is not a raddr_parse", {
  expect_error(addr_status("127.0.0.1"), class = "raddr_error_type")
  expect_error(addr_reading(addr_strict("127.0.0.1"), "strict"),
    class = "raddr_error_type"
  )
})

test_that("addr_codes() unions by default and narrows on request", {
  p <- addr_parse("0177.0.0.1")
  expect_identical(addr_codes(p)[[1L]], "leading_zero")
  expect_identical(addr_codes(p, "whatwg")[[1L]], character())
})

test_that("codes come back in registry order however they were collected", {
  p <- addr_parse("4294967296")
  codes <- addr_codes(p, "strict")[[1L]]
  expect_identical(codes, parse_code_levels[parse_code_levels %in% codes])
})

test_that("an accepted or shrugged-at row carries no codes", {
  p <- addr_parse(c("127.0.0.1", "example.com"))
  expect_identical(addr_codes(p), list(character(), character()))
})

# --- The compositions are resolved, not stored (section 3.2) ------------------

test_that("addr_reading() reproduces every single-dialect parser exactly", {
  x <- c(
    "127.0.0.1", "0177.0.0.1", "192.0.048.1", "4294967296", "1.2.3.",
    "1.2.3.4 junk", "0x7f.1", "example.com", "", NA,
    "::1", "::ffff:127.0.0.1", "fe80::1%lo0", "fe80:abcd::1",
    "00000::1", "1:2:3:4:5:6:7:8", "g::1", "fe80::1%lo0%en0"
  )
  p <- addr_parse(x)
  for (dialect in raddr_dialects) {
    expect_true(
      all(vctrs::vec_equal(
        addr_reading(p, dialect),
        dialect_fn(dialect)(x),
        na_equal = TRUE
      )),
      info = dialect
    )
    expect_identical(
      addr_zone(addr_reading(p, dialect)),
      addr_zone(dialect_fn(dialect)(x)),
      info = dialect
    )
  }
})

test_that("getaddrinfo's whitespace gate is a rejection with its own code", {
  p <- addr_parse(c("1.2.3.4 junk", "fe80::1%lo0 "))

  expect_true(is.na(addr_family(addr_reading(p, "getaddrinfo"))[[1L]]))
  gai <- as.character(addr_outcome(p, "getaddrinfo")[[1L]])
  expect_identical(gai, "rejected")
  expect_true("whitespace" %in% addr_codes(p, "getaddrinfo")[[1L]])

  # The gate covers the address, not the zone ID, so the second row survives it.
  expect_identical(addr_zone(addr_reading(p, "getaddrinfo"))[[2L]], "lo0 ")

  # curl inherits the gate along with the whole entry point (section 3.2), but
  # never reaches it here: aton answers first and gets to the host.
  expect_identical(addr_format(addr_reading(p, "curl"))[[1L]], "1.2.3.4")
  expect_identical(as.character(addr_outcome(p, "curl")[[1L]]), "ok")
})

test_that("moving curl's fallback left its acceptance set alone", {
  # RADD-puzhycev swapped curl's fallback from pton to the getaddrinfo entry
  # point, which changes bits on the lift rows but decides no acceptance:
  # getaddrinfo accepts what pton accepts plus what aton accepts, and aton has
  # already run. So the outcome and code surfaces still resolve over the two
  # primitives, and this is what says that is still true.
  literals <- corpus_literals()
  p <- addr_parse(literals)

  ok <- function(dialect) !is.na(addr_family(addr_reading(p, dialect)))
  expect_identical(ok("curl"), ok("aton") | ok("pton"))
})

test_that("curl and getaddrinfo differ by precedence alone", {
  p <- addr_parse("192.0.048.1")
  expect_true(is.na(addr_family(addr_reading(p, "whatwg"))))
  expect_identical(addr_format(addr_reading(p, "curl")), "192.0.48.1")
})

test_that("a composition shrugs only when both of its primitives do", {
  p <- addr_parse(c("example.com", "1.2.3.4.5"))
  expect_identical(
    as.character(addr_outcome(p, "curl")),
    c("not_an_address", "rejected")
  )
  expect_identical(addr_codes(p, "curl")[[1L]], character())
  expect_true(length(addr_codes(p, "curl")[[2L]]) > 0L)
})

test_that("a composition's codes are the union of its primitives'", {
  p <- addr_parse("01.2.3.4.5")
  expect_setequal(
    addr_codes(p, "curl")[[1L]],
    union(addr_codes(p, "aton")[[1L]], addr_codes(p, "pton")[[1L]])
  )
})

# --- Printing: quiet on agreement, loud on divergence (section 4) -------------

test_that("agreement prints one line per address and says nothing else", {
  out <- capture.output(print(addr_parse(c("127.0.0.1", "::1"))))
  expect_true(any(grepl("127.0.0.1", out, fixed = TRUE)))
  expect_false(any(grepl("strict", out, fixed = TRUE)))
  expect_false(any(grepl("Status:", out, fixed = TRUE)))
})

test_that("divergence is expanded, one block per row, with the codes", {
  out <- capture.output(print(addr_parse("0177.0.0.1")))
  expect_true(any(grepl("Status: divergent 1", out, fixed = TRUE)))
  expect_true(any(grepl("strict +<rejected: leading_zero>", out)))
  expect_true(any(grepl("pton +177\\.0\\.0\\.1", out)))
})

test_that("the report is capped however long the vector is", {
  out <- capture.output(print(addr_parse(rep("0177.0.0.1", 40L))))
  expect_length(grep("^\\[[0-9]+\\] \"", out), divergence_cap)
  expect_true(any(grepl("and 35 more divergent", out, fixed = TRUE)))
})

test_that("a non-divergent problem is tallied but not expanded", {
  out <- capture.output(print(addr_parse(c("127.0.0.1", "example.com"))))
  expect_true(any(grepl("not_an_address 1", out, fixed = TRUE)))
  expect_false(any(grepl("strict", out, fixed = TRUE)))
})

test_that("format() and as.character() default to whatwg (section 4)", {
  x <- c("0177.0.0.1", "192.0.048.1")
  p <- addr_parse(x)
  expect_identical(format(p), addr_format(addr_whatwg(x)))
  expect_identical(as.character(p), format(p))
})

# --- Vectorized diagnostics (RADD-wjbscyvu) -----------------------------------

test_that("ten thousand bad rows produce no conditions at all", {
  x <- rep(c("1.2.3.4.5", "0177.0.0.1", "example.com", "g::1"), 2500L)
  expect_silent(p <- addr_parse(x))
  expect_identical(vctrs::vec_size(p), 10000L)
})

test_that("ten thousand bad rows produce one bounded report", {
  x <- rep(c("1.2.3.4.5", "0177.0.0.1"), 5000L)
  out <- capture.output(print(addr_parse(x)))
  # One status line, and the divergence detail capped at five blocks.
  expect_length(grep("^Status:", out), 1L)
  expect_length(grep("^\\[[0-9]+\\] \"", out), divergence_cap)
})

# --- The standing property: one pass equals one at a time ---------------------

test_that("the vectorized parse equals the one-at-a-time parse", {
  x <- c(
    "127.0.0.1", "0177.0.0.1", "4294967296", "example.com", "1.2.3.4.5",
    "::1", "fe80::1%lo0", "::ffff:127.0.0.1", "g::1", "", NA, "1.2.3.4 junk"
  )
  batch <- addr_parse(x)
  one <- lapply(x, addr_parse)

  expect_identical(
    as.character(addr_status(batch)),
    vapply(one, function(p) as.character(addr_status(p)), character(1L))
  )
  for (dialect in raddr_dialects) {
    expect_identical(
      addr_codes(batch, dialect),
      lapply(one, function(p) addr_codes(p, dialect)[[1L]]),
      info = dialect
    )
    expect_true(
      all(vctrs::vec_equal(
        addr_reading(batch, dialect),
        vctrs::vec_c(!!!lapply(one, addr_reading, dialect)),
        na_equal = TRUE
      )),
      info = dialect
    )
  }
})

test_that("slicing a record slices every field with it", {
  p <- addr_parse(c("127.0.0.1", "0177.0.0.1", "example.com"))
  sliced <- vctrs::vec_slice(p, 2L)
  expect_identical(addr_input(sliced), "0177.0.0.1")
  expect_identical(as.character(addr_status(sliced)), "divergent")
  expect_identical(addr_codes(sliced, "strict")[[1L]], "leading_zero")
})
