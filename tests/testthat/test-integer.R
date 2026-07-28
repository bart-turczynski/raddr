# The fourth encoding pair: unsigned integers. See docs/architecture.md section
# 6.5.2, and docs/research/08-encoding-reverse.md section 2, whose subject is
# what R's numeric types cannot hold.
#
# Organized like test-encoding.R: the round trip first, then one section per
# hazard the research document names -- round-trip failure 2 for the family, and
# the three R-specific gotchas (26, 27, 28) for the types.

integer_corpus <- c(
  "0.0.0.0",
  "127.0.0.1",
  "128.0.0.0",
  "192.0.2.1",
  "255.255.255.255",
  "::",
  "::1",
  "2001:db8::1",
  "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
  "8000::",
  "0:0:8000:0:0:0:0:0",
  "::8000:0",
  "::ffff:192.0.2.1",
  "::192.0.2.1",
  "64:ff9b::192.0.2.33"
)

test_that("the pair round-trips the corpus, bits and family", {
  a <- addr_pton(integer_corpus)
  back <- integer_to_addr(addr_to_integer(a), addr_family(a))

  expect_true(all(back == a))
  expect_identical(addr_family(back), addr_family(a))
})

test_that("the pair round-trips random words at every position", {
  set.seed(20260728L)
  n <- 500L
  words <- lapply(seq_len(4L), function(i) {
    narrow_word(floor(stats::runif(n, 0, 4294967296)))
  })
  a <- c(
    raddr_address(0L, 0L, 0L, words[[4L]], "v4"),
    raddr_address(words[[1L]], words[[2L]], words[[3L]], words[[4L]], "v6")
  )

  expect_true(all(integer_to_addr(addr_to_integer(a), addr_family(a)) == a))
})

test_that("the two decode paths agree across the digit-count boundary", {
  # Values of 15 digits or fewer are exact in a double and skip the chunked
  # multiplication. The seam is invisible from outside, and this is what says
  # so: consecutive values either side of it, plus the powers of ten around it.
  seam <- c(
    "999999999999998", "999999999999999", "1000000000000000",
    "1000000000000001", "99999999999999", "10000000000000000",
    "4294967295", "4294967296", "281473902969345"
  )
  a <- integer_to_addr(seam, "v6")

  expect_identical(addr_to_integer(a), seam)
  expect_false(any(is.na(a)))
})

test_that("the values are the ones the RFC layouts give", {
  # RFC 4632 section 3.1 reads an IPv4 address as a 4-octet quantity;
  # RFC 4291 section 2 fixes IPv6 at 128 bits. Both big-endian.
  expect_identical(
    addr_to_integer(addr_pton(c("0.0.0.0", "192.0.2.1", "255.255.255.255"))),
    c("0", "3221225985", "4294967295")
  )
  expect_identical(
    addr_to_integer(addr_pton(c("::", "::1", "2001:db8::1"))),
    c("0", "1", "42540766411282592856903984951653826561")
  )
  # 2^128 - 1 and 2^127, the two values a signed 128-bit type would spoil.
  expect_identical(
    addr_to_integer(addr_pton("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")),
    "340282366920938463463374607431768211455"
  )
  expect_identical(
    addr_to_integer(addr_pton("8000::")),
    "170141183460469231731687303715884105728"
  )
  expect_identical(
    addr_to_integer(addr_pton("::ffff:192.0.2.1")),
    "281473902969345"
  )
})

test_that("the decimal digits agree with the hex encoding, via bignum", {
  # An independent path: bignum parses the hex form in C++, raddr divides the
  # four words by 10^6 seven times. They share no code.
  skip_if_not_installed("bignum")
  a <- addr_pton(integer_corpus)

  expect_identical(
    bignum::biginteger(addr_to_integer(a)),
    bignum::biginteger(paste0("0x", addr_to_hex(a)))
  )
})

# --- round-trip failure 2: the family does not travel in the number ----------
#
# RFC 4291 section 2.5.5 puts the IPv4 address in the low 32 bits of the mapped
# and compatible forms, so one integer names several objects. The research
# document's rule is that the family must be carried alongside the number.

test_that("one integer, three addresses, and the caller says which", {
  # `192.0.2.1` and the deprecated `::192.0.2.1` are the *same* integer.
  expect_identical(
    addr_to_integer(addr_pton(c("192.0.2.1", "::192.0.2.1"))),
    c("3221225985", "3221225985")
  )

  got <- integer_to_addr("3221225985", c("v4", "v6", "v6_4in6"))
  expect_identical(
    addr_format(got),
    c("192.0.2.1", "::c000:201", "::c000:201")
  )
  expect_identical(
    as.character(addr_family(got)),
    c("v4", "v6", "v6")
  )
  expect_false(got[[1L]] == got[[2L]])
})

