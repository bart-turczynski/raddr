# IPv6 parsing. See docs/architecture.md sections 3.5 and 5.1.
#
# One vectorized engine, two rule sets, and the same discipline as R/ipv4.R: a
# pass at a time over the whole character vector, never an element at a time.
#
# The engine works by rewriting each literal into its fully expanded
# eight-hextet form as *text*, then parsing eight hextets per row in one flat
# pass. That keeps
# the ragged part of the problem -- how many groups the "::" stands for, and
# whether the tail is a dotted quad -- in vectorized string operations, and
# leaves the arithmetic uniform.

#' Rule sets for the IPv6 grammar
#'
#' @param leading_zeros Whether a hextet may carry leading zeros. The RFC 4291
#'   grammar caps a hextet at four hex digits outright; Apple `inet_pton` caps
#'   the four at *significant* digits and lets the zeros run as wide as they
#'   like, so `0000000000001::` is `1::` **[verified 2026-07-26]**.
#' @param zone `"reject"` if the dialect has no zone ID at all, `"any"` if it
#'   accepts one. See section 3.5 for why the paper dialects reject.
#' @param tail The IPv4 rule set the dotted-quad tail is read under. Both
#'   choices are rule sets that already exist, which is the finding: the tail is
#'   not a new grammar, it is the dialect's own four-part decimal grammar.
#'
#' @noRd
ipv6_rules <- function(leading_zeros, zone, tail) {
  list(leading_zeros = leading_zeros, zone = zone, tail = tail)
}

# The two paper dialects agree completely about IPv6, so they share a rule set.
# All of the paper-versus-reality divergence in IPv6 is on the reality side
# (section 3.5), which is the opposite of the IPv4 picture.
rules_v6_paper <- ipv6_rules(
  leading_zeros = FALSE, zone = "reject", tail = rules_strict
)

rules_v6_libc <- ipv6_rules(
  leading_zeros = TRUE, zone = "any", tail = rules_pton
)

# Count the ":"-separated pieces of a string, where the empty string has none.
ipv6_pieces <- function(s) {
  ifelse(
    nzchar(s),
    nchar(s) - nchar(gsub(":", "", s, fixed = TRUE)) + 1L,
    0L
  )
}

