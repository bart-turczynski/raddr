# The classification layer: longest-prefix-match lookup over the vendored IANA
# registries, and the `raddr_class` record built from it.
# See docs/architecture.md sections 5.3, 7, 7.1 and 7.3.
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

# The matcher's view of a prefix table: the blocks grouped by space and prefix
# length, the groups ordered longest prefix first.
#
# Every block of one length reduces its addresses to the same key -- the top
# `len` bits -- so a whole group costs one hash lookup however many blocks it
# holds, and the pass count over the address vector becomes the number of
# distinct lengths rather than the number of blocks. The 276-row address-space
# table has nine of them, because its 256 IPv4 rows are all /8. Section 11.1.6
# measures this against the descending-length walk it replaced, a sorted masked
# vector and a `triebeard` trie; R/within.R is the same regrouping answering the
# containment question.
#
# Longest-first is what keeps it longest-prefix-match: an address matched by one
# group is finished, because every group after it is shorter by construction.
# `order(decreasing = TRUE)` is stable and `split()` keeps each group's rows in
# ascending table order, so two blocks of the same length carrying the same key
# resolve to the earlier row -- the tie-break the walk had, unchanged.
build_prefix_index <- function(space, prefix_len, w1, w2, w3, w4) {
  words <- lapply(list(w1, w2, w3, w4), widen_word)
  groups <- split(seq_along(prefix_len), paste(space, prefix_len))

  lens <- vapply(groups, function(rows) prefix_len[[rows[[1L]]]], integer(1L))
  groups <- unname(groups[order(lens, decreasing = TRUE)])

  lapply(groups, function(rows) {
    at <- rows[[1L]]
    plan <- prefix_word_plan(prefix_len[[at]], space[[at]])
    list(
      space = space[[at]],
      plan = plan,
      rows = rows,
      targets = lapply(plan, function(step) {
        words[[step$word]][rows] %/% step$divisor
      })
    )
  })
}

# The key columns for every address under one group's plan. `sel` restricts the
# work to the addresses still in play. Shared with R/within.R, which reduces its
# blocks to keys the same way.
prefix_keys <- function(words, plan, sel) {
  lapply(plan, function(step) words[[step$word]][sel] %/% step$divisor)
}

# Which target row each key row equals, or NA where none does. This is
# `keys_in_targets()` in R/within.R asked for a position instead of a logical,
# and the difference is the whole reason the regrouping answers
# longest-prefix-match at all: containment only needs to know that a block
# matched, the registry needs to know which one.
keys_match_targets <- function(keys, targets) {
  if (!length(keys)) {
    # A /0 covers its whole space and has no words to compare, so every address
    # in the group's space matches its first row. Scalar, and recycled by the
    # caller, exactly as `keys_in_targets()` returns a scalar `TRUE`. No
    # vendored table holds a /0; a hand-authored overlay could.
    return(1L)
  }
  if (length(keys) == 1L) {
    return(match(keys[[1L]], targets[[1L]]))
  }
  names(keys) <- paste0("k", seq_along(keys))
  names(targets) <- paste0("k", seq_along(targets))
  vec_match(new_data_frame(keys), new_data_frame(targets))
}

# The overlay stores its prefixes as text, because R/transition.R is
# hand-authored from the RFCs rather than built by a script (section 7.2). They
# are parsed here rather than carried as four more hand-typed columns: the words
# of `2002::/16` are a mechanical consequence of the block, and P9 forbids
# hand-transcribing what can be derived.
#
# `addr_pton()` gives `::ffff:0:0` the `v6_4in6` family, which is right for an
# address and irrelevant here -- only the bits are read, and the space a block
# is matched in follows its notation.
parse_blocks <- function(block) {
  at <- regexpr("/", block, fixed = TRUE)
  address <- substr(block, 1L, at - 1L)
  parsed <- addr_pton(address)
  list(
    space = ifelse(grepl(":", address, fixed = TRUE), "v6", "v4"),
    prefix_len = as.integer(substring(block, at + 1L)),
    w1 = field(parsed, "w1"),
    w2 = field(parsed, "w2"),
    w3 = field(parsed, "w3"),
    w4 = field(parsed, "w4")
  )
}

# The four tables the matcher knows, in the pre-index form that
# `build_prefix_index()` reads. Named rather than inlined into `prefix_index()`
# because the tests and `bench/prefix.R` both need the table itself, not the
# index built from it.
prefix_table <- function(which) {
  switch(
    which,
    special = raddr_registry_data$blocks,
    space = raddr_registry_data$space,
    transition = parse_blocks(raddr_transition_prefixes$block),
    codes = parse_blocks(classify_code_blocks$block)
  )
}

# Memoized rather than built at load, because top-level code in R/ runs while
# the package is being installed and the order in which `R/sysdata.rda` becomes
# visible is not something to depend on.
prefix_index_cache <- new.env(parent = emptyenv())

