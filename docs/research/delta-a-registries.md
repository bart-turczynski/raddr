# Delta A — IANA registries and block semantics

Slice: `01-iana-registries.md` and `07-block-semantics.md`, judged against the baseline
`00-local-inventory.md`. Repo line numbers are as of the audit (`feature/ipv6-parsing`).

---

## Contradicts

**A1. The registry provenance stamp does not mean what the repo says it means.** `[CODE]` `[DOC]`

- Repo claims: `addr_registry_version()` "reports when the vendored registries were last
  changed upstream" via "the `Last-Modified` date the two files were served with" —
  `R/registry.R:87-104`, `docs/architecture.md:983-988`.
- Research says: `Last-Modified` is a **site deploy timestamp, not a content timestamp** —
  seven CSVs from four unrelated registries all report the identical second
  `Thu, 09 Oct 2025 21:51:16 GMT`. IANA's editorial signal is the page-level `Last Updated`
  field inside the XHTML — 01 §Source metadata, 01 gotcha 33.
- Consequence: the "older of the two halves" rule (`R/registry.R:103-104`,
  `data-raw/build-registry.R:429-438`) is a **no-op** — both halves carry the same second.
  The stamp also drifts with unrelated IANA deploys, so `addr_registry_outdated()` fires
  for reasons unconnected to the data. Fix: stamp from the page `Last Updated`, or restate
  the docs to claim only "when this file was served", not "changed upstream".

**A2. `Globally Reachable` is not `is_global`.** `[DOC]`

- Repo claims: "`Globally Reachable` **is** `is_global`, authoritatively, per row, with an
  RFC citation" — `docs/architecture.md:902`.
- Research says: RFC 8190 §3 renamed the column *from* "Global" precisely because "global"
  was being misread as "public Internet address" — 07 §Registry vocabulary. `True` holds
  for AS112 (x4), AMT (x2), PCP/TURN/SRP anycast (x5), ORCHIDv2 and DETs, none of which is
  a geolocatable public host, and ORCHIDv2/DETs are **never valid packet destinations at
  all** (RFC 7343: ORCHIDs "should not appear in actual IPv6 headers") — 07 gotchas 6, 21.
  `False` equally is not "private": documentation, benchmarking, discard, SRv6 SIDs and
  translation prefixes are all False for unrelated reasons — 07 gotcha 5.
- The repo already contradicts itself: `docs/architecture.md:774` says the column is "the
  IANA column, **not** a derived `is_global`". Line 902 is the outlier and should go.

**A3. Teredo's `N/A` is not for the reason the repo ships in its docs.** `[DOC]` `[TEST]`

- Repo claims: Teredo (`2001::/32`) and 6to4 (`2002::/16`) "are recorded as `N/A` for
  `globally_reachable`, because reachability follows the *embedded* IPv4 address" —
  `R/registry.R:38-41`, and the same reason for both rows at
  `docs/architecture.md:944-948` and `docs/architecture.md:998-1004`.
- Research says: only **6to4**'s `N/A` follows the embedded IPv4 (RFC 3056). **Teredo's**
  `N/A` is because relay advertisement is *voluntary and per-deployment* — RFC 4380 §5.4,
  "A minimal Teredo relay may serve just a local host, and would not advertise the prefix
  beyond this host" — 07 §2001::/32, 07 gotcha 2. Footnote `[2]` points at RFC 4380 §5;
  footnote `[3]` points at RFC 3056. Two different reasons, two different footnotes.
- Consequence: the repo uses one shared rationale to justify `addr_embedded_scope()` for
  both. The extraction is still useful for Teredo, but the *stated justification* is wrong
  and a reader following footnote `[2]` will not find it.

---

## New

**N1. RFC 6890 §2.2.1 states exactly one cross-column invariant, and no more.** `[TEST]`
`Destination=False ⇒ Forwardable=False and Globally Reachable=False`. There is **no** rule
tying `Source` to anything — 07 §Registry vocabulary. This is a free machine-check over the
51 vendored blocks, and it pins the shape the repo already chose (five independent columns).

**N2. `Source` and `Destination` are independent in both directions, with named rows.**
`[TEST]` `[DOC]` `255.255.255.255/32` is the only row that is Source=**False** /
Destination=**True**; `0.0.0.0/8`, `0.0.0.0/32`, `::/128`, `192.0.0.8/32` and
`100:0:0:1::/64` are Source=True / Destination=False — 07 gotcha 10. Any single
"is this address usable" boolean is lossy; these six rows are the proof.

