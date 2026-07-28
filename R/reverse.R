# Reverse DNS pointer names. See docs/architecture.md section 6.2.1, and the
# research note docs/research/08-encoding-reverse.md, whose first half is a
# specification for this file.
#
# Two trees, one function. RFC 1035 section 3.5 defines `in-addr.arpa` and
# RFC 3596 section 2.5 defines `ip6.arpa`; the suffix says which, because the
# labels themselves cannot (research 08 gotcha 9 -- a label `9` is valid in both
# trees and means octet 9 in one and nibble 9 in the other).
#
# --- the two granularities are different, and that is the classic bug ---------
#
# IPv4 reverses whole octets and IPv6 reverses 4-bit nibbles (research 08
# gotcha 1). Reversing IPv6 by octet produces a name of the right length, made
# of legal labels, that points somewhere else -- which is why the IPv6 branch
# never touches the octet order it is handed and expands each octet into its two
# nibbles low first.
#
# --- and it is never built from the text form --------------------------------
#
# An `ip6.arpa` name is always 32 labels: no `::`, no leading-zero suppression,
# no mixed 4-in-6 spelling (research 08 gotcha 2). Every one of those is
# something the text renderers in R/format.R are required to do, so this file
# reads the octets rather than reusing `addr_format()` or `addr_expand()`.

# The 256 octet values rendered as the two labels they contribute, low nibble
# first: 0xab becomes "b.a". Sixteen of these joined with "." is the whole
# 32-label body, which halves the width of the `paste()` that assembles it.
#
# Lowercase because RFC 5952 section 4.3 requires it of address text and
# nothing in RFC 3596 disagrees; comparison is case-insensitive either way
# (RFC 1035 section 3.1), so this is a choice about emission only.
octet_nibbles <- vapply(
  0:255,
  function(v) sprintf("%x.%x", v %% 16, v %/% 16),
  character(1L)
)

# RFC 1035 section 3.5: "a decimal value in the range 0-255", with "leading
# zeros omitted except in the case of a zero octet which is represented by a
# single zero". `as.character()` on an integer is exactly that rule, so the
# table is the rule.
octet_decimal <- as.character(0:255)

