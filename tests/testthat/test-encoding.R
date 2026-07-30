# The three encoding round-trip pairs. See docs/architecture.md section 6.5, and
# the research note docs/research/08-encoding-reverse.md it is graded against.
#
# The research document is organized as a list of *round-trip failures* -- the
# numbered cases where encode-then-decode does not return what went in -- so the
# sections below are organized the same way: first that the pairs round-trip,
# then one section per failure the encodings are supposed to have, asserting the
# failure happens where the document says and nowhere else.

# A corpus wide enough that a round trip over it exercises both families, both
# IPv6 sub-families, and every word position holding the one bit pattern R
# spends on NA_integer_ (section 5.1.1).
encoding_corpus <- c(
  # IPv4, including both ends and the address whose word is 0x80000000
  "0.0.0.0",
  "127.0.0.1",
  "192.0.2.1",
  "128.0.0.0",
  "255.255.255.255",
  # IPv6, including both ends
  "::",
  "::1",
  "2001:db8::1",
  "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
  # 0x80000000 in each of the four words in turn
  "8000::",
  "0:0:8000:0:0:0:0:0",
  "0:0:0:0:8000:0:0:0",
  "::8000:0",
  # The AS112 direct-delegation prefix, whose second word is the pattern; the
  # address a bitwise matcher never matches (see the header of R/classify.R)
  "2620:4f:8000::",
  # The three forms that share their low 32 bits
  "::ffff:192.0.2.1",
  "::192.0.2.1",
  "64:ff9b::192.0.2.33"
)

# --- the symmetric-pair convention -------------------------------------------

test_that("all three pairs round-trip the corpus, bits and family", {
  a <- addr_pton(encoding_corpus)

  for (pair in list(
    list(to = addr_to_bytes, from = bytes_to_addr),
    list(to = addr_to_hex, from = hex_to_addr),
    list(to = addr_to_binary, from = binary_to_addr)
  )) {
    back <- pair$from(pair$to(a))
    expect_true(all(back == a))
    expect_identical(addr_family(back), addr_family(a))
  }
})

test_that("all three pairs round-trip random words at every position", {
  # The corpus above is hand-picked, so it can only exercise the word boundaries
  # someone thought of. An offset that is wrong by one byte in `string_word()`
  # survives a hand-picked corpus and does not survive this.
  set.seed(20260728L)
  n <- 500L
  words <- lapply(seq_len(4L), function(i) {
    narrow_word(floor(stats::runif(n, 0, 4294967296)))
  })
  a <- c(
    raddr_address(0L, 0L, 0L, words[[4L]], "v4"),
    raddr_address(words[[1L]], words[[2L]], words[[3L]], words[[4L]], "v6")
  )

  expect_true(all(bytes_to_addr(addr_to_bytes(a)) == a))
  expect_true(all(hex_to_addr(addr_to_hex(a)) == a))
  expect_true(all(binary_to_addr(addr_to_binary(a)) == a))
})

test_that("the three encodings are three renderings of the same octets", {
  a <- addr_pton(encoding_corpus)
  bytes <- addr_to_bytes(a)

  by_hand <- vapply(
    bytes,
    function(b) paste(sprintf("%02x", as.integer(b)), collapse = ""),
    character(1L)
  )
  expect_identical(addr_to_hex(a), by_hand)
  expect_identical(
    nchar(addr_to_binary(a)),
    4L * nchar(addr_to_hex(a))
  )
})

test_that("the encoders emit the values the research document names", {
  expect_identical(addr_to_hex(addr_pton("192.0.2.1")), "c0000201")
  expect_identical(
    addr_to_hex(addr_pton("2001:db8::1")),
    "20010db8000000000000000000000001"
  )
  expect_identical(
    addr_to_binary(addr_pton("192.0.2.1")),
    "11000000000000000000001000000001"
  )
  expect_identical(
    addr_to_bytes(addr_pton("192.0.2.1"))[[1L]],
    as.raw(c(192L, 0L, 2L, 1L))
  )
  expect_identical(
    addr_to_bytes(addr_pton("::ffff:192.0.2.1"))[[1L]],
    as.raw(c(rep(0L, 10L), 255L, 255L, 192L, 0L, 2L, 1L))
  )
})

# --- round-trip failure 2: the low 32 bits do not name one object ------------
#
# RFC 4291 section 2.5.5 gives the IPv4-mapped layout, so `::ffff:192.0.2.1` and
# `192.0.2.1` share four octets. The research document's point is that an
# encoding without a declared family cannot tell three distinct objects apart.
# raddr declares the family by the width, so this is where that is pinned.

