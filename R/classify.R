# Longest-prefix-match lookup over the vendored IANA registries.
# See docs/architecture.md sections 7, 7.1 and 5.3.
#
# Flat first-match-wins is wrong here, and the registry says so itself:
# 192.0.0.9/32 and 192.0.0.10/32 are globally reachable inside a 192.0.0.0/24
# that is not. A matcher that stops at the first containing block reports the
# /24's answer for both, which is the opposite of what IANA published.
#
# --- why this file contains no bitwAnd ---------------------------------------
#
# Section 5.1.1 says words are raw bit patterns and `NA_integer_` means
# 0x80000000. Every bitwise operator in R is therefore unusable here, in BOTH
# directions, and neither failure is loud:
#
#   - a bitwise AND of the pattern with anything is NA, so a word holding
#     0x80000000 reads as missing rather than as bits;
#   - a bitwise NOT of 2147483647 is NA, so the mask for a /1 prefix cannot
#     even be spelled.
#
# The first is not hypothetical: 2620:4f:8000::/48, the AS112 direct-delegation
# prefix, has second word 0x80000000, so a bitwise matcher never matches it. The
# second bites any prefix length congruent to 1 mod 32, which no IANA block uses
# but a caller-supplied prefix could.
#
# So the matcher widens to unsigned doubles with `widen_word()` (the proxy
# section 5.1.1 already built for ordering) and compares top bits by integer
# division. Doubles are exact to 2^53, so all 2^32 patterns survive. This is the
# section 12 "arithmetic, never bitwShiftL" constraint in its third form.

# Which words a prefix of `len` bits covers, and by how much to divide each so
# that only the covered bits remain. IPv4 lives in `w4` alone (section 5.1), so
# the two spaces number their words differently and the space has to be passed.
#
# Returns a list of `list(word =, divisor =)`, most significant first. A divisor
# of 1 means the whole word participates.
prefix_word_plan <- function(len, space) {
  words <- if (space == "v4") 4L else 1:4
  plan <- list()
  for (i in seq_along(words)) {
    bits <- min(max(len - 32L * (i - 1L), 0L), 32L)
    if (bits == 0L) {
      next
    }
    # 2^(32 - bits), never bitwShiftL: see the header.
    step <- list(word = words[[i]], divisor = 2^(32 - bits))
    plan[[length(plan) + 1L]] <- step
  }
  plan
}

# The matcher's view of the registry: for each block, the word/divisor/target
# triples that decide containment. Sorted by DESCENDING prefix length, so
# walking it in order and keeping the first hit is longest-prefix-match.
#
# Memoized rather than built at load, because top-level code in R/ runs while
# the package is being installed and the order in which `R/sysdata.rda` becomes
# visible is not something to depend on.
registry_index_cache <- new.env(parent = emptyenv())

registry_index <- function() {
  cached <- registry_index_cache$index
  if (!is.null(cached)) {
    return(cached)
  }

  blocks <- raddr_registry_data$blocks
  ord <- order(blocks$prefix_len, decreasing = TRUE)
  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(blocks[[nm]][ord])
  )

  prefix_len <- blocks$prefix_len[ord]
  space <- blocks$space[ord]

  checks <- lapply(seq_along(ord), function(i) {
    plan <- prefix_word_plan(prefix_len[[i]], space[[i]])
    lapply(plan, function(step) {
      step$target <- words[[step$word]][[i]] %/% step$divisor
      step
    })
  })

  index <- list(row = ord, space = space, checks = checks)

  registry_index_cache$index <- index
  index
}

#' Match addresses against the registry, longest prefix wins
#'
#' @param x A `raddr_address` vector.
#'
#' @return An integer vector, one element per address, giving the row of
#'   `raddr_registry_data$blocks` that matched, or `NA_integer_` where no
#'   special-purpose block contains the address.
#'
#' @details
#' The 4-in-6 family matches **IPv6** blocks, not IPv4 ones. `::ffff:127.0.0.1`
#' is an IPv6 address in `::ffff:0:0/96`; that its embedded address is loopback
#' is a separate fact, and `embeddings` is where it is reported -- each element
#' carries the extracted address with its own `category` (section 5.3.5).
#' Answering `loopback` here would collapse the two facts raddr exists to
#' keep apart.
#'
#' @noRd
registry_match <- function(x) {
  family <- field(x, "family")
  n <- length(family)
  out <- rep(NA_integer_, n)
  if (n == 0L) {
    return(out)
  }

  # Missingness lives in `family` (section 5.1.1); a missing address matches
  # nothing rather than matching whatever its leftover words happen to say.
  known <- !is.na(family)
  is_v4 <- known & family == "v4"
  # v6 and v6_4in6 both search the IPv6 half. See @details.
  in_space <- list(v4 = is_v4, v6 = known & !is_v4)

  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(field(x, nm))
  )

  index <- registry_index()

  for (i in seq_along(index$row)) {
    hit <- in_space[[index$space[[i]]]] & is.na(out)
    if (!any(hit)) {
      next
    }

    for (step in index$checks[[i]]) {
      hit[hit] <- (words[[step$word]][hit] %/% step$divisor) == step$target
      if (!any(hit)) {
        break
      }
    }

    out[hit] <- index$row[[i]]
  }

  out
}
