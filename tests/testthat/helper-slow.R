# Naive second implementations of the shipped engines, kept to be disagreed
# with. See docs/architecture.md section 11.3; the pattern is the one Go keeps
# in its net/netip package, as a slow test file beside the fast parser.
#
# Everything here is written for obviousness and is far too slow to ship: one
# address at a time, one character at a time, no vectorization, no fast paths,
# no lookup tables indexed by character code. That is the whole value of it.
# The shipped engines are fast because they work in bulk -- a flat pass over 8n
# hextets, a scatter-add over four part positions, a digit run truncated to the
# digits the modulus keeps, a zero run found by a backwards recursion over a
# matrix -- and every one of those is a place an off-by-one can hide and still
# look plausible. A second implementation that shares none of that machinery
# turns such a bug into a disagreement rather than into the same wrong answer
# computed twice.
#
# What the two sides do share is the *specification*. The rule sets below
# restate section 3 rather than reading `rules_strict` and friends, and the
# renderer restates RFC 5952 rather than calling `render_canonical()`. A rule
# written down twice is checked; a rule read from one place by both sides is
# not.
#
# The comparison surface is text on both sides: these functions answer with a
# fixed-width hex string, a family and a zone, which is a complete description
# of a `raddr_address` that reaches none of its constructors.

# --- characters, digits and bases --------------------------------------------

# The hex alphabet, lowercase. `match()` against this is the entire digit
# conversion here -- no `strtoi()`, and no table indexed by character code.
slow_digit_chars <- c(as.character(0:9), letters[1:6])

slow_chars <- function(s) {
  if (nzchar(s)) strsplit(s, "", fixed = TRUE)[[1L]] else character(0)
}

slow_count <- function(s, ch) {
  sum(slow_chars(s) == ch)
}

# A split that keeps every empty piece. `strsplit()` drops a trailing one, so
# `strsplit("1:", ":")` is a single piece and the stray colon disappears --
# which is exactly the input this file exists to disagree about.
slow_split <- function(s, sep) {
  pieces <- character(0)
  current <- ""
  for (ch in slow_chars(s)) {
    if (ch == sep) {
      pieces <- c(pieces, current)
      current <- ""
    } else {
      current <- paste0(current, ch)
    }
  }
  c(pieces, current)
}

# The value of a digit run in one base, longhand. Accumulation is modulo 2^32
# with a flag for whether it wrapped: `value` stays below 2^32 and `base` is at
# most 16, so `value * base + d` stays under 2^36 and a double holds it exactly.
#
# The shipped parser truncates a long run to the trailing digits the modulus
# preserves and runs a separate fast path for plain decimals. This one does
# neither, which is the point of having it.
slow_run_value <- function(digits, base) {
  value <- 0
  over <- FALSE
  for (ch in slow_chars(digits)) {
    d <- match(tolower(ch), slow_digit_chars) - 1L
    if (is.na(d) || d >= base) {
      return(list(value = 0, ok = FALSE, over = FALSE))
    }
    value <- value * base + d
    if (value > 4294967295) {
      over <- TRUE
      value <- value %% 4294967296
    }
  }
  list(value = value, ok = TRUE, over = over)
}

# A number as `digits` lowercase hex characters, by repeated division.
slow_hex_string <- function(value, digits) {
  out <- character(digits)
  for (i in seq.int(digits, 1L)) {
    out[[i]] <- slow_digit_chars[[(value %% 16) + 1L]]
    value <- value %/% 16
  }
  paste(out, collapse = "")
}

# --- the rule sets, restated (section 3) -------------------------------------

slow_rules <- list(
  strict = list(
    v4 = list(
      hex = FALSE, octal = FALSE, leading_zeros = FALSE, parts = 4L,
      trailing_dot = FALSE, wrap = FALSE, stop_at_space = FALSE,
      empty_hex = FALSE, empty_hex_final = TRUE
    ),
    v6 = list(leading_zeros = FALSE, zone = "reject", tail = "strict")
  ),
  whatwg = list(
    v4 = list(
      hex = TRUE, octal = TRUE, leading_zeros = TRUE, parts = NULL,
      trailing_dot = TRUE, wrap = FALSE, stop_at_space = FALSE,
      empty_hex = TRUE, empty_hex_final = TRUE
    ),
    v6 = list(leading_zeros = FALSE, zone = "reject", tail = "strict")
  ),
  pton = list(
    v4 = list(
      hex = FALSE, octal = FALSE, leading_zeros = TRUE, parts = 4L,
      trailing_dot = FALSE, wrap = FALSE, stop_at_space = FALSE,
      empty_hex = FALSE, empty_hex_final = TRUE
    ),
    v6 = list(leading_zeros = TRUE, zone = "any", tail = "pton")
  ),
  # `inet_aton` is AF_INET by signature, so it has no IPv6 reading at all.
  aton = list(
    v4 = list(
      hex = TRUE, octal = TRUE, leading_zeros = TRUE, parts = NULL,
      trailing_dot = FALSE, wrap = TRUE, stop_at_space = TRUE,
      empty_hex = TRUE, empty_hex_final = FALSE
    ),
    v6 = NULL
  )
)