test_that("the width is the family, not the bits", {
  a <- addr_pton(c("192.0.2.1", "::ffff:192.0.2.1", "::192.0.2.1"))

  expect_identical(nchar(addr_to_hex(a)), c(8L, 32L, 32L))
  expect_identical(nchar(addr_to_binary(a)), c(32L, 128L, 128L))
  expect_identical(lengths(addr_to_bytes(a)), c(4L, 16L, 16L))
})

test_that("the three forms decode back to three different addresses", {
  a <- addr_pton(c("192.0.2.1", "::ffff:192.0.2.1", "::192.0.2.1"))
  back <- hex_to_addr(addr_to_hex(a))

  expect_identical(
    as.character(addr_family(back)),
    c("v4", "v6_4in6", "v6")
  )
  # Not one of the three pairs is equal to another, before or after the trip.
  expect_false(back[[1L]] == back[[2L]])
  expect_false(back[[2L]] == back[[3L]])
  expect_false(back[[1L]] == back[[3L]])
})

test_that("the 4-in-6 form encodes to sixteen octets, not the four it embeds", {
  # Research 08 gotcha 23: silently demoting this is the surprise to avoid.
  expect_identical(lengths(addr_to_bytes(addr_pton("::ffff:127.0.0.1"))), 16L)
  expect_identical(
    addr_to_hex(addr_pton("::ffff:127.0.0.1")),
    "00000000000000000000ffff7f000001"
  )
})

# --- round-trip failure 5: leading zeros, in both directions -----------------
#
# RFC 5952 section 4.1 suppresses them in text; these forms require them. The
# research document calls mixing the two rules a common bug.

test_that("output is fixed width and zero padded, against RFC 5952 4.1", {
  expect_identical(
    addr_to_hex(addr_pton("::1")),
    paste0(strrep("0", 31L), "1")
  )
  expect_identical(addr_to_hex(addr_pton("0.0.0.1")), "00000001")
  expect_identical(addr_to_binary(addr_pton("0.0.0.0")), strrep("0", 32L))
  expect_identical(addr_to_binary(addr_pton("::")), strrep("0", 128L))
  expect_identical(
    addr_to_binary(addr_pton("255.255.255.255")),
    strrep("1", 32L)
  )
})

test_that("a width the family does not fix decodes to NA, never padded", {
  # Seven digits is an IPv4 address missing one zero or an IPv6 address missing
  # twenty-five. The document's rule is that a short string is a guess.
  short <- c("c000201", "1", "", strrep("0", 31L), strrep("0", 33L))
  expect_true(all(is.na(hex_to_addr(short))))

  expect_true(all(is.na(binary_to_addr(c(
    strrep("0", 31L),
    strrep("0", 33L),
    strrep("0", 127L),
    strrep("0", 129L)
  )))))

  expect_true(all(is.na(bytes_to_addr(list(
    as.raw(1:3),
    as.raw(1:5),
    as.raw(1:15),
    as.raw(1:17),
    raw(0)
  )))))
})

test_that("a digit outside the base decodes to NA", {
  expect_true(is.na(hex_to_addr("c000020g")))
  expect_true(is.na(hex_to_addr("c000 020")))
  expect_true(is.na(binary_to_addr(strrep("2", 32L))))
  # Eight hex digits are not thirty-two binary ones.
  expect_true(is.na(binary_to_addr("c0000201")))
})

# --- round-trip failure 1: the zone does not survive -------------------------
#
# RFC 4007 section 6: zone indices are strictly local to the node, so nothing in
# the octets can carry one. Section 5.1.2 keeps the zone out of equality, so the
# round trip still satisfies `==` -- that is the distinction being pinned here,
# because "it round-trips" and "nothing was lost" are not the same claim.

test_that("two addresses differing only by zone encode identically", {
  a <- addr_pton(c("fe80::1%eth0", "fe80::1%eth1"))
  expect_identical(addr_to_hex(a)[[1L]], addr_to_hex(a)[[2L]])
  expect_identical(addr_to_bytes(a)[[1L]], addr_to_bytes(a)[[2L]])
})

test_that("the round trip keeps equality and drops the zone", {
  a <- addr_pton("fe80::1%eth0")
  back <- hex_to_addr(addr_to_hex(a))

  expect_true(back == a)
  expect_identical(addr_zone(a), "eth0")
  expect_identical(addr_zone(back), NA_character_)
})

# --- case, the 0x prefix, and grouping ---------------------------------------

