# Architecture

Durable design decisions for `raddr`. This file supersedes `_scratch/SPEC.md`
wherever the two disagree; the scratch documents remain the authority for
*evidence* (what was measured) but not for *design* (what we decided).

**Provenance.** Decisions below were settled in a review session on 2026-07-26.
Empirical claims marked **[verified 2026-07-26]** were measured on this machine:
macOS Darwin 25.4.0 arm64, R 4.6.0, `ipaddress` 1.0.3, `adaR` 0.3.5,
libcurl 8.14.1, Python 3.x, Apple libc.

Claims marked **[verified 2026-07-27]** were measured on the same machine during
Epic E, and additionally against Python 3.9.6 / 3.12.13 / 3.14.6, Rust 1.91.1,
Ruby 2.6.10, PHP 8.5.7 and Node 26.3.1. `data-raw/survey-zone.sh` reproduces the
cross-implementation ones; §11's numbers come from `bench/record.R`.

---

## 1. What raddr is

**The `rurl` of IPs.** A pure, offline R package that reports what an IP address
literal means under each of the standards and implementations that disagree
about it, and classifies *parsed values* against the IANA special-purpose
registries.

raddr is a **shower**, not a **protector**. It reports facts; it never returns a
verdict, a risk score, or an allow/deny decision. That distinction places it
alongside `rurl`, `pslr`, and `punycoder` in this stack, and deliberately apart
from `linklint`, which is a protector.

The thesis, in one string **[verified 2026-07-26]**:

```
"0177.0.0.1"
  strict (RFC / Python ipaddress / Go / Rust)   -> reject
  whatwg (= browsers)                           -> 127.0.0.1
  pton   (Apple libc)                           -> 177.0.0.1
  aton   (BSD)                                  -> 127.0.0.1
```

Three outcomes, one string, one machine. Every existing library picks one and
discards the rest. raddr does not pick.

### 1.1 Not in scope, permanently

| Excluded | Owner |
|---|---|
| DNS resolution, hostname lookup | `ssrfr` / `curl` |
| HTTP, redirects, connection pinning | `ssrfr` |
| Allow/deny policy, risk scores, verdicts | `ssrfr` |
| Cloud-metadata endpoint tables | `ssrfr` |
| "Most restrictive reading wins" convenience | `ssrfr` |
| Geolocation, ASN, country data | nowhere |
| IDNA, punycode | `punycoder` |
| Public-suffix logic | `pslr` |
| URL parsing, scheme/port policy, reg-name-vs-IP host form | `rurl` |
| General CIDR set algebra (collapse, exclude, subnets) | `ipaddress` |
| `X-Forwarded-For` extraction (HTTP header parsing, not address parsing) | `ssrfr` |
| Visualization | `ggip` |

---

## 2. Design principles

**P1 — A string may never be classified.** `addr_classify()` accepts a parsed
value and nothing else. No exported function takes `character` and returns a
classification.

**P2 — Unparseable is a distinct outcome, never bare `NA`.** Scoped to
`addr_parse()`, raddr's primary answer: every `addr_parse()` result carries a
named outcome the consumer must read. `NA` fails silently in every R idiom a
consumer reaches for. The six single-dialect parsers are an explicit, documented
exception — see §6.1.

**P3 — Dialect is chosen by function name, never by a leniency flag.** No
`strict = FALSE`, no `...`-buried dialect knob. A named function is harder to
"helpfully" default away than an argument.

**P4 — Classification is registry-derived, never hardcoded.** `addr_classify()`
returns the matched IANA row with its RFC citation and all five policy columns.

**P5 — The value the resolver sees is the value that gets classified.**
Formatting never echoes the input.

**P6 — Everything the parser noticed is in the output.** Nothing is silently
normalized away. Scoped like P2 to `addr_parse()`: the single-dialect parsers
return an address without `codes`, and are documented as the shortcut they are.

**P7 — Provenance travels with the verdict.** Registry snapshot version on every
classification; RFC on every reason code; verification date on anything modelled
from an implementation rather than a standard.

**P8 — raddr states facts; consumers make decisions.**

**P9 — Precise beats general, and the specific document beats the summary.**
Where a precise reading and a more general one are both available, take the
precise one — especially where the "tiny edge case" the general reading swallows
has already caused a real-world failure. Three consequences follow, and each has
already been paid for:

- **Vendor the authoritative file; do not hand-transcribe a summary of it.**
  Hand-transcription is reserved for facts with no upstream file at all, which
  is why `R/transition.R` is hand-written and the registries are not. The
  `0xfdffffff` mask that was silently `NA` (§7.2) and the "four of the six
  lengths" that is three (§7.2) were both transcription errors caught late.
- **Keep the source's own granularity.** IANA's IPv6 address-space registry
  spells sixteen reserved rows with distinct citations; collapsing them to
  `::/3`-style aggregates loses `fec0::/10`'s deprecating RFC and `200::/7`'s
  entirely.
- **Cite the document that governs the value, not the one that describes the
  framework.** RFC 6890 defines the special-purpose framework; IANA's registry
  holds the data, and RFC 6890's own tables are a stale 2013 snapshot missing
  about ten current entries. Likewise RFC 2544 §C.2.2.2 contains a typo in the
  benchmarking range and RFC 5180 §8 prints the wrong benchmarking prefix
  (Errata 1752). Cite RFCs for meaning; take values from the registry.

The deciding evidence for P9 **[verified 2026-07-27]**: deriving a classification
table from the special-purpose registry *alone* is a known CVE-producing pattern.
Multicast is not in that registry — it has its own — so PHP's registry-derived
rewrite has no multicast handling at all, and `ssrfcheck` shipped the identical
omission as CVE-2025-8267. Every implementation that gets multicast right does so
by hardcoding it, because the registry they would naturally parse does not
contain it. raddr's answer is to vendor the address-space registries as a
fallback layer under the special-purpose ones (`RADD-pekbpche`), so that the
multicast space is answered from a registry rather than from a literal.

---

## 3. The dialect model

The single most important revision to the draft spec. Dialects sit on **two
axes**, not one list: what a *standard* requires ("on paper") and what an
*implementation* actually does ("in reality").

### 3.1 The four primitives

| Axis | Dialect | Models | Stability |
|---|---|---|---|
| paper | `strict` | RFC dotted-quad grammar; Python `ipaddress`, Go, Rust | fixed |
| paper | `whatwg` | WHATWG URL host parser; what browsers do | fixed, versioned spec |
| reality | `pton` | POSIX `inet_pton` | **platform-varying** |
| reality | `aton` | BSD `inet_aton` | **platform-varying** (see §3.3) |

### 3.2 The two compositions

Both are precedence orderings over the same two reality primitives — not
separate parsers **[verified 2026-07-26]**:

```
addr_getaddrinfo  =  pton, falling back to aton
addr_curl         =  aton, falling back to addr_getaddrinfo
```

Every measured row falls out of those two orderings. They are implemented as
literal compositions of the exported primitives, so a precedence change upstream
is an argument swap, not a rewrite — which is exactly what `RADD-puzhycev` cost
when the second line turned out to be wrong.

**The asymmetry in the second line is deliberate.** `curl` falls back to the
resolver *entry point*, not to the bare parser under it, because curl's URL
layer normalizes a numeric host `aton`-style and hands `getaddrinfo` whatever is
left. `addr_getaddrinfo()`'s whitespace gate is inherited along with it but can
never be seen through `addr_curl()`: the gate tests the text before the `%`,
which is the address text, and `pton` refuses whitespace there anyway — so
wherever the gate would bite, `aton` has already answered. Pinned by running it
over the whole corpus in `test-ipv6.R` rather than left as this paragraph.

**The `curl` ordering was derived, not measured, until 2026-07-28 [§11.6].**
"Verified 2026-07-26" above covered `getaddrinfo`; no `data-raw` script invoked
curl at all, so the `curl` column of §3.3 was produced by the composition it was
being read as evidence for. Running real curl (8.20.0) says:

- **IPv4 — the ordering holds**, on all 78 rows that can be asked. curl's URL
  layer normalizes a numeric host itself, `aton`-style, before the resolver is
  reached, which is why the `aton`-first precedence is right.
- **IPv6 — the ordering was wrong**, and it was `aton, falling back to pton`
  until 2026-07-28. `aton` rejects every IPv6 literal, so the composition *is*
  its fallback, and the fallback has to be `getaddrinfo`. curl's URL layer does
  not normalize an IPv6 literal, so the text reaches `getaddrinfo`, which lifts
  an embedded scope out of a link-local address where `inet_pton` does not
  (§3.5.3). Ten rows differed, all inside `fe80::/10` with a non-zero second
  hextet.

`aton` falling back to **`getaddrinfo`** fits both families with no divergence,
because once `aton` has rejected an IPv4 literal `getaddrinfo` reduces to `pton`
anyway. **That one-argument fix landed as `RADD-puzhycev`**, and the ten rows it
moved are still named in `test-ipv6.R` — as the set where `addr_curl()` and
`addr_pton()` now part company, which is the same set seen from the other side.

**One leak, found while implementing Epic C [verified 2026-07-26].** The
`getaddrinfo` composition is exact except for whitespace. `inet_aton` stops at
the first whitespace character and ignores everything after it, so
`"1.2.3.4 junk"` is an address to it — but `getaddrinfo()` rejects any input
containing whitespace before either primitive sees it:

| input | `pton` | `aton` | `getaddrinfo` |
|---|---|---|---|
| `1.2.3.4 ` | reject | 1.2.3.4 | **reject** |
| `1.2.3.4 x` | reject | 1.2.3.4 | **reject** |
| `1.2 .3.4` | reject | 1.0.0.2 | **reject** |

`addr_getaddrinfo()` therefore rejects whitespace-bearing input first, then
composes. The composition claim holds for every other measured row; this is a
gate in front of it rather than a different precedence.

The gate covers the **address, not the zone ID**. `fe80::1%lo0 ` is accepted and
`fe80::1 %lo0` is not **[verified 2026-07-26]**, so the whitespace test runs on
the text before the `%`. An IPv4 literal carries no `%`, so this is the same
gate it always was for IPv4.

**A second leak, found while implementing Epic D, and it is IPv6-only.** See
§3.5.3: Apple's `getaddrinfo` lifts an embedded scope out of a link-local
address where `inet_pton` does not, so the two disagree on bits for an input
both accept. That one is modelled as a post-step on the composition, for the
same reason the whitespace gate is modelled as a pre-step: the precedence is
right, the entry point does something extra around it.

### 3.3 Measured divergence **[verified 2026-07-26]**

| input | `strict` | `whatwg` | `pton` | `aton` | `getaddrinfo` | `curl` |
|---|---|---|---|---|---|---|
| `127.0.0.1` | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 |
| `0177.0.0.1` | reject | 127.0.0.1 | 177.0.0.1 | 127.0.0.1 | 177.0.0.1 | 127.0.0.1 |
| `192.0.010.1` | reject | 192.0.8.1 | 192.0.10.1 | 192.0.8.1 | 192.0.10.1 | 192.0.8.1 |
| `192.0.048.1` | reject | reject | 192.0.48.1 | reject | 192.0.48.1 | 192.0.48.1 |
| `4294967296` | reject | reject | reject | 0.0.0.0 | 0.0.0.0 | 0.0.0.0 |
| `1.2.3.` | reject | 1.2.0.3 | reject | reject | reject | reject |
| `2130706433` | reject | 127.0.0.1 | reject | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 |
| `10.048.1.1` | reject | reject | 10.48.1.1 | reject | 10.48.1.1 | 10.48.1.1 |

Two rows carry most of the package's value:

- **`192.0.048.1`** — curl reaches a host a browser refuses to dial.
- **`4294967296`** — `aton` wraps modulo 2^32 to `0.0.0.0`; the standards reject.

**Both reality dialects are platform-dependent**, not just `pton`.

- `pton` — Apple libc strips leading zeros and reads decimal. glibc and musl are
  **unverified** — see §10.
- `aton` — glibc's `inet_aton` ignores trailing garbage, so `1.2.3.4junk`
  **succeeds** there; Apple and musl reject it. glibc ships a separate
  `__inet_aton_exact` for callers that want the strict reading, which is the
  clearest evidence the leniency is deliberate rather than a bug.

The `aton` divergence is why §3.1's "stable in practice" was wrong. Note that
**the oracle fixtures cannot currently show either divergence**: they carry the
columns `input, pton, aton, getaddrinfo, whatwg` and no libc dimension, so every
recorded row is Apple. Adding a per-libc column is `RADD-xrgomyhx` (O6), and
until it lands raddr ships no dialect for which the glibc reading is true.

### 3.3.1 The rest of the measured surface **[verified 2026-07-26]**

The eight rows above are the headline. Implementing Epic C required pinning the
whole surface, and `data-raw/oracle-ipv4.py` (Apple libc) plus
`data-raw/oracle-ipv4.R` (ada, for `whatwg`) now record 91 inputs as
`tests/testthat/fixtures/ipv4-oracle.csv`. Regenerate after a libc or curl
upgrade; the fixture is asserted, so drift fails loudly rather than silently.

The findings that shaped the implementation, none of which were in the draft
spec or the scratch documents:

- **`inet_aton` range-checks every arity except the whole-host number.** With
  two to four parts the final part is bounded by `256^(5-k) - 1` and a larger
  value is rejected: `127.16777215` is fine, `127.16777216` is not. With one
  part there is no check at all — the value is truncated to 32 bits. That is
  why `4294967296` is `0.0.0.0` while `1.4294967296` is a rejection.
- **The truncation is exactly modulo 2^32.** libc wraps in a C `unsigned long`
  and then keeps the low 32 bits, and 2^32 divides 2^64, so the two agree for
  every input. `99999999999999999999999999` is `227.255.255.255` under both.
  This is what lets raddr accumulate modulo 2^32 in a `double` and stay exact.
- **`inet_aton` stops at the first whitespace character** (space, tab, CR, LF,
  VT, FF) and ignores the remainder, so `1.2.3.4 junk` parses. Leading
  whitespace still fails, because the truncation leaves nothing to parse, and
  glued-on non-whitespace (`1.2.3.4x`) fails too.
  **[Apple libc only.]** This whole row is one of three answers, not the
  answer: glibc accepts `1.2.3.4x` as well, since its `inet_aton` ignores
  trailing garbage outright; musl agrees with Apple in rejecting it. Nothing
  here is measured off Apple — see §3.3 and `RADD-xrgomyhx`.
- **A digitless `0x` is tolerated by `inet_aton` in any part but the last.**
  `0x.1` and `0x.0x.0` parse; `0x`, `0x.0x` and `1.2.0x` do not. WHATWG has no
  such carve-out — a bare `0x` is simply zero.
- **`inet_pton` puts no width limit on leading zeros.** `00000000177.0.0.1` is
  `177.0.0.1` and a nineteen-digit run of zeros before a `1` is still `1`.

### 3.4 What is deliberately absent

- **`rfc3986`** — reg-name-vs-IPv4 host form. rurl already answers this via
  `get_host_type(url, url_standard = "rfc3986")`. It is a host-form question,
  not an address question.
- **A profile layer.** rurl's `"browser"` profile differs from its `"whatwg"`
  profile only in `scheme_policy`, `scheme_relative_handling`, and
  `fixup_posture` — all scheme-layer knobs. raddr never sees a scheme, so the
  two would collapse to one bundle. "Browser" appears in raddr's prose, never as
  an identifier.
- **Bracketed IPv6 hosts.** `[::1]` is a URL-layer form: the WHATWG host parser
  is handed the text *between* the brackets, and libc rejects them outright
  **[verified 2026-07-26]**. raddr never sees a URL, so it never sees brackets.

### 3.5 IPv6, and how its divergence is shaped differently
**[verified 2026-07-26]**