prefix_index <- function(which) {
  cached <- prefix_index_cache[[which]]
  if (!is.null(cached)) {
    return(cached)
  }

  table <- prefix_table(which)
  index <- build_prefix_index(
    table$space, table$prefix_len,
    table$w1, table$w2, table$w3, table$w4
  )

  prefix_index_cache[[which]] <- index
  index
}

#' Match addresses against a prefix table, longest prefix wins
#'
#' @param x A `raddr_address` vector.
#' @param which Which table: `"special"` (the IANA special-purpose pair),
#'   `"space"` (the IANA address-space pair), `"transition"` (the overlay) or
#'   `"codes"` (the classify-layer rule blocks).
#'
#' @return An integer vector, one element per address, giving the row of that
#'   table which matched, or `NA_integer_` where no block contains the address.
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
prefix_match <- function(x, which) {
  prefix_match_index(x, prefix_index(which))
}

# The matcher itself, taking the index rather than the table's name, so that a
# test can hand it a table the package does not ship.
#' @noRd
prefix_match_index <- function(x, index) {
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

  # Groups are longest prefix first, so an address already carrying a row is
  # done: see `build_prefix_index()`.
  for (group in index) {
    sel <- in_space[[group$space]] & is.na(out)
    if (!any(sel)) {
      next
    }

    row <- keys_match_targets(
      prefix_keys(words, group$plan, sel),
      group$targets
    )
    found <- !is.na(row)
    if (!any(found)) {
      next
    }

    hit <- sel
    hit[sel] <- found
    out[hit] <- group$rows[row[found]]
  }

  out
}

# The special-purpose pair, which is what "the registry" means unqualified.
#' @noRd
registry_match <- function(x) {
  prefix_match(x, "special")
}

# --- the transition mechanism (sections 5.3 and 8.1) -------------------------

# `embedded_kind` names the mechanism an address belongs to and nothing else.
#
# NA MEANS "NO MECHANISM PREFIX MATCHED". It does not mean "this is not NAT64",
# and no field of the record may be read that way: RFC 6052 permits a
# network-specific NAT64 prefix at any of six lengths, and a caller-supplied
# prefix is invisible to a prefix table. raddr may only ever say `nat64_wk` or
# `nat64_local` AFFIRMATIVELY.
embedded_kind_of <- function(x) {
  n <- vec_size(x)
  levels <- raddr_embedded_kinds
  if (n == 0L) {
    return(factor(character(), levels = levels))
  }

  kinds <- rep(NA_character_, n)
  hit <- prefix_match(x, "transition")
  matched <- !is.na(hit)
  kinds[matched] <- raddr_transition_prefixes$kind[hit[matched]]

  # A prefix with no geometry is not a kind. NA propagates through the lookup,
  # so this drops `6to4_relay_anycast` and leaves an unmatched row alone.
  kinds[is.na(transition_geometry_kind[kinds])] <- NA_character_

  # RFC 4291 section 2.5.5.1's form is deprecated, and its low 32 bits are an
  # embedded address only above 1: `::` is the unspecified address and `::1` is
  # loopback, and both are separate, higher-priority IANA rows. Reading either
  # as an embedded 0.0.0.0 or 0.0.0.1 misclassifies both. The threshold is a
  # registry fact rather than a heuristic, and it is what both of the shipped
  # in-house guards raddr replaces already use.
  compatible <- !is.na(kinds) & kinds == "ipv4_compatible"
  if (any(compatible)) {
    tail32 <- widen_word(field(x, "w4"))
    kinds[compatible & tail32 <= 1] <- NA_character_
  }

  # RFC 5214 section 6.1 makes ISATAP an interface-identifier PATTERN rather
  # than a prefix, so it can sit under any /64 -- including one already assigned
  # to another mechanism. A prefix is an assignment and an interface identifier
  # is a convention within it, so the prefix wins and ISATAP fills in only where
  # no mechanism prefix matched.
  #
  # Compared against `permitted`, not re-derived, and with no bitwise operator:
  # section 5.1.1 forbids `bitwAnd()` on a word, which reads 0x80000000 as NA.
  # `%in%` is exact on the raw pattern, and that pattern is not a permitted
  # interface identifier, so it correctly does not match.
  family <- field(x, "family")
  isatap <- is.na(kinds) & !is.na(family) & family != "v4" &
    field(x, "w3") %in% isatap_iid$permitted
  kinds[isatap] <- "isatap"

  factor(kinds, levels = levels)
}

