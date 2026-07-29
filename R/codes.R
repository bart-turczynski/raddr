# The reason-code vocabulary. See docs/architecture.md sections 5.2 and 6.4.
#
# One const registry, and everything else derived from it. The valid-value set
# is `raddr_codes$code` rather than a second list that has to be kept in step,
# because a vocabulary restated in two places is a vocabulary that drifts.
#
# The codes are a versioned vocabulary: adding one is an API change and removing
# one is breaking. That is what the `since` column is for.
#
# They are NOT a vocabulary `ssrfr` echoes verbatim, and an earlier version of
# this comment claimed they were. `ssrfr` ADR-001 section 7 assigns the
# "reason-code vocabulary and result model" to `ssrfr`, and its spec section 5.2
# fixes those as kebab-case, normative for `ssrfr` and constrained by its own
# published consumers -- the case divergence is deliberate, not drift. Both
# documents cannot be right, and the counterparty's own ADR wins.
#
# So the relationship is many-to-one and conditional, not an alias: raddr states
# facts, `ssrfr` interprets them into a refusal reason. A raddr code may travel
# in a detailed `ssrfr` result as evidence, but `ssrfr`'s public reason comes
# from `ssrfr`. This is the same separation section 5.3.3 draws for `category`,
# and for the same purpose -- a policy layer must not enumerate a descriptive
# classifier's output as its deny list.

# --- the strength scale ------------------------------------------------------
#
# How much force the rule a code reports actually carries. The user's framing,
# which corrected an earlier proposal to ship only the MUST rules:
#
#   "must is must; other language should be reported, but no consequences are
#   needed."
#
# Shipping only the MUSTs would collapse a spectrum into a binary, which is the
# move raddr exists to refuse. So every rule is reported and every one is
# graded.
#
# `should` currently has no member. That is not an oversight and the level is
# not removed for it: a scale missing its middle would let a consumer read
# `must`/`may` as the whole spectrum. RFC 6052 section 3.1's SHOULD NOT ("the
# Well-Known Prefix SHOULD NOT be used to construct IPv4-translatable IPv6
# addresses") is the nearest candidate and is not decidable from an address, so
# nothing fills the tier yet.
#
# --- and what it does NOT claim ----------------------------------------------
#
# `must` is graded on the rule's SUBSTANCE, not on the presence of an RFC 2119
# keyword, because the eight sources do not agree about keywords
# [verified 2026-07-27, against the RFC texts]:
#
#   RFC 3056, 3927, 4193, 4380, 6052  invoke RFC 2119
#   RFC 4291, 8215                    invoke it nowhere, and state their rules
#                                     in lowercase or as a format diagram
#
# So `link_local_outside_fe80_64` is `must` because RFC 4291 section 2.5.6's
# 54 zero bits are the DEFINITION of the link-local format, not because 4291
# spells a keyword -- it never does. Each summary says which it is, so the
# grading is inspectable rather than asserted.
raddr_code_strengths <- c("must", "should", "may", "unspecified")

# A row-major literal, so the registry reads as a table in the source too.
#
# `strength` defaults to NA because that is the honest value for the 15
# parse-layer codes: they describe what a parser DID with a literal, not what a
# specification mandates about an address. Filling them in would be inventing a
# grade for a rule that was never being graded.
raddr_codes_row <- function(code, layer, rfc, summary,
                            strength = NA_character_, since = "0.1.0") {
  list(
    code = code, layer = layer, rfc = rfc, summary = summary,
    strength = strength, since = since
  )
}

