# The raddr_embedding type. See docs/architecture.md section 5.3.5.
#
# `embeddings` is PLURAL BY CONSTRUCTION, and Teredo is why. RFC 4380 section 4
# puts two IPv4 addresses in one Teredo address -- the server in the clear at
# bits 32-63, and the client bitwise-complemented at bits 96-127 -- and both are
# destinations, not one address plus metadata. Section 5.2.6 directs a host to
# extract the SERVER address from a peer's address and send a UDP bubble to it.
#
# A scalar field cannot say that. `embedded_scope` was removed for exactly this
# reason: reducing two embedded addresses to one IS the Teredo decision, and
# raddr does not make it (P8). The same objection killed the field twice --
# first in a name (`effective_scope` asserts one of three true fields is the
# real one), then in a cardinality.
#
# EXTRACTION IS EPIC J, and it is below. The type was settled first so that
# filling `embeddings` would not also re-version the record, and it did not:
# `kind`, `role`, `address` and `category` are the four fields the extractor
# writes, unchanged.

# `embedded` for the forms that carry one address; `server` and `client` for
# Teredo, in RFC 4380 section 4's order. Not a ranking -- raddr reports both and
# says which field each came from, which is the fact the RFC states.
raddr_embedding_roles <- c("embedded", "server", "client")

new_raddr_embedding <- function(kind = factor(levels = raddr_embedded_kinds),
                                role = factor(levels = raddr_embedding_roles),
                                address = raddr_address(),
                                category = factor(
                                  levels = raddr_category_levels
                                )) {
  new_rcrd(
    list(kind = kind, role = role, address = address, category = category),
    class = "raddr_embedding"
  )
}

# The empty value, and the `list_of` prototype every `embeddings` column is
# built against. One ptype across the whole vector is what keeps the outer
# record `vctrs` size-stable (section 5.3.5): rows multiply only when a caller
# explicitly unnests.
empty_raddr_embedding <- function() {
  new_raddr_embedding()
}

#' Test whether an object is a `raddr_embedding`
#'
#' The elements of the `embeddings` column of a [addr_classify()] result. There
#' is no public constructor: these are produced by classification, not built by
#' hand.
#'
#' @param x An object.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_raddr_embedding(addr_embeddings(addr_pton("64:ff9b::a9fe:a9fe"))[[1]])
#' is_raddr_embedding("169.254.169.254")
#'
#' @export
is_raddr_embedding <- function(x) {
  inherits(x, "raddr_embedding")
}

# `kind/role`, then the address, then what that address classifies as. The kind
# repeats the outer record's `embedded_kind`, and it is here anyway because
# Teredo's two rows share a kind and differ only in role -- reading a row on its
# own should not need the record it came out of.
#' @export
format.raddr_embedding <- function(x, ...) {
  n <- vec_size(x)
  if (n == 0L) {
    return(character())
  }
  sprintf(
    "%s/%s %s %s",
    as.character(field(x, "kind")),
    as.character(field(x, "role")),
    addr_format(field(x, "address")),
    as.character(field(x, "category"))
  )
}

#' @export
obj_print_data.raddr_embedding <- function(x, ...) {
  if (vec_size(x) == 0L) {
    return(invisible(x))
  }
  print(format(x), quote = FALSE)
  invisible(x)
}

#' @export
as.character.raddr_embedding <- function(x, ...) {
  format(x, ...)
}

#' @export
vec_ptype_abbr.raddr_embedding <- function(x, ...) {
  "embed"
}

#' @export
vec_ptype_full.raddr_embedding <- function(x, ...) {
  "raddr_embedding"
}