# --- the classify-layer codes (section 5.2.2) --------------------------------
#
# The vocabulary, the rule blocks and the strength grading all live in
# R/codes.R, which is where the parse layer's bits live too and for the same
# reason: R/ is sourced alphabetically, so a table this file defines at load
# time could not be cross-checked against the vocabulary. codes.R defines and
# the engines consume, exactly as R/ipv4.R and R/ipv6.R consume `code_bit()`.
#
# The classify codes for each address, as the `list_of<character>` the record
# stores.
#
# `kind` and `embedded` are passed in rather than recomputed: five of the eight
# rules are conditional on the mechanism or on the extracted address, and
# `addr_classify()` has already paid for both lookups.
classify_codes_of <- function(x, kind, embedded) {
  n <- vec_size(x)
  if (n == 0L) {
    return(new_list_of(list(), ptype = character()))
  }

  mask <- integer(n)

  hit <- prefix_match(x, "codes")
  matched <- !is.na(hit)
  by_block <- rep(NA_character_, n)
  by_block[matched] <- classify_code_blocks$code[hit[matched]]

  # Two blocks share `link_local_reserved_range`, so the loop is over the
  # distinct codes rather than over the rows.
  named <- classify_code_blocks$code[!is.na(classify_code_blocks$code)]
  for (code in unique(named)) {
    mask <- add_classify_code(mask, code, !is.na(by_block) & by_block == code)
  }

  kind <- as.character(kind)
  mask <- add_classify_code(
    mask, "nat64_local_layout_unspecified",
    !is.na(kind) & kind == "nat64_local"
  )

  # Only where the carve-out already let the form through: `::` and `::1` have
  # no kind at all (section 5.3.7), so this reports the tails between them and
  # 1.0.0.0 rather than re-deciding the threshold. Both shipped in-house guards
  # use `tail32 > 1`, and changing it would change their behavior; the fact
  # that the tail is nonetheless unroutable is reported instead, at `may`.
  compatible <- !is.na(kind) & kind == "ipv4_compatible"
  if (any(compatible)) {
    tail32 <- widen_word(field(x, "w4"))
    mask <- add_classify_code(
      mask, "ipv4_compatible_low_tail",
      compatible & tail32 < ipv4_this_network_end
    )
  }

  # --- and the three that are about the EMBEDDED address ---------------------
  #
  # `embedded$global` is `NA` for a role a mechanism has no row for, so a
  # negation is `NA` there too and `add_classify_code()` drops it. That is the
  # affirmative-only discipline again: a rule fires where raddr extracted an
  # address and found it non-global, never where it extracted nothing.
  #
  # Each rule binds a different mechanism, and the binding is the load-bearing
  # half in every case.

  # RFC 6052 section 3.1 binds the WELL-KNOWN PREFIX ALONE. It never reached a
  # network-specific prefix, and RFC 8215 section 5 says in terms that it does
  # not reach 64:ff9b:1::/48 -- "the restrictions on the use of the WKP
  # described in Section 3.1 of [RFC6052] do not apply". Over-applying it
  # reports a MUST-drop on legitimate addresses.
  mask <- add_classify_code(
    mask, "nat64_wk_embedded_not_global",
    !is.na(kind) & kind == "nat64_wk" & !embedded$global$embedded
  )

  # RFC 3056 section 9. The 6to4 case has no equivalent carve-out: every
  # 2002::/16 address is a 6to4 address by construction of the prefix.
  mask <- add_classify_code(
    mask, "sixtofour_embedded_not_global",
    !is.na(kind) & kind == "6to4" & !embedded$global$embedded
  )

  # RFC 4380 section 4 is conditional on the OUTER address -- "the identifiers
  # used in global addresses MUST include a global scope unicast IPv4 address,
  # while the identifiers used in link-local addresses MAY include a private
  # IPv4 address". The condition resolves without being evaluated: raddr names
  # `teredo` only from the 2001::/32 prefix, which is the global form, and the
  # link-local Teredo identifier sits under fe80::/64 and has no overlay row.
  # So a Teredo kind IS the antecedent, and the MAY case never reaches here.
  #
  # The SERVER is not graded. RFC 4380 states no equivalent requirement on it,
  # and section 5.3.5 records the asymmetry running the other way -- section
  # 5.2.3 validates the client against the packet source and specifies no check
  # of the server at all. Reporting one would be raddr inventing a rule.
  mask <- add_classify_code(
    mask, "teredo_client_not_global",
    !is.na(kind) & kind == "teredo" & !embedded$global$client
  )

  # --- and one that is about the CONTAINER rather than either address --------
  #
  # RFC 6052 section 2.2 reserves bits 64-71 "for compatibility with the host
  # identifier format defined in the IPv6 addressing architecture" and says
  # they MUST be set to zero. raddr's geometry SKIPS those bits -- section 2.3
  # says to remove the u octet before reading, which is what the two-segment
  # rows at /40, /48 and /56 encode -- so a violation changes no extracted
  # address. It is reported anyway: a MUST raddr can see and does not say is
  # the shape of thing this package exists to avoid, and a non-zero u-byte on
  # an otherwise well-formed NAT64 address is a hand-built address.
  #
  # Only `nat64_local` can reach it. Under the well-known /96 the reserved
  # octet lies INSIDE the prefix, so it is zero by construction of
  # 64:ff9b::/96 -- the condition is written over both kinds anyway, because it
  # is a fact about the geometry rather than about which prefix matched, and a
  # future prefix at another length would otherwise slip through unreported.
  nat64 <- !is.na(kind) & kind %in% c("nat64_wk", "nat64_local")
  if (any(nat64)) {
    at <- which(nat64)
    words <- lapply(
      c("w1", "w2", "w3", "w4"),
      function(nm) widen_word(field(x, nm))
    )
    hit <- rep(FALSE, n)
    hit[at] <- read_bits(
      words, nat64_u_byte[["offset"]], nat64_u_byte[["length"]], at
    ) != 0
    mask <- add_classify_code(mask, "nat64_u_byte_nonzero", hit)
  }

  new_list_of(
    codes_from_mask(mask, classify_code_levels, classify_code_bits),
    ptype = character()
  )
}

