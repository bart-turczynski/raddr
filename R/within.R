# Containment: is this address inside that block? See docs/architecture.md
# section 6.3.
#
# The matcher is the one in R/classify.R turned inside out. `prefix_match()`
# walks a table of blocks in descending prefix-length order and keeps the first
# hit, because it has to answer *which* block -- longest-prefix-match over the
# IANA registry. A denylist asks a smaller question, "any at all", and pays for
# the walk anyway: 200 blocks is 200 passes over the address vector.
#
# So the blocks are grouped by prefix length instead. Every block of the same
# length reduces its addresses to the same key -- the top `len` bits -- and
# membership in the group is one hash lookup. The number of passes stops being
# the number of blocks and becomes the number of *distinct lengths*, which for
# IPv4 can never exceed 32 however long the list is. See section 11.1.5 for what
# that is worth measured.
#
# Same constraint as R/classify.R and for the same reason: no `bitwAnd`
# anywhere. Section 5.1.1 makes a word a raw bit pattern in which `NA_integer_`
# is 0x80000000, so bitwise operators read that word as missing and cannot spell
# a /1 mask at all. Keys are integer division of unsigned doubles.

# One parsed block list: the space it lives in, its prefix length, and the four
# words of its base address. `blocks` is text, because raddr has no prefix type
# -- section 6.6 is about the function-name prefix, and a `raddr_prefix` is not
# in v0.1.
#
# Everything here errors rather than returning NA, which is the opposite of what
# the decoders in R/encoding.R do, and deliberately. A block is not data being
# read, it is the *question being asked*: a denylist entry that silently matches
# nothing is a hole in the denylist, and the caller has no way to notice. A
# missing address is still a missing answer -- that part is unchanged.
parse_within_blocks <- function(blocks, arg = "blocks") {
  if (is.factor(blocks)) {
    blocks <- as.character(blocks)
  }
  if (!is.character(blocks)) {
    abort(
      sprintf(
        "`%s` must be a character vector of CIDR blocks, not %s.",
        arg, class(blocks)[[1L]]
      ),
      class = "raddr_error_type"
    )
  }

  blocks <- trimws(blocks)
  if (anyNA(blocks)) {
    abort(
      c(
        sprintf("`%s` must not contain missing values.", arg),
        i = "A block is the question being asked, so it cannot be unknown."
      ),
      class = "raddr_error_block"
    )
  }

  at <- regexpr("/", blocks, fixed = TRUE)
  if (any(at == -1L)) {
    bad <- blocks[[which(at == -1L)[[1L]]]]
    abort(
      c(
        sprintf("`%s` needs a prefix length on every block.", arg),
        x = sprintf('"%s" has none.', bad),
        i = "A single address is a host route: write `/32` or `/128`."
      ),
      class = "raddr_error_block"
    )
  }

  text <- substr(blocks, 1L, at - 1L)
  # `addr_strict()`, not `addr_pton()`, and the difference matters exactly here.
  # A block is a *specification*, so it has to mean one thing everywhere:
  # `addr_pton()` models Apple libc, which strips leading zeros, so it reads
  # "010.0.0.0/8" as 10.0.0.0/8 while glibc's `inet_pton()` rejects the same
  # text (section 3.2). A denylist entry that means different blocks on
  # different machines is worse than one that is refused. `addr_strict()` is the
  # RFC grammar -- what Python, Go and Rust accept -- and it is where CIDR text
  # is written in the first place.
  base <- addr_strict(text)
  if (anyNA(base)) {
    bad <- blocks[[which(is.na(base))[[1L]]]]
    abort(
      c(
        sprintf("`%s` contains a block whose address does not parse.", arg),
        x = sprintf('"%s".', bad),
        i = paste(
          "Blocks are read by the RFC grammar, as `addr_strict()` reads an",
          "address: no leading zeros, no octal, no short form."
        )
      ),
      class = "raddr_error_block"
    )
  }

  family <- field(base, "family")
  space <- ifelse(family == "v4", "v4", "v6")
  width <- ifelse(space == "v4", 32L, 128L)

  len_text <- substring(blocks, at + 1L)
  len <- suppressWarnings(as.integer(len_text))
  bad_len <- is.na(len) | len < 0L | len > width |
    !grepl("^[0-9]+$", len_text)
  if (any(bad_len)) {
    i <- which(bad_len)[[1L]]
    abort(
      c(
        sprintf("`%s` contains a prefix length that is not one.", arg),
        x = sprintf('"%s".', blocks[[i]]),
        i = sprintf(
          "An %s prefix length is 0 to %d.",
          if (space[[i]] == "v4") "IPv4" else "IPv6", width[[i]]
        )
      ),
      class = "raddr_error_block"
    )
  }

  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(field(base, nm))
  )

  # Host bits set is refused rather than masked away. `192.168.1.1/24` is either
  # a typo for the network or a host someone meant to write `/32`, and guessing
  # which is the kind of silent reinterpretation section 6.5.2 refuses for a
  # double above 2^53. Python's `ip_network()` refuses it too; the error names
  # the masked form so the fix is a copy and paste.
  masked <- mask_words(words, len, space)
  set <- rep(FALSE, length(len))
  for (k in seq_len(4L)) {
    set <- set | masked[[k]] != words[[k]]
  }
  if (any(set)) {
    i <- which(set)[[1L]]
    suggestion <- words_to_addr(
      lapply(masked, function(w) w[[i]]),
      if (space[[i]] == "v4") 32L else 128L
    )
    abort(
      c(
        sprintf("`%s` contains a block with host bits set.", arg),
        x = sprintf('"%s".', blocks[[i]]),
        i = sprintf(
          'Did you mean "%s/%d"?', addr_format(suggestion), len[[i]]
        )
      ),
      class = "raddr_error_block"
    )
  }

  list(space = space, len = len, words = words)
}

