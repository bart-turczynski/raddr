# Local inventory — what this repo already records

Baseline for a delta check against fresh external research. **Nothing here was
researched externally.** Every row is transcribed from a file already in this
repository, with the path (and line where practical) given. Where the repo
asserts something with no source, the row says so.

Line numbers are as of the audit and refer to the state of the working tree on
branch `feature/ipv6-parsing`.

---

## Ranges already known

Three sources, kept apart because they have different authority: the vendored
IANA CSVs (upstream data), `R/transition.R` (hand-transcribed from RFCs, no
upstream file), and prose-only mentions in `docs/architecture.md` and
`_scratch/` (evidence and rejected overlays, not shipped data).

### 1. Vendored IANA IPv4 special-purpose registry

`inst/extdata/iana-ipv4-special-registry.csv` — 25 CSV records, **26 blocks**
(one record names two prefixes). Parsed into `R/sysdata.rda` by
`data-raw/build-registry.R`; surfaced by `addr_registry()` (`R/registry.R:82`).

| prefix | space | name | RFC/source | where recorded (file:line) |
|---|---|---|---|---|
| `0.0.0.0/8` | v4 | "This network" | RFC 791 §3.2 | `inst/extdata/iana-ipv4-special-registry.csv:2` |
| `0.0.0.0/32` | v4 | "This host on this network" | RFC 1122 §3.2.1.3 | `inst/extdata/iana-ipv4-special-registry.csv:3` |
| `10.0.0.0/8` | v4 | Private-Use | RFC 1918 | `inst/extdata/iana-ipv4-special-registry.csv:4` |
| `100.64.0.0/10` | v4 | Shared Address Space (CGNAT) | RFC 6598 | `inst/extdata/iana-ipv4-special-registry.csv:5` |
| `127.0.0.0/8` | v4 | Loopback | RFC 1122 §3.2.1.3 | `inst/extdata/iana-ipv4-special-registry.csv:6` |
| `169.254.0.0/16` | v4 | Link Local | RFC 3927 | `inst/extdata/iana-ipv4-special-registry.csv:7` |
| `172.16.0.0/12` | v4 | Private-Use | RFC 1918 | `inst/extdata/iana-ipv4-special-registry.csv:8` |
| `192.0.0.0/24` | v4 | IETF Protocol Assignments (footnote `[2]`) | RFC 6890 §2.1 | `inst/extdata/iana-ipv4-special-registry.csv:9` |
| `192.0.0.0/29` | v4 | IPv4 Service Continuity Prefix | RFC 7335 | `inst/extdata/iana-ipv4-special-registry.csv:10` |
| `192.0.0.8/32` | v4 | IPv4 dummy address | RFC 7600 | `inst/extdata/iana-ipv4-special-registry.csv:11` |
| `192.0.0.9/32` | v4 | Port Control Protocol Anycast (globally reachable carve-out) | RFC 7723 | `inst/extdata/iana-ipv4-special-registry.csv:12` |
| `192.0.0.10/32` | v4 | TURN Anycast (globally reachable carve-out) | RFC 8155 | `inst/extdata/iana-ipv4-special-registry.csv:13` |
| `192.0.0.170/32` | v4 | NAT64/DNS64 Discovery | RFC 8880, RFC 7050 §2.2 | `inst/extdata/iana-ipv4-special-registry.csv:14` (composite field, split at build) |
| `192.0.0.171/32` | v4 | NAT64/DNS64 Discovery | RFC 8880, RFC 7050 §2.2 | `inst/extdata/iana-ipv4-special-registry.csv:14` (same record) |
| `192.0.2.0/24` | v4 | Documentation (TEST-NET-1) | RFC 5737 | `inst/extdata/iana-ipv4-special-registry.csv:15` |
| `192.31.196.0/24` | v4 | AS112-v4 | RFC 7535 | `inst/extdata/iana-ipv4-special-registry.csv:16` |
| `192.52.193.0/24` | v4 | AMT | RFC 7450 | `inst/extdata/iana-ipv4-special-registry.csv:17` |
| `192.88.99.0/24` | v4 | Deprecated (6to4 Relay Anycast); terminated 2015-03, all policy columns empty | RFC 7526 | `inst/extdata/iana-ipv4-special-registry.csv:18` |
| `192.88.99.2/32` | v4 | 6a44-relay anycast address | RFC 6751 | `inst/extdata/iana-ipv4-special-registry.csv:19` |
| `192.168.0.0/16` | v4 | Private-Use | RFC 1918 | `inst/extdata/iana-ipv4-special-registry.csv:20` |
| `192.175.48.0/24` | v4 | Direct Delegation AS112 Service | RFC 7534 | `inst/extdata/iana-ipv4-special-registry.csv:21` |
| `198.18.0.0/15` | v4 | Benchmarking | RFC 2544 | `inst/extdata/iana-ipv4-special-registry.csv:22` |
| `198.51.100.0/24` | v4 | Documentation (TEST-NET-2) | RFC 5737 | `inst/extdata/iana-ipv4-special-registry.csv:23` |
| `203.0.113.0/24` | v4 | Documentation (TEST-NET-3) | RFC 5737 | `inst/extdata/iana-ipv4-special-registry.csv:24` |
| `240.0.0.0/4` | v4 | Reserved | RFC 1112 §4 | `inst/extdata/iana-ipv4-special-registry.csv:25` |
| `255.255.255.255/32` | v4 | Limited Broadcast | RFC 8190, RFC 919 §7 | `inst/extdata/iana-ipv4-special-registry.csv:26-27` (record wraps across two lines) |

### 2. Vendored IANA IPv6 special-purpose registry

`inst/extdata/iana-ipv6-special-registry.csv` — 25 CSV records, **25 blocks**.