#' Parse an IPv6 literal
#'
#' @param x A character vector.
#' @param rules A list from [ipv6_rules()].
#'
#' @return A list with `w1`-`w4` (doubles in `[0, 2^32)`), `zone` (character,
#'   `NA` where the literal carried none), `four_in_six` (logical) and `ok`.
#'
#' @noRd
parse_ipv6_addr <- function(x, rules) {
  n <- length(x)
  out <- list(
    w1 = numeric(n), w2 = numeric(n), w3 = numeric(n), w4 = numeric(n),
    zone = rep(NA_character_, n),
    four_in_six = logical(n),
    ok = logical(n)
  )
  if (n == 0L) {
    return(out)
  }

  live <- !is.na(x)
  body <- x
  zone <- rep(NA_character_, n)

  # --- The zone ID, which never enters the bits (section 5.1) ---------------
  #
  # The zone is split off first, because everything downstream is about the
  # address and the zone's own grammar is "whatever is left". Apple inet_pton
  # accepts a zone on any address and accepts an empty one; what it rejects is a
  # second "%" [verified 2026-07-26].
  marker <- regexpr("%", body, fixed = TRUE)
  zoned <- live & marker > 0L
  if (any(zoned)) {
    if (identical(rules$zone, "reject")) {
      live <- live & !zoned
    } else {
      at <- marker[zoned]
      zone[zoned] <- substring(body[zoned], at + 1L)
      body[zoned] <- substr(body[zoned], 1L, at - 1L)
      live[zoned] <- !grepl("%", zone[zoned], fixed = TRUE)
    }
  }

  # A literal that is nothing but a zone, or a single colon, is not an address.
  live <- live & nchar(body) >= 2L

  # --- The dotted-quad tail -------------------------------------------------
  #
  # Stood down to a placeholder rather than parsed in place, so that everything
  # after this point sees a uniform hextet grammar. The tail is read under the
  # dialect's own four-part decimal IPv4 rules, which is why no new number
  # parser appears here.
  #
  # The placeholder is the constant "0:0" and the parsed value is carried
  # alongside, rather than rendered back into hex text. A tail is always the
  # final piece, so it always lands in the last two groups, and writing it there
  # afterwards costs nothing -- where rendering it would mean an `sprintf()`
  # over every dotted row, which measured as more than the rest of the parse.
  tail_value <- rep(NA_real_, n)
  dotted <- live & grepl(".", body, fixed = TRUE)
  if (any(dotted)) {
    last <- sub("^.*:", "", body[dotted])
    # Every dot must be inside the final piece; "::1.2.3.4:5" is not a tail.
    dots_total <- nchar(body[dotted]) -
      nchar(gsub(".", "", body[dotted], fixed = TRUE))
    dots_last <- nchar(last) - nchar(gsub(".", "", last, fixed = TRUE))
    quad <- parse_ipv4_addr(last, rules$tail)
    usable <- quad$ok & dots_total == dots_last
    where <- which(dotted)
    live[where] <- usable
    if (any(usable)) {
      keep <- where[usable]
      tail_value[keep] <- quad$value[usable]
      body[keep] <- paste0(sub("[^:]*$", "", body[keep]), "0:0")
    }
  }

  # --- The "::" elision -----------------------------------------------------
  #
  # At most one, and it must stand for at least one group: "1:2:3:4:5:6:7:8::"
  # is a rejection rather than a no-op, because the eight groups are already
  # spoken for.
  live <- live & !grepl(":::", body, fixed = TRUE)
  elision <- regexpr("::", body, fixed = TRUE)
  elided <- live & elision > 0L
  if (any(elided)) {
    rest <- substring(body[elided], elision[elided] + 2L)
    live[elided] <- regexpr("::", rest, fixed = TRUE) < 0L
    elided <- live & elision > 0L
  }

  head_part <- body
  tail_part <- rep("", n)
  if (any(elided)) {
    head_part[elided] <- substr(body[elided], 1L, elision[elided] - 1L)
    tail_part[elided] <- substring(body[elided], elision[elided] + 2L)
  }
  gap <- 8L - ipv6_pieces(head_part) - ipv6_pieces(tail_part)
  live <- live & !is.na(gap) & ifelse(elided, gap >= 1L, gap == 0L)

  # Expand to exactly eight pieces, so the parse below is a single flat pass
  # over 8n hextets rather than a ragged one.
  full <- body
  if (any(elided & live)) {
    at <- which(elided & live)
    # The filler always ends in a colon, so it is trimmed only when there is no
    # tail to join it to. Trimming unconditionally would swallow the stray
    # trailing colon of "::1:" and turn a rejection into a seven-group address.
    tails <- tail_part[at]
    full[at] <- paste0(
      ifelse(nzchar(head_part[at]), paste0(head_part[at], ":"), ""),
      ifelse(nzchar(tails), strrep("0:", gap[at]), strrep("0:", gap[at] - 1L)),
      ifelse(nzchar(tails), tails, "0")
    )
  }

  # An empty piece anywhere is a stray colon: ":1", "1:", "1:::2" all land here.
  live <- live & !grepl("(^:|::|:$)", full)
  if (!any(live)) {
    return(out)
  }

  # --- The hextets ----------------------------------------------------------
  #
  # Apple inet_pton caps the four hex digits at the *significant* ones, so the
  # leading-zero form of the pattern lets the zeros run first.
  pattern <- if (rules$leading_zeros) {
    "^0*[0-9a-fA-F]{0,4}$"
  } else {
    "^[0-9a-fA-F]{1,4}$"
  }

  rows <- which(live)
  flat <- unlist(strsplit(full[rows], ":", fixed = TRUE), use.names = FALSE)
  bad <- !grepl(pattern, flat, perl = TRUE)

  # `strtoi()` reads a leading zero happily, so the zeros only have to be
  # stripped where they could push a hextet past four digits and overflow it --
  # which is only possible under the leading-zero rules, and only for a piece
  # wider than a hextet. Guarding it keeps an 8n-element regex out of the common
  # case, where every piece is already four characters or fewer.
  wide <- nchar(flat) > 4L
  if (any(wide)) {
    flat[wide] <- sub("^0+(.)", "\\1", flat[wide])
  }
  value <- as.numeric(strtoi(flat, 16L))

  # Likewise: in the common case nothing is malformed, so neither the blanking
  # nor the group-wise reduction has to touch a single piece.
  if (any(bad)) {
    value[bad] <- 0
    spoiled <- .colSums(as.numeric(bad), 8L, length(rows)) > 0
  } else {
    spoiled <- logical(length(rows))
  }

  m <- matrix(value, nrow = 8L)

  w1 <- m[1L, ] * 65536 + m[2L, ]
  w2 <- m[3L, ] * 65536 + m[4L, ]
  w3 <- m[5L, ] * 65536 + m[6L, ]
  w4 <- m[7L, ] * 65536 + m[8L, ]

  # The dotted-quad tail, written into the last two groups it always occupies.
  tails <- tail_value[rows]
  at <- which(!is.na(tails))
  if (length(at)) {
    w4[at] <- tails[at]
  }

  good <- rows[!spoiled]
  keep <- !spoiled
  out$w1[good] <- w1[keep]
  out$w2[good] <- w2[keep]
  out$w3[good] <- w3[keep]
  out$w4[good] <- w4[keep]
  out$zone[good] <- zone[good]
  # The 4-in-6 family is decided by the bits, exactly as Go's net/netip decides
  # it: an IPv6 literal in ::ffff:0:0/96, however it was spelled (section 5.1).
  out$four_in_six[good] <- w1[keep] == 0 & w2[keep] == 0 & w3[keep] == 65535
  out$ok[good] <- TRUE
  out
}

ipv6_address <- function(parsed) {
  family <- ifelse(
    parsed$ok,
    ifelse(parsed$four_in_six, "v6_4in6", "v6"),
    NA_character_
  )
  new_raddr_address(
    w1 = ipv4_word(parsed$w1),
    w2 = ipv4_word(parsed$w2),
    w3 = ipv4_word(parsed$w3),
    w4 = ipv4_word(parsed$w4),
    family = factor(family, levels = addr_families),
    zone = ifelse(parsed$ok, parsed$zone, NA_character_)
  )
}
