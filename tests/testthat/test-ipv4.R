# The IPv4 dialects. See docs/architecture.md sections 3.1 to 3.3.

# --- ends_in_a_number() ------------------------------------------------------

test_that("ends_in_a_number() fires on the labels the number parser accepts", {
  expect_true(all(ends_in_a_number(c("1.2.3.4", "foo.09", "foo.0x4", "0x1f"))))
  expect_true(all(ends_in_a_number(c("1.2.3.08.", "1.", "0x"))))
})

test_that("ends_in_a_number() is FALSE for names, NA and empty", {
  expect_false(any(ends_in_a_number(c("example.com", "1.2.3.4a", "0xg"))))
  expect_identical(ends_in_a_number(c(NA_character_, "")), c(FALSE, FALSE))
})

# --- parse_ipv4_number() -----------------------------------------------------

test_that("the radix is sniffed per part", {
  parsed <- parse_ipv4_number(c("10", "010", "0x10", "0X10"))
  expect_identical(parsed$value, c(10, 8, 16, 16))
  expect_true(all(parsed$status == "ok"))
})

test_that("the alphabet is validated before conversion, so 09 is not 9", {
  parsed <- parse_ipv4_number(c("09", "08", "0xg", "1e2", "-1"))
  expect_true(all(parsed$status == "not_a_number"))
})

test_that("a digitless 0x is a zero, and is flagged as empty", {
  parsed <- parse_ipv4_number("0x")
  expect_identical(parsed$value, 0)
  expect_identical(parsed$status, "ok")
  expect_true(parsed$empty)
})

test_that("radix prefixes are ignorable, for the decimal-only dialects", {
  parsed <- parse_ipv4_number(c("010", "0x10"), hex = FALSE, octal = FALSE)
  expect_identical(parsed$value[[1]], 10)
  expect_identical(parsed$status[[2]], "not_a_number")
})

test_that("overflow is reported but still carries the wrapped value", {
  parsed <- parse_ipv4_number(c("4294967295", "4294967296", "4294967297"))
  expect_identical(parsed$status, c("ok", "overflow", "overflow"))
  expect_identical(parsed$value, c(4294967295, 0, 1))
})

test_that("the wrapped value is exact for digit runs far past 2^32", {
  # Verified against Apple inet_aton: 1e26 wraps to 227.255.255.255
  # [verified 2026-07-26].
  parsed <- parse_ipv4_number("99999999999999999999999999")
  expect_identical(parsed$status, "overflow")
  expect_identical(parsed$value, 3825205247)
})

test_that("leading zeros do not change the value at any width", {
  parsed <- parse_ipv4_number(
    c("1", "0000000000000000001"),
    octal = FALSE
  )
  expect_identical(parsed$value, c(1, 1))
})

# --- the divergence table ----------------------------------------------------
#
# Section 3.3, the eight rows the whole package is built to explain. Spelled out
# here rather than read from the fixture, because if this table ever changes the
# diff should be impossible to miss.