| prefix | space | name | RFC/source | where recorded (file:line) |
|---|---|---|---|---|
| `::1/128` | v6 | Loopback Address | RFC 4291 | `inst/extdata/iana-ipv6-special-registry.csv:2` |
| `::/128` | v6 | Unspecified Address | RFC 4291 | `inst/extdata/iana-ipv6-special-registry.csv:3` |
| `::ffff:0:0/96` | v6 | IPv4-mapped Address | RFC 4291 | `inst/extdata/iana-ipv6-special-registry.csv:4` |
| `64:ff9b::/96` | v6 | IPv4-IPv6 Translat. (NAT64 well-known) | RFC 6052 | `inst/extdata/iana-ipv6-special-registry.csv:5` |
| `64:ff9b:1::/48` | v6 | IPv4-IPv6 Translat. (NAT64 local-use) | RFC 8215 | `inst/extdata/iana-ipv6-special-registry.csv:6` |
| `100::/64` | v6 | Discard-Only Address Block | RFC 6666 | `inst/extdata/iana-ipv6-special-registry.csv:7` |
| `100:0:0:1::/64` | v6 | Dummy IPv6 Prefix | RFC 9780 | `inst/extdata/iana-ipv6-special-registry.csv:8` |
| `2001::/23` | v6 | IETF Protocol Assignments (footnote `[1]` on policy values) | RFC 2928 | `inst/extdata/iana-ipv6-special-registry.csv:9` |
| `2001::/32` | v6 | TEREDO; `Globally Reachable = N/A` | RFC 4380, RFC 8190 | `inst/extdata/iana-ipv6-special-registry.csv:10-11` (record wraps) |
| `2001:1::1/128` | v6 | Port Control Protocol Anycast | RFC 7723 | `inst/extdata/iana-ipv6-special-registry.csv:12` |
| `2001:1::2/128` | v6 | TURN Anycast | RFC 8155 | `inst/extdata/iana-ipv6-special-registry.csv:13` |
| `2001:1::3/128` | v6 | DNS-SD Service Registration Protocol Anycast | RFC 9665 | `inst/extdata/iana-ipv6-special-registry.csv:14` |
| `2001:2::/48` | v6 | Benchmarking | RFC 5180 + Errata 1752 | `inst/extdata/iana-ipv6-special-registry.csv:15` |
| `2001:3::/32` | v6 | AMT | RFC 7450 | `inst/extdata/iana-ipv6-special-registry.csv:16` |
| `2001:4:112::/48` | v6 | AS112-v6 | RFC 7535 | `inst/extdata/iana-ipv6-special-registry.csv:17` |
| `2001:10::/28` | v6 | Deprecated (previously ORCHID); terminated 2014-03, policy columns empty | RFC 4843 | `inst/extdata/iana-ipv6-special-registry.csv:18` |
| `2001:20::/28` | v6 | ORCHIDv2 | RFC 7343 | `inst/extdata/iana-ipv6-special-registry.csv:19` |
| `2001:30::/28` | v6 | Drone Remote ID Protocol Entity Tags (DETs) | RFC 9374 | `inst/extdata/iana-ipv6-special-registry.csv:20` |
| `2001:db8::/32` | v6 | Documentation | RFC 3849 | `inst/extdata/iana-ipv6-special-registry.csv:21` |
| `2002::/16` | v6 | 6to4 (footnote `[3]`); `Globally Reachable = N/A` | RFC 3056 | `inst/extdata/iana-ipv6-special-registry.csv:22` |
| `2620:4f:8000::/48` | v6 | Direct Delegation AS112 Service | RFC 7534 | `inst/extdata/iana-ipv6-special-registry.csv:23` |
| `3fff::/20` | v6 | Documentation | RFC 9637 | `inst/extdata/iana-ipv6-special-registry.csv:24` |
| `5f00::/16` | v6 | Segment Routing (SRv6) SIDs | RFC 9602 | `inst/extdata/iana-ipv6-special-registry.csv:25` |
| `fc00::/7` | v6 | Unique-Local (footnote `[4]` on Globally Reachable) | RFC 4193, RFC 8190 | `inst/extdata/iana-ipv6-special-registry.csv:26-27` (record wraps) |
| `fe80::/10` | v6 | Link-Local Unicast | RFC 4291 | `inst/extdata/iana-ipv6-special-registry.csv:28` |

Block count and the 25+25-records → 51-blocks arithmetic:
`docs/architecture.md:925-938`, `R/registry.R:47-52`, `R/registry.R:67`.

### 3. Transition-prefix overlay (`R/transition.R`) — hand-transcribed, not vendored

| prefix | space | kind / name | RFC/source | where recorded (file:line) |
|---|---|---|---|---|
| `::ffff:0:0/96` | v6 | `ipv4_mapped` | RFC 4291 §2.5.5.2 | `R/transition.R:33` |
| `::/96` | v6 | `ipv4_compatible` (deprecated; only tail > 1 is an embedded address) | RFC 4291 §2.5.5.1 | `R/transition.R:37` |
| `::ffff:0:0:0/96` | v6 | `ipv4_translated` — **no RFC assigns this**; carried only because the in-house guards recognize it | none (repo says so explicitly) | `R/transition.R:45-46` |
| `2002::/16` | v6 | `6to4` | RFC 3056 §2 | `R/transition.R:50` |
| `2001::/32` | v6 | `teredo` (two embedded addresses; client complemented) | RFC 4380 §4 | `R/transition.R:54` |
| `192.88.99.0/24` | v4 | `6to4_relay_anycast` — classify-only, embeds nothing; deprecated by RFC 7526 | RFC 3068 §2.3 | `R/transition.R:61` |
| `64:ff9b::/96` | v6 | `nat64_wk` (well-known, only ever /96) | RFC 6052 §2.1 | `R/transition.R:66` |
| `64:ff9b:1::/48` | v6 | `nat64_local` (u-byte-aware) | RFC 8215 §3 | `R/transition.R:70` |
| ISATAP — **no prefix at all**, an interface-identifier pattern `0000:5efe` / `0200:5efe` under any `/64` | v6 | `isatap` | RFC 5214 §6.1 | `R/transition.R:119-122`, `R/transition.R:145-159`; wrapper matrix `docs/architecture.md:1104` |
| NAT64 network-specific prefixes at /32, /40, /48, /56, /64, /96 — **not prefixes, prefix lengths** | v6 | `nat64` geometry | RFC 6052 §2.2 | `R/transition.R:126-134`; table `docs/architecture.md:1025-1032` |

Only two of these prefixes are absent from the IANA CSVs (`::/96`,
`::ffff:0:0:0/96`); the rest annotate IANA rows — `docs/architecture.md:998-1004`,
`tests/testthat/test-transition.R:42-46`.

NAT64 embedded-segment geometry (offset, bits), tabulated because it cannot be
computed from the prefix length — `R/transition.R:126-134`,
`docs/architecture.md:1025-1032`:
`/32 → (32,32)`; `/40 → (40,24)+(72,8)`; `/48 → (48,16)+(72,16)`;
`/56 → (56,8)+(72,24)`; `/64 → (72,32)`; `/96 → (96,32)`.
Reserved u-byte at bits 64-71: `R/transition.R:143`.

### 4. Ranges and literals mentioned only in prose (not shipped data)

