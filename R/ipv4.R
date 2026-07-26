# IPv4 dialect primitives. See docs/architecture.md sections 3.1 to 3.3.
#
# One vectorized engine, four rule sets. Every function here works a pass at a
# time over the whole character vector rather than an element at a time, because
# at 1e6 rows the cost is allocation and copying (section 11.1).

# Digit alphabet, uppercase and lowercase folded onto the same values.
ipv4_digit_chars <- c(as.character(0:9), letters[1:6], LETTERS[1:6])
ipv4_digit_values <- c(0:9, 10:15, 10:15)

# How many trailing digits preserve a value modulo 2^32 in each base. Keeping
# only those bounds the accumulation loop without changing the wrapped result:
# 2^32 divides 16^8, 8^11 and 10^32.
ipv4_mod_digits <- c("8" = 11L, "10" = 32L, "16" = 8L)

# How many digits a value below 2^32 can have in each base. More than this is an
# overflow, whatever the digits are.
ipv4_max_digits <- c("8" = 11L, "10" = 10L, "16" = 8L)

# Positional weights, and the bound on the final part at each arity. Looked up
# rather than computed, because `256^(4 - pos)` over millions of parts is not
# free.
ipv4_weights <- c(16777216, 65536, 256, 1)
ipv4_final_bounds <- c(4294967295, 16777215, 65535, 255)

#' Does a host end in something the IPv4 number parser would accept?
#'
#' Drops one trailing dot, then asks whether the final label is a run of ASCII
#' digits or a `0x` hex literal. Those are exactly the labels the number parser
#' accepts, so a `TRUE` here means the host must parse as IPv4 or fail outright:
#' there is no reg-name fallback to fall into.
#'
#' Broader than "every label is numeric" -- it also fires on `foo.09`, `foo.0x4`
#' and `1.2.3.08.`, which is the point.
#'
#' @param x A character vector.
#'
#' @return A logical vector. `NA` and `""` are `FALSE`.
#'
#' @noRd
ends_in_a_number <- function(x) {
  out <- !is.na(x) & nzchar(x)
  if (!any(out)) {
    return(out)
  }
  last <- sub("^.*\\.", "", sub("\\.$", "", x))
  out & (grepl("^[0-9]+$", last) | grepl("^0[xX][0-9a-fA-F]*$", last))
}

#' Parse one IPv4 part
#'
#' Vectorized over a character vector of parts, with the radix sniffed per part:
#' a `0x`/`0X` prefix means hex, a leading `0` on a longer run means octal,
#' anything else is decimal. The alphabet is validated **before** conversion, so
#' `09` is not a number rather than nine.
#'
#' @param parts A character vector of single parts.
#' @param hex,octal Whether those radix prefixes are recognized. Both are
#'   `FALSE` for the decimal-only dialects.
#'
#' @return A list with `value` (double, the value modulo 2^32) and `status`, one
#'   of `"ok"`, `"not_a_number"` or `"overflow"`. `"overflow"` still carries the
#'   wrapped `value`, because one dialect wants it: see [addr_aton()].
#'
#' @noRd
parse_ipv4_number <- function(parts, hex = TRUE, octal = TRUE) {
  n <- length(parts)
  value <- numeric(n)
  status <- rep("ok", n)
  empty <- logical(n)
  if (n == 0L) {
    return(list(value = value, status = status, empty = empty))
  }

  # A decimal run with no leading zero means the same thing in every dialect and
  # is almost all real input, so it skips the digit-at-a-time path entirely.
  # Ten digits is the widest a value below 2^32 can be, and as.numeric() is
  # exact well past that.
  width <- nchar(parts, type = "bytes")
  plain <- !grepl("[^0-9]", parts, perl = TRUE) &
    width >= 1L & width <= 10L &
    (width == 1L | !startsWith(parts, "0"))
  if (any(plain)) {
    fast <- as.numeric(parts[plain])
    over <- fast > 4294967295
    fast[over] <- fast[over] %% 4294967296
    value[plain] <- fast
    marks <- rep("ok", length(fast))
    marks[over] <- "overflow"
    status[plain] <- marks
  }
  if (all(plain)) {
    return(list(value = value, status = status, empty = empty))
  }

  slow <- which(!plain)
  parsed <- parse_ipv4_number_slow(parts[slow], hex = hex, octal = octal)
  value[slow] <- parsed$value
  status[slow] <- parsed$status
  empty[slow] <- parsed$empty
  list(value = value, status = status, empty = empty)
}

