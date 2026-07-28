# The fourth encoding pair: unsigned integers. See docs/architecture.md section
# 6.5.2, and the research note docs/research/08-encoding-reverse.md section 2 on
# why R makes this the awkward one.
#
# An IPv4 address is a 32-bit unsigned quantity (RFC 4632 section 3.1, "a
# 4-octet quantity") and an IPv6 address is a 128-bit one (RFC 4291 section 2).
# R has neither type. Its `integer` is signed 32-bit, so half the IPv4 space
# does not fit and `as.integer(4294967295)` is NA; its `double` is exact only to
# 2^53, which covers IPv4 with room to spare and misses IPv6 by twenty-five
# orders of magnitude.
#
# So the carrier that always works is a decimal *string*, and that is the
# default. A double is offered for IPv4 because it is exact there and is the
# only R-native numeric that is; it is NA for IPv6 rather than lossy, on the
# same grounds as everything else here.
#
# --- why there is no hard bignum dependency ---------------------------------
#
# `ipaddress::ip_to_integer()` calls `check_installed("bignum")` before it does
# anything else, so without that package the function errors -- for IPv4 too,
# where no arbitrary-precision arithmetic is needed at all. Measured
# 2026-07-28 on 1.0.3: `ip_to_integer(ip_address("192.0.2.1"))` is an error, and
# so is `integer_to_ip(1L, is_ipv6 = FALSE)`. raddr does the arithmetic itself
# and reaches for `bignum` only when asked to.
#
# --- the arithmetic ----------------------------------------------------------
#
# Both directions work in base-10^6 chunks over the four 32-bit words, which is
# the largest chunk that keeps every intermediate under 2^53 and therefore exact
# in a double:
#
#   encode: repeated division of the 128-bit value by 10^6. The dividend is
#           `rem * 2^32 + word` with `rem < 10^6`, at most 4.295e15.
#   decode: repeated multiplication by 10^6 with carry. The product is
#           `word * 10^6 + carry` with `carry < 10^6`, the same bound.
#
# 2^128 - 1 is 39 digits, so seven chunks of six cover any address, and a
# 40-digit number is out of range on its length alone.

# The chunk width, and how many chunks span 128 bits.
decimal_chunk <- 1e6
decimal_chunks <- 7L
decimal_width <- 6L
# 2^128 - 1 has this many digits; anything longer cannot be an address.
decimal_max_digits <- 39L
word_base <- 4294967296

# The 128 bits of each column as a decimal string, most significant digit
# first. One pass per chunk, each pass one long division of the whole vector.
words_decimal <- function(w) {
  n <- length(w[[1L]])
  chunks <- vector("list", decimal_chunks)
  for (j in seq_len(decimal_chunks)) {
    rem <- rep(0, n)
    for (k in seq_len(4L)) {
      cur <- rem * word_base + w[[k]]
      w[[k]] <- cur %/% decimal_chunk
      rem <- cur %% decimal_chunk
    }
    # Least significant chunk first, so the pieces are reversed to assemble.
    chunks[[j]] <- sprintf("%06.0f", rem)
  }
  out <- do.call(paste0, rev(chunks))
  # Every chunk is zero padded, so the leading zeros of the whole number are
  # exactly the padding of its top chunk. The lookahead keeps the last digit,
  # which is what makes zero itself come out as "0" rather than "".
  sub("^0+(?=[0-9])", "", out, perl = TRUE)
}

# The inverse: decimal digits to four words, plus the rows that overflowed.
# `s` is all digits and no wider than `decimal_chunks * decimal_width`.
decimal_words <- function(s) {
  n <- length(s)
  w <- rep(list(rep(0, n)), 4L)
  over <- rep(FALSE, n)

  # Fifteen digits is under 2^50, so `as.numeric()` is exact and two divisions
  # place the value. That is every IPv4 address and every small IPv6 one, and
  # skipping the chunked path for them takes the IPv4 decode from 2.75 s to
  # 0.31 s at 1e6 -- the whole 128-bit machinery, paid for 32 bits of value.
  small <- !is.na(s) & nchar(s) <= 15L
  if (any(small)) {
    v <- as.numeric(s[small])
    w[[3L]][small] <- v %/% word_base
    w[[4L]][small] <- v %% word_base
  }

  wide <- which(!small)
  if (length(wide)) {
    padded <- paste0(
      strrep("0", decimal_chunks * decimal_width - nchar(s[wide])),
      s[wide]
    )
    ww <- rep(list(rep(0, length(wide))), 4L)
    carried <- rep(FALSE, length(wide))

    for (j in seq_len(decimal_chunks)) {
      at <- decimal_width * j
      carry <- as.numeric(substr(padded, at - decimal_width + 1L, at))
      for (k in 4:1) {
        cur <- ww[[k]] * decimal_chunk + carry
        ww[[k]] <- cur %% word_base
        carry <- cur %/% word_base
      }
      # A carry out of the top word is a value of 2^128 or more. It is
      # collected rather than returned early, because the loop is vectorized
      # over rows that are mostly fine.
      carried <- carried | carry > 0
    }

    for (k in seq_len(4L)) {
      w[[k]][wide] <- ww[[k]]
    }
    over[wide] <- carried
  }

  list(words = w, over = over)
}