# --- IPv4 --------------------------------------------------------------------

# One part: sniff the radix, strip the leading zeros, read the digits.
slow_v4_number <- function(s, hex, octal) {
  base <- 10
  digits <- s
  if (hex && grepl("^0[xX]", s)) {
    base <- 16
    digits <- substring(s, 3L)
  } else if (octal && grepl("^0[0-9]+$", s)) {
    base <- 8
    digits <- substring(s, 2L)
  }
  digits <- sub("^0+(.)", "\\1", digits)
  run <- slow_run_value(digits, base)
  list(value = run$value, ok = run$ok, over = run$over, empty = !nzchar(digits))
}

# Is a digitless "0x" acceptable in this position? WHATWG tolerates one
# anywhere, `inet_aton` anywhere but the final part, and nobody else at all.
slow_empty_hex_ok <- function(rules, last) {
  rules$empty_hex && (rules$empty_hex_final || !last)
}

# The part's value, or NA if any of the dialect's gates rejects it.
slow_v4_part <- function(p, i, k, rules) {
  if (!nzchar(p)) {
    return(NA_real_)
  }
  if (!rules$leading_zeros && grepl("^0[0-9]", p)) {
    return(NA_real_)
  }
  n <- slow_v4_number(p, hex = rules$hex, octal = rules$octal)
  last <- i == k
  if (!n$ok || (n$empty && !slow_empty_hex_ok(rules, last))) {
    return(NA_real_)
  }
  # Every part but the last is one octet; the last fills whatever is left.
  # `inet_aton` range-checks every arity but the whole-host number, which it
  # simply truncates to 32 bits.
  limit <- if (last) c(4294967295, 16777215, 65535, 255)[[k]] else 255
  waived <- rules$wrap && last && k == 1L
  if (!waived && (n$over || n$value > limit)) {
    return(NA_real_)
  }
  n$value
}

# A dotted IPv4 address under one rule set: a double in [0, 2^32) or NA.
slow_v4 <- function(s, rules) {
  if (is.na(s)) {
    return(NA_real_)
  }
  # `inet_aton` stops at the first whitespace character and ignores the rest,
  # so "1.2.3.4 junk" is an address to it and " 1.2.3.4" is not.
  if (rules$stop_at_space) {
    s <- sub("[ \t\r\n\v\f].*$", "", s)
  }
  # WHATWG drops one trailing dot, so "1.2.3." is 1.2.0.3. A second one leaves
  # an empty final part, which is a rejection.
  if (rules$trailing_dot && endsWith(s, ".")) {
    s <- substr(s, 1L, nchar(s) - 1L)
  }
  if (!nzchar(s)) {
    return(NA_real_)
  }

  piece <- slow_split(s, ".")
  k <- length(piece)
  if (k > 4L || (!is.null(rules$parts) && k != rules$parts)) {
    return(NA_real_)
  }

  value <- 0
  for (i in seq_len(k)) {
    part <- slow_v4_part(piece[[i]], i, k, rules)
    if (is.na(part)) {
      return(NA_real_)
    }
    value <- value + part * if (i == k) 1 else 256^(4 - i)
  }
  value %% 4294967296
}

# --- IPv6 --------------------------------------------------------------------

# The zone ID, split off first: everything downstream is about the address, and
# the zone's own grammar is "whatever is left" (section 5.1). A second "%" is
# the one thing the reality dialects reject.
slow_v6_zone <- function(s, zone) {
  at <- regexpr("%", s, fixed = TRUE)
  if (at < 0L) {
    return(list(body = s, zone = NA_character_))
  }
  if (zone == "reject") {
    return(NULL)
  }
  rest <- substring(s, at + 1L)
  if (grepl("%", rest, fixed = TRUE)) {
    return(NULL)
  }
  list(body = substr(s, 1L, at - 1L), zone = rest)
}