# --- the record (section 5.3) ------------------------------------------------

# Which vendored pair answered. The two are stamped separately and carry
# different columns, so the record says which one a row came from rather than
# leaving a caller to infer it from the block.
raddr_class_registries <- c("special_purpose", "address_space")

new_raddr_class <- function(block, name, rfc, footnotes, category,
                            globally_reachable, forwardable, source,
                            destination, reserved_by_protocol,
                            termination_date,
                            embedded_kind, embeddings, codes,
                            registry, registry_version) {
  new_rcrd(
    list(
      block = block, name = name, rfc = rfc, footnotes = footnotes,
      category = category,
      globally_reachable = globally_reachable,
      forwardable = forwardable,
      source = source,
      destination = destination,
      reserved_by_protocol = reserved_by_protocol,
      termination_date = termination_date,
      embedded_kind = embedded_kind,
      embeddings = embeddings,
      codes = codes,
      registry = registry,
      registry_version = registry_version
    ),
    class = "raddr_class"
  )
}

#' Classify addresses against the IANA registries
#'
#' Reports what the IANA registries say about each address: the block that
#' matched, its name and RFC, raddr's own one-word `category`, all five IANA
#' policy columns, the transition mechanism the address belongs to, and the
#' snapshot the answer came from.
#'
#' `addr_classify()` returns facts. It returns no verdict, no risk score and no
#' allow-or-deny decision, and it ships no "everything that is not `global`"
#' helper. Policy belongs to the consumer (P8).
#'
#' @section Two registries, and which one answered:
#'
#' Classification is **total**: every non-missing address matches some row.
#' That takes two layers, because the IANA special-purpose registries do not
#' cover the whole address space -- `224.0.0.0/4` and `ff00::/8` appear in
#' neither, which is how `ssrfcheck` shipped CVE-2025-8267.
#'
#' \describe{
#'   \item{[addr_registry()], the special-purpose pair}{Answers **policy**: the
#'     five logical columns. Matched first, and it outranks the other layer on
#'     IANA's own instruction -- the address-space registries carry "For
#'     authoritative registration, see \[Special-Purpose Address Space\]".}
#'   \item{[addr_address_space()], the address-space pair}{Answers
#'     **identity**: what a range is for and who holds it. Each half is an exact
#'     partition, which is what makes the lookup total.}
#' }
#'
#' `registry` says which one answered, and `registry_version` carries that
#' layer's own stamp (P7). The distinction is load-bearing, because it is what
#' keeps the two meanings of `NA` apart in the five policy columns:
#'
#' \describe{
#'   \item{`registry = "special_purpose"`}{`NA` is IANA's own `N/A` -- a policy
#'     it specifically declined to state. Reading it as `FALSE` asserts
#'     something the registry withheld.}
#'   \item{`registry = "address_space"`}{`NA` means the question was never
#'     asked: that registry has no policy columns at all. raddr leaves them
#'     absent rather than inventing them.}
#' }
#'
#' @section Every `NA` says why it is `NA`:
#'
#' Where raddr knows that two missing values mean different things, it reports
#' what distinguishes them rather than leaving both blank. Four special-purpose
#' blocks have a missing policy value, for three different reasons, and each
#' reason is a column:
#'
#' \describe{
#'   \item{Deprecated: `192.88.99.0/24`, `2001:10::/28`}{all five columns are
#'     `NA` and `termination_date` is set. IANA gives a withdrawn block no
#'     policy at all.}
#'   \item{Withheld: `2001::/32` (Teredo), footnote `[2]`}{RFC 4380 section 5
#'     makes relay advertisement voluntary and per-deployment, so no bits in the
#'     address answer reachability.}
#'   \item{Withheld: `2002::/16` (6to4), footnote `[3]`}{a different reason
#'     entirely -- reachability follows the *embedded* IPv4 address, which a
#'     prefix table cannot express.}
#' }
#'
#' `footnotes` does the same job for `rfc`, which is `NA` for every IPv4
#' address-space row. 42 of those 256 rows carry a footnote marker, meaning the
#' citation exists and its text is on the registry page rather than in the CSV;
#' the other 214 carry none. raddr reports that a caveat exists rather than
#' inventing its wording, and `""` means the row carried no marker at all.
#'
#' Footnote numbering is **per registry**, so a marker is only meaningful
#' alongside `registry` and the address family.
#'
#' @section What the fields are:
#'
#' \describe{
#'   \item{`block`, `name`, `rfc`, `footnotes`}{The matched row, as vendored.
#'     `rfc` is `NA` for every IPv4 address-space row, because that registry has
#'     no reference column; `footnotes` is what says whether a citation
#'     nonetheless exists.}
#'   \item{`category`}{raddr's own one-word vocabulary, 19 levels. It is
#'     **descriptive, not a policy input** -- see [addr_category_map()], and do
#'     not build a deny-list of level names on it.}
#'   \item{`globally_reachable`, `forwardable`, `source`, `destination`,
#'     `reserved_by_protocol`}{IANA's five policy columns, per row and never
#'     collapsed. `globally_reachable` **is** the column, not a derived
#'     `is_global`.}
#'   \item{`termination_date`}{Set on a deprecated block, and the reason its
#'     policy columns are empty. `NA` everywhere else, including for every
#'     address-space row.}
#'   \item{`embedded_kind`}{The transition mechanism, when a mechanism prefix
#'     matched. `NA` means no prefix matched -- it never means "not NAT64". A
#'     caller-supplied RFC 6052 network-specific prefix is invisible to a prefix
#'     table, so raddr states a NAT64 kind only affirmatively.}
#'   \item{`embeddings`}{Zero or more extracted inner addresses, one
#'     `raddr_embedding` per element, each carrying the extracted address and
#'     **its own** `category`. Plural because a Teredo address carries **two**
#'     IPv4 addresses -- a server in the clear and a bitwise-complemented
#'     client -- and raddr does not choose between them.}
#'   \item{`codes`}{Classify-layer reason codes, from the same vocabulary as
#'     [addr_codes_registry()] and graded by that registry's `strength`
#'     column. See below.}
#' }
#'
#' @section The codes are graded, and all of them are reported:
#'
#' `codes` carries what the RFCs say about an address that the registry row
#' alone does not. Each one is graded in [addr_codes_registry()] by the force
#' of the rule it reports, because reporting only the MUST rules would collapse
#' a spectrum into a binary:
#'
#' \describe{
#'   \item{`nat64_wk_embedded_not_global` (`must`)}{`64:ff9b::/96` carries a
#'     non-global embedded IPv4 address, which RFC 6052 section 3.1 says
#'     translators MUST drop. The rule binds the well-known prefix **alone** --
#'     never a network-specific prefix, and RFC 8215 section 5 says in terms
#'     that it does not reach `64:ff9b:1::/48`.}
#'   \item{`sixtofour_embedded_not_global` (`must`)}{the 6to4 `V4ADDR` is not a
#'     global unicast address, so RFC 3056 section 9 requires both encapsulators
#'     and decapsulators to discard the traffic silently.}
#'   \item{`teredo_client_not_global` (`must`)}{a global Teredo address embeds a
#'     non-global client IPv4 (RFC 4380 section 4). The **server** is not
#'     graded: the RFC states no equivalent requirement on it.}
#'   \item{`link_local_outside_fe80_64` (`must`)}{`febf::1` matches the
#'     `fe80::/10` registry row but is not a link-local address -- RFC 4291
#'     section 2.5.6 fixes the next 54 bits to zero. Both CPython's
#'     `ipaddress` and R's `ipaddress` report it as link-local with nothing
#'     attached to say otherwise.}
#'   \item{`link_local_reserved_range` (`must`)}{`169.254.0.0/24` and
#'     `169.254.255.0/24` MUST NOT be selected by IPv4 autoconfiguration
#'     (RFC 3927 section 2.1). Neither has a registry row of its own.}
#'   \item{`ipv4_compatible_low_tail` (`may`)}{the deprecated `::a.b.c.d` tail
#'     lands in `0.0.0.0/8`, so it is not a host address.}
#'   \item{`nat64_local_layout_unspecified` (`unspecified`)}{RFC 8215 section 5
#'     leaves the syntax under `64:ff9b:1::/48` deliberately undefined, so the
#'     RFC 6052 geometry raddr reads there is contested rather than implied.}
#'   \item{`ula_l_bit_unset` (`unspecified`)}{`fc00::/8` is the L = 0 half of
#'     the ULA prefix, for which RFC 4193 section 3.1 defines nothing at all.
#'     Only `fd00::/8` is a specified ULA.}
#' }
#'
#' The first three are stated about the **embedded** address rather than the
#' outer one, and all three are worded slightly differently -- "non-global",
#' "not in the format of a global unicast address", "a global scope unicast
#' IPv4 address". raddr answers them with one predicate, and answers it
#' affirmatively from both registry layers: an extracted address is global when
#' IANA records `globally_reachable = TRUE` for it, or when it lies in space
#' delegated to an RIR. Neither layer settles it alone.
#'
#' A rule fires only where raddr actually extracted an address. A
#' caller-supplied RFC 6052 network-specific prefix is invisible to a prefix
#' table, so no code is emitted for one -- silence here is not a clean bill of
#' health, for the same reason `embedded_kind = NA` is not.
#'
#' @section A string may never be classified:
#'
#' `addr_classify()` takes a parsed address and nothing else (P1). It also
#' declines a `raddr_parse`, which holds four readings that may be four
#' different addresses: choosing one is a decision, and raddr makes it by
#' function name rather than silently. Pick a reading with
#' [addr_reading()], or parse with [addr_strict()], [addr_whatwg()],
#' [addr_pton()] or [addr_aton()].
#'
#' @param x A `raddr_address` vector.
#'
#' @return A `raddr_class` vector, one element per address. Every field is `NA`
#'   for a missing address.
#'
#' @seealso [addr_category()] and [addr_embeddings()] for single fields,
#'   [addr_registry()] and [addr_address_space()] for the data behind the
#'   answer.
#'
#' @examples
#' addr_classify(addr_pton(c("127.0.0.1", "8.8.8.8", "224.0.0.1", "4000::1")))
#'
#' # All four facts about the NAT64 well-known prefix, none collapsed
#' cl <- addr_classify(addr_pton("64:ff9b::a9fe:a9fe"))
#' as.data.frame(cl)[c("block", "category", "globally_reachable")]
#'
#' # The carve-out that forces longest-prefix matching
#' as.data.frame(addr_classify(addr_pton(c("192.0.0.9", "192.0.0.100"))))
#'
#' @export
addr_classify <- function(x) {
  check_classify_input(x)
  n <- vec_size(x)

  blocks <- raddr_registry_data$blocks
  spaces <- raddr_registry_data$space

  # Special-purpose outranks address space, on IANA's own instruction. Because
  # the address-space pair is an exact partition, every special-purpose block
  # falls inside one of its rows, so this decides every doubly-matched lookup
  # rather than an edge case.
  special <- prefix_match(x, "special")
  space <- prefix_match(x, "space")
  from_special <- !is.na(special)
  from_space <- !from_special & !is.na(space)

  take <- function(special_column, space_column) {
    out <- rep(NA_character_, n)
    out[from_special] <- special_column[special[from_special]]
    out[from_space] <- space_column[space[from_space]]
    out
  }

  # Columns the address-space registry does not have. Where that layer
  # answered they stay missing, because the question was never asked of it --
  # see the two meanings of NA above.
  only_special <- function(column, empty) {
    out <- rep(empty, n)
    out[from_special] <- blocks[[column]][special[from_special]]
    out
  }
  policy <- function(column) only_special(column, NA)

  block <- take(blocks$block, spaces$block)
  registry <- rep(NA_character_, n)
  registry[from_special] <- "special_purpose"
  registry[from_space] <- "address_space"

  version <- rep(NA_character_, n)
  version[from_special] <- addr_registry_version()
  version[from_space] <- addr_address_space_version()

  kind <- embedded_kind_of(x)
  embedded <- extract_embeddings(x, kind)
  new_raddr_class(
    block = block,
    name = take(blocks$name, spaces$name),
    rfc = take(blocks$rfc, spaces$rfc),
    footnotes = take(blocks$footnotes, spaces$footnotes),
    category = factor(
      unname(raddr_category_map[block]),
      levels = raddr_category_levels
    ),
    globally_reachable = policy("globally_reachable"),
    forwardable = policy("forwardable"),
    source = policy("source"),
    destination = policy("destination"),
    reserved_by_protocol = policy("reserved_by_protocol"),
    termination_date = only_special("termination_date", NA_character_),
    embedded_kind = kind,
    embeddings = embedded$embeddings,
    codes = classify_codes_of(x, kind, embedded),
    registry = factor(registry, levels = raddr_class_registries),
    registry_version = version
  )
}