# The general case: radix prefixes, alphabet validation, and digit runs of any
# width. Correct for everything, and only reached by parts the fast path above
# declined.
parse_ipv4_number_slow <- function(parts, hex = TRUE, octal = TRUE) {
  n <- length(parts)
  base <- rep(10L, n)
  digits <- parts

  is_hex <- if (hex) grepl("^0[xX]", parts) else rep(FALSE, n)
  if (any(is_hex)) {
    base[is_hex] <- 16L
    digits[is_hex] <- substring(parts[is_hex], 3L)
  }
  if (octal) {
    is_octal <- !is_hex & grepl("^0[0-9]+$", parts)
    if (any(is_octal)) {
      base[is_octal] <- 8L
      digits[is_octal] <- substring(parts[is_octal], 2L)
    }
  }

  # Leading zeros carry no value in any base, so dropping them bounds the loop.
  digits <- sub("^0+(.)", "\\1", digits)
  width <- nchar(digits)

  key <- as.character(base)

  # A digit run too long to fit below 2^32 has overflowed whatever its digits
  # are. Truncating those to the last few digits bounds the loop without
  # changing the wrapped result, and it only ever happens to runs this check has
  # already flagged.
  overflow <- width > ipv4_max_digits[key]
  keep <- pmin(width, ipv4_mod_digits[key])
  long <- width > keep
  if (any(long)) {
    digits[long] <- substring(digits[long], width[long] - keep[long] + 1L)
    width[long] <- keep[long]
  }

  # An empty digit run is a bare "0x". It is a zero, not a failure; the dialects
  # that dislike it say so themselves.
  status <- rep("ok", n)
  value <- numeric(n)

  maxwidth <- if (n == 0L) 0L else max(width)
  if (maxwidth > 0L) {
    padded <- paste0(strrep("0", maxwidth - width), digits)
    invalid <- logical(n)
    for (i in seq_len(maxwidth)) {
      digit <- ipv4_digit_values[match(substr(padded, i, i), ipv4_digit_chars)]
      bad <- is.na(digit) | digit >= base
      invalid <- invalid | bad
      digit[bad] <- 0
      # `value` is below 2^32 and `base` is at most 16, so this stays under
      # 2^36 and a double holds it exactly. That is what makes the overflow
      # test reliable at every width rather than only at the wide ones.
      accumulated <- value * base + digit
      overflow <- overflow | accumulated >= 4294967296
      value <- accumulated %% 4294967296
    }
    status[invalid] <- "not_a_number"
  }

  status[status == "ok" & overflow] <- "overflow"
  list(value = value, status = status, empty = width == 0L)
}

