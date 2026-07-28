# The shipped engines against the naive ones in helper-slow.R. See
# docs/architecture.md section 11.3.
#
# Nothing here needs an oracle, and nothing here is an example. Each test says
# that two implementations of one specification answer the same thing over a
# corpus, where the fast side works in bulk and the slow side works one
# character at a time. The per-function files carry the named cases a human
# thought to write down; this file covers the space between them.
#
# The corpus itself is in helper-corpus.R, because test-invariants.R runs over
# it too.

# --- the parsers -------------------------------------------------------------

expect_dialect_agrees <- function(literals, dialect) {
  fast <- dialect_fn(dialect)(literals)
  slow <- slow_parse(literals, dialect)

  expect_identical(addr_to_hex(fast), slow$hex)
  expect_identical(as.character(addr_family(fast)), slow$family)
  expect_identical(addr_zone(fast), slow$zone)
}

test_that("the corpus is worth running two implementations over", {
  # An agreement test between two parsers passes trivially if both reject
  # everything, so the corpus has to be shown to reach both answers -- and to
  # reach the disagreements section 3 is about, which is the whole package.
  literals <- corpus_literals()
  expect_gt(length(literals), 1800L)

  accepted <- vapply(
    c("strict", "whatwg", "pton", "aton", "getaddrinfo", "curl"),
    function(d) sum(!is.na(addr_family(dialect_fn(d)(literals)))),
    integer(1)
  )
  expect_true(all(accepted > 500L))
  expect_true(all(accepted < length(literals)))

  # Every dialect differs from every other one somewhere in here.
  readings <- lapply(
    c("strict", "whatwg", "pton", "aton", "getaddrinfo", "curl"),
    function(d) addr_expand(dialect_fn(d)(literals))
  )
  pairs <- utils::combn(length(readings), 2L)
  differ <- apply(pairs, 2L, function(p) {
    !identical(readings[[p[[1L]]]], readings[[p[[2L]]]])
  })
  expect_true(all(differ))

  # And both families, and a zone, are actually represented.
  families <- addr_family(addr_pton(literals))
  expect_true(all(c("v4", "v6", "v6_4in6") %in% as.character(families)))
  expect_true(any(!is.na(addr_zone(addr_pton(literals)))))
})

test_that("the strict dialect agrees with the naive parser", {
  expect_dialect_agrees(corpus_literals(), "strict")
})

test_that("the whatwg dialect agrees with the naive parser", {
  expect_dialect_agrees(corpus_literals(), "whatwg")
})

test_that("the pton dialect agrees with the naive parser", {
  expect_dialect_agrees(corpus_literals(), "pton")
})

test_that("the aton dialect agrees with the naive parser", {
  expect_dialect_agrees(corpus_literals(), "aton")
})

test_that("the getaddrinfo composition agrees with the naive one", {
  # The composition leaks in two places -- the whitespace gate and the fe80::/10
  # scope lift (section 3.2) -- and the naive side composes rather than
  # reimplementing, so this is a test of the leaks and not of `pton` again.
  expect_dialect_agrees(corpus_literals(), "getaddrinfo")
})

test_that("the curl composition agrees with the naive one", {
  expect_dialect_agrees(corpus_literals(), "curl")
})

# --- the renderers -----------------------------------------------------------

# Random bytes of both widths, plus zero-heavy ones, because RFC 5952 section
# 4.2 is entirely about runs of zero fields and a uniform draw almost never
# produces one.
slow_render_corpus <- local({
  set.seed(5952L)
  draw <- function(n, width, holes) {
    lapply(seq_len(n), function(i) {
      b <- as.raw(sample(0:255, width, replace = TRUE))
      if (holes) {
        b[sample(seq_len(width), sample(seq_len(width), 1L))] <- as.raw(0)
      }
      b
    })
  }
  c(
    bytes_to_addr(draw(150L, 4L, FALSE)),
    bytes_to_addr(draw(150L, 4L, TRUE)),
    bytes_to_addr(draw(150L, 16L, FALSE)),
    bytes_to_addr(draw(700L, 16L, TRUE)),
    addr_pton(c(
      # Both ends of both families, and the words the storage convention is
      # about (section 5.1.1).
      "0.0.0.0", "255.255.255.255", "128.0.0.0", "0.0.0.1",
      "::", "::1", "1::", "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "8000::", "::8000:0", "7fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      # The RFC 5952 section 4.2 rules, one address each.
      "1:0:0:1:0:0:1:1", "2001:db8:0:1:1:1:1:1", "0:1:2:3:4:5:6:7",
      "1:2:3:4:5:6:7:0", "1:2:3:4:5:6:0:8", "0:0:1:0:0:0:1:1",
      # The mixed form, and the zone.
      "::ffff:192.0.2.1", "::ffff:0:0", "::ffff:255.255.255.255",
      "::192.0.2.1", "64:ff9b::192.0.2.33", "fe80::1%eth0", "fe80::1%",
      # And a missing address, which renders as NA rather than as text.
      NA_character_
    ))
  )
})

# The bits as text, which is what the naive renderer reads. It reaches none of
# `addr_format()`'s machinery: no hextet matrix, no blanked run, no `sub()` over
# a joined string.
slow_render_parts <- function(x) {
  list(
    hex = addr_to_hex(x),
    family = as.character(addr_family(x)),
    zone = addr_zone(x)
  )
}

test_that("addr_format() agrees with the naive RFC 5952 renderer", {
  x <- slow_render_corpus
  parts <- slow_render_parts(x)
  expect_identical(
    addr_format(x),
    slow_format(parts$hex, parts$family, parts$zone)
  )
  # Not vacuous: the corpus reaches every branch of section 4.2 and section 5.
  rendered <- addr_format(x)
  expect_true(any(grepl("::", rendered, fixed = TRUE)))
  expect_true(any(startsWith(rendered[!is.na(rendered)], "::")))
  expect_true(any(endsWith(rendered[!is.na(rendered)], "::")))
  expect_true(any(grepl("^[^:]+::[^:]+$", rendered)))
  expect_true(any(grepl(":0:", rendered, fixed = TRUE)))
  expect_true(any(grepl("::ffff:[0-9]+[.]", rendered)))
})

test_that("addr_expand() agrees with the naive renderer", {
  x <- slow_render_corpus
  parts <- slow_render_parts(x)
  expect_identical(
    addr_expand(x),
    slow_expand(parts$hex, parts$family, parts$zone)
  )
})

test_that("the naive renderer round-trips through the naive parser", {
  # Both sides of the package's own round-trip claim (section 6.2), asserted
  # without either of the package's implementations: naive text, naive bits.
  x <- slow_render_corpus
  parts <- slow_render_parts(x)
  known <- !is.na(parts$family)

  text <- slow_format(parts$hex, parts$family, parts$zone)[known]
  back <- slow_parse(sub("%.*$", "", text), "pton")

  expect_identical(back$hex, parts$hex[known])
  expect_identical(back$family, parts$family[known])
})
