# The six dialects. See docs/architecture.md sections 3.1 and 3.2.

#' Read an address literal under one dialect
#'
#' Six functions, one per dialect. They exist because standards and
#' implementations disagree about what an IP address literal means, and raddr's
#' answer is to show you all of the readings rather than pick one.
#'
#' The dialect is chosen by calling a named function. There is deliberately no
#' `strict = FALSE` argument and no dialect knob buried in `...`: a named
#' function is harder to helpfully default away than an argument is.
#'
#' @section On paper:
#'
#' \describe{
#'   \item{`addr_strict()`}{The RFC dotted-quad grammar: exactly four decimal
#'     octets, no leading zeros, no hex, no octal, no short form. This is what
#'     Python's `ipaddress`, Go and Rust accept. It is **not** what
#'     `inet_pton()` accepts, although the two are often conflated.}
#'   \item{`addr_whatwg()`}{The WHATWG URL host parser -- what browsers do. Hex
#'     and octal parts, one to four parts with the last filling the remainder,
#'     and one trailing dot dropped, so `1.2.3.` is `1.2.0.3`. Values above
#'     2^32 - 1 are rejected rather than wrapped.}
#' }
#'
#' @section In reality:
#'
#' \describe{
#'   \item{`addr_pton()`}{POSIX `inet_pton()`. Four decimal parts, leading zeros
#'     allowed and ignored, so `0177.0.0.1` is **177.0.0.1** and not
#'     `127.0.0.1`. This is the one dialect whose behavior varies by platform;
#'     raddr models Apple libc, and glibc and musl are unverified.}
#'   \item{`addr_aton()`}{BSD `inet_aton()`. Hex, octal and short forms, and
#'     three quirks worth knowing: a whole-host number is truncated to 32 bits
#'     rather than rejected, so `4294967296` is `0.0.0.0`; parsing stops at the
#'     first whitespace character and ignores the rest, so `1.2.3.4 junk` is an
#'     address; and a digitless `0x` is tolerated in any part but the last.
#'     `inet_aton()` is `AF_INET` by signature, so it rejects **every** IPv6
#'     literal.}
#' }
#'
#' @section IPv6:
#'
#' The shape of the disagreement inverts. The two paper dialects agree about
#' IPv6 on every measured input, and all of the divergence is on the reality
#' side:
#'
#' \describe{
#'   \item{Leading zeros}{A hextet is four hex digits on paper. Apple
#'     `inet_pton()` counts only the *significant* four and lets the zeros run
#'     as wide as they like, so `0000000000001::` is `1::` where `strict` and
#'     `whatwg` reject. The dotted-quad tail splits the same way.}
#'   \item{The zone ID}{The paper dialects have none: RFC 4291's grammar does
#'     not admit one and the WHATWG parser rejects `%`. The reality dialects
#'     accept a zone on any address and resolve nothing, so `%bogus0` parses.
#'     The zone is stored beside the bits and read with [addr_zone()]; it never
#'     enters the address and never affects equality.}
#'   \item{`fe80::/10`}{`addr_getaddrinfo()` lifts the second hextet of a
#'     link-local address out into the zone and clears it, zone ID or not, so
#'     `fe80:abcd::1` is `fe80::1` with zone `43981` -- while `addr_pton()`
#'     leaves it alone. One string, one machine, two different hosts.}
#' }
#'
#' Apple `inet_pton()` also does the reverse, writing a resolved interface index
#' *into* the second hextet. raddr deliberately does not reproduce that: the
#' index comes from the host's interface table, so it is not a function of the
#' input, and raddr is pure and offline.
#'
#' @section Compositions:
#'
#' The last two are precedence orderings over the same two reality primitives,
#' not parsers in their own right:
#'
#' \describe{
#'   \item{`addr_getaddrinfo()`}{`pton`, falling back to `aton`. Whitespace is
#'     the one place the composition leaks: `getaddrinfo()` rejects an input
#'     containing whitespace outright, where bare `aton` would accept it.}
#'   \item{`addr_curl()`}{`aton`, falling back to `pton` -- the opposite
#'     precedence, which is the whole reason `192.0.048.1` reaches a host under
#'     curl that a browser refuses to dial.}
#' }
#'
#' @section What these do not give you:
#'
#' These are shortcuts for a caller who has already chosen a dialect. They
#' return a bare address, so a rejected input comes back as `NA` with no reason
#' attached. The total, outcome-bearing form -- every reading at once, with the
#' reason codes -- is [addr_parse()], and its result is what [addr_reading()]
#' reads a single dialect back out of.
#'
#' @section Provenance:
#'
#' The reality dialects and both compositions were measured against Apple libc
#' and libcurl 8.14.1 on macOS Darwin 25.4.0 arm64 on 2026-07-26.
#' `data-raw/oracle-ipv4.py` regenerates the measurements, and
#' `tests/testthat/test-ipv4.R` holds them as the divergence table.
#'
#' @param x A character vector of address literals.
#'
#' @return A `raddr_address` vector, `NA` where the dialect rejects the input.
#'
#' @examples
#' # One string, one machine, three different hosts
#' addr_strict("0177.0.0.1")
#' addr_whatwg("0177.0.0.1")
#' addr_pton("0177.0.0.1")
#'
#' # curl reaches a host a browser refuses to dial
#' addr_whatwg("192.0.048.1")
#' addr_curl("192.0.048.1")
#'
#' # inet_aton truncates a whole-host number instead of rejecting it
#' addr_aton("4294967296")
#'
#' # Two libc entry points, one machine, two different IPv6 hosts
#' addr_pton("fe80:abcd::1")
#' addr_getaddrinfo("fe80:abcd::1")
#'
#' # The zone travels beside the bits, so it does not affect equality
#' addr_pton("fe80::1%lo0") == addr_pton("fe80::1%en0")
#' addr_zone(addr_pton("fe80::1%lo0"))
#'
#' @name dialects
NULL