raddr_codes <- local({
  rows <- list(
    # --- IPv4 -----------------------------------------------------------------
    raddr_codes_row(
      "not_a_number", "parse", "RFC 3986 section 3.2.2",
      "A dot-separated part is not a number in any radix this dialect reads."
    ),
    raddr_codes_row(
      "leading_zero", "parse", "RFC 6943 section 3.1.1",
      "A part carries a leading zero and this dialect forbids one."
    ),
    raddr_codes_row(
      "empty_part", "parse", "RFC 3986 section 3.2.2",
      "Two consecutive dots, or a leading dot, leave a part empty."
    ),
    raddr_codes_row(
      "empty_hex", "parse", "WHATWG URL, IPv4 number parser",
      "A part is a digitless \"0x\" where this dialect requires digits."
    ),
    raddr_codes_row(
      "out_of_range", "parse", "RFC 3986 section 3.2.2",
      "A part exceeds the largest value its position can hold."
    ),
    raddr_codes_row(
      "wrong_part_count", "parse", "RFC 3986 section 3.2.2",
      "The number of dot-separated parts is not one this dialect accepts."
    ),
    raddr_codes_row(
      "trailing_dot", "parse", "WHATWG URL, IPv4 parser",
      "The literal ends in a dot that this dialect does not drop."
    ),
    # --- IPv6 -----------------------------------------------------------------
    raddr_codes_row(
      "zone_not_permitted", "parse", "RFC 4291 section 2.2",
      "The literal carries a zone ID and this dialect has no zone ID at all."
    ),
    raddr_codes_row(
      "multiple_zones", "parse", "RFC 4007 section 11.2",
      "More than one \"%\", so the zone ID has no single delimiter."
    ),
    raddr_codes_row(
      "bad_hextet", "parse", "RFC 4291 section 2.2",
      "A group is not one to four hexadecimal digits."
    ),
    raddr_codes_row(
      "empty_group", "parse", "RFC 4291 section 2.2",
      "A stray colon leaves a group empty."
    ),
    raddr_codes_row(
      "bad_elision", "parse", "RFC 4291 section 2.2",
      "More than one \"::\", or a \":::\" run."
    ),
    raddr_codes_row(
      "wrong_group_count", "parse", "RFC 4291 section 2.2",
      "The literal does not resolve to exactly eight groups."
    ),
    raddr_codes_row(
      "bad_embedded_ipv4", "parse", "RFC 4291 section 2.2",
      "The dotted-quad tail is not an address under this dialect's IPv4 rules."
    ),
    # An AF_INET-only dialect has no objection to a colon literal, it has no
    # reading of one -- so that is a `not_an_address` outcome and not a code.
    # See ip_attempt() in R/parse.R.
    # --- Compositions ---------------------------------------------------------
    raddr_codes_row(
      "whitespace", "parse", "POSIX getaddrinfo(3)",
      "The literal contains whitespace, which this dialect rejects outright."
    ),
    # --- classify, strongest first --------------------------------------------
    #
    # Ordered by descending normative force, which is both the order a consumer
    # wants to read them in and the order `codes` reports them in.
    raddr_codes_row(
      "nat64_wk_embedded_not_global", "classify", "RFC 6052 section 3.1",
      paste(
        "The NAT64 well-known prefix carries a non-global embedded IPv4",
        "address. Translators MUST NOT translate such packets and MUST drop",
        "them. The rule binds 64:ff9b::/96 alone -- never a network-specific",
        "prefix, and RFC 8215 section 5 says it does not reach 64:ff9b:1::/48."
      ),
      strength = "must"
    ),
    raddr_codes_row(
      "sixtofour_embedded_not_global", "classify", "RFC 3056 section 9",
      paste(
        "The 6to4 V4ADDR is not in the format of a global unicast address, so",
        "the traffic MUST be silently discarded by both encapsulators and",
        "decapsulators. Spelled `sixtofour` because a code may not begin with",
        "a digit; CPython's `ipaddress` names the same property the same way."
      ),
      strength = "must"
    ),
    raddr_codes_row(
      "teredo_client_not_global", "classify", "RFC 4380 section 4",
      paste(
        "A global Teredo address MUST embed a global-scope unicast IPv4 as its",
        "client address. Only a link-local Teredo identifier MAY embed a",
        "private one, so the rule is conditional on the outer address."
      ),
      strength = "must"
    ),
    raddr_codes_row(
      "link_local_outside_fe80_64", "classify", "RFC 4291 section 2.5.6",
      paste(
        "The address is inside the fe80::/10 reservation but outside",
        "fe80::/64: the link-local format fixes the 54 bits after the prefix",
        "to zero, so febf::1 matches the registry row without being a",
        "link-local address. RFC 4291 states this as a format definition and",
        "invokes no RFC 2119 keywords anywhere."
      ),
      strength = "must"
    ),
    raddr_codes_row(
      "link_local_reserved_range", "classify", "RFC 3927 section 2.1",
      paste(
        "The address is in 169.254.0.0/24 or 169.254.255.0/24. Those 512",
        "addresses are reserved for future use and MUST NOT be selected by a",
        "host configuring an IPv4 link-local address. The rule binds the host",
        "that picks an address, not a packet carrying one."
      ),
      strength = "must"
    ),
    raddr_codes_row(
      "ipv4_compatible_low_tail", "classify", "RFC 4291 section 2.5.5.1",
      paste(
        "The deprecated IPv4-compatible tail is below 1.0.0.0, so it lands in",
        "0.0.0.0/8 and is not a host address. Reported rather than suppressed:",
        "the exclusion raddr applies is the registry fact that :: and ::1 are",
        "separate rows, and implementations are in any case 'not required to",
        "support this address type', so a consumer may discount the reading."
      ),
      strength = "may"
    ),
    raddr_codes_row(
      "nat64_local_layout_unspecified", "classify", "RFC 8215 section 5",
      paste(
        "raddr read RFC 6052 /48 geometry under 64:ff9b:1::/48, whose syntax",
        "RFC 8215 leaves deliberately unspecified -- nodes 'must not make any",
        "assumptions regarding the syntax or properties of those addresses",
        "(e.g., the existence and location of embedded IPv4 addresses)',",
        "lowercase, in a document that invokes no RFC 2119. The extraction is",
        "kept because deployments use that geometry, but it is contested",
        "rather than implied by the prefix."
      ),
      strength = "unspecified"
    ),
    raddr_codes_row(
      "ula_l_bit_unset", "classify", "RFC 4193 section 3.1",
      paste(
        "The ULA L bit is 0, so the address is in fc00::/8 rather than the",
        "locally assigned fd00::/8. RFC 4193 defines only L = 1 and says L = 0",
        "'may be defined in the future'; no allocation mechanism ever was.",
        "Such an address is unspecified, not merely unusual."
      ),
      strength = "unspecified"
    )
  )

  columns <- c("code", "layer", "rfc", "summary", "strength", "since")
  out <- lapply(columns, function(column) {
    vapply(rows, function(row) row[[column]], character(1L))
  })
  names(out) <- columns
  # The grading discipline, checked rather than trusted: every strength is from
  # the scale, and the two layers divide exactly on it -- a parse code is never
  # graded and a classify code always is.
  stopifnot(
    all(is.na(out$strength) | out$strength %in% raddr_code_strengths),
    identical(is.na(out$strength), out$layer == "parse")
  )
  vctrs::new_data_frame(out, n = length(rows))
})

