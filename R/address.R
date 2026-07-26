# The raddr_address type.
# See docs/architecture.md sections 5.1, 5.1.1 and 5.1.2.

#' The address families raddr distinguishes
#'
#' Three states, not two. `parse("::ffff:127.0.0.1")` must not equal
#' `parse("127.0.0.1")`, so the 4-in-6 form is its own family rather than an
#' IPv6 address that happens to sit in `::ffff:0:0/96`.
#'
#' @noRd
addr_families <- c("v4", "v6", "v6_4in6")

# Sort rank per family (O3). IPv4 sorts before IPv6, and the 4-in-6 form ranks
# with IPv6 because it is an IPv6 address.
addr_family_ranks <- c(v4 = 0L, v6 = 1L, v6_4in6 = 1L)

#' An IP address vector
#'
#' `raddr_address()` builds a vector of IP addresses from raw 32-bit words. It
#' is a low-level constructor: it does no parsing and accepts whatever bits it
#' is given. Parsing text into addresses is the job of the dialect parsers,
#' which are not written yet.
#'
#' @section Storage:
#'
#' A [vctrs::new_rcrd()] with six fields:
#'
#' \describe{
#'   \item{`w1`-`w4`}{Four 32-bit words as `integer`, most significant first
#'     (big-endian). An IPv4 address occupies `w4` and leaves `w1`-`w3` zero.}
#'   \item{`family`}{A factor with levels `"v4"`, `"v6"` and `"v6_4in6"`.
#'     `NA` marks a **missing address** -- see below.}
#'   \item{`zone`}{The RFC 4007 zone ID, or `NA` when the address carries none.
#'     Never stored in the address bits.}
#' }
#'
#' @section Missingness lives in `family`:
#'
#' R reserves the bit pattern `0x80000000` as `NA_integer_`, so a word cannot
#' use `NA` to mean "absent" without also losing the one address that has that
#' pattern. raddr therefore reads a word as raw bits and nothing else:
#' `NA_integer_` in `w1`-`w4` means the pattern `0x80000000`, not missingness.
#'
#' A row is a missing address if and only if its `family` is `NA`, and `is.na()`
#' reports exactly that.
#'
#' The consequence a caller can see is that `128.0.0.0` compares equal to
#' itself, which is not true of every R package that stores addresses this way.
#'
#' @section Equality and ordering:
#'
#' Equality is over the 128 bits and the family, and nothing else. The **zone
#' does not participate**: `fe80::1%lo0` equals `fe80::1%en0`, because they are
#' the same address named on two interfaces. Query [addr_zone()] when the
#' interface matters.
#'
#' Ordering is **total**, so [sort()] and [order()] work on a vector mixing
#' families: IPv4 sorts before IPv6, and the 4-in-6 form sorts with IPv6 by its
#' full 128 bits. Ordering agrees with equality -- `x == y` implies
#' `vctrs::vec_compare(x, y)` is `0`.
#'
#' @param w1,w2,w3,w4 Integer vectors of 32-bit words, most significant first.
#'   Interpreted as raw bit patterns: `NA_integer_` means `0x80000000`.
#' @param family A character or factor vector of `"v4"`, `"v6"` or `"v6_4in6"`.
#'   `NA` marks a missing address.
#' @param zone A character vector of RFC 4007 zone IDs, `NA` where absent.
#'
#' @return A `raddr_address` vector.
#'
#' @examples
#' # 127.0.0.1 lives in w4
#' raddr_address(0L, 0L, 0L, 2130706433L, "v4")
#'
#' # The zone travels alongside the bits, not inside them
#' addr_zone(raddr_address(-25165824L, 0L, 0L, 1L, "v6", zone = "lo0"))
#'
#' @export
raddr_address <- function(w1 = integer(),
                          w2 = integer(),
                          w3 = integer(),
                          w4 = integer(),
                          family = character(),
                          zone = NA_character_) {
  w1 <- vec_cast(w1, integer())
  w2 <- vec_cast(w2, integer())
  w3 <- vec_cast(w3, integer())
  w4 <- vec_cast(w4, integer())
  zone <- vec_cast(zone, character())

  if (is.factor(family)) {
    family <- as.character(family)
  }
  family <- vec_cast(family, character())
  unknown <- !is.na(family) & !family %in% addr_families
  if (any(unknown)) {
    abort(
      c(
        "`family` must be one of \"v4\", \"v6\" or \"v6_4in6\".",
        x = sprintf("Unknown value: \"%s\".", family[unknown][[1]])
      ),
      class = "raddr_error_family"
    )
  }

  fields <- vec_recycle_common(w1, w2, w3, w4, family, zone)
  new_raddr_address(
    w1 = fields[[1L]],
    w2 = fields[[2L]],
    w3 = fields[[3L]],
    w4 = fields[[4L]],
    family = factor(fields[[5L]], levels = addr_families),
    zone = fields[[6L]]
  )
}

new_raddr_address <- function(w1 = integer(),
                              w2 = integer(),
                              w3 = integer(),
                              w4 = integer(),
                              family = factor(levels = addr_families),
                              zone = character()) {
  new_rcrd(
    list(w1 = w1, w2 = w2, w3 = w3, w4 = w4, family = family, zone = zone),
    class = "raddr_address"
  )
}

#' Test whether an object is a `raddr_address`
#'
#' @param x An object.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_raddr_address(raddr_address(0L, 0L, 0L, 1L, "v4"))
#' is_raddr_address("127.0.0.1")
#'
#' @export
is_raddr_address <- function(x) {
  inherits(x, "raddr_address")
}