# The "::" elision: at most one, and everything on either side of it. A second
# one is a rejection, and so is ":::", whose third colon lands in `tail` as an
# empty piece.
slow_v6_split <- function(body) {
  at <- regexpr("::", body, fixed = TRUE)
  if (at < 0L) {
    return(list(head = slow_split(body, ":"), tail = character(0),
                elided = FALSE))
  }
  before <- substr(body, 1L, at - 1L)
  rest <- substring(body, at + 2L)
  if (grepl("::", rest, fixed = TRUE)) {
    return(NULL)
  }
  list(
    head = if (nzchar(before)) slow_split(before, ":") else character(0),
    tail = if (nzchar(rest)) slow_split(rest, ":") else character(0),
    elided = TRUE
  )
}

# The text after the final colon, which is where a dotted-quad tail must sit.
slow_v6_final <- function(groups) {
  if (length(groups$tail)) {
    groups$tail[[length(groups$tail)]]
  } else if (groups$elided) {
    ""
  } else {
    groups$head[[length(groups$head)]]
  }
}

# Each piece as a hextet value, or NULL if any of them is not one. An empty
# piece is a stray colon; a piece with more than four significant hex digits
# overflows a hextet, and only the reality dialects let the insignificant ones
# run wider than that.
slow_v6_hextets <- function(pieces, leading_zeros) {
  out <- numeric(length(pieces))
  for (i in seq_along(pieces)) {
    p <- pieces[[i]]
    digits <- sub("^0+(.)", "\\1", p)
    if (!nzchar(p) || nchar(digits) > 4L ||
          (!leading_zeros && nchar(p) > 4L)) {
      return(NULL)
    }
    run <- slow_run_value(digits, 16)
    if (!run$ok) {
      return(NULL)
    }
    out[[i]] <- run$value
  }
  out
}

# An IPv6 literal under one rule set: eight hextet values and a zone, or NULL.
slow_v6 <- function(s, rules) {
  split <- slow_v6_zone(s, rules$zone)
  # A literal that is nothing but a zone, or a single colon, is not an address.
  if (is.null(split) || nchar(split$body) < 2L) {
    return(NULL)
  }
  body <- split$body
  groups <- slow_v6_split(body)
  if (is.null(groups)) {
    return(NULL)
  }
  head <- groups$head
  tail <- groups$tail

  # The dotted-quad tail is read under the dialect's own four-part decimal IPv4
  # rules, which is why no new number parser appears here. Every dot has to be
  # inside the final piece: "::1.2.3.4:5" is not a tail.
  quad <- numeric(0)
  if (grepl(".", body, fixed = TRUE)) {
    final <- slow_v6_final(groups)
    if (slow_count(body, ".") != slow_count(final, ".")) {
      return(NULL)
    }
    value <- slow_v4(final, slow_rules[[rules$tail]]$v4)
    if (is.na(value)) {
      return(NULL)
    }
    quad <- c(value %/% 65536, value %% 65536)
    if (length(tail)) {
      tail <- tail[-length(tail)]
    } else {
      head <- head[-length(head)]
    }
  }

  # "::" must stand for at least one group: "1:2:3:4:5:6:7:8::" is a rejection
  # rather than a no-op, because the eight groups are already spoken for.
  given <- length(head) + length(tail) + length(quad)
  if (if (groups$elided) given >= 8L else given != 8L) {
    return(NULL)
  }
  pieces <- c(head, rep("0", 8L - given), tail)

  values <- slow_v6_hextets(pieces, rules$leading_zeros)
  if (is.null(values)) {
    return(NULL)
  }
  list(hextets = c(values, quad), zone = split$zone)
}

# --- one dialect over one literal --------------------------------------------

slow_nothing <- list(
  hex = NA_character_, family = NA_character_, zone = NA_character_
)

# Apple's getaddrinfo runs the KAME embedding in reverse: for an address in
# fe80::/10 -- 0xfe80 through 0xfebf in the first hextet -- it lifts the second
# hextet out into the scope ID and clears it from the bytes, whether or not a
# zone ID was written. An explicit zone still wins; the hextet is cleared either
# way.
slow_gai_scope <- function(out) {
  if (is.na(out$family) || out$family != "v6") {
    return(out)
  }
  first <- slow_run_value(substr(out$hex, 1L, 4L), 16)$value
  second <- slow_run_value(substr(out$hex, 5L, 8L), 16)$value
  if (first < 65152 || first > 65215 || second == 0) {
    return(out)
  }
  if (is.na(out$zone)) {
    out$zone <- as.character(second)
  }
  substr(out$hex, 5L, 8L) <- "0000"
  out
}