# The valid-value sets, derived rather than restated. Ordering is the
# registry's, so a `codes` vector always reads in the same order whatever the
# input -- and for the classify layer that order is descending normative force.
parse_code_levels <- raddr_codes$code[raddr_codes$layer == "parse"]
classify_code_levels <- raddr_codes$code[raddr_codes$layer == "classify"]

# --- Carrying codes through the engines --------------------------------------
#
# The parsers work a pass at a time over the whole vector, so the codes have to
# travel the same way: a per-row integer mask, one bit per code, built with
# vectorized bitwOr() and unpacked only at the end. A list of character vectors
# grown row by row would put a per-element loop back into the middle of an
# engine built specifically to avoid one.
#
# The classify layer reuses the same mask, for a different reason: its rules are
# independent facts about one address rather than competing readings of one
# part, so they ACCUMULATE instead of racing. Unpacking by distinct mask is what
# keeps that from becoming a per-row loop.
#
# One bit per code caps a vocabulary at 31, because R's integer is signed
# 32-bit. That is far away for both layers, but it is a real ceiling rather than
# a stylistic one, so it is asserted where a 32nd code would be added.
code_bits_for <- function(levels) {
  stopifnot(length(levels) <= 31L)
  bits <- as.integer(2^(seq_along(levels) - 1L))
  names(bits) <- levels
  bits
}