# P1 in one place. A `raddr_parse` is refused rather than reduced: reducing four
# readings to one is the decision section 4 says raddr makes by function name.
check_classify_input <- function(x, arg = "x") {
  if (is_raddr_parse(x)) {
    abort(
      c(
        sprintf(
          "`%s` must be a <raddr_address> vector, not a <raddr_parse>.",
          arg
        ),
        i = paste(
          "A <raddr_parse> holds four readings, which may be four different",
          "addresses. raddr does not choose which one gets classified."
        ),
        i = paste(
          "Take one with `addr_reading()`, or parse with `addr_strict()`,",
          "`addr_whatwg()`, `addr_pton()` or `addr_aton()`."
        )
      ),
      class = "raddr_error_type"
    )
  }
  check_raddr_address(x, arg)
}

#' Test whether an object is a `raddr_class`
#'
#' @param x An object.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_raddr_class(addr_classify(addr_pton("127.0.0.1")))
#' is_raddr_class("127.0.0.1")
#'
#' @export
is_raddr_class <- function(x) {
  inherits(x, "raddr_class")
}

# One accessor shape for all three: classify an address, or read the field
# straight off a classification the caller already has.
class_field <- function(x, field_name, arg = "x") {
  if (is_raddr_class(x)) {
    return(field(x, field_name))
  }
  field(addr_classify(x), field_name)
}

