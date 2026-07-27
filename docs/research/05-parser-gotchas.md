# Parsing IP Address Literals from Text — Divergence Inventory

Research notes for `raddr`. Every claim carries a source. Anything not directly substantiated
from a primary source is marked `UNVERIFIED`.

Primary sources consulted: RFC 4291 §2.2, RFC 5952, RFC 4007 §11, RFC 6874, RFC 3986 §3.2.2,
RFC 6943 §3.1, RFC 1035 §3.5, RFC 3596 §2.5; the WHATWG URL Standard (host parser, IPv4 parser,
IPv4 number parser, IPv6 parser, serializers); `inet_aton(3)` / `inet_pton(3)` / `getaddrinfo(3)`
man pages; glibc `resolv/inet_addr.c`; musl `src/network/inet_aton.c` and
`src/network/lookup_ipliteral.c`; Microsoft `RtlIpv4StringToAddress` docs; CPython `ipaddress`
docs; Go `net` / `net/netip` docs and the Go 1.17 release notes; Rust `std::net` docs and
RustSec; NVD entries for CVE-2021-29921, CVE-2021-28918, CVE-2021-29418, CVE-2020-28360,
CVE-2021-29922, CVE-2021-29923; sick.codes SICK-2021-011/014/016; NCC Group's OpenJDK advisory;
FreeBSD Developers' Handbook ch. 8; daniel.haxx.se on curl 7.77.0.

**The thesis in one line.** There is no such thing as "the" IP address parser. `inet_aton`,
`inet_pton`, the WHATWG URL host parser, and the modern language standard libraries are four
mutually incompatible grammars, and RFC 6943 §3.1.1 says outright that this is a *security*
problem: *"Different implementations treating the same string differently can cause false
positives or negatives in security comparisons."* Seven CVEs in 2020–2021 are the receipts.

---

## Divergence matrix

Cells are derived from the cited specification text or source code, not from executing code
(per research constraints). Where a cell could not be substantiated from a source it is marked
`UNVER`.

Column key:

| col | what it means | authority |
|---|---|---|
| `pton` | POSIX `inet_pton(AF_INET/AF_INET6)` — glibc, musl, BSD/Apple, Windows `InetPton` | `inet_pton(3)` |
| `glibc` | glibc `inet_aton(3)` and therefore glibc `getaddrinfo(3)` numeric-host path | glibc `resolv/inet_addr.c`; `getaddrinfo(3)` |
| `musl` | musl `inet_aton` / `__lookup_ipliteral` | musl `src/network/inet_aton.c`, `lookup_ipliteral.c` |
| `WHATWG` | WHATWG URL host parser — browsers, `ada`, Node.js `URL`, curl ≥ 7.77.0 | url.spec.whatwg.org |
| `py` | CPython `ipaddress` ≥ 3.9.5 / ≥ 3.8.12 | docs.python.org |
| `go` | Go ≥ 1.17 `net.ParseIP` / `net/netip.ParseAddr` | Go 1.17 release notes; pkg.go.dev |
| `rust` | Rust ≥ 1.53 `std::net::{Ipv4Addr,Ipv6Addr}: FromStr` | doc.rust-lang.org; RustSec CVE-2021-29922 |
| `java` | `java.net.InetAddress` with default `jdk.net.allowAmbiguousIPAddressLiterals=false` | Oracle release note "Update java.net.InetAddress to Detect Ambiguous IPv4 Address Literals" (JDK-8277608) |

### IPv4 literals

| literal | `pton` | `glibc` | `musl` | `WHATWG` | `py` | `go` | `rust` | `java` |
|---|---|---|---|---|---|---|---|---|
| `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` | `1.2.3.4` |
| `010.0.0.1` | reject | **`8.0.0.1`** | **`8.0.0.1`** | **`8.0.0.1`** + warn | reject | reject | reject | reject (was `10.0.0.1`) |
| `0177.0.0.1` | reject | **`127.0.0.1`** | **`127.0.0.1`** | **`127.0.0.1`** + warn | reject | reject | reject | reject (was `177.0.0.1`) |
| `0x7f.1` | reject | **`127.0.0.1`** | **`127.0.0.1`** | **`127.0.0.1`** + warn | reject | reject | reject | reject |
| `127.1` | reject | `127.0.0.1` | `127.0.0.1` | `127.0.0.1` + warn | reject | reject | reject | `127.0.0.1` `UNVER` |
| `0x7f000001` | reject | `127.0.0.1` | `127.0.0.1` | `127.0.0.1` + warn | reject | reject | reject | reject |
| `2130706433` | reject | `127.0.0.1` | `127.0.0.1` | `127.0.0.1` | reject | reject | reject | `127.0.0.1` `UNVER` |
| `1.2.3.4.5` | reject | reject | reject | reject | reject | reject | reject | reject |
| `1.2.3.04` | reject | **`1.2.3.4`** | **`1.2.3.4`** | **`1.2.3.4`** + warn | reject | reject | reject | reject |
| `1.2.3.08` | reject | **reject** | **reject** | **reject** | reject | reject | reject | reject |
| `4294967296` | reject | reject | reject | reject | reject | reject | reject | reject |
| `4294967295` | reject | `255.255.255.255` | `255.255.255.255` | `255.255.255.255` | reject | reject | reject | `UNVER` |
| `0` | reject | **`0.0.0.0`** | **`0.0.0.0`** | **`0.0.0.0`** | reject | reject | reject | `0.0.0.0` `UNVER` |
| `1.2.3.4.` | reject | reject | reject | **`1.2.3.4`** + warn | reject | reject | reject | reject `UNVER` |
| `1.2.3.4 ` (trailing SP) | reject | **`1.2.3.4`** | **reject** | reject at host level; but see G-14 | reject | reject | reject | reject `UNVER` |
| `1.2.3.4junk` | reject | **`1.2.3.4`** | **reject** | reject | reject | reject | reject | reject `UNVER` |

Notes on the harder cells:

- `010.0.0.1`, `0177.0.0.1`, `0x7f.1`, `1.2.3.04`, `0x7f000001` — `inet_aton(3)`: *"components of
  the dotted address can be specified in decimal, octal (with a leading `0`), or hexadecimal,
  with a leading `0X`"*, and the one/two/three-part forms are all defined there. glibc
  implements this with `__strtoul_internal (cp, &endp, 0, 0)` — base 0 — with the in-code
  comment `0x=hex, 0=octal, isdigit=decimal`. musl uses `strtoul(s, &z, 0)` identically.
- `010.0.0.1` under WHATWG — the *IPv4 number parser* says: *"if the first code point is U+0030
  (0): set validationError to true, remove it, set R to 8"*. The error is a **validation error,
  not a failure**; step 5 of the *IPv4 parser* only records `IPv4-non-decimal-part`. So browsers
  reach `8.0.0.1`.