test_that("the 4-in-6 family is decided by the bits, not by the argument", {
  # Asking for "v6" and asking for "v6_4in6" are the same request -- 128 bits --
  # and the mapped prefix in the value is what produces the family, exactly as
  # it does when parsing a literal.
  got <- integer_to_addr("281473902969345", c("v6", "v6_4in6"))
  expect_identical(as.character(addr_family(got)), c("v6_4in6", "v6_4in6"))
  expect_identical(addr_format(got), rep("::ffff:192.0.2.1", 2L))
})

test_that("family is required and is not guessed", {
  expect_error(integer_to_addr("1"))
  expect_error(integer_to_addr("1", "v5"), class = "raddr_error_type")
  expect_error(integer_to_addr("1", 4), class = "raddr_error_type")
  # A missing family is a missing address, not a guess.
  expect_true(is.na(integer_to_addr("1", NA_character_)))
})

test_that("family recycles in both directions and mismatches error", {
  expect_length(integer_to_addr("1", c("v4", "v6")), 2L)
  expect_length(integer_to_addr(c("1", "2", "3"), "v6"), 3L)
  expect_error(integer_to_addr(c("1", "2", "3"), c("v4", "v6")))
})

test_that("the factor from addr_family() is accepted whole", {
  a <- addr_pton(integer_corpus)
  expect_true(all(integer_to_addr(addr_to_integer(a), addr_family(a)) == a))
})

# --- gotcha 26: R's integer is signed 32-bit ---------------------------------
#
# `.Machine$integer.max` is 2147483647, so half the IPv4 space does not fit and
# `as.integer()` answers NA rather than wrapping. This is why the default output
# is a string and the numeric one is a double.

test_that("addresses R's integer cannot hold are exact anyway", {
  a <- addr_pton(c("127.255.255.255", "128.0.0.0", "255.255.255.255"))

  expect_identical(
    addr_to_integer(a),
    c("2147483647", "2147483648", "4294967295")
  )
  expect_identical(
    addr_to_integer(a, output = "double"),
    c(2147483647, 2147483648, 4294967295)
  )
  # The boundary the gotcha is about: everything above the first row overflows
  # R's own integer type.
  expect_identical(
    suppressWarnings(as.integer(addr_to_integer(a, output = "double"))),
    c(2147483647L, NA_integer_, NA_integer_)
  )
})

test_that("a double is exact for IPv4 and the round trip proves it", {
  a <- addr_pton(c("0.0.0.0", "128.0.0.0", "192.0.2.1", "255.255.255.255"))
  expect_true(all(integer_to_addr(addr_to_integer(a, "double"), "v4") == a))
})

# --- gotcha 27: never a double for IPv6 --------------------------------------
#
# 2^128 is twenty-five orders of magnitude past the 2^53 a double represents
# exactly, so the answer is nothing rather than something close.

test_that("output = double is NA for every IPv6 row, 4-in-6 included", {
  a <- addr_pton(c("192.0.2.1", "::1", "::ffff:192.0.2.1", "::192.0.2.1"))
  expect_identical(
    addr_to_integer(a, output = "double"),
    c(3221225985, NA, NA, NA)
  )
})

test_that("a double above 2^53 is not read as a number it cannot hold", {
  # 2^53 is the last exactly representable integer, and it is accepted.
  expect_false(is.na(integer_to_addr(2^53, "v6")))
  expect_true(is.na(integer_to_addr(2^54, "v6")))
  expect_true(is.na(integer_to_addr(1e300, "v6")))
  # The same value as digits is fine -- it is the carrier that was refused.
  expect_false(is.na(integer_to_addr("18014398509481984", "v6")))
})

# --- what decodes to NA ------------------------------------------------------

test_that("out of range for the family is NA", {
  expect_true(is.na(integer_to_addr("4294967296", "v4")))
  expect_false(is.na(integer_to_addr("4294967295", "v4")))
  expect_true(is.na(integer_to_addr(
    "340282366920938463463374607431768211456",
    "v6"
  )))
  expect_false(is.na(integer_to_addr(
    "340282366920938463463374607431768211455",
    "v6"
  )))
  # Forty digits cannot be an address whatever they say.
  expect_true(is.na(integer_to_addr(strrep("9", 40L), "v6")))
})

test_that("anything that is not unsigned decimal digits is NA", {
  bad <- c("-1", "+1", "1.0", "1e9", "0x10", "", " ", "one", "1 2", NA)
  expect_true(all(is.na(integer_to_addr(bad, "v4"))))
  expect_true(all(is.na(integer_to_addr(bad, "v6"))))
})

test_that("leading zeros and surrounding whitespace are read", {
  # Unambiguous in a decimal integer: there is no octal reading to fall into,
  # which is the trap research 08 failure 5 describes for dotted quads.
  expect_identical(
    addr_format(integer_to_addr(c("0000003221225985", " 3221225985 "), "v4")),
    rep("192.0.2.1", 2L)
  )
  # The digit-count check runs after the zeros are stripped, so a value padded
  # past 39 characters is still whatever it says it is.
  expect_identical(
    addr_format(integer_to_addr(strrep("0", 45L), "v4")),
    "0.0.0.0"
  )
})

