# Encodings, reverse pointers and round-trip hazards

Primary-source research for `raddr`. Scope: representing an IP address in forms
*other* than its usual textual notation — reverse-DNS pointer names, raw bytes,
integers, hex, binary, prefix notation, and address literals embedded in URIs.

Every claim is cited by RFC number and section. Items I could not substantiate
from a primary source are marked `UNVERIFIED`.

Sources consulted: RFC 1035, RFC 1886, RFC 2317, RFC 2673, RFC 2874, RFC 3152,
RFC 3363, RFC 3364, RFC 3596, RFC 3986, RFC 4007, RFC 4038, RFC 4159, RFC 4291,
RFC 4632, RFC 5952, RFC 6052, RFC 6874, RFC 8501, RFC 9844, and the IANA `.arpa`
zone management page.

---

## Reverse pointers

### IPv4 — `in-addr.arpa` (RFC 1035 §3.5)

RFC 1035 §3.5 defines the special domain: *"The domain begins at IN-ADDR.ARPA and
has a substructure which follows the Internet addressing structure."*

Construction rules, exactly as specified:

1. **One label per octet.** RFC 1035 §3.5: *"Each label represents one octet of an
   Internet address, and is expressed as a character string for a decimal value in
   the range 0-255."*
2. **Leading zeros are omitted**, except that a zero octet is a single `0`. RFC 1035
   §3.5: *"(with leading zeros omitted except in the case of a zero octet which is
   represented by a single zero)."* So `010` is **not** a legal label; `10` is.
3. **Octet order is reversed** (least significant first). RFC 1035 §3.5: *"Thus data
   for Internet address 10.2.0.52 is located at domain name 52.0.2.10.IN-ADDR.ARPA.
   The reversal, though awkward to read, allows zones to be delegated which are
   exactly one network of address space."*
4. **Suffix** `in-addr.arpa`.
5. **Trailing dot.** A domain name in presentation form is fully qualified when it
   ends in the root label. RFC 1035 §3.1: *"Since every domain name ends with the
   null label of the root, a domain name is terminated by a length byte of zero."*
   In master-file/presentation syntax the explicit trailing `.` denotes that root
   label. RFC 1035 §3.5's own example prints without a trailing dot in prose but
   the master-file examples in §3.6.2 use fully-qualified names with the dot.
   `raddr` should emit the trailing dot (unambiguously absolute) and accept input
   with or without it.
6. **Case-insensitive on comparison.** RFC 1035 §3.1: *"Name servers and resolvers
   must compare labels in a case-insensitive manner (i.e., A=a)."* Digits are
   unaffected for IPv4, but this matters for IPv6 (below).

Worked examples:

| Address | Pointer name |
| --- | --- |
| `10.2.0.52` | `52.0.2.10.in-addr.arpa.` (RFC 1035 §3.5, verbatim example) |
| `192.0.2.1` | `1.2.0.192.in-addr.arpa.` |
| `0.0.0.0` | `0.0.0.0.in-addr.arpa.` |
| `255.255.255.255` | `255.255.255.255.in-addr.arpa.` |
| `127.0.0.1` | `1.0.0.127.in-addr.arpa.` |

Partial (prefix) pointers are meaningful for whole-octet boundaries: RFC 1035 §3.5
notes *"a program which wanted to locate gateways on net 10 would originate a query
of the form QTYPE=PTR, QCLASS=IN, QNAME=10.IN-ADDR.ARPA."* So `10.0.0.0/8` →
`10.in-addr.arpa.`, `/16` → two labels, `/24` → three labels.

### IPv4 classless delegation — RFC 2317

RFC 2317 solves delegating **fewer than 256 addresses**, i.e. prefixes longer than
/24, which do not land on a label boundary.

- Mechanism (RFC 2317 §4): create extra delegation points and point the individual
  leaf names at them with `CNAME` records. *"Since a single zone can only be
  delegated once, we need more points to do delegation on to solve the problem
  above."*
- Recommended sub-zone name (RFC 2317 §4): first address of the block, `/`, prefix
  length. The RFC's own example:

  ```
  0/25            NS      ns.A.domain.
  129             CNAME   129.128/26.2.0.192.in-addr.arpa.
  ```

- The `/` is legal in a DNS label. RFC 2317 §4: *"Some DNS implementations are not
  kind to special characters in domain names, e.g. the '/' used in the above
  examples"* — but they *"are legal"*, and the RFC suggests *"a more conservative
  character, such as hyphen, for '/'"*. Consequence: the naming convention is
  **not canonical**. `0/25`, `0-25`, and other schemes all occur in the wild.
- Alternative (RFC 2317 §5.2): CNAME out of the `in-addr.arpa` tree entirely, e.g.
  `1 CNAME 1.A.domain.`, consolidating forward and reverse in one zone.
- Limitation (RFC 2317 §5.3): *"One cannot provide CNAME referrals twice for the
  same address space"* — CNAME chains are brittle and are to be avoided.

**Implication for `raddr`:** RFC 2317 is a *delegation* convention, not an address
encoding. There is no bijection between an address and an RFC 2317 name, because
the operator chooses the block boundary and the separator character. A library can
offer an RFC 2317 name *given a prefix* and a separator option, but it must not
claim to round-trip.

### IPv6 — `ip6.arpa` (RFC 3596 §2.5)