| prefix / literal | space | name | RFC/source | where recorded (file:line) |
|---|---|---|---|---|
| `fe80::/10` | v6 | link-local; the *only* range Apple's `inet_pton` fold and `getaddrinfo` lift apply to | measured, not RFC-cited in repo | `docs/architecture.md:406`, `R/dialects.R:196-197` (bounds `4269801472`–`4273995775` as unsigned w1) |
| `fec0::/10` | v6 | deprecated site-local; present in `linklint`'s hand-rolled table, **not** in raddr | no RFC cited in repo | `_scratch/SPEC.md:451`, `_scratch/COMPETITORS.md:747` |
| `224.0.0.0/4` | v4 | IPv4 multicast — named as a gap in other libraries' `is_global`; **not** an IANA special-purpose block | no RFC cited in repo | `_scratch/COMPETITORS.md:1103`, `_scratch/COMPETITORS.md:421` |
| `224.0.0.1`, `ff02::1` | v4/v6 | multicast literals used as evidence that CPython's `is_global` is TRUE for multicast | none | `_scratch/COMPETITORS.md:166`, `_scratch/COMPETITORS.md:421`, `_scratch/BRAINSTORM.md:91` |
| `169.254.169.254` | v4 | cloud-metadata endpoint (AWS/GCP/Azure/others) — **removed from raddr**, assigned to `ssrfr` | appears in no RFC (repo says so) | `docs/architecture.md:916-919`, `_scratch/COMPETITORS.md:1046-1052`, `_scratch/SPEC.md:435-438` |
| `fd00:ec2::254` (and `fd00:ec2::/64`) | v6 | AWS IPv6 metadata endpoint; the literal behind the `grepl("^fd00:ec2:")` bypass | provider docs, marked `[verified]` in scratch | `_scratch/BRAINSTORM.md:521-522`, `_scratch/BRAINSTORM.md:639`, `_scratch/COMPETITORS.md:1047` |
| `192.0.0.192` | v4 | Oracle Cloud legacy metadata; sits inside non-global `192.0.0.0/24` that has global /32 carve-outs | provider docs, `[verified]` | `_scratch/SPEC.md:438-441`, `_scratch/COMPETITORS.md:1050`, `_scratch/COMPETITORS.md:1061` |
| `100.100.100.200` | v4 | Alibaba Cloud metadata, inside `100.64.0.0/10` | `[unconfirmed]` in the repo | `_scratch/COMPETITORS.md:1051`, `_scratch/COMPETITORS.md:1112-1113` |
| `2001:2::/48`, `2001:10::/28`, `2002::/16`, `64:ff9b:1::/48`, `192.0.0.0/29 → /24` | v4/v6 | the measured CPython 3.12.3 → 3.12.4 registry delta | CPython gh-113171 / PR #113179 | `_scratch/COMPETITORS.md:443-451` |
| `64:ff9b::a9fe:a9fe` | v6 | NAT64-wrapped `169.254.169.254`, used as the worked bypass example | — | `_scratch/COMPETITORS.md:1021`, `_scratch/SPEC.md:960-969` |

**Total distinct prefixes/literals recorded: 62** — 51 IANA blocks, 2
overlay-only prefixes, the ISATAP identifier pattern, the 6 NAT64 prefix-length
geometries, and 10 prose-only entries (some overlapping the IANA set, counted
once).

---

## Classification levels/categories already proposed or used

| vocabulary | values | status | where defined (file:line) |
|---|---|---|---|
| Address **family** | `v4`, `v6`, `v6_4in6`; `NA` = missing address | shipped | `R/address.R:11`; docs `R/address.R:31-35`; design `docs/architecture.md:476-484` |
| Family **sort rank** | `v4 = 0`, `v6 = 1`, `v6_4in6 = 1` | shipped | `R/address.R:15`; `docs/architecture.md:592-596` |
| **Dialect** names | primitives `strict`, `whatwg`, `pton`, `aton`; compositions `getaddrinfo`, `curl` | shipped | `R/parse.R:9-16`; `R/dialects.R:126-221`; axes table `docs/architecture.md:107-111` |
| Dialect **axis** | `paper` vs `reality` | prose only | `docs/architecture.md:105-111` |
| Per-dialect **outcome** | `ok`, `rejected`, `not_an_address` | shipped | `R/parse.R:18`; `docs/architecture.md:671` |
| Derived **status** | `ok`, `divergent`, `not_an_address`, `malformed` | shipped, documented as convenience not truth | `R/parse.R:20`; `docs/architecture.md:673-689`; `R/parse.R:50-74` |
| **Reason codes** (15, `parse` layer) | `not_a_number`, `leading_zero`, `empty_part`, `empty_hex`, `out_of_range`, `wrong_part_count`, `trailing_dot`, `zone_not_permitted`, `multiple_zones`, `bad_hextet`, `empty_group`, `bad_elision`, `wrong_group_count`, `bad_embedded_ipv4`, `whitespace` | shipped, machine-checked both directions | `R/codes.R:16-92`; table `docs/architecture.md:736-752`; tests `tests/testthat/test-codes.R` |
| Reason-code **layer** | `parse`, `classify` (classify layer declared but **empty**) | shipped | `R/codes.R:175-181` |
| Transition **kind** | `ipv4_mapped`, `ipv4_compatible`, `ipv4_translated`, `6to4`, `teredo`, `6to4_relay_anycast`, `nat64_wk`, `nat64_local`; plus `isatap` and `nat64` in the embeddings table only | shipped | `R/transition.R:32-72`, `R/transition.R:122-134` |
| Embedding **role** | `embedded`, `server`, `client` | shipped | `R/transition.R:103-134` |
| IANA **policy columns** (five, never collapsed) | `source`, `destination`, `forwardable`, `globally_reachable`, `reserved_by_protocol` — each **three-valued**: `TRUE` / `FALSE` / `NA`, where `NA` covers two distinct upstream spellings (`N/A` and empty) | shipped | `R/registry.R:12-17`, `R/registry.R:25-45`; `docs/architecture.md:939-952` |
| Registry **space** | `v4`, `v6` | shipped (internal + public column) | `R/registry.R:12`, `R/classify.R:36-37`, `R/classify.R:119` |
| `raddr_class` fields (**not yet implemented**) | `block`, `name`, `rfc`, `scope` (factor, "raddr's vocabulary"), `globally_reachable`, `forwardable`, `source`, `destination`, `reserved_by_protocol`, `embedded`, `embedded_kind`, `embedded_scope`, `registry_version` | designed only | `docs/architecture.md:769-794`; `R/classify.R:3-5` (record "arrives with the rest of Epic I") |
| Draft **scope / classification** vocabulary (superseded, never implemented) | `loopback`, `unspecified`, `link-local`, `private`, `cgnat`, `multicast`, `reserved`, `documentation`, `benchmarking`, `discard`, `cloud-metadata`, `malformed-address`, plus wrapper labels `ipv4-mapped`, `ipv4-translated`, `ipv4-compatible`, `6to4`, `teredo`, `nat64`, `isatap` | draft, in `_scratch/` only | `_scratch/SPEC.md:369-376` |
| Draft **parse-code** vocabulary (superseded by `R/codes.R`) | `ipv4-octal`, `ipv4-hex`, `ipv4-leading-zero`, `ipv4-short-form`, `ipv4-non-decimal`, `ipv4-number-form`, `ipv4-non-dotted`, `ipv4-out-of-range`, `ipv4-trailing-dot`, `ipv6-zone`, `ipv6-zone-encoded`, `ipv6-embedded-v4`, `ipv6-double-elision`, `ipv6-single-field-elision`, `divergent-dialects`, `ends-in-number` | draft only | `_scratch/SPEC.md:356-367` |

