# Rendering an address back to text. See docs/architecture.md sections 5.1 and
# 6.2.
#
# Two renderers, because the two jobs are different. `addr_format()` is RFC 5952
# canonical -- one spelling per address, the one every other tool agrees on --
# and is what `format()` and `as.character()` emit. `addr_expand()` is the fully
# expanded eight-hextet form, which is what you want when addresses have to line
# up in a column, be compared as text, or be grepped for a prefix.
#
# Both are vectorized over the whole vector: the hextets become one 8 x n matrix
# and every step below operates on that matrix, never on a row at a time.

# The 128 bits as an 8 x n matrix of hextet values, most significant first. The
# words are widened first, because a word holding 0x80000000 is NA_integer_ at
# the R level and means the bit pattern, not missingness (section 5.1.1).
addr_hextets <- function(x) {
  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(f) widen_word(field(x, f))
  )
  n <- length(words[[1L]])
  h <- matrix(0, nrow = 8L, ncol = n)
  for (k in seq_len(4L)) {
    h[2L * k - 1L, ] <- words[[k]] %/% 65536
    h[2L * k, ] <- words[[k]] %% 65536
  }
  h
}

# RFC 5952 section 4.2: find the run of all-zero fields that "::" stands for.
# The rules are that the run must cover more than one field (4.2.2), that the
# longest run wins (4.2.3), and that the first of two equally long runs wins.
#
# `runlen[j, ]` is the length of the zero run *starting* at j, filled in by one
# backwards recursion over the k rows -- k steps, each vectorized over all n
# columns. The leftmost argmax then falls out of a forward pass using a strict
# `>`, which is exactly the tie-break 4.2.3 asks for.
longest_zero_run <- function(h) {
  k <- nrow(h)
  n <- ncol(h)
  zero <- h == 0

  runlen <- matrix(0L, nrow = k, ncol = n)
  runlen[k, ] <- as.integer(zero[k, ])
  for (j in seq.int(k - 1L, 1L)) {
    runlen[j, ] <- ifelse(zero[j, ], runlen[j + 1L, ] + 1L, 0L)
  }

  best_len <- integer(n)
  best_start <- rep(NA_integer_, n)
  for (j in seq_len(k)) {
    better <- runlen[j, ] > best_len
    best_len[better] <- runlen[j, better]
    best_start[better] <- j
  }

  # A single zero field is spelled "0", never "::" (RFC 5952 section 4.2.2).
  best_start[best_len < 2L] <- NA_integer_
  list(start = best_start, len = best_len)
}

# Join k rows of a character matrix with ":", plus any trailing pieces.
join_pieces <- function(pieces, extra = NULL) {
  rows <- lapply(seq_len(nrow(pieces)), function(j) pieces[j, ])
  do.call(paste, c(rows, extra, list(sep = ":")))
}

# The RFC 5952 rendering of a k x n hextet matrix, with `extra` appended as a
# final piece when the mixed form is in play (section 5).
#
# The compressed run is blanked rather than removed, and the pieces are then
# joined with ":" as if nothing had happened: a run of two blanks already lands
# the "::" in the right place, and a longer one leaves a colon per blank, which
# one `sub()` collapses. That keeps the ragged part of the problem -- how many
# fields "::" swallowed, and whether it sits at either end -- inside two
# vectorized operations instead of a per-row assembly.
render_canonical <- function(h, extra = NULL) {
  k <- nrow(h)
  n <- ncol(h)
  # RFC 5952 section 4.1 (no leading zeros) and 4.3 (lowercase) are both just
  # what "%x" does.
  pieces <- matrix(sprintf("%x", as.integer(h)), nrow = k, ncol = n)

  run <- longest_zero_run(h)
  if (!all(is.na(run$start))) {
    start <- matrix(rep(run$start, each = k), nrow = k, ncol = n)
    len <- matrix(rep(run$len, each = k), nrow = k, ncol = n)
    position <- matrix(seq_len(k), nrow = k, ncol = n)
    pieces[!is.na(start) & position >= start & position < start + len] <- ""
  }

  sub(":{3,}", "::", join_pieces(pieces, extra))
}

# The dotted-quad rendering of a 32-bit word, vectorized.
format_v4 <- function(word) {
  paste(
    as.integer(word %/% 16777216),
    as.integer((word %/% 65536) %% 256),
    as.integer((word %/% 256) %% 256),
    as.integer(word %% 256),
    sep = "."
  )
}

