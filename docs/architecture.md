# Architecture

Durable design decisions for `raddr`. This file supersedes `_scratch/SPEC.md`
wherever the two disagree; the scratch documents remain the authority for
*evidence* (what was measured) but not for *design* (what we decided).

**Provenance.** Decisions below were settled in a review session on 2026-07-26.
Empirical claims marked **[verified 2026-07-26]** were measured on this machine:
macOS Darwin 25.4.0 arm64, R 4.6.0, `ipaddress` 1.0.3, `adaR` 0.3.5,
`curl` 7.1.0 / libcurl 8.14.1, Python 3.x, Apple libc.

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
| reality | `aton` | BSD `inet_aton` | stable in practice |

### 3.2 The two compositions

Both are precedence orderings over the same two reality primitives — not
separate parsers **[verified 2026-07-26]**:

```
addr_getaddrinfo  =  pton, falling back to aton
addr_curl         =  aton, falling back to pton
```

Every measured row falls out of those two orderings. They are implemented as
literal compositions of the exported primitives, so a precedence change upstream
is an argument swap, not a rewrite.

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

`pton` is the one dialect whose row is **platform-dependent**. Apple libc strips
leading zeros and reads decimal. glibc and musl are **unverified** — see §10.

### 3.4 What is deliberately absent

- **`rfc3986`** — reg-name-vs-IPv4 host form. rurl already answers this via
  `get_host_type(url, url_standard = "rfc3986")`. It is a host-form question,
  not an address question.
- **A profile layer.** rurl's `"browser"` profile differs from its `"whatwg"`
  profile only in `scheme_policy`, `scheme_relative_handling`, and
  `fixup_posture` — all scheme-layer knobs. raddr never sees a scheme, so the
  two would collapse to one bundle. "Browser" appears in raddr's prose, never as
  an identifier.

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

### 5.3 `raddr_class`

| Field | Type | Notes |
|---|---|---|
| `block` | `character` | matched registry prefix |
| `name`, `rfc` | `character` | registry columns; `rfc` is the provenance string |
| `scope` | factor | raddr's vocabulary |
| `globally_reachable` | `logical` | the IANA column, **not** a derived `is_global` |
| `forwardable`, `source`, `destination`, `reserved_by_protocol` | `logical` | the other four IANA columns |
| `embedded` | `raddr_address` | the extracted inner IPv4, or `NA` |
| `embedded_kind` | factor | `ipv4_mapped`, `6to4`, `teredo`, `nat64_wk`, ... |
| `embedded_scope` | factor | scope after recursive extraction |
| `registry_version` | `character` | snapshot stamp (P7) |

**Vocabulary — one word, and it is the RFCs' word.** raddr says *embedded*
throughout: field names, accessors, prose. RFC 6052 §2 speaks of "embedding an
IPv4 address" in an IPv6 prefix, and RFC 4291 §2.5.5 of the "IPv4-mapped" form.
Matching the standards' noun means someone reading the RFC and someone reading
raddr use the same term. "Unwrap" does not appear anywhere in raddr.