**14 vocabularies.** Note the gap: **`scope` and `embedded_scope` have no
enumerated value set anywhere in `R/`.** The only concrete list is the draft in
`_scratch/SPEC.md:369-376`, which `docs/architecture.md:791-794` partially
overrides (renaming `effective_scope` → `embedded_scope`) without restating the
levels. This is the single largest classification-vocabulary hole in the repo.

---

## Gotchas already recorded

### Storage and integer representation

1. **R reserves the bit pattern `0x80000000` as `NA_integer_`, so a naive
   "words are integers" layout loses exactly one address per word position.**
   It bites because the loss is silent at rest and shows up as `NA` from `==`,
   so `if (addr == blocked)` is *skipped* rather than taken — fail-open.
   `docs/architecture.md:486-514`, `R/address.R:37-48`,
   `tests/testthat/test-address.R:43-53`.
2. **`ipaddress` 1.0.3 ships this bug.** `ip_address("0.0.0.128") ==
   ip_address("0.0.0.128")` is `NA`. It prints correctly and `is.na()` is
   `FALSE`, because the C++ formatter reads raw bits while the R field holds
   `NA_integer_`. `docs/architecture.md:493-514`; filed as O11(b) at
   `docs/architecture.md:1163`.
3. **Which literal triggers it depends on byte order — always name the layout.**
   `ipaddress` stores little-endian so its colliding IPv4 address is
   `0.0.0.128`; raddr stores big-endian so raddr's is `128.0.0.0`. Quoting the
   wrong literal against the wrong layout looks like a false alarm.
   `docs/architecture.md:504-509`, `tests/testthat/test-address.R:50-53`.
4. **raddr's resolution has a non-obvious invariant that a "simplifying"
   contributor can delete.** Words hold raw bits; `NA_integer_` in `w1`-`w4`
   means the pattern, *not* missingness; missingness lives in `family` alone.
   A named regression test exists precisely to go red. `R/address.R:37-48`,
   `R/address.R:195-275`, `tests/testthat/test-address.R:43-53`.
5. **The vendored IANA data itself trips this.** `2620:4f:8000::/48`, the AS112
   direct-delegation prefix, has second word `0x80000000`. A registry built on
   "words are numbers" either loses or corrupts that block. The build script
   must *assign* rather than coerce, because `as.integer(-2147483648)` is an
   out-of-range `NA` plus a warning. `docs/architecture.md:960-966`,
   `data-raw/build-registry.R:255-265`.
6. **Equality and ordering need different proxies.** Equality only needs
   distinctness, so it stays in `integer` and lifts the collision into a
   separate `pattern` column; ordering needs magnitude, so it widens to
   `double`. Building both as `double` data frames measured **19x** slower.
   `R/address.R:206-266`, `docs/architecture.md:1206-1220`.

### Bitwise-operator traps

7. **Every bitwise operator in R is unusable on raddr's words, in both
   directions, and neither failure is loud.** `bitwAnd(0x80000000-pattern, …)`
   is `NA` (a word reads as missing rather than as bits), and
   `bitwNot(2147483647L)` is `NA` (the mask for a `/1` prefix cannot even be
   spelled). `R/classify.R:9-28`.
8. **`bitwShiftL(1L, 31)` returns `NA` silently** — no warning, unlike
   `as.integer()` at the same boundary. This is why the whole codebase uses
   arithmetic (`2^(8*n)`, `256^(4-i)`) instead of shifts.
   `docs/architecture.md:537-540`, `docs/architecture.md:1394-1395`,
   `R/ipv4.R:174-176`, `R/classify.R:44-45`, `data-raw/build-registry.R:242-244`.
9. **`bitwAnd()` also returns `NA` for an out-of-range *operand*, which the
   "never bitwShiftL" rule does not obviously cover.** The ISATAP mask was
   first written as the literal `0xfdffffff` — a `double` above 2^31 — and
   every ISATAP address would have silently failed to match. It is spelled
   `bitwNot(0x02000000L)` instead. `docs/architecture.md:1047-1052`,
   `R/transition.R:152-156`, `tests/testthat/test-transition.R:166-167`.
10. **`ifelse()` evaluates both branches over the whole vector**, and in the
    prefix-masking path the unused branch overflows to `NA` with a warning —
    noise that would hide a real `NA`. Indexed assignment is used instead.
    `data-raw/build-registry.R:255-257`.

### Parsing

11. **`inet_aton` range-checks every arity *except* the whole-host number.**
    With 2–4 parts the final part is bounded by `256^(5-k)-1`; with one part
    there is no check at all and the value is truncated to 32 bits. So
    `4294967296` is `0.0.0.0` while `1.4294967296` is a rejection.
    `docs/architecture.md:186-190`, `R/ipv4.R:355-358` (`wrap = TRUE`).
12. **The `inet_aton` truncation is exactly modulo 2^32**, which is what lets
    raddr accumulate in a `double` and stay exact.
    `docs/architecture.md:191-194`, `R/ipv4.R:11-13`.
13. **`inet_aton` stops at the first whitespace character and ignores the
    rest**, so `1.2.3.4 junk` is an address. Leading whitespace still fails and
    glued-on non-whitespace (`1.2.3.4x`) fails. `docs/architecture.md:195-198`,
    `R/dialects.R:33-37`.
14. **That whitespace quirk is the only way an IPv4 rule set can accept a
    colon**, so `"1.2.3.4 :5"` is an IPv4 address carrying a colon — a
    colon-test alone is not an exact IPv4/IPv6 discriminator.
    `R/ipv4.R:403-414`.
15. **A digitless `0x` is tolerated by `inet_aton` in any part but the last.**
    `0x.1` and `0x.0x.0` parse; `0x`, `0x.0x`, `1.2.0x` do not. WHATWG has no
    such carve-out — a bare `0x` is simply zero.
    `docs/architecture.md:199-201`, `R/ipv4.R:357-358` (`empty_hex_final`).
