# The embedded-IPv4 extraction machinery. See docs/architecture.md section 8.1.
#
# These tests cover the layer BELOW `addr_classify()`: widening back down to a
# word, reading an arbitrary bit field out of the 128 bits, and resolving a
# mechanism to the geometry rows it reads. The mechanisms themselves are
# exercised through the record in test-classify.R.

# --- narrow_word(), and the pattern the whole convention exists for ----------

test_that("narrowing inverts widening, including 0x80000000", {
  # Section 5.1.1: a word is raw bits, and NA_integer_ IS the pattern
  # 0x80000000. So the round trip has to survive the one value R cannot hold as
  # a signed integer, in both directions.
  patterns <- c(0L, 1L, 2147483647L, NA_integer_, -1L, -2147483647L)
  expect_identical(narrow_word(widen_word(patterns)), patterns)

  expect_identical(narrow_word(2147483648), NA_integer_)
  expect_identical(widen_word(NA_integer_), 2147483648)

  # And it does not get there through a coercion warning.
  expect_silent(narrow_word(2147483648))
  expect_silent(narrow_word(c(0, 4294967295)))

  expect_identical(narrow_word(4294967295), -1L)
  expect_identical(narrow_word(numeric()), integer())
})

# --- read_bits() -------------------------------------------------------------

words_of <- function(literal) {
  parsed <- addr_pton(literal)
  lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(field(parsed, nm))
  )
}

test_that("a bit field is read at any offset and any length", {
  # RFC 4380 section 4's own worked layout, which uses five different offsets
  # and two different lengths across one address.
  words <- words_of("2001:0:4136:e378:8000:63bf:3fff:fdd2")
  at <- 1L

  expect_equal(read_bits(words, 0L, 32L, at), 0x20010000)
  expect_equal(read_bits(words, 32L, 32L, at), 0x4136e378)
  expect_equal(read_bits(words, 64L, 16L, at), 0x8000)
  expect_equal(read_bits(words, 80L, 16L, at), 0x63bf)
  expect_equal(read_bits(words, 96L, 32L, at), 0x3ffffdd2)

  # A single octet, and a single hextet.
  expect_equal(read_bits(words, 64L, 8L, at), 0x80)
  expect_equal(read_bits(words, 0L, 16L, at), 0x2001)
})

test_that("a field straddling a word boundary reads as one value", {
  # 6to4's V4ADDR is bits 16-47, which is the low half of w1 joined to the high
  # half of w2. Reading bits 32-63 instead -- gotcha 9 in docs/research/04 --
  # gives `2.4.0.0` for an address that embeds `192.0.2.4`.
  words <- words_of("2002:c000:204::")
  expect_equal(read_bits(words, 16L, 32L, 1L), 0xc0000204)
  expect_equal(read_bits(words, 32L, 32L, 1L), 0x02040000)

  # RFC 6052's /64 segment is bits 72-103, which straddles w3 and w4. This is
  # the RFC's own section 2.4 example for that length.
  words <- words_of("2001:db8:122:344:c0:2:2100::")
  expect_equal(read_bits(words, 72L, 32L, 1L), 0xc0000221)
})

test_that("reading is vectorized and never touches a bitwise operator", {
  # Bits 96-127 of `2001::8000:0` are 0x80000000, which R stores as
  # NA_integer_ -- so a bitwAnd()-based reader returns NA for it. That address
  # is a Teredo client at 127.255.255.255 once complemented, so the pattern is
  # reachable through the geometry rather than only through a hand-built word.
  words <- words_of(c("::", "2001::8000:0", "::ffff:ffff:ffff"))
  expect_equal(read_bits(words, 96L, 32L, 1:3), c(0, 0x80000000, 0xffffffff))
  expect_equal(read_bits(words, 96L, 32L, integer()), numeric())
})

# --- embedding_geometry() ----------------------------------------------------

test_that("a mechanism resolves to the geometry rows it reads", {
  # One geometry, two mechanisms: RFC 6052 keys NAT64 on prefix LENGTH, and the
  # length comes from each prefix's own block rather than a second table.
  wk <- embedding_geometry("nat64_wk")
  expect_equal(nrow(wk), 1L)
  expect_equal(wk$offset, 96L)
  expect_equal(wk$length, 32L)

  local <- embedding_geometry("nat64_local")
  expect_equal(nrow(local), 2L)
  expect_equal(local$offset, c(48L, 72L))
  expect_equal(local$length, c(16L, 16L))

  # Teredo's two roles arrive in RFC 4380 section 4's order, and exactly one of
  # them is complemented.
  teredo <- embedding_geometry("teredo")
  expect_equal(teredo$role, c("server", "client"))
  expect_equal(teredo$complement, c(FALSE, TRUE))

  # ISATAP is a geometry with no prefix, so nothing is looked up in the prefix
  # table for it.
  isatap <- embedding_geometry("isatap")
  expect_equal(nrow(isatap), 1L)
  expect_equal(isatap$offset, 96L)
})

test_that("every embedded_kind resolves to a total 32-bit geometry", {
  for (kind in raddr_embedded_kinds) {
    rows <- embedding_geometry(kind)
    expect_gt(nrow(rows), 0L)
    for (role in unique(rows$role)) {
      segments <- rows[rows$role == role, , drop = FALSE]
      expect_equal(sum(segments$length), 32L, info = paste(kind, role))
    }
  }
})

