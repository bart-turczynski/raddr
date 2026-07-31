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

new_raddr_embedding <- function(kind = factor(levels = raddr_embedding_kinds),
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

# --- the extractor (sections 5.3.5 and 8.1) ----------------------------------
#
# One element per address, holding zero, one or two rows. The outer record stays
# `vctrs` size-stable: rows multiply only when a caller unnests.
#
# TWO ROWS IS TEREDO AND ONLY TEREDO, and they are not a ranking. RFC 4380
# section 4 puts the server in the clear at bits 32-63 and the client
# complemented at bits 96-127, and section 5.2.6 makes the server a destination
# a host actually sends a UDP bubble to -- so neither is metadata for the other.
# They are reported in the overlay's order, server then client, which is the
# RFC's, and raddr does not choose between them (P8).
#
# `category` is the classification of the EXTRACTED address, not of the outer
# one, so filling it is one level of `addr_classify()` on what came out. That
# recursion is one level deep by construction rather than by a depth guard: an
# extracted address is IPv4, the only IPv4 row in the overlay is
# `192.88.99.0/24`, and that prefix has no geometry (section 5.3.7) -- so the
# inner call finds no kind, extracts nothing, and stops.
#
# Returns the column and, separately, whether each role's extracted address is
# global. The three MUST rules of section 5.2.2 are stated about the embedded
# address rather than the outer one, so the code layer needs an answer the
# `raddr_embedding` record does not carry -- see `global_reachability()`.
extract_embeddings <- function(x, kind) {
  n <- vec_size(x)
  empty <- empty_raddr_embedding()
  # Kept as a plain list as well as a `list_of`, because the scatter at the end
  # of the function writes into it rather than rebuilding it.
  slots <- rep(list(empty), n)
  out <- list(
    embeddings = new_list_of(slots, ptype = empty),
    global = stats::setNames(
      rep(list(rep(NA, n)), length(raddr_embedding_roles)),
      raddr_embedding_roles
    )
  )

  kind <- as.character(kind)
  mechanisms <- unique(kind[!is.na(kind)])
  if (length(mechanisms) == 0L) {
    return(out)
  }

  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(field(x, nm))
  )

  # One block per (mechanism, role), each covering every address of that
  # mechanism at once. `rank` is the role's position in the geometry table, and
  # it is what puts an element's rows in the RFC's order once they are sorted.
  blocks <- list()
  for (mechanism in mechanisms) {
    at <- which(!is.na(kind) & kind == mechanism)
    geometry <- embedding_geometry(mechanism)
    roles <- unique(geometry$role)

    for (rank in seq_along(roles)) {
      segments <- geometry[geometry$role == roles[[rank]], , drop = FALSE]
      blocks[[length(blocks) + 1L]] <- list(
        at = at,
        kind = mechanism,
        role = roles[[rank]],
        rank = rank,
        w4 = narrow_word(read_embedded(words, segments, at))
      )
    }
  }

  sizes <- vapply(blocks, function(block) length(block$at), integer(1L))
  column <- function(name, ptype) {
    rep(vapply(blocks, `[[`, ptype, name), sizes)
  }
  at <- unlist(lapply(blocks, `[[`, "at"), use.names = FALSE)
  w4 <- unlist(lapply(blocks, `[[`, "w4"), use.names = FALSE)
  order_in_element <- order(at, column("rank", integer(1L)))

  at <- at[order_in_element]
  address <- new_raddr_address(
    w1 = rep(0L, length(at)),
    w2 = rep(0L, length(at)),
    w3 = rep(0L, length(at)),
    w4 = w4[order_in_element],
    family = factor(rep("v4", length(at)), levels = addr_families),
    zone = rep(NA_character_, length(at))
  )
  role <- column("role", character(1L))[order_in_element]

  inner <- addr_classify(address)
  rows <- new_raddr_embedding(
    kind = factor(
      column("kind", character(1L))[order_in_element],
      levels = raddr_embedding_kinds
    ),
    role = factor(role, levels = raddr_embedding_roles),
    address = address,
    category = field(inner, "category")
  )

  # Back into one element per outer address, with the rows that extracted
  # nothing keeping the shared empty `slots` already holds.
  #
  # `vec_chop()` is asked ONLY for the groups that have rows. It used to be
  # given a `split()` over a factor whose levels were `seq_len(n)` -- a level
  # per address, present or absent -- which asks `vctrs` for `n` slices of a
  # nested record and pays a `vec_proxy()` round-trip for every one of them, to
  # deliver as few as nineteen. That cost 11.7 s per 1e6 addresses and was 84%
  # of `addr_classify()` on IPv6, against 0.4 s for the prefix lookups §11.1.6
  # exists to tune. Worse than slow, it was *flat in the number of embeddings
  # and linear in `n`* -- 11.1 s for 19 embedded rows and 12.2 s for 240,172 --
  # so no wall clock could show it and only the decomposition in §11.1.7 did.
  #
  # `split()` on an integer vector groups by `as.factor()`, whose levels are
  # `sort(unique())`, so the groups arrive in ascending position order and
  # `sort(unique(at))` names them. `at` happens to be ascending already, from
  # `order_in_element` above, but spelling the sort makes the scatter correct
  # whether or not it is -- the alternative reads the positions back out of
  # `names()`, which is a round-trip through character.
  groups <- unname(split(seq_along(at), at))
  slots[sort(unique(at))] <- vec_chop(rows, indices = groups)
  out$embeddings <- new_list_of(slots, ptype = empty)

  global <- global_reachability(inner)
  for (name in unique(role)) {
    out$global[[name]][at[role == name]] <- global[role == name]
  }

  out
}