#' Read the family of an address
#'
#' @param x A `raddr_address` vector.
#'
#' @return A factor with levels `"v4"`, `"v6"` and `"v6_4in6"`, `NA` for missing
#'   addresses.
#'
#' @examples
#' addr_family(raddr_address(0L, 0L, 0L, 1L, "v4"))
#'
#' @export
addr_family <- function(x) {
  check_raddr_address(x)
  field(x, "family")
}

#' Read the zone ID of an address
#'
#' The RFC 4007 zone ID is stored alongside the address bits, never inside them,
#' and it does not participate in equality. Two addresses that differ only by
#' zone compare equal; this is how you tell them apart.
#'
#' @param x A `raddr_address` vector.
#'
#' @return A character vector, `NA` where the address carries no zone.
#'
#' @examples
#' a <- raddr_address(-25165824L, 0L, 0L, 1L, "v6", zone = "lo0")
#' b <- raddr_address(-25165824L, 0L, 0L, 1L, "v6", zone = "en0")
#' a == b
#' addr_zone(a) == addr_zone(b)
#'
#' @export
addr_zone <- function(x) {
  check_raddr_address(x)
  field(x, "zone")
}

check_raddr_address <- function(x, arg = "x") {
  if (!is_raddr_address(x)) {
    abort(
      sprintf(
        "`%s` must be a <raddr_address> vector, not %s.",
        arg,
        class(x)[[1L]]
      ),
      class = "raddr_error_type"
    )
  }
  invisible(x)
}

# --- The widening proxies (section 5.1.1) -----------------------------------
#
# A 32-bit word has 2^32 bit patterns; R's integer can distinguish 2^32 - 1 of
# them, because it spends `0x80000000` on NA_integer_. Comparing the words as
# integers therefore loses one address per word position, which is a live bug in
# at least one CRAN package. Widening to double fixes it: doubles are exact to
# 2^53, so every 32-bit value survives, and only the transient proxy is wide --
# storage stays four bytes per word.
#
# The mapping is the unsigned reading of the signed pattern, uniformly:
# a negative word gains 2^32, and `NA_integer_` is the pattern 0x80000000, whose
# unsigned value is 2^31.

widen_word <- function(w) {
  d <- as.double(w)
  negative <- !is.na(d) & d < 0
  d[negative] <- d[negative] + 2^32
  d[is.na(w)] <- 2^31
  d
}

# Both proxies share this. `rank` is prepended for ordering only, so that IPv4
# sorts before IPv6 (O3); equality leads with the family code instead, so that
# `0.0.0.0` and `::` -- identical bits, different families -- are not equal.
#
# Rows whose family is NA are the missing addresses, and every proxy column is
# set NA for them so that is.na(), ==, and sort() all agree.
addr_proxy <- function(x, ordered) {
  family <- field(x, "family")
  code <- as.integer(family)
  missing <- is.na(code)

  out <- data.frame(
    w1 = widen_word(field(x, "w1")),
    w2 = widen_word(field(x, "w2")),
    w3 = widen_word(field(x, "w3")),
    w4 = widen_word(field(x, "w4"))
  )

  if (ordered) {
    # Ties on the full 128 bits break on the family code, so that ordering stays
    # consistent with equality rather than calling two unequal addresses equal.
    out <- data.frame(
      rank = unname(addr_family_ranks[as.character(family)]),
      out,
      code = code
    )
  } else {
    out <- data.frame(code = code, out)
  }

  out[missing, ] <- NA
  out
}

#' @export
vec_proxy_equal.raddr_address <- function(x, ...) {
  addr_proxy(x, ordered = FALSE)
}

#' @export
vec_proxy_compare.raddr_address <- function(x, ...) {
  addr_proxy(x, ordered = TRUE)
}

# --- Printing ----------------------------------------------------------------

#' @export
format.raddr_address <- function(x, ...) {
  # A placeholder. RFC 5952 formatting -- zero-run compression, the 4-in-6 form,
  # the zone suffix -- is its own body of work; until it lands this emits the
  # fully expanded form so that addresses can be printed and eyeballed at all.
  family <- field(x, "family")
  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(f) widen_word(field(x, f))
  )

  out <- vapply(
    seq_along(x),
    function(i) {
      if (is.na(family[[i]])) {
        return(NA_character_)
      }
      if (family[[i]] == "v4") {
        return(format_v4(words[[4L]][[i]]))
      }
      format_v6_expanded(vapply(words, `[[`, double(1), i))
    },
    character(1)
  )

  zone <- field(x, "zone")
  zoned <- !is.na(out) & !is.na(zone)
  out[zoned] <- paste0(out[zoned], "%", zone[zoned])
  out
}

format_v4 <- function(word) {
  octets <- (word %/% 256^(3:0)) %% 256
  paste(octets, collapse = ".")
}

format_v6_expanded <- function(words) {
  groups <- as.vector(rbind(words %/% 65536, words %% 65536))
  paste(sprintf("%04x", groups), collapse = ":")
}

#' @export
obj_print_data.raddr_address <- function(x, ...) {
  if (vec_size(x) == 0L) {
    return(invisible(x))
  }
  print(format(x), quote = FALSE)
  invisible(x)
}

#' @export
as.character.raddr_address <- function(x, ...) {
  format(x, ...)
}

#' @export
vec_ptype_abbr.raddr_address <- function(x, ...) {
  "addr"
}

#' @export
vec_ptype_full.raddr_address <- function(x, ...) {
  "raddr_address"
}

# --- Coercion ----------------------------------------------------------------

#' @export
vec_ptype2.raddr_address.raddr_address <- function(x, y, ...) {
  x
}

#' @export
vec_cast.raddr_address.raddr_address <- function(x, to, ...) {
  x
}