#' Reverse DNS pointer name
#'
#' The name that holds an address's `PTR` record: `in-addr.arpa` for IPv4
#' (RFC 1035 §3.5), `ip6.arpa` for IPv6 (RFC 3596 §2.5).
#'
#' @section How the name is built:
#'
#' IPv4 reverses whole **octets** and IPv6 reverses 4-bit **nibbles**, each
#' least significant first, and the two are not interchangeable -- reversing an
#' IPv6 address by octet yields a plausible-looking name that points somewhere
#' else. RFC 1035 §3.5 gives the reason for the reversal: it "allows zones to be
#' delegated which are exactly one network of address space".
#'
#' \preformatted{
#' 10.2.0.52    ->  52.0.2.10.in-addr.arpa.
#' 2001:db8::1  ->  1.0.0. ... .0.8.b.d.0.1.0.0.2.ip6.arpa.
#' }
#'
#' @section An `ip6.arpa` name is always 32 labels:
#'
#' No `::`, no suppressed leading zeros, no mixed 4-in-6 spelling. `::1` has 32
#' labels, 31 of them `0`. This is the opposite of the text form -- see
#' [addr_format()] -- and it is why the name is built from the bits rather than
#' from the rendered address. An `in-addr.arpa` name is always 4 labels, in
#' decimal, with leading zeros omitted (RFC 1035 §3.5: "leading zeros omitted
#' except in the case of a zero octet which is represented by a single zero").
#'
#' @section The trailing dot, and the case:
#'
#' The name is emitted **fully qualified**, with the trailing dot that stands
#' for the root label (RFC 1035 §3.1). `1.2.0.192.in-addr.arpa` and
#' `1.2.0.192.in-addr.arpa.` denote the same name but are not the same string,
#' so raddr picks the unambiguous one.
#'
#' Hex labels are lowercase. Comparison in the DNS is case-insensitive
#' (RFC 1035 §3.1: "Name servers and resolvers must compare labels in a
#' case-insensitive manner"), so `B.A.9` and `b.a.9` are the same name; the
#' lowercase choice follows RFC 5952 §4.3.
#'
#' @section The 4-in-6 form gets the mechanical answer:
#'
#' No RFC says whether `::ffff:192.0.2.1` should map into `ip6.arpa` or into
#' `1.2.0.192.in-addr.arpa.` raddr returns the **`ip6.arpa`** name, because the
#' address is an IPv6 address and that is the mechanical reading of RFC 3596
#' §2.5. The *useful* name is often the `in-addr.arpa` one, because that is
#' where the data actually lives -- ask for it by naming the embedded address
#' directly, which is the same choice [addr_to_bytes()] makes about width.
#'
#' @section The zone is not part of the name:
#'
#' A zone ID is dropped, silently and by design. It is strictly local to a node
#' (RFC 4007 §6), so it has no meaning in a DNS name, and there is nowhere in
#' the `ip6.arpa` grammar to put it. Note that a zoned address is *rendered*,
#' not rejected: Python's `IPv6Address.reverse_pointer` raises on one, which is
#' a bug in its renderer rather than a rule about zones.
#'
#' @section What this function is not:
#'
#' \itemize{
#'   \item **Not a resolver.** raddr is offline. RFC 8501 §1.2 notes that
#'     pre-populating an IPv6 reverse zone is impractical -- "2^80 possible
#'     addresses could be configured in a single /48 zone alone" -- and §2.1
#'     records `NXDOMAIN` as a legitimate answer. A correct name is not a
#'     resolvable name.
#'   \item **Not reversible here.** There is no pointer-to-address function,
#'     because a pointer name does not have to name an address:
#'     `10.in-addr.arpa.` is a /8 (RFC 1035 §3.5's own gateway example), so the
#'     general answer is a prefix, and raddr has no prefix type yet.
#'   \item **Not `ip6.int`.** Deprecated by RFC 3152 §2 and retired by RFC 4159
#'     ("the DNS domain 'ip6.int' should no longer be used"). raddr never emits
#'     it.
#'   \item **Not a bitstring label.** RFC 2673 and RFC 2874 were reclassified
#'     Experimental by RFC 3363, whose §3 concluded that the hexadecimal text
#'     form "appears to be capable of expressing all of the delegation schemes
#'     that we expect to be used".
#'   \item **Not an RFC 2317 name.** Classless `in-addr.arpa` delegation is an
#'     operator convention -- the block boundary and even the separator
#'     character are choices (RFC 2317 §4) -- so those names are generate-only
#'     and cannot claim to round-trip.
#' }
#'
#' @param x A `raddr_address` vector.
#'
#' @return A character vector the same length as `x`, `NA` for missing
#'   addresses.
#'
#' @examples
#' a <- addr_pton(c("10.2.0.52", "2001:db8::1", "::ffff:192.0.2.1"))
#' addr_reverse_pointer(a)
#'
#' # RFC 1035 section 3.5's own example
#' addr_reverse_pointer(addr_pton("10.2.0.52"))
#'
#' # Always 32 labels for IPv6, however short the text form is
#' lengths(strsplit(addr_reverse_pointer(addr_pton("::1")), ".", fixed = TRUE))
#'
#' # The zone is not part of a DNS name
#' addr_reverse_pointer(addr_pton(c("fe80::1", "fe80::1%eth0")))
#'
#' @export
addr_reverse_pointer <- function(x) {
  check_raddr_address(x)
  family <- field(x, "family")
  out <- rep(NA_character_, length(family))
  if (!length(family)) {
    return(out)
  }

  # The family picks the tree, exactly as it picks the width in R/encoding.R,
  # and a missing address is in neither mask and stays NA.
  sel <- family_masks(family)
  o <- addr_octets(x)

  if (any(sel$v4)) {
    q <- o[v4_octet_rows, sel$v4, drop = FALSE]
    out[sel$v4] <- paste(
      octet_decimal[q[4L, ] + 1L],
      octet_decimal[q[3L, ] + 1L],
      octet_decimal[q[2L, ] + 1L],
      octet_decimal[q[1L, ] + 1L],
      "in-addr.arpa.",
      sep = "."
    )
  }

  if (any(sel$v6)) {
    wide <- o[, sel$v6, drop = FALSE]
    # Octets last to first, each contributing its low nibble then its high one.
    # The suffix carries the trailing dot, so the whole name is one `paste()`.
    pieces <- lapply(16:1, function(r) octet_nibbles[wide[r, ] + 1L])
    out[sel$v6] <- do.call(paste, c(pieces, list("ip6.arpa.", sep = ".")))
  }

  out
}