# --- reading the bits (section 8.1) ------------------------------------------
#
# Every offset and length the extractor uses comes from
# `addr_transition_registry("embeddings")`. Nothing below spells a bit position:
# the geometry is data, and this is the machine that reads it.
#
# --- and again, no bitwise operator ------------------------------------------
#
# R/classify.R's header applies here word for word, and harder. A field is read
# by shifting and masking, which is `bitwShiftR()` and `bitwAnd()` in any other
# language -- and both are unusable on a word that may hold `0x80000000`, which
# R stores as `NA_integer_` (section 5.1.1). Teredo makes that concrete rather
# than theoretical: the client field is stored complemented, so a client at
# `127.255.255.255` is `0x80000000` on the wire, and `2001::7f00:0:0` is an
# address a bitwise extractor reads as missing.
#
# So the words are widened to unsigned doubles and the field is read with
# integer division and modulo. Doubles are exact to 2^53 and every intermediate
# here is below 2^32, so the arithmetic is exact.

# The value of bits [offset, offset + len) of each address selected by `at`,
# most significant bit of the 128-bit address being bit 0.
#
# A field may straddle a word boundary -- 6to4's V4ADDR is bits 16-47 and
# RFC 6052's /64 segment is bits 72-103 -- so this walks the words the field
# touches, most significant first, and accumulates.
read_bits <- function(words, offset, len, at) {
  first <- offset %/% 32L
  last <- (offset + len - 1L) %/% 32L

  value <- numeric(length(at))
  for (w in first:last) {
    lo <- max(offset, 32L * w)
    hi <- min(offset + len, 32L * (w + 1L))
    # Drop the bits below the field, then the bits above it. Never
    # bitwShiftR()/bitwAnd(): see the header.
    part <- (words[[w + 1L]][at] %/% 2^(32L * (w + 1L) - hi)) %% 2^(hi - lo)
    value <- value * 2^(hi - lo) + part
  }
  value
}

# The geometry rows for one `embedded_kind`, in table order.
#
# Two lookups rather than one, because a mechanism and its geometry are not the
# same thing (section 5.3.7). `transition_geometry_kind` maps the mechanism to
# the geometry it reads, which is many-to-one: `nat64_wk` and `nat64_local` both
# read the `nat64` rows.
#
# And the NAT64 rows are keyed on PREFIX LENGTH rather than on a prefix, because
# RFC 6052 section 2.2 permits six lengths and a network-specific prefix may be
# any prefix of one of them. The length of the two prefixes raddr can name is
# already in their blocks -- `64:ff9b::/96` and `64:ff9b:1::/48` -- so it is
# derived from there rather than transcribed a second time (P9).
embedding_geometry <- function(kind) {
  rows <- raddr_transition_embeddings[
    raddr_transition_embeddings$kind == transition_geometry_kind[[kind]], ,
    drop = FALSE
  ]

  keyed <- !is.na(rows$prefix_len)
  if (any(keyed)) {
    # Half a geometry keyed on length and half on a prefix would silently read
    # two lengths at once.
    stopifnot(all(keyed))
    block <- raddr_transition_prefixes$block[
      raddr_transition_prefixes$kind == kind
    ]
    len <- as.integer(sub(".*/", "", block))
    rows <- rows[rows$prefix_len == len, , drop = FALSE]
  }

  rows
}

# The 32 bits one role of one mechanism embeds, as an unsigned double.
#
# A role is one or more SEGMENTS, most significant first, and joining them is
# the RFC 6052 section 2.2 u-byte case: at /40, /48 and /56 the embedded address
# is interrupted by the reserved octet at bits 64-71, so the octets are not
# contiguous and reading 32 bits from the prefix boundary yields a plausible
# wrong address -- under a /48 prefix `192.0.2.33` reads as `192.0.0.2`.
#
# The complement is applied to the assembled address rather than per segment.
# RFC 4380 section 4 complements Teredo's client address as one 32-bit field,
# and it is the only complemented address in the table.
read_embedded <- function(words, segments, at) {
  value <- numeric(length(at))
  for (i in seq_len(nrow(segments))) {
    len <- segments$length[[i]]
    value <- value * 2^len + read_bits(words, segments$offset[[i]], len, at)
  }

  if (any(segments$complement)) {
    stopifnot(all(segments$complement))
    value <- 4294967295 - value
  }

  value
}
