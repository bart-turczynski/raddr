# Generated properties. See docs/architecture.md section 11.9.
#
# test-invariants.R asserts the same *kind* of claim over a frozen corpus: 400
# byte draws behind `set.seed(60221L)` and 2139 hostile literals. This file
# quantifies over a generator instead, and the difference is not more inputs --
# it is the two things a frozen corpus structurally cannot give.
#
# The first is the **shrunk counterexample**. A corpus failure says "one of 2139
# literals broke totality" and leaves the reader to bisect it by hand; hedgehog
# hands back the smallest input that still fails, which is usually the bug
# stated in one line. That is the entire reason for the dependency.
#
# The second is **tuples**. Transitivity is a claim about three addresses at
# once, and a flat corpus cannot express it -- which is why, until this file, it
# was the one order axiom section 5.1.2 claims and nothing checked.
#
# The generators are built out of base R -- `paste`, `sprintf`, `as.hexmode` --
# and never out of the parser they feed. Same rule as section 11.4's wrapper
# round-trip: a generator that spelled its addresses with `addr_format()` would
# round-trip through the renderer's mistakes and report agreement.
#
# `hedgehog` is Suggests (section 12), so every block below skips when it is
# absent, and nothing at file scope touches the namespace.

# The draw count is passed explicitly at every call rather than left to
# `getOption("hedgehog.tests", 100)`. Pinning the option would set it for the
# whole testthat run -- every later file in the same process inherits it -- and
# a property whose sample size depends on which files ran first is exactly the
# silent drift this file exists to catch. Low everywhere by default so the CRAN
# machines pay for 25 draws, high under NOT_CRAN where a real sweep is free.
property_tests <- function(cran = 25L, local = 400L) {
  if (identical(Sys.getenv("NOT_CRAN"), "true")) local else cran
}

# --- generators ---------------------------------------------------------------

# `gen.element` shrinks toward its FIRST element, so every pool below is ordered
# simplest-first: the counterexample hedgehog reports is the one carrying the
# fewest incidental features.

# Addresses are drawn a WORD at a time, because the hazards this package is
# built around are word-level facts and an octet-level draw reaches them only by
# a four-way coincidence. `0x80000000` is the one that matters -- section 5.1.1
# stores it as `NA_integer_` -- and four independently drawn octets land on it
# about once in 10^5, so a uniform generator is blind to it in any sample a test
# suite can afford.
#
# Mutation grading is what forced this, twice. With uniform octets, a renderer
# that dropped a trailing zero octet survived the round-trip property, and
# removing `widen_word()`'s NA guard -- the ipaddress bug of O11(b) -- survived
# the order property outright. Both are caught now.
property_hazard_words <- list(
  c(0L, 0L, 0L, 0L),
  c(128L, 0L, 0L, 0L), # 0x80000000, the word stored as NA
  c(128L, 0L, 0L, 1L),
  c(127L, 255L, 255L, 255L),
  c(255L, 255L, 255L, 255L),
  c(0L, 0L, 0L, 1L)
)

# Half hazard, half uniform, so the draw still reaches the rest of the space.
gen_word <- function() {
  hedgehog::gen.choice(
    hedgehog::gen.element(property_hazard_words),
    hedgehog::gen.c(of = 4, hedgehog::gen.element(0:255))
  )
}

gen_octets <- function(width) {
  hedgehog::gen.c(of = width %/% 4L, gen_word())
}

# An address from its bytes, which is the one entry point that cannot beg the
# question: the octets ARE the address, so nothing about the text grammar is
# assumed to build one.
gen_address <- function(widths = c(4L, 16L)) {
  hedgehog::gen.and_then(hedgehog::gen.element(widths), function(w) {
    hedgehog::gen.map(
      function(o) bytes_to_addr(list(as.raw(o))),
      gen_octets(w)
    )
  })
}

# Every radix the IPv4 grammars disagree about, both sides of each arity bound,
# and the digitless `0x` that decides `empty_hex_final` (section 3.1).
property_v4_parts <- c(
  "0", "1", "10", "127", "255", "256",
  "01", "010", "0377", "09", "00000001",
  "0x", "0xff", "0Xff", "0x100",
  "65535", "65536", "16777216", "4294967295", "4294967296",
  "", "x", "-1"
)