# What the caller handed in, as decimal digits.
#
# A double is read only where it is exact. Above 2^53 it has already lost the
# value it was meant to carry (research 08 gotcha 27), so raddr refuses it
# rather than decoding whatever the nearest representable number happens to be
# -- the same refusal as the width rule in section 6.5.1.
integer_digits <- function(x) {
  if (is.raw(x)) {
    # `as.character()` on a raw is *hex*, so the fallback branch below would
    # read `as.raw(16)` as the number 10 and hand back 0.0.0.10 without a word.
    # Bytes are the other pair's input, and they carry their own width rule.
    abort(
      c(
        "`x` must be a number or decimal digits, not a <raw> vector.",
        i = "A raw vector is bytes rather than digits: use `bytes_to_addr()`."
      ),
      class = "raddr_error_type"
    )
  }

  if (inherits(x, "bignum_biginteger")) {
    # Two traps in one line. A `biginteger` stores its digits as text, so
    # `is.character()` on one is TRUE and the branch below would keep the class;
    # and its `as.character()` is the *display* form, which rounds -- 2^128 - 1
    # comes back as "3.402824e+38". The decimal notation is the exact one.
    s <- format(x, notation = "dec")
  } else if (is.character(x) && !is.object(x)) {
    s <- x
  } else if (is.numeric(x) && !is.object(x)) {
    v <- as.numeric(x)
    ok <- !is.na(v) & is.finite(v) & v >= 0 & v <= 2^53 & v == floor(v)
    s <- rep(NA_character_, length(v))
    # Adding zero is what normalizes IEEE negative zero, which `0 * -1` and
    # `as.numeric("-0")` both produce. It passes every test above -- `-0 >= 0`
    # is TRUE and `identical(-0, 0)` is TRUE -- but `sprintf("%.0f", -0)` writes
    # "-0", which the digit scan below would then reject. Zero is zero.
    s[ok] <- sprintf("%.0f", v[ok] + 0)
  } else {
    # Anything else that can say what its digits are, `bit64::integer64`
    # included; its `as.character()` is exact.
    s <- as.character(x)
  }

  s <- trimws(s)
  # Digits only: no sign, no decimal point, no exponent. An address integer is
  # unsigned, and a negative one is the signed-32-bit bug of research 08
  # section 2 rather than an address.
  s[is.na(s) | !grepl("^[0-9]+$", s)] <- NA_character_
  s <- sub("^0+(?=[0-9])", "", s, perl = TRUE)
  s[!is.na(s) & nchar(s) > decimal_max_digits] <- NA_character_
  s
}