#' @rdname dialects
#' @export
addr_strict <- function(x) {
  parse_dialect(x, rules_strict, rules_v6_paper)
}

#' @rdname dialects
#' @export
addr_whatwg <- function(x) {
  parse_dialect(x, rules_whatwg, rules_v6_paper)
}

#' @rdname dialects
#' @export
addr_pton <- function(x) {
  parse_dialect(x, rules_pton, rules_v6_libc)
}

# `inet_aton` is AF_INET by signature and has no IPv6 reading at all, so its
# IPv6 rule set is deliberately absent rather than empty. Measured rather than
# assumed, because both compositions below depend on it: see the `aton` column
# of tests/testthat/fixtures/ipv6-oracle.csv.
#' @rdname dialects
#' @export
addr_aton <- function(x) {
  parse_dialect(x, rules_aton, NULL)
}

# The compositions are written as compositions on purpose (section 3.2): if the
# precedence changes upstream, the fix here is swapping two arguments rather
# than editing a parser.
compose_dialects <- function(first, second) {
  missing <- is.na(addr_family(first))
  if (!any(missing)) {
    return(first)
  }
  vctrs::vec_assign(first, missing, vctrs::vec_slice(second, missing))
}

#' @rdname dialects
#' @export
addr_getaddrinfo <- function(x) {
  x <- vec_cast(x, character())
  # getaddrinfo() rejects an input containing whitespace before either
  # primitive sees it, which is where the composition stops being exactly
  # "pton then aton" [verified 2026-07-26].
  #
  # The gate covers the address, not the zone ID: "fe80::1%lo0 " is accepted and
  # "fe80::1 %lo0" is not [verified 2026-07-26]. An IPv4 literal carries no "%",
  # so this is the same gate it always was for IPv4.
  x[grepl("[ \t\r\n\v\f]", sub("%.*$", "", x))] <- NA_character_
  gai_extract_scope(compose_dialects(addr_pton(x), addr_aton(x)))
}

# The second place the composition leaks, and it is IPv6-only.
#
# Apple's getaddrinfo runs the KAME embedding in reverse: for an address in
# fe80::/10 it lifts the second hextet out into `sin6_scope_id` and clears it
# from the bytes, whether or not a zone ID was written. So `fe80:abcd::1` is
# `fe80::1` with zone 43981 to getaddrinfo and `fe80:abcd::1` with no zone to
# `inet_pton` -- one string, one machine, two different hosts, which is the IPv6
# counterpart of what `0177.0.0.1` does for IPv4 [verified 2026-07-26].
#
# raddr models this and does *not* model inet_pton's forward fold, and the
# difference between the two is the point: this transform is a pure function of
# the input, where the forward fold reads the host's interface table (section
# 3.5). An explicit zone ID still wins; the hextet is cleared either way.
gai_extract_scope <- function(a) {
  family <- field(a, "family")
  w1 <- widen_word(field(a, "w1"))
  # fe80::/10, RFC 4291 section 2.5.6, as the first 32 bits: 0xFE800000 through
  # 0xFEBFFFFF inclusive. The /10 is what Apple's resolver tests, so the /10 is
  # what this models -- RFC 4291 section 2.5.6 also fixes the conformant format
  # at fe80::/64 with 54 zero bits between, but a stricter gate here would stop
  # reproducing the behaviour this function exists to reproduce. The citation
  # sources the BOUNDS; it is not a claim that the gate is conformance-checking.
  link_local <- !is.na(family) & family == "v6" &
    w1 >= 4269801472 & w1 <= 4273995775
  scope <- w1 %% 65536
  at <- which(link_local & scope != 0)
  if (!length(at)) {
    return(a)
  }
  zone <- field(a, "zone")
  zone[at] <- ifelse(is.na(zone[at]), as.character(scope[at]), zone[at])
  w1[at] <- w1[at] - scope[at]

  new_raddr_address(
    w1 = ipv4_word(w1),
    w2 = field(a, "w2"),
    w3 = field(a, "w3"),
    w4 = field(a, "w4"),
    family = family,
    zone = zone
  )
}

#' @rdname dialects
#' @export
addr_curl <- function(x) {
  compose_dialects(addr_aton(x), addr_pton(x))
}