#' Parse a dotted IPv4 address
#'
#' The shared engine. Splits on `.`, parses each part, applies the per-part
#' bounds, and accumulates. The accumulation uses arithmetic (`256^(4 - i)`),
#' never `bitwShiftL()`, because R integers are signed 32-bit and shifting past
#' 2^31 returns `NA` in silence (section 11).
#'
#' @param x A character vector.
#' @param rules A list from [ipv4_rules()].
#' @param codes Whether to collect reason codes. Off by default: the six
#'   single-dialect parsers return a bare address and have nowhere to put them,
#'   so they should not pay for them. [addr_parse()] turns them on.
#'
#' @return A list with `value` (double in `[0, 2^32)`, `NA` where the dialect
#'   rejects), `ok` (logical) and, when `codes` is `TRUE`, `mask` (integer, the
#'   packed reason codes -- see R/codes.R).
#'
#' @noRd
parse_ipv4_addr <- function(x, rules, codes = FALSE) {
  n <- length(x)
  value <- rep(NA_real_, n)
  ok <- rep(FALSE, n)
  mask <- integer(n)
  if (n == 0L) {
    return(list(value = value, ok = ok, mask = mask))
  }

  input <- x
  live <- !is.na(input)

  # inet_aton stops at the first whitespace character and ignores the rest, so
  # "1.2.3.4 junk" is an address to it. Leading whitespace still fails, because
  # the truncation leaves nothing to parse.
  if (rules$stop_at_space) {
    input <- sub("[ \t\r\n\v\f].*$", "", input)
  }

  # WHATWG drops one trailing dot, so "1.2.3." is 1.2.0.3. A second one is still
  # an empty final part, and strsplit() would swallow it in silence, so the
  # check happens here rather than on the split parts.
  if (rules$trailing_dot) {
    dotted <- which(endsWith(input, "."))
    if (length(dotted)) {
      input[dotted] <- substr(input[dotted], 1L, nchar(input[dotted]) - 1L)
    }
  }
  present <- live & !is.na(input)
  empty <- present & !nzchar(input)
  trailing <- present & !empty & endsWith(input, ".")
  live <- present & !empty & !trailing
  if (codes) {
    mask[empty] <- code_bit("empty_part")
    mask[trailing] <- code_bit("trailing_dot")
  }
  if (!any(live)) {
    return(list(value = value, ok = ok, mask = mask))
  }

  # Ragged split, flattened so the parts can be parsed in one pass.
  pieces <- strsplit(input[live], ".", fixed = TRUE)
  k <- lengths(pieces)
  flat <- unlist(pieces, use.names = FALSE)
  id <- rep.int(seq_along(k), k)
  pos <- sequence(k)
  last <- pos == k[id]

  arity_ok <- k >= 1L & k <= 4L
  if (!is.null(rules$parts)) {
    arity_ok <- arity_ok & k == rules$parts
  }

  parsed <- parse_ipv4_number(flat, hex = rules$hex, octal = rules$octal)
  blank <- !nzchar(flat)
  nan <- parsed$status == "not_a_number"
  zeroed <- if (rules$leading_zeros) FALSE else grepl("^0[0-9]", flat)
  hexless <- if (!rules$empty_hex) {
    parsed$empty
  } else if (!is.null(rules$empty_hex_final) && !rules$empty_hex_final) {
    # inet_aton tolerates a digitless "0x" anywhere but in the final part.
    parsed$empty & last
  } else {
    FALSE
  }

  # Every part but the last is one octet; the last fills whatever is left.
  # A row with more than four parts is already rejected on arity, and its parts
  # past the fourth never reach the accumulation below, so pinning the lookup at
  # four only keeps an NA out of `over` -- it changes no verdict.
  bound <- rep(255, length(pos))
  bound[last] <- ipv4_final_bounds[pmin(k[id][last], 4L)]
  over <- parsed$status == "overflow" | parsed$value > bound
  if (rules$wrap) {
    # inet_aton range-checks every arity but the whole-host number, which it
    # simply truncates to 32 bits.
    over <- over & !(last & k[id] == 1L)
  }
  bad <- blank | nan | zeroed | hexless | over

  # One code per part, first match wins, so a part that is not a number does not
  # also report the range its garbage value happened to land outside of. A row
  # still collects every code its parts raised, which is the honest answer when
  # two parts fail for two different reasons.
  part_mask <- if (codes) {
    first_code(
      list(
        empty_part = blank,
        not_a_number = nan,
        leading_zero = zeroed,
        empty_hex = hexless,
        out_of_range = over
      ),
      length(flat)
    )
  }

  weight <- ipv4_weights[pos]
  weight[last] <- 1
  contribution <- parsed$value * weight

  # Group-sum by scatter-add over the four possible part positions. A general
  # grouped sum (rowsum(), tapply()) costs several times this, and the group
  # sizes here are bounded by four.
  total <- numeric(length(k))
  spoiled <- logical(length(k))
  row_mask <- integer(length(k))
  for (i in seq_len(4L)) {
    at <- which(pos == i)
    if (!length(at)) {
      next
    }
    group <- id[at]
    total[group] <- total[group] + contribution[at]
    spoiled[group] <- spoiled[group] | bad[at]
    if (codes) {
      # `group` is unique within one position, so this is a scatter and not a
      # reduction -- bitwOr() is what makes it accumulate across the four.
      row_mask[group] <- bitwOr(row_mask[group], part_mask[at])
    }
  }
  good <- arity_ok & !spoiled
  good[is.na(good)] <- FALSE

  if (codes) {
    # Parts past the fourth never reach the loop above, so their codes are lost
    # -- which is the right answer, because the arity is the whole objection.
    row_mask[!arity_ok] <- bitwOr(
      row_mask[!arity_ok],
      code_bit("wrong_part_count")
    )
    mask[live] <- row_mask
  }

  value[live][good] <- total[good] %% 4294967296
  ok[live] <- good
  list(value = value, ok = ok, mask = mask)
}

# The rule sets. Each one is a claim about a standard or an implementation, and
# each claim is exercised by the divergence table in test-ipv4.R.
ipv4_rules <- function(hex, octal, leading_zeros, parts, trailing_dot, wrap,
                       stop_at_space, empty_hex, empty_hex_final = TRUE) {
  list(
    hex = hex, octal = octal, leading_zeros = leading_zeros, parts = parts,
    trailing_dot = trailing_dot, wrap = wrap, stop_at_space = stop_at_space,
    empty_hex = empty_hex, empty_hex_final = empty_hex_final
  )
}

rules_strict <- ipv4_rules(
  hex = FALSE, octal = FALSE, leading_zeros = FALSE, parts = 4L,
  trailing_dot = FALSE, wrap = FALSE, stop_at_space = FALSE, empty_hex = FALSE
)

rules_whatwg <- ipv4_rules(
  hex = TRUE, octal = TRUE, leading_zeros = TRUE, parts = NULL,
  trailing_dot = TRUE, wrap = FALSE, stop_at_space = FALSE, empty_hex = TRUE
)