16. **`inet_pton` puts no width limit on leading zeros.**
    `00000000177.0.0.1` is `177.0.0.1`; nineteen zeros before a `1` is still
    `1`. Same rule one grammar up for IPv6 hextets: Apple `inet_pton` caps the
    *significant* digits at four, so `0000000000001::` is `1::` while
    `12345::`, `abcde::`, `ffff1::` are rejections.
    `docs/architecture.md:202-203`, `docs/architecture.md:250-255`,
    `R/ipv6.R:15-18`, `R/ipv6.R:218-236`.
17. **The dotted-quad tail of an IPv6 literal is not a grammar of its own** —
    it is the dialect's own four-part decimal IPv4 grammar. Consequently
    WHATWG's IPv6 tail is **stricter than WHATWG's own standalone IPv4
    parser**: no hex, octal, short form or trailing dot reaches it. rust-url
    implements it as a separate loop for this reason.
    `docs/architecture.md:256-262`, `R/ipv6.R:21-23`.
18. **`::` must stand for at least one group.** `1:2:3:4:5:6:7:8::` is a
    rejection, not a no-op. `docs/architecture.md:263-264`, `R/ipv6.R:156-160`.
19. **`":1"` fails two gates at once**, and reporting it as a group-count error
    would send a reader off to add groups; an edge colon on an unelided literal
    is named for what it is. `R/ipv6.R:184-187`.
20. **A code fires once per part, first match wins**, so a non-numeric part
    does not also report the range its garbage value landed outside of.
    `docs/architecture.md:761-765`, `R/ipv6.R:78-81`, `R/codes.R:126-138`.
21. **The one-bit-per-code mask caps the reason vocabulary at 31**, because R's
    integer is signed 32-bit. Asserted at load. `R/codes.R:105-109`,
    `docs/architecture.md:706-707`.

### Dialect divergence and composition

22. **`getaddrinfo` is `pton`-then-`aton` *except* for whitespace.**
    `getaddrinfo()` rejects any whitespace-bearing input before either
    primitive sees it, so `1.2.3.4 ` is a rejection where bare `aton` accepts.
    Modelled as a pre-gate, not a different precedence.
    `docs/architecture.md:126-140`, `R/dialects.R:167-177`.
23. **The whitespace gate covers the address, not the zone ID.**
    `fe80::1%lo0 ` is accepted, `fe80::1 %lo0` is not, so the test runs on the
    text before the `%`. `docs/architecture.md:142-145`, `R/dialects.R:173-176`.
24. **`curl` is the opposite precedence (`aton`-then-`pton`), which is why
    `192.0.048.1` reaches a host under curl that a browser refuses to dial.**
    `docs/architecture.md:169`, `R/dialects.R:78-80`.
    **Second half retracted 2026-07-28 (RADD-hnczgkcf).** The precedence claim
    holds; the consequence does not. curl's URL parser gates the host before the
    resolver sees it, so `curl http://192.0.048.1/` looks up a *name* and never
    dials `192.0.48.1`. Measured against curl 8.20.0 over a 35-host numeric
    sweep, there is no input the URL parser admits that `whatwg` refuses. The
    `curl` dialect is the resolver, and `0177.0.0.1` (`127.0.0.1` here,
    `177.0.0.1` under `getaddrinfo`) is the divergence it actually shows.
25. **`inet_aton` has no IPv6 reading at all** — `AF_INET` by signature — so
    for IPv6 both compositions collapse onto their `pton` half. Measured, not
    assumed, because both compositions lean on it.
    `docs/architecture.md:246-249`, `R/dialects.R:144-152`.
26. **Two silences look alike and are not.** `aton` shrugging at `::1` is not
    dissent (counting it would make every IPv6 address `divergent`); `strict`
    declining `1.2.3.4 junk` while `aton` finds an address in it *is*. Getting
    this wrong is a print-method and status bug at once.
    `docs/architecture.md:710-726`, `R/parse.R:228-248`.
27. **`pton` is the one platform-dependent dialect**, and raddr models Apple
    libc only. `docs/architecture.md:173-174`, `R/dialects.R:29-32`.
28. **A single scalar parse status cannot be written honestly.** `4294967296`
    is accepted by `aton`, out-of-range for `whatwg`, and not-a-dotted-quad for
    `strict`, simultaneously. The draft spec called it `malformed`, which was
    wrong. `docs/architecture.md:657-686`, `R/parse.R:1-7`.

### Zone ID

29. **Apple's `inet_pton` folds a resolved interface index *into* the address
    bytes** — `fe80::1%lo0` becomes `fe80:1::1` — which makes a byte-comparing
    filter treat one host as two and two hosts as one.
    `docs/architecture.md:560-562`, `docs/architecture.md:400-410`.
30. **That fold has three properties a one-line description misses:** it
    applies to `fe80::/10` **only** (not `fec0::`, not `ff0x::`); it fires only
    when the zone names a *resolvable* interface (`%lo0` folds; `%1`, `%bogus0`,
    `%LO0` do not); and it **overwrites the second hextet** rather than filling
    a spare one, so `fe80:abcd::1%lo0` is `fe80:1::1` and `abcd` is gone.
    `docs/architecture.md:400-417`.
31. **raddr deliberately does not reproduce the fold**, because
    `if_nametoindex()` reads the host's interface table — the same string means
    different bits on a different machine, which breaks purity.
    `docs/architecture.md:419-425`, `R/dialects.R:64-67`.
32. **raddr *does* reproduce the inverse "lift":** Apple's `getaddrinfo` takes
    the second hextet of an `fe80::/10` address as the scope ID and clears it
    from the bytes **whether or not a zone was written**. So `fe80:abcd::1` is
    `fe80::1` zone `43981` under `getaddrinfo` and `fe80:abcd::1` with no zone
    under `inet_pton` — one string, one machine, two different hosts.
    `docs/architecture.md:426-441`, `R/dialects.R:180-215`.
33. **Zone support tracks *storage*, not paper-vs-reality and not
    RFC-vs-WHATWG.** Every implementation with somewhere to put a zone accepts
    one; every implementation without either rejects it or loses it. Rust
    proves it inside one language: `Ipv6Addr` rejects all zones, `SocketAddrV6`
    accepts `%1` but rejects `%lo0` because a name does not fit a `u32`.
    `docs/architecture.md:280-313`.
34. **The two implementations that accept a zone without a slot are also
    *looser* than a validator in their own library.** R's `ipaddress` accepts a
    second `%` that Apple's `inet_pton` rejects; Node's `SocketAddress` accepts
    `fe80::1%lo0%en0`, which `net.isIPv6()` in the same module rejects.
    Accepting a zone you cannot store loosens the grammar, because there is
    nothing left to validate the discarded text against.
    `docs/architecture.md:323-329`.
