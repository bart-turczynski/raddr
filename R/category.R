# raddr's block -> category map. See docs/architecture.md sections 5.3.2-5.3.4.
#
# This map is RADDR'S OWN JUDGMENT, not IANA data, and its provenance stays
# visibly separate: it is hand-authored here with its own version stamp, so
# neither stamp is evidence about the other. It must never become a column of
# `addr_registry()`, whose promise is the IANA data exactly as vendored.
#
# It is not vendored and not built by a data-raw/ script, for section 7.2's
# reason: a script that "builds" a table from a literal in its own source is
# ceremony around a constant. It follows `R/transition.R` and `R/codes.R`
# instead. (Section 5.3.4 says "in data-raw/" in one sentence and "follows
# R/transition.R's pattern" in the next; the pattern is the load-bearing half
# and the location was written before the address-space pair was vendored.)
#
# THE MAP IS KEYED ON THE BLOCK, NEVER ON `Name`. Name-keying is tempting --
# there are 40 distinct names over the 50 special-purpose records and no repeat
# today needs two levels -- but it fails on the property the map exists for: a
# NEW registry row reusing an existing name would classify itself with nobody
# reading it. `Name` is a mutable display string ("DS-Lite [RFC6333]" became
# "IPv4 Service Continuity Prefix [RFC7335]" with no change of prefix) while
# the block is the row's identity.
#
# EVERY BLOCK IS LISTED EXPLICITLY, including the 221 IPv4 /8s delegated to an
# RIR, which could have been derived from the `status` column. Deriving them
# would mean a /8 changing hands silently becomes `global`; listed, it fails
# the build and gets read by a human. Section 5.3.4's fourth test is exactly
# that requirement, and the verbosity here is the feature.

# Bump when a level is added or a block is re-pointed. Adding a level is an API
# addition; removing or re-pointing one is breaking (section 5.3.3).
raddr_category_version <- "2026-07-27"

# The vocabulary, in section 5.3.2's order. `unallocated` is the nineteenth and
# was added when the address-space pair was vendored: it names space IANA holds
# and has neither purposed nor delegated, which none of the other eighteen
# covers. It sits next to `global` because both are address-space answers.
raddr_category_levels <- c(
  "unspecified", "this_network", "loopback", "link_local", "multicast",
  "broadcast", "private", "shared", "documentation", "benchmarking",
  "future_use", "protocol", "anycast", "discard", "dummy", "discovery",
  "special", "unallocated", "global"
)

# Blocks that share an IANA `Name` but must NOT share a level, each with a
# reason. Empty today: `IPv4-IPv6 Translat.` was the only candidate and both
# its blocks are `protocol` now that the mechanism moved to `embedded_kind`.
# Kept because it is what makes the name arithmetic a mechanical check rather
# than a one-off observation.
raddr_category_name_splits <- character(0)

