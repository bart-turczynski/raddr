# The encoding round-trips. See docs/architecture.md section 6.5, and the
# research note docs/research/08-encoding-reverse.md on round-trip hazards.
#
# Three symmetric pairs -- bytes, hex, binary -- over one shared view of the
# address: its octets, most significant first. RFC 1035 section 3.5 treats an
# IPv4 address as an ordered sequence of octets and RFC 4291 section 2.5.5 lays
# IPv6 out as bit ranges most significant first, so both are network byte order
# and neither pair needs its own notion of endianness.
#
# --- the width is the family ------------------------------------------------
#
# 4 octets for IPv4, 16 for both IPv6 families. Nothing here inspects the bits
# to pick a width, which is what keeps `::ffff:192.0.2.1` and `192.0.2.1` apart:
# they share their low 32 bits (RFC 4291 section 2.5.5) and are told apart only
# by length. Research 08 round-trip failure 2 is the same observation from the
# other side -- one integer names three distinct objects, so the family must
# travel alongside the number. Here the length carries it.
#
# The 4-in-6 form therefore encodes to 16 octets, not 4. Research 08 gotcha 23
# is the warning that this surprises people; demoting it to 4 would be the
# collapse raddr exists to refuse.
#
# --- leading zeros are load-bearing here ------------------------------------
#
# RFC 5952 section 4.1 suppresses leading zeros in IPv6 *text*, and these are
# not text forms: every output is fixed width and zero padded. `::1` is 32 hex
# digits, 31 of them `0`. Research 08 section 3 names mixing the two rules as a
# common bug, and round-trip failure 5 is why the decoders reject a short string
# rather than pad it -- any width other than the two exact ones is a guess about
# a family, and raddr does not guess.
#
# --- no bitwAnd, for the reason R/classify.R gives at length -----------------
#
# Words are raw bit patterns and `NA_integer_` means 0x80000000 (section 5.1.1),
# so the words are widened to unsigned doubles and split by division. 2^53 is
# exact, so all 2^32 patterns survive.

# The 256 octet values in base 2, rendered once each, so the binary encoder
# indexes a table instead of formatting sixteen values per address. Hex needs no
# such table: `sprintf()` reaches the same place in one vectorized call, which
# the hextet matrix already has the shape for.
octet_binary <- vapply(
  0:255,
  function(v) paste(rev((v %/% 2^(0:7)) %% 2), collapse = ""),
  character(1L)
)

# The 128 bits as a 16 x n matrix of octet values, most significant first. The
# IPv6 view; IPv4 is its last four rows, because an IPv4 address lives in `w4`
# and leaves `w1`-`w3` zero (section 5.1).
addr_octets <- function(x) {
  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(f) widen_word(field(x, f))
  )
  n <- length(words[[1L]])
  o <- matrix(0, nrow = 16L, ncol = n)
  for (k in seq_len(4L)) {
    w <- words[[k]]
    o[4L * k - 3L, ] <- w %/% 16777216
    o[4L * k - 2L, ] <- (w %/% 65536) %% 256
    o[4L * k - 1L, ] <- (w %/% 256) %% 256
    o[4L * k, ] <- w %% 256
  }
  o
}

# The rows of the octet matrix an IPv4 address occupies.
v4_octet_rows <- 13:16

# Render a k x m octet matrix as m strings, each octet through `table`. The
# matrix is rebuilt after the lookup because indexing drops the dimensions.
join_octets <- function(o, table) {
  k <- nrow(o)
  pieces <- matrix(table[o + 1L], nrow = k, ncol = ncol(o))
  do.call(paste0, lapply(seq_len(k), function(j) pieces[j, ]))
}

# Every encoder splits the vector by family first, because the family fixes the
# width. A missing address is in neither mask and keeps whatever the caller
# initialized the answer with.
family_masks <- function(family) {
  known <- !is.na(family)
  is_v4 <- known & family == "v4"
  list(v4 = is_v4, v6 = known & !is_v4)
}

# --- decoding ----------------------------------------------------------------