- `1.2.3.08` — this is the interesting one: every parser rejects it, but for *two different
  reasons*. `inet_aton`/WHATWG reject because `8` is not an octal digit; the strict parsers
  reject because of the leading zero. A filter that rejects on parse failure is safe here; a
  filter that falls back to a regex is not. This is exactly CVE-2021-29418.
- `4294967296` under WHATWG — *IPv4 parser* step 8: *"If the last item in numbers is greater than
  or equal to 256^(5 − numbers's size), then return failure."* With one part that bound is 2^32.
  glibc bounds the one-part form at `0xffffffff` in `max[]`.
- `0` — accepted by `inet_aton` (the one-part form) and by WHATWG (the *ends-in-a-number checker*
  routes a bare-digits host to the IPv4 parser), yielding `0.0.0.0`. `ipaddress.IPv4Address('0')`
  raises: the strict parsers demand four octets. See G-3 — this is why `http://0/` reaches
  localhost.
- `1.2.3.4.` — WHATWG *IPv4 parser* step 2: *"If last part is empty string: IPv4-empty-part
  validation error; remove last item if parts's size > 1."* Non-fatal. glibc's parser breaks on
  `.` and then requires a digit (`if (!isdigit (c)) goto ret_0;`); musl's loop exits with `i==4`
  and returns 0. Both reject.
- `1.2.3.4 ` / `1.2.3.4junk` — **glibc/musl disagree here.** glibc: `if (c != '\0' && (!isascii
  (c) || !isspace (c))) goto ret_0;` — trailing whitespace passes. Worse, glibc carries a variant
  commented *"inet_aton ignores trailing garbage"*, so the public `inet_aton` succeeds on
  `1.2.3.4junk`; glibc added `__inet_aton_exact` (requires `*endp == 0`) for the callers that
  must not. musl's loop rejects any trailing byte that is not `.` or NUL. Space is also a WHATWG
  *forbidden host code point*.
- Java column — the Oracle release note for JDK-8277608 states Java now rejects strings such as
  `"0x7f.016.0.0xa"`, `"0x7f000001"` and `"017700000001"` by default unless
  `-Djdk.net.allowAmbiguousIPAddressLiterals=true` is passed. The pre-fix value in the "(was …)"
  cells is the *decimal* reading, because `Inet4Address.ofLiteral` *"ignores leading zeros,
  parses all numbers as decimal"* — which is itself a divergence from `getaddrinfo`, on which
  `InetAddress.getAllByName` relies and which parses with `strtoul` (octal/hex bases). Which
  decimal short-forms survive the new check is `UNVER`.

### IPv6 literals

| literal | `pton` | `glibc gai` | `musl gai` | `WHATWG` | `py` | `go` | `rust` | `java` |
|---|---|---|---|---|---|---|---|---|
| `::1` | `::1` | `::1` | `::1` | `::1` | `::1` | `::1` | `::1` | `::1` |
| `::ffff:127.0.0.1` | ok | ok | ok | ok | ok | ok | ok | ok — but see G-17 for the *format* divergence |
| `::1%lo0` | **reject** | accept | **reject** (EAI_NONAME) | **reject** | accept | accept | **reject** `UNVER` | accept |
| `fe80::1%1` | **reject** | accept | accept | **reject** | accept | accept | **reject** `UNVER` | accept |
| `fe80::1%25eth0` (URI form) | reject | reject | reject | reject | reject `UNVER` | reject `UNVER` | reject | reject `UNVER` |
| `::00001` | reject | reject | reject | **reject** | reject | reject | reject | reject |
| `1::2::3` | reject | reject | reject | reject | reject | reject | reject | reject |
| `2001:db8::00ff` | accept | accept | accept | accept **+ warn** | accept | accept | accept | accept |
| `::1.2.3.4` | accept | accept | accept | accept | accept | accept | accept | accept |
| `::1.2.3.04` | reject | reject | reject | **reject** | reject `UNVER` | reject `UNVER` | reject | `UNVER` |
| `::ffff:1.2.3.4.5` | reject | reject | reject | reject | reject | reject | reject | reject |
| `1:2:3:4:5:6:7` (7 groups) | reject | reject | reject | reject | reject | reject | reject | reject |
| `1:2:3:4:5:6:7:8:9` | reject | reject | reject | reject | reject | reject | reject | reject |
| `::ffff:1.2.3` (short v4 tail) | reject | reject | reject | **reject** | reject | reject | reject | `UNVER` |

Notes on the harder cells:

- `::1%lo0` under musl — `__lookup_ipliteral` extracts the `%` suffix, tries `strtoull`, falls
  back to `if_nametoindex`, and then gates on
  `if (!IN6_IS_ADDR_LINKLOCAL(&a6) && !IN6_IS_ADDR_MC_LINKLOCAL(&a6)) return EAI_NONAME;`.
  `::1` is loopback, so musl rejects a zone on it. glibc does not impose that restriction.
  This is a real, sourced glibc/musl divergence on a very ordinary-looking literal.
- Zone IDs under WHATWG — the IPv6 parser carries the note *"Support for `<zone_id>` is
  intentionally omitted."* Browsers never shipped RFC 6874 and the WHATWG later rejected a
  request to add it.
- `2001:db8::00ff` under WHATWG — *"If length is greater than 1 and value is less than
  0x10^(length−1), IPv6-piece-leading-zero validation error"*, then the algorithm **continues**:
  *"Set address[pieceIndex] to value. Increase pieceIndex by 1."* Accepted with a warning. This
  is legal under RFC 4291 §2.2 (*"one to four hexadecimal digits"*) but must not be *emitted*
  under RFC 5952 §4.1.
- `::00001` — five hex digits. The WHATWG hex loop runs *"While length is less than 4 and c is an
  ASCII hex digit"*, so after four digits the next `1` is neither `:` nor end-of-input and the
  parser returns failure. RFC 4291 §2.2 caps a field at four digits. `UNVER`: Dave Anderson's
  survey claims *"most modern parsers seem to allow an unlimited amount of leading zeros"* in
  IPv6 pieces; I could not substantiate a named parser that does.
- `::1.2.3.04` under WHATWG — the IPv4-in-IPv6 inner loop: *"If ipv4Piece is null, then set
  ipv4Piece to number. Otherwise, if ipv4Piece is 0, IPv4-in-IPv6-invalid-code-point validation
  error, return failure."* A leading zero in the embedded quad is a **hard failure** here, unlike
  a leading zero in a standalone IPv4 host, which is only a warning. That asymmetry is worth
  reproducing exactly.
- `1:2:3:4:5:6:7` — WHATWG: *"If pieceIndex is not 8, IPv6-too-few-pieces validation error,
  return failure."* RFC 4291 §2.2 form 1 requires eight pieces.

---

## Rules by standard

### RFC 4291 §2.2 — Text Representation of IPv6 Addresses

Three conventional forms, and only three:

1. **Preferred:** *"x:x:x:x:x:x:x:x, where the 'x's are one to four hexadecimal digits of the
   eight 16-bit pieces."* Leading zeros **may** be omitted; each field needs at least one
   numeral. Note what this permits: `2001:0DB8:0000:0000:0008:0800:200C:417A` is fully legal
   input, and so is uppercase.
2. **Compressed:** *"The use of '::' indicates one or more groups of 16 bits of zeros. The '::'
   can only appear once in an address."* Note "one or more" — RFC 4291 lets you compress a
   *single* zero group; RFC 5952 §4.2.2 later forbids emitting that. §2.2 is a *parsing*
   grammar; §4.2.2 is an *output* rule. Conflating them is a common bug.
3. **Mixed:** *"x:x:x:x:x:x:d.d.d.d, where the 'x's are the hexadecimal values of the six
   high-order 16-bit pieces"* and the low 32 bits are dotted quad. Examples given: `::13.1.68.3`,
   `::FFFF:129.144.52.38`.

RFC 4291 §2.2 says nothing about zone IDs, nothing about `0x`/octal in the `d.d.d.d` tail,
and nothing about a maximum for the dotted part beyond "IPv4 notation".

### RFC 5952 — A Recommendation for IPv6 Text Representation

RFC 5952 constrains **output**, not input. A parser that rejects non-canonical input is
over-applying it; a formatter that emits non-canonical output is under-applying it.

| § | rule (quoted) |
|---|---|
| 4.1 | *"Leading zeros MUST be suppressed. For example, 2001:0db8::0001 is not acceptable and must be represented as 2001:db8::1."* Plus: *"A single 16-bit 0000 field MUST be represented as 0."* |
| 4.2.1 | *"The use of the symbol '::' MUST be used to its maximum capability. For example, 2001:db8:0:0:0:0:2:1 must be shortened to 2001:db8::2:1."* |
| 4.2.2 | *"The symbol '::' MUST NOT be used to shorten just one 16-bit 0 field. For example, the representation 2001:db8:0:1:1:1:1:1 is correct, but 2001:db8::1:1:1:1:1 is not correct."* |
| 4.2.3 | On a tie in run length, *"the first sequence of zero bits MUST be shortened. For example, 2001:db8::1:0:0:1 is correct representation."* |
| 4.3 | *"The characters 'a', 'b', 'c', 'd', 'e', and 'f' in an IPv6 address MUST be represented in lowercase."* |
| 5 | Mixed `x:x:x:x:x:x:d.d.d.d` notation *"is RECOMMENDED if … the address can be distinguished as having IPv4 addresses embedded in the lower 32 bits"* via a well-known prefix. Otherwise emit pure hextets. |
| 6 | With a port, *"The [] style as expressed in [RFC3986] SHOULD be employed, and is the default unless otherwise specified."* |

§4.2.2 is the rule most implementations get wrong, and §4.2.3 is the rule most *test suites*
miss. Note that 4.1's second sentence and 4.2.2 interact: `2001:db8:0:1:1:1:1:1` — the single
zero group is written `0`, not `::` and not `0000`.

### WHATWG URL Standard — host parser

The WHATWG host parser is the de facto standard for anything reachable from a URL: browsers,
`ada` (used by Node.js `URL`), and — since 7.77.0 — curl, which normalises these forms itself
rather than delegating to the resolver.

**Host parser.** For non-opaque hosts: bracketed input goes to the IPv6 parser (brackets are
mandatory); otherwise the input is percent-decoded and domain-to-ASCII'd, then the
*ends-in-a-number checker* decides whether to run the IPv4 parser. That checker *"splits domain
labels on dots, then checks if the final label contains only ASCII digits or parses as a
hexadecimal number."* So `foo.0x10` is an IPv4 attempt, and `foo.bar` is not.

**IPv4 parser** (verbatim structure):

1. Split on `.`.
2. Trailing empty part → `IPv4-empty-part` **validation error**; remove it if size > 1.
3. Size < 4 → `IPv4-too-few-parts` **validation error** (not fatal — this is where `127.1` lives).
4. Size > 4 → `IPv4-too-many-parts`, **return failure**.
5. Each part through the IPv4 number parser; failure → `IPv4-non-numeric-part`, **return
   failure**; non-decimal flag → `IPv4-non-decimal-part` **validation error**.
6. Any item > 255 → `IPv4-out-of-range-part` **validation error**.
7. Any **non-last** item > 255 → **return failure**.
8. Last item ≥ 256^(5 − size) → **return failure**.
9. Combine: `ipv4 = last + n₁·256³ + n₂·256² + n₃·256`.

**IPv4 number parser:** `0X`/`0x` prefix → radix 16 + validationError; leading `0` → radix 8 +
validationError; empty after stripping → `(0, true)`; a non-radix digit → failure.

**IPv6 parser:** at most one `::`; exactly 8 pieces (`IPv6-too-few-pieces` / `IPv6-too-many-pieces`
are fatal); each piece at most 4 hex digits; leading zeros in a piece are a **non-fatal**
validation error; an embedded dotted quad must have exactly 4 parts
(`IPv4-in-IPv6-too-few-parts` is fatal), each ≤ 255 (fatal), with **no leading zeros** (fatal);
`<zone_id>` support *"is intentionally omitted"*.

**Forbidden host code points:** NUL, TAB, LF, CR, space, `#`, `/`, `:`, `<`, `>`, `?`, `@`, `[`,
`\`, `]`, `^`, `|`. Note `%` is *not* on that list, which is why the zone-ID question is a policy
decision rather than a syntactic one.

**Serializers:** IPv4 serializer is plain dotted decimal via repeated mod-256. IPv6 serializer
*"identifies the longest run of consecutive zero pieces"*, uses `::` for it, and emits the rest
as lowercase hex without leading zeros — i.e. it implements RFC 5952 §§4.1/4.2.1/4.3, **but
not §4.2.2 as stated**; see G-19.

### POSIX `inet_pton` vs `inet_aton`

`inet_pton(3)`, `AF_INET`: *"src points to a character string containing an IPv4 network address
in dotted-decimal format, 'ddd.ddd.ddd.ddd', where ddd is a decimal number of up to three digits
in the range 0 to 255."* Four parts, decimal only. glibc additionally rejects leading zeros — the
CPython docs describe the post-CVE `ipaddress` behaviour as *"now parsed as strict as glibc
`inet_pton()`"*.

`inet_pton(3)`, `AF_INET6`: preferred form (eight hex 16-bit values), `::` compression
(*"Only one instance of :: can occur in an address"*), and `x:x:x:x:x:x:d.d.d.d`. **No zone IDs.**

`inet_aton(3)`: four accepted forms, quoted —

- `a.b.c.d` — *"Each of the four numeric parts specifies a byte of the address."*
- `a.b.c` — *"Part c is interpreted as a 16-bit value that defines the rightmost two bytes."*
- `a.b` — *"Part b is interpreted as a 24-bit value that defines the rightmost three bytes."*
- `a` — *"The value a is interpreted as a 32-bit value that is stored directly into the binary
  address without any byte rearrangement."*

and in all of them, *"components of the dotted address can be specified in decimal, octal (with a
leading 0), or hexadecimal, with a leading 0X"*. The man page states the relationship plainly:
*"inet_aton and inet_addr allow the more general numbers-and-dots notation (hexadecimal and octal
number formats, and formats that don't require all four bytes to be explicitly written)."*

`inet_addr(3)` has an additional documented defect: *"If the input is invalid, INADDR_NONE
(usually -1) is returned. Use of this function is problematic because -1 is a valid address
(255.255.255.255)."*

`getaddrinfo(3)` inherits `inet_aton` for numeric IPv4 hosts (*"for IPv4, numbers-and-dots
notation as supported by inet_aton(3)"*) and `inet_pton` for IPv6. **This is the single most
important fact in this document:** the resolver is permissive even where your language's
`ipaddress`-equivalent is strict.

### RFC 3986 §3.2.2 — host in a URI

```
host        = IP-literal / IPv4address / reg-name
IP-literal  = "[" ( IPv6address / IPvFuture  ) "]"
IPvFuture   = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
dec-octet   = DIGIT / %x31-39 DIGIT / "1" 2DIGIT
            / "2" %x30-34 DIGIT / "25" %x30-35
