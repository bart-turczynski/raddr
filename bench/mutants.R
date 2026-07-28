# How much the naive second implementations actually catch (RADD-sdgyxkin). See
# docs/architecture.md section 11.3, which is the table this file produces.
#
# Not a benchmark. It lives here because `bench/` is where the scripts that back
# a number in the design record live, and because the number this one backs is
# the only honest answer to "is that test suite worth its runtime?".
#
# The method: break the shipped code on purpose, one plausible slip at a time,
# and count how many rows of tests/testthat/test-slow.R's corpus the naive
# implementations then disagree about. A mutation nobody notices is either a
# gap in the corpus or an equivalent mutant, and the two have to be told apart
# by reading, not by assuming.
#
# Each mutation is applied to the loaded namespace and put back afterwards, so
# nothing here edits a file. Run with:
#
#   Rscript bench/mutants.R
#
# Needs `pkgload` and `testthat`; neither is a dependency.

suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-dialects.R")
source("tests/testthat/helper-slow.R")

# The test file reaches for its fixtures through testthat's path helper, which
# resolves against the working directory when the suite is not running, so this
# has to be defined before the corpus helper is sourced.
test_path <- function(...) file.path("tests", "testthat", ...)

source("tests/testthat/helper-corpus.R")

# Everything in test-slow.R that is not a `test_that()` call: the render corpus,
# and only that. Read from the test file rather than copied, so the two cannot
# drift apart into measuring different things.
for (expression in parse("tests/testthat/test-slow.R")) {
  is_test <- is.call(expression) &&
    identical(expression[[1L]], as.name("test_that"))
  if (!is_test) {
    eval(expression)
  }
}

literals <- corpus_literals()
addresses <- slow_render_corpus
parts <- slow_render_parts(addresses)

cat(sprintf(
  "corpus: %d literals x 6 dialects, %d addresses x 2 renderers\n\n",
  length(literals), length(addresses)
))

ns <- asNamespace("raddr")
dialects <- c("strict", "whatwg", "pton", "aton", "getaddrinfo", "curl")

same <- function(x, y) {
  (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & x == y)
}

# Every field of every row on both sides. A mutation that changes only the zone,
# or only the family, still counts -- those are answers too.
disagreements <- function() {
  total <- 0L
  for (dialect in dialects) {
    fast <- dialect_fn(dialect)(literals)
    slow <- slow_parse(literals, dialect)
    total <- total +
      sum(!same(addr_to_hex(fast), slow$hex)) +
      sum(!same(as.character(addr_family(fast)), slow$family)) +
      sum(!same(addr_zone(fast), slow$zone))
  }
  total +
    sum(!same(
      addr_format(addresses),
      slow_format(parts$hex, parts$family, parts$zone)
    )) +
    sum(!same(
      addr_expand(addresses),
      slow_expand(parts$hex, parts$family, parts$zone)
    ))
}

probe <- function(mutation) {
  original <- get(mutation$name, ns)
  assignInNamespace(mutation$name, mutation$mutant, ns)
  # A mutation can make the shipped code raise rather than answer, which is a
  # disagreement of a different shape and still a catch.
  count <- tryCatch(
    suppressWarnings(disagreements()),
    error = function(e) NA_integer_
  )
  assignInNamespace(mutation$name, original, ns)

  caught <- is.na(count) || count > 0L
  equivalent <- isTRUE(mutation$equivalent)
  verdict <- if (is.na(count)) {
    "CAUGHT (error)"
  } else if (caught) {
    sprintf("CAUGHT (%d)", count)
  } else if (equivalent) {
    "equivalent, as expected"
  } else {
    "MISSED"
  }
  cat(sprintf("%-52s %s\n", mutation$label, verdict))
  list(label = mutation$label, caught = caught, equivalent = equivalent)
}

# Replace one top-level statement of a function body, leaving the rest alone.
edited <- function(name, at, replacement) {
  f <- get(name, ns)
  body(f)[[at]] <- replacement
  f
}

replaced <- function(name, replacement) {
  f <- get(name, ns)
  body(f) <- replacement
  f
}