# Build the address from four widened words and a decoded width. Rows whose
# `bits` is NA are missing addresses; their words are left at zero, which never
# escapes, because missingness lives in `family` and every proxy blanks those
# rows (section 5.1.1).
#
# The 4-in-6 test is the one R/ipv6.R applies to a literal: the family is
# decided by the bits, so a decoded `::ffff:0:0/96` address lands in the same
# family its text spelling would have (section 5.1).
words_to_addr <- function(w, bits) {
  n <- length(bits)
  family <- rep(NA_character_, n)
  is_v4 <- !is.na(bits) & bits == 32L
  is_v6 <- !is.na(bits) & bits == 128L
  family[is_v4] <- "v4"
  family[is_v6] <- ifelse(
    w[[1L]][is_v6] == 0 & w[[2L]][is_v6] == 0 & w[[3L]][is_v6] == 65535,
    "v6_4in6",
    "v6"
  )

  new_raddr_address(
    w1 = narrow_word(w[[1L]]),
    w2 = narrow_word(w[[2L]]),
    w3 = narrow_word(w[[3L]]),
    w4 = narrow_word(w[[4L]]),
    family = factor(family, levels = addr_families),
    zone = rep(NA_character_, n)
  )
}

# One 32-bit word out of a fixed-width string, read as two halves. `strtoi()`
# returns NA above the signed 32-bit range -- `strtoi("ffffffff", 16L)` is NA --
# so a whole word can never be read in one call; each half tops out at 65535.
string_word <- function(s, start, digits, base) {
  half <- digits %/% 2L
  strtoi(substr(s, start, start + half - 1L), base) * 65536 +
    strtoi(substr(s, start + half, start + digits - 1L), base)
}

# The shared decoder for both string forms. `digits` is how many characters one
# 32-bit word occupies, and `bad` matches one character the form does not admit.
#
# --- why the validity scan cannot be skipped ---------------------------------
#
# `strtoi()` already answers NA for a digit outside its base, which is most of
# what a validity check is for. It is not all of it: `strtoi()` also accepts
# leading whitespace, a sign, and a `0x` prefix, so an eight-character string
# like "0x0000c0" would decode to a real address instead of to NA. The scan is
# what makes the width check mean what it says.
#
# --- and why it runs before the whitespace strip -----------------------------
#
# Grouping is cosmetic in both forms -- `c000 0201`, a binary string spaced per
# octet -- and research 08 section 4 says to strip it. Stripping every string to
# find the few that need it copies the whole vector for nothing, so the scan
# does double duty: a string with whitespace in it has already failed the
# character check, and only those rows pay for the `gsub()`.
#
# `perl = TRUE` is not decoration. Measured at 1e6 rows of 128 characters, the
# TRE default scans in 0.99 s and PCRE in 0.13 s, and this scan is the single
# largest cost in either decoder.
decode_string <- function(x, digits, base, bad) {
  x <- vec_cast(x, character())
  n <- length(x)
  if (n == 0L) {
    return(words_to_addr(rep(list(double()), 4L), integer()))
  }

  s <- x
  dirty <- !is.na(s) & grepl(bad, s, perl = TRUE)
  if (any(dirty)) {
    s[dirty] <- gsub("[[:space:]]+", "", s[dirty])
    dirty[dirty] <- grepl(bad, s[dirty], perl = TRUE)
  }

  # The family is the width, and nothing is padded to reach one (section 6.5).
  width <- nchar(s)
  width[is.na(s) | dirty] <- NA_integer_
  bits <- rep(NA_integer_, n)
  bits[!is.na(width) & width == digits] <- 32L
  bits[!is.na(width) & width == 4L * digits] <- 128L

  w <- rep(list(rep(0, n)), 4L)
  at <- which(bits == 32L)
  if (length(at)) {
    w[[4L]][at] <- string_word(s[at], 1L, digits, base)
  }
  at <- which(bits == 128L)
  if (length(at)) {
    wide <- s[at]
    for (k in seq_len(4L)) {
      w[[k]][at] <- string_word(wide, digits * (k - 1L) + 1L, digits, base)
    }
  }

  words_to_addr(w, bits)
}

# --- the six exported names --------------------------------------------------