#' Encode and decode addresses as unsigned integers
#'
#' `addr_to_integer()` is the numeric value of an address: the 4 octets of an
#' IPv4 address read big-endian (RFC 4632 §3.1), or the 16 octets of an IPv6
#' address (RFC 4291 §2). `integer_to_addr()` reads one back.
#'
#' @section R has no unsigned integer, which decides the default:
#'
#' R's `integer` is **signed 32-bit**, so it holds barely half the IPv4 space --
#' `as.integer(4294967295)` is `NA` -- and R's `double` is exact only to 2^53,
#' which is comfortable for IPv4 and twenty-five orders of magnitude short for
#' IPv6. The carrier that always works is a decimal **string**, so that is what
#' `output = "character"`, the default, returns.
#'
#' \describe{
#'   \item{`"character"`}{Decimal digits, no padding, no separators. Always
#'     available, exact for both families.}
#'   \item{`"double"`}{Exact for IPv4 and **`NA` for IPv6**, including the
#'     4-in-6 family, whose value is 128 bits like any other address. A double
#'     cannot carry an IPv6 address, so raddr returns nothing rather than
#'     something close.}
#'   \item{`"bignum"`}{A `bignum::biginteger()`. The only output that needs an
#'     installed package, and the only one that can fail -- see below.}
#' }
#'
#' @section The bignum dependency is optional, and actually optional:
#'
#' `bignum` is in `Suggests`, and the two default-reachable outputs never touch
#' it. The comparison worth stating: `ipaddress::ip_to_integer()` calls
#' `check_installed("bignum")` before doing anything, so without that package it
#' errors -- including for IPv4, where no arbitrary-precision arithmetic is
#' needed at all (verified 2026-07-28, ipaddress 1.0.3). raddr does its own
#' arithmetic in base 10^6 over the four 32-bit words, so you can encode and
#' decode every address of either family with nothing installed.
#'
#' `output = "bignum"` does require the package, and **errors** when it is
#' missing rather than quietly handing back the character vector. The digits
#' would be right and the answers would not: character ordering is
#' lexicographic, so `max()` of `c("9", "16777216")` is `"9"` and `sort()` puts
#' 10 before 9. A caller who asked for numbers and silently received text gets a
#' wrong answer out of the first thing they do with it. The error names the
#' install command and the `"character"` alternative.
#'
#' @section What bignum shows you is not what it stores:
#'
#' `bignum` displays 7 significant figures by default, and its `as.character()`
#' and `format()` follow the display -- so a `biginteger` holding
#' `42540766411282592856903984951653826561` prints, formats, coerces and
#' `write.csv()`s as `"4.254077e+37"`. The stored value is exact and arithmetic
#' on it is exact; only the rendering rounds. Use
#' `format(x, notation = "dec")`, or raise `options(bignum.sigfig)`, to see all
#' of it. `integer_to_addr()` reads a `biginteger` by its decimal notation for
#' this reason, so the round trip is unaffected.
#'
#' @section The family does not travel in the number, so you must pass it:
#'
#' `integer_to_addr()` requires `family`, and has no default. One integer names
#' three different objects: `3221225985` is `192.0.2.1` as IPv4, and as a
#' 128-bit value the deprecated IPv4-compatible `::192.0.2.1` (RFC 4291 §2.5.5),
#' while `::ffff:192.0.2.1` is a fourth thing again. Nothing in the digits says
#' which, so raddr does not guess -- `ipaddress::integer_to_ip()` takes
#' `is_ipv6 = NULL` and infers one.
#'
#' `family` accepts `"v4"`, `"v6"` and `"v6_4in6"`, scalar or one per element,
#' and takes the factor from [addr_family()] directly. `"v6"` and `"v6_4in6"`
#' both mean 128 bits: which of the two families comes back is decided by the
#' bits, exactly as it is when parsing a literal.
#'
#' @section Out of range is `NA`, and so is anything that is not a number:
#'
#' A value of 2^32 or more with `family = "v4"`, 2^128 or more with an IPv6
#' family, a negative number, a sign, an exponent, a decimal point, or empty
#' text all decode to `NA`. So does a `double` above 2^53, because such a double
#' has already lost the value it was meant to carry -- raddr will not decode the
#' nearest representable number instead. Leading zeros and surrounding
#' whitespace are accepted, being unambiguous in a decimal integer.
#'
#' Like the other decoders in [addr_to_bytes()], `integer_to_addr()` signals
#' nothing about a *value* it cannot read: the answer is a missing address. A
#' wrong *type* is a different matter and errors, as it does everywhere else in
#' raddr. A `raw` vector is the case worth naming, because its `as.character()`
#' is hexadecimal -- reading `as.raw(16)` as a number would silently yield
#' `0.0.0.10`. Bytes go to [bytes_to_addr()], which knows they are bytes.
#'
#' @param x For `addr_to_integer()`, a `raddr_address` vector. For
#'   `integer_to_addr()`, a character vector of decimal digits, a numeric
#'   vector, or anything whose `as.character()` is decimal digits -- a
#'   `bignum::biginteger()`, for instance. Not a `raw` vector; see below.
#' @param output One of `"character"` (the default), `"double"` or `"bignum"`.
#' @param family The family the number is to be read as: `"v4"`, `"v6"` or
#'   `"v6_4in6"`, length 1 or `length(x)`. Required.
#'
#' @return `addr_to_integer()` returns a character, double or `biginteger`
#'   vector as `output` asks, `NA` for a missing address. `integer_to_addr()`
#'   returns a `raddr_address` vector.
#'
#' @seealso [addr_to_bytes()] for the byte, hex and binary pairs.
#'
#' @examples
#' a <- addr_pton(c("192.0.2.1", "2001:db8::1", "::ffff:192.0.2.1"))
#' addr_to_integer(a)
#'
#' # Exact in a double for IPv4, and NA rather than lossy for IPv6
#' addr_to_integer(a, output = "double")
#'
#' # The family has to be carried alongside the number
#' integer_to_addr(3221225985, family = "v4")
#' integer_to_addr(3221225985, family = "v6")
#'
#' # Which makes the round trip this
#' integer_to_addr(addr_to_integer(a), addr_family(a)) == a
#'
#' # The largest address of each family
#' addr_to_integer(addr_pton("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
#'
#' @export
addr_to_integer <- function(x, output = c("character", "double", "bignum")) {
  check_raddr_address(x)
  output <- arg_match0(output, c("character", "double", "bignum"))
  family <- field(x, "family")
  n <- length(family)
  sel <- family_masks(family)

  if (output == "double") {
    out <- rep(NA_real_, n)
    if (any(sel$v4)) {
      out[sel$v4] <- widen_word(field(x, "w4"))[sel$v4]
    }
    return(out)
  }

  out <- rep(NA_character_, n)
  if (any(sel$v4)) {
    # 2^32 - 1 is exact in a double, so IPv4 needs none of the machinery.
    out[sel$v4] <- sprintf("%.0f", widen_word(field(x, "w4"))[sel$v4])
  }
  if (any(sel$v6)) {
    w <- lapply(
      c("w1", "w2", "w3", "w4"),
      function(f) widen_word(field(x, f))[sel$v6]
    )
    out[sel$v6] <- words_decimal(w)
  }

  if (output == "bignum") {
    # Handing back the character vector instead would be worse than refusing.
    # The digits are right, but character ordering is lexicographic: `max()` of
    # c("9", "16777216") is "9", and `sort()` puts 10 before 9. A caller who
    # asked for a number and silently got text gets a wrong answer out of the
    # first thing they do with it, so this is the one place raddr requires the
    # optional package -- and only because the caller named it.
    if (!has_bignum()) {
      abort(
        c(
          '`output = "bignum"` needs the bignum package, which is missing.',
          i = 'Install it with `install.packages("bignum")`.',
          i = paste(
            'Or use the default `output = "character"`: the digits are the',
            "same, but they sort as text rather than as numbers."
          )
        ),
        class = "raddr_error_dependency"
      )
    }
    return(bignum::biginteger(out))
  }
  out
}

