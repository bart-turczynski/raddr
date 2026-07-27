# Delta C — parsers, library divergence, encodings

Slice: `05-parser-gotchas.md`, `06-library-divergence.md`, `08-encoding-reverse.md`,
judged against `00-local-inventory.md` (the repo baseline).

Tags: `[CORPUS]` test-corpus row · `[CODE]` code change · `[DOC]` architecture.md
change · `[CODES]` reason-code vocabulary · `[OPEN]` human decision.

---

## Contradicts

**C1. Research 05's `pton` column is wrong for Apple/BSD, and the repo's measurement wins.**
05 §"IPv4 literals" gives `pton` = reject for `010.0.0.1`, `0177.0.0.1`, `1.2.3.04`,
while its column key claims that column covers "glibc, musl, **BSD/Apple**, Windows".
The repo measured the opposite on Apple: `tests/testthat/fixtures/ipv4-oracle.csv`
row `"0177.0.0.1","177.0.0.1",…` and `docs/architecture.md:150` both record Apple
`inet_pton` → `177.0.0.1`. Do **not** import that column. `[DOC]`

**C2. 05 contradicts itself on the same cell.** The note under the same matrix says
*"glibc **additionally** rejects leading zeros"* — conceding that `inet_pton(3)`'s
POSIX text does not forbid them and that the merged column is a fiction. The one
sourced fact is CPython's *"as strict as glibc `inet_pton()`"*, which is a claim
about **glibc only**. `[DOC]`

**C3. The repo asserts `inet_aton` trailing-garbage behaviour unqualified, and it is
Apple-only.** Repo: *"glued-on non-whitespace (`1.2.3.4x`) fails too"*
(`docs/architecture.md:195-198`, inventory gotcha 13). 05 G-10 quotes the glibc
source comment *"inet_aton ignores trailing garbage"* — public glibc `inet_aton`
**succeeds** on `1.2.3.4junk`, which is why glibc had to add `__inet_aton_exact`.
musl rejects it. Three answers; the repo's prose reads as one. `[DOC]`

**C4. `pton` is *not* "the one platform-dependent dialect".** Repo:
`docs/architecture.md:173-174`, inventory gotcha 27. 05 G-10/G-11 show `aton`
diverging between glibc and musl on **two** inputs (`1.2.3.4junk`, `1.2.3.4 `),
independent of `pton`. The `aton` row of §3.3 needs the same platform caveat the
`pton` row carries. `[DOC]` `[OPEN]`

**C5. RFC 6874 is not merely "lost" — it is formally obsoleted.** Repo records only
that ada/WHATWG rejects `%25lo0` and that browsers declined
(`docs/architecture.md:319-322`). 08 round-trip §12: RFC 9844 (Aug 2025, Standards
Track) *"completely obsoletes [RFC6874]"* and drops the URI syntax entirely, so
zone-in-URI has **no live standard**. `[DOC]`

---

## New

**N1. musl gates the zone ID on scope; glibc and Apple do not.** 05 G-28: musl's
`__lookup_ipliteral` returns `EAI_NONAME` unless the address is link-local or
link-local multicast, so `::1%lo0` resolves on Debian and fails on Alpine. The repo
measured Apple accepting it (`ipv6-oracle.csv`, `::1%lo0` → zone `lo0`). A third
answer for a literal the corpus already carries. `[CORPUS]` `[OPEN]`

**N2. glibc/musl `getaddrinfo` flag defaults differ.** 05 G-38: glibc defaults to
`AI_ADDRCONFIG|AI_V4MAPPED`, musl to `0`; glibc synthesises IPv4-mapped IPv6 where
musl does not. raddr's `getaddrinfo` dialect models an entry point whose returned
**family** is flag-dependent, not just its grammar. `[DOC]`

**N3. Multicast `224.0.0.0/4` is missing from the special-purpose registry by
design, and that hole has already shipped as a CVE — twice.** 06 G-14: multicast
lives in the *main IPv4 address-space registry*; PHP's registry-derived rewrite has
no multicast handling at all, and `ssrfcheck` shipped the identical omission as
CVE-2025-8267. The repo flags `224.0.0.0/4` as an uncited competitor gap
(inventory §4, `_scratch/COMPETITORS.md:1103`) without knowing *why* every
registry-derived table misses it. raddr's classify layer inherits the hole unless a
second registry is vendored. `[OPEN]` `[DOC]`