# Whether an address is in globally reachable space. Written for the EXTRACTED
# address, because that is the antecedent of all three of the MUST rules in
# section 5.2.2, and it is worded three ways:
#
#   RFC 6052 section 3.1  "non-global IPv4 addresses, such as those defined in
#                          [RFC1918] or listed in Section 3 of [RFC5735]"
#   RFC 3056 section 9    "not in the format of a global unicast address"
#   RFC 4380 section 4    "a global scope unicast IPv4 address"
#
# One predicate serves all three, because over IPv4 the three sets coincide.
# RFC 5735 section 3 enumerates the special-use blocks, and RFC 3056 section 9
# names "[RFC1918], broadcast, subnet broadcast, multicast and loopback" --
# every one of which is in that enumeration.
#
# IT RETURNS THREE VALUES, AND THE THIRD IS THE POINT. Each layer answers the
# question in its own terms, and neither silence may be read as an answer:
#
#   - where the SPECIAL-PURPOSE layer answered, the answer is IANA's own
#     `globally_reachable` column, unmodified. That is what keeps the five
#     blocks IANA marks globally reachable -- PCP and TURN anycast, AS112 twice,
#     AMT -- out of a MUST-drop they do not deserve.
#   - where the ADDRESS-SPACE layer answered there is no policy column at all,
#     and the question that layer does answer is whether the space is delegated
#     to an RIR. That is `category = global`, the one level documented to mean
#     "an ordinary host may live here". Without it `8.8.8.8` reads as non-global
#     and `224.0.0.0/4` reads as nothing -- CVE-2025-8267's shape.
#
# Measured over all 256 IPv4 /8s [2026-07-27]: 220 answer `global` and 16
# `multicast` from the address-space layer, 25 of the 26 special-purpose rows
# state `globally_reachable`, and EXACTLY ONE block leaves the question open --
# `192.88.99.0/24`, which IANA withdrew and gave no policy at all. So `NA` here
# is not a hypothetical tier: it is the 6to4 image of the deprecated relay
# anycast address, `2002:c058:6301::`, and asserting a MUST-drop for it would
# be reading IANA's silence as a `FALSE` one level down. The rules fire on an
# affirmative `FALSE` and nowhere else.
#
# This is not the `category` deny-list section 5.3.3 forbids. It reads ONE
# positive level, only in the layer that has no other column, and a level added
# later changes no answer that layer gives today.
#
# NOTHING HERE IS SPECIFIC TO AN EXTRACTED ADDRESS. The rule reads two registry
# layers, and both cover IPv6 as well -- so the same body answers the question
# for an outer address, and `addr_global_reachability()` is that export. It was
# internal for as long as raddr was its own only consumer, and the argument for
# exporting it is that the alternative is worse: a policy layer that cannot
# reach this fact has to rebuild it from `category`, which is precisely the
# deny-list section 5.3.3 forbids, in the layer that can least afford it.
global_reachability <- function(class) {
  registry <- field(class, "registry")
  category <- field(class, "category")

  out <- field(class, "globally_reachable")
  from_space <- !is.na(registry) & registry == "address_space"
  out[from_space] <- category[from_space] == "global"
  out
}