h16         = 1*4HEXDIG
ls32        = ( h16 ":" h16 ) / IPv4address
```

Three consequences that bite:

- IPv6 literals **must** be bracketed: *"A host identified by an Internet Protocol literal
  address, version 6 … is distinguished by enclosing the IP literal within square brackets"*, and
  this is *"the only permissible bracket usage in URI syntax."*
- `dec-octet` **forbids leading zeros** by construction. `010.0.0.1` does not match
  `IPv4address`; under first-match-wins it falls through to `reg-name`, i.e. RFC 3986 says
  `010.0.0.1` is a *hostname*. WHATWG says it is `8.0.0.1`. Same string, three answers across
  three specs (RFC 3986: name; WHATWG: 8.0.0.1; `getaddrinfo`: 8.0.0.1).
- The RFC 3986 `IPv6address` production has no `%` — *"The specification does not currently
  account for IPv6 zone identifiers"*. RFC 6874 was written to patch exactly this.

### RFC 4007 §11 and RFC 6874 — zone IDs

RFC 4007 §11: syntax is `<address>%<zone_id>`; *"'%' is a delimiter character to distinguish
between <address> and <zone_id>"*. An implementation *"SHOULD support at least numerical indices
that are non-negative decimal integers as <zone_id>"* and *"MAY support other kinds of non-null
strings"*, with *"the precise format and semantics of additional strings … implementation
dependent."* Crucially, the notation *"MUST be used only within a node and MUST NOT be sent on
the wire."*

RFC 6874 lifts it into URIs:

```
IP-literal = "[" ( IPv6address / IPv6addrz / IPvFuture ) "]"
ZoneID     = 1*( unreserved / pct-encoded )
IPv6addrz  = IPv6address "%25" ZoneID
```

*"Any occurrences of literal '%' symbols in a URI MUST be percent-encoded and represented in the
form '%25'"* — so `fe80::a%en1` becomes `http://[fe80::a%25en1]`. RFC 6874 also warns that
*"URIs including a ZoneID are to be interpreted only in the context of the host at which they
originate, since the ZoneID is of local significance only"*, and that *"implementations MUST NOT
allow use of this format except for well-defined usages, such as sending to link-local addresses
under prefix fe80::/10"*, with intermediaries required to strip the zone.