#' Read single fields of a classification
#'
#' Each takes either a `raddr_address`, which it classifies, or a `raddr_class`
#' that [addr_classify()] already produced.
#'
#' @section `category` describes; it does not decide:
#'
#' `addr_category()` returns raddr's one-word vocabulary, and a policy layer
#' must not enumerate it. Label vocabularies drift -- `ipaddr.js` renamed
#' `deprecated` to `deprecatedOrchid` -- and a consumer that denies by named
#' list turns every newly added level into a bypass. Policy belongs on the five
#' IANA columns, the classify codes and the embeddings, all of which are
#' three-valued and registry- or RFC-sourced (P8). See [addr_category_map()].
#'
#' @section Embeddings are plural, and Teredo is why:
#'
#' `addr_embeddings()` always returns the typed list, never a single address.
#' RFC 4380 section 4 puts two IPv4 addresses in a Teredo address -- a server in
#' the clear and a bitwise-complemented client -- and section 5.2.6 makes the
#' server a destination a host actually sends to, so neither is metadata for the
#' other. There is deliberately no scalar accessor: reducing the pair to one
#' address *is* the Teredo decision, and it is the consumer's to make.
#'
#' Each row carries the `category` of the **extracted** address, not of the one
#' it came out of. `addr_classify(addr_pton("::ffff:127.0.0.1"))` therefore
#' reports an IPv6 address in `::ffff:0:0/96` *and* an embedded `127.0.0.1`
#' that is `loopback`, with neither fact collapsed into the other.
#'
#' @section `embedded_kind` is affirmative only:
#'
#' `NA` from `addr_embedded_kind()` means no mechanism prefix matched. It does
#' **not** mean the address is not NAT64: RFC 6052 permits a network-specific
#' prefix at six lengths, and a prefix table cannot see one. A caller who knows
#' their operator's prefix can read the address under it with
#' [addr_nat64_embeddings()], which is opt-in precisely because the prefix
#' cannot come from the address.
#'
#' @param x A `raddr_address` or `raddr_class` vector.
#'
#' @return `addr_category()` and `addr_embedded_kind()` return factors;
#'   `addr_embeddings()` returns a `list_of<raddr_embedding>`. All are the same
#'   length as `x`.
#'
#' @seealso [addr_classify()] for the whole record.
#'
#' @examples
#' addr_category(addr_pton(c("127.0.0.1", "224.0.0.1", "8.8.8.8", "4000::1")))
#'
#' # The mechanism is a separate fact from the category: this block is
#' # `protocol` AND `nat64_wk` AND globally reachable, all at once.
#' a <- addr_pton("64:ff9b::a9fe:a9fe")
#' addr_category(a)
#' addr_embedded_kind(a)
#'
#' # `::` and `::1` are not IPv4-compatible addresses carrying an embedded
#' # 0.0.0.0 or 0.0.0.1, and are not reported as though they were
#' addr_embedded_kind(addr_pton(c("::", "::1", "::2")))
#'
#' @export
addr_category <- function(x) {
  class_field(x, "category")
}