raddr_category_blocks <- list(
  unspecified = c("0.0.0.0/32", "::/128"),

  # RFC 1122 section 3.2.1.3's own term for the /8, and deliberately NOT
  # `unspecified` -- only the /32 is that.
  this_network = "0.0.0.0/8",

  loopback = c("127.0.0.0/8", "::1/128"),

  link_local = c("169.254.0.0/16", "fe80::/10"),

  # Neither of these is in a special-purpose registry. That absence is the
  # whole reason the address-space pair is vendored: a classifier derived from
  # the special-purpose registries alone has no multicast handling at all,
  # which is how ssrfcheck shipped CVE-2025-8267.
  multicast = c(
    "224.0.0.0/8", "225.0.0.0/8", "226.0.0.0/8", "227.0.0.0/8",
    "228.0.0.0/8", "229.0.0.0/8", "230.0.0.0/8", "231.0.0.0/8",
    "232.0.0.0/8", "233.0.0.0/8", "234.0.0.0/8", "235.0.0.0/8",
    "236.0.0.0/8", "237.0.0.0/8", "238.0.0.0/8", "239.0.0.0/8",
    "ff00::/8"
  ),

  broadcast = "255.255.255.255/32",

  # ULA is `private` because cross-family normalization is the level's job, and
  # the consumer settles it: ssrfr ADR-001 section 2.1 makes the unblocked
  # fc00::/7 its motivating defect. That fc00::/8 (L=0) has no defining
  # specification -- only fd00::/8 is real, RFC 4193 section 3.1 -- is a
  # classify code at strength = unspecified, not a category. `private` does
  # NOT imply "valid ULA".
  private = c("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"),

  shared = "100.64.0.0/10",

  documentation = c(
    "192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24",
    "2001:db8::/32", "3fff::/20"
  ),

  benchmarking = c("198.18.0.0/15", "2001:2::/48"),

  # RFC 1112 section 4's own word for 240/4. The address-space registry spells
  # the same space as sixteen /8s, all "Future use".
  future_use = c(
    "240.0.0.0/4",
    "240.0.0.0/8", "241.0.0.0/8", "242.0.0.0/8", "243.0.0.0/8",
    "244.0.0.0/8", "245.0.0.0/8", "246.0.0.0/8", "247.0.0.0/8",
    "248.0.0.0/8", "249.0.0.0/8", "250.0.0.0/8", "251.0.0.0/8",
    "252.0.0.0/8", "253.0.0.0/8", "254.0.0.0/8", "255.0.0.0/8"
  ),

  # IETF protocol assignments, service continuity, and the wrapper prefixes.
  #
  # The last three are the mechanism blocks, and section 5.3.2 settles them by
  # its own worked example rather than by name: 64:ff9b::/96 is category =
  # protocol with embedded_kind = nat64_wk, and ::ffff:0:0/96, 2001::/32 and
  # 2002::/16 are the same kind of thing -- an IETF-defined wrapper prefix
  # carrying an embedded IPv4. The mechanism is stated precisely in
  # `embedded_kind`; it is not a category. `special` is the wrong home: 5.3.2
  # enumerates what that covers, and these are not in the list.
  protocol = c(
    "192.0.0.0/24", "192.0.0.0/29", "2001::/23",
    "64:ff9b::/96", "64:ff9b:1::/48",
    "::ffff:0:0/96", "2001::/32", "2002::/16"
  ),

  # Addressing STYLE, never reachability. The tempting "globally reachable
  # service anycast" reading is falsified by the registry itself:
  # 192.88.99.2/32 is Globally Reachable = False, and 192.88.99.0/24 has no
  # policy values at all. AS112 and AMT fold in -- `name` already says
  # "AS112-v4" and "AMT" better than a level can.
  anycast = c(
    "192.0.0.9/32", "192.0.0.10/32", "192.31.196.0/24", "192.52.193.0/24",
    "192.88.99.0/24", "192.88.99.2/32", "192.175.48.0/24",
    "2001:1::1/128", "2001:1::2/128", "2001:1::3/128",
    "2001:3::/32", "2001:4:112::/48", "2620:4f:8000::/48"
  ),

  discard = "100::/64",

  dummy = c("192.0.0.8/32", "100:0:0:1::/64"),

  discovery = c("192.0.0.170/32", "192.0.0.171/32"),

  # An assignment, not a fallthrough: blocks with no question a short word
  # answers. A new unclassified registry row still fails the build. `identifier`
  # was proposed to cover these together and REJECTED -- it would lump RFC 7343
  # cryptographic host identifiers with RFC 8986 routing segment identifiers.
  special = c("2001:10::/28", "2001:20::/28", "2001:30::/28", "5f00::/16"),

  # Space IANA holds and has neither purposed nor delegated. IANA's own string
  # is "Reserved by IETF", but `reserved` is precisely the word this vocabulary
  # deleted: it means four different things across the ecosystem, and it would
  # shadow the `reserved_by_protocol` column in the same record. Measured
  # 2026-07-27, the ecosystem bears that out -- CPython `ipaddress` and R
  # `ipaddress` both call this space `is_reserved` while ALSO reporting
  # is_global = TRUE for it, and ipaddr.js labels it plain `unicast`, the same
  # label it gives real global unicast. Three tools, three answers, and all
  # three assert something false about 4000::1.
  #
  # `global` would be that same false statement: IANA's own note on 2000::/3
  # limits unicast assignment to 2000::/3, so calling the other seven eighths
  # globally reachable asserts reachability for space nobody may use.
  #
  # The per-row facts stay in the registry's own words. 200::/7's deprecating
  # RFC 4048 and fec0::/10's RFC 3879 live in the address-space `notes` column,
  # which is why P9 forbids collapsing these sixteen rows to ::/3-style
  # aggregates -- R `ipaddress` does exactly that and loses both citations.
  unallocated = c(
    "::/8", "100::/8", "200::/7", "400::/6", "800::/5", "1000::/4",
    "4000::/3", "6000::/3", "8000::/3", "a000::/3", "c000::/3",
    "e000::/4", "f000::/5", "f800::/6", "fe00::/9", "fec0::/10"
  ),

  # Delegated to an RIR (IANA status ALLOCATED or LEGACY), plus the one IPv6
  # block IANA actually assigns unicast from. This is the only level that means
  # "an ordinary host may live here", and it is backed by a registry row rather
  # than inferred from an absence.
  global = c(
    "1.0.0.0/8", "2.0.0.0/8", "3.0.0.0/8", "4.0.0.0/8", "5.0.0.0/8",
    "6.0.0.0/8", "7.0.0.0/8", "8.0.0.0/8", "9.0.0.0/8", "11.0.0.0/8",
    "12.0.0.0/8", "13.0.0.0/8", "14.0.0.0/8", "15.0.0.0/8", "16.0.0.0/8",
    "17.0.0.0/8", "18.0.0.0/8", "19.0.0.0/8", "20.0.0.0/8", "21.0.0.0/8",
    "22.0.0.0/8", "23.0.0.0/8", "24.0.0.0/8", "25.0.0.0/8", "26.0.0.0/8",
    "27.0.0.0/8", "28.0.0.0/8", "29.0.0.0/8", "30.0.0.0/8", "31.0.0.0/8",
    "32.0.0.0/8", "33.0.0.0/8", "34.0.0.0/8", "35.0.0.0/8", "36.0.0.0/8",
    "37.0.0.0/8", "38.0.0.0/8", "39.0.0.0/8", "40.0.0.0/8", "41.0.0.0/8",
    "42.0.0.0/8", "43.0.0.0/8", "44.0.0.0/8", "45.0.0.0/8", "46.0.0.0/8",
    "47.0.0.0/8", "48.0.0.0/8", "49.0.0.0/8", "50.0.0.0/8", "51.0.0.0/8",
    "52.0.0.0/8", "53.0.0.0/8", "54.0.0.0/8", "55.0.0.0/8", "56.0.0.0/8",
    "57.0.0.0/8", "58.0.0.0/8", "59.0.0.0/8", "60.0.0.0/8", "61.0.0.0/8",
    "62.0.0.0/8", "63.0.0.0/8", "64.0.0.0/8", "65.0.0.0/8", "66.0.0.0/8",
    "67.0.0.0/8", "68.0.0.0/8", "69.0.0.0/8", "70.0.0.0/8", "71.0.0.0/8",
    "72.0.0.0/8", "73.0.0.0/8", "74.0.0.0/8", "75.0.0.0/8", "76.0.0.0/8",
    "77.0.0.0/8", "78.0.0.0/8", "79.0.0.0/8", "80.0.0.0/8", "81.0.0.0/8",
    "82.0.0.0/8", "83.0.0.0/8", "84.0.0.0/8", "85.0.0.0/8", "86.0.0.0/8",
    "87.0.0.0/8", "88.0.0.0/8", "89.0.0.0/8", "90.0.0.0/8", "91.0.0.0/8",
    "92.0.0.0/8", "93.0.0.0/8", "94.0.0.0/8", "95.0.0.0/8", "96.0.0.0/8",
    "97.0.0.0/8", "98.0.0.0/8", "99.0.0.0/8", "100.0.0.0/8", "101.0.0.0/8",
    "102.0.0.0/8", "103.0.0.0/8", "104.0.0.0/8", "105.0.0.0/8",
    "106.0.0.0/8", "107.0.0.0/8", "108.0.0.0/8", "109.0.0.0/8",
    "110.0.0.0/8", "111.0.0.0/8", "112.0.0.0/8", "113.0.0.0/8",
    "114.0.0.0/8", "115.0.0.0/8", "116.0.0.0/8", "117.0.0.0/8",
    "118.0.0.0/8", "119.0.0.0/8", "120.0.0.0/8", "121.0.0.0/8",
    "122.0.0.0/8", "123.0.0.0/8", "124.0.0.0/8", "125.0.0.0/8",
    "126.0.0.0/8", "128.0.0.0/8", "129.0.0.0/8", "130.0.0.0/8",
    "131.0.0.0/8", "132.0.0.0/8", "133.0.0.0/8", "134.0.0.0/8",
    "135.0.0.0/8", "136.0.0.0/8", "137.0.0.0/8", "138.0.0.0/8",
    "139.0.0.0/8", "140.0.0.0/8", "141.0.0.0/8", "142.0.0.0/8",
    "143.0.0.0/8", "144.0.0.0/8", "145.0.0.0/8", "146.0.0.0/8",
    "147.0.0.0/8", "148.0.0.0/8", "149.0.0.0/8", "150.0.0.0/8",
    "151.0.0.0/8", "152.0.0.0/8", "153.0.0.0/8", "154.0.0.0/8",
    "155.0.0.0/8", "156.0.0.0/8", "157.0.0.0/8", "158.0.0.0/8",
    "159.0.0.0/8", "160.0.0.0/8", "161.0.0.0/8", "162.0.0.0/8",
    "163.0.0.0/8", "164.0.0.0/8", "165.0.0.0/8", "166.0.0.0/8",
    "167.0.0.0/8", "168.0.0.0/8", "169.0.0.0/8", "170.0.0.0/8",
    "171.0.0.0/8", "172.0.0.0/8", "173.0.0.0/8", "174.0.0.0/8",
    "175.0.0.0/8", "176.0.0.0/8", "177.0.0.0/8", "178.0.0.0/8",
    "179.0.0.0/8", "180.0.0.0/8", "181.0.0.0/8", "182.0.0.0/8",
    "183.0.0.0/8", "184.0.0.0/8", "185.0.0.0/8", "186.0.0.0/8",
    "187.0.0.0/8", "188.0.0.0/8", "189.0.0.0/8", "190.0.0.0/8",
    "191.0.0.0/8", "192.0.0.0/8", "193.0.0.0/8", "194.0.0.0/8",
    "195.0.0.0/8", "196.0.0.0/8", "197.0.0.0/8", "198.0.0.0/8",
    "199.0.0.0/8", "200.0.0.0/8", "201.0.0.0/8", "202.0.0.0/8",
    "203.0.0.0/8", "204.0.0.0/8", "205.0.0.0/8", "206.0.0.0/8",
    "207.0.0.0/8", "208.0.0.0/8", "209.0.0.0/8", "210.0.0.0/8",
    "211.0.0.0/8", "212.0.0.0/8", "213.0.0.0/8", "214.0.0.0/8",
    "215.0.0.0/8", "216.0.0.0/8", "217.0.0.0/8", "218.0.0.0/8",
    "219.0.0.0/8", "220.0.0.0/8", "221.0.0.0/8", "222.0.0.0/8",
    "223.0.0.0/8",
    "2000::/3"
  )
)