Status: **RFC 6874 lost.** Browsers declined to implement it; the WHATWG marked the zone ID
*"intentionally omitted"* and later rejected a request to add it; `draft-ietf-6man-rfc6874bis`
*"failed to achieve consensus and was not published."* So the `%25` form in the matrix above is
rejected essentially everywhere, while the bare `%` form is accepted by everything *except*
URL parsers. That is the inverse of what the RFCs say.

### Reverse-pointer forms

- **in-addr.arpa** (RFC 1035 §3.5): the four octets reversed, then `.IN-ADDR.ARPA`.
  `10.2.0.52` → `52.0.2.10.IN-ADDR.ARPA`. Traps: the reversal, the case (DNS names are
  case-insensitive but tooling often isn't), and the fact that a *prefix* shorter than /24 has no
  single in-addr.arpa name — see G-27.
- **ip6.arpa** (RFC 3596 §2.5): *"a sequence of nibbles separated by dots with the suffix
  '.IP6.ARPA'. The sequence of nibbles is encoded in reverse order … Each nibble is represented
  by a hexadecimal digit."* `4321:0:1:2:3:4:567:89ab` →
  `b.a.9.8.7.6.5.0.4.0.0.0.3.0.0.0.2.0.0.0.1.0.0.0.0.0.0.0.1.2.3.4.IP6.ARPA`. RFC 3596 does
  **not** literally state the 32-nibble count (`UNVERIFIED` as RFC wording), though the example
  demonstrates it. Note the older `IP6.INT` domain is deprecated.

---

## Security history

Seven CVEs, one root cause: **a validator and a fetcher disagreed about the same string.**

### CVE-2021-29921 — CPython `ipaddress`, leading zeros

NVD: *"In Python before 3.9.5, the ipaddress library mishandles leading zero characters in the
octets of an IP address string."* CVSS v3.1 **9.8 Critical**. Affected 3.8.0–3.8.11 and
3.9.0–3.9.4.

**What was wrong:** `ipaddress.ip_address('0177.0.0.1')` *silently stripped* the leading zeros and
returned `177.0.0.1` — a public address. The application then handed the original string to
`socket`/`requests`, which went through `getaddrinfo` → `inet_aton` → octal → **`127.0.0.1`**.
Allowlist says "public, fine"; the socket goes to loopback.

**Consequence:** SSRF/access-control bypass. Fixed by rejecting leading zeros outright in 3.9.5
and 3.8.12; the docs now record *"Changed in version 3.9.5: Leading zeros are no longer tolerated
and are treated as an error. IPv4 address strings are now parsed as strict as glibc
`inet_pton()`."* Note 3.8 had explicitly *added* the tolerance: *"Changed in version 3.8: Leading
zeros are tolerated, even in ambiguous cases that look like octal notation."* The fix is a
deliberate reversal.

### CVE-2021-28918 — npm `netmask` ≤ 1.0.6, octal strings

NVD: *"Improper input validation of octal strings in netmask npm package v1.0.6 and below allows
unauthenticated remote attackers to perform indeterminate SSRF, RFI, and LFI attacks."*
CVSS v3.1 **9.1 Critical**, CWE-704 (Incorrect Type Conversion or Cast).

**What was wrong:** SICK-2021-011 states it precisely: *"a remote unauthenticated attacker can
request local resources using input data `0177.0.0.1` (127.0.0.1), which netmask evaluates as
public IP `177.0.0.1`."* Same stripped-zero bug as Python, in a package with ~270,000 dependents.

**Consequence:** SSRF, RFI and LFI in anything using `netmask` as an internal/external gate.
Fixed in 2.0.0.

### CVE-2021-29418 — npm `netmask` < 2.0.1, incomplete fix

NVD: *"The netmask package before 2.0.1 for Node.js mishandles certain unexpected characters in
an IP address string, such as an octal digit of 9. This (in some situations) allows attackers to
bypass access control that is based on IP addresses."* CVSS v3.1 **5.3**, CWE-20, explicitly
*"an incomplete remediation of CVE-2021-28918."*

**What was wrong:** the 2.0.0 fix handled valid octal but not *invalid* octal. `0129.0.0.1`
contains `9`, which is not an octal digit. `inet_aton` **rejects** the whole string; netmask
2.0.0 kept parsing and produced some other address. The lesson generalises: the interesting
divergence is not "how do parsers read octal" but "at which byte do they give up".

**Consequence:** the same access-control bypass, one round later.

### CVE-2020-28360 — npm `private-ip` ≤ 1.0.5, regex instead of a parser

NVD: *"Insufficient RegEx in private-ip npm package v1.0.5 and below insufficiently filters
reserved IP ranges."* CVSS v3.1 **9.8 Critical**, CWE-918 (SSRF).

**What was wrong:** the library decided "is this address private?" with regular expressions over
the *text*, not by parsing to 32 bits and testing prefix membership. Any alternative textual form
— octal, hex, short-form, or simply a reserved range the regex list had missed — slid past.

**Consequence:** SSRF to reserved/internal ranges, with RCE as the documented downstream. This is
the canonical argument for `raddr`'s design: **never classify an address from its text.**

### CVE-2021-29922 — Rust `std::net::Ipv4Addr`, leading zeros

RustSec: *"IP address octets are left stripped instead of evaluated as valid IP addresses"* —
`010.8.8.8` parsed as `10.8.8.8`. Fixed in **Rust ≥ 1.53.0**.

**What was wrong / consequence:** identical to CVE-2021-29921. The fix rejects leading zeros
rather than honouring octal, which means Rust now disagrees with `getaddrinfo` in the *safe*
direction (refusal) rather than the unsafe one (wrong answer).

### CVE-2021-29923 — Go `net`, leading zeros

*"Go before 1.17 does not properly consider extraneous zero characters at the beginning of an IP
address octet, which (in some situations) allows attackers to bypass access control that is based
on IP addresses, because of unexpected octal interpretation."* Affects `net.ParseIP` and
`net.ParseCIDR`.

Go's own release note is notably more grudging than the CVSS: *"These components were always
interpreted as decimal, but some operating systems treat them as octal. This mismatch could
hypothetically lead to security issues if a Go application was used to validate IP addresses
which were then used in their original form with non-Go applications."* Go declined to backport,
deeming it *"not a serious security risk"* — and Kubernetes then had to ship a deprecation path
and an e2e test for it (kubernetes#108074, kubernetes#104368). Disclosed at DEF CON by Cheng Xu,
Victor Viale, Sick Codes, Nick Sahler, Kelly Kaoudis, opennota and John Jackson.

### CVE-2021-29662 — Perl `Data::Validate::IP` ≤ 0.29

Named in SICK-2021-011 as *"a parallel vulnerability … with an identical class of octal parsing
defects."* Details `UNVERIFIED` beyond that reference.

### JDK-8277608 / NCC Group advisory — `java.net.InetAddress`

NCC Group (Oct 2022, no CVE assigned at publication: *"Advisory URL / CVE Identifier: TBD"*)
documented two distinct problems in Java 8–17+:

1. **BSD-style literals accepted by default** — `0x7f.016.0.0xa`, `017700000001`, `0x7f000001`.
2. **Zone-identifier boundary not validated** — inputs like `::1%1]foo.bar baz'"` and
   `[::ffff:1.1.1.1%1]foo.bar baz'"]` were accepted, with the trailing junk simply ignored. That
   is a *truncation* bug: a validator sees `::1%1` and an emitter/logger sees the whole string.

Fixed by the October 2022 CPU: ambiguous IPv4 literals are rejected unless
`-Djdk.net.allowAmbiguousIPAddressLiterals=true`. NCC contrasted this with Android/bionic
`getaddrinfo`, which *"parses IP addresses extremely strictly."*

### The 2021 "octal SSRF" class, generally

Every one of the above is the same shape:

```
attacker string ──> VALIDATOR (strict-ish, strips or ignores)  ──> "public, allow"
                └─> FETCHER   (inet_aton, honours octal)       ──> 127.0.0.1
```

The defect is never in one parser. It is in the *pair*. This is the design justification for
reporting disagreements instead of picking a winner: a library that returns "glibc says
127.0.0.1, Go says reject, RFC 3986 says this is a hostname" makes the bug visible at the point
where it is introduced.

---

## Gotchas

**IPv4 textual forms**

1. **The one-, two- and three-part forms are not legacy trivia; they are live.** `inet_aton(3)`
   defines `a`, `a.b`, `a.b.c`, `a.b.c.d`, and `getaddrinfo(3)` inherits them. `127.1` reaches
   loopback through glibc, musl, Windows (`RtlIpv4StringToAddress` with `Strict = FALSE`) and
   every browser. It is rejected by `inet_pton`, Python `ipaddress`, Go, and Rust. Any code that
   validates with the second group and connects with the first is exploitable.

2. **Windows makes the choice an API parameter.** `RtlIpv4StringToAddress` takes a `Strict`
   BOOLEAN: *"If this parameter is TRUE, the string must be dotted-decimal with four parts. If
   this parameter is FALSE, any of four possible forms are allowed, with decimal, octal, or
   hexadecimal notation."* Same OS, same function, two grammars, selected by a caller who may not
   know the difference exists.

3. **`http://0/` is localhost.** WHATWG's ends-in-a-number checker routes `0` to the IPv4 parser,
   which yields `0.0.0.0`; `inet_aton`'s one-part form does the same. On Linux and macOS
   `0.0.0.0` as a *destination* is treated as "this host". Allowlists built on string prefixes
   (`127.`, `localhost`) miss it entirely. Same trick: `0x0`, `0.0.0.0`, `[::]`.

4. **Leading zeros are not "just ignorable".** Three mutually incompatible behaviours are in
   production simultaneously: honour as octal (`inet_aton`, WHATWG, curl ≥ 7.77.0, Windows
   non-strict), strip and read as decimal (pre-fix Python/Go/Rust/netmask/Java — the CVE
   behaviour), and reject (`inet_pton`, post-fix Python/Go/Rust/Java, RFC 3986 `dec-octet`).
   Reporting only one answer is a lie by omission.

5. **`1.2.3.04` and `1.2.3.4` are the same address; `1.2.3.08` is not an address at all.**
   A test suite that only checks `04` will conclude "octal is harmless here" and miss that
   `08` changes the *failure mode*, which is what CVE-2021-29418 was.

6. **Mixed radix within one literal is legal for `inet_aton`.** `0x8.0X8.010.8` mixes hex, hex,
   octal and decimal in four parts, and glibc/musl parse each part independently with base-0
   `strtoul`. There is no rule that all parts share a radix.

7. **The last part's bound depends on how many parts there are.** WHATWG step 8: last item must
   be `< 256^(5 − size)`. So `1.16777215` is valid (`1.255.255.255`) but `1.16777216` is not,
   and `1.2.256` is invalid while `1.2.65535` is valid (`1.2.255.255`). Parsers that hardcode
   "each part ≤ 255" get the short forms wrong.

8. **`4294967295` is `255.255.255.255`; `4294967296` is nothing.** One-part overflow is the only
   thing separating them, and the strict parsers reject both, so a "does it parse?" check
   disagrees with a "what does it mean?" check.

9. **`inet_addr` cannot distinguish failure from `255.255.255.255`.** The man page says so
   directly: *"Use of this function is problematic because -1 is a valid address."* Any code
   still on `inet_addr` mis-handles the broadcast address. Prefer `inet_aton`'s separate return.

10. **glibc's `inet_aton` ignores trailing garbage.** The glibc source carries the comment
    *"inet_aton ignores trailing garbage"*, which is why glibc had to add `__inet_aton_exact`
    (`*endp == 0`) for internal callers. `1.2.3.4whatever` succeeds. musl rejects it. Two Linux
    libcs, opposite answers, same function name.

11. **glibc `inet_aton` accepts trailing whitespace; musl does not.** glibc:
    `if (c != '\0' && (!isascii (c) || !isspace (c))) goto ret_0;`. musl's loop rejects any byte
    that is not `.` or NUL. `"1.2.3.4 "` from a trimmed-vs-untrimmed config file therefore
    resolves on Debian and fails on Alpine.

12. **A trailing dot is a WHATWG-only address.** `1.2.3.4.` parses to `1.2.3.4` in browsers
    (`IPv4-empty-part` is non-fatal) and fails in glibc, musl, `inet_pton`, Python, Go and Rust.
    Trailing dots are meaningful in DNS (fully-qualified), so this is a place where the "is it a
    name or an address?" question genuinely has two right answers.

13. **`1.2.3.4.5` fails everywhere, and that uniformity is worth asserting in tests.** WHATWG's
    `IPv4-too-many-parts` is one of the few fatal conditions in that algorithm.

14. **Embedded whitespace and control characters are removed at the URL layer, not the host
    layer.** Space is a WHATWG *forbidden host code point*, but the URL parser strips leading and
    trailing C0 controls and spaces from the whole URL and removes all ASCII tab/LF/CR
    *anywhere* before parsing. So `"http://1.2.3.4 "` works, and `"http://1.2.\n3.4/"` works,
    while a bare host string `"1.2.3.4 "` handed to the host parser does not. Whether your input
    is "a URL" or "a host" changes the answer.

15. **RFC 3986 and WHATWG disagree about what `010.0.0.1` even *is*.** RFC 3986 `dec-octet`
    excludes leading zeros, so under first-match-wins the string is a `reg-name` — a *hostname*,
    to be sent to DNS. WHATWG says it is the address `8.0.0.1`. Neither is wrong; they are
    different specifications with the same scope.

**IPv6 textual forms**

16. **RFC 4291 §2.2 permits what RFC 5952 §4 forbids.** Uppercase, leading zeros, `::` over a
    single zero group, and non-maximal compression are all *valid input* and all *invalid
    output*. Treating RFC 5952 as a parsing grammar breaks interoperability with conforming
    senders; treating it as optional breaks string comparison. Both failure modes are common.

17. **`::ffff:127.0.0.1` formats four different ways.** RFC 5952 §5 recommends the mixed form for
    well-known-prefix embeddings; glibc `inet_ntop` special-cases IPv4-mapped and emits
    `::ffff:127.0.0.1`; Go's `net.IP.String` emits bare `127.0.0.1` while `netip.Addr.String`
    *"format[s] with a '::ffff:' prefix before the dotted quad"* — the Go docs flag this
    difference explicitly; Python `ipaddress` emits `::ffff:7f00:1` (`UNVERIFIED` — inferred from
    the general serializer, not a doc statement); Java's `getHostAddress` emits the fully
    expanded `0:0:0:0:0:ffff:7f00:1` (`UNVERIFIED`). All five denote the same 128 bits.

18. **IPv4-mapped is an SSRF bypass surface.** A filter that checks "is this in 127.0.0.0/8"
    against the *IPv4* representation never sees `::ffff:127.0.0.1`, and vice versa. Same for
    `::ffff:169.254.169.254` against cloud metadata filters. `raddr` should always report the
    embedded IPv4 alongside the IPv6.

19. **RFC 5952 §4.2.2 is the most-violated formatting rule.** *"'::' MUST NOT be used to shorten
    just one 16-bit 0 field."* The WHATWG IPv6 serializer as specified compresses *"the longest
    run of consecutive zero pieces"* — which, when the longest run is length 1, produces exactly
    the form §4.2.2 forbids (`UNVERIFIED` whether the spec adds a length ≥ 2 guard; the
    summary text I retrieved does not mention one). Any round-trip test that compares WHATWG
    output to RFC 5952 canonical output must handle this case.

20. **RFC 5952 §4.2.3's tie-break is a real behavioural fork.** With two equal-length zero runs,
    *"the first sequence of zero bits MUST be shortened"*: `2001:db8:0:0:1:0:0:1` must become
    `2001:db8::1:0:0:1`, not `2001:db8:0:0:1::1`. Naïve "longest run, last wins" implementations
    produce the second.

21. **Leading zeros in a hextet: valid input, forbidden output, warned by WHATWG.** RFC 4291 §2.2
    allows *"one to four hexadecimal digits"*; RFC 5952 §4.1 says *"Leading zeros MUST be
    suppressed"*; WHATWG raises a non-fatal `IPv6-piece-leading-zero`. `2001:db8::00ff` is
    accepted by everything and re-emitted by nothing.

22. **Five hex digits in a hextet is a hard failure, and the failure point is subtle.** In WHATWG
    the hex loop is capped (*"While length is less than 4"*), so `::00001` fails not on a
    "too many digits" rule but because the fifth character is neither `:` nor end-of-input. Error
    *messages* from different parsers for the same string will therefore describe different
    problems.

23. **Leading zeros in the dotted-quad tail are fatal in WHATWG, unlike leading zeros in a
    standalone IPv4 host.** `010.0.0.1` → warning + `8.0.0.1`; `::010.0.0.1` → *failure*
    (`IPv4-in-IPv6-invalid-code-point`). The same digits, in the same spec, with opposite
    outcomes depending on context.

24. **The dotted-quad tail is decimal-only and exactly-four-parts, even where the standalone IPv4
    parser is not.** `::ffff:1.2.3` and `::ffff:0x7f.1` are rejected by `inet_pton` and WHATWG
    alike; there is no octal/hex/short-form escape hatch inside an IPv6 literal.

25. **`::1.2.3.4` is a *deprecated* IPv4-compatible address, and RFC 5952 §5 says not to write it
    that way.** Mixed notation is only recommended when the prefix marks a genuine embedding.
    Round-trip: `::1.2.3.4` in, `::102:304` out. Users report this as a bug; it is the spec.

26. **Group counting is off-by-one-prone in both directions.** Seven groups without `::` is too
    few, nine is too many, and `::` must expand to *at least one* zero group under RFC 4291 §2.2
    — but note `1:2:3:4:5:6:7::` (`::` expanding to exactly one group) is a legal parse while
    being a §4.2.2 formatting violation to emit.

**Zone IDs / scope IDs**

27. **`inet_pton` cannot parse a zone ID at all.** Neither the `AF_INET6` description nor the
    grammar admits `%`. Code that "validates with `inet_pton`, then connects with `getaddrinfo`"
    rejects every link-local address a user can actually reach.

28. **musl rejects a zone on a non-link-local address; glibc does not.** musl's
    `__lookup_ipliteral` gates on
    `if (!IN6_IS_ADDR_LINKLOCAL(&a6) && !IN6_IS_ADDR_MC_LINKLOCAL(&a6)) return EAI_NONAME;`.
    `::1%lo0` therefore resolves on Debian and fails on Alpine. RFC 6874 §3 agrees with musl in
    spirit (*"MUST NOT allow use of this format except for well-defined usages, such as sending
    to link-local addresses"*), but the RFC governs URIs, not `getaddrinfo`.

29. **Zone IDs are opaque strings whose meaning is per-host and per-OS.** RFC 4007 §11: an
    implementation *"SHOULD support at least numerical indices"* and *"MAY support other kinds of
    non-null strings"*, with *"the precise format and semantics … implementation dependent"*.
    `%1` means a different interface on every machine; `%eth0` may not exist. Two textually
    identical addresses can denote different destinations. RFC 4007 §11 adds the hard rule: the
    notation *"MUST be used only within a node and MUST NOT be sent on the wire."*

30. **BSD and macOS *fold the scope ID into the address bits*.** The FreeBSD Developers' Handbook
    (ch. 8, KAME): *"an interface index for link-local scoped address is embedded into 2nd
    16bit-word (3rd and 4th byte) in IPv6 address"*, and it warns *"When you specify scoped
    address to the command line, you should not write the embedded form (such as ff02:1::1 or
    fe80:2::fedc)."* The embedded index *"becomes visible on PF_ROUTE socket and kernel memory
    accesses"*. So `fe80::1%1` may resurface from the routing table as `fe80:1::1` — an address
    whose text no longer matches what was entered and whose bits are not what was on the wire.
    This is the single most surprising IPv6 behaviour in this document.

31. **URI zone syntax (`%25eth0`) is a dead letter.** RFC 6874 requires `fe80::a%25en1` inside
    brackets. Browsers never implemented it, the WHATWG marked zone IDs *"intentionally
    omitted"* and rejected a proposal to add them, and `rfc6874bis` *"failed to achieve consensus
    and was not published."* Practical result: `%` works in `getaddrinfo`/Python/Go/Java and
    nowhere in a URL, while `%25` works nowhere at all.

32. **Zone-ID boundaries are a truncation attack surface.** The NCC Group OpenJDK advisory found
    `InetAddress` accepting `::1%1]foo.bar baz'"` — validating the prefix and discarding the rest.
    Anywhere a parser stops at `%` without anchoring the end of input, a validator and a logger
    or emitter can be shown two different strings.

33. **Rust `std::net` has no zone support.** The `Ipv6Addr` docs describe only hex groups and
    point at RFC 5952; there is no `scope_id`. `UNVERIFIED` as an explicit rejection statement,
    but the type has nowhere to store one. Go (`netip.Addr` carries a `Zone`) and Python
    (`IPv6Address.scope_id`, added with RFC 4007 semantics; *"must be non-empty and may not
    contain `%`"*) do support it. Note Python does **not** validate that the zone names a real
    interface — it is stored as an opaque string.

**Brackets, URIs and round-trips**

34. **Brackets are mandatory in a URI and forbidden in a bare literal.** RFC 3986 §3.2.2 makes
    `[...]` *"the only permissible bracket usage in URI syntax"*. A single code path that accepts
    both `::1` and `[::1]` will also accept `[::1` and `::1]`; the WHATWG host parser checks
    bracket closure explicitly.

35. **`[` and `]` are forbidden host code points *outside* the IPv6 branch**, along with NUL,
    TAB, LF, CR, space, `#`, `/`, `:`, `<`, `>`, `?`, `@`, `\`, `^`, `|`. `%` is conspicuously
    absent — the zone-ID exclusion is a deliberate policy choice, not a grammar consequence.

36. **Parse-then-format is not the identity function.** Documented round-trip failures:
    `2001:0db8::0001` → `2001:db8::1` (§4.1); `2001:DB8::1` → `2001:db8::1` (§4.3);
    `2001:db8:0:0:0:0:2:1` → `2001:db8::2:1` (§4.2.1); `::1.2.3.4` → `::102:304` (§5);
    `010.0.0.1` → `8.0.0.1` (WHATWG); `127.1` → `127.0.0.1`; `1.2.3.4.` → `1.2.3.4` (WHATWG);
    `0` → `0.0.0.0`. Any equality test written over *text* rather than bits is wrong, which is
    the exact conclusion RFC 6943 §3.1.1 reaches: *"if comparison relies on strings rather than
    binary forms, security failures occur."*

37. **curl changed sides in 7.77.0.** Before that release curl *"mostly accidentally somewhat
    supported the 'flexible' IPv4 address formats"* by delegating to the system resolver, which
    broke TLS certificate matching and `Host:` headers. Since 7.77.0 curl *"will 'natively'
    understand these IPv4 formats and normalize them itself"*, following WHATWG rather than
    RFC 3986 — Stenberg notes RFC 3986 requires strict `dec-octet` but *"in reality very few
    clients that accept such URLs actually restrict the addresses to that format."* Version
    number changes the answer; pin it in any conformance claim.

38. **`getaddrinfo` flag defaults differ between glibc and musl, which changes what you get back
    even when parsing agrees.** glibc defaults to `AI_ADDRCONFIG|AI_V4MAPPED`, musl to `0`; musl
    may return addresses unreachable from the host, and glibc will synthesise IPv4-mapped IPv6
    where musl will not. Parsing is only half the divergence.

39. **Reverse-pointer names are a separate parser with its own traps.** Nibble reversal (ip6.arpa)
    and octet reversal (in-addr.arpa) are easy to get backwards; ip6.arpa requires the *fully
    expanded* 32 nibbles, so any zero compression must be undone first; both are
    case-insensitive as DNS names but are conventionally written in one case; and a prefix
    shorter than /24 (IPv4) or not on a nibble boundary (IPv6) has no single reverse name at all,
    which is what RFC 2317 classless delegation exists to work around (`UNVERIFIED` — RFC 2317
    not fetched for this note).

40. **The `raddr` conclusion.** For every literal in the matrix above there is at least one pair
    of widely deployed implementations that disagree, and in the CVE cases the disagreement was
    silent. A parser that returns a single answer is asserting a fact that is not true of the
    world. Returning the set — `{glibc: X, WHATWG: Y, strict: reject, RFC 3986: hostname}` — is
    both more honest and, per RFC 6943, more secure.

---

## Source list

Standards: [RFC 4291 §2.2](https://www.rfc-editor.org/rfc/rfc4291.txt) ·
[RFC 5952](https://www.rfc-editor.org/rfc/rfc5952.txt) ·
[RFC 4007 §11](https://www.rfc-editor.org/rfc/rfc4007.txt) ·
[RFC 6874](https://www.rfc-editor.org/rfc/rfc6874.txt) ·
[RFC 3986 §3.2.2](https://www.rfc-editor.org/rfc/rfc3986.txt) ·
[RFC 6943 §3.1](https://www.rfc-editor.org/rfc/rfc6943.txt) ·
[RFC 3596 §2.5](https://www.rfc-editor.org/rfc/rfc3596.txt) ·
[WHATWG URL Standard](https://url.spec.whatwg.org/) ([IPv4 parser](https://url.spec.whatwg.org/#concept-ipv4-parser),
[IPv6 parser](https://url.spec.whatwg.org/#concept-ipv6-parser))

Implementations: [`inet_aton(3)`](https://man7.org/linux/man-pages/man3/inet_aton.3.html) ·
[`inet_pton(3)`](https://man7.org/linux/man-pages/man3/inet_pton.3.html) ·
[`getaddrinfo(3)`](https://man7.org/linux/man-pages/man3/getaddrinfo.3.html) ·
[glibc `resolv/inet_addr.c`](https://raw.githubusercontent.com/bminor/glibc/master/resolv/inet_addr.c) ·
[musl `inet_aton.c`](https://git.musl-libc.org/cgit/musl/plain/src/network/inet_aton.c) ·
[musl `lookup_ipliteral.c`](https://git.musl-libc.org/cgit/musl/plain/src/network/lookup_ipliteral.c) ·
[musl functional differences from glibc](https://wiki.musl-libc.org/functional-differences-from-glibc.html) ·
[`RtlIpv4StringToAddress`](https://learn.microsoft.com/en-us/windows/win32/api/ip2string/nf-ip2string-rtlipv4stringtoaddressa) ·
[CPython `ipaddress`](https://docs.python.org/3/library/ipaddress.html) ·
[Go `net/netip`](https://pkg.go.dev/net/netip) ·
[Rust `Ipv6Addr`](https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html) ·
[FreeBSD Developers' Handbook ch. 8 (KAME scope IDs)](https://docs.freebsd.org/en/books/developers-handbook/ipv6/)

Advisories and write-ups:
[CVE-2021-29921](https://nvd.nist.gov/vuln/detail/CVE-2021-29921) ·
[CVE-2021-28918](https://nvd.nist.gov/vuln/detail/CVE-2021-28918) ·
[CVE-2021-29418](https://nvd.nist.gov/vuln/detail/CVE-2021-29418) ·
[CVE-2020-28360](https://nvd.nist.gov/vuln/detail/CVE-2020-28360) ·
[CVE-2021-29922 (RustSec)](https://rustsec.org/advisories/CVE-2021-29922.html) ·
[SICK-2021-011](https://sick.codes/sick-2021-011/) ·
[SICK-2021-016](https://sick.codes/sick-2021-016/) ·
[NCC Group — OpenJDK weak parsing logic](https://www.nccgroup.com/research-blog/technical-advisory-openjdk-weak-parsing-logic-in-javanetinetaddress-and-related-classes/) ·
[Daniel Stenberg — curl those funny IPv4 addresses](https://daniel.haxx.se/blog/2021/04/19/curl-those-funny-ipv4-addresses/) ·
[Dave Anderson — Fun with IP address parsing](https://blog.dave.tf/post/ip-addr-parsing/) ·
[BleepingComputer — Go/Rust net library IP validation](https://www.bleepingcomputer.com/news/security/go-rust-net-library-affected-by-critical-ip-address-validation-vulnerability/) ·
[kubernetes#108074 — deprecate IPs with leading zeros](https://github.com/kubernetes/kubernetes/issues/108074) ·
[golang/go d3e3d03 — reject leading zeros in IP address parsers](https://github.com/golang/go/commit/d3e3d03666bbd8784007bbb78a75864aac786967) ·
[draft-schinazi-httpbis-link-local-uri-bcp (zone IDs in URIs, history)](https://www.ietf.org/archive/id/draft-schinazi-httpbis-link-local-uri-bcp-03.html)