Measured by `data-raw/oracle-ipv6.py` (Apple `inet_pton`, `inet_aton`,
`getaddrinfo`, and Python's `ipaddress`) and `data-raw/oracle-ipv6.R` (ada),
recorded as `tests/testthat/fixtures/ipv6-oracle.csv`.

**The headline finding is that the shape of the disagreement inverts.** For IPv4
the two paper dialects are the divergence — `strict` and `whatwg` disagree on
six of §3.3's eight rows. For IPv6 they **agree on every measured row**, and all
of the divergence is on the reality side.

| input | `strict` | `whatwg` | `pton` | `aton` | `getaddrinfo` | `curl` |
|---|---|---|---|---|---|---|
| `::1` | ::1 | ::1 | ::1 | reject | ::1 | ::1 |
| `00001::` | reject | reject | 1:: | reject | 1:: | 1:: |
| `::1.2.3.04` | reject | reject | ::102:304 | reject | ::102:304 | ::102:304 |
| `fe80:abcd::1` | fe80:abcd::1 | fe80:abcd::1 | fe80:abcd::1 | reject | **fe80::1 %43981** | **fe80::1 %43981** |
| `fe80::1%lo0` | reject | reject | ::1 %lo0 | reject | ::1 %lo0 | ::1 %lo0 |
| `1.2.3.4` | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 |
| `[::1]` | reject | reject | reject | reject | reject | reject |

The row that carries the value is **`fe80:abcd::1`**: two libc entry points on
one machine return different bits for one string, which is the IPv6 counterpart
of what `0177.0.0.1` does for IPv4.

**The `curl` column is a copy of the `getaddrinfo` one, and that is the finding
rather than a redundancy.** `aton` rejects every IPv6 literal, so §3.2's
composition is nothing but its fallback here — and the fallback is the
`getaddrinfo` entry point **[measured 2026-07-28, curl 8.20.0; `RADD-puzhycev`]**.
For IPv4 the same two columns differ on two of §3.3's eight rows, `0177.0.0.1`
and `192.0.010.1`, where `aton` reads the leading zero as octal and answers
first.

#### 3.5.1 The four measured facts

- **`inet_aton` has no IPv6 reading at all.** It is `AF_INET` by signature and
  rejects every colon-bearing literal. Measured rather than assumed, because
  both compositions in §3.2 lean on it: for IPv6, `getaddrinfo` collapses onto
  its `pton` half and `curl` collapses onto `getaddrinfo`, so nothing about IPv6
  is decided by the precedence — only by which fallback was named.
- **Apple `inet_pton` puts no width limit on leading zeros in a hextet**, then
  caps the *significant* digits at four. `0000000000001::` is `1::`; `12345::`,
  `abcde::` and `ffff1::` are rejections. This is exactly the IPv4 finding of
  §3.3.1 repeated one grammar up. The RFC 4291 grammar caps the raw digits at
  four, so the paper dialects reject the whole family.
- **The dotted-quad tail is not a grammar of its own.** It is the dialect's own
  four-part decimal IPv4 grammar: `strict` and `whatwg` read it under
  `rules_strict` (no leading zeros), the reality dialects under `rules_pton`
  (leading zeros at any width). Notably `whatwg`'s IPv6 tail is **stricter than
  `whatwg`'s standalone IPv4 parser** — no hex, no octal, no short form, no
  trailing dot reach it. rust-url implements it as a separate loop rather than
  by calling its own `parse_ipv4addr`, and that is why.
- **A hextet is case-insensitive, a `::` may appear once and must stand for at
  least one group.** `1:2:3:4:5:6:7:8::` is a rejection, not a no-op.

#### 3.5.2 The zone ID, and why `strict` rejects it

The paper dialects have **no zone ID**. RFC 4291 §2.2's text grammar does not
admit one; the WHATWG IPv6 parser sends `%` to its catch-all and rejects
(rust-url `host.rs` ~364-512, read 2026-07-26).

The named `strict` reference implementations **disagree with each other**:
Python's `ipaddress` and Go's `net/netip` accept a zone, Rust's `std` does not
**[verified 2026-07-26]**. Since "what the implementations do" does not decide
it, the paper does, and §3.1 calls `strict` a paper dialect. **`strict` rejects
the zone.** The consequence is the only place raddr's `strict` and Python's
`ipaddress` disagree about IPv6 — 23 rows in the fixture, every one of them a
literal carrying a `%`, and none otherwise.

**The wider survey says the same thing more strongly [verified 2026-07-27].**
Three implementations was too small a sample to conclude "they disagree, so
consult the paper" and leave it there. `data-raw/survey-zone.sh` reproduces the
whole table on demand:

| Implementation | Zone slot in the type | `fe80::1%lo0` | Keeps it? |
|---|---|---|---|
| Rust `std::net::Ipv6Addr` | none | reject | — |
| Ruby `IPAddr` | none | reject | — |
| PHP `filter_var(FILTER_VALIDATE_IP)` | none (returns the string) | reject | — |
| ada / WHATWG URL (`adaR`, Node `new URL`) | none | reject | — |
| Python `ipaddress` | `.scope_id`, string | accept | yes |
| Go `net/netip` | `Zone()`, string | accept | yes |
| Rust `std::net::SocketAddrV6` | `scope_id`, **`u32`** | **numeric only** | yes |
| R `ipaddress` 1.0.3 | none | accept | **no — discarded** |
| Node `net.SocketAddress` | none | accept | **no — discarded** |
| Node `net.isIPv6()` | n/a, returns a boolean | accept | n/a |

**The split is not paper-versus-reality, and not RFC-versus-WHATWG. It is
storage.** Every implementation that has somewhere to put a zone accepts one;
every implementation that does not either rejects it or loses it. The grammar
each parser admits is the shape of its own data model, read back out.

Rust proves it within one language. `Ipv6Addr` is sixteen bytes with no zone
field and rejects every zone; `SocketAddrV6` carries a `scope_id: u32` and
accepts `%1` — while still rejecting `%lo0`, `%bogus0` and `%LO0`, because a
name does not fit in a `u32`. Same crate, same address grammar underneath, and
the accepted syntax tracks the field type exactly, down to its width.

Python looks like the same story across time rather than across types —
`scope_id` is documented as new in 3.9, and the grammar would have arrived with
it — but the oldest interpreter on this machine is 3.9.6, so that half is
**from the changelog, not measured**. Every other row in the table is measured.

Two consequences worth stating plainly:

- **The RFC-versus-WHATWG reading fails in both directions.** Rust, Ruby and
  PHP are RFC-lineage and reject; ada is the only WHATWG entry among four
  rejecters. And there is no single RFC answer to appeal to — RFC 4291 §2.2's
  address grammar has no `%`, RFC 4007 §11 defines the syntax, and RFC 6874
  *used to* define it for URIs — it was **obsoleted in August 2025 by RFC 9844**,
  which drops the zone-in-URI syntax entirely because implementers found it
  impracticable. ada rejects even the RFC 6874 spelling `%25lo0`
  **[verified 2026-07-27]**, and that measurement now has a standards
  explanation rather than being a bare observation: the WHATWG URL parser never
  adopted 6874, and 6874 is no longer live to adopt. That belongs to §3.4, not
  here.
- **The two that accept without a slot are the two that lose data**, and both
  are also *more lenient* than a validator in their own library: R's
  `ipaddress` accepts a second `%` that Apple's `inet_pton` rejects, and Node's
  `SocketAddress` accepts `fe80::1%lo0%en0`, which `net.isIPv6()` in the same
  module rejects. Accepting a zone you cannot store does not just lose the
  zone — it loosens the grammar, because there is no longer anything to
  validate the discarded text against.

**Where that leaves raddr.** raddr has a `character` zone field, so structurally
it sits with Python and Go: the data model imposes no constraint here, and it is
wide enough that Rust's `u32` problem and O14's modulo-2^16 truncation cannot
arise. `strict` therefore rejects the zone as a **decision about the paper**,
not as a consequence of storage — which is exactly why §3.5.2 stays a one-line
reversal (plus splitting `rules_v6_paper`, since `whatwg` must keep rejecting).
The reality dialects, which have no paper to answer to, accept and keep it.

So the tally among parsers that return a value is four reject, three accept and
keep, two accept and lose. The paper's answer is also the plurality answer,
which is a better position than the tie-break this section originally described.
Nothing here changes the decision; it stops being a coin toss.

**R's `ipaddress` is the case worth dwelling on**, because it is raddr's nearest
peer — same language, same problem, `Suggests`-adjacent in every comparison in
§11. It accepts a zone, truncates the literal at the **first** `%`, and throws
the rest away without a warning:

```r
ipaddress::ip_address("fe80::1%lo0")                       # -> fe80::1
ipaddress::ip_address("fe80::1%lo0%en0%wat")               # -> fe80::1
ipaddress::ip_address("fe80::1%lo0") == ip_address("fe80::1")   # -> TRUE
```

There is no `zone` field and no accessor to recover it. The zone is not merely
excluded from equality, as it is in raddr under O2 — it is **gone**, and the
last two rows are accepted where Apple's `inet_pton` rejects a second `%`
outright. That is a measured argument for §5.1's separate field: the choice is
not "in the bits or out of them" but "kept or lost", and a parser that answers
`fe80::1` to `fe80::1%lo0%en0%wat` has silently discarded the part of the input
that decides which host it is.

**And Python keeps the zone but cannot render it [verified 2026-07-27].**
Found while writing the survey, on CPython 3.9.6, 3.12.13 and 3.14.6 alike:

```python
a = ipaddress.IPv6Address("fe80::1%lo0")
str(a)          # 'fe80::1%lo0'
a.scope_id      # 'lo0'
a.packed        # b'\xfe\x80...\x01'
a.compressed    # 'fe80::1%lo0'
a.exploded         # AddressValueError: Only hex digits permitted in '1%lo0'
a.reverse_pointer  # AddressValueError, same cause
```

`_explode_shorthand_ip_string()` re-parses `str(self)` — zone suffix included —
without splitting the scope off first, so a **valid object raises on two of its
own accessors**. The value is fine; only those two renderings are broken.

Three consequences for raddr, in ascending order of importance:

1. It is why `data-raw/oracle-ipv6.py` reads `.packed` rather than `.exploded`,
   and why the fixture is unaffected. Confirmed by regenerating it byte for byte
   on 3.14.6 **[verified 2026-07-27]**. A survey script that used `.exploded`
   reported "Python rejects every zone", which is wrong in the most misleading
   possible direction — it looks like a *grammar* difference.
2. `.exploded` is Python's `addr_expand()` and `.reverse_pointer` is Epic K's
   `addr_reverse_pointer()`. Both of raddr's must work on a zoned address, and
   `test-format.R` asserts it for the renderers. Epic K inherits the warning.
3. It is a second instance of the §5.1 pattern, from the opposite direction.
   R's `ipaddress` loses the zone at parse time; Python keeps it and then trips
   over it at render time, because the renderer round-trips through text that
   the parser it calls does not accept. raddr's renderers never re-parse: they
   read the fields and append the zone last (§5.1.3).

The reality dialects accept one, on any address, and resolve nothing at parse
time: `%`, `%bogus0`, `%99999999999` and `%LO0` all parse. A second `%` is a
rejection, and a bare `%lo0` is not an address.

#### 3.5.3 The fold, the lift, and which one raddr reproduces

§5.1 records that Apple's `inet_pton` folds the interface index into the address
bytes. The measurement sharpens that in three ways it did not say:

- the fold applies to **`fe80::/10` only** — not `fec0::`, not the `ff0x::`
  multicast link-local scopes;
- it fires only when the zone **names a resolvable interface**. `%lo0` folds,
  `%1`, `%bogus0` and `%LO0` do not;
- it **overwrites the second hextet** rather than filling a spare one:
  `fe80:abcd::1%lo0` is `fe80:1::1`, and `abcd` is gone.

All three were re-measured through PHP's `inet_pton` **[verified 2026-07-27]**,
which is a different binding to the same libc, and all three reproduce exactly —
`fe80::1%lo0` gives `fe800001…`, while `%1`, `%bogus0`, `%LO0` and
`%99999999999` do not fold. That rules out the oracle's Python binding as the
source of the behavior, so the fold is libc's. It says **nothing** about glibc
or musl, which is still O6: same libc, different doorway.

**raddr does not reproduce the fold**, and the reason is a principle rather than
a shortcut: `if_nametoindex()` reads the host's interface table, so the fold is
not a function of the input. The same string means different bits on a different
machine. raddr is pure and offline (§1), so it keeps the zone in its own field
and reports the text it was given. This *strengthens* §5.1's argument rather than
qualifying it: the zone is out of the bytes precisely because putting it in is
machine-dependent.

**raddr does reproduce the lift**, which is the same convention running the
other way. Apple's `getaddrinfo` takes the second hextet of an `fe80::/10`
address as the scope ID and clears it from the bytes, **whether or not a zone ID
was written**; an explicit zone wins, and the hextet is cleared either way. That
transform is pure arithmetic on the input, so raddr models it, and
`addr_getaddrinfo()` applies it as a post-step on the §3.2 composition.

| | reads the host's interface table | raddr models it |
|---|---|---|
| `inet_pton` fold (name -> bits) | yes | **no** |
| `getaddrinfo` lift (bits -> scope) | no | **yes** |

Six fixture rows are therefore expected to differ from the `pton` oracle column,
and `tests/testthat/test-ipv6.R` names them individually rather than matching a
pattern, so that a change to the set is visible in the diff.

---

## 4. Mode selection: showing beats forcing

- **`addr_parse()` takes no mode argument.** It returns every reading, always.
  There is nothing to choose, so nothing to force.
- **Dialect is selected by calling a named function** (P3).
- **A default exists only where R structurally forces a single value** —
  `as.character()`, `format()`, a data-frame column. There the default is
  **`whatwg`**, because it is a fixed, versioned standard rather than an
  implementation. Defaulting to a reality dialect would make the answer depend
  on the machine raddr happens to be running on — §3.1 marks `pton` as
  platform-varying, and `curl` and `getaddrinfo` both compose it.
- **P5 does not conflict with this.** P5 governs *formatting*: `format()` emits
  the canonical form of a parsed value rather than echoing the input spelling.
  It says nothing about which dialect produced that value. Choosing `whatwg` as
  the display default is a §4 question; P5 applies whichever dialect is chosen.
- **The print method carries the load.** It collapses to one line when all
  dialects agree, and expands to show the divergence when they do not. Quiet
  when there is nothing to say, loud when there is.

Explicitly rejected: rurl's `url_standard = NULL` → all-`NA` default. That is a
backward-compatibility scar from retrofitting the argument onto a shipped
package, not a design principle. raddr is greenfield and does not inherit it.

---

## 5. Data model

### 5.1 `raddr_address`

A `vctrs_rcrd`.

| Field | Type | Notes |
|---|---|---|
| `w1`–`w4` | `integer` | 4 x 32-bit words, big-endian. IPv4 occupies `w4`. Raw bit patterns — see §5.1.1 |
| `family` | factor | three states: `v4`, `v6`, `v6_4in6`; `NA` marks a missing address |
| `zone` | `character` | RFC 4007 zone ID, `NA` when absent. **Never in the bytes** |

The three-state family is Go's `net/netip` lesson: `parse("::ffff:127.0.0.1")`
must not equal `parse("127.0.0.1")`, and `format()` on a 4-in-6 must emit
`::ffff:127.0.0.1` so `parse(format(x)) == x` holds.

#### 5.1.1 The `0x80000000` problem — why the words need a widening proxy

A 32-bit word has 2^32 possible bit patterns. R's `integer` can distinguish only
2^32 − 1 of them, because R reserves the pattern `0x80000000` (INT_MIN) as
`NA_integer_`. One address per word position is therefore unrepresentable by the
naive layout.

**This is not theoretical. `ipaddress` 1.0.3 ships the bug**
**[verified 2026-07-26]**:

```r
ip_address("0.0.0.128") == ip_address("0.0.0.128")
#> NA          # should be TRUE

ip_address("128.0.0.0") == ip_address("128.0.0.0")
#> TRUE        # fine, because ipaddress stores little-endian
```

**Which literal triggers it depends on byte order, so name the layout whenever
you quote one.** `ipaddress` stores words **little-endian**, so its colliding
IPv4 address is `0.0.0.128` (bytes `00 00 00 80` → word `0x80000000`)
**[verified 2026-07-26]**. raddr stores words **big-endian** (§5.1), so raddr's
colliding address is `128.0.0.0`. Same defect, different literal; quoting the
wrong one against the wrong layout looks like a false alarm.

It prints correctly and `is.na()` returns `FALSE`, because the C++ formatter
reads the raw bits — but the R-level field holds `NA_integer_`, so comparison
yields `NA`. For IPv4 this is a single address; for IPv6 it is every address
with that pattern in any of the four words. Report upstream (O11).

**This is not a bug in R, and the question will be asked again.** R documents the
constraint at every level **[verified 2026-07-26]**:

- `?integer` — "the range of representable integers is restricted to about
  ±2×10^9"
- `.Machine$integer.max` is `2147483647`, not `2147483648`; INT_MIN is excluded
  by definition
- `as.integer(-2147483648)` returns `NA` *with* a warning: "NAs introduced by
  coercion to integer range"
- `?bitwAnd` — "Pairwise operations can result in integer `NA`"

R represents missingness **in band**, spending one value of the type rather than
carrying a separate validity mask. For `double` that is free — IEEE-754 has 2^52
NaN payloads to spare, so `NA_real_` costs nothing anyone can observe. For
`integer` there is no spare value, so the sentinel costs a real one. That is a
deliberate trade inherited from S, not an oversight.

The defect is therefore squarely in the library, not the language: storing
*unsigned* 32-bit data in a *signed* type that reserves a value, and not handling
the one collision. Any library doing this must handle it; `ipaddress` does not.

The sharp edge worth knowing: `as.integer()` warns at the boundary, but
`bitwShiftL(1L, 31)` and `bitwNot(2147483647L)` both return `NA` **silently**.
Documented, but easy to walk into — and another reason §11 requires arithmetic
(`2^(8*n)`) rather than bit-shifts.

raddr's resolution:

- **Words store the raw signed bit pattern.** No value is forbidden.
  `NA_integer_` in a word means the pattern `0x80000000`, *not* missingness.
- **Missingness lives in `family`.** A row is a missing address if and only if
  `family` is `NA`. That is what disambiguates the two meanings.
- **`vec_proxy_equal()` and `vec_proxy_compare()` widen to `double`,** mapping
  the `NA_integer_` pattern to `2^31`. Doubles are exact to 2^53, so every
  32-bit value survives the round trip. Storage stays 4 bytes per word; only the
  transient comparison proxy is wide.

This keeps the memory profile (§11) and stays pure R, at the cost of one
non-obvious invariant. It must therefore carry an explicit regression test named
for the failing address — `128.0.0.0` for IPv4 in raddr's big-endian layout, plus
its IPv6 analogues, one per word position — asserting
`parse(x) == parse(x)` is `TRUE`, never `NA`. A contributor who "simplifies" the
proxy away must see that test go red.

The zone is separate because Apple's `inet_pton` embeds the interface index into
the address bytes (`fe80::1%lo0` -> `fe80:1::1`), which makes a byte-comparing
filter treat one host as two and two hosts as one.

**Epic D measured that fold and found a second, stronger reason.** The index
comes from `if_nametoindex()`, so the fold reads the host's interface table and
`fe80::1%lo0` means different bits on different machines. A field that raddr
cannot fill as a pure function of its input does not belong in the bits at all.
raddr therefore keeps the zone text and declines to fold; §3.5.3 has the
measurement, and the inverse transform that raddr *does* reproduce.

#### 5.1.2 Equality and ordering

Settled 2026-07-26; this closes O2 and O3.

**Zone does not participate in `==` (O2).** Equality is over the 128 bits and
`family`, and nothing else. `fe80::1%lo0 == fe80::1%en0` is `TRUE`: same
address, different interface. A consumer for whom the interface matters queries
`addr_zone()` separately.

This follows from the reason zone is out of the bytes at all. Apple's
`inet_pton` folds the interface index *into* the address, which §5.1 already
notes makes a byte-comparing filter treat one host as two. Admitting zone into
`==` reintroduces that failure at the R level: `unique()` would partition by
interface name, and a consumer filtering against a zoneless blocklist would
silently miss every zoned address. raddr reports what the address *is*; which
interface it was named on is a separate fact, exposed separately (P8).

**Ordering is total, IPv4 before IPv6 (O3).** `vec_proxy_compare()` prepends a
family rank so `sort()` and `vec_order()` are total and `vec_compare()` never
returns `NA` for a pair of non-missing addresses.

| family | rank |
|---|---|
| `v4` | 0 |
| `v6` | 1 |
| `v6_4in6` | 1 |

Comparing an IPv4 to an IPv6 address is arguably a category error, and a partial
order would say so. It would also make `sort()` on a mixed vector error or
produce garbage, and vctrs wants a total order. The v4-before-v6 rule is
arbitrary; what matters is that it is fixed, documented, and testable.

**`v6_4in6` ranks with `v6`, and sorts by its full 128 bits** — it *is* an IPv6
address, which is the whole reason the family is three-state (§5.1). It is
deliberately not interleaved with IPv4 by embedded value: doing so would make
ordering disagree with equality, since `::ffff:127.0.0.1 != 127.0.0.1` by
design. Consumers who want the embedded ordering sort on `addr_embedded()`.

Zone is excluded from the comparison proxy as well as the equality proxy, so
ordering and equality stay consistent: `x == y` implies `vec_compare(x, y) == 0`.

#### 5.1.3 Rendering — two forms, and why both are public **[verified 2026-07-27]**

`addr_format()` is RFC 5952 canonical and is what `format()`, `print()` and
`as.character()` emit. `addr_expand()` is the fully expanded eight-hextet form.
Both are in §6.2, and both append the zone as `%zone` without ever reading it
back into the bits.

Two renderers rather than one, because the canonical form is **variable-width
by construction** — that is the point of §4.2's `::` — and a variable-width
string cannot line up in a column, sort as text in address order, or be matched
by a prefix. Those are ordinary things to want of an address, and every one of
them needs the expanded form. `ipaddress` reaches the same conclusion from the
other direction, exposing both.

**The mixed form is decided by the family, never by the spelling.** RFC 5952 §5
asks for `::ffff:192.0.2.1`; raddr emits it for `v6_4in6`, which §5.1 decides
from the bits (`w1 == 0 && w2 == 0 && w3 == 0xffff`). So `::ffff:7f00:1` and
`::ffff:127.0.0.1` render identically, and `parse(format(x)) == x` holds —
including the family, which is the invariant the three-state family exists to
protect. The deprecated v4-compatible form is `v6`, so `::1.2.3.4` renders as
`::102:304`. The renderer does not *assume* the `::ffff:` prefix, though: it
compresses the leading six fields under the ordinary rules and appends the quad
as a seventh piece, so a `v6_4in6` built through the low-level constructor with
some other prefix still renders correctly.

**O8 — RFC 5952 publishes no test vectors**, so raddr authors its own in
`tests/testthat/test-format.R`, organized by the RFC's own section numbers.
Where the RFC's prose gives an example (§4.2.2's `2001:db8:0:1:1:1:1:1`,
§4.2.3's `2001:0:0:1::1`), that example is the row. The vectors are pinned by
four properties: the canonical form round-trips through the parser, it is a
fixed point of itself, equal addresses render identically and unequal ones do
not, and the vectorized rendering equals the one-at-a-time rendering.

The implementation is one 8 x n hextet matrix and vectorized operations over
it — §2's rule, and the same shape as the parser. The zero run is found by a
backwards recursion over the eight rows (eight steps, each over all n columns),
and the leftmost argmax of that gives §4.2.3's tie-break for free. The
compressed run is then **blanked rather than removed**, and the pieces joined
with `:` regardless: a run of two blanks already puts `::` in the right place,
and a longer one leaves one colon per blank, which a single `sub(":{3,}", "::")`
collapses. That keeps the ragged part — how many fields `::` swallowed, and
whether it touches either end — inside two vectorized calls instead of a
per-row assembly.

### 5.2 `raddr_parse`

**Outcomes are per-dialect.** A single scalar status cannot express
`4294967296`, which is simultaneously accepted by `aton` (as `0.0.0.0`),
rejected as overflow by `whatwg`, and rejected as non-dotted-quad by `strict`.
Collapsing that to one value is what produced the errors listed in §9.

| Field | Type | Notes |
|---|---|---|
| `input` | `character` | the literal, verbatim |
| `strict`, `whatwg`, `pton`, `aton` | `raddr_address` | per-dialect reading, `NA` when that dialect rejects |
| `outcome` | `list<factor>` | per-dialect outcome, one per primitive |
| `codes` | `list<character>` | per-dialect reason codes |
| `status` | factor | **derived** summary, see below |

Per-dialect `outcome` values: `ok`, `rejected`, `not_an_address`.

The top-level `status` is a **derived convenience**, documented as such, never as
truth:

| status | meaning |
|---|---|
| `ok` | all four primitives accept and yield the same address |
| `divergent` | the primitives are not unanimous — on value *or* on acceptance |
| `not_an_address` | no primitive treats the input as an IP attempt |
| `malformed` | at least one treats it as an IP attempt; none accepts |

`divergent` deliberately covers accept-vs-reject disagreement, not only
value disagreement. Under this definition `4294967296` is `divergent`, which is
the honest answer; the draft spec called it `malformed`, which was wrong.

`out_of_range` is a **reason code on the dialect that overflowed**, not a status.
The question of whether it deserves its own status dissolves once outcomes are
per-dialect.

#### 5.2.1 Storage, and the two silences **[implemented 2026-07-27]**

Two clarifications Epic F forced, both recorded because the field table above
is too compressed to settle them.

**`outcome` and `codes` are data-frame columns**, four columns each, one per
primitive — which is what "one per primitive" means once it has to be a vector
of the record's own length. `outcome`'s four columns are factors over `ok`,
`rejected`, `not_an_address`; `codes`' four are `list_of<character>`. The
alternative reading — a length-four object stored per *row* — would allocate
four lists per address and put a per-element loop in the middle of an engine
built to avoid one.

Internally the codes travel as a **per-row integer mask**, one bit per code,
and are unpacked once at the end via the distinct masks rather than row by row.
A million-row vector has a handful of masks, nearly all of them zero. The
one-bit-per-code layout caps the vocabulary at 31, which `R/codes.R` asserts.

**`ok` means every primitive *with a say* accepts, not all four.** Two silences
look alike and are not:

| input | the silence | is it dissent? |
|---|---|---|
| `::1` | `aton` is `AF_INET` by signature and has no IPv6 grammar to withhold | **No.** Counting it would make every IPv6 address `divergent` |
| `1.2.3.4 junk` | `strict` has the grammar and declines to see an address — but `aton` finds `1.2.3.4` in it | **Yes.** This is the class where curl reaches a host a browser will not dial |

So a dialect has a say when it accepted, or when it is *applicable* — has a
grammar for the family the literal is spelled in — and either saw an attempt or
some other dialect found an address in the string. An acceptance anywhere means
the literal is an address, and no applicable dialect gets to shrug after that.
The §5.2 table says "all four" because its worked examples are IPv4, where all
four are applicable; this is the same rule written out for both families.

The consequence for `aton` and a colon literal is that it reports
`not_an_address` rather than `rejected`, for `::ffff:1.2.3.4` exactly as for
`::1` — the outcome no longer depends on how the tail happens to be spelled.

#### 5.2.2 The reason-code vocabulary **[implemented 2026-07-27]**

One const registry in `R/codes.R`, exported as `addr_codes_registry()`, with the
valid-value set derived from it rather than restated. Adding a code is an API
addition and removing one is breaking, which is what `since` records.

**Correction: `ssrfr` does not report raddr's codes, and this section used to
claim it did.** `ssrfr` ADR-001 §7 assigns the reason-code vocabulary and result
model to `ssrfr`; its spec §5.2 fixes those codes as kebab-case, normative for
`ssrfr` and constrained by its own published consumers, with the case divergence
called *deliberate*. Both documents cannot be right, and the counterparty's own
ADR wins. The relationship is many-to-one and conditional: raddr states facts,
`ssrfr` interprets them into a refusal reason, and a raddr code may travel in a
detailed `ssrfr` result as evidence without being its public reason.

This matters beyond bookkeeping. It is the same separation §5.3.3 draws for
`category`, and it means the deny-list-bypass worry is *smaller* than it looked
when this contract was assumed — `ssrfr` was never going to enumerate raddr's
vocabulary, because its own is fixed downstream.

| code | layer | provenance | fires when |
|---|---|---|---|
| `not_a_number` | `parse` | RFC 3986 §3.2.2 | a part is not a number in any radix this dialect reads |
| `leading_zero` | `parse` | RFC 6943 §3.1.1 | a part carries a leading zero and the dialect forbids one |
| `empty_part` | `parse` | RFC 3986 §3.2.2 | two consecutive dots, or a leading dot |
| `empty_hex` | `parse` | WHATWG URL, IPv4 number parser | a digitless `0x` where the dialect requires digits |
| `out_of_range` | `parse` | RFC 3986 §3.2.2 | a part exceeds the largest value its position can hold |
| `wrong_part_count` | `parse` | RFC 3986 §3.2.2 | the number of dot-separated parts is not one the dialect accepts |
| `trailing_dot` | `parse` | WHATWG URL, IPv4 parser | the literal ends in a dot the dialect does not drop |
| `zone_not_permitted` | `parse` | RFC 4291 §2.2 | a zone ID on a dialect that has none (§3.5.2) |
| `multiple_zones` | `parse` | RFC 4007 §11.2 | more than one `%` |
| `bad_hextet` | `parse` | RFC 4291 §2.2 | a group is not one to four hex digits |
| `empty_group` | `parse` | RFC 4291 §2.2 | a stray colon leaves a group empty |
| `bad_elision` | `parse` | RFC 4291 §2.2 | more than one `::`, or a `:::` run |
| `wrong_group_count` | `parse` | RFC 4291 §2.2 | the literal does not resolve to exactly eight groups |
| `bad_embedded_ipv4` | `parse` | RFC 4291 §2.2 | the dotted-quad tail fails the dialect's own IPv4 rules |
| `whitespace` | `parse` | POSIX `getaddrinfo(3)` | whitespace in the address, which `getaddrinfo` refuses outright (§3.2) |
| `nat64_wk_embedded_not_global` | `classify` | RFC 6052 §3.1 | the NAT64 well-known prefix carries a non-global embedded IPv4 |
| `sixtofour_embedded_not_global` | `classify` | RFC 3056 §9 | a 6to4 `V4ADDR` is not in the format of a global unicast address |
| `teredo_client_not_global` | `classify` | RFC 4380 §4 | a global Teredo address embeds a non-global client IPv4 |
| `link_local_outside_fe80_64` | `classify` | RFC 4291 §2.5.6 | the address is in `fe80::/10` but outside `fe80::/64` |
| `link_local_reserved_range` | `classify` | RFC 3927 §2.1 | the address is in `169.254.0.0/24` or `169.254.255.0/24` |
| `ipv4_compatible_low_tail` | `classify` | RFC 4291 §2.5.5.1 | the deprecated `::a.b.c.d` tail is below `1.0.0.0` |
| `nat64_local_layout_unspecified` | `classify` | RFC 8215 §5 | raddr read RFC 6052 geometry under `64:ff9b:1::/48`, whose syntax is undefined |
| `ula_l_bit_unset` | `classify` | RFC 4193 §3.1 | the address is in `fc00::/8`, the ULA half that was never specified |

**This table is machine-checked in both directions** — `test-codes.R` fails on an
undocumented code and on an orphan entry left by a rename — and every code is
required to have at least one corpus row that produces it, so a code nothing can
emit fails the build. That coverage requirement is why there is no
`no_ipv6_reading`: an `AF_INET`-only dialect has no *objection* to a colon
literal, it has no reading of one, which §5.2.1 settles as an outcome.

A code fires **once per part, first match wins**, so a part that is not a number
does not also report the range its garbage value happened to land outside of. A
row still collects every code its parts raised. On the IPv6 side the engine
already narrows row by row through one gate at a time, so the first gate a row
fails is its reason, at no extra cost.

The **classify** layer accumulates instead, because its rules are independent
facts about one address rather than competing readings of one part. It reuses
the same integer mask for the same reason — unpacking by distinct mask is what
keeps a per-row loop out of the middle of a vectorized lookup.

#### 5.2.3 `strength`, and why every rule is reported **[implemented 2026-07-27]**

Each code records the normative force of the rule it reports: `must`, `should`,
`may` or `unspecified`. The user's framing, which corrected an earlier proposal
to ship only the MUST rules:

> **must is must; other language should be reported, but no consequences are
> needed.**

Shipping only the MUSTs would collapse a spectrum into a binary — the move raddr
exists to refuse. So a weaker rule is still reported, and the *grade* is what
says not to act on it as though it were a MUST. It is `NA` for all 15 parse
codes, and that is the honest value rather than a filler: those describe what a
parser **did** with a literal, not what a specification mandates about an
address. A `stopifnot` in `R/codes.R` makes the two layers divide exactly on it.

**The grade follows the rule's substance, not the presence of a keyword, because
the sources do not agree about keywords [verified 2026-07-27 against the RFC
texts]:**

| Invokes RFC 2119 | Does not invoke it anywhere |
|---|---|
| RFC 3056, 3927, 4193, 4380, 6052 | **RFC 4291, RFC 8215** |

So `link_local_outside_fe80_64` is `must` because RFC 4291 §2.5.6's 54 zero bits
**are the definition** of the link-local format, not because 4291 spells a
keyword — it never does, and its only nearby requirement ("Routers must not
forward…") is lowercase. Grading it `unspecified` would be plainly false, and
grading it silently alongside RFC 3927's uppercase `MUST NOT` would merge two
different facts, so each `summary` says which case it is. The same measurement
makes `nat64_local_layout_unspecified` right twice over: RFC 8215 §5 both leaves
the syntax undefined *and* states its prohibition in lowercase.

Conversely `ula_l_bit_unset` is `unspecified` even though RFC 4193 **does**
invoke 2119 — §3.1's "Set to 0 may be defined in the future" is lowercase, and
no allocation mechanism was ever defined. Keyword presence in a document says
nothing about the sentence that matters.

**`should` has no member yet**, and the level is kept anyway so a consumer does
not read `must` and `may` as the whole scale. The nearest candidate, RFC 6052
§3.1's "the Well-Known Prefix SHOULD NOT be used to construct IPv4-translatable
IPv6 addresses", is not decidable from an address.

Three codes were registered ahead of the rule that emits them — the two
MUST-drop rules and Teredo's conditional MUST each need the embedded IPv4
extracted and classified. They were registered early because adding a code is an
API addition, so landing the extractor must not also be a re-versioning, and it
was not: **all eight are emitted as of Epic J [implemented 2026-07-27]**, and
`test-codes.R` names one input per code rather than carrying a pending list.

Five rules need nothing but the address, and three of those are decided by
prefix alone — one longest-prefix-match pass over a five-row table in
`R/codes.R` answers all three. `fe80::/64` is in that table carrying **no code**:
it exists only to shadow `fe80::/10`, so that longest-prefix-match lands on the
/10 exactly when the address is inside the reservation and outside the format.
Encoding "in A but not in B" as a second row is cheaper than a second pass.

The survey is what makes two of these worth having at all **[measured
2026-07-27]**. CPython's `ipaddress` and R's `ipaddress` both answer
`is_link_local = TRUE` for `febf::1`, and both answer `is_private = TRUE` for
`fc00::1` — in each case a single predicate covering two states the RFC keeps
apart, with nothing attached that a caller could use to tell them apart.
`sixtofour_embedded_not_global` also takes its spelling from that survey: a code
may not begin with a digit, and `ipaddress` solved the identical problem the
identical way with its `sixtofour` property.

#### 5.2.4 What "global" means to the three embedded rules **[added 2026-07-27]**

The remaining three rules are stated about the **embedded** address, and all
three state the same antecedent in different words:

| Code | Source | Wording |
|---|---|---|
| `nat64_wk_embedded_not_global` | RFC 6052 §3.1 | "non-global IPv4 addresses, such as those defined in \[RFC1918\] or listed in Section 3 of \[RFC5735\]" |
| `sixtofour_embedded_not_global` | RFC 3056 §9 | "not in the format of a global unicast address" |
| `teredo_client_not_global` | RFC 4380 §4 | "a global scope unicast IPv4 address" |

One predicate answers all three, because over IPv4 the three sets coincide. RFC
5735 §3 enumerates the special-use blocks, and RFC 3056 §9's own gloss —
"\[RFC1918\], broadcast, subnet broadcast, multicast and loopback" — names
members of that enumeration and nothing outside it.

**The predicate is three-valued, and the third value is the point.** Each
vendored layer answers in its own terms, and neither silence is an answer:

| Layer that answered | The question it can answer |
|---|---|
| special-purpose | IANA's own `globally_reachable`, unmodified — `TRUE`, `FALSE` or `N/A` |
| address space | whether the space is delegated to an RIR, which is `category = global`. That layer has no policy column at all |

Measured over all 256 IPv4 `/8`s **[verified 2026-07-27]**: 220 answer `global`
and 16 `multicast` from the address-space layer; 25 of the 26 special-purpose
rows state `globally_reachable`; and **exactly one block leaves the question
open** — `192.88.99.0/24`, which IANA withdrew and gave no policy at all.

So the `NA` tier is not a hypothetical: it is `2002:c058:6301::`, the 6to4 image
of the deprecated relay anycast address. The rules fire on an affirmative
`FALSE` and nowhere else, because asserting a MUST-drop there would be reading
IANA's `N/A` as `FALSE` one level down — §7.1's mistake, relocated rather than
avoided. What raddr reports instead is the extracted address with its own
record, whose `termination_date = 2015-03` is exactly why the question has no
answer.

Both halves of the predicate are load-bearing, and each fixes what the other
gets wrong:

- Without `globally_reachable = TRUE`, the five special-purpose blocks IANA
  marks globally reachable — PCP and TURN anycast, AS112 twice, AMT — take a
  MUST-drop they do not deserve. `64:ff9b::192.31.196.1` is the case.
- Without `category = global`, `8.8.8.8` reads as non-global (its layer has no
  policy column) and `224.0.0.0/4` reads as nothing at all. That second failure
  is CVE-2025-8267's shape, one level in.

This is **not** the `category` deny-list §5.3.3 forbids. It reads one *positive*
level, only in the layer that has no other column, and a level added later
changes no answer that layer gives today.

**A disagreement worth recording: RFC 7050 versus IANA, on `192.0.0.170`**
**[verified 2026-07-27].** RFC 7050 §2 constructs `Pref64::WKA` for NAT64
discovery and gives `64:ff9b::192.0.0.170` as a worked example, justifying the
choice of well-known address with:

> The IPv4 addresses for the well-known name cannot be non-global IPv4 addresses
> as listed in the Section 3 of \[RFC5735\]. Otherwise, DNS64 servers might not
> perform AAAA record synthesis when the well-known prefix is used, as stated in
> Section 3.1 of \[RFC6052\].

But RFC 5735 §3 **does** list `192.0.0.0/24` ("reserved for IETF protocol
assignments"), and IANA records `192.0.0.170/32` as `Globally Reachable =
False`. Two sources disagree about whether RFC 6052 §3.1 binds the address the
IETF built for exactly this purpose. raddr does not resolve it: the code fires,
because IANA says `FALSE` affirmatively, and the embedding's own `category =
discovery` names what the address is. P8 — a consumer implementing RFC 7050
knows to expect it; raddr may not decide that for them.

### 5.3 `raddr_class`

| Field | Type | Notes |
|---|---|---|
| `block` | `character` | matched registry prefix |
| `name`, `rfc` | `character` | registry columns; `rfc` is the provenance string |
| `footnotes` | `character` | upstream footnote markers, `""` when none. Says why an `rfc` or a policy value is absent **[added 2026-07-27]** |
| `category` | factor | raddr's vocabulary — 19 levels, enumerated below. **Not** `scope` |
| `globally_reachable` | `logical` | the IANA column, **not** a derived `is_global` |
| `forwardable`, `source`, `destination`, `reserved_by_protocol` | `logical` | the other four IANA columns |
| `termination_date` | `character` | set on a deprecated block, and the reason its five columns are empty **[added 2026-07-27]** |
| `embedded_kind` | factor | the *mechanism*: `ipv4_mapped`, `6to4`, `teredo`, `nat64_wk`, ... |
| `embeddings` | `list_of<raddr_embedding>` | zero or more extracted inner addresses. One list element per row |
| `codes` | `list_of<character>` | classify-layer codes (`RADD-wglsdrmu`) |
| `registry` | factor | which vendored pair answered: `special_purpose` or `address_space` **[added 2026-07-27]** |
| `registry_version` | `character` | snapshot stamp of *that* pair (P7) |

Each element of `embeddings` is a `raddr_embedding` record of zero or more rows:

| Field | Type | Notes |
|---|---|---|
| `kind` | factor | same vocabulary as `embedded_kind` |
| `role` | factor | `embedded`, or `client` / `server` for Teredo |
| `address` | `raddr_address` | the extracted address |
| `category` | factor | classification of *that* address, not of the outer one |

#### 5.3.1 Why `category` and not `scope`

**`scope` is the wrong word and it is taken.** RFC 4007 §5 and RFC 7346 §2 both
define "scope" for IPv6 as a specific, bit-derived value, and raddr already
carries `zone` — RFC 4007's companion concept — inside the same record. The
levels below also mix address scope (`link_local`), purpose (`documentation`),
and architecture (`multicast`), so the word was never accurate for them anyway.

The deciding factor is that raddr *will* want the real thing: the 4-bit
multicast scope nibble is the one piece of IPv6 reachability semantics a pure
offline classifier can state with full confidence, so `scope` must stay free to
name it. Renaming is cheap now and breaking later.

#### 5.3.2 The 19 `category` levels

The criterion, which generates every call below:

> **A level exists only when it answers a question that the registry's own
> columns and the block's `name` cannot.**

| Level | Covers |
|---|---|
| `unspecified` | `0.0.0.0/32`, `::/128` |
| `this_network` | `0.0.0.0/8` — RFC 1122's own term, and *not* `unspecified`; only the `/32` is |
| `loopback` | `127.0.0.0/8`, `::1/128` |
| `link_local` | `169.254.0.0/16`, `fe80::/10` |
| `multicast` | `224.0.0.0/4`, `ff00::/8` |
| `broadcast` | `255.255.255.255/32` |
| `private` | RFC 1918 ×3 **and** ULA `fc00::/7` |
| `shared` | `100.64.0.0/10` (CGNAT) |
| `documentation` | `192.0.2.0/24`, `2001:db8::/32`, `3fff::/20`, ... |
| `benchmarking` | `198.18.0.0/15`, `2001:2::/48` |
| `future_use` | `240.0.0.0/4` — RFC 1112 §4's own word |
| `protocol` | IETF Protocol Assignments, service continuity, the translation prefixes |
| `anycast` | well-known service addresses reached by anycast routing |
| `discard` | `100::/64` |
| `dummy` | `192.0.0.8/32`, `100:0:0:1::/64` |
| `discovery` | `192.0.0.170/32`, `192.0.0.171/32` (NAT64/DNS64 discovery) |
| `special` | in the special-purpose registry, and raddr has no shorter true word than its `name` |
| `unallocated` | IANA holds it and has neither purposed nor delegated it — the 16 IPv6 `Reserved by IETF` rows |
| `global` | delegated to an RIR (IPv4) or the one block IANA assigns unicast from, `2000::/3` |

Five calls need their reasoning recorded, because each was contested:

**`anycast` means addressing style, never reachability.** The tempting
definition — "globally reachable service anycast" — is falsified by the registry
itself: `192.88.99.2/32` (6a44-relay anycast) is `Globally Reachable = False`,
and `192.88.99.0/24` has *no policy values at all*. The workable definition is
"a well-known service address reached by anycast routing, whatever its
reachability," which admits AS112, AMT, PCP/TURN/SRP, 6a44 and the deprecated
6to4 relay anycast alike. `as112` and `amt` **fold into it**: `name` already
says "AS112-v4" and "AMT" better than a level can.

**`private` covers ULA.** Cross-family normalization is the level's whole job,
and the consumer settles it — `ssrfr` ADR-001 §2.1 makes the unblocked
`fc00::/7` its motivating defect and prescribes exactly this one word. The
genuinely surprising fact that `fc00::/8` (L=0) has **no defining
specification** — only `fd00::/8` is real, RFC 4193 §3.1 — lives in the classify
codes at `strength = unspecified`. `category = private` therefore does **not**
imply "valid ULA".

**`reserved` is deleted, not renamed.** `is_reserved` means four different
things across the ecosystem and IANA's `Reserved-by-Protocol` column is a fifth;
the word carries no portable meaning. Shipping it as a level in the same record
that carries a `reserved_by_protocol` column guarantees the two get confused.

**The mechanisms leave the vocabulary.** `nat64`, `teredo`, `6to4` and
`ipv4_mapped` are *not* categories — they are `embedded_kind` values, where the
mechanism is stated precisely and independently of the outer block. So
`64:ff9b::/96` is `category = protocol`, `embedded_kind = nat64_wk`,
`globally_reachable = TRUE`, with the extracted IPv4 in `embeddings` — four
simultaneously true facts, none compressed into the others. This also keeps
`category` honest for a caller-supplied network-specific NAT64 prefix, whose
outer category is whatever the ordinary lookup returns.

**`special` is an assignment, not a fallthrough.** It covers SRv6 SIDs
(`5f00::/16`), ORCHIDv2, DETs, and deprecated ORCHID — blocks with no question a
short word answers. It is **not** a catch-all: a new IANA row nobody classified
still fails the build (§5.3.3). `special` and `global` are different answers and
must never be merged — one means "matched, and `name` is the best available
description", the other means "no special-purpose block matched at all".

**`unallocated` is the nineteenth, and the eighteen were never total**
**[verified 2026-07-27].** This section asserted totality; measuring it while
building the map falsified the claim twice. `multicast` and `global` have **no
special-purpose block at all**, so "every declared level is used" was
unsatisfiable over 51 blocks — the address-space pair (§7.3) supplies both. And
16 IPv6 address-space rows named `Reserved by IETF` match none of the eighteen.

Every near-miss is wrong for a stated reason. `global` is false: IANA's own note
on `2000::/3` limits unicast assignment to `2000::/3`, so calling the other
seven eighths globally reachable asserts reachability for space nobody may use.
`special` is definitionally "in the special-purpose registry", and these are
not — and §5.3.2 already says `special` is an assignment, not a fallthrough, so
widening it to cover *unassigned* space would turn it into exactly the
fallthrough that sentence forbids. `future_use` is RFC 1112 §4's word for
`240/4`, and two of these rows are *deprecated*, which is the opposite of
future. `reserved` stays deleted.

**The survey settles the name, and it settles it against `reserved`**
**[measured 2026-07-27].** Two of three comparable implementations do name this
space, and both call it `reserved` while simultaneously asserting the thing that
is false about it:

| Tool | Its name for `4000::1` | Also reports |
|---|---|---|
| CPython `ipaddress` | `is_reserved` (15 rows — `fec0::/10` omitted) | `is_global == True` |
| R `ipaddress` | `is_reserved` (coarse `::/3`, `4000::/2`, `8000::/2`) | `is_global == True` |
| `ipaddr.js` | `unicast` — the default fallthrough | same label as real global unicast |

Three tools, three answers, all three wrong. `ipaddr.js`'s `reserved` is
`2001::/23` + `2001:db8::/32` + `3fff::/20` — a set **disjoint** from CPython's
`reserved`, which is the sharpest possible evidence for the ecosystem-ambiguity
finding that deleted the word. `unallocated` is unattested in the survey, and
that is a point in its favour: it cannot inherit four incompatible meanings.

R `ipaddress` is also the P9 case study in the flesh — its `::/3`-style
aggregates lose `fec0::/10`'s RFC 3879 and `200::/7`'s RFC 4048 exactly as §2
predicted. raddr keeps all 16 rows and leaves both citations in the
address-space `notes` column rather than in the level.

A rejected level worth recording: **`identifier`**, proposed to cover ORCHIDv2,
DETs and SRv6 SIDs together. It was rejected because it lumps cryptographic host
identifiers (RFC 7343) with routing segment identifiers (RFC 8986). Those are
not the same kind of thing, and grouping them would assert a similarity raddr
cannot defend from any source — the collapse this package exists to refuse.

#### 5.3.3 `category` is descriptive. It is not a policy input.

**State this in the accessor documentation, not only here.** `ipaddr.js`
demonstrates both failure modes: label names are unstable across versions
(`deprecated` → `deprecatedOrchid`), and consumers deny by *named list*, so a
newly added label becomes a bypass — `::ffff:127.0.0.1` passing under the
`ipv4Mapped` label.

raddr's answer is **not** a smaller vocabulary. A smaller deny-list merely
postpones the bypass until the next level is added; the fix is to decouple
description from policy entirely. Policy reads the five IANA columns, the
classify codes, and `embeddings` — all three-valued and registry- or
RFC-sourced. `ssrfr`'s own spec already requires exactly that shape (INV-13: a
positive routability predicate, not an enumerated prohibition list), and **no
`category` label appears in it**.

Consequently raddr ships **no** "everything that is not `global`" helper. Such a
helper is a verdict wearing a predicate's clothes, and it would be wrong on
`64:ff9b::a00:1` — a block IANA marks `Globally Reachable = True` that embeds
`10.0.0.1`. Whichever level that block gets, the helper loses one of two true
facts. Answering "is this safe" is `ssrfr`'s job, over the columns. P8.

`category` is a cross-repo vocabulary under `since` discipline: adding a level is
an API addition, removing or re-pointing one is breaking.

#### 5.3.4 Who maintains the block → level map

**It cannot be derived from the policy columns.** Over the 50 upstream records
there are only 14 distinct five-column signatures: 14 records share
`True,True,True,True,False` (PCP/TURN/SRP anycast, AS112 ×4, AMT ×2, the NAT64
well-known prefix, ORCHIDv2, DETs) and 11 share `True,True,True,False,False`
(all three `Private-Use` blocks, Shared Address Space, service continuity, 6a44
anycast, Benchmarking ×2, `64:ff9b:1::/48`, Discard-Only, SRv6 SIDs). Seven
proposed levels collapse into that second signature alone. Columns are out.

**The map is keyed on the canonical block, not on `Name`.** Name-keying is
tempting — there are 40 distinct names over 50 records, 9 repeats, and no repeat
today needs two levels — but it fails on the property the map exists for: a
*new* IANA row reusing an existing name (a fourth `Private-Use`, another
`Documentation`) would classify itself with nobody reading its policy columns.
`Name` is a mutable display string — "DS-Lite [RFC6333]" became "IPv4 Service
Continuity Prefix [RFC7335]" with no change of prefix — while the block is the
row's identity. Canonicalizing a block is deterministic parsing; grouping by
name asserts semantic equivalence, which is the classification judgment itself.

So: **322 block-keyed entries**, with four tests. **[implemented 2026-07-27]**

Two corrections to this subsection as first written. The count was 51 because
the address-space pair was not yet vendored; the map must cover both pairs, and
it is 322 rather than 327 because five blocks appear in both and are mapped
once — which is also what makes it impossible for the two layers to disagree
about them. And the map lives in **`R/category.R`**, not `data-raw/`: §7.2's
rule is that "a `data-raw/` script that builds a table from a literal in its own
source is ceremony around a constant", and this subsection's own next sentence
already says it follows `R/transition.R`'s pattern. The pattern was the
load-bearing half; the location was not.

Every block is listed explicitly, **including the 221 IPv4 `/8`s delegated to an
RIR**, which could have been derived from the `status` column. Deriving them
would mean a `/8` changing hands silently becomes `global`; listed, it fails the
build and gets read. Test 4 is precisely that requirement, so the verbosity is
the feature.

Test 4 fires in two places: the test suite, and `data-raw/build-registry.R`
itself, so a maintainer regenerating the registry learns of an unclassified
block at the moment it arrives rather than one gate later.

1. Every special-purpose block resolves to exactly one level.
2. Every declared level is used by at least one block.
3. Any two blocks sharing an IANA `Name` resolve to the *same* level, unless an
   explicit `name_split` entry names the pair and says why. This keeps the whole
   value of the name arithmetic as a mechanical check. The list is **empty**
   today: `IPv4-IPv6 Translat.` was its only candidate, and both its blocks are
   `protocol` now that the mechanisms live in `embedded_kind`.
4. A new IANA row with no entry **fails the build** rather than landing in
   `global`.

**The map is raddr's, and its provenance stays visibly separate from IANA's.**
It must not become a column of `addr_registry()`, whose promise is the IANA data
*exactly as vendored*. It follows `R/transition.R`'s pattern instead —
hand-authored, RFC-cited, and carrying its own version stamp, so neither stamp
is evidence about the other. P9 permits this: P9 forbids hand-transcribing an
upstream fact when an authoritative file exists, and `category` has no upstream
value to preserve.

#### 5.3.5 Embeddings are plural, and Teredo is why **[implemented 2026-07-27]**

**`embeddings` is a `list_of` column with exactly one element per row.** The
outer record stays `vctrs` size-stable — `vec_size()` is preserved by
construction and `vec_ptype()` is one type across all 51 blocks. Rows multiply
only when a caller explicitly unnests.

RFC 4380 §4 puts **two** IPv4 addresses in a Teredo address: the server at bits
32–63 in the clear, and the client at bits 96–127 bitwise-complemented. Both are
reported, in the overlay's existing order — server, then client — and **both are
classified**. raddr does not choose which one matters.

An earlier design gave `raddr_class` a single `embedded` field meaning the
client, on the reasoning that the server is tunnel infrastructure rather than
what the address stands for. **That reasoning is falsified.** RFC 4380 §5.2.6
directs a host to extract the server IPv4 *from a peer's address* and send a UDP
bubble to it:

> the bubble will be sent to that IPv4 address and the Teredo UDP port

so the server field is a destination, not metadata. The asymmetry between the
two fields runs the *opposite* way to the discarded rationale: RFC 4380 §5.2.3
validates the **client** field against the packet's actual IPv4 source, and no
equivalent check of the **server** field is specified anywhere. That per-`(kind,
role)` fact belongs in the transition overlay (§7.2), not in per-row output.

This is not a novel finding and raddr should not present it as one — Hoagland's
Black Hat USA 2007 analysis describes the relay case, and Miredo has validated
the server field since 2004 despite RFC 4380 not requiring it at the relay
(§5.4.1). Its author's note is the same judgment raddr keeps making: *"This
check is only specified for client case 4 & 5… As for the relay, I consider the
check should also be done, even if it wasn't specified."* Teredo is disabled by
default on Windows since 10 v1803 and the public servers shut down in June 2021,
so this is a **classification-correctness** point, not a live vector.

**`embedded_scope` is removed.** It was a scalar `factor` typed in this section
and returned by `addr_embedded_scope()` in §6.3, and under a plural embeddings
model it cannot return a length-`n` factor without a reduction — and *the
reduction is the decision*. Rather than relocate the Teredo choice into an
accessor contract where it would be answered under less scrutiny, the field
goes. `addr_embeddings()` replaces it and always returns the typed list. This is
an **API removal**, recorded here as one.

**Vocabulary — one word, and it is the RFCs' word.** raddr says *embedded*
throughout: field names, accessors, prose. RFC 6052 §2 speaks of "embedding an
IPv4 address" in an IPv6 prefix, and RFC 4291 §2.5.5 of the "IPv4-mapped" form.
Matching the standards' noun means someone reading the RFC and someone reading
raddr use the same term. "Unwrap" does not appear anywhere in raddr.

This governs **identifiers** — field names, accessor names, code names. Prose
may still say "wrapper" for the outer IPv6 form that carries an inner address
(§8.1's wrapper matrix), because that names the *container*, not the operation.

That field's history is worth keeping, because the same objection killed it
twice. It was `effective_scope` in the draft; the name went because "effective"
asserts that one of three simultaneously-true fields is the real one. It became
`embedded_scope`, and then went entirely (§5.3.5) because a *scalar* asserts
that one of Teredo's two embedded addresses is the real one. Same judgment,
refused at two different layers — first in a name, then in a cardinality.

**Filling the column changed nothing about it [implemented 2026-07-27].** The
extractor writes the same four fields the type was built with, and the record
was not re-versioned — which is what settling the type ahead of Epic J bought.
Two properties of the implementation are worth stating here because neither is
visible from the field list:

- **`category` is the extracted address's, so extraction recurses** — one level
  of `addr_classify()` on what came out. It terminates *by construction* rather
  than by a depth guard: an extracted address is IPv4, the only IPv4 row in the
  overlay is `192.88.99.0/24`, and that prefix has no geometry (§5.3.7), so the
  inner call finds no kind and extracts nothing.
- **An extracted address never inherits the outer zone.** The zone names an
  interface on the address that carried the bits; attaching it to a value read
  out of 32 of them would assert a scope nobody stated.

**The invariant this exists to hold is CVE-2024-24790's.** Go's `netip`
predicates answered differently for `127.0.0.1` and for its IPv4-mapped form.
The invariant that catches it is *not* that the two records agree — they must
not, and §6.3 says why — but that the **embedded** address classifies as the
address it is. It is checked over every IPv4 block raddr maps, through both
`::ffff:` and the deprecated `::`, plus across four textual spellings of one
128-bit value, since Node normalising `::ffff:169.254.169.254` to the hex form
while the range check read only the dotted one is the documented root cause
behind CVE-2024-29415 and six more.

#### 5.3.6 Every `NA` says why it is `NA` **[added 2026-07-27]**

**The governing rule, stated by the user and now the section's title: be
perfectly compliant with the standard, report everything we know, and where we
know two `NA`s mean different things, disclose it.** Three fields are additions
to the settled list, all made while building the record and all falling out of
that one rule.

The line it draws is narrow on purpose. `raddr_class` does **not** duplicate
every column of the two source tables — `block` plus `registry` is an exact key
into them, so `status`, `date`, `notes` and `allocation_date` stay one lookup
away. What the record may not do is leave a field empty when the vendored data
says *why* it is empty. That fact would be unrecoverable, because nothing in the
record points at it.

**`registry`.** Without it the five policy logicals carry two different `NA`s
that a caller cannot tell apart:

| `registry` | What `globally_reachable = NA` means |
|---|---|
| `special_purpose` | IANA's own `N/A` — a policy it **declined to state**. §7.1 keeps two distinct reasons for it |
| `address_space` | the question was **never asked**: that registry has no policy columns at all |

`192.88.99.1` and `8.8.8.8` both classify with all five logicals `NA`, and the
two facts are not the same fact. Merging them is the identical mistake as
reading IANA's `N/A` as `FALSE`, one level up — so the record says which
registry answered rather than leaving a caller to re-derive it by looking the
block up in both accessors.

It also makes `registry_version` honest. §7.3 fixed the two pairs' stamps
separately *because* one date across both would assert something about a table
it says nothing about; a per-row version with no per-row registry reintroduces
exactly that ambiguity. So the two travel together, and P7 is satisfied per row
rather than per call.

**`termination_date` and `footnotes`.** `registry` separates the two *layers*'
`NA`s; these two separate the reasons *within* the special-purpose layer.
Measured: exactly four blocks have a missing policy value, and they carry three
different reasons **[verified 2026-07-27]**.

| Block | Which columns are `NA` | Why | Disclosed by |
|---|---|---|---|
| `192.88.99.0/24` | all five | deprecated — IANA gives a withdrawn block no policy at all | `termination_date = 2015-03` |
| `2001:10::/28` | all five | deprecated (previously ORCHID) | `termination_date = 2014-03` |
| `2001::/32` Teredo | `globally_reachable` only | relay advertisement is voluntary and per-deployment (RFC 4380 §5) | footnote `[2]` |
| `2002::/16` 6to4 | `globally_reachable` only | reachability follows the **embedded** IPv4 (RFC 3056) | footnote `[3]` |

The last two are the pair §7.1 already splits in four places. Before these
fields the record was the fifth place they were merged — both came out as a bare
`NA`, and the only thing in the vendored data distinguishing them was a column
the record dropped.

`footnotes` does the same job for `rfc`. That column is `NA` for **every** one
of the 256 IPv4 address-space rows, because the registry has no reference
column — but **42 of them carry a footnote marker** and 214 do not. "There is no
citation" and "there is a citation, and its text is on the registry page rather
than in the CSV" are different facts, and `127.0.0.0/8`'s `[7]` is the evidence
for the second. Footnote numbering is per registry, so a marker is only
meaningful alongside `registry` and the family — one more thing that field is
load-bearing for.

**Where the rule stops.** `embedded_kind = NA` also has three causes — no
overlay prefix matched, a prefix with no geometry matched (`192.88.99.0/24`), or
the `::/96` carve-out fired. No field is added for it, because unlike the cases
above **nothing is unrecoverable**: `block`, `name` and `category` are in the
same record, and `addr_transition_registry()` is public and keyed on the block.
The rule is "disclose what only the source knows", not "annotate every
absence".

**The survey supports the shape, and it is the only one that does**
**[measured 2026-07-27].** Of the comparable implementations, one consults more
than one registry, and it carries provenance the same way:

| Tool | `192.0.0.9` (a globally reachable carve-out) | Provenance |
|---|---|---|
| Python `netaddr` | `192/8`, `Administered by ARIN`, `Legacy` | `.info` is **keyed by registry** — `IPv4`, `IPv6`, `Multicast`, `IPv6_unicast` |
| CPython `ipaddress` | `is_global=True`, `is_reserved=False` | none |
| R `ipaddress` | `is_global=True`, `is_reserved=False` | none — no block, RFC or registry accessor exists |

Two findings, and both point the same way. `netaddr` labels every answer with
the registry it came from, which is the field proposed here arriving at the same
place by a different route. And `netaddr` has **no special-purpose registry at
all**, so it answers `192.0.0.9` from the `/8` and the carve-out disappears, and
answers `64:ff9b::a9fe:a9fe` as `::/8 Reserved by IETF` — losing both the
`Globally Reachable = True` and the embedded `169.254.169.254`. That is P9's
CVE-producing pattern in a fourth library, and it is why the two layers are
ordered rather than merged.

The two that carry no provenance also emit `is_global` and `is_reserved` as
simultaneously `True` for `64:ff9b::a9fe:a9fe` — contradictory predicates with
nothing to check them against. Provenance is what makes a contradiction
inspectable instead of merely present.

#### 5.3.7 `embedded_kind` is affirmative only **[implemented 2026-07-27]**

`NA` means **no mechanism prefix matched**. It never means "not NAT64": RFC 6052
permits a network-specific prefix at six lengths, so a caller-supplied prefix is
invisible to a prefix table and raddr may only ever say `nat64_wk` or
`nat64_local` affirmatively. Three rules follow, each mechanical:

1. **A prefix with no geometry is not a kind.** `192.88.99.0/24` is in the
   overlay, but nothing is embedded *in* it — the 6to4 image of `192.88.99.1` is
   a mapping *out*. Naming a kind there would assert an extraction that does not
   exist, and the fact is already carried by `name` and `category = anycast`. So
   the vocabulary is **derived** from the geometry table rather than restated,
   and `6to4_relay_anycast` falls out of it.
2. **`::/96` keeps the `tail32 > 1` carve-out.** `::` and `::1` are separate,
   higher-priority IANA rows; reading their low 32 bits would report an embedded
   `0.0.0.0` or `0.0.0.1`. The threshold is a registry fact, not a heuristic, and
   both shipped in-house guards already use it.
3. **A prefix outranks the ISATAP interface identifier.** RFC 5214 §6.1 makes
   ISATAP a pattern that can sit under *any* `/64`, including one already
   assigned to another mechanism, so `2002:c000:201:0:0:5efe:1.2.3.4` is `6to4`.
   A prefix is an assignment; an interface identifier is a convention inside one.

The IID is matched by comparison against both permitted forms, never by
`bitwAnd` — §5.1.1 again, since `w3` could hold `0x80000000`.

---

## 6. Public API

### 6.1 Parse

```r
addr_parse(x)          # -> raddr_parse, all readings + per-dialect outcomes
addr_strict(x)         # -> raddr_address
addr_whatwg(x)         # -> raddr_address
addr_pton(x)           # -> raddr_address
addr_aton(x)           # -> raddr_address
addr_getaddrinfo(x)    # -> raddr_address   (pton, then aton)
addr_curl(x)           # -> raddr_address   (aton, then pton)
```

**All seven take `character`.** They are parsers, not accessors. To read a
dialect out of an existing `raddr_parse`, use `addr_reading(p, dialect)`.

`addr_reading()`'s `dialect` argument is a view selector on output, not a
leniency knob on input, so P3 is unaffected. It admits **all six** dialect names;
`raddr_parse` stores only the four primitives, and the two compositions are
resolved from those on request (§3.2).

**P2 is scoped to `addr_parse()`, deliberately.** The six single-dialect parsers
return a bare `raddr_address`, so a rejected input comes back as `NA` — which is
what P2 forbids of the *multi-dialect* result. That is the trade for having them:
they exist so a caller who has already chosen a dialect is not made to carry an
outcome they do not need. Their documentation must say so, and must point at
`addr_parse()` as the total, outcome-bearing form. P2's guarantee is that raddr's
*primary* answer is never a bare `NA`; it is not a claim about every shortcut.

```r
addr_reading(p, dialect)   # -> raddr_address
addr_status(p)             # derived factor
addr_outcome(p, dialect)   # per-dialect factor
addr_codes(p)              # union of codes; addr_codes(p, dialect) narrows
addr_is_divergent(p)       # logical
addr_input(p)              # the literals back, verbatim
is_raddr_parse(x)          # logical, scalar
```

The last two were added in Epic F. `input` is a field of the record and the
print method shows it, so leaving it reachable only through `vctrs::field()`
would have been a wart; `is_raddr_parse()` is the counterpart of the
`is_raddr_address()` that already existed.

`addr_curl()` is an exported convenience despite naming a third-party
implementation. Compliance is the floor, not the ceiling. Its liability is
managed by: implementing it as a composition of exported primitives; stamping
the verified libcurl version in its docs (P7); and exercising it against the
local `curl` in the `data-raw/` oracle run so drift fails loudly.

### 6.2 Inspect

```r
addr_family(a)  addr_zone(a)  addr_embedded(a)  addr_embedded_kind(a)
addr_format(a)  addr_expand(a)  addr_reverse_pointer(a)
```

#### 6.2.1 Reverse pointers **[implemented 2026-07-28]**

`R/reverse.R`, one export and no decoder.
`docs/research/08-encoding-reverse.md`'s first half is the specification, and
`tests/testthat/test-reverse.R` is graded against it — both RFCs publish a
worked example, so those are the first two tests.

**Cross-checked against CPython, not against `ipaddress`** **[verified
2026-07-28]**. 6029 addresses — 3000 random IPv4, 3000 random IPv6 drawn as raw
bytes, plus both ends of both families, the 4-in-6 forms and the `0x80000000`
word in each position — agree with Python 3.14.6's `ipaddress` on
`.reverse_pointer` and on `int()`, with **zero** mismatches on either surface.
Ours differs from Python's pointer by exactly two documented things: the
trailing dot, and lowercase. The R `ipaddress` package is **not** a usable
oracle for either surface (O18, and `ip_to_integer()` cannot run at all without
`bignum`), which is why the oracle is a different language rather than a
different R package.

**The suffix is the only thing that can say which tree a name is in.** A label
`9` is legal in both and means octet 9 under `in-addr.arpa`, nibble 9 under
`ip6.arpa` (research 08 gotcha 9). So the family picks the tree here exactly as
it picks the width in §6.5.1, and nothing sniffs the labels.

**IPv4 reverses octets, IPv6 reverses nibbles.** Research 08 gotcha 1: the two
granularities are different, and reversing IPv6 by octet is a classic bug that
produces a name of the right length, made of legal labels, pointing somewhere
else. `test-reverse.R` spells the wrong name out next to the right one rather
than asserting the difference in the abstract.

**The name is never built from the text form.** An `ip6.arpa` name is always 32
labels — no `::`, no suppressed leading zeros, no mixed 4-in-6 spelling — and
every one of those is something §5.1.3's renderers are *required* to do. So the
implementation reads the octet matrix, and reusing `addr_format()` or
`addr_expand()` would be gotcha 2 exactly. The one place the expanded form does
appear is as a second opinion inside the tests, where it shares no code with
what it checks.

**The trailing dot is emitted; the case is a choice.** Research 08 round-trip
failure 9: the absolute form is unambiguous, and the relative one is the same
name but not the same string, so raddr picks one. Lowercase follows RFC 5952
§4.3 by analogy — `UNVERIFIED` that any RFC mandates it for `ip6.arpa` labels
specifically, and RFC 1035 §3.1's case-insensitive comparison rule means it
cannot matter to a resolver.

**The 4-in-6 form gets the mechanical answer.** No RFC settles whether
`::ffff:192.0.2.1` maps into `ip6.arpa` or into `in-addr.arpa` (research 08
gotcha 24, `UNVERIFIED`). raddr returns the `ip6.arpa` name because the address
is an IPv6 address, documents that the *useful* name is usually the
`in-addr.arpa` one, and leaves reaching it to naming the embedded address —
the same refusal to demote as §6.5.1's width rule.

**The zone is dropped, and a zoned address still renders.** A zone index is
strictly local to a node (RFC 4007 §6) and the grammar has nowhere to put it.
The second half of that sentence is the point: §3.5.2 records that CPython
*raises* on `IPv6Address("fe80::1%lo0").reverse_pointer`, and §3.5.2's warning
that Epic K inherits the bug is discharged by a test.

**There is no pointer-to-address function.** Research 08 round-trip failure 10:
`ip6.arpa` → address is bijective but `in-addr.arpa` → address is not, because
a partial name is a prefix — `10.in-addr.arpa.` is a /8, from RFC 1035 §3.5's
own gateway-lookup example. The general answer is a prefix and §6.6 does not
exist yet, so the decoder waits for it rather than shipping a version that
silently requires exactly four labels.

Three forms are never emitted, all three for reasons the research note
documents: `ip6.int` (deprecated by RFC 3152 §2, retired by RFC 4159), RFC 2673
bitstring labels (made Experimental by RFC 3363, whose §3 found the hex text
form sufficient), and RFC 2317 classless delegation names (an operator
convention down to the separator character, so generate-only and never
round-tripping).

### 6.3 Classify

```r
addr_classify(a)         # -> raddr_class
addr_category(a)         # factor, 19 levels (section 5.3.2). Was addr_scope()
addr_embedded_kind(a)    # factor, affirmative only (section 5.3.7)
addr_embeddings(a)       # list_of<raddr_embedding>, always. Replaces
                         #   addr_embedded_scope(); see section 5.3.5
addr_within(a, blocks)   addr_within_any(a, blocks)
```

The three field accessors each take **either** a `raddr_address`, which they
classify, **or** a `raddr_class` a caller already holds. Everything else on the
record is reached with `as.data.frame()` rather than nine more accessors: a
record is one column under `vctrs`' default, which is right inside a data frame
and wrong for someone who wants to read `globally_reachable`.

`is_raddr_class()` and `is_raddr_embedding()` ship alongside, matching
`is_raddr_address()` and `is_raddr_parse()`. There is no public
`raddr_embedding()` constructor: they come out of classification and are not
built by hand.

#### 6.3.1 Containment **[implemented 2026-07-28]**

`R/within.R`. `addr_within()` tests each address against the block in the same
position, recycling as any pair of vctrs arguments does; `addr_within_any()`
tests every address against every block and answers whether *any* contains it.
The second is the denylist question and the one with the performance target
(§11.1.5).

**A block is the question being asked, so a bad block errors.** This is the one
place raddr's decoders do not return `NA` for input they cannot read, and the
reason is that the two failures are not alike. A malformed *address* is data,
and a missing answer is the honest report. A malformed *block* is a hole in the
denylist that the caller has no way to see: it silently matches nothing, and
nothing about the result says so. So a missing block, a prefix length outside
`0:32` or `0:128`, an unparseable address and a block with **host bits set** all
abort with `raddr_error_block`. A missing *address* is still `NA`, never `FALSE`.

**`192.168.1.1/24` is refused rather than masked**, because it is equally likely
to be a typo for the network and a host that wanted `/32`. Guessing between them
is the silent reinterpretation §6.5.2 refuses for a double above 2^53. Python's
`ip_network()` refuses it too; the error names the masked form.

**Blocks are read by `addr_strict()`, not `addr_pton()`.** §3.2 records that
`pton` is the one dialect whose behaviour varies by platform — raddr models
Apple libc, which strips leading zeros, so it reads `010.0.0.0` as `10.0.0.0`
where glibc rejects the text outright. A block that denotes different networks
on different machines is worse than one that is refused, and CIDR text is
written in the RFC grammar in the first place.

**The family decides the space, and a mismatch is `FALSE` rather than an
error**, because a denylist holding both families is an ordinary thing to hold.
A `v6_4in6` address searches the **IPv6** space: `::ffff:10.0.0.1` is inside
`::ffff:0:0/96` and is *not* inside `10.0.0.0/8`. That is §6.5.1's width rule in
its containment form — the address is 128 bits that happen to embed an IPv4 one,
and the embedding is the separate fact `embeddings` reports (§5.3.5).

**No `bitwAnd`, for the third time.** §5.1.1 makes a word a raw bit pattern in
which `NA_integer_` *is* `0x80000000`, so a bitwise matcher reads
`2620:4f:8000::/48` — the AS112 direct-delegation prefix — as missing and never
matches it, and cannot spell a `/1` mask at all. Keys are integer division of
unsigned doubles, as in §5.3's matcher. `test-within.R` pins both cases.

`addr_classify()` also refuses a `raddr_parse`, which is P1 one step further in.
Four readings may be four different addresses, and §4 puts the choice in a
function name — so the error names `addr_reading()` and the four primitives
rather than silently taking `whatwg`. `format()` may default because R
structurally forces one value out of it; `addr_classify()` is not forced.

### 6.4 Data and metadata

```r
addr_registry()  addr_codes_registry()
addr_registry_version()  addr_registry_outdated(max_age = 365)
addr_transition_registry(what = c("prefixes", "embeddings"))
addr_transition_version()
addr_address_space()  addr_address_space_version()
addr_category_map()  addr_category_version()
```

`addr_transition_*` were added in Epic H. The overlay is stamped separately from
the IANA snapshot (§7.2), so it needs its own version accessor; folding it into
`addr_registry_version()` would make one date imply something about a table it
says nothing about.

`addr_address_space*` were added in Epic I and follow the same rule for the same
reason (§7.3). They are a **separate accessor**, not a `which =` argument on
`addr_registry()`: the two pairs have different columns, so one function would
return a different shape per argument and `addr_registry()`'s documented
promise of 51 rows with five policy columns would stop being true.

There is deliberately no `addr_address_space_outdated()`, matching
`addr_transition_version()`, which also ships without one. Adding it later is an
API addition; removing it would be breaking.

### 6.5 Encoding round-trips

```r
addr_to_bytes / bytes_to_addr        addr_to_binary / binary_to_addr
addr_to_hex   / hex_to_addr          addr_to_integer / integer_to_addr
```

`addr_to_integer()` returns `character` decimal by default so it always works,
and `bignum` output only when that package is present. Degrade, never error.

#### 6.5.1 The first three pairs **[implemented 2026-07-28]**

Bytes, hex and binary ship together in `R/encoding.R`; the integer pair is
`RADD-qqmsvpzr` and is not built yet. `docs/research/08-encoding-reverse.md` is
organized as a numbered list of *round-trip failures*, and
`tests/testthat/test-encoding.R` is organized the same way — one section per
failure, asserting it happens where the document says and nowhere else.

**The width is the family, and that is the whole design.** 4 octets for IPv4, 16
for both IPv6 families. Nothing inspects the bits to choose a width. Research 08
round-trip failure 2 is the reason: `192.0.2.1`, `::ffff:192.0.2.1` and the
deprecated `::192.0.2.1` share their low 32 bits (RFC 4291 §2.5.5), so one
integer names three distinct objects and the family must travel alongside the
number. Here the length carries it, and the three decode back to three different
addresses in three different families.

The 4-in-6 form therefore encodes to **16** octets. Research 08 gotcha 23 warns
that this surprises people; demoting it to 4 is the collapse raddr exists to
refuse, and it is the same refusal as §5.3's on the classification side.

**Leading zeros are load-bearing, which is the opposite of RFC 5952 §4.1.** That
rule suppresses them in *text*; these are not text forms. Every output is fixed
width and zero padded — `::1` is 32 hex digits, 31 of them `0`. Research 08 §3
names mixing the two rules as a common bug, so both directions are pinned.

**A short string is a guess, and raddr does not guess.** Seven hex digits is an
IPv4 address missing one zero or an IPv6 address missing twenty-five. Any width
other than the two the family fixes decodes to `NA`; nothing is padded to reach
one. This is research 08 round-trip failure 5 read as a rule rather than as a
caution.

**The zone does not survive, and "it round-trips" is not "nothing was lost."**
Both claims are true at once and the tests keep them apart.
`bytes_to_addr(addr_to_bytes(x)) == x` holds, because §5.1.2 keeps the zone out
of equality — but `addr_zone()` on the result is `NA`, because RFC 4007 §6 says
zone indices are strictly local to a node and nothing in the octets can carry
one (research 08 round-trip failure 1).

**Input leniency is three named things and no others.** Uppercase hex, because
RFC 3596 §2.5 and RFC 2874 §2.2.1 print their own examples in uppercase; an
optional `0x`, which is a presentation convention with no RFC behind it, read
and never written; and whitespace grouping, which research 08 §4 calls cosmetic.
Nothing else is normalized away.

**`bytes_to_addr()` refuses a bare `raw` vector.** Eight octets are one
malformed address or two IPv4 addresses, and the caller knows which. The list is
the vectorized form, and `list()` around a single address is the fix the error
names.

The decoders return a missing address rather than signalling, matching the
single-dialect parsers of §6.1 — P2 is a promise about `addr_parse()`, not about
every shortcut.

#### 6.5.2 The integer pair **[implemented 2026-07-28]**

`R/integer.R`. The awkward pair, because **R has no unsigned integer type and no
128-bit one**. Its `integer` is signed 32-bit, so `128.0.0.0` upward — over half
the IPv4 space — does not fit and `as.integer(4294967295)` is `NA` rather than a
wrap; its `double` is exact to 2^53, which covers IPv4 with room to spare and
misses IPv6 by twenty-five orders of magnitude (research 08 gotchas 26 and 27).

So the default carrier is a **decimal string**, which always works, and
`output = "double"` is offered because a double is exactly right for IPv4 and is
the only R-native numeric that is. It is `NA` for every IPv6 row, the 4-in-6
family included, on the §6.5.1 grounds: 128 bits is 128 bits, and nothing close
is offered in place of the value.

**The `bignum` dependency is optional in fact, not only in `DESCRIPTION`.**
`ipaddress::ip_to_integer()` calls `check_installed("bignum")` before it does
anything, so without that package the function errors — including for IPv4,
where no arbitrary-precision arithmetic is involved at all **[verified
2026-07-28, 1.0.3]**. raddr does the arithmetic itself, so both
default-reachable outputs encode and decode either family with nothing
installed. `has_bignum()` exists as a seam so the branch is testable without
uninstalling anything.

That mock proves the branch and not the claim, so the claim was checked against
the world **[verified 2026-07-28]**: with `bignum` and `bit64` moved out of the
library entirely, the suite is 1174 passing and **6 skipped** with no errors,
and `R CMD check --as-cran` is clean but for the pre-existing new-submission
NOTE. `R CMD check` refuses a complete check when a `Suggests` package is
missing unless `_R_CHECK_FORCE_SUGGESTS_=false` — which is what CRAN itself
sets on a machine that lacks one, and how the run above was made. A mocked
`has_bignum()` cannot catch a `bignum::` call reached by another route, and this
is what says there is none.

**`output = "bignum"` errors when `bignum` is missing, and that is not a
retreat from "degrade, never error".** The subissue's complaint is about being
made to install a package you did not ask for; it is not an argument for
answering a request for numbers with text. Degrading to the character vector
was implemented first and then reverted, because the digits are right and the
answers are not: character ordering is lexicographic, so `max()` of
`c("9", "16777216")` is `"9"` and `sort()` puts 10 before 9. The failure lands
on the first thing a caller does with the value, and it is silent. The error
names both the install command and the `"character"` output.

**What `bignum` shows is not what it stores.** It displays 7 significant
figures by default and its `as.character()` and `format()` follow the display,
so a `biginteger` holding an IPv6 address prints, coerces and `write.csv()`s as
`"4.254077e+37"`. The value is exact and so is arithmetic on it; only the
rendering rounds. This is the same trap as the input one below, from the other
side, and `tests/testthat/test-integer.R` pins both.

**The arithmetic is base 10^6 over the four words**, which is the widest chunk
keeping every intermediate under 2^53 and therefore exact in a double: the
division's dividend is `rem * 2^32 + word` and the multiplication's product is
`word * 10^6 + carry`, both bounded by 4.295e15. 2^128 − 1 is 39 digits, so
seven chunks span any address and a 40-digit number is out of range on its
length alone. Values of 15 digits or fewer skip the chunked path entirely — that
is every IPv4 address, and it is worth 4x on the decode (§11.1.4).

**`family` is required, with no default**, because research 08 round-trip
failure 2 is exactly this pair's problem: `3221225985` is `192.0.2.1` as IPv4
and the deprecated `::192.0.2.1` as 128 bits, and `::ffff:192.0.2.1` is a fourth
object again. `ipaddress::integer_to_ip()` takes `is_ipv6 = NULL` and infers
one. The argument takes the factor from `addr_family()` directly, so the round
trip reads `integer_to_addr(addr_to_integer(a), addr_family(a))`.

Four input traps are handled rather than inherited. A `bignum` vector **is** a
character vector underneath and its `as.character()` is the rounded display form
— 2^128 − 1 comes back as `"3.402824e+38"` — so the decoder asks for
`notation = "dec"`. And a `double` above 2^53 is refused rather than decoded,
because it has already lost the value it was meant to carry; the same number
given as digits is fine.

The other two were found by the adversarial pass of **[verified 2026-07-28]**,
after the pair had already shipped green. A **`raw` vector is a type error**,
because `as.character()` on a raw is *hexadecimal*: the fallback branch read
`as.raw(16)` as the number ten and returned `0.0.0.10` silently, and only raws
above `0x99` escaped by failing the digit scan. Bytes go to `bytes_to_addr()`,
which is the pair that knows they are bytes — the same redirection §6.5.1 makes
for a bare `raw` vector. And **IEEE negative zero decodes as zero**: `-0` passes
every range test (`-0 >= 0` and `identical(-0, 0)` are both TRUE) but
`sprintf("%.0f", -0)` writes `"-0"`, which the digit scan then rejected, so
`0 * -1` and `0` disagreed. Adding zero normalizes the sign.

The type/value line these two draw is the one §6.5.1 already draws: a wrong
**value** is a missing address and signals nothing, a wrong **type** errors.

### 6.6 Prefix

`addr_` throughout. Measured **[verified 2026-07-26]**: `ipaddress` exports 29
names matching `^ip_|^is_`, including every predicate and three of the four
encoding pairs. Collisions under `addr_`: zero.

---

## 7. Classification data

Source: **four** IANA registries (CC0, 29 777 bytes), vendored as two pairs
that answer two different questions.

| Pair | Rows | Answers | Accessor |
|---|---|---|---|
| special-purpose v4 + v6 | **51 blocks** | policy — the five IANA logicals | `addr_registry()` |
| address space v4 + v6 | **276 rows** | identity — what a range is for, who holds it | `addr_address_space()` |

The special-purpose figure corrects the "26 + 27 rows" this section used to
claim; see §7.1. The address-space pair is §7.3, and IANA states the precedence
between them itself.

All five policy columns surfaced, never collapsed. `globally_reachable` reports
IANA's `Globally Reachable` column verbatim, per row, with an RFC citation — it
is **not** a derived `is_global`, and §5.3 says the same. RFC 8190 §3 renamed
this column *away from* "Global" precisely to stop that reading: `True` holds
for AS112, AMT, PCP/TURN/SRP anycast, ORCHIDv2 and DETs, none of which is an
ordinary public host, and ORCHIDs should not appear in IPv6 headers at all.

Lookup is **longest-prefix-match**, not first-match-wins, because the registry
contains carve-outs: `192.0.0.9/32` and `192.0.0.10/32` are globally reachable
inside a non-global `192.0.0.0/24`.

Table lookup is necessary but not sufficient. `64:ff9b::/96` is marked globally
reachable *because it maps onto global IPv4*; the embedded address must be
extracted and classified separately. Hence `category` *and* `embeddings`, with
the inner address carrying its own `category` (§5.3.2, §5.3.5).

One overlay remains, separately stamped from the IANA table: **transition
prefixes needing sub-registry granularity** — 6to4 `2002::/16`, Teredo
`2001::/32`, ISATAP, the six RFC 6052 NAT64 prefix lengths.

The **cloud-metadata overlay is removed** from raddr and belongs to `ssrfr`.
`169.254.169.254` appears in no RFC; the table was hand-assembled from provider
docs and partly from memory. Removing it deletes the package's only data table
with no upstream authority.

No network refresh in v0.1. The registries change on a multi-year cadence, the
whole vendored payload is 29 KB, and "zero network code" is a cleaner claim
than "network code that defaults off".

### 7.1 What the CSVs actually contain **[implemented 2026-07-27]**

Vendored from the two `-1.csv` endpoints, `Last-Modified: 2025-10-09`, 4712
bytes. Everything below was found by parsing the real bytes, and each item is
something a naive read of the files gets wrong.

**The row count in §7 was a line count.** Three records wrap across lines,
because they cite more than one RFC in a quoted field
(`255.255.255.255/32`, `2001::/32`, `fc00::/7`). The files hold 26 and 27
*lines* but **25 and 25 records**. One v4 record then names two prefixes in a
single field — `"192.0.0.170/32, 192.0.0.171/32"` — and is split, because a
composite block matches nothing. The result is **26 + 25 = 51 blocks**, and a
block is the unit raddr stores and matches.

**The policy columns are three-valued, not boolean.** Four spellings occur:
`True`, `False`, `N/A`, and empty. They map to `TRUE` / `FALSE` / `NA` / `NA`,
and the two `NA` cases mean different things — both of which are *IANA
declining to answer*, which is not the same as answering `False`:

| block | `Globally Reachable` | why |
|---|---|---|
| `192.88.99.0/24`, `2001:10::/28` | empty | deprecated; carries a `Termination Date` and no policy values at all |
| `2002::/16` (6to4) | `N/A [3]` | reachability follows the **embedded** IPv4 address (RFC 3056), which a prefix table cannot express |
| `2001::/32` (Teredo) | `N/A [2]` | relay advertisement is **voluntary and per-deployment** (RFC 4380 §5), so reachability depends on operator choice, not on any bits in the address |

**The two `N/A`s are not one case.** They carry two different IANA footnotes
pointing at two different RFCs, and a reader who follows `[2]` expecting 6to4's
reason will not find it. raddr reported them merged until this was caught; the
merged version was wrong about Teredo specifically.

Collapsing either to `FALSE` would have raddr assert, in its own voice, a policy
the registry specifically withheld.

**Footnote markers are data; footnote text is not in the file.** Markers appear
both in `Address Block` (`192.0.0.0/24 [2]`, `2002::/16 [3]`) and inside policy
values (`False [1]`). They are stripped from the values and recorded in a
`footnotes` column, because their *text* lives only on the HTML registry page.
raddr reports that a caveat exists and does not invent its wording.

**§5.1.1 is load-bearing for the vendored data, not just for user input.**
`2620:4f:8000::/48`, the AS112 direct-delegation prefix, has second word
`0x80000000` — the exact pattern R reserves for `NA_integer_`. A registry
built on "words are numbers" either loses this block or corrupts it. Storing
words as raw bits is what makes the vendored table representable at all, and
`as.integer(-2147483648)` is an out-of-range `NA` plus a warning, so the fold
is assigned rather than coerced.

**`--check` compares content, never dates.** The staleness guard rebuilds the
table from the committed `inst/extdata` bytes and diffs it against the
committed `R/sysdata.rda`. A rebuild on a different day, or on a machine that
got no `Last-Modified` header, must not fail the guard — provenance is not
content.

**The repo's own hygiene tried to rewrite the vendored bytes.** The CSVs
terminate rows with CRLF but use bare LF inside their wrapped quoted fields —
genuinely mixed, upstream. `.gitattributes`' `* text=auto eol=lf` and the
`mixed-line-ending` / `end-of-file-fixer` pre-commit hooks all normalize that,
which changes the file and therefore falsifies the sha256 the build script just
recorded. `inst/extdata/*.csv` is now `-text` in `.gitattributes` and excluded
from the three whitespace hooks. **A vendoring pattern needs an exemption from
the repo's formatting, or the formatting silently invalidates the provenance.**

**An undated snapshot is outdated (see §7.2 for the overlay's own stamp).** The CSVs carry no version field, so the
stamp is the served `Last-Modified`, normalized to ISO at build time with an
explicit month map (never `strptime`'s locale-dependent `%b`). The stamp is the
**older** of the two halves, and is `NA` if either half is undated;
`addr_registry_outdated()` then returns `TRUE`. Treating absence of evidence as
evidence of freshness is the one failure a staleness check exists to prevent.

**But the stamp answers a weaker question than "when did IANA change this"**
**[verified 2026-07-27].** `Last-Modified` is a site *deploy* timestamp, not an
editorial one. Seven CSV exports across four unrelated IANA registries are
served with the identical second `Thu, 09 Oct 2025 21:51:16 GMT`, and the IPv4
multicast registry's own page records an editorial `Last Updated` of
`2026-06-26` while several of its CSV exports still carry a 2025
`Last-Modified`. IANA's editorial signal is the page-level `Last Updated` field
inside the XHTML, which raddr does not fetch.

The number raddr currently ships is nonetheless correct: both special-purpose
registries record `Last Updated` `2025-10-09`, matching the served header. It is
right by coincidence, which is why the claim was narrowed rather than the
mechanism changed. The failure mode to watch is a deploy with no content change
advancing the stamp, which would assert freshness the data has not earned — the
same failure as an undated snapshot, arriving more slowly.

Two things contain the damage. Content identity is tracked exactly by a sha256
per file, and `--check` compares content and never dates, so provenance drift
cannot move the staleness guard. And the "older of the two halves" rule is
currently a no-op, because both halves always carry the same deploy second; it
is kept as the correct rule should they ever diverge.

Stamping from the page-level `Last Updated` is the real fix and is deferred
(`RADD-lfgkjvfv`), because it means scraping XHTML in the build script.
Its failure mode is safe — an unparseable field yields `NA`, which yields
`outdated = TRUE` — so the deferral is a cost decision, not a risk one.

### 7.2 The transition overlay **[implemented 2026-07-27]**

**It is not vendored, because there is nothing to vendor.** The overlay is
transcribed from RFCs by hand, so it follows `R/codes.R`'s const-registry shape
rather than the build-script shape the IANA registries use. A `data-raw/` script
that "builds" a table from a literal in its own source would be ceremony around
a constant.

**IANA marks the boundary itself — but only half of it is about embedding.**
§7.1 found that the only two non-deprecated blocks IANA leaves `N/A` for
`Globally Reachable` are Teredo `2001::/32` and 6to4 `2002::/16`. For 6to4 the
reason really is that reachability follows the *embedded* IPv4 address, so the
registry declines in its own voice exactly where the overlay picks up.

For Teredo it is not. RFC 4380 §5 makes relay advertisement voluntary and
per-deployment, so IANA's `N/A` there says *nobody can answer this from the
address at all* — including the overlay. The overlay still earns its Teredo row,
but on a different ground: the address carries extractable structure (a server
and a client, §7.2) that is worth reporting on its own terms. It does not
resolve the `N/A`, and §7.2 must not be read as if it did.

This distinction was merged in an earlier draft, which made the boundary
argument look stronger and more uniform than the registry supports. The
`::/96` and `::ffff:0:0:0/96` rows aside, the overlay mostly **annotates** the
IANA table rather than extending it.

**Two shapes, because prefixes and geometry are different facts.**
`addr_transition_registry("prefixes")` lists fixed prefixes with a `kind`;
`addr_transition_registry("embeddings")` gives one row per **contiguous
segment** of an embedded IPv4 address. Three forms make the second table
necessary:

- **Teredo carries two addresses**, not one: a server in the clear at bit 32,
  and a client at bit 96 stored **bitwise-complemented** so a NAT will not
  rewrite it in transit (RFC 4380 §4). It is the only complemented field.
- **NAT64 geometry is a function of the prefix length, not of a prefix.** A
  network-specific prefix may be *any* prefix of the six lengths RFC 6052 §2.2
  permits, so those rows carry a `prefix_len` and no block.
- **ISATAP has an embedding but no prefix at all** — it is an
  interface-identifier pattern (`0000:5efe`, or `0200:5efe` when built from a
  globally unique IPv4) that can sit under any `/64`.

**The u-byte is why the segments exist.** RFC 6052 reserves bits 64–71, and the
embedded address skips them, so three of the six lengths — /40, /48 and /56 —
split it in two. /32, /64 and /96 are contiguous:

| prefix length | segments (offset, bits) |
|---|---|
| /32 | (32, 32) |
| /40 | (40, 24) + (72, 8) |
| /48 | (48, 16) + (72, 16) |
| /56 | (56, 8) + (72, 24) |
| /64 | (72, 32) |
| /96 | (96, 32) |

The embedded address begins immediately after the prefix at every length
**except `/64`**, where the u-byte sits between them. That single exception is
the whole reason the geometry cannot be computed from the prefix length and has
to be tabulated. The tests check the RFC's rules — segments totalling 32 bits,
ordered, disjoint, and clear of bits 64–71 — rather than only restating the
numbers a second time, because hand-transcribed offsets are wrong in ways
re-reading does not catch.

**A second stamp, and no expiry.** `addr_transition_version()` is independent of
`addr_registry_version()`: the two change for unrelated reasons, so neither is
evidence about the other. There is deliberately no
`addr_transition_outdated()` — the RFCs this is drawn from do not expire.

**`0xfdffffff` is not a mask.** The ISATAP identifier mask was first written as
that literal, which is a double above 2^31; `bitwAnd()` returns `NA` for it
silently, and every ISATAP address would have failed to match. It is spelled
`bitwNot(0x02000000L)` instead. This is the §12 signed-integer constraint
reappearing in `bitwAnd`'s *operand* rather than in a shift, which is the form
the constraint as written does not obviously cover.

### 7.3 The address-space fallback **[implemented 2026-07-27]**

**Why a second pair at all.** Each of these two registries is an *exact
partition* of its space — 256 IPv4 `/8`s, and 20 IPv6 blocks that tile `::/0`.
With them, classification is **total**: every address matches some row, so
`global` is a statement backed by a registry row rather than an inference from
an absence.

The failure mode this closes is not hypothetical, and the clearest case is
**multicast**: `224.0.0.0/4` and `ff00::/8` appear in *neither* special-purpose
registry. A classifier derived from that pair alone therefore has no multicast
handling at all, which is how `ssrfcheck` shipped CVE-2025-8267. P9.

**Precedence is stated by the source, not chosen by raddr.** The address-space
registries carry "For authoritative registration, see [Special-Purpose Address
Space]", so special-purpose outranks address space on IANA's own instruction.
Because the address-space pair is a partition, *every* special-purpose block
falls inside one of its rows — precedence decides every doubly-matched lookup,
not an edge case. **Five prefixes appear in both pairs identically**
[verified 2026-07-27]: `0.0.0.0/8`, `10.0.0.0/8`, `127.0.0.0/8`, `fc00::/7`,
`fe80::/10`. (`RADD-pekbpche` predicted "seven IPv6 and eleven IPv4"; measuring
it gave five, and the measurement stands.)

**Identity, and no invented policy.** The five policy logicals do not exist in
these registries, so they are absent from the table rather than filled in. What
these carry instead is `status` (IPv4: `ALLOCATED` / `LEGACY` / `RESERVED`),
`date` (IPv4), and `notes` (IPv6 — free prose, and the only record that
`200::/7` and `fec0::/10` are deprecated). `rfc` is `NA` for **every** IPv4 row,
because that registry has no reference column; its citations live in numeric
footnotes whose text is on the HTML page and not in the CSV.

**The IPv6 Global Unicast Assignments registry is deliberately not vendored.**
It is not a partition — sub-ranges of `2000::/3` appear in no row — so absence
there would mean "unallocated", a different answer from "not found".

**Every documented parsing trap reproduced** [verified 2026-07-27]. The IPv4
`Prefix` column is `000/8`…`255/8` and **not CIDR** — it is read as a number and
the block rebuilt canonically, because raddr's own strict dialect rejects `000`
as a leading-zero octet, which is exactly the ambiguity behind the `inet_aton`
CVE class. The IPv4 header literally reads `Status [1]`, so matching on
`Status` finds nothing. The IPv6 export at `ipv6-address-space.csv` 404s into a
4216-byte HTML body and the real file is `ipv6-address-space-1.csv`. The `RDAP`
column is corrupted by the export itself on every ARIN and AFRINIC row, two
URLs run together with no separator — dropped here, but the general lesson is
that **an IANA CSV export does not guarantee per-column fidelity**.

**§5.1.1 recurs, and the stakes are larger.** `8000::/3` stores `w1` as
`0x80000000` — R's `NA_integer_` bit pattern — so the AS112 `/48` was not a
one-off. The partition check tiles the space through the unsigned proxy for
this reason; on a naive numeric read the check does not merely mis-report, it
silently loses an eighth of the IPv6 address space.

**Two stamps, and here the "older half" rule does real work.** The pair is
stamped separately from the special-purpose pair, for §7.2's reason. Unlike
that pair — whose halves share a deploy second, making the rule a no-op — these
four files are **not** served with one timestamp: three carry
`Thu, 09 Oct 2025 21:51:16 GMT` and the IPv6 address-space export carries
`Sat, 11 Oct 2025 00:06:16 GMT`. The `Last-Modified`-is-a-deploy-timestamp
caveat (§7.1) applies more strongly here, since these two registries' editorial
dates are known to differ from what they are served with (`RADD-lfgkjvfv`).

### 7.4 What the registry pins, asserted **[implemented 2026-07-28]**

`tests/testthat/test-harvest.R`. Everything below was checked against the
vendored snapshot before it was written down, and the two normative claims
against the RFCs rather than against memory of them.

**The one cross-column rule.** RFC 6890 §2.2.1 states exactly one implication:
`Destination = False` requires `Forwardable` and `Global` to be false too. It
ties `Source` to nothing at all, and it says this in a lowercase descriptive
"must" — §2.2.1 does not invoke RFC 2119 for the attribute definitions, so this
is a consistency property of the registry and not a conformance requirement on
an implementation. Checked over all 51 blocks; it holds.

**Which is why no column is the answer.** Six rows prove any single "is this
usable" boolean would be lossy. `255.255.255.255/32` is the registry's *only*
`Source = False, Destination = True` row — written to, never from. Five rows go
the other way (`0.0.0.0/8`, `0.0.0.0/32`, `::/128`, `192.0.0.8/32`,
`100:0:0:1::/64`), and three of those five carry `reserved_by_protocol` while
two do not, on otherwise identical policy. That is the five-independent-columns
shape §4 chose, now pinned rather than asserted in prose.

**A withdrawn row reports `NA`, not `False`.** `192.88.99.0/24` and
`2001:10::/28` are terminated, IANA prints nothing in their policy columns, and
raddr keeps that as missing. A blank is not a denial, which is the whole "facts,
not verdicts" position in one assertion.

**Longest-prefix-match regressions.** Each of these is *wrong* under
first-match-in-file-order, which is what a naive scan of the registry CSV
produces:

| address | must resolve to | not |
|---|---|---|
| `0.0.0.0` | `0.0.0.0/32` | `0.0.0.0/8` |
| `255.255.255.255` | `255.255.255.255/32` | `240.0.0.0/4` — they differ in `destination` |
| `192.88.99.2` | the live `/32` | the terminated `/24`, whose policy is blank |
| `100::1` / `100:0:0:1::1` | discard / dummy | each other, one hex digit apart |
| `5f00::1` | `5f00::/16` (SRv6 SIDs) | `4000::/3`, the reserved block it nests in |

The `5f00::/16` row is also a layering test: the inner block is in the
special-purpose registry and the outer one in the address-space registry, so it
pins IANA's own precedence note (§7.3) as well as the match.

**Boundaries, in both directions.** `192.0.0.0/29` is `.0` through `.7` and
nothing else; `.8`, `.9`, `.10`, `.170` and `.171` each have their own row and
their own policy, so an off-by-one in the prefix arithmetic silently swaps five
protocols' semantics — and every one of those addresses matches *something*
either way, which is why it would be silent. The `/29` is also
`Forwardable = True` inside a `Forwardable = False` `/24`: a more-specific block
that **widens** a permission its parent withholds, which is why containment
cannot be shortcut to "the shortest match decides".

`2001:db8::/32` is **not** inside `2001::/23`. The `/23` spans `2001:0000::`
through `2001:01ff:ffff:…`, and reading it as "everything under `2001:`" would
fold the documentation prefix into IETF protocol assignments. Asserted at both
edges from both sides.

**And one prefix that must never match.** RFC 5180 §8 as printed names
`2001:0200::/48` for IPv6 benchmarking. Errata ID 1752 — **Verified**,
2009-04-27 — corrects it to `2001:0002::/48`, because the printed prefix was
never in the RFC 4773 pool. `2001:200::/48` is real, allocated, globally routed
APNIC space, so matching the typo would be worse than missing the prefix.
`2001:2::1` is `benchmarking`; `2001:200::1` is `global`.

**Ten corpus literals that had no fixture**, from
`docs/research/delta-c-parsers.md`:

- `fe80::a%25en1`, `fe80::1%25lo0` — the RFC 6874 percent-encoded zone spelling,
  which RFC 9844 obsoleted. raddr is not a URI parser and never percent-decodes,
  so the zone is the literal text `25en1`.
- `::1%1]foo.bar baz'"` — the zone runs to the end of the string, delimiters
  included, because Apple's `inet_pton` takes everything after the first `%`
  (§5.1). Implementations that truncate at `]`, whitespace or a quote read a
  different host. It also lands on `getaddrinfo`'s whitespace gate covering the
  address and not the zone (§3.2).
- `0x8.0X8.010.8` — hex, hex, octal and decimal **in one literal**. Nothing says
  the parts share a radix; each is a separate base-0 `strtoul`.
- `0129.0.0.1` — CVE-2021-29418, an invalid octal digit in the *first* part.
  `netmask` read it as `0.0.0.1` and lost the part entirely. Under raddr it is
  `129.0.0.1` or a rejection, and never `0.0.0.1` or `127.0.0.1`.
- `2002:7f00:1::` (6to4 carrying `127.0.0.1`, the Symfony CVE-2026-48736
  string), `64:ff9b::a00:1` (the NAT64 well-known prefix carrying `10.0.0.1` — a
  globally reachable prefix around a private payload, simultaneously), and
  `::ffff:169.254.169.254` (IPv4-mapped link-local, the metadata bypass every
  surveyed guard misses). In all three the outer block and the inner address
  disagree about danger, and §8.1's position is that raddr reports both.
- `100.100.100.200` — Alibaba's metadata endpoint, inside CGNAT and outside
  every link-local rule. raddr has no opinion about metadata endpoints (§1.1);
  what it must not do is call it global.
- `[::]` — URL authority syntax. Stripping brackets is the URL layer's job, so
  every dialect rejects it.

`1.2.3.4junk` is the one row in the harvest raddr **cannot settle**: glibc
accepts it, Apple and musl reject it, and the fixture records Apple only. The
test asserts rejection under every dialect — which is what raddr's model claims
— and says so: until `RADD-xrgomyhx` gives the fixture a per-libc column, a pass
there is a statement about Apple and nothing else.

---

## 8. Scope for v0.1

Re-derived on raddr's own merits. The draft spec sized this list against an
urgency argument — that every SSRF fix costs two mirrored patches across
`sitemapr` and `robotstxtr` until raddr ships — which **no longer holds**. With
policy moved to `ssrfr`, shipping raddr lets those two delete the classification
half of their guards and keep the policy half. The mirrored-patch cost ends when
`ssrfr` ships, not when raddr does.

**In:**

- `raddr_address` with three-state family and separate zone.
- Four primitives, two compositions, `addr_parse()` with per-dialect outcomes.
- Full IPv4 obfuscation handling; full IPv6 parse; RFC 5952 format and expand.
- Embedded-IPv4 extraction for every wrapper in §8.1, **including ISATAP**.
- Registry-driven `addr_classify()` with `category` and plural `embeddings`.
- Versioned reason-code vocabulary shipped as data.
- `addr_within` / `addr_within_any`, encoding round-trips, reverse pointer.
- WPT + IANA vendored with upstream SHAs; the invariant suite.

**Deferred, on their own merits:**

- Compiled fast path. Pure R for v0.1; `src/` is a v0.2 optimization with the
  API already frozen. If compiled code becomes necessary, plain C — not
  Rcpp/Boost, whose dependency weight is the plausible cause of `iptools`'
  archival and of `ipaddress`'s OS-dependent parse.
- `addr_registry_refresh()` (network).
CIDR set algebra beyond containment is **not** on this list — §1.1 excludes it
permanently and assigns it to `ipaddress`. Deferred means "later"; excluded means
"never". Keep the two lists disjoint.

ISATAP returns to scope. It was cut as "nobody implements it; low value until
someone asks", which was an urgency judgment. It is RFC 5214, it is already a
reason code in both in-house guards, and it is roughly a dozen lines.

### 8.1 Wrapper matrix **[implemented 2026-07-27]**

| Wrapper | Prefix | RFC | Source to port |
|---|---|---|---|
| v4-mapped | `::ffff:0:0/96` | 4291 | universal |
| v4-compatible | `::/96` (deprecated) | 4291 | in-house guard — keep the `tail32 > 1` carve-out so `::` and `::1` are not misread |
| v4-translated | `::ffff:0:0:0/96` | — | in-house guard (only implementation found anywhere) |
| 6to4 | `2002::/16` | 3056 | `ipaddress` has the extractor |
| Teredo | `2001::/32` | 4380 | Python's `(server, client)` with XOR-decoded client |
| NAT64 well-known | `64:ff9b::/96` | 6052 | in-house guard |
| NAT64 local-use | `64:ff9b:1::/48` | 8215 | in-house guard — **u-byte-aware** |
| NAT64 other PLs | /32 /40 /56 /64 | 6052 §2.2 | `ip-address` (JS) — the only implementation covering all six |
| 6to4 relay anycast | `192.88.99.0/24` | 3068 | classify only |
| ISATAP | `::0:5efe:a.b.c.d` | 5214 | nobody — write it |

RFC 6052 §2.2: at a /48 prefix the embedded IPv4 **straddles the reserved
u-byte**, so the octets are not contiguous. Port with tests rather than
rewriting.

**What was actually built, and the one column that turned out to be wrong.**
The extractor is a single table-driven pass over the geometry shipped in §7.2 —
there is no per-mechanism code and no partially correct version of reading a
geometry table, so the whole matrix landed together.

The "source to port" column is right about ISATAP (nobody implements it, so it
was written) and about the two in-house forms. It is wrong about NAT64. The
recommendation was to port `ip-address` (JS) *with its tests*, on the reasoning
that it is the only implementation covering all six lengths. **RFC 6052 ships
two tables of its own, and both grade the geometry harder than a port would:**

- **§2.3 is the extraction *algorithm***: for a /96 prefix take the last 32
  bits; otherwise delete the `u` octet to get a 120-bit string, then take the 32
  bits after the prefix. It is implemented independently in `test-embedding.R`
  and required to reproduce all six offset/length pairs. This is the check
  `docs/research/04` asks for — raddr does hard-code the six pairs, because the
  geometry is public data, so the algorithm grades the data.
- **§2.4 is a worked example table**: one address, `192.0.2.33`, embedded under
  six prefixes with the result printed. Reading the RFC's own output back at
  every length is the nearest thing to a vendor-supplied test vector.

Both traps are pinned as the wrong answer they produce rather than described:
`/64` read at bit 64 gives `0.192.0.2`, and `/48` read contiguously gives
`192.0.0.2`. A port would have inherited whichever of these `ip-address` got
right without proving either.

---

## 9. Corrections to `_scratch/SPEC.md`

Errors found during the 2026-07-26 review, recorded so they are not
reintroduced.

1. **§17's worked example is wrong.** It states `strict <NA> # inet_pton rejects
   the leading zero` for `0177.0.0.1`. Apple `inet_pton` returns `177.0.0.1`
   **[verified 2026-07-26]**. COMPETITORS §8 already recorded this; the spec
   contradicted its own evidence file.
2. **§8's `4294967296` row is wrong.** It says `malformed` +
   `ipv4-out-of-range`. `aton`, `getaddrinfo`, and `curl` all return `0.0.0.0`
   **[verified 2026-07-26]**.
3. **§4.1 welds two disagreeing dialects.** `addr_strict(x) — RFC 4291 /
   inet_pton only` treats the RFC grammar and libc `inet_pton` as one dialect.
   They disagree on the package's own headline example class.
4. **§16 item 12 is not a bug.** `rurl::get_host_type()` returns `NA` for every
   input because `url_standard` defaults to `NULL`, documented as "no
   classification, returns NA". A usability wart worth an issue on rurl; not a
   correctness bug and not a raddr blocker.
5. **§16 item 6 partly resolved.** The `getaddrinfo` = pton-then-aton
   composition is confirmed on macOS **[verified 2026-07-26, `AI_NUMERICHOST`]**.
   The `curl` = aton-then-pton composition is new and appears in none of the
   three scratch documents.
6. **`ipaddress` has no diagnostic layer to learn from.** Zero of its 66 exports
   match `valid|diag|warn|reason|status|error|parse`; it emits one warning per
   bad row (10,000 warnings for 10,000 bad rows) and is **silent** on
   `0177.0.0.1 -> 177.0.0.1` and `10.048.1.1 -> 10.48.1.1`
   **[verified 2026-07-26]**. It is loud about inputs that fail and silent about
   inputs where it changed which host you reach. Take its record layout,
   symmetric encoding pairs, and boundary-test helper; refuse its diagnostics.

---

## 10. Open items

Second-order. With O2 and O3 settled on 2026-07-26, **nothing here blocks the
API freeze**; the two that did are kept in the table with their resolutions so
the decisions are not relitigated.

| # | Item | Disposition |
|---|---|---|
| O1 | Pure R vs compiled | **Measured 2026-07-26, see §11.2.** The record meets both targets in pure R; the parsers miss the speed target by 18x and that is the pure R floor. Still v0.1-pure and v0.2-decidable, because the API does not change either way. Plain C, not Rcpp |
| O2 | Does `zone` participate in `==`? | **Settled 2026-07-26: no.** Equality over the 128 bits and family; `addr_zone()` queried separately. See §5.1.2 |
| O3 | Cross-family ordering | **Settled 2026-07-26: total order, v4 before v6**, with `v6_4in6` ranked as `v6`. See §5.1.2 |
| O4 | `stringi` vs base R for ASCII host tokenization | Benchmark base R first |
| O5 | Trie vs sorted masked vector for the 51 IANA rows plus the transition overlay | **Measured and closed 2026-07-28, see §11.1.6.** Neither, and not the walk either: grouping the blocks by prefix length — §11.1.5's containment trick, with `vec_match()` in place of `vec_in()` so the group reports *which* row — won every case and **shipped**, worth **36x** on the 276-row address-space table `addr_classify()` reads on every call. The sorted masked vector is *slower* than the walk on `special`; the trie pays to re-encode 1e6 addresses as bit strings on every call |
| O6 | glibc and musl `pton` rows | **Unverified.** Docker is installed locally. §3.3's `pton` column is Apple-only, and §3.5 raises the stakes: the IPv6 leading-zero rule, the fold and the lift are all Apple behaviors |
| O7 | IPv6 half of rust-url `host.rs` (~363–512) | **Read 2026-07-26.** §3.5.1 records what it settled: the WHATWG IPv6 tail is a separate, stricter grammar than the WHATWG IPv4 parser, and `%` is a rejection |
| O8 | RFC 5952 test vectors | **Closed 2026-07-27.** None published upstream; raddr's own are in `tests/testthat/test-format.R`, by RFC section (§5.1.3) |
| O9 | `hedgehog` 0.2 on R 4.6.0 aarch64 | **Settled 2026-07-29: yes, and it costs nothing.** Installs from a prebuilt `sonoma-arm64` binary, 180 KB, no compilation. Its entire dependency closure is `testthat` + `rlang (>= 0.1.6)`, both of which raddr already carries — so the §12 argument it needed to win, it wins by adding no transitive weight at all. `Suggests`, and §11.9's file skips whole when it is absent |
| O10 | WPT vendoring licence mechanics under CRAN | **Settled 2026-07-28, see §12.1.** BSD-3 is fine to bundle, but `LICENSE.note` was the wrong instrument: it appears in **zero** of the 266 packages installed locally, while `inst/COPYRIGHTS` appears in 10 — `fs` and `vroom` among them, which are the exact analogue. `License:` and `LICENSE` do not change, and cannot: measured against `tools:::.license_component_is_for_stub_and_ok`, **every** way of writing BSD-3 into `LICENSE` fails the MIT stub check. The hazard the survey turned up is that `inst/NOTICE` is **generated** — `build-registry.R` overwrites it wholesale, so a licence notice appended there is deleted by the next registry rebuild |
| O11 | Two bugs to file upstream on `davidchall/ipaddress` | (a) the NAT64 gap — one predicate plus one extractor; (b) the `0x80000000` equality bug of §5.1.1, reproducer `ip_address("0.0.0.128") == ip_address("0.0.0.128")` returning `NA`. Not an R bug — see §5.1.1. File both regardless of what raddr ships |
| O12 | `rurl::get_host_type()` NULL-default wart | File on rurl |
| O13 | The `curl` = aton-then-pton composition for **IPv6** | **Settled 2026-07-28 by running it, and the answer is no — see §11.6.** curl reaches **`getaddrinfo`**, not `inet_pton`, on all 88 IPv6 rows that can be asked through a URL at all; the derived half was wrong on the 10 rows where Apple's `getaddrinfo` lifts an embedded scope and `inet_pton` does not. The item's own premise was also wrong: the IPv4 composition had never been measured either — no `data-raw` script invoked curl before `RADD-xpmuxafb`, so §3.3's `curl` column was derived from the composition it was being used to support. Measured now, IPv4 holds on all 78 rows. `addr_curl()`'s fallback was corrected to `getaddrinfo` under `RADD-puzhycev` |
| O15 | **CPython bug to file:** `IPv6Address.exploded` and `.reverse_pointer` raise `AddressValueError` on any address with a `scope_id` | Reproducer: `ipaddress.IPv6Address("fe80::1%lo0").exploded`. Present on 3.9.6, 3.12.13 and 3.14.6 **[verified 2026-07-27]**. `_explode_shorthand_ip_string()` re-parses `str(self)` without splitting the scope. See §3.5.2; raddr's oracle dodges it by reading `.packed` |
| O16 | **`davidchall/ipaddress` bug to file (third):** the IPv6 zone ID is accepted and silently discarded | `ip_address("fe80::1%lo0")` is `fe80::1`, `ip_address("fe80::1%lo0%en0%wat")` is also `fe80::1`, and there is no accessor to recover the zone **[verified 2026-07-27, 1.0.3]**. Truncating at the first `%` also accepts two rows Apple's `inet_pton` rejects. Joins O11's list |
| O17 | **Why does the `raddr_parse` record cost more to build for IPv6 than for IPv4?** | 5.7 s against 2.5 s per 1e6 **[verified 2026-07-27, §11.1.1]**, which the flat-per-row theory does not explain. The suspicion, unmeasured, is `derive_status()`: for an IPv6 vector `aton`'s reading is missing on every row, so `readings_agree()` runs `vec_equal()` against an all-missing address and enters `blank_missing()`'s `proxy[is.na(code), ] <- NA` over a million rows and six columns — a path an all-accepted IPv4 vector never takes. If that is it, the fix is to skip dialects that accepted nothing, and it is small. Profile before touching anything |
| O18 | **`davidchall/ipaddress` bugs to file (fourth and fifth), both in `reverse_pointer()`** | **[verified 2026-07-28, 1.0.3]** (a) every IPv6 name ends in **`ip.arpa`**, not `ip6.arpa` — `reverse_pointer(ip_address("2001:db8::1"))` is one character short of RFC 3596 §2.5's suffix, and `ip.arpa` is not a registered `.arpa` sub-zone at all (research 08 gotcha 7), so every IPv6 answer the function has ever returned is a wrong name that looks right. (b) the IPv6 branch **accumulates**: element *k* of the result carries the labels of elements 1..*k*, so `reverse_pointer(ip_address(c("::1", "2001:db8::1")))[[2]]` has 64 labels. Cost is quadratic in vector length (§11.1.3). IPv4 is correct on both counts, modulo the trailing dot, which is a choice. Joins the O11/O16 list |
| O14 | Apple `getaddrinfo` truncates a numeric zone modulo 2^16 | `fe80::1%99999999999` reports scope 59391 **[verified 2026-07-26]**. raddr keeps the literal zone text and does not truncate, on the same grounds as everything else in §3.5.3. Harmless; recorded so it is not rediscovered |

---

## 11. Performance targets

Measured against `ipaddress` 1.0.3 on M-series, 1e6 rows. Speed target:
**within 3x** on every operation.

Memory target: **<= 30 MB per 1e6 addresses**, revised up from the draft's
25 MB, which was not reachable. The arithmetic, from §5.1's record:

| Component | per 1e6 |
|---|---|
| `w1`–`w4`, 4 x `integer` | 16 MB |
| `family` factor | 4 MB |
| `zone` character (pointers; all `NA` share one CHARSXP) | 8 MB |
| **total** | **~28 MB** |

### 11.1 Measured, 1e6 addresses **[verified 2026-07-26]**

`bench/record.R`, same machine as §0. Both targets are met by the pure R
record; nothing here argues for compiled code yet (O1).

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| memory, IPv4 | 26.7 MB | 19.1 MB | — | <= 30 MB |
| memory, IPv6 | 26.7 MB | — | — | <= 30 MB |
| memory, IPv6 + populated zone | 26.7 MB | — | — | <= 30 MB |
| `==` | 0.007 s | 0.004 s | 1.75x | <= 3x |
| `sort()` | 0.073 s | 0.052 s | 1.40x | <= 3x |
| `unique()` | 0.037 s | 0.017 s | 2.18x | <= 3x |

26.7 MB against the 28 MB estimate above, and it does not move when the zone is
populated: the field is a pointer vector, so distinct zone strings cost only the
CHARSXPs they share.

Getting `==` under target took work and the shape of that work is worth
recording. A first cut built both proxies as `data.frame()`s of five doubles and
measured **19x**, not 1.75x. Three changes closed the gap, none of them
algorithmic:

- **`vctrs::new_data_frame()` instead of `data.frame()`**, which skips name
  repair and row-name construction.
- **Equality proxies in `integer`, not `double`.** Equality needs distinctness,
  not magnitude, so it does not need the widening at all — it flattens each
  word's `0x80000000` rows to `0` and records them as a bit in a `pattern`
  column. Ordering still widens, because it does need magnitude.
- **Guarding the whole collision path on `anyNA()`.** In the common case, no
  word holds the pattern, so `pattern` is an allocated zero vector and not one
  word is copied.

The lesson generalizes to the parsers: at 1e6 rows the cost is allocation and
copying, not arithmetic.

### 11.1.1 `addr_parse()`, 1e6 addresses **[verified 2026-07-27]**

`bench/record.R`, best of seven runs after a warm-up, same as every other number
in §11.1.

| | one dialect | `addr_parse()` | ratio |
|---|---|---|---|
| IPv4 | 1.22 s | 9.53 s | **7.8x** |
| IPv6 | 3.92 s | 20.11 s | **5.1x** |
| mixed, every row rejected | — | 10.99 s | — |

`addr_parse()` runs four engines over one input, so **4x is the floor** and the
ratio is the number to read rather than the wall clock.

**Read the ratio, and read it loosely.** A second run of the same measurement
put IPv4 at 6.7x and IPv6 at 4.5x. The decomposition below is stable across both
runs; the totals are not, and no decimal place here is meaningful.

Decomposed against one dialect, so the parts are comparable across families:

| | IPv4 | IPv6 |
|---|---|---|
| four engines, codes off | 4.19x | 3.23x |
| \+ the reason codes | +0.41x | +0.13x |
| \+ the record | +2.07x | +1.17x |
| **`addr_parse()`** | **6.67x** | **4.53x** |

Three things fall out of that, and only the first was expected.

**The engines are at the floor, and IPv6 is below it.** Four engines cost four
parses, as they must. IPv6 comes in under 4x because `aton` has no IPv6 grammar
at all (§3.2), so the fourth engine sees a colon literal and bails without ever
reaching the arithmetic.

**The reason codes are close to free** — under half a second either way, well
under a tenth of the call. That is the mask design paying off: one integer per
row per dialect, unpacked over the *distinct* masks rather than row by row. It
is also the answer to whether Epic G should have been a separate opt-in pass. It
should not.

**The record is the expensive part, at roughly a third of the call**, and this
is the one that was measured wrong before it was measured right. The obvious
theory — that the record is a flat per-row price and therefore looms largest
where parsing is cheapest — is **false**: it costs 2.5 s on IPv4 and 5.7 s on
IPv6. The ratio is nonetheless worse for IPv4, because IPv4 parsing is four
times cheaper and the ratio's denominator is what moves. Both halves of that are
measured; the *mechanism* behind the IPv6 record cost is not, and is O17.

The last row of the first table is **not comparable to the two above it** — its
corpus mixes IPv4 and IPv6 literals, so it sits between the families for reasons
that have nothing to do with rejection. It is recorded only to show that
rejecting a million literals with codes attached stays in the same range as
accepting them.

**A caution, because it already cost a wrong number once.** A first pass
measured this with a single `system.time()` per expression and reported 4.2x for
IPv4. The error was in the *baseline*: one dialect over clean dotted quads takes
about a second, so a single noisy sample inflates it and flatters the ratio.
Anything divided by a sub-second measurement needs `bench/record.R`'s
best-of-seven, not one shot.

### 11.1.2 Encoding round-trips, 1e6 addresses **[verified 2026-07-28]**

`bench/record.R`, best of seven after a warm-up. Twelve operations, and
`ipaddress` implements all twelve in C++, so this is the one part of the package
where every number has a like-for-like baseline.

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_to_bytes()`, IPv4 | 0.177 s | 0.047 s | **3.77x** | <= 3x |
| `addr_to_bytes()`, IPv6 | 0.197 s | 0.049 s | **4.02x** | <= 3x |
| `addr_to_hex()`, IPv4 | 0.275 s | 0.229 s | 1.20x | <= 3x |
| `addr_to_hex()`, IPv6 | 0.903 s | 0.427 s | 2.12x | <= 3x |
| `addr_to_binary()`, IPv4 | 0.524 s | 0.261 s | 2.01x | <= 3x |
| `addr_to_binary()`, IPv6 | 1.238 s | 0.418 s | 2.96x | <= 3x |
| `bytes_to_addr()`, IPv4 | 0.360 s | 0.503 s | **0.72x** | <= 3x |
| `bytes_to_addr()`, IPv6 | 0.464 s | 0.507 s | **0.92x** | <= 3x |
| `hex_to_addr()`, IPv4 | 0.330 s | 0.136 s | 2.43x | <= 3x |
| `hex_to_addr()`, IPv6 | 0.792 s | 0.300 s | 2.64x | <= 3x |
| `binary_to_addr()`, IPv4 | 0.313 s | 0.071 s | **4.41x** | <= 3x |
| `binary_to_addr()`, IPv6 | 0.797 s | 0.191 s | **4.17x** | <= 3x |

Eight of twelve meet the target, two beat the C++ baseline outright, and four
miss. Three things are worth recording.

**The `list_of<raw>` shape is the cost, and it is symmetric.** `addr_to_bytes()`
is the worst ratio in the table and `bytes_to_addr()` is the best — the only
operation anywhere in raddr that is *faster* than `ipaddress`. Both facts have
one cause. A million small raw vectors is a million R allocations, and reading
them back is a million R-level element visits that a C++ implementation cannot
skip either. `ipaddress` pays that cost only on the way in, where raddr pays it
on the way out; on the way in the two are level and raddr's arithmetic-over-a-
matrix decode wins. Nothing about the 0.72x is cleverness, and nothing about the
3.77x is a defect in the encoder — it is the same allocation bound seen twice.

Two rewrites of `addr_to_bytes()` were measured before this number was accepted.
The obvious one — `as.raw()` once per address — runs at 0.95 s, five times
slower than the `vec_chop()` of one flat vector that shipped. §11.1's lesson
holds a third time: at 1e6 rows the cost is allocation, not arithmetic.

**`binary_to_addr()` is the one real miss**, and it is regex-bound rather than
allocation-bound. The validity scan is the single largest line item in either
string decoder, and it cannot be skipped: `strtoi()` returns `NA` for a digit
outside its base, which is most of a validity check, but it also *accepts*
leading whitespace, a sign and a `0x` prefix, so `"0x0000c0"` would decode to a
real address instead of to `NA`. The scan is what makes the width check mean
what it says. Moving it from the TRE default to `perl = TRUE` took it from
0.99 s to 0.13 s on 1e6 rows of 128 characters — a 7x win from one argument, and
without it the decoders were at 13x rather than 4x. What remains is PCRE plus
`strtoi()`, and closing the rest would mean a hand-rolled character-code decoder
whose fast path is exactly the kind of "tiny edge case" this package exists to
get right. Not worth it in pure R; it is O1's problem.

**`addr_to_binary()`, IPv6 passes at 2.96x, which is not a pass to rely on.**
It is inside the target by four hundredths and will read differently on another
machine. Treat it as a fourth miss when deciding whether §8's deferred compiled
path is worth building.

Nothing here changes the v0.1 decision. §8 defers `src/` with the API frozen,
and four operations at 4x on a pure-R implementation of a C++ baseline is the
same evidence §11.2 already records, one epic later and an order of magnitude
smaller.

### 11.1.3 Reverse pointers, 1e6 addresses **[verified 2026-07-28]**

`bench/record.R`, best of seven after a warm-up.

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_reverse_pointer()`, IPv4 | 0.737 s | 0.400 s | 1.84x | <= 3x |
| `addr_reverse_pointer()`, IPv6 | 1.674 s | — | — | <= 3x |

IPv4 meets the target against a C++ baseline. **The IPv6 row has no baseline,
and the reason is O18**: `ipaddress` 1.0.3 accumulates its IPv6 output across
the vector, so the run cannot finish at 1e6. Measured on this machine
**[verified 2026-07-28]**, best of three:

| n | `ipaddress` | raddr |
|---|---|---|
| 2 500 | 0.181 s | 0.003 s |
| 5 000 | 0.904 s | 0.005 s |
| 10 000 | 3.093 s | 0.010 s |

Doubling the input multiplies their time by 5.0 and then by 3.4, which brackets
the 4x of a quadratic; raddr's doubles. Extrapolating their curve to 1e6 is
about eight hours, and the last element alone would be a 64 MB string, so this
is not a slow baseline — it is one that does not terminate. The 13.2 s measured
at n = 20 000 was where the comparison was abandoned.

The IPv6 number is 2.3x the IPv4 one for 8x the labels, which is the shape the
implementation predicts: the 256-entry table renders each octet as *both* its
nibble labels, so the assembling `paste()` takes 16 pieces rather than 32 and
the per-address work is one table lookup per octet either way.

### 11.1.4 The integer pair, 1e6 addresses **[verified 2026-07-28]**

`bench/record.R`, best of seven after a warm-up. `ipaddress` returns a
`biginteger` where raddr returns a character vector, so the forward direction is
measured twice: the default, and the one that builds the same type they do.

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_to_integer()`, IPv4 | 0.306 s | 1.442 s | **0.21x** | <= 3x |
| `addr_to_integer(output = "bignum")`, IPv4 | 1.063 s | 1.442 s | **0.74x** | <= 3x |
| `integer_to_addr()`, IPv4 | 0.703 s | 1.112 s | **0.63x** | <= 3x |
| `addr_to_integer()`, IPv6 | 3.906 s | 1.726 s | 2.26x | <= 3x |
| `addr_to_integer(output = "bignum")`, IPv6 | 5.038 s | 1.726 s | 2.92x | <= 3x |
| `integer_to_addr()`, IPv6 | 4.220 s | 1.426 s | 2.96x | <= 3x |

All six meet the target and **three beat the C++ baseline outright**, which is
the same shape as §11.1.2's `bytes_to_addr()` result and has the same cause: the
comparison is not only arithmetic. `ipaddress` must construct a `biginteger` on
every row whatever the family, so for IPv4 it pays 128-bit machinery for a
32-bit value while raddr pays one `sprintf()`. Our own `output = "bignum"` row
is the price of that construction, measured: 0.76 s of the 1.063 s is
`biginteger()` itself.

**The 15-digit fast path is worth 4x on the IPv4 decode.** Before it, every row
went through seven chunked multiplications regardless of magnitude and the IPv4
decode ran at 2.747 s, a 2.38x ratio; routing values under 2^50 through
`as.numeric()` took it to 0.703 s. §11.1's lesson inverted for once — here the
cost really was arithmetic, because the allocation is one string vector either
way.

**The two IPv6 rows at 2.92x and 2.96x are inside by a hair.** Run-to-run
variance on this machine is around 10%, so treat them the way §11.1.2 treats its
own 2.96x: passing today, and evidence for §8's deferred compiled path rather
than against it.

### 11.1.5 Containment, 1e6 addresses x 200 blocks **[verified 2026-07-28]**

`bench/record.R`, best of five. The target `RADD-ehyllbox` states is 3x, and
this is the operation the target was written for.

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_within_any()`, IPv4, 200 blocks / 25 lengths | 0.677 s | 0.706 s | **0.96x** | <= 3x |
| `addr_within_any()`, IPv6, 200 blocks / 8 lengths | 0.236 s | 0.995 s | **0.24x** | <= 3x |
| `addr_within()`, IPv4, one block | 0.065 s | — | — | |

Both meet it and the IPv6 row beats the C++ baseline by **4.2x**, which is a
statement about the algorithm rather than about R. `ipaddress::is_within_any()`
walks the block list; `addr_within_any()` groups the blocks by prefix length,
because every block of the same length reduces its addresses to the same key and
membership is then one hash lookup. So the pass count is the number of
**distinct lengths**, not the number of blocks — 25 and 8 above, against 200 of
each — and it cannot exceed 32 for IPv4 or 128 for IPv6 however long the
denylist grows. That is why the IPv6 row is the faster of the two despite moving
four times the words: its eight lengths are eight passes. The gap widens with
the list, and the row-walk `prefix_match()` uses is right for the registry,
which asks *which* block, and wrong for a denylist, which asks only whether any
of them.

**That last sentence was wrong, and §11.1.6 corrects it two days later.** The
walk is not right for the registry either: a length group can report *which*
row as easily as *whether* one matched, by returning `vec_match()`'s position
in place of `vec_in()`'s logical, and visiting the groups longest-first keeps
the first hit the longest one. `prefix_match()` now groups too, and the
address-space table got **36x** out of it. What this section measured is
unaffected — only its closing claim about the neighbouring function was.

`bench/record.R` reports a disagreement count against `ipaddress` beside each
ratio, on all 1e6 rows of both families, because a ratio between two functions
that answer differently is not a measurement of anything. Both are **0**.

### 11.1.6 Longest-prefix-match, 1e6 addresses — O5 settled, and `prefix_match()` regrouped
**[verified 2026-07-28]**

`bench/prefix.R`, best of five. O5 asked whether the registry lookup wants a
trie or a sorted masked vector instead of `prefix_match()`'s walk over blocks
sorted by descending prefix length. The answer is **neither**, and it is not the
walk either: the regrouping §11.1.5 built for containment answers
longest-prefix-match too. It won every case measured, so it shipped, and the
`prefix_match()` column is what the package now does.

| | walk (replaced) | grouped | sorted masked | trie (`triebeard`) | **`prefix_match()`** |
|---|---|---|---|---|---|
| `special`, IPv4 random | 0.292 s | 0.177 s | 0.549 s (1.88x) | 0.742 s (2.54x) | **0.191 s (0.65x)** |
| `special`, IPv6 random | 0.286 s | 0.206 s | 0.837 s (2.93x) | 1.530 s (5.35x) | **0.222 s (0.78x)** |
| `special`, IPv4 inside blocks | 0.325 s | 0.161 s | 0.520 s (1.60x) | 0.492 s (1.51x) | **0.180 s (0.55x)** |
| `special`, IPv6 inside blocks | 0.364 s | 0.202 s | 0.700 s (1.92x) | 1.532 s (4.21x) | **0.230 s (0.63x)** |
| `space`, IPv4 random | 1.601 s | 0.030 s | 0.469 s (0.29x) | 0.769 s (0.48x) | **0.044 s (0.027x)** |
| `space`, IPv6 random | 0.789 s | 0.150 s | 0.588 s (0.75x) | 1.477 s (1.87x) | **0.172 s (0.22x)** |

Ratios are against the walk. `grouped` is the bare algorithm reading a shared
view of the addresses; `prefix_match()` is that plus the per-call setup every
caller pays — widening four words and deriving the space mask — which is the
0.014 s to 0.026 s between the two columns and does not vary with the table.

Index build is once per table and irrelevant at this size: every candidate is
between 0.04 ms and 0.92 ms, the whole spread smaller than one lookup's noise.

**The `space` row is the finding.** It is the address-space pair of §7.3, and
`addr_classify()` reads it on every call beside `special`. Its 276 rows collapse
to **9** groups, because its 256 IPv4 rows are all `/8` and every block of one
length costs one hash lookup — so 256 passes over a million-row logical vector
become one, and the operation goes from 1.601 s to 0.044 s. **36x.** The 51-row
`special` table collapses 51 to 20 and wins a more ordinary 1.3x to 1.8x.

What makes the regrouping answer *which* block rather than only whether one
exists is that `vec_match()` returns the position of the hit where `vec_in()`
returns a logical. Visiting the groups longest-first then keeps the same
first-hit-wins rule the walk had, because anything matched later is shorter by
construction. Ties resolve identically on both sides, which is why the swap is
answer-preserving and not merely answer-compatible: `order(decreasing = TRUE)`
is stable and `split()` keeps each group ascending, so two blocks with the same
length and the same key both resolve to the earlier table row.

The two rejected candidates lose for reasons worth keeping:

- **Sorted masked vector** is 1.6x to 2.9x *slower* than the walk it was meant
  to replace on `special`. A binary search is `log2(m)` passes over the address
  vector where the hash is one, and `m` here is at most 256 — eight passes to
  save what one `match()` already does in C. Vectorized binary search in R pays
  an n-sized `ifelse()` on every step, which is the whole cost.
- **The trie** is the only candidate that cannot read the words. `triebeard`
  wants character keys, so every call re-encodes 1e6 addresses into 1e6 binary
  strings — 32 characters each for IPv4 and 128 for IPv6, which is why its IPv6
  rows are its worst. That encoding is inside the timed region deliberately: it
  is not overhead the design could amortize, it is what the data structure
  costs. O5's guess that it would be neither a trie nor `triebeard` was right,
  for a reason O5 did not name.

`bench/prefix.R` gates its timings on an agreement check, as `bench/record.R`
does: every candidate against the shipped `prefix_match()` over 6e6 random rows
**and** over the first and last address of every block in all four tables (680
rows — a random draw lands in the middle of a block and says nothing about a
divisor that is off by one). All 40 counts are **0**. The walk is kept in the
file rather than deleted with the shipped copy, because a benchmark that
measured the shipped function against itself would report 1.00x forever.

The block-edge half of that check is also a test, `test-classify.R`, where the
oracle is not the old walk but an independent matcher that decides containment
by **string prefix** — `startsWith()` over `addr_to_binary()` — and so shares
nothing with `prefix_match()` except the encoder. A wrong divisor surfaces there
as a disagreement rather than as the same wrong answer computed twice. That
matcher now lives in `helper-slow.R` with the rest of the naive second
implementations (§11.3), which it was the worked example for.

### 11.2 Parsing misses the speed target, and that is the O1 evidence
**[verified 2026-07-26]**

The record meets both targets. **Parsing does not, and not by a little.**

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_whatwg()`, canonical dotted quads | 1.11 s | 0.06 s | **18x** | <= 3x |
| `addr_strict()` | 1.23 s | — | — | |
| `addr_aton()` | 1.57 s | — | — | |
| `addr_curl()` | 1.58 s | — | — | |
| `addr_whatwg()`, nothing canonical | 1.64 s | — | — | |

**IPv6 is worse, and for the same reason [verified 2026-07-26, Epic D]:**

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_strict()`, IPv6 | 5.64 s | 0.12 s | **41x** | <= 3x |
| `addr_pton()`, IPv6 | 5.34 s | — | — | |
| `addr_pton()`, IPv6 with a zone | 4.67 s | — | — | |
| `addr_strict()`, dotted-quad tail | 7.04 s | 0.09 s | **78x** | <= 3x |

**Rendering, by contrast, is close to target [verified 2026-07-27, Epic E]:**

| | raddr | `ipaddress` | ratio | target |
|---|---|---|---|---|
| `addr_format()`, IPv4 | 0.41 s | 0.36 s | **1.1x** | <= 3x |
| `addr_format()`, IPv6 | 2.30 s | 0.30 s | **7.5x** | <= 3x |
| `addr_format()`, IPv6 dense (no zero run) | 2.28 s | — | — | |
| `addr_format()`, 4-in-6 | 2.36 s | — | — | |
| `addr_expand()`, IPv6 | 1.29 s | — | — | |

Worth recording because it is the *asymmetry* that is informative, not the
numbers. Rendering is 5x cheaper than parsing on the same values and lands
within target for IPv4, on the same interpreter, with no compiled code — and
the renderer was written straightforwardly, with none of the tuning §11.2
describes. The difference is that rendering knows the shape of its work in
advance: eight fields, always, so every step is a whole-matrix operation with
no ragged case. Parsing does not know how many pieces it has until it looks.
The cost of pure R is paid on **irregularity**, not on volume, and that is a
sharper reading of O1 than "string work is slow".

The three timings inside the IPv6 row are flat to within noise, which is the
answer to the obvious worry: the zero-run search is eight vectorized steps
whether or not there is a run to find, and the mixed form costs a `paste()`
column, not a branch.

Three changes took the plain case from 7.0 s and the dotted tail from 13.0 s,
and all three are the same lesson as §11.1 — do not touch a vector you do not
have to:

- **The dotted-quad tail is stood down to the constant `"0:0"`** and its value
  carried alongside, rather than rendered back into hex text. A tail is always
  the final piece, so it always lands in the last two groups and can be written
  there after the fact. The `sprintf()` it replaces cost more than the entire
  rest of the parse.
- **The IPv4 engine skips colon-bearing rows** unless the rule set is the one
  that could still accept them (`aton`, via its stop-at-whitespace quirk). Every
  IPv6 literal used to be fully parsed as IPv4 and rejected first.
- **The leading-zero strip and the malformed-piece path are both guarded**, so
  the common case runs neither over the 8n hextets.

What is left is spread across `paste0()`, `grepl()`, `strsplit()` and `substr()`
with no single hot spot above 17% — the same shape, and the same conclusion, as
the IPv4 result below. IPv6 is worse than IPv4 because there is simply more
string work per row: eight groups to validate instead of four parts, plus the
elision arithmetic. It strengthens rather than changes the O1 reading.

That is after tuning took it from 2.9 s, a 2.6x improvement, via:

- a **fast path for plain decimal parts** — a digit run with no leading zero
  means the same thing in every dialect and is almost all real input, so it goes
  through `as.numeric()` and skips the digit-at-a-time loop;
- **scatter-add over the four part positions** instead of `rowsum()`, which
  costs several times as much for groups this small;
- `grepl("[^0-9]", perl = TRUE)` over an anchored alternation, and
  `endsWith()` + `substr()` over `sub()`.

What is left is spread thin — `strsplit()`, one `grepl()`, one `as.numeric()`,
and a long tail of vector operations over four million parts. There is no
remaining hot spot to remove, which is the point: **18x is the pure R floor for
this shape of work, not a coding defect.**

This is the concrete evidence O1 was waiting for, and it splits the question
rather than settling it:

- The **record** is fine in pure R. Storage, equality, ordering and hashing all
  meet target with room to spare, so `src/` buys nothing there.
- The **parsers** are the case for compiled code, and they are also the case
  that was always going to be. Splitting and scanning a million strings a
  character at a time is what C is for.

The API does not change either way (§8), so this stays a v0.2 decision made on
its own schedule. Recorded here so it is decided on measurements rather than
re-argued from first principles. Plain C, not Rcpp.

`ipaddress`'s 19.1 MB is not a like-for-like comparison: it has no `zone` field
and encodes family as a single `logical`. An R `logical` and a factor are both
4 bytes per element, so `family` is not where the difference lies: the whole
gap is the `zone` field
§5.1 argues for, and
 the `0x80000000` correctness fix (§5.1.1) is free at rest —
it widens only the transient comparison proxy.

Within 3x on speed is deliberate. raddr does strictly more work — four primitives,
per-dialect code collection, embedded-address extraction — and correctness is
the product. Pure R landing within 3x of a C++ package is a good trade.

Vectorize aggressively: one pass over the character vector returning all fields
at once, never per-element. Use arithmetic (`2^(8*n)`), not `bitwShiftL` —
R integers are signed 32-bit and shifting past 2^31 is a trap.

### 11.3 The naive second implementations **[implemented 2026-07-28]**

Every optimization in §11.1 and §11.2 buys speed with machinery, and each piece
of machinery is a place an off-by-one can hide and still look plausible. The
digit run truncated to the trailing digits the modulus preserves; the flat pass
over 8n hextets; the scatter-add over four part positions; the zero run found by
a backwards recursion over a matrix and blanked rather than removed — none of
those reads like what it computes, which is exactly why they are fast.

So `tests/testthat/helper-slow.R` computes the same answers a second time,
badly. One address at a time, one character at a time, no vectorization, no
fast paths, no tables indexed by character code. It covers the two parsers, both
compositions, and both renderers, and it is the same pattern Go keeps beside
`net/netip`'s fast parser.

The two sides share the **specification** and nothing else. The rule sets in
`helper-slow.R` restate §3 rather than reading `rules_strict` and friends, and
the renderer restates RFC 5952 rather than calling `render_canonical()`. A rule
written down twice is checked; a rule read from one place by both sides is not.
The comparison surface is text on both sides — a fixed-width hex string, a
family and a zone, which describes a `raddr_address` completely while reaching
none of its constructors.

`tests/testthat/test-slow.R` runs both over the 2139 literals of
`helper-corpus.R`: the oracle fixtures, the boundaries an argument is about —
every per-part bound from both sides, the elision in every illegal quantity,
`fe80::/10` at both ends — and 1800 generated spellings, half of them valid by
construction so the agreement cannot be vacuous. The renderers get 1175
addresses, most of them zero-heavy, because RFC 5952 §4.2 is entirely about runs
of zero fields and a uniform draw almost never produces one.

The corpus is in a helper rather than in this test file because §11.4 runs over
it too, and a second corpus would have made the weaker of the two answers
quietly weaker still.

**What it caught, measured by breaking the shipped code on purpose.** Nine
mutations, each a plausible slip, run against the corpus:

| mutation | disagreements |
|---|---|
| `ipv4_final_bounds`: last part off by one | 94 |
| `ipv4_weights`: the short form off by a byte | 2504 |
| `ipv4_mod_digits`: decimal 32 → 16 | 15 |
| `ipv4_digit_values`: hex alphabet off by one | 130 |
| RFC 5952 §4.2.3: tie-break the last equal run | 25 |
| RFC 5952 §4.2.2: compress a single zero field | 206 |
| `ipv6_pieces`: group count off by one | 6017 |
| `format_v4`: octet shift off by a byte | 455 |
| `addr_hextets`: high and low half swapped | 7040 |

All nine caught. A tenth — `ipv4_max_digits` for decimal widened from 10 to 11
— is **not** caught, and should not be: an eleven-digit decimal is at least
10^10, so the modular accumulation flags it as an overflow whether or not the
width did. That is an equivalent mutant, and its surviving is a statement about
the shipped code rather than about the corpus.

Two of the nine were missed on the first attempt, and both were gaps in the
corpus rather than in the second implementation: nothing exercised a bound on
the *final* part (`1.2.3.256`, not `256.1.1.1`), and no address had a single
zero field to decline to compress (`2001:db8:0:1:1:1:1:1`). Both are now in the
boundary literals, which is the argument for measuring a test suite this way
rather than trusting that a corpus is broad because it is long.

`block_edges()` and `slow_prefix_match()` — the string-prefix matcher §11.1.6
built for the registry lookup — moved here from `test-classify.R`, since they
are the same idea and were the worked example the rest was generalized from.
`slow_bits_step()` and `block_probes()` joined them for §11.5, and are the same
idea again applied to a block rather than to a literal: a block's geometry
written out as characters, sharing no divisor with the code that matches it.

### 11.4 The invariant suite **[implemented 2026-07-28]**

§11.3 checks one surface against a second implementation of the same
specification. `tests/testthat/test-invariants.R` checks **two surfaces against
each other**, which needs no second implementation and no oracle: it states a
relationship the package is supposed to keep, and it fails when either side
drifts. That is the class of breakage the per-function files structurally cannot
see, because each of them only ever looks at one surface.

| property | the two surfaces |
|---|---|
| the four encodings decode to one address | base-10^6 arithmetic vs three octet readers (§6.5) |
| ordering agrees with ordering the integers | `vec_proxy_compare()` by word vs the integer encoder |
| an address integer never exceeds 39 digits | the encoder vs the ceiling its decoder rejects above |
| a pointer name has the label count its tree fixes | the name vs the family (§6.2.1) |
| `parse(format(x)) == x`, family and zone included | the renderer vs the parser (§5.1.3) |
| canonicalization is a fixed point | the renderer against itself |
| `addr_parse()` is total | the record vs its own input (P2) |
| `rejected` carries codes and `not_an_address` does not | `outcome` vs `codes`, in both directions (§5.2.1) |
| `status` is a function of the four outcomes | the derived status vs the columns it derives from |
| the record's readings are the standalone parsers' | `addr_reading()` vs the six exported parsers (§3.2) |
| classification never errors on a parser output | `addr_classify()` vs every reading of the hostile corpus |
| every wrapper gives back the address it embeds | the extractor vs the RFCs' own spellings (§8.1) |
| every address matches exactly one registry row | `prefix_match()`'s grouped keys vs `addr_within()` (§5.3) |
| comparison is antisymmetric and total | `vec_compare()` against itself (§5.1.2) |
| the zone stays out of `==` and out of the order | O2, restated as a property |

Two corpora, because the questions differ. Properties *of addresses* run over
400 random draws of both widths plus the literals that are hazards in their own
right; properties *of parsing* run over §11.3's 2139 hostile literals, since a
parser is only interestingly total on input nobody meant it to read. The
registry property adds one address from every special-purpose block, so all 51
rows are reached rather than only the ones a uniform draw lands in.

Both corpora are **frozen** — one seed, drawn once. §11.9 asserts the same kind
of claim over a generator instead, which is what buys the shrunk counterexample
and the one axiom a flat corpus cannot state at all.

**The wrapper round-trip builds its own wrappers, from the RFCs rather than from
`raddr_transition_prefixes`.** A builder sharing the geometry table with the
extractor round-trips through its own mistakes and reports agreement — so each
wrapper is spelled the way its RFC spells it, including the /48 NAT64 case where
RFC 6052 §2.2's reserved u octet splits the embedded address into two pairs of
octets. Where §8.1's named examples pin the geometry against RFC 6052 §2.4's
table, this quantifies over the **value**, which is where the two patterns that
break bit-twiddling live: `0x80000000` is `NA_integer_` in a word (§5.1.1), and
`0xffffffff` is the one value Teredo's complement sends to zero. The deprecated
v4-compatible form is quantified over the values *above* 1, and its carve-out is
asserted as the separate fact it is: `::` and `::1` embed nothing, because
reading them as `0.0.0.0` and `0.0.0.1` would lose the unspecified and loopback
addresses.

**One thing it found, and it is not a bug.** The record and the standalone
parsers spell a *missing* address two different ways: `addr_parse()` blanks all
four words when the `getaddrinfo` whitespace rule refuses a literal, while
`addr_getaddrinfo()` hands back whatever `pton` left behind. §5.1.1 puts
missingness in `family` and makes the words meaningless once it is set, and
every public surface — `==`, `unique()`, `vec_match()`, `format()`, all four
encoders — reads both as the same missing address. So the invariant is asserted
over the address, not over the bytes, and the difference is recorded here rather
than normalized away in code that has no observable reason to change.

### 11.5 The block boundaries **[implemented 2026-07-28]**

§11.4's registry property says every address matches exactly one row and that
the address-space layer partitions each family's space. Both stay true of a
block that is **one address too wide**. Totality is a statement about coverage
and says nothing about where a block stops, which is the only place prefix
arithmetic is ever wrong.

`tests/testthat/test-boundary.R` gives every block of all four tables six probe
addresses — 340 blocks, 2040 addresses:

| probe | where it is | what it pins |
|---|---|---|
| `start`, `end` | the block's two ends | the block reaches its own edges |
| `below`, `above` | one address outside each end | it reaches no further |
| `middle` | the first address of the upper half | a proper subnet is inside it |
| `sibling` | the other half of the supernet | one bit of prefix is a real difference |

**The probes are built from the block's text, in binary, and that is the whole
design.** `block_edges()` derives an edge from the stored words using the same
`pmin(pmax(len - 32 * (k - 1), 0), 32)` step `mask_words()` uses to decide
containment — copied, line for line. A wrong step there moves the edge and the
matcher's idea of the block *together*, and the two agree about the wrong block.
So `block_probes()` truncates the base address to `len` characters and pads it
out, and a neighbour is a ripple carry over the same string: no divisor, no
word, and no arithmetic the shipped code also does. Agreement is the null
result, and two copies of one formula cannot produce it.

`block_edges()` is then checked against that construction rather than trusted,
which hardens §11.1.6's 340-block matcher agreement too — that test stands on
the same primitive.

**The escape hatch, because blocks abut.** The natural expectation is that the
address past the end of a registry block is outside the registry. It is false
for **20 of the 51** special-purpose blocks, and ten of those are followed
*immediately* by another block:

| block | its successor's block |
|---|---|
| `192.0.0.0/29` | `192.0.0.8/32` |
| `192.0.0.8/32` | `192.0.0.9/32` |
| `192.0.0.9/32` | `192.0.0.10/32` |
| `192.0.0.170/32` | `192.0.0.171/32` |
| `::/128` | `::1/128` |
| `100::/64` | `100:0:0:1::/64` |
| `2001:1::1/128` | `2001:1::2/128` |
| `2001:1::2/128` | `2001:1::3/128` |
| `2001:10::/28` | `2001:20::/28` |
| `2001:20::/28` | `2001:30::/28` |

So contiguity is **computed from the table** and the pairs are pinned, rather
than a list of blocks hand-excused from a rule that was wrong for them. The
sound assertion is not "the neighbour matches nothing"; it is "the neighbour
never matches *this* block", which holds regardless of what else is next door.

The address-space pair is the opposite case and the same test says so: it is a
partition, so every one of its blocks that has a successor at all — 274 of 276 —
is followed immediately by another. That is gaplessness read off the boundary,
where §7.3's partition check reads it off the tiling arithmetic.

**Four blocks have no neighbour on one side**, and they are pinned by name for a
reason: a `+1` that wrapped around instead of answering `NA` would leave every
neighbour assertion passing about the wrong address, at exactly the four places
the arithmetic is hardest. They are `0.0.0.0/8`, `0.0.0.0/32` and `::/128` at
the bottom, `240.0.0.0/4` and `255.255.255.255/32` at the top of the
special-purpose pair; `0.0.0.0/8`, `::/8`, `255.0.0.0/8` and `ff00::/8` in the
address-space pair; and `::/96` in the overlay.

**§7.4's five hand-picked addresses, quantified.** That section's argument is
that `192.0.0.0/29` is `.0` through `.7` while `.8`, `.9`, `.10`, `.170` and
`.171` each carry their own policy, so an off-by-one silently swaps five
protocols' semantics — silently, because every one of those addresses still
classifies to something well formed. The boundary suite runs that question over
all 51 blocks through `addr_classify()`: at an edge the record names this block
or one nested inside it and always answers from the policy layer; just outside,
it never names this block.

**What it caught, measured the same way §11.3 was.** Five mutations, each a slip
someone could make, run against this file alone:

| mutation | tests failed |
|---|---|
| `mask_words`: one bit of prefix ignored | 6 of 11 |
| `prefix_word_plan`: match key one bit too short | 7 of 11 |
| `build_prefix_index`: shortest prefix wins | 3 of 11 |
| `block_edges`: last address off by one | 1 of 11 |
| `slow_bits_step`: wraps instead of answering `NA` | 2 of 11 |

All five caught, and the last two by the tests written for them specifically.

One measurement caveat worth recording, because anyone repeating this will hit
it: `prefix_index()` **memoizes**, so a mutation underneath it is invisible until
`prefix_index_cache` is emptied. The `build_prefix_index` reversal read as a
missed mutant on the first run for that reason alone. A mutation campaign
against memoized code measures the cache unless it clears it.

---

### 11.6 The ahead-of-time oracles **[implemented 2026-07-28]**

Differential testing, never at runtime. Each oracle runs in `data-raw/` on a
maintainer's machine, writes a golden CSV, and the suite reads the CSV — so the
tests need no Go toolchain, no `adaR`, and no curl, and a CRAN check machine
without them still runs every assertion.

| Oracle | Measures | Written by |
|---|---|---|
| Apple libc | `pton`, `aton`, `getaddrinfo`, the scope lift | `oracle-ipv{4,6}.py` |
| CPython `ipaddress` | the `strict` dialect, on paper | `oracle-ipv6.py` |
| ada, via `adaR` | the `whatwg` dialect, as browsers ship it | `oracle-ipv{4,6}.R` |
| **Go `net/netip`** | `strict` again, a second implementation | `oracle-netip.go` |
| **real curl** | the one dialect raddr composes rather than reads | `oracle-tools.R` |

The last two are new, and each falsified something.

**Go `netip` — §3.1's grouping is not quite one dialect.** The table files
Python, Go and Rust together under `strict`. On 125 of the 126 recorded IPv6
literals Go and Python agree exactly, address and zone. The exception is
`fe80::1%lo0%en0`: Go splits at the **first** `%` and takes the entire remainder
as the zone, yielding `lo0%en0`, where Python rejects the literal. raddr sides
with Python. One row is not a refutation of the grouping, but it is the
difference between a grouping that was checked and one that was assumed.

**curl — see §3.2.** The IPv4 ordering holds on every measurable row; the IPv6
ordering was wrong, and `RADD-puzhycev` swapped the fallback from `pton` to
`getaddrinfo`.

**Measuring curl means measuring curl's resolver, and that is easy to get
wrong.** Two traps were hit and are worth recording, because both produced
confident, wrong numbers:

- **`curl_parse_url()` is the wrong layer.** It answers about curl's *URL*
  parser. `addr_curl()` models the resolver. Comparing them measures neither.
- **Blocking DNS changes the answer.** `--doh-url` pointed at a dead port looks
  like the careful way to keep an oracle offline. It removes `getaddrinfo`, and
  `getaddrinfo` *is* curl's leniency: under it curl appears to reject
  `4294967296`, `0X7F000001`, `0x.1` and `040000000000`, and §3.2's composition
  appears to fail on 11 IPv4 rows. All 11 were the instrument. There is no
  verbose output that separates "read numerically" from "resolved as a name"
  either, because in curl they are one `getaddrinfo` call.

So the probe lets DNS work and **checks the resolver is honest instead**: a
random `.invalid` label (RFC 2606) must not resolve, or the run aborts. A
resolver that hijacks NXDOMAIN would otherwise turn every rejection into a
fabricated address, silently. A literal is asked through a URL, so anything the
URL layer would eat first — whitespace, `%` zones, the authority delimiters — is
recorded as **not measurable** rather than as a result raddr should match, which
is the same caveat the `adaR` probes carry.

**A NUL-delimited wire, so no escaping grammar is agreed twice.** The fixtures
escape control characters to stay plain ASCII, and `unescape_control()` is
sequential rather than single-pass. Reimplementing that in Go would be a second
thing to get wrong, so R unescapes and hands over raw bytes with a delimiter no
literal contains. R cannot hold a NUL inside a string, which is why the reply is
split as a raw vector.

### 11.7 The WPT URL host corpus **[implemented 2026-07-29]**

`url/resources/urltestdata.json` from `web-platform-tests`, pinned at commit
`181476a` — 891 objects, 624 success / 267 failure, `sha256:355c9f1e…`, 228 373
bytes. The pin is a **commit** with the sha256 of the bytes it served recorded
beside it, because the two fail differently: a moved branch changes the first, a
truncated download only the second.

The suite reads a **derived CSV**, not the JSON, for the same reason §11.6's
oracles do. Parsing JSON needs a parser, and `jsonlite` in `Suggests` would work
on a developer machine and then *skip* on a check without it — which is exactly
the failure `RADD-oqevkuzo` names, since a corpus that skips is not a corpus.
`vendor-wpt.R --check` re-derives the CSV from the vendored bytes and fails on
drift.

**The corpus is read through what WPT's output reveals, not through whether the
row passed.** A `failure` flag is about the whole URL: WPT fails
`http://[1::2]:3:4` on the port, and its host is well formed. The successes say
more, because the serialized `hostname` reveals which parser the URL parser
reached. Hence a derived `expect` column:

| `expect` | what it means | what raddr must do |
|---|---|---|
| `ipv4` / `ipv6` | an address parser ran and serialized an address | reach the same address |
| `regname` | no address parser ran; the host is a reg-name | **decline** |
| `url-failure` | the URL failed | decline, bar a pinned exception |

`regname` is the class worth having. `0x7f.0.0.0x7g` ends in something that
looks like a number and is not one, so WHATWG's gate admits it, the IPv4 parser
rejects it, and the URL parser keeps it as a **valid host**. raddr has no
reg-name concept, so `NA` is its whole answer and the right one — and reading
that row's success as "raddr must parse it" is the mistake `RADD-cdmoeadr`
found waiting for anyone delegating `rurl`'s host layer.

**Addresses are compared as addresses, never as text**, because WPT's serializer
and RFC 5952 §5 disagree on exactly one form — `::ffff:7f00:1` against
`::ffff:127.0.0.1`. Pinning to text would turn one real divergence into 17
unrelated failures. The divergence is instead pinned as an *exact set*, so a new
one cannot arrive disguised as the known one.

**What the mutation run found, and it changed the design.** Comparing a hostile
spelling against the canonical form it means is blind to a parser that is too
**permissive**: under a widened rule both sides are still addresses, so both
sides still agree. Measured, by breaking the shipped code on purpose:

| mutation | caught by the success rows | caught overall |
|---|---|---|
| final part's bound 255 → 256 | no | yes, after the boundary rows |
| hex width 8 → 9 digits | no | yes |
| three-part form's bound off by a byte | no | yes |
| octal width 11 → 12 digits | no | **no — equivalent mutant** |

Only the rows that must **not** parse catch a permissive parser, and asserting
those needs the exceptions pinned exactly: one in 69, the bad port above. That
was `RADD-aitbetjb`'s bidirectional rot check in miniature over a single class —
a row *leaving* the set means raddr started rejecting a good host, a row
entering it means raddr started accepting a bad one. §11.8 is the general
version.

The final-bounds mutation survived even then, because WPT has no four-part host
whose last part is exactly 256; a bound is only checked by the two values that
straddle it, which is §11.3's lesson arrived at a second time by the same route.
Eleven boundary rows closed it. The octal survivor is genuinely equivalent — a
12-digit octal is at least 8¹¹ > 2³², so the modular accumulation flags the
overflow whether or not the width check does, exactly as §11.3 records for the
decimal case.

**raddr's own additions are a separate file, and the split is a licence boundary
rather than a convenience** (§12.1). `fixtures/wpt/` holds nothing but upstream
BSD-3 bytes, so a re-sync stays a file swap and `inst/COPYRIGHTS` can say which
bytes are whose; `fixtures/raddr_extra_urltestdata.json` is raddr's own MIT work.
The derived CSV carries a `source` column so that claim is checkable in the data
and not merely recoverable by remembering which file a row came from. The 25
raddr rows fill gaps **measured** in the vendored file rather than imagined ones
— at `181476a` no input contains `2147483648`, `0x80000000`, `fe80`, `::ffff:`,
`64:ff9b` or `2002:`, and uppercase `0X` is spelled only inside reg-names. Every
expectation was measured against Node v26.3.1, whose URL parser is ada, already
an oracle above; a hand-written expectation is a second implementation with no
tests.

**Two extraction rules that are raddr's own judgment, recorded because they are
the parts a reader would otherwise have to reverse-engineer.** Row selection
does *not* call `ends_in_a_number()` and errs inclusive: a corpus selected by the
gate can never contain a row the gate gets wrong. And authority extraction
refuses what it cannot read without implementing a URL parser — 371 rows — each
attributed to a named rule and counted, so the refusals can neither grow nor
change shape silently (§11.8).

**The ticket's row counts did not fully reproduce.** `RADD-xdgfyznt` said "43
numeric-IPv4 authorities, 44 bracketed IPv6". Bracketed reproduces exactly on the
first natural definition; numeric does not reproduce under any of six tried
(58 / 55 / 49 / 35 / 57 / 20). The measured figures are what is recorded, rather
than a filter bent to hit a remembered number.

### 11.8 The expected-failure record **[implemented 2026-07-29]**

`tests/testthat/fixtures/expected_failures.txt`, `RADD-aitbetjb`. Every place
raddr and the WPT corpus do not line up, written down once with its reason and
re-checked by the suite. Three entries about rows, one class about extraction:

| class | claim | rows at this pin |
|---|---|---|
| `reads-failed-url` | WPT failed the URL; raddr reads the host, because the failure is not the host's | 1 |
| `declines-pct-encoded` | WPT reached an address; raddr declines, because the URL parser decoded before it | 2 |
| `format-divergence` | same address, different text | 1 |
| `extractor-refusal` | rows that never became corpus rows, per rule | 5 rules, 371 rows |

**A record like this rots three ways, and the third is the one such files
usually miss.** An entry that stopped being true is an *unexpected success* and
the fix is to delete it; a disagreement nobody wrote down is a *regression* and
the fix is the parser; and an entry naming a row the corpus no longer has is a
**leftover** — it stops exempting anything the moment the row leaves, silently,
while the suite goes on passing and the entry goes on looking like coverage.
Each is its own expectation, because a harness that reports "these two sets
differ" has left the reader to work out which way round it went and therefore
what to do. Each class also states a **direction**, and the direction is
checked: filing a row under the wrong class would otherwise buy the same
exemption for free.

**Rows are keyed by `(source, input)` and never by index.** An index is a
position and shifts under any upstream insertion, so an index key would turn one
re-sync into 128 leftovers and teach everyone to ignore the check. `input` is
the identity WPT itself uses. The suite asserts the pair is unique before
relying on it.

**Percent-encoded rows stopped being excluded wholesale, and that is the
strengthening.** The suite used to drop all six on the `pct_encoded` column.
Only **two** of them actually turn on the decode — `%30%78%63%30%2e%30%32%35%30`
is `0xc0.0250`, so WPT serializes 192.168.0.1 from bytes raddr never sees — and
the other four were getting a free pass: nothing would have caught raddr
starting to read `http://[::%31]` as an address. Listing the two by name puts
the other four back under assertion. The blanket-exclusion instinct is the
thing to distrust here; an exclusion should be as narrow as its reason.

**The refusal counts close a loop the suite cannot close alone.** They are a
fact about the JSON, and reading JSON needs a parser raddr does not depend on.
So `vendor-wpt.R` attributes each refusal to a named rule, writes the table to
`fixtures/wpt-refusals.csv`, and `--check` re-derives it from the vendored bytes
and fails on drift; the suite then holds the hand-written account against that
generated table, in both directions. The bytes fix the CSV and the CSV fixes the
account. It is a **fixture and not a provenance field** because `data-raw/` is
`.Rbuildignore`d and so absent under `R CMD check` — and a check that skips is
not a check, the same rule §11.7 applies to the corpus itself.

`--check` also stopped spot-checking the provenance. It compared three fields;
it now compares every generated field and reports fields that are absent or no
longer generated. A pin that is only spot-checked has a hole exactly where
nobody thought to look, and the new `RefusalRules` field would have landed in
one.

**Measured, by breaking the record on purpose.** Eight perturbations, all
caught, each naming its own fault: a deleted entry (regression), an entry for a
row that agrees (unexpected success), an entry pointing at a row that is not
there (leftover), a row filed under the wrong direction, a mistyped class name,
a hand-edited refusal count, a refusal rule dropped from the account, and an
unparseable line. The run also found a defect in the check itself — the class
vocabulary was asserted set-equal, which would have turned the suite red the
day someone *fixed* the last divergence in a class and removed its entry. It is
one-directional now: unknown classes are rejected, empty ones are the good
outcome.

One entry was wrong when first written — the v4-mapped divergence was filed
under `wpt` and the row is one of raddr's own additions, since no input at
`181476a` contains `::ffff:` at all. The leftover check caught it on the first
run, which is the only reason it is worth mentioning.

### 11.9 The generated properties **[implemented 2026-07-29]**

`tests/testthat/test-property.R` asserts §11.4's kind of claim over a
**generator** rather than over §11.4's frozen corpus. The corpus is 400 byte
draws behind one seed plus 2139 hostile literals, and it is not short of
inputs — so the case for a seventh test file, and for a dependency, rests on
the two things a frozen corpus structurally cannot do.

**The shrunk counterexample.** A corpus failure says one of 2139 literals broke
totality and leaves the reader to bisect it; `hedgehog` returns the smallest
input that still fails. Breaking `addr_parse()` on inputs containing `0x`
shrinks to the literal **`"0x"`** — the bug stated in two characters. That is
what the dependency buys.

**Tuples.** Transitivity is a claim about three addresses at once, which a flat
corpus cannot express. Until this file it was the one axiom §5.1.2 claims and
nothing checked.

| property | what it quantifies over |
|---|---|
| a rendered address reads back, and rendering is a fixed point | drawn addresses, both renderers (§5.1.3) |
| the four encodings decode to the drawn address | drawn addresses (§6.5) |
| the order is transitive, and ties are an equivalence | drawn *triples*, repeats included (§5.1.2) |
| containment is downward closed in the prefix length | drawn address pairs, every length at once (§6.3) |
| `addr_parse()` is total, and only `rejected` carries codes | drawn literals (P2, §5.2.1) |
| every reading classifies without erroring | drawn literals × six dialects (§5.3) |

The generators are built from `paste`, `sprintf` and `as.hexmode`, never from
the parser they feed — §11.4's rule for the wrapper round-trip, for the same
reason: a generator that spelled its addresses with `addr_format()` would
round-trip through the renderer's mistakes and report agreement. The masking
behind the containment property is byte arithmetic, sharing nothing with the
divisor arithmetic in `R/within.R` that it checks.

The draw count is passed explicitly at every call rather than set through
`options(hedgehog.tests)`. The option is process-wide, so pinning it in one file
sets it for every file that runs afterwards, and a property whose sample size
depends on file ordering is the drift this file exists to catch. 25 draws on
CRAN, 400 under `NOT_CRAN`.

**Graded by mutation, and the grading changed the generators twice.** Six
mutations, one per property, all caught, each shrinking to a legible cause:

| mutation | shrinks to |
|---|---|
| the renderer drops a trailing zero octet | `0.0.0` |
| the integer encoder loses a digit | `129.127.0.1` |
| `widen_word()` loses its `NA` guard | a word of `0x80000000` |
| `/7` answers as `/8` | a pair agreeing to 7 bits |
| `addr_parse()` errors on `0x` | `"0x"` |
| `addr_classify()` errors on a missing address | `"0"` |

Two of those first **survived**, and neither survival was the property's fault.

**Uniform octets are blind to the hazards this package is built around.** Four
independently drawn octets land on `0x80000000` about once in 10^5, so removing
`widen_word()`'s `NA` guard — the ipaddress bug of O11(b), reintroduced on
purpose — passed every property. Addresses are drawn a **word** at a time now,
half from a hazard pool and half uniform, because the hazards are word-level
facts and the data model is four 32-bit words. The same change caught the
trailing-zero renderer, which an address ending in `.0` at 1-in-256 had also
been surviving. Sensitivity went from one property catching the `widen_word`
mutation to four.

**Transitivity cannot fail while the order goes through a `vctrs` proxy**, and
that is worth writing down rather than rediscovering. A lexicographic
comparison of proxy columns *is* a total order, so no proxy — however wrong —
can be intransitive. The first attempt at a mutation here, comparing on a
single octet, was rejected for exactly this reason: one key still gives a
transitive relation. So the property's real content is the two ways the axiom
can still break: comparison answering `NA`, which is O11(b)'s shape and makes
the order undefined rather than intransitive, and ties failing to be an
equivalence. It is filed under transitivity because that is what a reader will
look for, but what it guards is totality.

`hedgehog` is `Suggests` (§12), and the file skips as a whole when it is
absent — verified by hiding the installed package and running the suite: six
tests, six skips, no errors, nothing at file scope touching the namespace.

### 11.10 The migration diff against the in-house guards **[measured 2026-07-29]**

sitemapr and robotstxtr each carry a structural SSRF guard whose IP reading
raddr is meant to replace. Measured read-only in both repos; nothing was
changed in either. `tests/testthat/test-migration.R` pins the facts a
delegation would rest on.

**The two guards are one implementation.** `R/ssrf.R` in each repo is
byte-identical for its whole IP body — 232 lines, 11 functions — differing only
in the entry point (`ssrf_check_parsed()` takes a parsed rurl row,
`robots_ssrf_check()` takes a URL). So "run both guards' assertions" is running
one guard's assertions twice, their agreement with each other is not evidence
of anything, and a defect in one is a defect in both. That duplication is a
better argument for delegating than any divergence below.

**On the reading itself, they agree completely.** raddr's 1861-literal hostile
corpus through the guard: **659 literals read by both, zero disagreements on
the bits.** Not one address is read differently. And **zero literals that raddr
reads and the guard refuses** — so delegation cannot loosen the guard, which is
the direction that would matter for a security control.

Three literals go the other way, and they are two different findings.

**The guard's fail-closed posture has a trailing-separator hole.** `::1:`,
`::ffff:`, `1:2:3:4:5:6:7:8:` and `1.2.3.4.` are read as valid addresses.
The cause is one line: R's `strsplit()` **drops a trailing empty field**, so
`strsplit("1:2:3:4:5:6:7:8:", ":")` returns eight groups, not nine, and
`ssrf_expand_zero_run()`'s arity check passes. The same mechanism makes
`ssrf_is_dotted_quad("1.2.3.4.")` true. The guard's header states the opposite
as an invariant — a literal that cannot resolve to exactly 8 hextets "is
refused with `malformed-address` rather than reaching the default allow" — and
that is the reliance SITE-vovtwvuh set out to remove. raddr calls all three
IPv6 forms `malformed`, under **every one of the six dialects**.

Severity is bounded and should be stated as such: the hole makes the guard read
`X:` as `X`, so it over-accepts rather than under-blocks — `::1:` still
classifies as loopback and is still refused. What it breaks is the documented
invariant, not a specific block.

**The trailing dot is not the guard's mistake.** `1.2.3.4.` is a hostname
carrying the DNS root label; WHATWG reads it as an address and the other five
dialects refuse, so raddr reports it as **`divergent`** rather than picking a
side. The guard agrees with WHATWG — silently, and without knowing that is what
it is doing. This is the P3 case, and the fact the guard needs is one raddr
already has.

**One reason code in the guard is wrong.** Its IPv4 matrix files
`100.64.0.0/10` under `cloud-metadata`. That block is RFC 6598 **Shared Address
Space** — carrier-grade NAT — and has nothing to do with metadata endpoints.
raddr answers `shared`. The codes are documented as "machine-readable and
stable", so a caller keying off `cloud-metadata` misattributes every CGNAT
address. `0.0.0.0/8` is filed as `unspecified` where raddr says `this_network`,
which is the more defensible of the two but still imprecise: only
`0.0.0.0/32` is the unspecified address.

**What raddr supplies, and what it declines to.** Every range-derived reason
code in the guard is a rename of an `addr_category()` value — `loopback`,
`private`, `link_local`, `this_network`, `shared` — and the whole embedding
inventory is `addr_embedded_kind()` plus `addr_embeddings()`, both ISATAP
markers included. The obfuscation grep in `ssrf_numeric_literal_blocked()` is
answered structurally rather than by pattern: a literal the lenient dialects
read and `strict` refuses **is** the obfuscation, and it arrives with the
address each dialect saw. What raddr does not supply is `cloud-metadata` and
the metadata hostname — those are policy, they are P8, and they are ssrfr's.

**Nothing here changed raddr.** The diff found no defect in it, and the
literals involved were already pinned (`test-codes.R`'s `trailing_dot`,
`test-ipv6.R`'s stray-colon block). The new file pins the *contract* instead,
because the migration depends on a vocabulary that no existing test forces to
stay put.

---

## 12. Dependencies

Target: **`vctrs` + `rlang`, and argue about anything else.**

| Candidate | Verdict |
|---|---|
| `vctrs` | Yes — the data model rests on it |
| `rlang` | Yes — conditions, checks; already a `vctrs` dep |
| `cli` | Open; nice, not load-bearing |
| `stringi` | Open; benchmark base R first (O4) |
| `bignum` | Suggests only, degrade gracefully |
| `hedgehog` | Suggests only — **taken up 2026-07-29 (§11.9)**. Adds nothing transitively: it needs `testthat` + `rlang`, both already here (O9) |
| `ipaddress` | **No.** Would import its `is_global` semantics and its gaps |
| `adaR` | **No.** Oracle in `data-raw/`, not a runtime dep |
| Go toolchain | **No.** Oracle in `data-raw/` (§11.6). The suite reads the CSV it wrote |
| `curl`, the CLI | **No.** Oracle in `data-raw/` (§11.6), and the only one that touches DNS |
| `rurl` | **No.** raddr must not depend on rurl; the dependency runs the other way |
| `triebeard` | Probably unnecessary at this table size (O5) |
| Rcpp / BH / AsioHeaders | **No** |

### 12.1 Bundled third-party material **[settled 2026-07-28]**

§12 governs what raddr **imports at runtime**. This section governs what it
**carries in its tarball**, which is a separate question with separate
obligations. O10 asked it about WPT and is closed here.

Two bodies of third-party material, under two licences that demand different
things:

| Material | Licence | What redistribution requires |
|---|---|---|
| the four IANA registries, `inst/extdata/*.csv` | CC0 1.0 | nothing — CC0 waives |
| WPT `urltestdata.json` (§8; RADD-xdgfyznt) | BSD-3-Clause, "web-platform-tests contributors" | clause 1: retain the copyright notice, the three conditions, and the disclaimer |

**That difference is the whole of O10.** CC0 asks for nothing, so `inst/NOTICE`
records provenance only — URL, sha256, byte count — and carries no licence
text. BSD-3 clause 1 binds **source** redistributions, and an R source tarball
is one, so with WPT the terms have to travel with the bytes. This is the first
bundled material for which attribution is an obligation rather than a courtesy.

**`License:` and `LICENSE` do not change, and cannot.**
`tools:::.license_component_is_for_stub_and_ok` is the function `R CMD check`
uses to validate a `+ file LICENSE` stub; for MIT it requires `LICENSE` to
parse as DCF with **exactly** the field set `{YEAR, COPYRIGHT HOLDER}`.
Measured, rather than assumed:

| `LICENSE` content under `MIT + file LICENSE` | result |
|---|---|
| the bare two-line template (what raddr ships) | **0 — OK** |
| template + a prose paragraph | 2 — unreadable as DCF |
| template + an extra DCF field | 3 — wrong field set |
| template + the full BSD-3 text | 2 — unreadable as DCF |
| template + `ORGANIZATION` | 3 — wrong field set |

A blank line makes DCF start a second record, so appended prose does not merely
look wrong — it stops parsing. There is no way to write the BSD-3 terms into
`LICENSE`, which is why they need a file of their own.

**The file is `inst/COPYRIGHTS`, not `LICENSE.note`.** O10's original wording
named `LICENSE.note`; a survey of the 266 packages installed locally found it in
**none** of them, against 10 carrying `inst/COPYRIGHTS` (and 3 more using
`AUTHORS` for the same purpose). `fs` and `vroom` are
the precedent worth copying — MIT R packages bundling third-party
permissive-licensed material, each reproducing the upstream licence **in full**
in `inst/COPYRIGHTS` and naming the upstream holder in `Authors@R` as
`person(..., role = "cph", comment = "<what they hold>")`. Copy the structure,
not the text: both files open by claiming GPL-3 terms that contradict their own
`MIT + file LICENSE` field, which is a copy-paste wart in `r-lib`, not a
convention.

**The generated-file hazard, which is the part worth knowing.** `inst/NOTICE`
is not hand-maintained — `data-raw/build-registry.R` composes it and ends with
`writeLines(notice, notice_path)`, overwriting the file wholesale. A BSD-3
notice appended to it would survive until the next registry rebuild and then
vanish, turning a routine maintainer action into a licence-compliance failure
with no error message. So the WPT terms may **not** live in a
build-script-owned file. The resolution is that `build-registry.R` composes
`inst/COPYRIGHTS` from its generated IANA provenance section plus a static
third-party section it *reads* from `data-raw/`, so the licence text is an
input to the script and not something the script can destroy. `inst/NOTICE` is
retired into that one file, which is also the name CRAN reviewers look for.

**The `raddr_extra_*.json` split is a licence boundary, not just a re-sync
convenience.** RADD-xdgfyznt keeps local additions out of the vendored file so
upstream re-sync stays a file swap; the same split is what lets
`inst/COPYRIGHTS` say which bytes are BSD-3 and which are raddr's own MIT work.
Mixing them would make the boundary unstateable.

**Clause 3 constrains how raddr describes itself.** Neither the holder's name
nor its contributors' may be used to endorse or promote. Recording that the
suite runs against WPT vectors is fact and is fine; "validated by
web-platform-tests", in `DESCRIPTION` or `README`, would read as endorsement.

**The vendored JSON needs §7.1's formatting exemption too.** The lesson the
IANA CSVs taught — `.gitattributes` and the whitespace pre-commit hooks rewrite
vendored bytes and thereby falsify the sha256 just recorded — applies to any
byte-pinned upstream file. `urltestdata.json` gets the same `-text` treatment
and the same hook exclusions when it lands, or its pin is a lie.

Implementation lands with the data in RADD-xdgfyznt rather than here: the
`Authors@R` `cph` entry would otherwise name a copyright holder for material
the package does not yet contain.

**[implemented 2026-07-29.]** All four changes landed as written. Two details
this section did not anticipate, both discovered while executing it:

- **The licence boundary works better as a directory than as a filename
  prefix.** O10 assumed `raddr_extra_*.json` beside the vendored file. Putting
  the upstream bytes alone under `fixtures/wpt/` instead makes the `-text`
  attribute and the three whitespace-hook exemptions one-line rules over a path,
  and lets `inst/COPYRIGHTS` name a directory rather than enumerate filenames
  that will change. The extras keep the `raddr_extra_` name, outside it.
- **`inst/COPYRIGHTS` is composed by `build-registry.R` but the WPT pin is
  written by `vendor-wpt.R`,** so the file has two upstreams. The rule that keeps
  §12.1's guarantee is that the *licence text* — `data-raw/wpt-LICENSE.txt` — is
  written by hand and generated by nothing, while only the numbers are generated.
  Missing WPT inputs are an **error** and never a warning, because emitting a
  `COPYRIGHTS` with no WPT section while the WPT bytes ship in the tarball is
  precisely the silent compliance failure this section exists to prevent.

See §11.7 for the corpus itself.

---

## 13. Relationship to the stack

```
   leaf layer          consumer layer
   ───────────         ──────────────
   punycoder                rurl ── pslr
   raddr                    ssrfr
```

**This is a layering diagram, not a dependency graph.** `punycoder` and `raddr`
are sibling leaves: both are pure, offline, and depend on neither each other nor
anything above them. `rurl` and `ssrfr` sit above and may import either. The only
edges that exist as package dependencies are the downward ones — see §12, which
admits `vctrs` and `rlang` and argues about everything else. raddr importing
`punycoder` would violate §1.1, which puts IDNA and punycode permanently out of
scope.

Sequencing: build raddr, validate it against `rurl`'s conformance CSV, the
in-house guards' assertions, and WPT as external oracles, then ship to CRAN.
`ssrfr` work begins once raddr has an early working version — the two release
trains are **not** coupled, because coupling is how a small package ends up
waiting on a big one.

`raddr` serves the component level. A URL-level convenience wrapper lives in
`ssrfr` or as a thin `rurl` bridge — never the reverse.

One caveat on the `punycoder` analogy: `punycoder` implements a spec with one
right answer and decidable conformance. raddr catalogs *deviations* from specs;
its premise is that `0177.0.0.1` has several defensible answers. Canonical vs.
deliberately multi-valued is an inversion, not a parallel. **Do not let raddr
drift into being another `ipaddress`.**
