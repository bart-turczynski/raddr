# The TRE -> PCRE migration, verified rewrite by rewrite. See
# docs/architecture.md section 11.2.3.
#
# `grepl()` and `sub()` are two engines behind one signature: TRE by default,
# PCRE under `perl = TRUE`. They are not interchangeable, and the two ways they
# differ are both invisible in the common case:
#
#   1. PCRE's `$` also matches *before* a trailing newline. TRE's anchors at the
#      end of the string, which is what every grammar here means.
#   2. PCRE's `.` excludes newline. TRE's does not, so a greedy run to the last
#      separator stops early under PCRE instead of crossing an embedded newline.
#
# Fault 1 shipped once already, as the wrong-address defect in the hextet
# validator, which is why each rewrite is asserted against the TRE form it
# replaced rather than eyeballed. The pairs below are the migration: left is
# what the source used to say, right is what it says now.

# Every way a separator, an anchor and a newline can be arranged around each
# other, plus the empty and NA rows that a vectorized pattern has to survive.
engine_alphabet <- c(
  # Bare, and the whitespace family one character at a time.
  "", "1", "0", "00", "01", "0x", "0X1f", "1234", "abcd", "fe80",
  "\n", "\r", "\t", "\v", "\f", " ", "\r\n",
  # A trailing newline is fault 1's whole surface: it is the one character `$`
  # and `\z` disagree about.
  "1\n", "0\n", "00\n", "0x\n", "fe80\n", "1\r", "1\r\n", "1\v", "1 ",
  "1\n\n", "1\n ",
  # A leading one, and one in the middle, where the anchors agree and the
  # greedy runs of fault 2 do not.
  "\n1", "1\n2", "1\n:2", "1\n.2", "a\nb:c", "\n:", "\n.",
  # Separators before, after and across the newline: fault 2 needs the *last*
  # separator to sit beyond one to show itself.
  ":", "::", ":\n", ":\n:", "1:", ":1", "1::2", "1:2\n", "1:2:3\n",
  "1:2\n:3", "1\n::2", ".", ".\n", "1.2.3.4", "1.2.3.", "1.2.3.\n",
  "1.2\n.3", "1.2\n.3.4", "0\n0", "00\n0", "0000",
  NA_character_
)

# The rewrites, as (before, after) pairs of one-argument functions.
engine_rewrites <- list(
  "ipv4.R ends_in_a_number, drop one trailing dot" = list(
    tre = function(x) sub("\\.$", "", x),
    pcre = function(x) sub("\\.\\z", "", x, perl = TRUE)
  ),
  "ipv4.R ends_in_a_number, take the final label" = list(
    tre = function(x) sub("^.*\\.", "", x),
    pcre = function(x) sub("(?s)^.*\\.", "", x, perl = TRUE)
  ),
  "ipv4.R ends_in_a_number, decimal label" = list(
    tre = function(x) grepl("^[0-9]+$", x),
    pcre = function(x) grepl("^[0-9]+\\z", x, perl = TRUE)
  ),
  "ipv4.R ends_in_a_number, hex label" = list(
    tre = function(x) grepl("^0[xX][0-9a-fA-F]*$", x),
    pcre = function(x) grepl("^0[xX][0-9a-fA-F]*\\z", x, perl = TRUE)
  ),
  "ipv4.R parse_ipv4_number_slow, hex prefix" = list(
    tre = function(x) grepl("^0[xX]", x),
    pcre = function(x) grepl("^0[xX]", x, perl = TRUE)
  ),
  "ipv4.R parse_ipv4_number_slow, octal prefix" = list(
    tre = function(x) grepl("^0[0-9]+$", x),
    pcre = function(x) grepl("^0[0-9]+\\z", x, perl = TRUE)
  ),
  "ipv4.R parse_ipv4_addr, leading-zero rejection" = list(
    tre = function(x) grepl("^0[0-9]", x),
    pcre = function(x) grepl("^0[0-9]", x, perl = TRUE)
  ),
  "ipv6.R parse_ipv6_addr, take the dotted tail" = list(
    tre = function(x) sub("^.*:", "", x),
    pcre = function(x) sub("(?s)^.*:", "", x, perl = TRUE)
  ),
  "ipv6.R parse_ipv6_addr, edge colon" = list(
    tre = function(x) grepl("(^:|:$)", x),
    pcre = function(x) grepl("(^:|:\\z)", x, perl = TRUE)
  ),
  "ipv6.R parse_ipv6_addr, stray colon" = list(
    tre = function(x) grepl("(^:|::|:$)", x),
    pcre = function(x) grepl("(^:|::|:\\z)", x, perl = TRUE)
  ),
  "integer.R integer_digits, digits only" = list(
    tre = function(x) grepl("^[0-9]+$", x),
    pcre = function(x) grepl("^[0-9]+\\z", x, perl = TRUE)
  )
)

test_that("every PCRE rewrite agrees with the TRE form it replaced", {
  for (label in names(engine_rewrites)) {
    pair <- engine_rewrites[[label]]
    expect_identical(
      pair$pcre(engine_alphabet),
      pair$tre(engine_alphabet),
      info = label
    )
  }
})