#' Encode and decode addresses as bytes, hex or binary
#'
#' Three symmetric pairs. Each `addr_to_*()` turns addresses into an encoding,
#' and each `*_to_addr()` turns that encoding back into addresses.
#'
#' @section The width carries the family:
#'
#' An IPv4 address encodes to **4** octets, 8 hex digits or 32 bits; an IPv6
#' address to **16** octets, 32 hex digits or 128 bits. The width is decided by
#' the family and never by the bits, which is what keeps `::ffff:192.0.2.1`
#' apart from `192.0.2.1`: the two share their low 32 bits (RFC 4291 §2.5.5) and
#' the length is the only thing that tells them apart.
#'
#' The 4-in-6 form therefore encodes to the **full 16 octets**, not to the 4 of
#' the address it embeds. Use [addr_embeddings()] when the embedded address is
#' what you want.
#'
#' @section Leading zeros:
#'
#' Every output is fixed width and zero padded. `::1` is 32 hex digits, 31 of
#' them `0`. This is the opposite of RFC 5952 §4.1, which suppresses leading
#' zeros -- that rule is about *text* form, and these are not text forms.
#'
#' Decoding is exact about it: a string of any width other than the two the
#' family fixes decodes to `NA`, and is never padded to the nearest one. Seven
#' hex digits could be an IPv4 address missing a zero or an IPv6 address missing
#' twenty-five, and raddr will not guess.
#'
#' @section What survives a round trip, and what does not:
#'
#' `bytes_to_addr(addr_to_bytes(x))` **equals** `x`, and likewise for the other
#' two pairs. Equality is over the 128 bits and the family (see
#' [raddr_address()]), and all three encodings preserve both.
#'
#' The **zone does not survive**. `fe80::1%eth0` and `fe80::1%eth1` encode to
#' identical octets, and the decoders return an address with no zone at all --
#' RFC 4007 §6 explains why it cannot be recovered, since zone indices are
#' strictly local to a node. The round trip still satisfies `==` because the
#' zone does not participate in equality, but [addr_zone()] on the result is
#' `NA`. Carry it separately if you need it.
#'
#' A **prefix length** does not survive either, for the simpler reason that an
#' address does not carry one. Four octets are `192.0.2.0`, full stop.
#'
#' @section Case, prefixes and grouping on input:
#'
#' Hex output is lowercase, following RFC 5952 §4.3. Uppercase input is
#' accepted, because RFC 3596 §2.5 and RFC 2874 §2.2.1 both print their examples
#' in uppercase.
#'
#' `hex_to_addr()` accepts an optional `0x` or `0X` prefix and never emits one.
#' No RFC defines a `0x`-prefixed address encoding; it is a presentation
#' convention, so raddr reads it and does not write it.
#'
#' Whitespace grouping -- `c000 0201`, or a binary string spaced per octet -- is
#' stripped on input by both string decoders. Nothing else is normalized away.
#'
#' @param x For `addr_to_*()`, a `raddr_address` vector. For `bytes_to_addr()`,
#'   a list of `raw` vectors of length 4 or 16. For `hex_to_addr()` and
#'   `binary_to_addr()`, a character vector.
#'
#' @return `addr_to_bytes()` returns a `list_of<raw>`, with `NULL` for a missing
#'   address. `addr_to_hex()` and `addr_to_binary()` return character vectors,
#'   `NA` for a missing address. The three decoders return a `raddr_address`
#'   vector, missing wherever the input could not be decoded -- they signal no
#'   error and no warning, exactly as the single-dialect parsers in [dialects]
#'   do.
#'
#' @examples
#' a <- addr_pton(c("192.0.2.1", "2001:db8::1", "::ffff:192.0.2.1"))
#'
#' addr_to_hex(a)
#' addr_to_bytes(a)
#'
#' # Every pair round-trips
#' hex_to_addr(addr_to_hex(a)) == a
#' bytes_to_addr(addr_to_bytes(a)) == a
#' binary_to_addr(addr_to_binary(a)) == a
#'
#' # The width is the family: the same low 32 bits, two different encodings
#' addr_to_hex(addr_pton(c("192.0.2.1", "::ffff:192.0.2.1")))
#'
#' # Uppercase and a 0x prefix are read; neither is written back
#' addr_to_hex(hex_to_addr("0xC0000201"))
#'
#' # A width the family does not fix is not guessed at
#' hex_to_addr("c000201")
#'
#' @export
addr_to_bytes <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  n <- length(family)
  out <- vector("list", n)
  if (n == 0L) {
    return(new_list_of(out, ptype = raw()))
  }

  sel <- family_masks(family)
  o <- addr_octets(x)

  # One flat `raw` vector per family, cut into elements by `vec_chop()`. The
  # obvious loop -- `as.raw()` once per address -- measures 3x slower at 1e6,
  # which is section 11.1's lesson again: the cost is allocation, not
  # arithmetic. `vector("list", n)` is already all NULL, so a missing address
  # needs no branch; it is the element left untouched.
  for (group in list(list(mask = sel$v4, rows = v4_octet_rows, size = 4L),
                     list(mask = sel$v6, rows = seq_len(16L), size = 16L))) {
    at <- which(group$mask)
    if (!length(at)) {
      next
    }
    flat <- as.raw(o[group$rows, at, drop = FALSE])
    out[at] <- vec_chop(flat, sizes = rep(group$size, length(at)))
  }

  new_list_of(out, ptype = raw())
}