RFC 3596 §2.5: *"A special domain is defined to look up a record given an IPv6
address."*

Construction rules:

1. **One label per nibble** (4 bits), written as a single hexadecimal digit.
2. **Reverse nibble order**, low-order nibble first. RFC 1886 §2.5 gives the wording
   inherited by RFC 3596 §2.5: *"The sequence of nibbles is encoded in reverse
   order, i.e. the low-order nibble is encoded first, followed by the next
   low-order nibble and so on."*
3. **Always 32 labels.** No zero suppression, no `::`, no leading-zero omission —
   the address is fully expanded to 32 nibbles first. This is visible in the RFC's
   own example, which contains all 32 digits.
4. **Suffix** `ip6.arpa`, then the trailing dot.
5. **Lowercase** is the sane emission choice; comparison is case-insensitive per
   RFC 1035 §3.1. RFC 3596 §2.5 prints the suffix as `IP6.ARPA.` and the digits
   in lowercase in its example; RFC 5952 §4.3 requires lowercase hex in address
   *text* form, which by analogy is the right default here (`UNVERIFIED` that any
   RFC mandates lowercase specifically for `ip6.arpa` labels).

Worked example, verbatim from RFC 3596 §2.5 — address `4321:0:1:2:3:4:567:89ab`:

```
b.a.9.8.7.6.5.0.4.0.0.0.3.0.0.0.2.0.0.0.1.0.0.0.0.0.0.0.1.2.3.4.IP6.ARPA.
```

Further examples:

| Address | Pointer name |
| --- | --- |
| `::1` | `1.0.0.…0.ip6.arpa.` (31 zeros then `1`, reversed: `1` first, then 31 `0` labels) |
| `2001:db8::1` | `1.0.…0.8.b.d.0.1.0.0.2.ip6.arpa.` (32 labels total) |
| `::` | 32 `0` labels + `.ip6.arpa.` |

Prefix pointers truncate on **nibble** boundaries only: a /48 is 12 labels, a /64
is 16 labels, a /56 is 14 labels. A /50 or /127 has no whole-label name — this is
precisely the gap RFC 2673 bitstring labels were invented to fill (see below), and
the IETF decided to live with the gap instead (RFC 3364 §10).

Zone name registration: `ip6.arpa` is registered in the IANA `.arpa` zone with the
description *"For mapping IPv6 addresses to Internet domain names"*, reference
RFC 3152. `in-addr.arpa` is registered with *"For mapping IPv4 addresses to
Internet domain names"*, reference RFC 1035. The `.arpa` zone is managed by IANA
under IAB guidance; all changes require manual coordination with IANA.

### Deprecated form 1 — `ip6.int` (RFC 1886 §2.5, killed by RFC 3152 / RFC 4159)

RFC 1886 §2.5 defined the identical nibble-reversed construction but rooted at
`IP6.INT`: *"The domain is rooted at IP6.INT."* Its example for
`4321:0:1:2:3:4:567:89ab` is the same digit string with the `.IP6.INT.` suffix.

Status trail:

- RFC 3152 §2 deprecated the references: *"This document deprecates references to
  IP6.INT in [RFC1886] section 2.5, [RFC2553] section 6.2.3, [RFC2766] section
  4.1, [RFC2772] section 7.1.c, and [RFC2874] section 2.5."* RFC 3152 §3 asked
  IANA to delegate `IP6.ARPA` instead.
- RFC 3596 obsoletes RFC 1886 and RFC 3152, folding the change in; the substantive
  change is `IP6.INT` → `IP6.ARPA`.
- RFC 4159 finished the job: *"As of 1 September 2005, the IETF advises the
  community that the DNS domain 'ip6.int' should no longer be used to perform
  reverse mapping of IPv6 addresses to domain names, and that the domain
  'ip6.arpa' should be used henceforth."* And: *"The domain 'ip6.int' is
  deprecated, and its use in IPv6 implementations that conform to the IPv6
  Internet Standards is discontinued."*

**Why abandoned:** administrative, not technical. `.int` is for international
treaty organisations; infrastructure names belong under `.arpa`. The nibble
construction itself was kept verbatim.

**`raddr` guidance:** an `ip6.int` emitter is safe to offer only as an explicitly
labelled legacy option; do not default to it. Accepting `ip6.int` on parse is
harmless and helps people reading old zone files.

### Deprecated form 2 — bitstring / binary labels (RFC 2673 + RFC 2874, killed by RFC 3363)

RFC 2874 §2.2.1 defined a reverse form using DNS bit-string labels: *"A base
indicator 'x' for hexadecimal and a sequence of hexadecimal digits is enclosed
between '\[' and ']'. The bits denoted by the digits represent a sequence of
one-bit domain labels ordered from most to least significant."*

Its worked example (RFC 2874 §2.2.1) for `3ffe:7c0:40:9:a00:20ff:fe81:2b32`:

```
\[x3FFE07C0004000090A0020FFFE812B32/128].IP6.ARPA.
\[x0A0020FFFE812B32/64].\[x0009/16].\[x3FFE07C00040/48].IP6.ARPA.
```

Note the **most-significant-first** ordering *within* a bitstring label, the
opposite of the nibble form, while the sequence of labels is still least-
significant-group-first. Delegation used `DNAME` rather than `NS` (RFC 2874 §3.2);
RFC 2874 §5.2 shows TLA-level delegation at non-nibble boundaries:

```
$ORIGIN IP6.ARPA.
\[x234500/24]   DNAME   IP6.ALPHA-TLA.ORG.
```

Label syntax itself is RFC 2673 §3.2 (`\[x…`, `\[b…`, `\[o…`, dotted-quad, each
with an optional `/length`), canonical form in RFC 2673 §3.3 (*"the form which has
the fewest possible Bit-String Labels and in which all except possibly the first …
label … is of maximum length"*), and a 256-bit ceiling per label (RFC 2673 §3.1:
*"Up to 256 One-Bit Labels can be grouped into a single Bit-String Label"*, with a
Count of zero meaning 256).

**Status: Experimental.** RFC 3363 §§1.1, 2.2, 3.2 moved both RFC 2673 and RFC 2874
from Proposed Standard to Experimental, while RFC 1886's AAAA stayed on the
standards track.

**Why abandoned** (the interesting part for a parser author):

- Flag-day deployment. RFC 3364 §10: *"all of the DNS name servers that are
  authoritative for any portion of the name in question must be upgraded before
  the new label type can be used, as must any resolvers involved in the resolution
  process"*, and an un-upgraded server would *"reject the query as being
  malformed"*. RFC 3363 §3 says the same: *"deployment of a new type is difficult
  since DNS servers that do not support bitlabels reject queries containing bit
  labels as being malformed."*
- The problem wasn't worth it. RFC 3363 §3: *"The hexadecimal text representation
  of IPv6 addresses appears to be capable of expressing all of the delegation
  schemes that we expect to be used in the DNS reverse tree."* RFC 3364 §10 adds
  that bitlabels mainly bought delegation in the least-significant bits, an
  unnecessary capability.
- RFC 3364 §11 conclusion: whatever happens with A6/DNAME, *use textual reverse
  DNS, not bitlabels.*

RFC 3363 explicitly disclaims the root question: *"The issue of the root of reverse
IPv6 address map is outside the scope of this document and is covered in a
different document [RFC3152]."* So the `ip6.int` story and the bitstring story are
independent deprecations that happened to overlap in time.

**`raddr` guidance:** do not emit bitstring labels. Parsing `\[x…/len]` is a
nice-to-have for reading historical zone files; it is not an interoperable output.

### Operational reality of `ip6.arpa` (RFC 8501)

RFC 8501 §1.2: *"Since 2^^80 possible addresses could be configured in a single /48
zone alone, it is impractical to write a zone with every possible address entered,
even with automation."* RFC 8501 §2 enumerates the five coping strategies
(NXDOMAIN §2.1, wildcards §2.2, dynamic DNS §2.3, delegation §2.4, on-the-fly
generation §2.5); §4 recommends matching AAAA and PTR only where name and address
assignment share an authority. This matters for `raddr` only as documentation
framing: a generated pointer name very often does not resolve, and that is normal.

---

## Numeric and binary encodings

Nine encodings are in scope for this document:

1. raw bytes (packed network order)
2. unsigned integer (32-bit IPv4 / 128-bit IPv6)
3. hexadecimal string
4. binary string
5. dotted-decimal / colon-hex text (reference form only, covered elsewhere)
6. reverse pointer name (`in-addr.arpa` / `ip6.arpa`)
7. prefix / CIDR notation
8. bracketed literal inside a URI authority
9. bitstring label (deprecated; documented for parse-only)

### 1. Raw bytes — network byte order