# The one place raddr looks for the optional package. A function rather than an
# inline call so the branch is testable without uninstalling anything.
has_bignum <- function() {
  requireNamespace("bignum", quietly = TRUE)
}

#' @rdname addr_to_integer
#' @export
integer_to_addr <- function(x, family) {
  # The number and its family are two vectors of the same thing, so they
  # recycle against each other the way any pair of vctrs arguments does.
  recycled <- vec_recycle_common(
    x = integer_digits(x),
    family = integer_family(family)
  )
  s <- recycled$x
  bits <- ifelse(
    is.na(recycled$family),
    NA_integer_,
    ifelse(recycled$family == "v4", 32L, 128L)
  )

  decoded <- decimal_words(ifelse(is.na(s), "0", s))
  w <- decoded$words

  # Three ways to be out of range, all answered the same way: the digits were
  # unreadable, the value did not fit 128 bits, or it did not fit the 32 the
  # family allows.
  bad <- is.na(s) | decoded$over
  bad[!is.na(bits) & bits == 32L] <- bad[!is.na(bits) & bits == 32L] |
    (w[[1L]] != 0 | w[[2L]] != 0 | w[[3L]] != 0)[!is.na(bits) & bits == 32L]
  bits[bad] <- NA_integer_

  words_to_addr(w, bits)
}

# The `family` argument as a plain character vector. A factor is accepted
# whole, so the result of `addr_family()` can be passed straight back in.
#
# "v6" and "v6_4in6" both mean 128 bits; which of the two comes back is decided
# by the bits, in `words_to_addr()`.
integer_family <- function(family) {
  if (is.factor(family)) {
    family <- as.character(family)
  }
  if (!is.character(family)) {
    abort(
      sprintf(
        "`family` must be a character vector or factor, not %s.",
        class(family)[[1L]]
      ),
      class = "raddr_error_type"
    )
  }

  unknown <- !is.na(family) & !family %in% addr_families
  if (any(unknown)) {
    abort(
      c(
        sprintf(
          "`family` must be one of %s.",
          paste(sprintf('"%s"', addr_families), collapse = ", ")
        ),
        i = sprintf('Got "%s".', family[which(unknown)[[1L]]])
      ),
      class = "raddr_error_type"
    )
  }

  family
}