#' @rdname addr_category
#' @export
addr_embedded_kind <- function(x) {
  class_field(x, "embedded_kind")
}

#' @rdname addr_category
#' @export
addr_embeddings <- function(x) {
  class_field(x, "embeddings")
}

#' Whether an address is in globally reachable space
#'
#' The two-layer positive fact raddr already uses internally to decide the
#' antecedent of RFC 6052 section 3.1, RFC 3056 section 9 and RFC 4380
#' section 4. It is a **fact, not a verdict**: it reports what the two vendored
#' registry layers say, and says nothing about whether a caller should permit
#' the address.
#'
#' @section The two layers, and why both:
#'
#' Neither layer answers alone, and each fixes what the other gets wrong:
#'
#' \describe{
#'   \item{special-purpose}{IANA's own `globally_reachable` column, unmodified.
#'     Without it the five blocks IANA marks globally reachable -- PCP and TURN
#'     anycast, AS112 twice, AMT -- read as non-global.}
#'   \item{address space}{that layer has no policy column at all, and the
#'     question it does answer is whether the space is delegated to an RIR,
#'     which is `category = "global"`. Without it `8.8.8.8` reads as non-global
#'     and `224.0.0.0/4` reads as nothing -- CVE-2025-8267's shape.}
#' }
#'
#' This is **not** the `category` deny-list [addr_category()] warns against. It
#' reads one *positive* level, only in the layer that has no other column, and
#' a level added later changes no answer that layer gives today. Reaching this
#' fact through this function rather than rebuilding it from `category` is the
#' whole reason it is exported.
#'
#' @section `NA` is a third answer, not a missing one:
#'
#' `NA` means the registries leave the question open, and it must not be read
#' as `FALSE`. Four special-purpose blocks are in that tier (see
#' [addr_registry()]): the withdrawn `192.88.99.0/24` and `2001:10::/28`, which
#' IANA gave no policy at all, and the live 6to4 (`2002::/16`) and Teredo
#' (`2001::/32`) blocks, which IANA itself records as `N/A`. So every 6to4 and
#' every Teredo address answers `NA` here, whatever it wraps. Asserting a
#' MUST-drop there would be reading IANA's `N/A` as a `FALSE` one level down.
#'
#' For 6to4 the question IANA declines is answered by the embedded IPv4 address:
#' pass the embedding row, `addr_global_reachability(addr_embeddings(x)[[1]])`.
#' The Teredo `N/A` has an unrelated cause -- relay advertisement is
#' per-deployment -- and no bits in the address answer it.
#'
#' Handle it explicitly. R propagates `NA` rather than resolving it: `any()`
#' returns `NA` instead of `FALSE`, `which()` drops the element entirely, and
#' `if` raises an error on it. A policy layer must branch on all three values
#' rather than let the third fall through to either side. raddr reports it;
#' deciding what it costs is the caller's.
#'
#' @param x A `raddr_address`, `raddr_class` or `raddr_embedding` vector. An
#'   embedding is classified by its extracted address, so the answer is the
#'   same one the classify layer used when grading that embedding.
#'
#' @return A logical vector the same length as `x`: `TRUE`, `FALSE` or `NA`.
#'
#' @seealso [addr_classify()] for the whole record, including the
#'   `globally_reachable` column this reads. [addr_category()] for why the
#'   descriptive vocabulary is not a policy input.
#'
#' @examples
#' # The address-space layer answers for an ordinary host, the special-purpose
#' # layer for a carve-out, and neither for the withdrawn anycast prefix.
#' addr_global_reachability(addr_pton(c("8.8.8.8", "192.0.0.9", "192.88.99.1")))
#'
#' # Both families, one rule
#' addr_global_reachability(addr_pton(c("2001:4860:4860::8888", "fe80::1")))
#'
#' # The outer address and what it embeds are separate questions: this block is
#' # globally reachable and the IPv4 inside it is not
#' a <- addr_pton("64:ff9b::a9fe:a9fe")
#' addr_global_reachability(a)
#' addr_global_reachability(addr_embeddings(a)[[1]])
#'
#' @export
addr_global_reachability <- function(x) {
  if (is_raddr_embedding(x)) {
    return(global_reachability(addr_classify(field(x, "address"))))
  }
  if (is_raddr_class(x)) {
    return(global_reachability(x))
  }
  global_reachability(addr_classify(x))
}

