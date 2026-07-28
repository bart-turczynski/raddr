# Properties that hold for every address, asserted over a corpus rather than
# over named examples. See docs/architecture.md sections 6.2.1 and 6.5.
#
# Nothing here needs an oracle. Each test states a relationship the package is
# supposed to keep between two surfaces that are implemented separately, so it
# fails when either one drifts -- which is the kind of breakage the per-function
# files cannot see, because each of them is only ever looking at one surface.

# Random bytes of both widths, so the corpus reaches parts of the space no
# hand-written literal does, plus the literals that are hazards in their own
# right: both ends of both families, the 4-in-6 forms, and a zoned address.
invariant_corpus <- local({
  set.seed(60221L)
  draw <- function(n, width) {
    lapply(seq_len(n), function(i) as.raw(sample(0:255, width, replace = TRUE)))
  }
  c(
    bytes_to_addr(draw(200L, 4L)),
    bytes_to_addr(draw(200L, 16L)),
    addr_pton(c(
      "0.0.0.0", "255.255.255.255", "128.0.0.0", "0.0.0.1", "10.2.0.52",
      "::", "::1", "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "8000::", "::8000:0", "7fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "2001:db8::1", "fe80::1%eth0", "::ffff:192.0.2.1", "::192.0.2.1",
      "64:ff9b::192.0.2.33"
    ))
  )
})

test_that("all four encodings decode to the same address", {
  # The four pairs share `words_to_addr()` and nothing else: the integer pair
  # does base-10^6 arithmetic, the other three read octets. Agreement between
  # them is the strongest statement available without an external oracle.
  a <- invariant_corpus
  from_integer <- integer_to_addr(addr_to_integer(a), addr_family(a))
  from_hex <- hex_to_addr(addr_to_hex(a))
  from_bytes <- bytes_to_addr(addr_to_bytes(a))
  from_binary <- binary_to_addr(addr_to_binary(a))

  expect_true(all(from_integer == a))
  expect_true(all(from_hex == a))
  expect_true(all(from_bytes == a))
  expect_true(all(from_binary == a))

  # And the family survives every one of them, which `==` does not check --
  # section 5.1.2 keeps the zone out of equality but not the family.
  expect_identical(addr_family(from_integer), addr_family(a))
  expect_identical(addr_family(from_hex), addr_family(a))
  expect_identical(addr_family(from_bytes), addr_family(a))
  expect_identical(addr_family(from_binary), addr_family(a))
})

test_that("ordering addresses agrees with ordering their integers", {
  # Two independent implementations of the same claim about the bits:
  # `vec_proxy_compare()` in R/address.R sorts by word, and the integer encoder
  # collapses the words to one number. Comparing across families is not a
  # question this asks -- section 6.5.1 makes the width the family.
  for (fam in c("v4", "v6")) {
    a <- invariant_corpus[addr_family(invariant_corpus) == fam]
    digits <- addr_to_integer(a)
    # Zero padding to a common width makes lexicographic order numeric order,
    # which avoids needing a numeric type wide enough to hold the values.
    padded <- paste0(strrep("0", 39L - nchar(digits)), digits)

    expect_identical(order(a), order(padded))
    expect_identical(addr_to_integer(sort(a)), digits[order(padded)])
  }
})

test_that("an address integer never needs more than 39 digits", {
  # 2^128 - 1 is 39 digits, so this is the ceiling the decoder rejects above.
  digits <- addr_to_integer(invariant_corpus)
  expect_true(all(nchar(digits) <= 39L))
  expect_true(all(grepl("^[0-9]+$", digits)))
  # No leading zeros either: the encoder strips its own chunk padding, and a
  # padded number would break the ordering test above.
  expect_false(any(grepl("^0.", digits)))
})

test_that("a pointer name has the label count its tree fixes", {
  # IPv6 is always 32 nibble labels plus `ip6` and `arpa`; IPv4 is always 4
  # octet labels plus `in-addr` and `arpa`. Neither depends on the text form,
  # which is the whole point of building the name from the octets.
  a <- invariant_corpus
  names <- addr_reverse_pointer(a)

  expect_true(all(endsWith(names, ".")))
  # The trailing dot stands for the root label and contributes no field.
  fields <- lengths(strsplit(names, ".", fixed = TRUE))
  want <- ifelse(addr_family(a) == "v4", 6L, 34L)
  expect_identical(fields, as.integer(want))

  expect_true(all(endsWith(names[want == 6L], ".in-addr.arpa.")))
  expect_true(all(endsWith(names[want == 34L], ".ip6.arpa.")))
  # Lowercase throughout: RFC 1035 section 3.1 makes comparison
  # case-insensitive, so this is a choice about emission and worth holding to.
  expect_false(any(grepl("[A-Z]", names)))
  # Every IPv6 label before the suffix is a single hex digit.
  expect_true(all(
    grepl("^([0-9a-f][.]){32}ip6[.]arpa[.]$", names[want == 34L])
  ))
  expect_true(all(
    grepl("^([0-9]{1,3}[.]){4}in-addr[.]arpa[.]$", names[want == 6L])
  ))
})