#' @rdname addr_to_bytes
#' @export
addr_to_hex <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  out <- rep(NA_character_, length(family))
  if (!length(family)) {
    return(out)
  }
  sel <- family_masks(family)

  # Lowercase (RFC 5952 section 4.3 by analogy) and the fixed width are both
  # just what "%04x" does, and one `sprintf()` per family is measurably cheaper
  # than a per-octet table lookup joined by a sixteen-piece `paste0()`. The
  # hextet matrix is the shape `sprintf()` already wants.
  h <- matrix(as.integer(addr_hextets(x)), nrow = 8L)
  if (any(sel$v4)) {
    out[sel$v4] <- sprintf("%04x%04x", h[7L, sel$v4], h[8L, sel$v4])
  }
  if (any(sel$v6)) {
    out[sel$v6] <- do.call(
      sprintf,
      c(
        list(strrep("%04x", 8L)),
        lapply(seq_len(8L), function(j) h[j, sel$v6])
      )
    )
  }
  out
}

#' @rdname addr_to_bytes
#' @export
addr_to_binary <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  out <- rep(NA_character_, length(family))
  if (!length(family)) {
    return(out)
  }
  sel <- family_masks(family)

  # No `sprintf()` conversion emits base 2, so this one keeps the octet table.
  o <- addr_octets(x)
  if (any(sel$v4)) {
    out[sel$v4] <- join_octets(
      o[v4_octet_rows, sel$v4, drop = FALSE],
      octet_binary
    )
  }
  if (any(sel$v6)) {
    out[sel$v6] <- join_octets(o[, sel$v6, drop = FALSE], octet_binary)
  }
  out
}

#' @rdname addr_to_bytes
#' @export
bytes_to_addr <- function(x) {
  # A bare `raw` vector is refused rather than read as one address, because it
  # is genuinely ambiguous: eight octets are one malformed address or two IPv4
  # addresses, and the caller knows which.
  if (is.raw(x)) {
    abort(
      c(
        "`x` must be a list of <raw> vectors, not a bare <raw> vector.",
        i = "Wrap a single address in `list()`."
      ),
      class = "raddr_error_type"
    )
  }
  if (!is.list(x)) {
    abort(
      sprintf(
        "`x` must be a list of <raw> vectors, not %s.",
        class(x)[[1L]]
      ),
      class = "raddr_error_type"
    )
  }

  n <- length(x)
  # Anything that is not a `raw` vector of one of the two widths -- `NULL`, an
  # integer vector of octet values, a truncated address -- decodes to missing.
  size <- vapply(
    x,
    function(b) if (is.raw(b)) length(b) else NA_integer_,
    integer(1L)
  )
  bits <- rep(NA_integer_, n)
  bits[!is.na(size) & size == 4L] <- 32L
  bits[!is.na(size) & size == 16L] <- 128L

  w <- rep(list(rep(0, n)), 4L)
  pack <- function(o) {
    o[1L, ] * 16777216 + o[2L, ] * 65536 + o[3L, ] * 256 + o[4L, ]
  }

  narrow <- which(!is.na(bits) & bits == 32L)
  if (length(narrow)) {
    o <- matrix(as.numeric(unlist(x[narrow], use.names = FALSE)), nrow = 4L)
    w[[4L]][narrow] <- pack(o)
  }
  wide <- which(!is.na(bits) & bits == 128L)
  if (length(wide)) {
    o <- matrix(as.numeric(unlist(x[wide], use.names = FALSE)), nrow = 16L)
    for (k in seq_len(4L)) {
      w[[k]][wide] <- pack(o[(4L * k - 3L):(4L * k), , drop = FALSE])
    }
  }

  words_to_addr(w, bits)
}

#' @rdname addr_to_bytes
#' @export
hex_to_addr <- function(x) {
  x <- vec_cast(x, character())
  # `strtoi()` reads uppercase, so the case is left alone rather than lowered:
  # the scan admits both and the round trip still emits only lowercase.
  decode_string(sub("^0[xX]", "", x), 8L, 16L, "[^0-9a-fA-F]")
}

#' @rdname addr_to_bytes
#' @export
binary_to_addr <- function(x) {
  decode_string(x, 32L, 2L, "[^01]")
}