# --- the geometry table against RFC 6052 section 2.3 -------------------------

test_that("the NAT64 geometry is what RFC 6052 section 2.3 computes", {
  # Section 2.2's Figure 1 was transcribed by hand into six pairs of numbers,
  # which is the kind of data no amount of re-reading catches an error in. So
  # this derives the same six geometries from section 2.3's ALGORITHM instead
  # and requires them to agree:
  #
  #   "If the prefix is 96 bits long, extract the last 32 bits of the IPv6
  #    address; for the other prefix lengths, remove the 'u' octet to obtain a
  #    120-bit sequence (effectively shifting bits 72-127 to positions 64-119),
  #    then extract the 32 bits following the prefix."
  #
  # This is the check docs/research/04 asks for: implement 2.3 rather than
  # hard-coding six offset pairs. raddr does hard-code them, because the
  # geometry is public data -- so the algorithm grades the data.
  from_algorithm <- function(prefix_len) {
    if (prefix_len == 96L) {
      return(data.frame(offset = 96L, length = 32L))
    }
    # Positions in the 120-bit u-byte-deleted string, mapped back to the 128.
    shrunk <- prefix_len + 0:31
    bits <- ifelse(shrunk < 64L, shrunk, shrunk + 8L)
    # Consecutive runs become segments.
    starts <- c(TRUE, diff(bits) != 1L)
    run <- cumsum(starts)
    data.frame(
      offset = bits[starts],
      length = as.integer(tabulate(run))
    )
  }

  nat64 <- raddr_transition_embeddings[
    raddr_transition_embeddings$kind == "nat64",
  ]
  for (prefix_len in unique(nat64$prefix_len)) {
    stored <- nat64[nat64$prefix_len == prefix_len, c("offset", "length")]
    rownames(stored) <- NULL
    expect_equal(stored, from_algorithm(prefix_len), info = prefix_len)
  }

  # And the algorithm reproduces the two facts the figure is easiest to get
  # wrong on: /64 starts at 72, not 64, and /48 is not contiguous.
  expect_equal(from_algorithm(64L)$offset, 72L)
  expect_equal(nrow(from_algorithm(48L)), 2L)
})

test_that("RFC 6052's own section 2.4 table reads back at all six lengths", {
  # The RFC embeds ONE address, 192.0.2.33, under six network-specific
  # prefixes and prints the result. Reading its own table back is the closest
  # thing to a vendor-supplied test vector this geometry has, and it covers the
  # three lengths where the reserved u-byte splits the address as well as the
  # three where it does not.
  section_2_4 <- list(
    c("32", "2001:db8:c000:221::"),
    c("40", "2001:db8:1c0:2:21::"),
    c("48", "2001:db8:122:c000:2:2100::"),
    c("56", "2001:db8:122:3c0:0:221::"),
    c("64", "2001:db8:122:344:c0:2:2100::"),
    c("96", "2001:db8:122:344::192.0.2.33")
  )
  embedded <- widen_word(field(addr_pton("192.0.2.33"), "w4"))

  nat64 <- raddr_transition_embeddings[
    raddr_transition_embeddings$kind == "nat64",
  ]
  for (row in section_2_4) {
    prefix_len <- as.integer(row[[1L]])
    segments <- nat64[nat64$prefix_len == prefix_len, , drop = FALSE]
    words <- words_of(row[[2L]])
    expect_equal(
      read_embedded(words, segments, 1L),
      embedded,
      info = row[[2L]]
    )
  }

  # The same table read at the wrong offset. `offset = prefix length` is right
  # for five of the six and wrong by exactly 8 bits at /64, which is the trap
  # gotcha 3 in docs/research/04 records: it yields a plausible address.
  expect_equal(
    read_bits(words_of("2001:db8:122:344:c0:2:2100::"), 64L, 32L, 1L),
    0x00c00002
  )
})

# --- read_embedded() ---------------------------------------------------------

test_that("segments split by the reserved u-byte rejoin in order", {
  # docs/research/04's worked example: under a /48 prefix the true address
  # 192.0.2.33 is stored as bits 48-63 = c000 and bits 72-87 = 0221. A naive
  # contiguous 32-bit read at bit 48 yields 192.0.0.2 -- plausible, and wrong.
  words <- words_of("64:ff9b:1:c000:2:2100::")
  segments <- embedding_geometry("nat64_local")

  expect_equal(read_embedded(words, segments, 1L), 0xc0000221)
  expect_equal(read_bits(words, 48L, 32L, 1L), 0xc0000002)
})

test_that("the Teredo client is complemented and the server is not", {
  # RFC 4380 section 4, its own example address. Complementing both, or
  # neither, produces a wrong-but-routable-looking answer with no error.
  words <- words_of("2001:0:4136:e378:8000:63bf:3fff:fdd2")
  geometry <- embedding_geometry("teredo")

  server <- geometry[geometry$role == "server", ]
  client <- geometry[geometry$role == "client", ]

  expect_equal(read_embedded(words, server, 1L), 0x4136e378)
  expect_equal(read_embedded(words, client, 1L), 0xc000022d)
})