# Flattened to block -> level. Five blocks appear in both vendored pairs
# (0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, fc00::/7, fe80::/10); each is listed
# once here, so the two layers cannot disagree about them by construction.
raddr_category_map <- unlist(
  lapply(raddr_category_levels, function(level) {
    blocks <- raddr_category_blocks[[level]]
    stats::setNames(rep(level, length(blocks)), blocks)
  })
)

#' raddr's block to category map
#'
#' Returns raddr's own mapping from registry block to `category` level, as a
#' data frame of `block` and `category`. This is **not** IANA data: it is
#' raddr's vocabulary, hand-authored and stamped separately, so that neither
#' stamp is evidence about the other.
#'
#' @section Why this is not a column of `addr_registry()`:
#'
#' [addr_registry()]'s promise is the IANA data *exactly as vendored*. A
#' judgment column sitting beside the five IANA policy logicals would blur the
#' one distinction this package exists to keep: what a registry says, versus
#' what raddr concluded. P9 permits the map because it forbids hand-transcribing
#' an upstream fact when an authoritative file exists, and `category` has no
#' upstream value to preserve.
#'
#' @section Descriptive, not a policy input:
#'
#' `category` describes; it does not decide. Do **not** build a deny-list of
#' level names on it. `ipaddr.js` demonstrates both failure modes: label names
#' drift across versions (`deprecated` became `deprecatedOrchid`), and consumers
#' deny by named list, so a newly added label becomes a bypass.
#'
#' raddr's answer is not a smaller vocabulary -- that only postpones the bypass.
#' Policy belongs on the five IANA columns, the classify codes, and the
#' embeddings, all of which are three-valued and registry- or RFC-sourced.
#' There is deliberately no "everything that is not `global`" helper: it would
#' be wrong on `64:ff9b::a00:1`, a block IANA marks `Globally Reachable = True`
#' that embeds `10.0.0.1`.
#'
#' @section Keyed on the block, never on the name:
#'
#' A registry `Name` is a mutable display string -- "DS-Lite \[RFC6333\]" became
#' "IPv4 Service Continuity Prefix \[RFC7335\]" with no change of prefix -- and
#' a *new* row reusing an existing name would classify itself with nobody
#' reading it. The block is the row's identity.
#'
#' @return A data frame of 322 rows, with columns `block` and `category`. Fewer
#'   rows than the 327 vendored registry rows, because five blocks appear in
#'   both vendored pairs and are mapped once.
#'
#' @seealso [addr_registry()] and [addr_address_space()] for the data being
#'   mapped, and [addr_category_version()] for this map's own stamp.
#'
#' @examples
#' map <- addr_category_map()
#' table(map$category)
#'
#' # The space IANA holds and has neither purposed nor delegated
#' map[map$category == "unallocated", ]
#'
#' @export
addr_category_map <- function() {
  data.frame(
    block = names(raddr_category_map),
    category = unname(raddr_category_map),
    stringsAsFactors = FALSE
  )
}

#' Provenance of raddr's category map
#'
#' Reports the version stamp of the hand-authored block to category map. This
#' is raddr's own judgment and changes on raddr's schedule, so it is stamped
#' separately from the vendored IANA snapshots
#' ([addr_registry_version()], [addr_address_space_version()]): one date across
#' both would make each assert something about a table it says nothing about.
#'
#' There is deliberately no `addr_category_outdated()`. The map does not go
#' stale on a clock -- it goes stale when a registry row appears that it has no
#' entry for, and that fails the build rather than aging quietly.
#'
#' @return A length-1 `character` `"YYYY-MM-DD"` date.
#'
#' @seealso [addr_category_map()] for the map itself.
#'
#' @examples
#' addr_category_version()
#'
#' @export
addr_category_version <- function() {
  raddr_category_version
}