# Junk at the ends, where `stop_at_space` truncates to a shorter arity and the
# authority delimiters decide whether there was an address here at all.
property_v4_junk <- c("", ".", "..", " ", "\t", " junk", ":80", "%eth0", "/24")

property_v6_parts <- c(
  "0", "1", "ffff", "abcd", "0000", "00ff", "FFFF",
  "12345", "000000001", "0x1", "g", ""
)

property_v6_junk <- c("", ":", "::", ":::", " ", "g", "%", "%eth0", "%lo0%x")

# One to five parts joined by dots, with junk on the end. The arity is drawn
# separately from the parts so shrinking can cut the literal down to one part
# without also rewriting which parts survived.
gen_literal_v4 <- function() {
  hedgehog::gen.map(
    function(x) {
      paste0(
        paste(x$parts[seq_len(x$k)], collapse = "."),
        x$tail
      )
    },
    list(
      k = hedgehog::gen.element(1:5),
      parts = hedgehog::gen.c(of = 5, hedgehog::gen.element(property_v4_parts)),
      tail = hedgehog::gen.element(property_v4_junk)
    )
  )
}

# Eight hextets, an elision of a drawn run, an optional dotted tail and an
# optional zone. `run = 0` means no elision, and it is first in the pool so the
# shrunk literal is the one without one.
gen_literal_v6 <- function() {
  hedgehog::gen.map(
    function(x) {
      pieces <- x$parts
      if (x$run > 0L) {
        to <- min(8L, x$from + x$run - 1L)
        pieces <- c(
          if (x$from > 1L) pieces[seq_len(x$from - 1L)],
          "",
          if (to < 8L) pieces[seq.int(to + 1L, 8L)]
        )
      }
      out <- paste(pieces, collapse = ":")
      if (x$quad > 0L) {
        # Replace the last two groups with a dotted tail, which is the only
        # place RFC 4291 section 2.2 allows one.
        tail <- paste(x$octets[seq_len(4L)], collapse = ".")
        out <- sub(":[^:]*:[^:]*$", paste0(":", tail), out)
      }
      paste0(x$head, out, x$tail)
    },
    list(
      parts = hedgehog::gen.c(of = 8, hedgehog::gen.element(property_v6_parts)),
      from = hedgehog::gen.element(1:8),
      run = hedgehog::gen.element(0:4),
      quad = hedgehog::gen.element(0:1),
      octets = hedgehog::gen.c(
        of = 4,
        hedgehog::gen.element(c(0, 1, 255, 256))
      ),
      head = hedgehog::gen.element(c("", ":", "::", " ")),
      tail = hedgehog::gen.element(property_v6_junk)
    )
  )
}

gen_literal <- function() {
  hedgehog::gen.choice(gen_literal_v4(), gen_literal_v6())
}

property_dialects <- c(
  "strict", "whatwg", "pton", "aton", "getaddrinfo", "curl"
)

# --- rendering and reading are inverses (section 5.1.3) -----------------------

test_that("a generated address survives being rendered and read back", {
  skip_if_not_installed("hedgehog")
  # Section 5.1.3's claim, quantified over the value rather than over a fixed
  # draw. Both renderers, because `addr_expand()` and `addr_format()` are
  # separate code paths over the same words, and both must land back on the
  # address they started from -- family included, which `==` does not check.
  set.seed(5952L)
  hedgehog::forall(gen_address(), function(a) {
    for (render in list(addr_format, addr_expand)) {
      back <- addr_pton(render(a))
      expect_true(back == a)
      expect_identical(addr_family(back), addr_family(a))
      # And the fixed point, which is the half that catches a renderer that is
      # merely self-consistent rather than canonical.
      expect_identical(render(back), render(a))
    }
  }, tests = property_tests())
})