This governs **identifiers** — field names, accessor names, code names. Prose
may still say "wrapper" for the outer IPv6 form that carries an inner address
(§8.1's wrapper matrix), because that names the *container*, not the operation.

`embedded_scope` was `effective_scope` in the draft. The computation is
RFC 6052-derived and stays; the name goes, because "effective" asserts that one
of three simultaneously-true fields is the real one. That is a judgment raddr no
longer makes.

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
```

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

### 6.3 Classify

```r
addr_classify(a)         # -> raddr_class
addr_scope(a)            # factor
addr_embedded_scope(a)   # factor, after recursive extraction
addr_within(a, blocks)   addr_within_any(a, blocks)
```

### 6.4 Data and metadata

```r
addr_registry()  addr_codes_registry()
addr_registry_version()  addr_registry_outdated(max_age = 365)
```

### 6.5 Encoding round-trips

```r
addr_to_bytes / bytes_to_addr        addr_to_binary / binary_to_addr
addr_to_hex   / hex_to_addr          addr_to_integer / integer_to_addr
```

`addr_to_integer()` returns `character` decimal by default so it always works,
and `bignum` output only when that package is present. Degrade, never error.

### 6.6 Prefix

`addr_` throughout. Measured **[verified 2026-07-26]**: `ipaddress` exports 29
names matching `^ip_|^is_`, including every predicate and three of the four
encoding pairs. Collisions under `addr_`: zero.

---

## 7. Classification data

Source: the two IANA special-purpose registries (CC0, 4.7 KB, 26 + 27 rows).
All five policy columns surfaced, never collapsed. `Globally Reachable` **is**
`is_global`, authoritatively, per row, with an RFC citation.

Lookup is **longest-prefix-match**, not first-match-wins, because the registry
contains carve-outs: `192.0.0.9/32` and `192.0.0.10/32` are globally reachable
inside a non-global `192.0.0.0/24`.

Table lookup is necessary but not sufficient. `64:ff9b::/96` is marked globally
reachable *because it maps onto global IPv4*; the embedded address must be
extracted and classified separately. Hence `scope` and `embedded_scope`.

One overlay remains, separately stamped from the IANA table: **transition
prefixes needing sub-registry granularity** — 6to4 `2002::/16`, Teredo
`2001::/32`, ISATAP, the six RFC 6052 NAT64 prefix lengths.

The **cloud-metadata overlay is removed** from raddr and belongs to `ssrfr`.
`169.254.169.254` appears in no RFC; the table was hand-assembled from provider
docs and partly from memory. Removing it deletes the package's only data table
with no upstream authority.

No network refresh in v0.1. The registries change on a multi-year cadence, the
whole file is 4.7 KB, and "zero network code" is a cleaner claim than "network
code that defaults off".

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
- Registry-driven `addr_classify()` with `scope` / `embedded_scope`.
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

### 8.1 Wrapper matrix

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

Second-order. None blocks the API freeze except where noted.

| # | Item | Disposition |
|---|---|---|
| O1 | Pure R vs compiled | Pure R for v0.1. Benchmark honestly against §11 targets. Not the biggest open question — the API can freeze first, so the escape hatch is real |
| O2 | Does `zone` participate in `==`? | Recommend no; equality over the 128 bits and family; `addr_zone()` queried separately. **Blocks type design** |
| O3 | Cross-family ordering | Recommend total order, v4 before v6, documented, so `sort()` is total. **Blocks type design** |
| O4 | `stringi` vs base R for ASCII host tokenization | Benchmark base R first |
| O5 | Trie vs sorted masked vector for the 53 IANA rows plus the transition overlay | Benchmark; probably neither a trie nor `triebeard` |
| O6 | glibc and musl `pton` rows | **Unverified.** Docker is installed locally. §3.3's `pton` column is Apple-only |
| O7 | IPv6 half of rust-url `host.rs` (~363–512) | Still unread; IPv6 is the genuinely new work |
| O8 | RFC 5952 test vectors | None published upstream. raddr authors its own |
| O9 | `hedgehog` 0.2 on R 4.6.0 aarch64 | Not currently installed |
| O10 | WPT vendoring licence mechanics under CRAN | BSD-3 should be fine; `LICENSE.note` handling needs checking |
| O11 | Two bugs to file upstream on `davidchall/ipaddress` | (a) the NAT64 gap — one predicate plus one extractor; (b) the `0x80000000` equality bug in §5.1.1, with `ip_address("128.0.0.0") == ip_address("128.0.0.0")` returning `NA` as the reproducer. File both regardless of what raddr ships |
| O12 | `rurl::get_host_type()` NULL-default wart | File on rurl |

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
| `hedgehog` | Suggests only |
| `ipaddress` | **No.** Would import its `is_global` semantics and its gaps |
| `adaR` | **No.** Oracle in `data-raw/`, not a runtime dep |
| `rurl` | **No.** raddr must not depend on rurl; the dependency runs the other way |
| `triebeard` | Probably unnecessary at this table size (O5) |
| Rcpp / BH / AsioHeaders | **No** |

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