test_that("hex output is lowercase and uppercase input is accepted", {
  # RFC 5952 4.3 for the output; RFC 3596 2.5 and RFC 2874 2.2.1 print their
  # own examples in uppercase, which is why the input side has to read it.
  expect_identical(
    addr_to_hex(addr_pton("2001:DB8::AB")),
    "20010db80000000000000000000000ab"
  )
  expect_true(hex_to_addr("C0000201") == addr_pton("192.0.2.1"))
  expect_true(hex_to_addr("C0000201") == hex_to_addr("c0000201"))
})

test_that("a 0x prefix is read and never written", {
  expect_true(hex_to_addr("0xc0000201") == addr_pton("192.0.2.1"))
  expect_true(hex_to_addr("0XC0000201") == addr_pton("192.0.2.1"))
  expect_identical(addr_to_hex(hex_to_addr("0xc0000201")), "c0000201")
  # The prefix is not a license to drop digits.
  expect_true(is.na(hex_to_addr("0xc201")))
})

test_that("whitespace grouping is stripped by both string decoders", {
  expect_true(hex_to_addr("c000 0201") == addr_pton("192.0.2.1"))
  expect_true(
    binary_to_addr("11000000 00000000 00000010 00000001") ==
      addr_pton("192.0.2.1")
  )
  expect_true(
    hex_to_addr("2001 0db8 0000 0000 0000 0000 0000 0001") ==
      addr_pton("2001:db8::1")
  )
})

# --- missingness and empty input ---------------------------------------------

test_that("a missing address encodes to missing, in each form's own way", {
  a <- addr_pton(c("192.0.2.1", "not an address"))

  expect_identical(addr_to_hex(a), c("c0000201", NA_character_))
  expect_identical(addr_to_binary(a)[[2L]], NA_character_)

  bytes <- addr_to_bytes(a)
  expect_null(bytes[[2L]])
  expect_identical(is.na(bytes), c(FALSE, TRUE))
})

test_that("missing input decodes to a missing address", {
  expect_true(is.na(hex_to_addr(NA_character_)))
  expect_true(is.na(binary_to_addr(NA_character_)))
  expect_true(is.na(bytes_to_addr(list(NULL))))
  # Anything that is not a raw vector is not an encoding of an address.
  expect_true(is.na(bytes_to_addr(list(c(192L, 0L, 2L, 1L)))))
})

test_that("empty input gives empty output of the right type", {
  none <- addr_pton(character())

  expect_identical(addr_to_hex(none), character())
  expect_identical(addr_to_binary(none), character())
  expect_identical(vctrs::vec_size(addr_to_bytes(none)), 0L)

  expect_identical(vctrs::vec_size(hex_to_addr(character())), 0L)
  expect_identical(vctrs::vec_size(binary_to_addr(character())), 0L)
  expect_identical(vctrs::vec_size(bytes_to_addr(list())), 0L)
  expect_true(is_raddr_address(bytes_to_addr(list())))
})

# --- type errors -------------------------------------------------------------

test_that("the encoders refuse anything that is not a raddr_address", {
  expect_error(addr_to_hex("192.0.2.1"), class = "raddr_error_type")
  expect_error(addr_to_binary(1L), class = "raddr_error_type")
  expect_error(addr_to_bytes(NULL), class = "raddr_error_type")
})

test_that("bytes_to_addr refuses a bare raw vector rather than guessing", {
  # Eight octets are one malformed address or two IPv4 addresses; the caller
  # knows which and the function does not.
  expect_error(
    bytes_to_addr(as.raw(c(192L, 0L, 2L, 1L))),
    class = "raddr_error_type"
  )
  expect_error(bytes_to_addr("c0000201"), class = "raddr_error_type")
  # Wrapped, it is unambiguous.
  one <- bytes_to_addr(list(as.raw(c(192L, 0L, 2L, 1L))))
  expect_true(one == addr_pton("192.0.2.1"))
})

# --- vectorization ------------------------------------------------------------

test_that("every encoder and decoder is vectorized over a mixed vector", {
  a <- addr_pton(c("192.0.2.1", NA, "2001:db8::1", "::ffff:10.0.0.1"))

  expect_length(addr_to_hex(a), 4L)
  expect_length(addr_to_binary(a), 4L)
  expect_identical(vctrs::vec_size(addr_to_bytes(a)), 4L)

  back <- bytes_to_addr(addr_to_bytes(a))
  expect_identical(is.na(back), is.na(a))
  expect_identical(addr_family(back), addr_family(a))
})