# --- the caller-supplied NAT64 prefix (section 8.1) --------------------------
#
# The one extraction raddr cannot reach from the address, and the reason is not
# a gap in the table: RFC 6052 section 2.2 lets an operator embed IPv4 under any
# Network-Specific Prefix at any of six lengths, and nothing in the resulting
# address says which prefix -- or whether it is NAT64 at all. A prefix table can
# name the two FIXED prefixes and must stay silent about the rest, which is what
# `embedded_kind = NA` means and why section 5.3.7 says an `NA` there is not a
# clean bill of health.
#
# So the prefix arrives as an argument. That is the whole of the difference,
# and it is confined to this function: `addr_classify()` is untouched, and the
# row this returns carries `nat64_nsp` so a caller can never mistake a reading
# it configured for one raddr concluded.
#
# The geometry is the same table the fixed prefixes read, keyed on length, so
# the u-byte split at /40, /48 and /56 is handled here for free -- which is the
# point. That splice is the part a consumer would get wrong: at /48 a naive
# 32-bit read from the prefix boundary turns `192.0.2.33` into `192.0.0.2`.

# The prefix, validated as an RFC 6052 prefix specifically.
# `parse_within_blocks()` already refuses a malformed block, a non-CIDR and host
# bits set; what it cannot know is that only six lengths are permitted and that
# this one has to be IPv6.
nat64_prefix <- function(prefix, arg = "prefix") {
  if (!is.character(prefix) || length(prefix) != 1L) {
    abort(
      c(
        sprintf("`%s` must be a single CIDR block, as a string.", arg),
        i = paste(
          "One call reads one prefix. Two prefixes of different lengths are",
          "two different readings of the same address, so raddr does not",
          "merge them -- loop over the prefixes instead."
        )
      ),
      class = "raddr_error_type"
    )
  }

  parsed <- parse_within_blocks(prefix, arg = arg)
  if (parsed$space != "v6") {
    abort(
      c(
        sprintf("`%s` must be an IPv6 prefix.", arg),
        x = sprintf('"%s" is IPv4.', prefix),
        i = "A NAT64 prefix is the IPv6 side: RFC 6052 section 2.2."
      ),
      class = "raddr_error_block"
    )
  }

  len <- parsed$len
  if (!len %in% nat64_prefix_lengths) {
    abort(
      c(
        sprintf("`%s` is not a permitted NAT64 prefix length.", arg),
        x = sprintf('"%s" is a /%d.', prefix, len),
        i = sprintf(
          "RFC 6052 section 2.2 permits %s, and no others.",
          paste0("/", nat64_prefix_lengths, collapse = ", ")
        )
      ),
      class = "raddr_error_block"
    )
  }

  # At /96, and only at /96, the reserved u-byte at bits 64-71 lies INSIDE the
  # prefix -- so RFC 6052 section 2.2's "MUST be set to zero" is a statement
  # about the prefix itself, and a caller who configured one with those bits set
  # has configured a prefix the RFC forbids. At the five shorter lengths those
  # bits are in the suffix and belong to the address, which this function reads
  # rather than grades.
  if (len == 96L) {
    u_byte <- read_bits(
      parsed$words, nat64_u_byte[["offset"]], nat64_u_byte[["length"]], 1L
    )
    if (u_byte != 0) {
      abort(
        c(
          sprintf("`%s` has a non-zero reserved u-byte.", arg),
          x = sprintf('"%s" has bits 64-71 set to %d.', prefix, u_byte),
          i = paste(
            "RFC 6052 section 2.2 reserves those bits and says they MUST be",
            "set to zero. At /96 they are part of the prefix."
          )
        ),
        class = "raddr_error_block"
      )
    }
  }

  len
}