test_that("the decoder signals nothing", {
  # Matching the other decoders in R/encoding.R: P2 is a promise about
  # addr_parse(), not about every shortcut.
  expect_silent(integer_to_addr(c("nope", "-1", NA), "v4"))
})

test_that("a missing address is a missing number", {
  a <- addr_pton(c("192.0.2.1", "not an address", "2001:db8::1"))
  expect_identical(is.na(addr_to_integer(a)), c(FALSE, TRUE, FALSE))
  expect_identical(
    is.na(addr_to_integer(a, output = "double")),
    c(FALSE, TRUE, TRUE)
  )
})

test_that("the empty vector round-trips as the empty vector", {
  expect_identical(addr_to_integer(addr_pton(character())), character())
  expect_identical(
    addr_to_integer(addr_pton(character()), output = "double"),
    double()
  )
  expect_length(integer_to_addr(character(), "v4"), 0L)
})

test_that("a character vector is a type error, not a parse", {
  expect_error(addr_to_integer("192.0.2.1"), class = "raddr_error_type")
  expect_error(addr_to_integer(addr_pton("::1"), output = "int"))
})

# --- the optional bignum path ------------------------------------------------
#
# The point of this section is that everything above ran without bignum.

test_that("output = bignum returns a biginteger when the package is there", {
  skip_if_not_installed("bignum")
  a <- addr_pton(integer_corpus)
  got <- addr_to_integer(a, output = "bignum")

  expect_s3_class(got, "bignum_biginteger")
  expect_identical(got, bignum::biginteger(addr_to_integer(a)))
  # And it goes back in.
  expect_true(all(integer_to_addr(got, addr_family(a)) == a))
})

test_that("a biginteger is read by its digits, not by as.character()", {
  skip_if_not_installed("bignum")
  # `as.character()` on a biginteger is the display form and rounds:
  # 2^128 - 1 comes back as "3.402824e+38". Reading that would silently give
  # the wrong address, so the decoder asks for decimal notation instead.
  big <- bignum::biginteger("340282366920938463463374607431768211455")
  expect_false(grepl("e", format(big, notation = "dec"), fixed = TRUE))
  expect_identical(
    addr_format(integer_to_addr(big, "v6")),
    "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
  )
})

test_that("every other output works with the package invisible", {
  # The point of the subissue, tested by hiding the package rather than by
  # uninstalling it. `ipaddress` fails this: `ip_to_integer()` calls
  # `check_installed("bignum")` before anything else, so it errors even for
  # IPv4, where no big number is involved (verified 2026-07-28, 1.0.3).
  local_mocked_bindings(has_bignum = function() FALSE)
  a <- addr_pton(integer_corpus)

  expect_silent(addr_to_integer(a))
  expect_silent(addr_to_integer(a, output = "double"))
  expect_silent(integer_to_addr(addr_to_integer(a), addr_family(a)))
  expect_identical(
    addr_to_integer(addr_pton("2001:db8::1")),
    "42540766411282592856903984951653826561"
  )
})

test_that("asking for bignum without bignum errors rather than degrading", {
  local_mocked_bindings(has_bignum = function() FALSE)
  expect_error(
    addr_to_integer(addr_pton("192.0.2.1"), output = "bignum"),
    class = "raddr_error_dependency"
  )
})

test_that("the character output is not a drop-in for the bignum one", {
  # Which is why the line above errors instead of quietly returning this. The
  # digits are right; the ordering is not, because character comparison is
  # lexicographic.
  chr <- addr_to_integer(addr_pton(c("0.0.0.9", "0.0.0.10", "1.0.0.0")))

  expect_identical(chr, c("9", "10", "16777216"))
  expect_identical(max(chr), "9")
  expect_identical(sort(chr), c("10", "16777216", "9"))

  skip_if_not_installed("bignum")
  big <- bignum::biginteger(chr)
  expect_identical(format(max(big), notation = "dec"), "16777216")
})

test_that("what bignum shows is not what it stores", {
  skip_if_not_installed("bignum")
  # The display is 7 significant figures by default and `as.character()` follows
  # it, so the obvious coercion of a correct value is a rounded string. Pinned
  # because the docs promise the stored value is exact anyway.
  big <- addr_to_integer(addr_pton("2001:db8::1"), output = "bignum")

  expect_identical(as.character(big), "4.254077e+37")
  expect_identical(
    format(big, notation = "dec"),
    "42540766411282592856903984951653826561"
  )
  expect_true(
    big == bignum::biginteger("42540766411282592856903984951653826561")
  )
})

test_that("bit64's integer64 is read exactly", {
  skip_if_not_installed("bit64")
  # Its as.character() is exact, which is what the decoder relies on. The value
  # is ::ffff:192.0.2.1, chosen because it is past 2^32 and inside 2^53.
  expect_identical(
    addr_format(integer_to_addr(bit64::as.integer64("281473902969345"), "v6")),
    "::ffff:192.0.2.1"
  )
})