parse_code_bits <- code_bits_for(parse_code_levels)
classify_code_bits <- code_bits_for(classify_code_levels)

# A bit by name, so the engines never spell a power of two.
code_bit <- function(code, bits = parse_code_bits) {
  unname(bits[[code]])
}

# The bit of the first condition that fires, per element, over a named list of
# logical vectors given in precedence order. A scalar `FALSE` stands for a
# condition this dialect's rules switch off, so a caller does not have to
# materialize a vector for a rule that cannot fire.
first_code <- function(conditions, n) {
  out <- integer(n)
  remaining <- rep(TRUE, n)
  for (code in names(conditions)) {
    hit <- remaining & conditions[[code]]
    hit[is.na(hit)] <- FALSE
    if (any(hit)) {
      out[hit] <- code_bit(code)
      remaining <- remaining & !hit
    }
  }
  out
}

# Unpack masks into the `list<character>` the record stores.
#
# Done via the *distinct* masks rather than row by row: a vector of a million
# addresses has a million rows and a handful of masks, most of them zero. That
# turns the one unavoidable per-element step into a loop over the masks that
# actually occurred.
codes_from_mask <- function(mask, levels = parse_code_levels,
                            bits = parse_code_bits) {
  keys <- unique(mask)
  decoded <- lapply(keys, function(key) {
    if (key == 0L) {
      return(character())
    }
    levels[bitwAnd(key, bits) != 0L]
  })
  decoded[match(mask, keys)]
}

# --- the blocks the prefix-only classify rules are decided on ----------------
#
# Three of the eight classify rules need nothing but the prefix, and one
# longest-prefix-match pass over this table answers all three.
#
# `fe80::/64` carries no code. It is here ONLY to shadow `fe80::/10`, because
# longest-prefix-match then lands on the /10 exactly when the address is inside
# the reservation and outside the format RFC 4291 section 2.5.6 defines.
# Encoding "in A but not in B" as a second row is cheaper than a second pass,
# and it keeps the rule readable as a table rather than as a subtraction.
#
# `fc00::/8` is the L = 0 half of RFC 4193's `fc00::/7`, and raddr stores only
# the /7 -- so the half that has no defining specification has no registry row
# to be recognised by, and this is where it becomes visible.
classify_code_block_row <- function(block, code = NA_character_) {
  list(block = block, code = code)
}