An IPv4 address is 4 octets; an IPv6 address is 16 octets. RFC 1035 §3.5 treats
IPv4 as an ordered sequence of octets ("each label represents one octet"), and
RFC 4291 §2.5.5 lays IPv6 out as bit ranges most-significant first (*"80 bits of
zeros | FFFF (16 bits) | 32-bit IPv4 address"*). Both are big-endian /
network byte order: the octet printed leftmost is the octet transmitted first and
is the most significant.

Round-trip hazards: byte arrays carry **no length discrimination beyond their
length** (4 vs 16 is the only signal), **no zone ID**, and **no prefix length**.
See Round-trip failures §1, §2, §4.

### 2. Unsigned integer

- **IPv4 → uint32.** RFC 4632 §3.1 describes an IPv4 address as *"a 4-octet
  quantity"*; the integer form is that quantity read big-endian, range
  `0 … 4294967295` (2^32 − 1).
- **IPv6 → uint128.** RFC 4291 §2 fixes IPv6 addresses at 128 bits; the integer
  form is the 16 octets read big-endian, range `0 … 2^128 − 1`.

**Signed-integer hazards — the central R problem.**

R has no unsigned integer type. `.Machine$integer.max` is `2147483647` (verified
locally by running R in this repo's environment), i.e. R's `integer` is a signed
32-bit type. Consequences:

- **A signed 32-bit integer cannot represent all 2^32 IPv4 addresses.** Its
  positive range tops out at 2147483647 = `127.255.255.255`. Every address from
  `128.0.0.0` upward — i.e. the entire former class B/C/D/E space, over half the
  IPv4 address space — overflows. In R, `as.integer(4294967295)` does not wrap; it
  produces `NA` with *"NAs introduced by coercion to integer range"* (verified
  locally). So the failure mode in R is **silent-ish data loss to `NA`**, not the
  C-style wrap to a negative number.
- Languages that *do* wrap (C `int32_t`, Java `int`) turn `192.0.2.1` into a
  **negative** integer. Any comparison, sorting, or range containment test done on
  signed 32-bit integers therefore places half the IPv4 space *below* `0.0.0.0`.
  Sorting IPv4 addresses as signed int32 gives the wrong order across the
  `127.255.255.255` / `128.0.0.0` boundary.
- **Doubles are the usual R workaround, and they are exactly sufficient for IPv4
  but not for IPv6.** `.Machine$double.digits` is 53 (verified locally), so IEEE
  754 doubles represent every integer up to 2^53 exactly; 2^32 − 1 is comfortably
  inside that. `sprintf("%.0f", 2^53 + 1)` yields `9007199254740992` (verified
  locally) — the first integer a double cannot represent. IPv6's 2^128 is off by
  25 orders of magnitude, so **an IPv6 address must never be represented as a
  double.** The only faithful R carriers are a 16-raw vector, a length-2
  `bit64::integer64` pair (still signed, so the sign bit of each half is a trap),
  or a decimal/hex **string**.
- **64-bit signed** (`bit64::integer64`, Java `long`) holds all of IPv4 with room
  to spare, but only *half* of an IPv6 address, and its top bit is a sign bit — so
  any IPv6 address with bit 0 set (i.e. anything in `8000::/1`, which includes all
  of multicast `ff00::/8`) produces a negative high word. Comparisons must be done
  unsigned or the ordering breaks.
- R's `bitwAnd`/`bitwOr`/`bitwShiftL` operate on 32-bit signed integers;
  `bitwAnd(-1L, 255L)` returns `255` (verified locally), which is convenient, but
  `bitwShiftL(1L, 31L)` is outside the positive range. Prefix-mask arithmetic in R
  is safer done on raw vectors than on integers.

### 3. Hexadecimal string

Definition: the raw bytes rendered as base-16 digits, most significant first, two
digits per octet.

- IPv4 needs **8** hex digits; IPv6 needs **32** hex digits. This follows from
  4 and 16 octets respectively.
- **A hex string without a stated length is ambiguous.** `0x1` could be
  `0.0.0.1` or `::1`. `c0000201` is `192.0.2.1` as IPv4 and also the last 32 bits
  of `::c000:201`. Only zero-padding to the fixed width (8 or 32) plus knowing the
  family makes it decodable.
- **Leading zeros are load-bearing here and forbidden elsewhere**, which is the
  cross-form trap: RFC 5952 §4.1 says *"Leading zeros MUST be suppressed. For
  example, 2001:0db8::0001 is not acceptable and must be represented as
  2001:db8::1"* — that is about *text* form. The fixed-width hex encoding must do
  the exact opposite and pad. Mixing the two rules is a common bug.
- Case: RFC 5952 §4.3 requires lowercase `a`–`f` in IPv6 text form. Applying the
  same default to hex output is consistent; accepting uppercase on input is
  required because RFC 3596 §2.5 and RFC 2874 §2.2.1 both print uppercase.
- An optional `0x` prefix is a presentation convention, not an RFC-defined
  encoding. `UNVERIFIED` that any RFC specifies a `0x`-prefixed IP hex form.

### 4. Binary string

Definition: 32 bits for IPv4, 128 bits for IPv6, most significant bit first,
matching the bit-position diagrams in RFC 4291 §2.5.5 and the prefix semantics in
RFC 4632 §3.1.

- Same length ambiguity as hex, more acutely: a 32-character binary string is a
  full IPv4 address *and* a legal 32-bit prefix of an IPv6 address.
- Grouping (per-octet spaces, per-16-bit groups) is cosmetic and must be stripped
  on parse.
- Bit order is the one place where the deprecated bitstring label had explicit RFC
  wording worth reusing — RFC 2874 §2.2.1: bits are *"ordered from most to least
  significant"*.

### 5. Textual form (cross-reference)

Covered fully elsewhere in this research set. The only points needed here:
RFC 4291 §2.2 permits the mixed form *"x:x:x:x:x:x:d.d.d.d, where the 'x's are the
hexadecimal values of the six high-order 16-bit pieces"*, with examples `::13.1.68.3`
and `::FFFF:129.144.52.38`; RFC 5952 §5 restricts decimal notation to *"the last 32
bits of the address"* and recommends the mixed form only for well-known prefixes,
e.g. `::ffff:192.0.2.1` rather than `0:0:0:0:0:ffff:192.0.2.1`.

### 6–9

Reverse pointers are §1 above; prefix notation is §3 below; URI literals and
bitstring labels are covered in Gotchas.

---

## Prefix notation

### CIDR for IPv4 — RFC 4632

RFC 4632 §3.1 defines the notation as *"a 4-octet quantity, just like a traditional
IPv4 address or network number, followed by the '/' (slash) character, followed by
a decimal value between 0 and 32 that describes the number of significant bits."*

- **Legal range is 0–32 inclusive.** `/0` is explicitly meaningful: RFC 4632 §3.1's
  table lists `0.0.0.0/0` as the default route covering all 4,294,967,296 addresses,
  and RFC 4632 §5.1 states *"the degenerate route to prefix 0.0.0.0/0 is used as a
  default route and MUST be accepted by all implementations."* A parser that
  rejects `/0` is wrong.
- `/32` is the host route — a single address (RFC 4632 §3.1 table, `n.n.n.n/32`).
- **Masks must be left-contiguous.** RFC 4632 §5.1: *"The only outstanding
  constraint is that the mask must be left contiguous."* So `255.255.0.255` is not
  a valid CIDR netmask even though it is a well-formed dotted quad. A netmask →
  prefix-length converter must reject non-contiguous masks rather than counting
  set bits.
- **Netmask form vs prefix-length form** are interconvertible *only* for contiguous
  masks. `/24` ⇔ `255.255.255.0`. The prefix-length form is the CIDR-native one
  (RFC 4632 §3.1); the dotted-quad mask is legacy from classful/`RFC 950`
  subnetting. There is also the inverse/wildcard mask (`0.0.0.255`) used by some
  vendors — `UNVERIFIED` that any RFC standardises the wildcard-mask form.
- **Classful addressing is gone.** RFC 4632 §3: *"The solution that the community
  created was to deprecate the Class A/B/C network address assignment system in
  favor of using 'classless', hierarchical blocks of IP addresses."* Never infer a
  prefix length from the first octet.
- **Non-zero host bits.** RFC 4632 does not state a requirement about the values of
  the host bits within a prefix; §3.1 speaks only about the significant leading
  bits. So `192.0.2.5/24` is *syntactically* a prefix whose significant bits are
  `192.0.2` — the trailing `.5` is simply not significant. Two readings coexist in
  practice:
  - **strict**: `192.0.2.5/24` is an error, only `192.0.2.0/24` names the network;
  - **lenient**: it is an *interface address with its prefix*, the form used in
    `ip addr` and in RFC 4291 §2.3 style host configuration.

  `raddr` should parse both and offer an explicit `strict` switch plus a
  "normalise to network address" operation (mask off host bits). Silently masking
  is data loss — see Round-trip failures §6.

### Prefix notation for IPv6 — RFC 4291 §2.3

RFC 4291 §2.3 uses the same `ipv6-address/prefix-length` shape, where the prefix
length *"specif[ies] how many of the leftmost contiguous bits of the address
comprise the prefix."* Range is 0–128.

- **You may not abbreviate the address part beyond the normal rules.** RFC 4291
  §2.3 is explicit that trailing zeros cannot be dropped within a 16-bit chunk:
  `2001:0DB8:0:CD3/60` is **invalid**; the address must be written in full as
  `2001:0DB8:0:CD30::/60` (or its `::`-compressed equivalent).
- RFC 5952 §7: *"The text representation method of IPv6 prefixes should be no
  different from that of IPv6 addresses"* — i.e. §4's leading-zero suppression,
  maximal `::`, and lowercase rules apply to the address part of a prefix too.
- There is no dotted netmask form for IPv6. Prefix length only.
- `::/0` is the IPv6 default route and is legal by the 0–128 range.
- `/128` is a single host.

### Prefix-length constraints from other specs

RFC 6052 §2.2 restricts IPv4-embedded IPv6 prefixes to exactly six lengths — 32,
40, 48, 56, 64, 96 — with the Well-Known Prefix `64:ff9b::/96` (RFC 6052 §2.1)
usable only at /96. RFC 6052 §2.2 also requires *"Bits 64 to 71 of the address are
reserved for compatibility with the host identifier format defined in the IPv6
addressing architecture [RFC4291]. These bits MUST be set to zero."* A general
prefix parser should not enforce these — they are translation-specific — but a
`raddr` classifier for NAT64 prefixes must.

---

## Round-trip failures

Numbered cases where encode-then-decode, or parse-then-format, does not return the
original input.

1. **Zone ID is lost through bytes.** RFC 4007 §11 defines the textual form
   `<address>%<zone_id>` and says *"The <zone_id> part does not have to contain the
   scope. This is because the <address> part should specify the appropriate
   scope."* The zone is metadata about *which link*, not part of the 128 bits.
   Encoding `fe80::1%eth0` to 16 bytes yields the same bytes as `fe80::1%eth1`;
   decoding produces `fe80::1` with no zone. **Byte round-trip is lossy for any
   scoped address.** RFC 4007 §6 explains why the zone cannot be recovered: *"The
   zone indices are strictly local to the node. For example, the node on the other
   end of the point-to-point link may well use entirely different interface and
   link index values for that link."* RFC 4007 §11 also forbids putting the form on
   the wire: *"The format MUST be used only within a node and MUST NOT be sent on
   the wire unless every node that interprets the format agrees on the semantics."*

2. **IPv4 and IPv4-mapped IPv6 collide on the low 32 bits.** RFC 4291 §2.5.5 gives
   the IPv4-mapped layout as *"80 bits of zeros | FFFF (16 bits) | 32-bit IPv4
   address"*. So `::ffff:192.0.2.1` and `192.0.2.1` share their trailing four
   octets. If an API accepts "an integer" or "a hex string" without a declared
   family, `3221225985` (`0xC0000201`) is `192.0.2.1` as IPv4 and, as a 128-bit
   value, is the *IPv4-compatible* address `::192.0.2.1` — a third, deprecated
   thing (RFC 4291 §2.5.5, IPv4-compatible = *"80 bits of zeros | 16 bits of zeros
   | 32-bit IPv4 address"*, and the RFC marks it deprecated). Three distinct
   objects, one integer. **The family must be carried alongside the number.**

3. **Two distinct texts encode to identical bytes.** `::ffff:192.0.2.1` and
   `::ffff:c000:201` are the same 16 octets (RFC 4291 §2.2 permits both the mixed
   and pure-hex spellings). Decoding gives back only one of them. RFC 5952 §5
   picks the mixed form for well-known prefixes, so `::ffff:c000:201` in →
   `::ffff:192.0.2.1` out. Likewise `2001:0db8:0000:0000:0000:0000:0000:0001`,
   `2001:db8::1`, and `2001:DB8:0:0:0:0:0:1` are one address with three spellings;
   RFC 5952 §4.1/§4.2/§4.3 makes only the middle one canonical.

4. **Prefix length is lost through bytes and through integers.** 4 bytes is
   `192.0.2.0`, full stop — nothing distinguishes it from `192.0.2.0/24`.
   Any byte/integer/hex/binary encoding of an address alone drops the `/n`.
   Prefix must be a separate field.

5. **Leading zeros are lost, in both directions.** RFC 5952 §4.1 mandates
   suppression in IPv6 text (`2001:0db8::0001` → `2001:db8::1`), and RFC 1035 §3.5
   mandates it in `in-addr.arpa` labels (*"leading zeros omitted except in the case
   of a zero octet"*). Conversely the fixed-width hex/binary encodings **require**
   padding. So `text → hex → text` is stable, but `hex-with-stripped-zeros → bytes`
   fails, and any user-supplied "hex" of fewer than 8/32 digits is a guess.
   The classic IPv4 case: `010.0.0.1` is not `10.0.0.1` in any RFC-defined
   notation, but `inet_addr()` historically read `010` as **octal 8**. `UNVERIFIED`
   that any RFC blesses octal dotted quads; it is a `libc` behaviour, and it means
   text → integer is implementation-dependent for zero-padded input. `raddr`
   should reject leading zeros in dotted quads rather than pick a base.

6. **Host bits are lost if a prefix is normalised.** `192.0.2.5/24` normalised to
   its network address becomes `192.0.2.0/24`; the `.5` never comes back. RFC 4632
   §3.1 makes only the leading bits significant, so a strict reader is entitled to
   discard the rest — but for an interface address (RFC 4291 §2.3 style) the host
   bits are the point. Normalisation must be opt-in.

7. **`::` placement is not recoverable from bytes when runs tie.** RFC 5952 §4.2
   requires maximal compression and forbids compressing a single 16-bit zero field
   (*"The symbol '::' MUST NOT be used to shorten just one 16-bit 0 field"*), which
   removes most ambiguity — but an address such as `2001:db8:0:1:1:1:1:0` has two
   equal-length zero runs, and pre-RFC-5952 encoders differ on which to compress.
   `2001:db8::1:1:1:1:0` and `2001:db8:0:1:1:1:1::` are the same bytes with
   different spellings; only one survives a byte round-trip. (RFC 5952 §4.2.3
   resolves the tie in favour of the leftmost run — `UNVERIFIED` on the exact
   subsection number from the fetched text, though the leftmost rule is the one
   RFC 5952 states.)

8. **Case is lost.** RFC 5952 §4.3: *"The characters 'a', 'b', 'c', 'd', 'e', and
   'f' in an IPv6 address MUST be represented in lowercase."* `2001:DB8::1` in →
   `2001:db8::1` out. In reverse pointers, RFC 1035 §3.1's case-insensitive
   comparison rule means `B.A.9.…IP6.ARPA.` and `b.a.9.…ip6.arpa.` are the same
   name but not the same string.

9. **The trailing dot is lost or gained.** `1.2.0.192.in-addr.arpa` and
   `1.2.0.192.in-addr.arpa.` denote the same name (RFC 1035 §3.1: every name ends
   with the root label), but string equality fails. Pick one on output — the dotted
   (absolute) form — and normalise on input.

10. **`ip6.arpa` → address is bijective; `in-addr.arpa` → address is not, if you
    allow partial names.** `10.in-addr.arpa.` decodes to a /8, not an address
    (RFC 1035 §3.5's gateway-lookup example). A pointer-to-address function must
    either require exactly 4 (or 32) labels or return a prefix.

11. **RFC 2317 names do not round-trip at all.** The separator is a free choice
    (RFC 2317 §4 sanctions `/` and suggests hyphen as an alternative) and the
    delegation boundary is an operator decision; RFC 2317 §5.2 even allows names
    entirely outside `in-addr.arpa`. Given a name you cannot recover the address
    without the zone's CNAMEs. Treat as generate-only.

12. **`%` in a URI must be escaped, and un-escaping is context-dependent.**
    RFC 6874 requires `IPv6addrz = IPv6address "%25" ZoneID`, i.e. *"any occurrences
    of literal '%' symbols in a URI MUST be percent-encoded and represented in the
    form '%25'"*, so `fe80::a%en1` becomes `http://[fe80::a%25en1]`. A naive
    percent-decode of `%25en1` gives `%en1`; a double decode gives garbage. Worse,
    RFC 6874 §4 says *"An HTTP client, proxy, or other intermediary MUST remove any
    ZoneID attached to an outgoing URI, as it has only local significance"* — so the
    zone is *designed* to be stripped in transit. And RFC 6874 has since been
    obsoleted by RFC 9844 (August 2025, Standards Track), whose §3 states *"This
    document completely obsoletes [RFC6874], which implementors of web browsers
    have determined is impracticable to support."* RFC 9844 drops the URI syntax
    entirely and specifies only user-interface entry (§5: a UI *"MUST provide a
    means for entering a link-local address or a scoped multicast address and
    selecting a zone identifier"*, and *"SHOULD support the complete format"* such
    as `fe80::1%eth0`). Net effect: **zone-in-URI has no live standard**, and
    `raddr` should emit `%25` only when explicitly asked for the RFC 6874 form and
    document it as historical.

---

## Gotchas

1. **Nibble order and octet order are both reversed, but at different
   granularities.** IPv4 reverses whole octets (RFC 1035 §3.5); IPv6 reverses
   4-bit nibbles (RFC 3596 §2.5). Reversing IPv6 by *octet* is a classic bug and
   produces a plausible-looking but wrong name.

2. **IPv6 pointer names are always 32 labels.** No compression, no zero
   suppression. `::1` produces 32 labels, 31 of them `0`. Reusing the text
   formatter to build the name is wrong.

3. **The bitstring label reverses bits most-significant-first *within* a label**
   (RFC 2874 §2.2.1: *"ordered from most to least significant"*) while the label
   sequence still runs least-significant-group-first. Opposite convention to the
   nibble form inside, same convention outside.

4. **RFC 2673 is Standards Track as published but Experimental as of RFC 3363**
   (§§1.1, 2.2, 3.2 reclassified RFC 2673 and RFC 2874). Reading the RFC's own
   header gives the wrong status.

5. **A6 records went the same way as bitlabels.** RFC 3363 §2: *"AAAA records are
   preferable at the moment for production deployment of IPv6, and that A6 records
   have interesting properties that need to be better understood before
   deployment."* RFC 3363 §2 and RFC 3364 §6 both cite resolution cost roughly
   proportional to chain length N and failure probability likewise. Not `raddr`'s
   problem, but it is why the reverse tree is plain nibble text today.

6. **`/` is legal in a DNS label.** RFC 2317 §4 confirms it. Any DNS-name validator
   in `raddr` that applies the "preferred name syntax" (letters, digits, hyphen)
   will reject valid RFC 2317 names.

7. **`.arpa` sub-zones are an IANA registry, not free-form.** `in-addr.arpa`
   (RFC 1035) and `ip6.arpa` (RFC 3152) are the two address-mapping entries; the
   registry also holds `ipv4only.arpa` (RFC 7050, DNS64 prefix discovery),
   `in-addr-servers.arpa` and `ip6-servers.arpa` (RFC 5855, the nameservers for
   the two reverse trees), `ns.arpa` (RFC 9120), `as112.arpa` (RFC 7535, traffic
   sinking), `home.arpa` (RFC 8375), `resolver.arpa` (RFC 9462) and `e164.arpa`
   (RFC 6116). `ip6.int` is *not* in it — that is the point of RFC 4159.

8. **`ipv4only.arpa` is an address-bearing name, not a reverse name** (RFC 7050).
   Do not confuse it with the reverse trees when pattern-matching on `.arpa`.

9. **`in-addr.arpa` labels are decimal, `ip6.arpa` labels are hex.** A label `9` is
   valid in both trees but means octet 9 in one and nibble 9 in the other. Sniffing
   the family from the labels alone fails; use the suffix.

10. **Zone IDs may be numeric or alphanumeric.** RFC 4007 §11: *"An implementation
    SHOULD support at least numerical indices that are non-negative decimal
    integers as <zone_id>."* So `%1` and `%eth0` are both legitimate, and `%1` is
    *not* a prefix length.

11. **The zone applies only to non-global scope.** RFC 4007 §11: *"The format
    applies to all kinds of unicast and multicast addresses of non-global scope
    except the unspecified address, which does not have a scope."* A zone on a
    global unicast address is meaningless. RFC 6874 §4 hardens this:
    implementations *"MUST NOT allow use of this format except for well-defined
    usages, such as sending to link-local addresses under prefix fe80::/10."*
    RFC 4007 §12 adds the security angle: *"A limited scope address without a zone
    index has security implications and cannot be used for some security
    contexts."*

12. **Square brackets are only legal in the URI host.** RFC 3986 §3.2.2: *"This is
    the only place where square bracket characters are allowed in the URI syntax."*
    Brackets are required to disambiguate the colons in an IPv6 literal from the
    port separator. RFC 5952 §6 says the same about the port form:
    `2001:db8::1:80` is ambiguous and *"NOT RECOMMENDED"*; use `[2001:db8::1]:80`.
    RFC 4038 §5.1 makes the identical point.

13. **RFC 3986's `IPv6address` ABNF does not admit a zone.** The grammar in
    §3.2.2 is `IP-literal = "[" ( IPv6address / IPvFuture ) "]"` — no `%`. RFC 6874
    added `IPv6addrz`, and RFC 9844 withdrew it. So a strict RFC 3986 parser must
    reject `[fe80::1%25eth0]`, and there is currently no successor syntax.

14. **`IPvFuture` exists and is parseable.** RFC 3986 §3.2.2:
    `IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )`. Nothing has
    ever been registered for it; `UNVERIFIED` that any IANA registry of IPvFuture
    version numbers exists. A URI host parser should recognise the shape and report
    "unknown address family" rather than crashing, and `raddr` should never emit it.

15. **RFC 3986's `IPv4address` production is strict.** `dec-octet = DIGIT /
    %x31-39 DIGIT / "1" 2DIGIT / "2" %x30-34 DIGIT / "25" %x30-35` — this forbids
    leading zeros (`01` is unmatched) and forbids values above 255. It also forbids
    the shortened `10.1` / `10.0.1` forms that `inet_aton()` accepts. A URI-derived
    IPv4 parse and a `libc`-style parse disagree on a large set of inputs.

16. **RFC 3986 host case normalisation.** §3.2.2: *"Producers and normalizers should
    use lowercase for registered names"* while percent-encodings keep uppercase hex
    digits. Combined with RFC 5952 §4.3, an IPv6 literal in a URI should be all
    lowercase — but a `%25` escape keeps its uppercase digits. Two different case
    rules inside one bracketed host.

17. **Never infer prefix length from the first octet.** RFC 4632 §3 deprecated
    classes. Any residual "class A/B/C" logic mis-parses `10.0.0.0/24` and
    `192.0.0.0/8`, both of which are perfectly legal.

18. **Netmask → prefix conversion must validate contiguity, not popcount.**
    RFC 4632 §5.1: *"the mask must be left contiguous."* Counting bits in
    `255.0.255.0` gives 16 and silently produces `/16`, which is wrong; the input
    should be rejected.

19. **`/0` must be accepted.** RFC 4632 §5.1: the default route *"MUST be accepted
    by all implementations."* Same for `::/0` by RFC 4291 §2.3's 0–128 range.

20. **RFC 4291 §2.3 forbids truncating a prefix's address part.**
    `2001:0DB8:0:CD3/60` is invalid; `2001:0DB8:0:CD30::/60` is correct. This is a
    real-world typo class because it looks like it should work.

21. **IPv4-compatible IPv6 addresses are deprecated but still parse.** RFC 4291
    §2.5.5 gives the layout (80 zero bits, 16 zero bits, 32-bit IPv4) and marks the
    form deprecated. `::192.0.2.1` should be classified, not rejected, and should
    not be treated as equivalent to `192.0.2.1`.

22. **NAT64 prefixes have hard constraints most parsers ignore.** RFC 6052 §2.2
    allows only /32, /40, /48, /56, /64, /96, and requires *"Bits 64 to 71 … MUST
    be set to zero."* RFC 6052 §2.1 reserves `64:ff9b::/96` as the Well-Known
    Prefix, usable only at /96. RFC 6052 §2.4 allows dotted-decimal for the
    embedded IPv4 with the WKP or a /96 NSP, e.g. `64:ff9b::192.0.2.33`.

23. **Applications should not special-case IPv4-mapped addresses at the network
    layer.** RFC 4038 §7: *"IPv6 applications must not be required to distinguish
    'normal' and 'NAT-PT translated' addresses (or any other kind of special
    addresses, including the IPv4-mapped IPv6 addresses)."* For `raddr` the
    opposite is true — classification is the product — but any *conversion*
    default that silently demotes `::ffff:a.b.c.d` to IPv4 will surprise people.

24. **Reverse DNS for IPv4-mapped IPv6 addresses is unspecified.** RFC 4038 does
    not discuss it; neither RFC 3596 nor RFC 4291 says whether `::ffff:192.0.2.1`
    should map into `ip6.arpa` (32 nibble labels ending `f.f.f.f.0.0…`) or into
    `1.2.0.192.in-addr.arpa.`. `UNVERIFIED` — no RFC found that settles this. The
    mechanically correct answer is the `ip6.arpa` form, since the address is an
    IPv6 address; the *useful* answer is the `in-addr.arpa` form, since that is
    where the data lives. `raddr` should default to mechanical and document the
    alternative.

25. **Generated pointer names usually do not resolve, and that is expected.**
    RFC 8501 §1.2 on the impossibility of pre-populating IPv6 reverse zones, §2.1
    on NXDOMAIN as a legitimate strategy. A "correct" name is not a "resolvable"
    name; `raddr` is offline and makes no claim about resolution.

26. **R-specific: `integer` is signed 32-bit and overflow yields `NA`, not a wrap.**
    `.Machine$integer.max` = 2147483647; `as.integer(4294967295)` warns *"NAs
    introduced by coercion to integer range"* (both verified locally). Half the
    IPv4 space cannot be stored in an R `integer`. Use `double` (exact to 2^53,
    `.Machine$double.digits` = 53, verified locally) for IPv4 integers, and raw
    vectors or strings for IPv6.

27. **R-specific: never use `double` for IPv6.** 2^128 ≫ 2^53. The first
    unrepresentable integer is 9007199254740992 (verified locally). Silent
    precision loss, no warning.

28. **R-specific: `bit64::integer64` is signed.** Splitting IPv6 into two 64-bit
    halves makes every address in `8000::/1` (all multicast `ff00::/8` included)
    have a negative high word, breaking ordering unless comparisons are done
    unsigned.