35. **`ipaddress` 1.0.3 silently discards the zone at the first `%`.**
    `ip_address("fe80::1%lo0%en0%wat")` is `fe80::1`, with no accessor to
    recover it, and `ip_address("fe80::1%lo0") == ip_address("fe80::1")` is
    `TRUE`. Filed as O16. `docs/architecture.md:344-361`,
    `docs/architecture.md:1167`.
36. **CPython keeps the zone but cannot render it.**
    `IPv6Address("fe80::1%lo0").exploded` and `.reverse_pointer` raise
    `AddressValueError` on 3.9.6, 3.12.13 and 3.14.6, because
    `_explode_shorthand_ip_string()` re-parses `str(self)` without splitting
    the scope off. A valid object raises on two of its own accessors.
    `docs/architecture.md:363-378`, `docs/architecture.md:1166` (O15).
37. **A survey script written against `.exploded` reported "Python rejects
    every zone" — wrong in the most misleading direction, because it looks like
    a grammar difference.** `data-raw/oracle-ipv6.py` reads `.packed` instead.
    `docs/architecture.md:380-386`, `data-raw/oracle-ipv6.py:79-91`.
38. **Apple `getaddrinfo` truncates a numeric zone modulo 2^16**:
    `fe80::1%99999999999` reports scope `59391`. raddr keeps the literal text.
    `docs/architecture.md:1169` (O14).
39. **`ada`/WHATWG rejects even the RFC 6874 spelling `%25lo0`**, so the WHATWG
    URL parser has not adopted RFC 6874. `docs/architecture.md:319-322`.
40. **The zone does not participate in `==`**, deliberately: admitting it would
    make `unique()` partition by interface name and would make a consumer
    filtering against a zoneless blocklist silently miss every zoned address.
    `docs/architecture.md:571-586`, `R/address.R:50-56`.

### Formatting and rendering

41. **RFC 5952 publishes no test vectors**, so raddr authors its own by RFC
    section. `docs/architecture.md:636-643`, `docs/architecture.md:1160` (O8).
42. **The mixed form is decided by the family (the bits), never by the
    spelling.** `::ffff:7f00:1` and `::ffff:127.0.0.1` render identically, and
    the deprecated v4-compatible form is plain `v6`, so `::1.2.3.4` renders as
    `::102:304`. `docs/architecture.md:626-635`, `R/format.R:145-150`.
43. **A variable-width canonical form cannot line up in a column, sort as text
    in address order, or be prefix-matched** — which is why `addr_expand()`
    exists as a second public renderer. `docs/architecture.md:612-624`,
    `R/format.R:4-8`.
44. **raddr's renderers never re-parse** — they read the fields and append the
    zone last — precisely to avoid CPython's `.exploded` failure mode.
    `docs/architecture.md:390-394`, `R/format.R:106-108`.
45. **The v4-compatible extractor needs a `tail32 > 1` carve-out** so `::` and
    `::1` are not misread as embedded `0.0.0.0` / `0.0.0.1`. Load-bearing and
    easy to drop on a rewrite. `_scratch/BRAINSTORM.md:503-506`,
    `docs/architecture.md:1096`, `R/transition.R:38-42`.

### Vendoring, registry, and build

46. **The IANA policy columns are three-valued, not boolean**, with four
    upstream spellings (`True`, `False`, `N/A`, empty). `N/A` and empty are both
    IANA *declining to answer*, which is not the same as answering `False`;
    collapsing them would make raddr assert a policy the registry withheld.
    `docs/architecture.md:939-952`, `R/registry.R:25-45`,
    `data-raw/build-registry.R:91-95`.
47. **A line count is not a record count and a record is not a block.** Three
    records wrap across lines (multi-RFC quoted fields), and one v4 record names
    two prefixes in one field. 26+27 *lines* = 25+25 *records* = **51 blocks**.
    `docs/architecture.md:930-938`, `R/registry.R:47-52`.
48. **Footnote markers are data; footnote text is not in the CSV.** Markers
    appear both in `Address Block` (`192.0.0.0/24 [2]`) and inside policy values
    (`False [1]`). raddr strips them into a `footnotes` column and does not
    invent their wording. `docs/architecture.md:954-958`, `R/registry.R:60-65`.
49. **Lookup must be longest-prefix-match, not first-match-wins**, because the
    registry contains deliberate carve-outs: `192.0.0.9/32` and `192.0.0.10/32`
    are globally reachable inside a non-global `192.0.0.0/24`.
    `docs/architecture.md:903-906`, `R/classify.R:4-7`, `R/registry.R:54-58`.
50. **The 4-in-6 family matches IPv6 blocks, not IPv4 ones.**
    `::ffff:127.0.0.1` is in `::ffff:0:0/96`; that its embedded address is
    loopback is a *separate* fact reported by `embedded_scope`. Answering
    `loopback` at the outer level collapses the two facts raddr exists to keep
    apart. `R/classify.R:98-103`.
51. **The repo's own hygiene tried to rewrite the vendored bytes.** The CSVs use
    CRLF row terminators but bare LF inside wrapped quoted fields — genuinely
    mixed, upstream. `.gitattributes`' `* text=auto eol=lf` plus the
    `mixed-line-ending` / `end-of-file-fixer` hooks normalize that and thereby
    falsify the sha256 the build script just recorded. A vendoring pattern needs
    an exemption from the repo's formatting.
    `docs/architecture.md:974-981`.
52. **An undated snapshot must read as outdated, never as fresh.** The CSVs
    carry no version field, so the stamp is the served `Last-Modified`; it is
    the **older** of the two halves and `NA` if either is undated, and
    `addr_registry_outdated()` then returns `TRUE`.
    `docs/architecture.md:983-988`, `R/registry.R:92-104`,
    `data-raw/build-registry.R:429-432`.
53. **Month-name parsing must not go through `strptime`'s `%b`**, which is
    locale-dependent; an explicit month map is used so the stored stamp does not
    depend on the machine that built it. `data-raw/build-registry.R:287-290`.
54. **`--check` compares content, never dates.** A rebuild on a different day,
    or on a machine that got no `Last-Modified` header, must not fail the
    staleness guard — provenance is not content.
    `docs/architecture.md:968-972`, `data-raw/build-registry.R:22-26`.
55. **The registry index is memoized rather than built at load**, because
    top-level code in `R/` runs during installation and the order in which
    `R/sysdata.rda` becomes visible is not dependable. `R/classify.R:54-58`.
