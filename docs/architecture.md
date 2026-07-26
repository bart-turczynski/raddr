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

`pton` is the one dialect whose row is **platform-dependent**. Apple libc strips
leading zeros and reads decimal. glibc and musl are **unverified** — see §10.

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
| `fe80:abcd::1` | fe80:abcd::1 | fe80:abcd::1 | fe80:abcd::1 | reject | **fe80::1 %43981** | fe80:abcd::1 |
| `fe80::1%lo0` | reject | reject | ::1 %lo0 | reject | ::1 %lo0 | ::1 %lo0 |
| `1.2.3.4` | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 | 1.2.3.4 |
| `[::1]` | reject | reject | reject | reject | reject | reject |

The row that carries the value is **`fe80:abcd::1`**: two libc entry points on
one machine return different bits for one string, which is the IPv6 counterpart
of what `0177.0.0.1` does for IPv4.

#### 3.5.1 The four measured facts

- **`inet_aton` has no IPv6 reading at all.** It is `AF_INET` by signature and
  rejects every colon-bearing literal. Measured rather than assumed, because
  both compositions in §3.2 lean on it: for IPv6, `getaddrinfo` and `curl` both
  collapse onto their `pton` half.
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

Second-order. With O2 and O3 settled on 2026-07-26, **nothing here blocks the
API freeze**; the two that did are kept in the table with their resolutions so
the decisions are not relitigated.

| # | Item | Disposition |
|---|---|---|
| O1 | Pure R vs compiled | **Measured 2026-07-26, see §11.2.** The record meets both targets in pure R; the parsers miss the speed target by 18x and that is the pure R floor. Still v0.1-pure and v0.2-decidable, because the API does not change either way. Plain C, not Rcpp |
| O2 | Does `zone` participate in `==`? | **Settled 2026-07-26: no.** Equality over the 128 bits and family; `addr_zone()` queried separately. See §5.1.2 |
| O3 | Cross-family ordering | **Settled 2026-07-26: total order, v4 before v6**, with `v6_4in6` ranked as `v6`. See §5.1.2 |
| O4 | `stringi` vs base R for ASCII host tokenization | Benchmark base R first |
| O5 | Trie vs sorted masked vector for the 53 IANA rows plus the transition overlay | Benchmark; probably neither a trie nor `triebeard` |
| O6 | glibc and musl `pton` rows | **Unverified.** Docker is installed locally. §3.3's `pton` column is Apple-only, and §3.5 raises the stakes: the IPv6 leading-zero rule, the fold and the lift are all Apple behaviors |
| O7 | IPv6 half of rust-url `host.rs` (~363–512) | **Read 2026-07-26.** §3.5.1 records what it settled: the WHATWG IPv6 tail is a separate, stricter grammar than the WHATWG IPv4 parser, and `%` is a rejection |
| O8 | RFC 5952 test vectors | **Closed 2026-07-27.** None published upstream; raddr's own are in `tests/testthat/test-format.R`, by RFC section (§5.1.3) |
| O9 | `hedgehog` 0.2 on R 4.6.0 aarch64 | Not currently installed |
| O10 | WPT vendoring licence mechanics under CRAN | BSD-3 should be fine; `LICENSE.note` handling needs checking |
| O11 | Two bugs to file upstream on `davidchall/ipaddress` | (a) the NAT64 gap — one predicate plus one extractor; (b) the `0x80000000` equality bug of §5.1.1, reproducer `ip_address("0.0.0.128") == ip_address("0.0.0.128")` returning `NA`. Not an R bug — see §5.1.1. File both regardless of what raddr ships |
| O12 | `rurl::get_host_type()` NULL-default wart | File on rurl |
| O13 | The `curl` = aton-then-pton composition for **IPv6** | **Unverified against real curl.** The IPv4 composition was measured; the IPv6 half is derived, and since `aton` rejects every IPv6 literal it reduces to a claim that curl reaches `inet_pton` rather than `getaddrinfo` for a bracketed literal. Those two now disagree (§3.5.3), so the claim is testable and worth testing |
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