**N3. Longest-prefix-match regression fixtures the repo has not named.** `[TEST]` The repo
cites only `192.0.0.9/32` / `192.0.0.10/32` inside `192.0.0.0/24`
(`docs/architecture.md:903-906`, `R/registry.R:54-58`). Research supplies four more, each
of which a first-match-in-file-order lookup gets wrong — 01 gotcha 9, 07 gotchas 4, 18:
`0.0.0.0` must return `/32` not `/8`; `255.255.255.255` must return `/32` not `240.0.0.0/4`
(and they differ in `destination`); `192.88.99.2` must return the **live** `/32` and not
inherit the empty policy row of the terminated `192.88.99.0/24`; `100::1` (discard) vs
`100:0:0:1::1` (dummy) are different blocks one hex digit apart.

**N4. `192.0.0.0/29` is `.0`–`.7` only.** `[TEST]` `192.0.0.8`, `.9`, `.10`, `.170` and
`.171` are all *outside* it, each with its own row and different policy — off-by-one prefix
arithmetic silently swaps five protocols' semantics. Also note the /29 is Forwardable=True
inside a Forwardable=False /24 — a more-specific that *widens* permissions — 07
§192.0.0.0/29, 07 gotcha 9.

**N5. `2001:db8::/32` is NOT inside `2001::/23`.** `[TEST]` The /23 spans
`2001:0000::`–`2001:01ff::` — 07 §2001::/23. Easy boundary to get wrong; the repo has never
asserted either way.

**N6. The NAT64 well-known prefix forbids non-global embedded IPv4, and translators MUST
drop such packets.** `[CODE]` `[TEST]` RFC 6052 §3.1: "The Well-Known Prefix MUST NOT be
used to represent non-global IPv4 addresses"; translators "MUST NOT translate packets in
which an address is composed of the Well-Known Prefix and a non-global IPv4 address; they
MUST drop these packets" — 07 §64:ff9b::/96, 07 gotcha 13. This is directly about the
repo's own worked example `64:ff9b::a9fe:a9fe` (`00-local-inventory.md:129`): the honest
report is not merely "embedded address is link-local", it is "this literal is invalid under
RFC 6052". It also sharpens `docs/architecture.md:908-910`, which says the /96 is globally
reachable "*because it maps onto global IPv4*" — the causality is a routing-policy fact, and
the per-address MUST-drop rule is the part the table cannot express.

**N7. 6to4 has the same per-address validity rule.** `[CODE]` `[OPEN]` RFC 3056: "any 6to4
traffic whose source or destination address embeds a V4ADDR which is not in the format of a
global unicast address MUST be silently discarded" — so `2002:0a00:0001::` (10.0.0.1) is
invalid while `2002:0808:0808::` may be reachable — 07 §2002::/16. This is new evidence for
the repo's live open question 14 (blanket-block vs unwrap-and-classify,
`_scratch/COMPETITORS.md:449-453`): the RFC itself demands per-address treatment, which
favours the repo's unwrap choice over CPython 3.12.4+'s blanket-private.

**N8. The IANA IPv6 Address Space registry exists, is a total function, and supplies two
citations the repo flagged as missing.** `[DATA]` `[DOC]` `[OPEN]` 20 rows that tile `::/0`
exactly, no gaps, no overlaps — 01 §2, 01 gotcha 31. It contains `fec0::/10`
(`Reserved by IETF`, **RFC 3879**, "Deprecated by [RFC3879] in September 2004") and
`200::/7` (RFC 4048, deprecated December 2004). The baseline records `fec0::/10` as having
"no RFC cited anywhere in this repo" (`00-local-inventory.md:121`, `:622-623`) — that gap is
now closed. Gotcha: the registry spells prefixes compressed (`::/8`, `100::/8`, `200::/7`,
`e000::/4`, `fe00::/9`), not `0000::/8`, so any hard-coded expectation list mismatches every
one — 01 gotcha 2. Decision for a human: vendor it as a fallback layer under the
special-purpose registry, or stay special-purpose-only.

**N9. The IANA IPv4 Address Space registry likewise partitions `0.0.0.0/0` and sources
`224.0.0.0/4`.** `[DATA]` `[OPEN]` 256 `/8` rows collapsing exactly to `0.0.0.0/0` — 01 §1,
01 gotcha 31. Footnote `[14]` gives multicast as RFC 5771 and `[17]` gives `240/4` as
RFC 1112. The baseline records `224.0.0.0/4` as having "no RFC cited in repo" and "in
neither vendored CSV nor the overlay" (`00-local-inventory.md:122`, `:624-626`) — now
sourced. Parsing gotchas if vendored: the Prefix column is `000/8`…`255/8`, **not CIDR**
(01 gotcha 1), and the CSV header literally reads `Status [1]`, so matching on `"Status"`
fails (01 gotcha 13).