56. **Hand-transcribed bit offsets are wrong in ways re-reading does not
    catch**, so `test-transition.R` checks RFC 6052's *rules* (segments totalling
    32 bits, ordered, disjoint, clear of bits 64-71) rather than restating the
    numbers. `tests/testthat/test-transition.R:1-7`,
    `docs/architecture.md:1036-1040`.
57. **The embedded NAT64 address begins immediately after the prefix at every
    length except `/64`**, where the u-byte sits between them — the single
    exception that forces the geometry to be tabulated rather than computed.
    `docs/architecture.md:1034-1036`, `tests/testthat/test-transition.R:100-102`.
58. **Teredo's client address is stored bitwise-complemented** so a NAT will not
    rewrite it in transit; it is the only complemented field in the overlay, and
    Teredo carries *two* embedded addresses, not one. `R/transition.R:88-92`,
    `R/transition.R:112-117`, `tests/testthat/test-transition.R:127`.

### Bugs recorded in other implementations

59. **`ipaddress` has no diagnostic layer and is loudest where it matters
    least.** Zero of its 66 exports match `valid|diag|warn|reason|status|error|
    parse`; it emits one warning per bad row (10,000 warnings for 10,000 bad
    rows) and is **silent** on `0177.0.0.1 → 177.0.0.1` and
    `10.048.1.1 → 10.48.1.1` — loud about failures, silent about changing which
    host you reach. `docs/architecture.md:1135-1141`.
60. **Go's `net.IP.To4()` silently collapsed `1.2.3.4` and `::ffff:1.2.3.4`
    into the same value; that conflation was the bug** and is why raddr's family
    is three-state. `_scratch/COMPETITORS.md:246-257`.
61. **CPython gh-119812 (open): `100.64.0.1` is `is_private` FALSE *and*
    `is_global` FALSE**; multicast (`224.0.0.1`, `ff02::1`) is `is_global` TRUE.
    `_scratch/COMPETITORS.md:421`.
62. **Rust's `is_global` has been unstable since 2015** (issue #27709), with
    the /32 carve-outs named as a blocker and `is_documentation` lagging RFC
    9637 (`3fff::/20`). `_scratch/COMPETITORS.md:415-431`.
63. **Go `IsGlobalUnicast()` returns TRUE for RFC 1918** and `IsPrivate` misses
    CGNAT, 6to4, Teredo, NAT64, `::/96`, ISATAP (issue #79925, closed *not
    planned*). `_scratch/COMPETITORS.md:421`.
64. **The seven-CVE pattern is one bug:** CVE-2021-28918 (npm `netmask`),
    CVE-2021-29921 (Python `ipaddress`, 9.8), CVE-2021-29922 (Rust std),
    CVE-2021-29923 (Go), CVE-2023-42282 and CVE-2024-29415 (npm `ip`) — all
    leading-zero / string-matched classification.
    `_scratch/COMPETITORS.md:461-480`.
65. **The in-house guards' four defects share one root cause: a string was in
    scope where a value should have been.** `grepl("^fd00:ec2:", low)` blocked
    `fd00:ec2::254` and allowed `fd00:0ec2::254` — same 128 bits, live bypass;
    and `^fe[89ab][0-9a-f]?:` made the fourth hex digit optional, so `fe8::`
    (`0x0fe8`) was reported link-local. This is the evidence behind P1.
    `_scratch/BRAINSTORM.md:512-539`.
66. **Fail-open on unparseable input, in three implementations.** `ipaddress`
    returns `NA`; the in-house expander returns `NULL` → no rule matches →
    default allow. `_scratch/BRAINSTORM.md:541-554`; this is the evidence
    behind P2 (`docs/architecture.md:68-74`).
67. **CPython's 2024 registry correction is a diff worth reusing**, but the
    briefing premise that `0.0.0.0/8` changed in that fix is **wrong** — it was
    already in `_private_networks` at the pristine v3.12.0 tag. The repo
    explicitly says "don't cite it." `_scratch/COMPETITORS.md:443-459`.
68. **Mozilla bug 1288049**: `http://2130706433/` → `http://127.0.0.1/`.
    `_scratch/BRAINSTORM.md:548`, `_scratch/COMPETITORS.md:1153`.

**68 gotchas recorded.**

---

## Explicitly rejected or out of scope

**Permanently excluded, with an owner named** — `docs/architecture.md:44-60`:
DNS resolution / hostname lookup (`ssrfr`/`curl`); HTTP, redirects, connection
pinning (`ssrfr`); allow/deny policy, risk scores, verdicts (`ssrfr`);
cloud-metadata endpoint tables (`ssrfr`); "most restrictive reading wins"
convenience (`ssrfr`); geolocation / ASN / country data (nowhere); IDNA and
punycode (`punycoder`); public-suffix logic (`pslr`); URL parsing, scheme/port
policy, reg-name-vs-IP host form (`rurl`); general CIDR set algebra — collapse,
exclude, subnets (`ipaddress`); `X-Forwarded-For` extraction (`ssrfr`);
visualization (`ggip`).

Other explicit rejections:

- **The cloud-metadata overlay is removed from raddr.** `169.254.169.254`
  appears in no RFC and the table was hand-assembled from provider docs and
  partly from memory; removing it deletes raddr's only data table with no
  upstream authority. `docs/architecture.md:916-919`.
- **No `rfc3986` dialect** — reg-name-vs-IPv4 is a host-form question `rurl`
  already answers. `docs/architecture.md:206-209`.
- **No profile layer** (`"browser"` vs `"whatwg"`): the differences are all
  scheme-layer knobs and raddr never sees a scheme. "Browser" appears in prose,
  never as an identifier. `docs/architecture.md:210-214`.
- **No bracketed IPv6 hosts.** `[::1]` is a URL-layer form; libc rejects it
  outright. `docs/architecture.md:215-217`.
- **No leniency flag or dialect argument** (P3): dialect is chosen by function
  name. `docs/architecture.md:76-78`, `R/dialects.R:9-11`.
- **No `strict`-accepts-zone.** `strict` rejects the zone as a decision about
  the paper, not a consequence of storage. `docs/architecture.md:331-342`.
- **No network refresh in v0.1**; no `addr_registry_refresh()` at all — "zero
  network code" is a cleaner claim than "network code that defaults off".
  `docs/architecture.md:921-923`, `R/registry.R:106-112`.
- **No `addr_transition_outdated()`** — the RFCs the overlay is drawn from do
  not expire. `docs/architecture.md:1042-1045`, `R/transition.R:179-181`.
- **No `data-raw/` build script for the overlay** — a script that "builds" a
  table from a literal in its own source is ceremony around a constant.
  `docs/architecture.md:992-996`.
- **No `no_ipv6_reading` reason code** — an `AF_INET`-only dialect has no
  *objection* to a colon literal, it has no reading of one; that is an outcome,
  not a code. `docs/architecture.md:756-759`, `R/codes.R:76-78`.