# The compositions are compositions here too (section 3.2), so a precedence
# change upstream is two arguments swapped on both sides rather than one.
slow_compose <- function(first, second) {
  if (is.na(first$family)) second else first
}

slow_parse_one <- function(s, dialect) {
  if (is.na(s)) {
    return(slow_nothing)
  }
  if (dialect == "getaddrinfo") {
    # getaddrinfo() rejects an input containing whitespace before either
    # primitive sees it, and the gate covers the address, not the zone ID.
    if (grepl("[ \t\r\n\v\f]", sub("%.*$", "", s))) {
      return(slow_nothing)
    }
    return(slow_gai_scope(
      slow_compose(slow_parse_one(s, "pton"), slow_parse_one(s, "aton"))
    ))
  }
  if (dialect == "curl") {
    return(slow_compose(slow_parse_one(s, "aton"), slow_parse_one(s, "pton")))
  }

  rules <- slow_rules[[dialect]]
  # The two grammars are disjoint, so a dialect is the two engines side by side.
  # IPv4 is asked first: `inet_aton` truncates at whitespace, so "1.2.3.4 :5" is
  # an IPv4 address carrying a colon, and asking IPv6 first would lose it.
  value <- slow_v4(s, rules$v4)
  if (!is.na(value)) {
    return(list(
      hex = slow_hex_string(value, 8L), family = "v4", zone = NA_character_
    ))
  }
  if (is.null(rules$v6)) {
    return(slow_nothing)
  }
  parsed <- slow_v6(s, rules$v6)
  if (is.null(parsed)) {
    return(slow_nothing)
  }
  h <- parsed$hextets
  list(
    hex = paste(
      vapply(h, slow_hex_string, character(1), digits = 4L), collapse = ""
    ),
    # The 4-in-6 family is decided by the bits, not by the spelling: an IPv6
    # literal in ::ffff:0:0/96, however it was written (section 5.1).
    family = if (all(h[1:5] == 0) && h[[6]] == 65535) "v6_4in6" else "v6",
    zone = parsed$zone
  )
}

# One dialect over a character vector: parallel `hex`, `family` and `zone`.
slow_parse <- function(x, dialect) {
  out <- lapply(x, slow_parse_one, dialect = dialect)
  list(
    hex = vapply(out, `[[`, character(1), "hex"),
    family = vapply(out, `[[`, character(1), "family"),
    zone = vapply(out, `[[`, character(1), "zone")
  )
}

# --- the renderers (RFC 5952, restated) --------------------------------------

slow_dotted <- function(hex) {
  octets <- vapply(seq_len(4L), function(i) {
    slow_run_value(substr(hex, 2L * i - 1L, 2L * i), 16)$value
  }, numeric(1))
  paste(as.integer(octets), collapse = ".")
}

slow_hextets_of <- function(hex) {
  vapply(seq_len(8L), function(i) {
    slow_run_value(substr(hex, 4L * i - 3L, 4L * i), 16)$value
  }, numeric(1))
}

# RFC 5952 section 4.2: the run of zero fields "::" stands for. It must cover
# more than one field (4.2.2), the longest run wins, and the first of two
# equally long runs wins (4.2.3) -- which a forward scan and a strict `>` give
# for free.
slow_zero_run <- function(h, fields) {
  start <- 0L
  best <- 0L
  for (i in seq_len(fields)) {
    j <- i
    while (j <= fields && h[[j]] == 0) {
      j <- j + 1L
    }
    if (j - i > best) {
      best <- j - i
      start <- i
    }
  }
  if (best < 2L) {
    list(start = 0L, len = 0L)
  } else {
    list(start = start, len = best)
  }
}

# The pieces joined with ":", where the compressed run is one empty piece. A run
# in the middle already spells "::" that way; a run at either end contributes
# only one colon and needs the other written in.
slow_render <- function(h, fields, extra = NULL) {
  run <- slow_zero_run(h, fields)
  pieces <- character(0)
  i <- 1L
  while (i <= fields) {
    if (i == run$start) {
      pieces <- c(pieces, "")
      i <- i + run$len
    } else {
      # 4.1 (no leading zeros) and 4.3 (lowercase).
      pieces <- c(pieces, sub("^0+(.)", "\\1", slow_hex_string(h[[i]], 4L)))
      i <- i + 1L
    }
  }
  pieces <- c(pieces, extra)
  out <- paste(pieces, collapse = ":")
  if (!nzchar(pieces[[1L]])) {
    out <- paste0(":", out)
  }
  if (!nzchar(pieces[[length(pieces)]])) {
    out <- paste0(out, ":")
  }
  out
}