**N4. `fec0::/10` finally has its citations.** Repo: *"appears only as a
competitor's table entry with no RFC citation anywhere in this repo"* (inventory,
Assertions-without-a-source). 06 §10: deprecated by RFC 3879 (2004); RFC 4291
§2.5.7 says new implementations must treat it as global unicast; it is **not in the
IANA registry at all**. That closes the gap and confirms raddr should keep it out.
`[DOC]`

**N5. `ipaddress`, which the repo cites as an oracle, is stale and wrong at the
classify layer.** 06 R-packages table: `is_private()` uses `192.0.0.0/29` where
IANA uses `/24` with carve-outs; **omits `64:ff9b:1::/48`, `2002::/16`,
`3fff::/20`**; has **no exception mechanism at all**, so `is_global()` returns
`TRUE` for `2002::/16` and `3fff::/20`. It is a Python ~3.8-era snapshot that
claims no registry version. Repo already files O11/O16 against it for *parse/storage*
bugs; this is a distinct, third class. Use `ipaddress` as a parse oracle only, never
a classification one. `[DOC]` (extend O11)

**N6. `adaR` — nothing found.** Neither 06 nor 05 reports `adaR`/`ada` as stale or
wrong; 05 cites `ada` as the WHATWG reference implementation without qualification.
The repo's use of it as the `whatwg` oracle survives this slice unchallenged.

**N7. Two classify-layer CVEs post-date the repo's CVE list, and both are pure
registry-staleness failures.** CVE-2026-54452 (`doyensec/safeurl` < 0.2.4: missing
`64:ff9b:1::/48`, `5f00::/16`, `3fff::/20`, `100:0:0:1::/64`) and CVE-2026-48736 /
GHSA-38cx-cq6f-5755 (Symfony `IpUtils`: missing `::/96`, `2002::/16`, `2001::/32`,
`64:ff9b::/96`, `64:ff9b:1::/48`). Repo gotcha 64 lists only the 2021 parse-layer
CVEs. These are the direct evidence for `addr_registry_outdated()` and for the
transition overlay existing at all. `[DOC]`

**N8. The `scope` vocabulary hole now has a recommended shape and a named
failure mode.** 06 §1 names `ipaddr.js`'s `range()` label model as *"the model
`raddr` should follow"*; 06 G-11 and G-12 then show the two ways labels fail — range
**names are unstable across versions** (`deprecated` → `deprecatedOrchid`), and
denying a *named list* rather than everything non-unicast lets `::ffff:127.0.0.1`
through under the `ipv4Mapped` label. Directly informs the repo's single largest
vocabulary hole (`scope` / `embedded_scope`, inventory §"14 vocabularies").
`[OPEN]`

**N9. Reverse-pointer names are a pure, offline, RFC-specified encoding raddr
neither implements nor excludes.** 08 §"Reverse pointers" gives the full rule set:
octet reversal + `in-addr.arpa` (RFC 1035 §3.5), nibble reversal + **always 32
labels** `ip6.arpa` (RFC 3596 §2.5), trailing dot, case-insensitive comparison,
partial names decoding to a *prefix* not an address. The exclusion list
(`docs/architecture.md:44-60`) does not mention them. In or out? `[OPEN]`

**N10. Reverse DNS for IPv4-mapped addresses is unspecified by any RFC.** 08 G-24:
no RFC settles whether `::ffff:192.0.2.1` maps into `ip6.arpa` or
`1.2.0.192.in-addr.arpa.` — mechanically the former, usefully the latter. If N9
lands, this is a design decision with no standard to defer to. `[OPEN]`

**N11. `fc00::/8` has no assignment authority.** 06 G-19: RFC 4193 reserves
`fc00::/8` for a centrally-assigned registry **that was never created**; only
`fd00::/8` is defined. IANA carries one `/7` row, so no library distinguishes them.
raddr's overlay is precisely the place a non-IANA-but-RFC-sourced distinction could
live. `[OPEN]` (low priority)