# The base address with everything below the prefix cleared, as unsigned
# doubles. Division and multiplication, never bitwShiftL: see the header.
#
# Vectorized over rows whose spaces differ, because a denylist holds both
# families at once. IPv4 lives in `w4` alone (section 5.1), so an IPv4 row's
# first three words are outside its prefix arithmetic entirely and are left
# alone -- `addr_pton()` has already made them zero.
mask_words <- function(words, len, space) {
  is_v4 <- space == "v4"
  out <- vector("list", 4L)
  for (k in seq_len(4L)) {
    bits <- pmin(pmax(len - 32L * (k - 1L), 0L), 32L)
    bits[is_v4] <- if (k == 4L) pmin(pmax(len[is_v4], 0L), 32L) else 32L
    divisor <- 2^(32 - bits)
    out[[k]] <- (words[[k]] %/% divisor) * divisor
  }
  out
}

# The blocks regrouped for matching: one entry per (space, prefix length), each
# carrying the word/divisor plan those blocks share and the target keys of every
# block that has that length.
within_index <- function(parsed) {
  key <- paste(parsed$space, parsed$len)
  groups <- split(seq_along(key), key)

  lapply(unname(groups), function(rows) {
    space <- parsed$space[[rows[[1L]]]]
    len <- parsed$len[[rows[[1L]]]]
    plan <- prefix_word_plan(len, space)
    targets <- lapply(plan, function(step) {
      parsed$words[[step$word]][rows] %/% step$divisor
    })
    list(space = space, plan = plan, targets = targets, rows = rows)
  })
}

# The key columns for every address under one group's plan, as a list of
# doubles. `sel` restricts the work to the addresses still in play.
within_keys <- function(words, plan, sel) {
  lapply(plan, function(step) words[[step$word]][sel] %/% step$divisor)
}

# Whether each key row appears among the target rows. One column is the common
# case and the fast one -- every IPv4 plan has exactly one word, whatever the
# prefix length -- so it skips the data frame entirely.
keys_in_targets <- function(keys, targets) {
  if (!length(keys)) {
    # A /0 covers its whole space and has no words to compare.
    return(TRUE)
  }
  if (length(keys) == 1L) {
    return(match(keys[[1L]], targets[[1L]], nomatch = 0L) > 0L)
  }
  names(keys) <- paste0("k", seq_along(keys))
  names(targets) <- paste0("k", seq_along(targets))
  vec_in(new_data_frame(keys), new_data_frame(targets))
}

# The address words as unsigned doubles, plus the space each address searches.
within_addresses <- function(x) {
  family <- field(x, "family")
  known <- !is.na(family)
  list(
    n = length(family),
    known = known,
    # v6 and v6_4in6 both search the IPv6 half, exactly as in `prefix_match()`:
    # `::ffff:127.0.0.1` is an IPv6 address in `::ffff:0:0/96`, and that its
    # embedded address is loopback is a separate fact reported by `embeddings`.
    is_v4 = known & family == "v4",
    words = lapply(
      c("w1", "w2", "w3", "w4"),
      function(nm) widen_word(field(x, nm))
    )
  )
}