rules_pton <- ipv4_rules(
  hex = FALSE, octal = FALSE, leading_zeros = TRUE, parts = 4L,
  trailing_dot = FALSE, wrap = FALSE, stop_at_space = FALSE, empty_hex = FALSE
)

rules_aton <- ipv4_rules(
  hex = TRUE, octal = TRUE, leading_zeros = TRUE, parts = NULL,
  trailing_dot = FALSE, wrap = TRUE, stop_at_space = TRUE, empty_hex = TRUE,
  empty_hex_final = FALSE
)

# A 32-bit value as the signed word the record stores. 2^31 lands on
# NA_integer_, which is the 0x80000000 bit pattern and not missingness
# (section 5.1.1) -- so `addr_aton("2147483648")` is 128.0.0.0 and equals
# itself.
ipv4_word <- function(value) {
  signed <- value - (value >= 2147483648) * 4294967296
  suppressWarnings(as.integer(signed))
}

# Run the IPv4 engine over everything except `skip`, unless the rule set is one
# that could still accept a skipped row. Rows not parsed come back rejected,
# which is what they would have been anyway.
parse_ipv4_skipping <- function(x, rules, skip, codes = FALSE) {
  if (rules$stop_at_space || !any(skip)) {
    return(parse_ipv4_addr(x, rules, codes = codes))
  }
  n <- length(x)
  at <- which(!skip)
  parsed <- parse_ipv4_addr(x[at], rules, codes = codes)
  value <- rep(NA_real_, n)
  ok <- logical(n)
  mask <- integer(n)
  value[at] <- parsed$value
  ok[at] <- parsed$ok
  mask[at] <- parsed$mask
  list(value = value, ok = ok, mask = mask)
}

ipv4_address <- function(parsed) {
  n <- length(parsed$ok)
  new_raddr_address(
    w1 = integer(n),
    w2 = integer(n),
    w3 = integer(n),
    w4 = ipv4_word(parsed$value),
    family = factor(
      ifelse(parsed$ok, "v4", NA_character_),
      levels = addr_families
    ),
    zone = rep(NA_character_, n)
  )
}

# The IPv4 and IPv6 grammars are disjoint, so a dialect is the two engines side
# by side rather than one engine that branches. IPv6 is asked only about rows
# the IPv4 rules declined *and* that contain a colon, which is both an exact
# filter -- no IPv6 literal is colon-free -- and a cheap one.
#
# The colon test alone would not be exact: `inet_aton` stops at the first
# whitespace character, so "1.2.3.4 :5" is an IPv4 address carrying a colon.
# Asking IPv4 first and IPv6 only about its leftovers keeps that row IPv4.
#
# That whitespace quirk is also the *only* way an IPv4 rule set can accept a
# colon, so every other one is spared looking at the IPv6 rows at all. On a
# vector of IPv6 literals that is most of the IPv4 engine's work removed.
parse_dialect <- function(x, rules, rules6 = NULL, arg = "x") {
  parse_dialect_full(x, rules, rules6, arg = arg, codes = FALSE)$address
}

# The same engine, returning the reason codes alongside. The six single-dialect
# parsers return a bare `raddr_address` (section 6.1) and have nowhere to put a
# mask, so they go through the wrapper above and pay for nothing; `addr_parse()`
# is the only caller that asks for both.
parse_dialect_full <- function(x, rules, rules6 = NULL, arg = "x",
                               codes = FALSE) {
  if (!is.character(x)) {
    x <- vec_cast(x, character(), x_arg = arg)
  }
  colon <- grepl(":", x, fixed = TRUE) & !is.na(x)
  parsed <- parse_ipv4_skipping(x, rules, skip = colon, codes = codes)
  out <- ipv4_address(parsed)
  mask <- parsed$mask

  if (is.null(rules6)) {
    if (codes) {
      # An AF_INET-only dialect has no reading of a colon literal to object to,
      # so whatever its IPv4 rules made of one is noise. `inet_aton` reaches
      # here with real codes for "1.2.3.4 :5", which it accepts, so the erasure
      # is scoped to the colon rows it rejected.
      mask[colon & is.na(field(out, "family"))] <- 0L
    }
    return(list(address = out, mask = mask))
  }

  candidate <- is.na(field(out, "family")) & colon
  if (!any(candidate)) {
    return(list(address = out, mask = mask))
  }
  parsed6 <- parse_ipv6_addr(x[candidate], rules6, codes = codes)
  out <- vec_assign(out, candidate, ipv6_address(parsed6))
  mask[candidate] <- parsed6$mask
  list(address = out, mask = mask)
}