**N10. IANA states the precedence between its own registries.** `[DOC]` The Address Space
registries say "For authoritative registration, see [IPv4 Special-Purpose Address Space]",
so precedence is **Special-Purpose > Address Space** — 01 gotcha 26, which also enumerates
the confirmed overlaps (`fc00::/7`, `fe80::/10`, `ff00::/8`, `2001::/23`, `2002::/16`,
`3fff::/20`, `240.0.0.0/4`, and eleven IPv4 blocks). Worth stating in §7 before any second
registry is added.

**N11. The multicast scope nibble is not a prefix, and IANA's scope registry contradicts
RFC 4291.** `[DOC]` `[OPEN]` Scope `N` is the *low* nibble of the second octet, so
"Link-Local scope" is `ff02::/16`, `ff12::/16`, `ff32::/16` … sixteen separate /16s —
mapping it to `ff02::/16` alone misses every transient, unicast-prefix-based and
Embedded-RP group (01 gotcha 20). Separately, IANA's scope registry (per RFC 7346) assigns
scope `3` = Realm-Local, while RFC 4291 §2.7 — still the normative addressing architecture —
says scope 3 is reserved; citing RFC 4291 for scope semantics yields a stale answer (01
gotcha 19). This bears directly on the repo's single largest hole, the undecided `scope`
vocabulary (`00-local-inventory.md:158-162`), whose draft list includes `multicast`.

**N12. `fc00::/7` is registered but only `fd00::/8` is defined.** `[DOC]` `[OPEN]` RFC 4193
§3.1 defines only the L=1 (locally assigned) half; `fc00::/8` (L=0, centrally assigned) has
no defining specification — 07 §fc00::/7, 07 gotcha 16. Reporting `fc00::1` as "a valid ULA"
overstates the case. A `scope` vocabulary with a single `private`/`ula` level cannot say
this; the honest answer is "in the registered ULA block, half undefined".

**N13. `fe80::/10` is registered but `fe80::/64` is the real format.** `[DOC]` RFC 4291
§2.5.6 mandates 54 zero bits after `1111111010` — everything `fe80::`–`febf:ffff…` matches
the registry row, but only `fe80::/64` is well-formed — 07 §fe80::/10, 07 gotcha 17. This
also sources the repo's unsourced magic numbers: the `fe80::/10` word bounds
`4269801472`–`4273995775` at `R/dialects.R:196-197` (flagged unsourced at
`00-local-inventory.md:618-620`) are the /10, and RFC 4291 §2.5.6 is the citation to attach.

**N14. Documentation prefixes are stricter than RFC 1918, in a way a "private" bucket
destroys.** `[DOC]` `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`, `2001:db8::/32` and
`3fff::/20` are Source=False **and** Destination=False — invalid on the wire in both
directions — while RFC 1918 space is Source=True/Destination=True — 07 gotcha 20. Seeing
TEST-NET traffic means an example config reached production; bucketing it as "private,
ignore" suppresses that signal. Input to the `scope` vocabulary decision.

**N15. RFC 5180's printed prefix is wrong and the registry is right.** `[DOC]` `[TEST]`
RFC 5180 §8 as printed reads `2001:0200::/48`; Errata ID 1752 corrects it to
`2001:0002::/48` — 07 §2001:2::/48, 07 gotcha 15. `2001:200::/48` is real, allocated,
globally routed APNIC-region space. The repo records the errata in the RFC field
(`00-local-inventory.md:73`) but not the trap; it is a one-line negative test.

**N16. Footnote *text* is now sourced verbatim.** `[DATA]` `[OPEN]` All six markers are
transcribed — 01 §IPv4/IPv6 Special-Purpose footnotes. The load-bearing one is IPv4 `[1]` on
`127.0.0.0/8`'s four False cells: MPLS LSP ping (RFC 8029) and BFD-for-MPLS (RFC 5884)
legitimately put 127/8 on the wire (07 §127.0.0.0/8). The repo ships markers without text
because "their text lives only on the HTML registry page" (`R/registry.R:60-65`) — still
defensible, but now a choice rather than a constraint.

**N17. Allocation dates routinely predate the cited RFC.** `[TEST]` `192.175.48.0/24` is
1996-01 citing RFC 7534 (2015); `255.255.255.255/32` is 1984-10 citing RFC 8190 (2017) — 01
gotcha 23, 07 gotcha 23. Any "RFC year vs allocation year" sanity check produces spurious
errors, and RFC 8190 changed rows' *values* without touching their dates.