# The zone travels beside the bits, never inside them (section 5.1), so both
# renderers append it the same way and neither reads it back into the address.
append_zone <- function(out, zone) {
  zoned <- !is.na(out) & !is.na(zone)
  out[zoned] <- paste0(out[zoned], "%", zone[zoned])
  out
}

#' Render addresses as text
#'
#' `addr_format()` renders an address in its **canonical** form: RFC 5952 for
#' IPv6, dotted-quad for IPv4. Every address has exactly one canonical spelling,
#' so two addresses that compare equal always format identically. This is what
#' [format()] and [as.character()] emit.
#'
#' `addr_expand()` renders the **fully expanded** form instead: eight
#' four-digit hextets, nothing compressed, nothing abbreviated. Reach for it
#' when addresses have to line up in a column, sort as text, or be matched by a
#' prefix -- none of which the canonical form supports, because it is
#' variable-width by design.
#'
#' @section What RFC 5952 asks for:
#'
#' \describe{
#'   \item{4.1}{Leading zeros in a field are suppressed: `2001:0db8` is
#'     `2001:db8`, and an all-zero field is `0`.}
#'   \item{4.2.1}{The `::` is used wherever it can be.}
#'   \item{4.2.2}{But never for a *single* zero field -- `2001:db8:0:1::1`, not
#'     `2001:db8::1::1`, and `2001:db8:0:1:1:1:1:1` keeps its `0`.}
#'   \item{4.2.3}{The longest run of zero fields is the one compressed, and the
#'     **first** of two equally long runs wins.}
#'   \item{4.3}{Hex digits are lowercase.}
#'   \item{5}{An address with an embedded IPv4 address is rendered in the mixed
#'     form: `::ffff:192.0.2.1`.}
#' }
#'
#' RFC 5952 publishes no test vectors; `tests/testthat/test-format.R` carries
#' the ones raddr authored against its text, section by section.
#'
#' @section The 4-in-6 form:
#'
#' The mixed form is emitted for the `v6_4in6` family, which is decided by the
#' bits rather than by the spelling (see [raddr_address()]). That is what makes
#' `parse(format(x)) == x` hold for `::ffff:192.0.2.1`: it round-trips back into
#' its own family rather than collapsing onto the bare IPv4 address.
#'
#' @section The zone:
#'
#' A zone ID is appended as `%zone` by both renderers, and neither reads it back
#' into the address bits. A missing address renders as `NA`.
#'
#' @param x A `raddr_address` vector.
#'
#' @return A character vector the same length as `x`, `NA` for missing
#'   addresses.
#'
#' @examples
#' a <- addr_strict(c("2001:db8::1", "::ffff:192.0.2.1", "192.0.2.1"))
#' addr_format(a)
#' addr_expand(a)
#'
#' # The canonical form round-trips
#' addr_strict(addr_format(a)) == a
#'
#' @export
addr_format <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  out <- rep(NA_character_, length(family))

  known <- !is.na(family)
  is_v4 <- known & family == "v4"
  is_4in6 <- known & family == "v6_4in6"
  is_v6 <- known & family == "v6"

  if (any(is_v4) || any(is_4in6)) {
    quad <- format_v4(widen_word(field(x, "w4")))
  }
  if (any(is_v4)) {
    out[is_v4] <- quad[is_v4]
  }
  if (any(is_v6) || any(is_4in6)) {
    h <- addr_hextets(x)
    if (any(is_v6)) {
      out[is_v6] <- render_canonical(h[, is_v6, drop = FALSE])
    }
    if (any(is_4in6)) {
      # The mixed form: the first six fields under the ordinary rules, then the
      # last 32 bits as a dotted quad. The quad joins the fields as a seventh
      # piece so that a compressed run reaching the end of the six -- which is
      # every canonical 4-in-6 address -- still collapses correctly.
      out[is_4in6] <- render_canonical(
        h[seq_len(6L), is_4in6, drop = FALSE],
        list(quad[is_4in6])
      )
    }
  }

  append_zone(out, field(x, "zone"))
}

#' @rdname addr_format
#' @export
addr_expand <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  out <- rep(NA_character_, length(family))

  known <- !is.na(family)
  is_v4 <- known & family == "v4"
  is_v6 <- known & !is_v4

  if (any(is_v4)) {
    out[is_v4] <- format_v4(widen_word(field(x, "w4")))[is_v4]
  }
  if (any(is_v6)) {
    h <- addr_hextets(x)[, is_v6, drop = FALSE]
    pieces <- matrix(
      sprintf("%04x", as.integer(h)),
      nrow = 8L,
      ncol = ncol(h)
    )
    out[is_v6] <- join_pieces(pieces)
  }

  append_zone(out, field(x, "zone"))
}