# The two rewrites above are the *only* ones that hold. Asserting that the
# obvious spellings fail keeps a later reader from simplifying them back: a
# comment saying "the flag is needed" is an opinion, and this is not.
test_that("the anchor and the dot-all flag are both load-bearing", {
  # `$` under PCRE accepts a hextet that ends in a newline. This is the defect.
  expect_true(grepl("^[0-9a-fA-F]{1,4}$", "8\n", perl = TRUE))
  expect_false(grepl("^[0-9a-fA-F]{1,4}\\z", "8\n", perl = TRUE))
  expect_false(grepl("^[0-9a-fA-F]{1,4}$", "8\n"))

  # A bare `.` under PCRE will not cross a newline, so the run to the last
  # separator stops at the wrong one -- or does not match at all.
  expect_identical(sub("^.*:", "", "1\n:2", perl = TRUE), "1\n:2")
  expect_identical(sub("(?s)^.*:", "", "1\n:2", perl = TRUE), "2")
  expect_identical(sub("^.*:", "", "1\n:2"), "2")

  expect_identical(sub("^.*\\.", "", "1.2\n.3", perl = TRUE), "2\n.3")
  expect_identical(sub("(?s)^.*\\.", "", "1.2\n.3", perl = TRUE), "3")
  expect_identical(sub("^.*\\.", "", "1.2\n.3"), "3")
})

# Walks the loaded namespace rather than the sources, so it holds for an
# installed package too. Only literal patterns at the call site are visible; the
# one pattern built in a variable is the hextet grammar, pinned below.
pcre_pattern_literals <- function() {
  engines <- c("grepl", "sub", "gsub", "regexpr", "gregexpr", "regexec")
  found <- character()
  walk <- function(e) {
    if (!is.call(e)) {
      return(invisible(NULL))
    }
    head <- e[[1L]]
    if (is.name(head) && as.character(head) %in% engines) {
      matched <- tryCatch(
        match.call(get(as.character(head), baseenv()), e),
        error = function(cnd) NULL
      )
      literal <- !is.null(matched) && identical(matched$perl, TRUE) &&
        is.character(matched$pattern)
      if (literal) {
        found <<- c(found, matched$pattern)
      }
    }
    for (part in as.list(e)) {
      if (!missing(part) && (is.call(part) || is.pairlist(part))) {
        walk(part)
      }
    }
    invisible(NULL)
  }
  ns <- asNamespace("raddr")
  for (name in ls(ns, all.names = TRUE)) {
    object <- get(name, envir = ns)
    if (is.function(object) && !is.null(body(object))) {
      walk(body(object))
    }
  }
  found
}

test_that("no pattern running under PCRE is anchored with a dollar sign", {
  patterns <- pcre_pattern_literals()
  # A guard is worthless if it is scanning nothing.
  expect_gt(length(patterns), 8L)
  expect_identical(
    patterns[grepl("$", patterns, fixed = TRUE)],
    character()
  )
})

# The hextet grammar is the one pattern built into a variable before the call,
# so the walk above cannot see it. Read it out of the deparsed body instead --
# both dialect branches, since only one of them is a leading-zero form and the
# defect was originally found on the other.
test_that("the hextet grammar is still anchored at the end of the string", {
  body_text <- paste(
    deparse(body(asNamespace("raddr")$parse_ipv6_addr)),
    collapse = " "
  )
  hextets <- regmatches(
    body_text,
    gregexpr('"[^"]*0-9a-fA-F[^"]*"', body_text)
  )[[1L]]
  expect_length(hextets, 2L)
  # Deparsing doubles the backslash, so `\z` reads as two characters here.
  expect_true(all(endsWith(hextets, '\\\\z"')))
  expect_false(any(grepl('$"', hextets, fixed = TRUE)))
})

# --- What the rewrites mean at the surface -----------------------------------
#
# The pattern-level assertions above say the engines agree. These say what that
# agreement buys, one entry point per migrated site, because a differential test
# that only ever compares two regexes cannot notice a site being deleted.

test_that("a newline-terminated IPv4 literal is still not an address", {
  for (literal in c("1.2.3.4\n", "1.2.3.\n", "0x1.2.3.4\n", "010.0.0.1\n")) {
    expect_true(is.na(addr_strict(literal)), info = literal)
    expect_true(is.na(addr_whatwg(literal)), info = literal)
    expect_true(is.na(addr_pton(literal)), info = literal)
  }
  # `inet_aton` truncates at the first whitespace character, so three of those
  # four are addresses to it, and the migration must not have changed that. It
  # is also the reason the assertion above is not "every dialect agrees".
  expect_identical(addr_aton("1.2.3.4\n"), addr_aton("1.2.3.4"))
  expect_identical(addr_aton("0x1.2.3.4\n"), addr_aton("1.2.3.4"))
  expect_identical(addr_aton("010.0.0.1\n"), addr_aton("8.0.0.1"))
  # The one it still refuses, because truncating leaves a trailing dot.
  expect_true(is.na(addr_aton("1.2.3.\n")))
})

test_that("ends_in_a_number reads the final label, not the trailing newline", {
  ends_in_a_number <- asNamespace("raddr")$ends_in_a_number
  expect_false(ends_in_a_number("foo.1\n"))
  expect_false(ends_in_a_number("foo.0x1\n"))
  expect_false(ends_in_a_number("1.2.3.\n"))
  # Unchanged, and the reason the rewrite is not simply "reject newlines".
  expect_true(ends_in_a_number("foo.1"))
  expect_true(ends_in_a_number("1.2.3."))
  expect_true(ends_in_a_number("foo.09"))
  expect_true(ends_in_a_number("foo.0x4"))
  expect_false(ends_in_a_number("foo.bar"))
})

test_that("an integer's digits still stop at a newline", {
  # `trimws()` runs first and takes a trailing newline with it, so `\z` here is
  # depth rather than a fix: the reachable failure is an *interior* newline.
  expect_identical(
    integer_to_addr("16909060\n", "v4"),
    integer_to_addr(16909060, "v4")
  )
  expect_true(is.na(integer_to_addr("169\n090", "v4")))
  expect_true(is.na(integer_to_addr("16909060\v", "v4")))
})