**N12. Mixed radix within one IPv4 literal is legal.** 05 G-6: `0x8.0X8.010.8`
parses each part independently with base-0 `strtoul`; there is no rule that parts
share a radix. No corpus row mixes hex and octal. `[CORPUS]`

**N13. RFC 4632 §5.1 requires left-contiguous masks; popcount is not enough.**
08 G-18: `255.0.255.0` popcounts to 16 and silently yields `/16`. Only relevant if
prefix parsing is ever in scope — currently `ipaddress` owns CIDR algebra
(`docs/architecture.md:44-60`), but the registry's own prefixes are parsed at build
time. Worth one line in the exclusion list. `[DOC]`

---

## Literals lacking a fixture

Checked against `tests/testthat/fixtures/ipv4-oracle.csv` (91 inputs) and
`ipv6-oracle.csv` (126 inputs). The corpus is already dense — these are the gaps.

| literal | why it matters | source | tag |
|---|---|---|---|
| `fe80::a%25en1` (and `fe80::1%25lo0`) | the RFC 6874 spelling; named in `docs/architecture.md:319-322` but **no fixture row exists**. Now doubly load-bearing: RFC 9844 obsoleted the syntax (C5) | 05 G-31, 08 §12 | `[CORPUS]` |
| `::1%1]foo.bar baz'"` | NCC/OpenJDK zone-boundary truncation: parser stops at `%`, validator and logger see different strings. raddr keeps zone text **verbatim**, so a zone bearing `]`, space and quotes is a live question for `ssrfr` downstream | 05 G-32 | `[CORPUS]` |
| `0x8.0X8.010.8` | mixed hex/hex/octal/decimal in one literal (N12) | 05 G-6 | `[CORPUS]` |
| `0129.0.0.1` | the *CVE-2021-29418* literal specifically: invalid octal digit in the **first** part, where the corpus only has `08`/`09`/`192.0.048.1` | 05 G-5, CVE-2021-29418 | `[CORPUS]` |
| `2002:7f00:1::` | 6to4 embedding `127.0.0.1` — the live Symfony CVE-2026-48736 exploit string, and the sharpest test of the overlay's unwrap-and-classify choice | 06 G-10, N7 | `[CORPUS]` |
| `64:ff9b::a00:1` | NAT64 WKP embedding `10.0.0.1`: IANA says the prefix **is** globally reachable and the embedding is private, simultaneously | 06 §7 | `[CORPUS]` |
| `::ffff:169.254.169.254` | IPv4-mapped link-local; the metadata-filter bypass every surveyed guard misses except by side effect | 06 §5, 05 G-18 | `[CORPUS]` |
| `1.2.3.4junk` | glibc accepts, musl rejects, Apple rejects (C3). The corpus has `1.2.3.4x` but the fixture only records Apple, so the row cannot show the divergence | 05 G-10 | `[CORPUS]` `[OPEN]` |
| `100.100.100.200` | Alibaba metadata inside CGNAT — outside every link-local rule. Repo has it only as `[unconfirmed]` scratch prose | 06 §5, G-18 | `[CORPUS]` |
| `[::]` | `http://0/`-class localhost trick; corpus has `[::1]` and `0` but not this | 05 G-3 | `[CORPUS]` |

Ten literals. `::1%lo0` (N1) already has a row but only an Apple column.

---

## Missing reason codes

The repo ships 15 parse codes (`R/codes.R:16-92`). Adding one is an API addition
(`R/codes.R:7-9`), so this list is deliberately short.

1. **`zone_scope_not_permitted`** — musl rejects a syntactically valid zone because
   the *address* is not link-local or link-local multicast (N1, 05 G-28). Nothing in
   the vocabulary expresses "the zone is well-formed, the address is the wrong
   scope for one": `zone_not_permitted` means the **dialect** has no zone at all
   (`R/codes.R:49-51`) and `multiple_zones` is a delimiter fault. **Blocked on O6** —
   only needed if a musl dialect ships. `[CODES]` `[OPEN]`

2. **`trailing_garbage`** — 05 §CVE-2021-29418 makes the point sharply: *"the
   interesting divergence is not 'how do parsers read octal' but 'at which byte do
   they give up'."* raddr currently reports `1.2.3.4x` through whichever
   part-level code fires first, which describes the wrong problem. Weakly held: an
   argument exists that `not_a_number` on the final part is already honest.
   `[CODES]` `[OPEN]`