# --- the mutations -----------------------------------------------------------
#
# Each one is a slip somebody could plausibly make, not a random edit: a bound
# off by one, two halves of a word the wrong way round, a tie-break reversed.
# Every mutant is built here, before any of them is applied, so each one is a
# edit to the pristine function rather than to whatever the last probe left.

mutations <- list(
  list(
    label = "ipv4_final_bounds: last part off by one",
    name = "ipv4_final_bounds",
    mutant = get("ipv4_final_bounds", ns) + 1
  ),
  list(
    label = "ipv4_weights: short form off by a byte",
    name = "ipv4_weights",
    mutant = c(65536, 256, 1, 1)
  ),
  list(
    label = "ipv4_mod_digits: decimal 32 -> 16",
    name = "ipv4_mod_digits",
    mutant = c("8" = 11L, "10" = 16L, "16" = 8L)
  ),
  list(
    label = "ipv4_digit_values: hex alphabet off by one",
    name = "ipv4_digit_values",
    mutant = c(0:9, 10:15, 11:16)
  ),
  list(
    label = "RFC 5952 4.2.3: tie-break the last equal run",
    name = "longest_zero_run",
    mutant = edited("longest_zero_run", 10L, quote(
      for (j in seq_len(k)) {
        better <- runlen[j, ] >= best_len
        best_len[better] <- runlen[j, better]
        best_start[better] <- j
      }
    ))
  ),
  list(
    label = "RFC 5952 4.2.2: compress a single zero field",
    name = "longest_zero_run",
    mutant = edited(
      "longest_zero_run", 11L,
      quote(best_start[best_len < 1L] <- NA_integer_)
    )
  ),
  list(
    label = "ipv6_pieces: group count off by one",
    name = "ipv6_pieces",
    mutant = replaced("ipv6_pieces", quote(
      ifelse(nzchar(s), nchar(s) - nchar(gsub(":", "", s, fixed = TRUE)), 0L)
    ))
  ),
  list(
    label = "format_v4: octet shift off by a byte",
    name = "format_v4",
    mutant = replaced("format_v4", quote(
      paste(
        as.integer(word %/% 16777216),
        as.integer((word %/% 65536) %% 256),
        as.integer((word %/% 512) %% 256),
        as.integer(word %% 256),
        sep = "."
      )
    ))
  ),
  list(
    label = "addr_hextets: high and low half swapped",
    name = "addr_hextets",
    mutant = local({
      f <- get("addr_hextets", ns)
      body(f)[[5L]][[4L]] <- quote({
        h[2L * k - 1L, ] <- words[[k]] %% 65536
        h[2L * k, ] <- words[[k]] %/% 65536
      })
      f
    })
  ),
  # The control. An eleven-digit decimal is at least 10^10, so the modular
  # accumulation flags it as an overflow whether or not the width check did --
  # this mutation changes no answer, and a run that "catches" it has found a
  # difference the shipped code does not actually have.
  list(
    label = "ipv4_max_digits: decimal 10 -> 11 (equivalent)",
    name = "ipv4_max_digits",
    mutant = c("8" = 11L, "10" = 11L, "16" = 8L),
    equivalent = TRUE
  )
)

results <- lapply(mutations, probe)

# --- the verdict -------------------------------------------------------------

surviving <- vapply(results, `[[`, character(1), "label")[
  !vapply(results, `[[`, logical(1), "caught") &
    !vapply(results, `[[`, logical(1), "equivalent")
]
unexpected <- vapply(results, `[[`, character(1), "label")[
  vapply(results, `[[`, logical(1), "caught") &
    vapply(results, `[[`, logical(1), "equivalent")
]

cat("\n")
if (length(surviving)) {
  stop(
    "mutations nobody noticed:\n  ", paste(surviving, collapse = "\n  "),
    "\nEither the corpus has a gap or the mutation is equivalent. Read it.",
    call. = FALSE
  )
}
if (length(unexpected)) {
  stop(
    "mutations expected to be equivalent but caught:\n  ",
    paste(unexpected, collapse = "\n  "),
    call. = FALSE
  )
}
cat(sprintf(
  "%d mutations, all caught; %d equivalent control(s), correctly missed.\n",
  sum(!vapply(results, `[[`, logical(1), "equivalent")),
  sum(vapply(results, `[[`, logical(1), "equivalent"))
))