# --- Printing ----------------------------------------------------------------

# The category leads because it is the answer; the block follows because it is
# the evidence. Neither is useful without the other, so the one-line form
# carries both.
#' @export
format.raddr_class <- function(x, ...) {
  block <- field(x, "block")
  out <- rep(NA_character_, length(block))
  known <- !is.na(block)
  out[known] <- paste(
    as.character(field(x, "category"))[known],
    block[known]
  )
  out
}

#' @export
as.character.raddr_class <- function(x, ...) {
  format(x, ...)
}

#' @export
obj_print_data.raddr_class <- function(x, ...) {
  if (vec_size(x) == 0L) {
    return(invisible(x))
  }
  print(format(x), quote = FALSE)
  invisible(x)
}

# P7: provenance travels with the verdict. Which snapshot answered is part of
# the answer, and the two layers are stamped separately, so the footer names
# every layer that actually contributed rather than printing one date that
# would imply something about a table it says nothing about.
registry_labels <- c(
  special_purpose = "special-purpose",
  address_space = "address space"
)

#' @export
obj_print_footer.raddr_class <- function(x, ...) {
  registry <- field(x, "registry")
  if (!length(registry) || all(is.na(registry))) {
    return(invisible(x))
  }
  version <- field(x, "registry_version")

  used <- names(registry_labels)[names(registry_labels) %in% registry]
  parts <- vapply(used, function(level) {
    at <- !is.na(registry) & registry == level
    count <- if (length(used) > 1L) sprintf(" (%d)", sum(at)) else ""
    sprintf("%s %s%s", registry_labels[[level]], version[at][[1L]], count)
  }, character(1L))

  cat(sprintf("Registry: %s\n", paste(parts, collapse = ", ")))
  invisible(x)
}

# Every field, as columns. A record is one column under vctrs' default, which is
# the right answer inside a data frame and the wrong one for a caller who wants
# to read `globally_reachable` -- and nine more accessors to reach nine fields
# would be API surface standing in for a coercion R already has a name for.
#' @export
as.data.frame.raddr_class <- function(x, ...) {
  vec_data(x)
}

#' @export
vec_ptype_abbr.raddr_class <- function(x, ...) {
  "class"
}

#' @export
vec_ptype_full.raddr_class <- function(x, ...) {
  "raddr_class"
}