test_that("the four encodings decode to the generated address", {
  skip_if_not_installed("hedgehog")
  # The integer pair does base-10^6 arithmetic and the other three read octets
  # (section 6.5). Agreement between them is the strongest statement available
  # without an oracle, and a generated draw reaches the carry patterns a fixed
  # corpus only reaches by luck.
  set.seed(60221L)
  hedgehog::forall(gen_address(), function(a) {
    expect_true(integer_to_addr(addr_to_integer(a), addr_family(a)) == a)
    expect_true(hex_to_addr(addr_to_hex(a)) == a)
    expect_true(bytes_to_addr(addr_to_bytes(a)) == a)
    expect_true(binary_to_addr(addr_to_binary(a)) == a)
  }, tests = property_tests())
})

# --- ordering (section 5.1.2) -------------------------------------------------

# Three addresses, sometimes with repeats, because transitivity is only
# interesting where ties are reachable and 128 random bits never collide. The
# shapes are ordered so the degenerate one shrinks out first.
gen_triple <- function() {
  hedgehog::gen.map(
    function(x) {
      pick <- switch(
        x$shape,
        aaa = c(1L, 1L, 1L),
        aab = c(1L, 1L, 2L),
        aba = c(1L, 2L, 1L),
        abb = c(1L, 2L, 2L),
        c(1L, 2L, 3L)
      )
      lapply(pick, function(i) x$addrs[[i]])
    },
    list(
      shape = hedgehog::gen.element(c("aaa", "aab", "aba", "abb", "abc")),
      addrs = hedgehog::gen.c(of = 3, gen_address())
    )
  )
}

test_that("the order over addresses is transitive", {
  skip_if_not_installed("hedgehog")
  # Section 5.1.2 makes the order TOTAL so `sort()` works on a mixed vector, and
  # a total order has to be transitive -- but transitivity is a claim about
  # three addresses at once, so no corpus test states it. Both directions,
  # because `<=` transitive and `>=` transitive are separate facts once the
  # family rank is part of the comparison.
  set.seed(4291L)
  hedgehog::forall(gen_triple(), function(t) {
    ab <- vctrs::vec_compare(t[[1L]], t[[2L]])
    bc <- vctrs::vec_compare(t[[2L]], t[[3L]])
    ac <- vctrs::vec_compare(t[[1L]], t[[3L]])

    expect_false(is.na(ab))
    expect_false(is.na(bc))
    expect_false(is.na(ac))

    if (ab <= 0L && bc <= 0L) {
      expect_true(ac <= 0L)
    }
    if (ab >= 0L && bc >= 0L) {
      expect_true(ac >= 0L)
    }
    # Ties are an equivalence, not merely a zero: if a == b and b == c then
    # a == c, which is what lets `unique()` group by the proxy.
    if (ab == 0L && bc == 0L) {
      expect_identical(ac, 0L)
    }
  }, tests = property_tests())
})

# --- containment (section 6.3) ------------------------------------------------

# Masking done as byte arithmetic, sharing nothing with the divisor arithmetic
# in R/within.R that it is used to check.
property_mask <- function(o, len) {
  n <- length(o)
  keep <- len %/% 8L
  rem <- len %% 8L
  if (keep < n) {
    o[[keep + 1L]] <- if (rem == 0L) {
      0
    } else {
      o[[keep + 1L]] - o[[keep + 1L]] %% 2^(8L - rem)
    }
  }
  if (keep + 2L <= n) {
    o[seq.int(keep + 2L, n)] <- 0
  }
  o
}

# The fully expanded spelling, so the block text under test carries no elision
# and no shorthand the block reader might be lenient about.
property_block <- function(o, len) {
  host <- if (length(o) == 4L) {
    paste(o, collapse = ".")
  } else {
    paste(
      sprintf("%02x%02x", o[c(TRUE, FALSE)], o[c(FALSE, TRUE)]),
      collapse = ":"
    )
  }
  paste0(host, "/", len)
}

