# The reason-code vocabulary. See docs/architecture.md sections 5.2 and 6.4.
#
# One const registry, and everything else derived from it. The valid-value set
# is `raddr_codes$code` rather than a second list that has to be kept in step,
# because a vocabulary restated in two places is a vocabulary that drifts.
#
# The codes are a cross-repo contract: `ssrfr` reports raddr's codes rather than
# inventing its own, so adding one is an API change and removing one is a
# breaking change. That is what the `since` column is for.

# A row-major literal, so the registry reads as a table in the source too.
raddr_codes_row <- function(code, layer, rfc, summary, since = "0.1.0") {
  list(code = code, layer = layer, rfc = rfc, summary = summary, since = since)
}

raddr_codes <- local({
  rows <- list(
    # --- IPv4 -----------------------------------------------------------------
    raddr_codes_row(
      "not_a_number", "parse", "RFC 3986 section 3.2.2",
      "A dot-separated part is not a number in any radix this dialect reads."
    ),
    raddr_codes_row(
      "leading_zero", "parse", "RFC 6943 section 3.1.1",
      "A part carries a leading zero and this dialect forbids one."
    ),
    raddr_codes_row(
      "empty_part", "parse", "RFC 3986 section 3.2.2",
      "Two consecutive dots, or a leading dot, leave a part empty."
    ),
    raddr_codes_row(
      "empty_hex", "parse", "WHATWG URL, IPv4 number parser",
      "A part is a digitless \"0x\" where this dialect requires digits."
    ),
    raddr_codes_row(
      "out_of_range", "parse", "RFC 3986 section 3.2.2",
      "A part exceeds the largest value its position can hold."
    ),
    raddr_codes_row(
      "wrong_part_count", "parse", "RFC 3986 section 3.2.2",
      "The number of dot-separated parts is not one this dialect accepts."
    ),
    raddr_codes_row(
      "trailing_dot", "parse", "WHATWG URL, IPv4 parser",
      "The literal ends in a dot that this dialect does not drop."
    ),
    # --- IPv6 -----------------------------------------------------------------
    raddr_codes_row(
      "zone_not_permitted", "parse", "RFC 4291 section 2.2",
      "The literal carries a zone ID and this dialect has no zone ID at all."
    ),
    raddr_codes_row(
      "multiple_zones", "parse", "RFC 4007 section 11.2",
      "More than one \"%\", so the zone ID has no single delimiter."
    ),
    raddr_codes_row(
      "bad_hextet", "parse", "RFC 4291 section 2.2",
      "A group is not one to four hexadecimal digits."
    ),
    raddr_codes_row(
      "empty_group", "parse", "RFC 4291 section 2.2",
      "A stray colon leaves a group empty."
    ),
    raddr_codes_row(
      "bad_elision", "parse", "RFC 4291 section 2.2",
      "More than one \"::\", or a \":::\" run."
    ),
    raddr_codes_row(
      "wrong_group_count", "parse", "RFC 4291 section 2.2",
      "The literal does not resolve to exactly eight groups."
    ),
    raddr_codes_row(
      "bad_embedded_ipv4", "parse", "RFC 4291 section 2.2",
      "The dotted-quad tail is not an address under this dialect's IPv4 rules."
    ),
    # An AF_INET-only dialect has no objection to a colon literal, it has no
    # reading of one -- so that is a `not_an_address` outcome and not a code.
    # See ip_attempt() in R/parse.R.
    # --- Compositions ---------------------------------------------------------
    raddr_codes_row(
      "whitespace", "parse", "POSIX getaddrinfo(3)",
      "The literal contains whitespace, which this dialect rejects outright."
    )
  )

  columns <- c("code", "layer", "rfc", "summary", "since")
  out <- lapply(columns, function(column) {
    vapply(rows, function(row) row[[column]], character(1L))
  })
  names(out) <- columns
  vctrs::new_data_frame(out, n = length(rows))
})

# The valid-value set, derived rather than restated. Ordering is the registry's,
# so a `codes` vector always reads in the same order whatever the input.
parse_code_levels <- raddr_codes$code[raddr_codes$layer == "parse"]

# --- Carrying codes through the engines --------------------------------------
#
# The parsers work a pass at a time over the whole vector, so the codes have to
# travel the same way: a per-row integer mask, one bit per code, built with
# vectorized bitwOr() and unpacked only at the end. A list of character vectors
# grown row by row would put a per-element loop back into the middle of an
# engine built specifically to avoid one.
#
# One bit per code caps the vocabulary at 31, because R's integer is signed
# 32-bit. That is far away, but it is a real ceiling rather than a stylistic
# one, so it is asserted here where a 32nd code would be added.
stopifnot(length(parse_code_levels) <= 31L)

parse_code_bits <- local({
  bits <- as.integer(2^(seq_along(parse_code_levels) - 1L))
  names(bits) <- parse_code_levels
  bits
})

# A bit by name, so the engines never spell a power of two.
code_bit <- function(code) {
  unname(parse_code_bits[[code]])
}

# The bit of the first condition that fires, per element, over a named list of
# logical vectors given in precedence order. A scalar `FALSE` stands for a
# condition this dialect's rules switch off, so a caller does not have to
# materialize a vector for a rule that cannot fire.
first_code <- function(conditions, n) {
  out <- integer(n)
  remaining <- rep(TRUE, n)
  for (code in names(conditions)) {
    hit <- remaining & conditions[[code]]
    hit[is.na(hit)] <- FALSE
    if (any(hit)) {
      out[hit] <- code_bit(code)
      remaining <- remaining & !hit
    }
  }
  out
}

# Unpack masks into the `list<character>` the record stores.
#
# Done via the *distinct* masks rather than row by row: a vector of a million
# addresses has a million rows and a handful of masks, most of them zero. That
# turns the one unavoidable per-element step into a loop over the masks that
# actually occurred.
codes_from_mask <- function(mask) {
  keys <- unique(mask)
  decoded <- lapply(keys, function(key) {
    if (key == 0L) {
      return(character())
    }
    parse_code_levels[bitwAnd(key, parse_code_bits) != 0L]
  })
  decoded[match(mask, keys)]
}

#' The reason-code registry
#'
#' Every reason code raddr can attach to a reading, with its layer, its
#' provenance and the version it was introduced in. `addr_codes()` returns codes
#' from this vocabulary; this is where you look one up.
#'
#' The registry is the vocabulary's single definition. raddr derives the set of
#' valid codes from it rather than keeping a second list, and a test asserts
#' that every code has at least one input in the corpus that produces it, so a
#' code that nothing can emit fails the build.
#'
#' @section A cross-repo contract:
#'
#' The codes are meant to be read by other packages -- `ssrfr` reports raddr's
#' codes rather than inventing a parallel vocabulary. Adding a code is therefore
#' an addition to raddr's API and removing one is a breaking change, which is
#' what the `since` column records.
#'
#' @section Layers:
#'
#' \describe{
#'   \item{`parse`}{Why a dialect declined to read a literal as an address.}
#'   \item{`classify`}{Facts about a parsed address noted during classification.
#'     None yet; classification is not written.}
#' }
#'
#' @return A data frame with one row per code and the columns `code`, `layer`,
#'   `rfc`, `summary` and `since`.
#'
#' @examples
#' registry <- addr_codes_registry()
#' registry$code
#'
#' registry[registry$code == "out_of_range", ]
#'
#' @export
addr_codes_registry <- function() {
  as.data.frame(raddr_codes, stringsAsFactors = FALSE)
}
