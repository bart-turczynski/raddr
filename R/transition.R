# The transition-prefix overlay.
# See docs/architecture.md sections 7, 7.2 and 8.1.
#
# Separately stamped from the IANA table, and deliberately not vendored: there
# is no upstream file to fetch. This is hand-authored from the RFCs, so it
# follows R/codes.R's const-registry shape rather than the build-script shape
# the IANA registries use, and it carries its own version.
#
# It exists because IANA's table stops short. IANA marks Teredo and 6to4 `N/A`
# for Globally Reachable (section 7.1) precisely because the answer follows the
# EMBEDDED IPv4 address, which a prefix table cannot express. The overlay says
# where those embedded bits are; extracting and classifying them is Epic J.

#' The overlay's own version stamp
#'
#' Independent of [addr_registry_version()]. The IANA snapshot and this table
#' change for unrelated reasons -- one when IANA republishes, the other when a
#' maintainer transcribes another RFC -- so one stamp must not be read as
#' evidence about the other.
#'
#' @noRd
raddr_transition_version <- "2026-07-27"

# A row-major literal, so the registry reads as a table in the source too.
transition_prefix_row <- function(block, kind, rfc, note = "") {
  list(block = block, kind = kind, rfc = rfc, note = note)
}

raddr_transition_prefixes <- local({
  rows <- list(
    # --- IPv4-in-IPv6 forms, RFC 4291 ---------------------------------------
    transition_prefix_row(
      "::ffff:0:0/96", "ipv4_mapped", "RFC 4291 section 2.5.5.2",
      "raddr gives this form its own family, v6_4in6 (section 5.1)."
    ),
    transition_prefix_row(
      "::/96", "ipv4_compatible", "RFC 4291 section 2.5.5.1",
      paste(
        "Deprecated. Only the tail above 1 is an embedded address:",
        ":: is the unspecified address and ::1 is loopback, and reading",
        "either as an embedded 0.0.0.0 or 0.0.0.1 misclassifies both."
      )
    ),
    transition_prefix_row(
      "::ffff:0:0:0/96", "ipv4_translated", "none",
      "No RFC assigns this. Carried because the in-house guards recognize it."
    ),
    # --- 6to4 and Teredo ----------------------------------------------------
    transition_prefix_row(
      "2002::/16", "6to4", "RFC 3056 section 2",
      "IANA records Globally Reachable as N/A here; the embedded v4 decides."
    ),
    transition_prefix_row(
      "2001::/32", "teredo", "RFC 4380 section 4",
      paste(
        "Two embedded addresses, not one: the server in the clear and the",
        "client bitwise-complemented. IANA records N/A here too."
      )
    ),
    transition_prefix_row(
      "192.88.99.0/24", "6to4_relay_anycast", "RFC 3068 section 2.3",
      "IPv4, and classify-only: it embeds nothing. Deprecated by RFC 7526."
    ),
    # --- NAT64, RFC 6052 ----------------------------------------------------
    transition_prefix_row(
      "64:ff9b::/96", "nat64_wk", "RFC 6052 section 2.1",
      "The well-known prefix. Only ever used at /96."
    ),
    transition_prefix_row(
      "64:ff9b:1::/48", "nat64_local", "RFC 8215 section 3",
      "Local-use, and u-byte-aware: at /48 the embedded v4 is not contiguous."
    )
  )

  out <- do.call(rbind.data.frame, c(rows, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
})

# --- where the embedded IPv4 bits live --------------------------------------

# One row per contiguous SEGMENT of an embedded IPv4 address. Most forms need a
# single segment; RFC 6052 at /40, /48 and /56 needs two, because the embedded
# address straddles the reserved u-byte at bits 64-71.
#
# `prefix_len` is `NA` except for NAT64, where the geometry is a function of the
# prefix length rather than of a fixed prefix -- a network-specific NAT64 prefix
# can be any prefix of the six permitted lengths, so it cannot be listed above.
#
# `complement` marks a field stored as its bitwise complement. Teredo's client
# address is obfuscated that way (RFC 4380 section 4) so that a NAT does not
# rewrite it in transit.
transition_embedding_row <- function(kind, role, prefix_len, offset, length,
                                     complement = FALSE) {
  list(
    kind = kind, role = role, prefix_len = prefix_len,
    offset = offset, length = length, complement = complement
  )
}

raddr_transition_embeddings <- local({
  rows <- list(
    transition_embedding_row("ipv4_mapped", "embedded", NA_integer_, 96L, 32L),
    transition_embedding_row(
      "ipv4_compatible", "embedded", NA_integer_, 96L, 32L
    ),
    transition_embedding_row(
      "ipv4_translated", "embedded", NA_integer_, 96L, 32L
    ),
    transition_embedding_row("6to4", "embedded", NA_integer_, 16L, 32L),

    # RFC 4380 section 4: server in the clear at 32, client complemented at 96.
    transition_embedding_row("teredo", "server", NA_integer_, 32L, 32L),
    transition_embedding_row(
      "teredo", "client", NA_integer_, 96L, 32L,
      complement = TRUE
    ),

    # RFC 5214 section 6.1. Not a prefix at all -- an interface-identifier
    # pattern that can sit under any /64, which is why ISATAP has an embedding
    # but no row in the prefix table. The pattern itself is `isatap_iid` below.
    transition_embedding_row("isatap", "embedded", NA_integer_, 96L, 32L),

    # RFC 6052 section 2.2, all six permitted prefix lengths. The u-byte at
    # bits 64-71 is reserved and is skipped, so four of the six are split.
    transition_embedding_row("nat64", "embedded", 32L, 32L, 32L),
    transition_embedding_row("nat64", "embedded", 40L, 40L, 24L),
    transition_embedding_row("nat64", "embedded", 40L, 72L, 8L),
    transition_embedding_row("nat64", "embedded", 48L, 48L, 16L),
    transition_embedding_row("nat64", "embedded", 48L, 72L, 16L),
    transition_embedding_row("nat64", "embedded", 56L, 56L, 8L),
    transition_embedding_row("nat64", "embedded", 56L, 72L, 24L),
    transition_embedding_row("nat64", "embedded", 64L, 72L, 32L),
    transition_embedding_row("nat64", "embedded", 96L, 96L, 32L)
  )

  out <- do.call(rbind.data.frame, c(rows, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
})

# The reserved u-byte, RFC 6052 section 2.2. No embedded segment may overlap it.
nat64_u_byte <- c(offset = 64L, length = 8L)

# RFC 5214 section 6.1: the interface identifier is `0000:5efe` or `0200:5efe`
# -- the second form when the address is built from a globally unique IPv4 --
# followed by the 32 embedded bits. Bits 64-95, given as mask and the two
# permitted values, so a matcher compares rather than re-derives.
isatap_iid <- list(
  offset = 64L,
  length = 32L,
  # Raw signed bit patterns, as everywhere else in raddr (section 5.1.1). The
  # mask clears the single bit that separates the two permitted forms, and is
  # spelled as bitwNot() rather than as 0xfdffffff -- that literal is a double
  # above 2^31, and bitwAnd() silently returns NA for it.
  mask = bitwNot(0x02000000L),
  value = 0x00005efeL,
  permitted = c(0x00005efeL, 0x02005efeL)
)

#' The transition-prefix overlay
#'
#' The prefixes whose classification needs more granularity than the IANA
#' special-purpose registries provide, and the bit geometry of the IPv4
#' addresses embedded in them.
#'
#' @section Why an overlay exists at all:
#'
#' IANA records `Globally Reachable` as `N/A` for Teredo (`2001::/32`) and 6to4
#' (`2002::/16`) -- see [addr_registry()]. That is not an omission: reachability
#' follows the **embedded** IPv4 address, which no prefix table can express.
#' IANA is marking the point where table lookup stops being sufficient, and this
#' overlay is what raddr uses past that point.
#'
#' @section Separately stamped:
#'
#' This table has its own version, independent of
#' [addr_registry_version()]. The two change for unrelated reasons -- one when
#' IANA republishes, the other when a maintainer transcribes another RFC -- so
#' neither stamp is evidence about the other. There is no
#' `addr_transition_outdated()`: the RFCs this is drawn from do not expire.
#'
#' @section Prefixes and embeddings are different shapes:
#'
#' `what = "prefixes"` gives fixed prefixes with a `kind`. `what = "embeddings"`
#' gives one row per **contiguous segment** of an embedded IPv4 address, which
#' is not always one row per form:
#'
#' \describe{
#'   \item{Teredo carries two addresses}{a server, in the clear, and a client
#'     stored bitwise-complemented so a NAT will not rewrite it
#'     (`complement = TRUE`).}
#'   \item{NAT64 geometry follows the prefix length, not a prefix}{RFC 6052
#'     permits six lengths, and a network-specific prefix may be any prefix of
#'     one of them -- so those rows carry a `prefix_len` and no block. At /40,
#'     /48 and /56 the embedded address **straddles the reserved u-byte** at
#'     bits 64-71 and arrives in two segments, most significant first.}
#'   \item{ISATAP has an embedding but no prefix}{it is an interface-identifier
#'     pattern (`0000:5efe` or `0200:5efe`) that can sit under any `/64`.}
#' }
#'
#' @param what Which table to return: `"prefixes"` (default) or `"embeddings"`.
#'
#' @return A data frame. For `"prefixes"`: `block`, `kind`, `rfc`, `note`. For
#'   `"embeddings"`: `kind`, `role`, `prefix_len`, `offset`, `length`,
#'   `complement`, where `offset` and `length` are bit positions counted from
#'   the most significant bit of the 128-bit address.
#'
#' @seealso [addr_registry()] for the IANA table this overlays.
#'
#' @examples
#' addr_transition_registry()
#'
#' # The two forms IANA declines to answer for
#' reg <- addr_registry()
#' reg[is.na(reg$globally_reachable) & is.na(reg$termination_date), "block"]
#'
#' # RFC 6052's split geometry: two segments at /40, /48 and /56
#' emb <- addr_transition_registry("embeddings")
#' emb[emb$kind == "nat64", c("prefix_len", "offset", "length")]
#'
#' @export
addr_transition_registry <- function(what = c("prefixes", "embeddings")) {
  what <- match.arg(what)
  switch(
    what,
    prefixes = raddr_transition_prefixes,
    embeddings = raddr_transition_embeddings
  )
}

#' @rdname addr_transition_registry
#' @export
addr_transition_version <- function() {
  raddr_transition_version
}