test_that("containment is downward closed in the prefix length", {
  skip_if_not_installed("hedgehog")
  # If `y` is inside `x/n` it agrees with `x` on the first n bits, so it agrees
  # on the first m for every m below n and is inside `x/m` too. Restated over
  # the whole length axis: the lengths at which `y` is inside are an unbroken
  # run starting at zero.
  #
  # That is a stronger statement than test-within.R's walk, which fixes one base
  # address and asks about each length separately -- a divisor that lost a bit
  # at one length only shows up here, as a gap in the run. The pair also has to
  # be non-vacuous, so both addresses are drawn at one width; a family mismatch
  # is FALSE everywhere including at /0, which would satisfy the claim by
  # holding nothing.
  set.seed(6052L)
  # Drawn as one double-width vector and cut in half, because `gen.c` over a
  # vector generator concatenates rather than nests.
  gen_pair <- hedgehog::gen.and_then(
    hedgehog::gen.element(c(4L, 16L)),
    function(w) {
      hedgehog::gen.map(
        function(o) list(x = o[seq_len(w)], y = o[seq.int(w + 1L, 2L * w)]),
        gen_octets(2L * w)
      )
    }
  )

  hedgehog::forall(gen_pair, function(p) {
    width <- length(p$x) * 8L
    y <- bytes_to_addr(list(as.raw(p$y)))
    lengths <- 0:width
    inside <- vapply(
      lengths,
      function(len) {
        addr_within(y, property_block(property_mask(p$x, len), len))
      },
      logical(1)
    )

    # A run of TRUE then nothing but FALSE, which `cumsum` states without
    # naming where the boundary is.
    expect_identical(inside, cumsum(!inside) == 0L)
    # Every space contains everything of its own family, so the run is never
    # empty -- this is what keeps the claim above from being vacuous.
    expect_true(inside[[1L]])
    # And the longest prefix is the address itself: a host route matches one
    # address, so `y` is inside `x/width` exactly when it IS `x`.
    expect_identical(inside[[width + 1L]], identical(p$x, p$y))
  }, tests = property_tests())
})

# --- totality (sections 5.2 and 6.1) ------------------------------------------

test_that("addr_parse() is total over a generated literal", {
  skip_if_not_installed("hedgehog")
  # P2, quantified over the generator. The corpus asserts this over 2139
  # literals at once; here a failure shrinks to the shortest literal that still
  # breaks it, which is the difference between a red suite and a bug report.
  set.seed(3986L)
  hedgehog::forall(gen_literal(), function(s) {
    expect_silent(p <- addr_parse(s))
    expect_length(p, 1L)
    # The input is handed back verbatim, control characters and all -- a parser
    # that rewrote its own input would make every divergence report unreadable.
    expect_identical(addr_input(p), s)
    expect_false(is.na(addr_status(p)))

    for (dialect in c("strict", "whatwg", "pton", "aton")) {
      outcome <- as.character(addr_outcome(p, dialect))
      expect_false(is.na(outcome))
      # Section 5.2.1's two silences, told apart on this row: `rejected` is a
      # dialect that has the grammar and declines, and it is the only outcome
      # carrying a reason.
      expect_identical(
        lengths(addr_codes(p, dialect)) > 0L,
        outcome == "rejected"
      )
    }
  }, tests = property_tests())
})

test_that("every reading of a generated literal classifies without erroring", {
  skip_if_not_installed("hedgehog")
  # Section 5.3: classification is total over whatever the parser produced,
  # including the rejections, which are missing addresses. A missing address
  # classifies to a missing row rather than to a wrong one.
  set.seed(6890L)
  hedgehog::forall(gen_literal(), function(s) {
    p <- addr_parse(s)
    for (dialect in property_dialects) {
      a <- addr_reading(p, dialect)
      known <- !is.na(addr_family(a))

      expect_silent(cl <- addr_classify(a))
      for (name in c("block", "category", "registry")) {
        expect_identical(is.na(field(cl, name)), !known, info = dialect)
      }
      # The three accessors take an address as readily as a record, and none of
      # them is allowed to be the one that errors (section 6.3).
      expect_silent(addr_category(a))
      expect_silent(addr_embedded_kind(a))
      expect_identical(length(addr_embeddings(a)), 1L)

      # Whatever a dialect accepted, `addr_pton()` reads back (section 5.1.3),
      # and this reaches it through the six dialects rather than through a
      # draw -- the accepted set is different for each of them.
      if (known) {
        expect_true(addr_pton(addr_format(a)) == a)
      }
    }
  }, tests = property_tests(cran = 15L, local = 200L))
})