test_that("the section 3.3 divergence table holds", {
  no <- NA_character_
  input <- c(
    "127.0.0.1", "0177.0.0.1", "192.0.010.1", "192.0.048.1",
    "4294967296", "1.2.3.", "2130706433", "10.048.1.1"
  )
  expected <- list(
    strict = c(
      "127.0.0.1", no, no, no,
      no, no, no, no
    ),
    whatwg = c(
      "127.0.0.1", "127.0.0.1", "192.0.8.1", no,
      no, "1.2.0.3", "127.0.0.1", no
    ),
    pton = c(
      "127.0.0.1", "177.0.0.1", "192.0.10.1", "192.0.48.1",
      no, no, no, "10.48.1.1"
    ),
    aton = c(
      "127.0.0.1", "127.0.0.1", "192.0.8.1", no,
      "0.0.0.0", no, "127.0.0.1", no
    ),
    getaddrinfo = c(
      "127.0.0.1", "177.0.0.1", "192.0.10.1", "192.0.48.1",
      "0.0.0.0", no, "127.0.0.1", "10.48.1.1"
    ),
    curl = c(
      "127.0.0.1", "127.0.0.1", "192.0.8.1", "192.0.48.1",
      "0.0.0.0", no, "127.0.0.1", "10.48.1.1"
    )
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
# data-raw/oracle-ipv4.py and data-raw/oracle-ipv4.R regenerate this fixture
# from Apple libc and from ada. If a libc upgrade changes a row, this fails and
# the model gets revisited rather than silently drifting.

test_that("pton, aton, getaddrinfo and whatwg match the recorded oracle", {
  oracle <- read.csv(
    test_path("fixtures", "ipv4-oracle.csv"),
    colClasses = "character",
    na.strings = NULL
  )
  input <- unescape_control(oracle$input)

  for (dialect in c("pton", "aton", "getaddrinfo", "whatwg")) {
    expected <- oracle[[dialect]]
    # "-" marks a row the oracle could not measure for that dialect, which
    # data-raw/oracle-ipv4.R explains.
    keep <- expected != "-"
    expected <- expected[keep]
    expected[!nzchar(expected)] <- NA_character_
    expect_identical(
      format(dialect_fn(dialect)(input[keep])),
      expected,
      label = dialect
    )
  }
})

test_that("inet_aton stops at the first whitespace and ignores the rest", {
  # [verified 2026-07-26] against Apple libc.
  accepted <- c("1.2.3.4 ", "1.2.3.4\t", "1.2.3.4\r\n", "1.2.3.4  ",
                "1.2.3.4 x", "1.2.3.4\v", "1.2.3.4\f")
  expect_identical(
    format(addr_aton(accepted)),
    rep("1.2.3.4", length(accepted))
  )
  expect_identical(format(addr_aton("127.0.0.1 junk")), "127.0.0.1")
  expect_identical(format(addr_aton("1.2 .3.4")), "1.0.0.2")
  expect_identical(format(addr_aton("1 ")), "0.0.0.1")

  # Leading whitespace leaves nothing to parse, and glued-on garbage is not
  # whitespace at all.
  expect_true(is.na(addr_aton(" 1.2.3.4")))
  expect_true(is.na(addr_aton("\t1.2.3.4")))
  expect_true(is.na(addr_aton("1.2.3.4x")))
})

test_that("getaddrinfo rejects whitespace that bare aton would accept", {
  # The one place the pton-then-aton composition leaks [verified 2026-07-26].
  expect_identical(format(addr_aton("1.2.3.4 ")), "1.2.3.4")
  expect_true(is.na(addr_getaddrinfo("1.2.3.4 ")))
})

test_that("a digitless 0x is allowed everywhere but the final aton part", {
  # [verified 2026-07-26] against Apple libc.
  expect_identical(
    format(addr_aton(c("0x.1", "0x.0x.0"))),
    c("0.0.0.1", "0.0.0.0")
  )
  expect_true(all(is.na(addr_aton(c("0x", "0X", "0x.0x", "1.0x", "1.2.0x")))))

  # WHATWG has no such carve-out: a bare 0x is simply zero.
  expect_identical(format(addr_whatwg("0x")), "0.0.0.0")
})

# --- per-dialect behavior ----------------------------------------------------

test_that("strict is the RFC grammar, not inet_pton", {
  expect_identical(format(addr_strict("127.0.0.1")), "127.0.0.1")
  # The conflation corrected in section 9: these two disagree.
  expect_true(is.na(addr_strict("0177.0.0.1")))
  expect_identical(format(addr_pton("0177.0.0.1")), "177.0.0.1")

  expect_true(all(is.na(addr_strict(
    c("0x7f.0.0.1", "127.1", "2130706433", "1.2.3.", "010.0.0.1")
  ))))
})

test_that("whatwg drops one trailing dot and rejects overflow", {
  expect_identical(format(addr_whatwg("1.2.3.")), "1.2.0.3")
  expect_true(is.na(addr_whatwg("1.2.3..")))
  expect_true(is.na(addr_whatwg("4294967296")))
  expect_identical(format(addr_whatwg("4294967295")), "255.255.255.255")
})

test_that("aton range-checks every arity except the whole-host number", {
  # [verified 2026-07-26]: k = 1 truncates to 32 bits, k >= 2 rejects.
  expect_identical(format(addr_aton("4294967296")), "0.0.0.0")
  expect_true(is.na(addr_aton("1.4294967296")))
  expect_identical(format(addr_aton("127.16777215")), "127.255.255.255")
  expect_true(is.na(addr_aton("127.16777216")))
})

test_that("the compositions are the two precedence orderings", {
  # The value of the whole package, in one row: curl reaches a host a browser
  # refuses to dial, because aton runs first and pton catches what it drops.
  expect_true(is.na(addr_whatwg("192.0.048.1")))
  expect_true(is.na(addr_aton("192.0.048.1")))
  expect_identical(format(addr_curl("192.0.048.1")), "192.0.48.1")

  # And the orderings genuinely differ from each other.
  expect_identical(format(addr_getaddrinfo("0177.0.0.1")), "177.0.0.1")
  expect_identical(format(addr_curl("0177.0.0.1")), "127.0.0.1")
})

# --- the type contract -------------------------------------------------------

test_that("the parsers return v4 addresses and NA family on rejection", {
  parsed <- addr_strict(c("1.2.3.4", "nope"))
  expect_identical(as.character(addr_family(parsed)), c("v4", NA))
  expect_true(is.na(parsed[[2]]))
})

test_that("128.0.0.0 survives the parsers (the 0x80000000 address)", {
  # Where section 5.1.1 meets the parsers: this address lands on the reserved
  # bit pattern, and must still equal itself.
  for (parser in list(addr_strict, addr_whatwg, addr_pton, addr_aton)) {
    parsed <- parser("128.0.0.0")
    expect_identical(format(parsed), "128.0.0.0")
    expect_identical(parsed == parsed, TRUE)
  }
  expect_identical(format(addr_aton("2147483648")), "128.0.0.0")
})

test_that("the parsers are vectorized and length-stable", {
  x <- c("1.2.3.4", NA, "", "nope", "0177.0.0.1")
  for (parser in list(addr_strict, addr_whatwg, addr_pton, addr_aton,
                      addr_getaddrinfo, addr_curl)) {
    expect_equal(vctrs::vec_size(parser(x)), 5L)
  }
  expect_equal(vctrs::vec_size(addr_whatwg(character())), 0L)
})

test_that("a large vector parses in one pass", {
  x <- rep(c("0177.0.0.1", "192.0.048.1", "nope"), length.out = 1000)
  expect_identical(
    format(addr_curl(x)),
    rep(c("127.0.0.1", "192.0.48.1", NA), length.out = 1000)
  )
})