#' Read the IPv4 address a caller-supplied NAT64 prefix embeds
#'
#' [addr_classify()] names NAT64 only from the two prefixes that are written
#' down -- the RFC 6052 Well-Known Prefix `64:ff9b::/96` and the RFC 8215
#' local-use prefix `64:ff9b:1::/48`. A Network-Specific Prefix is invisible to
#' a prefix table, so raddr states a NAT64 kind only affirmatively and
#' `addr_embedded_kind()` returns `NA` under an operator's own prefix. This
#' function is the opt-in for a caller who knows the prefix and wants the
#' address read under it.
#'
#' @section The reading is yours, and it is labeled that way:
#'
#' Nothing in an IPv6 address says it is NAT64 under some prefix, so supplying
#' one is an assertion, not a discovery -- and a wrong assertion produces a
#' plausible wrong IPv4 address rather than an error. Every row this returns
#' therefore carries `kind = "nat64_nsp"`, a level [addr_classify()] can never
#' emit, so a configured reading stays distinguishable from one raddr reached
#' from the address alone.
#'
#' `addr_classify()` is unchanged by this call. There is no way to register a
#' prefix so that classification starts seeing it: that would make the same
#' address classify differently depending on state held elsewhere.
#'
#' @section The u-byte split is why this is not a one-liner:
#'
#' RFC 6052 section 2.2 reserves bits 64-71, so at `/40`, `/48` and `/56` the
#' embedded address is **not contiguous** -- it resumes after the reserved
#' octet, and reading 32 bits from the prefix boundary yields a wrong address
#' that looks right. Under a `/48`, `192.0.2.33` read that way comes back as
#' `192.0.0.2`. This function reads the segments from the same geometry table
#' the fixed prefixes use, published as
#' `addr_transition_registry("embeddings")`.
#'
#' @section No RFC 2119 rule attaches to the result:
#'
#' RFC 6052 section 3.1's MUST-drop is written about the Well-Known Prefix
#' alone: "translators MUST NOT translate packets in which an address is
#' composed of the Well-Known Prefix and a non-global IPv4 address". It states
#' no equivalent requirement for a Network-Specific Prefix, and RFC 8215
#' section 5 says in terms that it does not reach the local-use prefix either.
#' So no classify code is emitted here even when the embedded address is not
#' global -- see [addr_global_reachability()] for the fact, which is a fact and
#' not a permission.
#'
#' @param x A `raddr_address` vector.
#' @param prefix A single CIDR block, as a string: an IPv6 prefix at one of the
#'   six lengths RFC 6052 section 2.2 permits (`/32`, `/40`, `/48`, `/56`,
#'   `/64`, `/96`). One call reads one prefix.
#'
#' @return A `list_of<raddr_embedding>` the same length as `x`, shaped exactly
#'   as [addr_embeddings()] is: one row for each address that lies under
#'   `prefix`, and zero rows for each that does not.
#'
#' @seealso [addr_embeddings()] for the mechanisms raddr names on its own, and
#'   [addr_transition_registry()] for the geometry this reads.
#'
#' @examples
#' a <- addr_pton(c("2001:db8:122:344::c000:221", "2001:db8::1", "8.8.8.8"))
#'
#' # Under the operator's own /96: one reading, two addresses it does not cover
#' addr_nat64_embeddings(a, "2001:db8:122:344::/96")
#'
#' # Classification still says nothing about it, and that is not a disagreement
#' addr_embedded_kind(a)
#'
#' # RFC 6052 section 2.4's own worked example, at the /48 where the reserved
#' # u-byte splits the octets: both of these embed 192.0.2.33
#' under <- addr_pton(c("2001:db8:122:c000:2:2100::", "2001:db8:c000:221::"))
#' addr_nat64_embeddings(under[1], "2001:db8:122::/48")
#' addr_nat64_embeddings(under[2], "2001:db8::/32")
#'
#' @export
addr_nat64_embeddings <- function(x, prefix) {
  check_raddr_address(x)
  len <- nat64_prefix(prefix)

  n <- vec_size(x)
  empty <- empty_raddr_embedding()
  slots <- rep(list(empty), n)

  # `%in% TRUE` rather than `isTRUE`-per-element: `addr_within()` returns NA for
  # an address that is itself NA, and an unknown address embeds nothing.
  at <- which(addr_within(x, prefix) %in% TRUE)
  if (!length(at)) {
    return(new_list_of(slots, ptype = empty))
  }

  segments <- raddr_transition_embeddings[
    raddr_transition_embeddings$kind == "nat64" &
      raddr_transition_embeddings$prefix_len == len, ,
    drop = FALSE
  ]
  words <- lapply(
    c("w1", "w2", "w3", "w4"),
    function(nm) widen_word(field(x, nm))
  )

  address <- new_raddr_address(
    w1 = rep(0L, length(at)),
    w2 = rep(0L, length(at)),
    w3 = rep(0L, length(at)),
    w4 = narrow_word(read_embedded(words, segments, at)),
    family = factor(rep("v4", length(at)), levels = addr_families),
    zone = rep(NA_character_, length(at))
  )

  rows <- new_raddr_embedding(
    kind = factor(
      rep("nat64_nsp", length(at)),
      levels = raddr_embedding_kinds
    ),
    role = factor(
      rep("embedded", length(at)),
      levels = raddr_embedding_roles
    ),
    address = address,
    category = field(addr_classify(address), "category")
  )

  slots[at] <- vec_chop(rows, indices = as.list(seq_along(at)))
  new_list_of(slots, ptype = empty)
}
