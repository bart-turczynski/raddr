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
#'     address; and a digitless `0x` is tolerated in any part but the last.}
#' }
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
#' reason codes -- is `addr_parse()`, which is not written yet.
#'
#' IPv6 literals are also not written yet, and are currently rejected by all
#' six. The package is unreleased.
#'
#' @section Provenance:
#'
#' The reality dialects and both compositions were measured against Apple libc
#' and curl 7.1.0 / libcurl 8.14.1 on macOS Darwin 25.4.0 arm64 on 2026-07-26.
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
#' @name dialects
NULL

#' @rdname dialects
#' @export
addr_strict <- function(x) {
  parse_dialect(x, rules_strict)
}

#' @rdname dialects
#' @export
addr_whatwg <- function(x) {
  parse_dialect(x, rules_whatwg)
}

#' @rdname dialects
#' @export
addr_pton <- function(x) {
  parse_dialect(x, rules_pton)
}

#' @rdname dialects
#' @export
addr_aton <- function(x) {
  parse_dialect(x, rules_aton)
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
  x[grepl("[ \t\r\n\v\f]", x)] <- NA_character_
  compose_dialects(addr_pton(x), addr_aton(x))
}

#' @rdname dialects
#' @export
addr_curl <- function(x) {
  compose_dialects(addr_aton(x), addr_pton(x))
}