slow_zoned <- function(out, zone) {
  if (is.na(out) || is.na(zone)) out else paste0(out, "%", zone)
}

slow_format_one <- function(hex, family, zone) {
  if (is.na(family)) {
    return(NA_character_)
  }
  out <- if (family == "v4") {
    slow_dotted(hex)
  } else if (family == "v6_4in6") {
    # RFC 5952 section 5: the first six fields under the ordinary rules, then
    # the last 32 bits as a dotted quad.
    slow_render(slow_hextets_of(hex), 6L, slow_dotted(substr(hex, 25L, 32L)))
  } else {
    slow_render(slow_hextets_of(hex), 8L)
  }
  slow_zoned(out, zone)
}

slow_expand_one <- function(hex, family, zone) {
  if (is.na(family)) {
    return(NA_character_)
  }
  out <- if (family == "v4") {
    slow_dotted(hex)
  } else {
    paste(
      vapply(slow_hextets_of(hex), slow_hex_string, character(1), digits = 4L),
      collapse = ":"
    )
  }
  slow_zoned(out, zone)
}

slow_format <- function(hex, family, zone) {
  vapply(
    seq_along(hex),
    function(i) slow_format_one(hex[[i]], family[[i]], zone[[i]]),
    character(1)
  )
}

slow_expand <- function(hex, family, zone) {
  vapply(
    seq_along(hex),
    function(i) slow_expand_one(hex[[i]], family[[i]], zone[[i]]),
    character(1)
  )
}

# --- the registry matcher (section 11.1.6) -----------------------------------

# The first and last address of one block, which is where an off-by-one in a
# divisor lives. Same arithmetic as `mask_words()` pointed the other way: clear
# the host bits for the first, set them all for the last.
block_edges <- function(table) {
  words <- lapply(
    list(table$w1, table$w2, table$w3, table$w4),
    function(w) widen_word(w)
  )
  len <- table$prefix_len
  is_v4 <- table$space == "v4"

  lo <- hi <- vector("list", 4L)
  for (k in seq_len(4L)) {
    bits <- pmin(pmax(len - 32L * (k - 1L), 0L), 32L)
    bits[is_v4] <- if (k == 4L) pmin(pmax(len[is_v4], 0L), 32L) else 32L
    lo[[k]] <- words[[k]]
    hi[[k]] <- words[[k]] + (2^(32 - bits) - 1)
  }
  c(
    words_to_addr(lo, ifelse(is_v4, 32L, 128L)),
    words_to_addr(hi, ifelse(is_v4, 32L, 128L))
  )
}

# An independent matcher: containment decided by string prefix rather than by
# word arithmetic, longest wins, one address at a time. Far too slow to ship,
# which is the point -- it shares nothing with `prefix_match()` except the
# encoder, so a wrong divisor surfaces as a disagreement instead of as the same
# wrong answer computed twice.
slow_prefix_match <- function(x, table) {
  bits <- addr_to_binary(x)
  space <- ifelse(field(x, "family") == "v4", "v4", "v6")
  base <- addr_to_binary(words_to_addr(
    lapply(list(table$w1, table$w2, table$w3, table$w4), widen_word),
    ifelse(table$space == "v4", 32L, 128L)
  ))

  vapply(seq_along(bits), function(i) {
    if (is.na(space[[i]])) {
      return(NA_integer_)
    }
    rows <- which(table$space == space[[i]])
    len <- table$prefix_len[rows]
    # `startsWith()` and not `substr(bits[[i]], 1L, len)`: `substr()` truncates
    # `stop` to the length of `x`, so a length-1 address against a vector of
    # prefix lengths silently uses only the first one.
    hit <- startsWith(bits[[i]], substr(base[rows], 1L, len))
    if (!any(hit)) {
      return(NA_integer_)
    }
    # `which.max()` takes the first maximum, so blocks of equal length resolve
    # to the earlier table row -- the tie-break `build_prefix_index()` states.
    rows[hit][[which.max(len[hit])]]
  }, integer(1))
}