- **No bare `is_*` exports and no `ip_`/`is_` prefix** — `addr_` throughout,
  measured at zero collisions against `ipaddress`'s 29 `^ip_|^is_` exports.
  `docs/architecture.md:889-893`, `_scratch/SPEC.md:489-494`.
- **Rejected: rurl's `url_standard = NULL` → all-`NA` default.** A
  backward-compatibility scar, not a design principle.
  `docs/architecture.md:464-466`.
- **Dependencies refused:** `ipaddress` (would import its `is_global` semantics
  and its gaps), `adaR` (oracle only), `rurl` (dependency runs the other way),
  Rcpp / BH / AsioHeaders. `docs/architecture.md:1403-1415`.
- **`v6_4in6` is deliberately not interleaved with IPv4 by embedded value**,
  because that would make ordering disagree with equality.
  `docs/architecture.md:603-607`.
- **Deferred (not excluded):** compiled fast path (plain C, v0.2, API already
  frozen) and `addr_registry_refresh()`. The repo insists deferred and excluded
  lists stay disjoint. `docs/architecture.md:1076-1085`.
- **Returned to scope after being cut:** ISATAP. `docs/architecture.md:1087-1089`.

---

## Known open questions

Numbered items are the repo's own `O`-numbers from `docs/architecture.md:1151-1169`.

1. **O6 — glibc and musl `pton` rows are unverified.** `docs/architecture.md`'s
   `pton` column is Apple-only, and the stakes rose with IPv6: the leading-zero
   rule, the `inet_pton` fold and the `getaddrinfo` lift are all *Apple*
   behaviors. Docker is installed locally but the measurement has not been run.
   `docs/architecture.md:1158`, `docs/architecture.md:405-417`.
2. **O13 — the `curl` = aton-then-pton composition for IPv6 is unverified
   against real curl.** The IPv4 half was measured; the IPv6 half is derived,
   and since `aton` rejects every IPv6 literal it reduces to a claim that curl
   reaches `inet_pton` rather than `getaddrinfo`. Those two now disagree, so the
   claim is testable. `docs/architecture.md:1165`.
3. **The `scope` / `embedded_scope` vocabulary is undecided.** `raddr_class` is
   designed but not implemented, `scope` is described only as "raddr's
   vocabulary", and the sole enumerated list lives in the superseded draft.
   `docs/architecture.md:769-794`, `_scratch/SPEC.md:369-376`,
   `R/classify.R:3-5`.
4. **O1 — pure R vs compiled.** Measured: the record meets both targets, the
   parsers miss the speed target by 18x (IPv4) / 41x-78x (IPv6). Split rather
   than settled; v0.2 decision, plain C not Rcpp.
   `docs/architecture.md:1153`, `docs/architecture.md:1285-1379`.
5. **O4 — `stringi` vs base R for ASCII host tokenization.** Benchmark base R
   first. `docs/architecture.md:1156`.
6. **O5 — trie vs sorted masked vector for the 51 IANA rows plus the overlay.**
   Note the item still says "53 IANA rows", which contradicts §7.1's 51.
   `docs/architecture.md:1157`.
7. **O9 — `hedgehog` 0.2 on R 4.6.0 aarch64: not currently installed.**
   `docs/architecture.md:1161`.
8. **O10 — WPT vendoring licence mechanics under CRAN**; BSD-3 should be fine,
   `LICENSE.note` handling needs checking. `docs/architecture.md:1162`.
9. **O11 / O16 — three `davidchall/ipaddress` bugs to file:** the NAT64 gap
   (one predicate plus one extractor); the `0x80000000` equality bug; the
   silently discarded IPv6 zone. `docs/architecture.md:1163`,
   `docs/architecture.md:1167`.
10. **O15 — CPython bug to file:** `IPv6Address.exploded` /
    `.reverse_pointer` raise on any zoned address.
    `docs/architecture.md:1166`.
11. **O12 — `rurl::get_host_type()` NULL-default wart**, to file on rurl.
    `docs/architecture.md:1164`.
12. **O17 — why does the `raddr_parse` record cost more to build for IPv6 than
    for IPv4?** 5.7 s vs 2.5 s per 1e6. Suspicion (unmeasured) is
    `derive_status()` entering `blank_missing()` over an all-missing `aton`
    reading. Profile before touching anything. `docs/architecture.md:1168`.
13. **Python's zone grammar arriving with `scope_id` in 3.9 is from the
    changelog, not measured** — the oldest interpreter on the machine is 3.9.6.
    Every other row of the zone survey is measured.
    `docs/architecture.md:309-312`.
14. **6to4: blanket-block or unwrap-and-classify?** CPython 3.12.4+ now treats
    *all* of `2002::/16` as private regardless of the embedded v4. raddr chose
    unwrap-and-classify; recorded as a live design question that sets the
    precedent for NAT64 and Teredo. `_scratch/COMPETITORS.md:449-453`,
    `_scratch/SPEC.md:805`.
15. **Half the cloud-metadata provider list is `[unconfirmed]`** (Azure's
    header requirement, Alibaba's `100.100.100.200`, DigitalOcean/Hetzner/
    OpenStack/IBM). Moot for raddr since the overlay was removed, but the
    unverified state is recorded. `_scratch/COMPETITORS.md:1049-1052`,
    `_scratch/SPEC.md:895-900`.
16. **`::ffff:0:0:0/96` (`ipv4_translated`) has no RFC assigning it.** The repo
    states this outright and carries the row only because the in-house guards
    recognize it — the one shipped prefix in raddr with no standards source.
    `R/transition.R:45-46`, `docs/architecture.md:1097`.
17. **The `classify` reason-code layer is declared but empty.** `R/codes.R:179-181`.

### Assertions the repo makes without citing a source

- `::ffff:0:0:0/96` as `ipv4_translated` — explicitly "No RFC assigns this."
  `R/transition.R:45-46`.
- The `fe80::/10` word bounds `4269801472`–`4273995775` in
  `R/dialects.R:196-197` are unsourced magic numbers (derivable, but no comment
  ties them to RFC 4291).
- `fec0::/10` appears only as a competitor's table entry with no RFC citation
  anywhere in this repo. `_scratch/SPEC.md:451`,
  `_scratch/COMPETITORS.md:747`.
- `224.0.0.0/4` (IPv4 multicast) is discussed as a competitor gap with no RFC
  citation and is in neither vendored CSV nor the overlay.
  `_scratch/COMPETITORS.md:1103`.
- The v4-before-v6 ordering rule is stated as "arbitrary; what matters is that
  it is fixed". `docs/architecture.md:598-601`.