**N18. The IPv6 Global Unicast registry is not a partition.** `[DOC]` 61 sub-ranges of
`2000::/3` appear in no row; absence means "unallocated", a distinct answer from "not
found" — 01 gotcha 31. Matters only if a third registry is vendored.

---

## Source conflicts

**S1. 01 gotcha 15 miscounts itself.** It says "three headings carry no range at all" and
then lists four (GLOP, Unicast-Prefix-based, Scoped Multicast Ranges, Relative Addresses).
The list is almost certainly right and the count wrong — the same gotcha independently
catches an arithmetic error in IANA's own heading ("251 /16s" spans 247), so the author was
counting items, not proofreading the lead-in. Immaterial to raddr either way.

**S2. `5f00::/8` vs `5f00::/16`.** The IPv6 Address Space notes for `4000::/3` and the Global
Unicast notes for `3ffe::/16` both call `5f00::/8` the returned 6bone range; the
Special-Purpose registry assigns `5f00::/16` to SRv6 SIDs (RFC 9602) — 01 gotcha 27.
This is IANA disagreeing with itself, not the two files disagreeing. Resolution: the `/16`
wins for classification, because only the `/16` is a registry row and because
Special-Purpose outranks Address Space by IANA's own statement (N10).

**S3. Block name for `2001:30::/28`.** 01 §4 transcribes the cell verbatim as "…(DETs)
**Prefix**"; 07's heading drops "Prefix". 01 wins (it is the transcription), and the vendored
CSV is authoritative regardless. No other name, prefix, policy value or date disagrees
between the two files — I checked all 51 blocks.

---

## Confirms (load-bearing only)

- **The vendored snapshot is current.** 07's header states the vendored
  `inst/extdata/*.csv` "match the live registries as fetched on 2026-07-27", and 01's
  independent fetch reproduces all 25+25 records including `100:0:0:1::/64` (RFC 9780,
  allocated 2025-04, the newest row in either registry). The repo's data is not stale — but
  see A1: `addr_registry_outdated()` will still flip `TRUE` on 2026-10-09 for provenance
  reasons unrelated to content.
- **`N/A` and empty are two distinct kinds of "IANA declined to answer".** The repo called
  this a judgement call at `docs/architecture.md:939-952`. Both files corroborate
  independently: 01 gotchas 6 and 7 ("Reading them as `False` asserts a policy IANA
  deliberately declined to state"), 07 gotchas 2 and 3 ("only NA is honest"). The
  three-valued design at `R/registry.R:25-45` is right.
- **Longest-prefix-match, and the carve-out set is larger than the repo's one example.**
  01 gotcha 9 and 07 gotcha 1 corroborate `docs/architecture.md:903-906` and add that
  `2001::/23` contains eight more special-purpose records, most of them permissive.
- **The parsing shape of the CSVs.** The composite `"192.0.0.170/32, 192.0.0.171/32"` cell
  (only such row), footnote markers inside the Address Block cell making it a non-CIDR
  string, and records wrapping across physical lines inside quoted fields requiring a real
  CSV reader — 01 gotchas 3, 4, 11 — all independently confirm `docs/architecture.md:930-958`
  and `R/registry.R:47-65`, a section the repo had to correct once already (the 26+27 *line*
  count). The 51-block arithmetic holds.
- **The `-1.csv` endpoints.** 01 gotcha 32 warns that `ipv6-address-space.csv` 404s and
  serves a 4216-byte HTML error body that a status-blind fetcher will happily vendor. The
  repo already fetches the `-1` endpoints (`docs/architecture.md:927`) and
  `data-raw/build-registry.R:373` uses `download.file()`, which errors on 404 under libcurl.
  Confirmed safe, worth not regressing.
- **`::ffff:0:0/96` must be reported as itself *and* unwrapped.** 07 gotcha 12 corroborates
  `R/classify.R:98-103` — the outer row is the IPv6 block, the embedded IPv4 classification
  is a separate fact. A filter checking only the IPv6 registry is bypassable with
  `::ffff:127.0.0.1`.

---

**Counts: 3 contradicts, 18 new, 3 source conflicts, 6 confirms.** Dropped ~9 CONFIRMS as
routine agreement (per-block policy values, RFC citations and dates for all 51 vendored
blocks, the two terminated rows, NAT64/ISATAP silence) and 4 low-consequence NEW items (the
CSV RDAP-column data-loss bug, the `multicast-addresses-10.csv` header typo, the
`"""This network"""` quote-in-quote encoding, cross-registry footnote staleness in the IPv4
Address Space registry) — none affects a classification raddr would report today.