#' Is an address inside a block?
#'
#' `addr_within()` tests each address against the block in the same position;
#' `addr_within_any()` tests each address against **every** block and answers
#' whether any of them contains it. The second is the denylist question.
#'
#' @section The family decides the space, and 4-in-6 is IPv6:
#'
#' An IPv4 address is never inside an IPv6 block and an IPv6 address is never
#' inside an IPv4 one, so those pairs are `FALSE` rather than an error -- a
#' mixed denylist is an ordinary thing to hold. A `v6_4in6` address such as
#' `::ffff:192.0.2.1` searches the **IPv6** space: it is inside
#' `::ffff:0:0/96` and it is *not* inside `192.0.2.0/24`, because it is a
#' 128-bit address that happens to embed an IPv4 one. That embedding is a
#' separate fact, reported by [addr_embeddings()]; testing the address it
#' contains means naming that address. This is the width rule of
#' [addr_to_bytes()] in its containment form.
#'
#' @section A block is the question, so a bad block is an error:
#'
#' The decoders elsewhere in raddr return a missing value for input they cannot
#' read. Blocks are the exception, because a block is not data being read -- it
#' is the question being asked. A denylist entry that silently matched nothing
#' would be a hole in the denylist that the caller has no way to see. So a
#' malformed block, a missing one, a prefix length outside `0:32` or `0:128`,
#' and a block with **host bits set** all error, and the message names the fix.
#'
#' `192.168.1.1/24` is refused rather than masked to `192.168.1.0/24`, because
#' it is equally likely to be a host someone meant to write `/32`. A missing
#' *address* is still a missing answer: `NA`, never `FALSE`.
#'
#' @param x A `raddr_address` vector.
#' @param blocks A character vector of CIDR blocks, `"10.0.0.0/8"` or
#'   `"2001:db8::/32"`. The address part is read by the RFC grammar, as
#'   [addr_strict()] reads one, so that a block means the same thing on every
#'   platform. For `addr_within()` it is recycled against `x`.
#'
#' @return A logical vector the length of `x`, `NA` where the address is
#'   missing.
#'
#' @seealso [addr_classify()] for what the IANA registry says about an address,
#'   which is the question to ask when the blocks would have come from there.
#'
#' @examples
#' a <- addr_pton(c("10.1.2.3", "192.0.2.1", "2001:db8::1", "::ffff:10.0.0.1"))
#'
#' addr_within_any(a, c("10.0.0.0/8", "2001:db8::/32"))
#'
#' # Recycled, one block per address
#' addr_within(a, "10.0.0.0/8")
#'
#' # A 4-in-6 address is an IPv6 address: it is in the mapped block and not in
#' # the IPv4 block whose address it embeds
#' addr_within_any(addr_pton("::ffff:10.0.0.1"), "10.0.0.0/8")
#' addr_within_any(addr_pton("::ffff:10.0.0.1"), "::ffff:0:0/96")
#'
#' # A /0 covers its own space and nothing else
#' addr_within_any(a, "0.0.0.0/0")
#'
#' @export
addr_within_any <- function(x, blocks) {
  check_raddr_address(x)
  parsed <- parse_within_blocks(blocks)
  addr <- within_addresses(x)

  out <- rep(NA, addr$n)
  if (addr$n == 0L || !length(parsed$len)) {
    out[addr$known] <- FALSE
    return(out)
  }
  out[addr$known] <- FALSE

  in_space <- list(v4 = addr$is_v4, v6 = addr$known & !addr$is_v4)
  for (group in within_index(parsed)) {
    # Only addresses in the right space, and only those not already matched:
    # "any" is done with an address the moment one block contains it.
    sel <- in_space[[group$space]] & !(out %in% TRUE)
    if (!any(sel)) {
      next
    }
    hit <- keys_in_targets(
      within_keys(addr$words, group$plan, sel),
      group$targets
    )
    out[sel] <- out[sel] | hit
  }

  out
}

#' @rdname addr_within_any
#' @export
addr_within <- function(x, blocks) {
  check_raddr_address(x)
  parsed <- parse_within_blocks(blocks)

  # The address and its block are two vectors of the same thing, so they
  # recycle against each other the way any pair of vctrs arguments does. The
  # indices are recycled rather than the values, so neither side is copied.
  recycled <- vec_recycle_common(
    x = seq_along(x),
    blocks = seq_along(parsed$len)
  )
  xi <- recycled$x
  bi <- recycled$blocks

  addr <- within_addresses(x)
  out <- rep(NA, length(xi))
  if (!length(xi)) {
    return(out)
  }
  out[addr$known[xi]] <- FALSE
  addr_space <- ifelse(addr$is_v4, "v4", "v6")

  # One pass per distinct block, which is one pass in total for the common call
  # of many addresses against a single block.
  for (row in unique(bi)) {
    at <- bi == row
    # An address of the other family is FALSE, not an error: see @section.
    sel <- at & addr$known[xi] & addr_space[xi] == parsed$space[[row]]
    if (!any(sel)) {
      next
    }
    plan <- prefix_word_plan(parsed$len[[row]], parsed$space[[row]])
    targets <- lapply(plan, function(step) {
      parsed$words[[step$word]][[row]] %/% step$divisor
    })
    out[sel] <- keys_in_targets(
      within_keys(addr$words, plan, xi[sel]),
      targets
    )
  }

  out
}