classify_code_blocks <- local({
  rows <- list(
    classify_code_block_row("fe80::/10", "link_local_outside_fe80_64"),
    classify_code_block_row("fe80::/64"),
    classify_code_block_row("169.254.0.0/24", "link_local_reserved_range"),
    classify_code_block_row("169.254.255.0/24", "link_local_reserved_range"),
    classify_code_block_row("fc00::/8", "ula_l_bit_unset")
  )

  out <- do.call(rbind.data.frame, c(rows, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
})

# Every code named above is a real code, and the shadow row is the only one
# without one. Checked rather than trusted, as elsewhere.
stopifnot(
  all(
    classify_code_blocks$code[!is.na(classify_code_blocks$code)] %in%
      classify_code_levels
  ),
  sum(is.na(classify_code_blocks$code)) == 1L
)

# 0.0.0.0/8 is "this network" (RFC 1122 section 3.2.1.3), so an IPv4-compatible
# tail below 1.0.0.0 is not a host address. Arithmetic, never bitwShiftL.
ipv4_this_network_end <- 2^24

# Set a classify code wherever `hit` is TRUE, accumulating rather than
# replacing. NA is not a hit: a rule that could not be evaluated for a row has
# not fired on it.
add_classify_code <- function(mask, code, hit) {
  hit[is.na(hit)] <- FALSE
  if (any(hit)) {
    mask[hit] <- bitwOr(mask[hit], code_bit(code, classify_code_bits))
  }
  mask
}

#' The reason-code registry
#'
#' Every reason code raddr can attach to a reading, with its layer, its
#' provenance and the version it was introduced in. `addr_codes()` returns codes
#' from this vocabulary; this is where you look one up.
#'
#' The registry is the vocabulary's single definition. raddr derives the set of
#' valid codes from it rather than keeping a second list, and a test asserts
#' that every code has at least one input in the corpus that produces it, so a
#' code that nothing can emit fails the build.
#'
#' @section A versioned vocabulary, not an alias:
#'
#' The codes are meant to be read by other packages, so adding one is an
#' addition to raddr's API and removing one is a breaking change -- which is
#' what the `since` column records.
#'
#' They are **not** a vocabulary another package echoes verbatim. `ssrfr` owns
#' its own reason codes and its own result model, and the relationship between
#' the two vocabularies is many-to-one and conditional rather than an alias:
#' raddr states facts, a policy layer interprets them into a refusal reason. A
#' raddr code may travel in a detailed result as evidence without being that
#' package's public reason. This is the same separation drawn between raddr's
#' `category` and a policy verdict, and for the same purpose -- a policy layer
#' must not enumerate a descriptive classifier's output as its deny list.
#'
#' @section Layers:
#'
#' \describe{
#'   \item{`parse`}{Why a dialect declined to read a literal as an address.
#'     Reported by [addr_codes()].}
#'   \item{`classify`}{Facts about a parsed address noted during
#'     classification. Reported in the `codes` field of [addr_classify()].}
#' }
#'
#' @section Why every rule is reported, not only the MUSTs:
#'
#' `strength` records how much force the rule a code reports actually carries:
#' `"must"`, `"should"`, `"may"` or `"unspecified"`. Reporting only the MUST
#' rules would collapse a spectrum into a binary, which is the move raddr
#' exists to refuse -- so a rule stated in weaker language is still reported,
#' and the grade is what says not to act on it as though it were a MUST.
#'
#' It is `NA` for every `parse` code, and that is the honest value rather than
#' a filler: those codes describe what a parser **did** with a literal, not
#' what a specification mandates about an address.
#'
#' The grade follows the rule's substance, not the presence of an RFC 2119
#' keyword, because the sources do not agree about keywords: RFC 4291 and
#' RFC 8215 invoke RFC 2119 nowhere and state their rules in lowercase or as a
#' format diagram, while RFC 3056, 3927, 4193, 4380 and 6052 all invoke it.
#' Each `summary` says which case it is, so the grading can be checked rather
#' than taken on trust.
#'
#' `"should"` has no member yet. The level is kept anyway, so that a consumer
#' does not read `must` and `may` as the whole scale.
#'
#' @return A data frame with one row per code and the columns `code`, `layer`,
#'   `rfc`, `summary`, `strength` and `since`.
#'
#' @examples
#' registry <- addr_codes_registry()
#' registry$code
#'
#' registry[registry$code == "out_of_range", ]
#'
#' # The classify layer, graded by normative force
#' classify <- registry[registry$layer == "classify", ]
#' classify[c("code", "rfc", "strength")]
#'
#' @export
addr_codes_registry <- function() {
  as.data.frame(raddr_codes, stringsAsFactors = FALSE)
}