**Explicitly *not* recommended:** a `forbidden_host_code_point` code for WHATWG's
list (NUL, TAB, LF, CR, space, `#`, `/`, `:`, `<`, `>`, `?`, `@`, `[`, `\`, `]`,
`^`, `|` — 05 §"Forbidden host code points"). That is a host-form question and
`rurl` owns it per `docs/architecture.md:206-209`; `whitespace` already covers the
one member raddr can see. No code needed for an **empty** zone either — the repo
already records that Apple accepts one deliberately (`R/ipv6.R:98-99`).

---

## Source conflicts

**S1. 08 tells raddr to pick a winner; 05 and the design record forbid it.**
08 round-trip §5: *"`raddr` should reject leading zeros in dotted quads rather than
pick a base."* 05 G-4: *"Reporting only one answer is a lie by omission,"* and 05
G-40 concludes the opposite explicitly. 08 is writing as if raddr were a single-answer
parser. **Ignore 08 here.** `[DOC]`

**S2. 05 self-conflict on `pton` and leading zeros** — see C2.

**S3. 05 G-19 doubts what 05's own body states.** The body says the WHATWG IPv6
serializer *"implements RFC 5952 §§4.1/4.2.1/4.3, **but not §4.2.2**"*; G-19 then
marks it `UNVERIFIED` whether the spec has a length ≥ 2 guard. The repo already
authors its own §4.2.2 vectors and tests the §4.2.3 tie-break
(`tests/testthat/test-format.R:77-92`), so raddr is unaffected either way — but the
research cannot be cited as settling it.

**S4. 08 round-trip §7 hedges a rule 05 quotes verbatim.** 08 marks the §4.2.3
subsection number `UNVERIFIED`; 05 quotes RFC 5952 §4.2.3 in full. 05 is right.

---

## Confirms (load-bearing only)

**F1. Longest-prefix-match was the right call, and first-match-wins has a live
victim.** Repo gotcha 49 (`R/classify.R:4-7`, `docs/architecture.md:903-906`) was a
judgement call. 06 G-11: `ipaddr.js` iterates in insertion order, so `2001:2::1`
resolves to `teredo` and `benchmarking` (`2001:2::/48`) is **unreachable for every
address**.

**F2. Preserving `N/A` is the design's load-bearing choice, and both resolutions of
it are in production.** Repo `docs/architecture.md:939-952`. 06 G-2: Python and Rust
resolve `N/A` to `False`; Go and R `ipaddress` resolve it to `True`; *"Neither is a
reading of the registry — both are inventions."* `2001::/32` and `2002::/16` are the
only two rows involved, exactly as the repo's CSVs record.

**F3. The vendored-registry structure is the only one that has not failed.**
06 G-22 / G-13: every surveyed library with a hand-maintained CIDR list has shipped
at least one staleness CVE; `iptools` ships a **2014-08-07** IPv4 snapshot and no
IPv6 registry at all. Validates Epic H and `addr_registry_outdated()`
(`docs/architecture.md:983-988`).

**F4. Reporting the prefix fact and the embedding fact as two fields is
independently arrived at.** Repo gotcha 50 (`R/classify.R:98-103`). 06 G-10:
*"Both facts are true simultaneously… Report the prefix fact and the embedding fact
as two fields, never one verdict."*

**44 further CONFIRMS dropped** — the leading-zero triad, the one/two/three-part
forms, `4294967295` vs `4294967296`, RFC 5952 §§4.1–4.3 as output-only rules, the
decimal-only dotted-quad tail, `inet_pton` having no zone grammar, brackets,
curl 7.77.0, `::1.2.3.4` → `::102:304`, R's `integer` overflow to `NA`, doubles
exact to 2^53, `bitwShiftL(1L, 31)`, big-endian byte order, the IPv4/4-in-6 integer
collision, fail-open guards, and the 2021 CVE set — all already in the inventory.

---

**Counts:** 5 Contradicts · 13 New · 10 corpus literals · 2 candidate reason codes
(1 blocked on O6, 1 weakly held) · 4 Source conflicts · 4 Confirms kept, 44 dropped.
