# Delta B — ranges (research 02, 03, 04) against the local baseline (00)

Baseline: `docs/research/00-local-inventory.md`. Sources: `02-ipv4-ranges.md`,
`03-ipv6-ranges.md`, `04-transition-embedding.md`. Tags: `[DATA]` vendored
data/table, `[CODE]` code, `[DOC]` `docs/architecture.md`, `[TEST]` test case,
`[OPEN]` human decision.

**Verdict asked for up front: the RFC 6052 bit-geometry table in
`R/transition.R:126-134` is CORRECT.** All six lengths match 04 §"Bit geometry"
row-for-row — `/32 (32,32)`, `/40 (40,24)+(72,8)`, `/48 (48,16)+(72,16)`,
`/56 (56,8)+(72,24)`, `/64 (72,32)`, `/96 (96,32)` — and the reserved u-byte at
`R/transition.R:143` (`offset 64, length 8`) matches RFC 6052 §2.2. Only the
*prose* around it is wrong (Contradicts C1).

## Contradicts

- **C1 — "four of the six are split" is three.** `R/transition.R:125` says the
  embedded address "straddles the reserved u-byte ... so four of the six are
  split"; 04 §"Bit geometry" states "**Which lengths split the address:** /40,
  /48, /56" and "**Which do not:** /32, /64, /96" — three, and the code table
  immediately below the comment already encodes three. `[CODE]` `[DOC]`
  (04 §Bit geometry, per-length breakdown; `R/transition.R:125`)
- **C2 — raddr asserts RFC 6052 /48 geometry under `64:ff9b:1::/48`, which
  RFC 8215 forbids.** `R/transition.R:71` notes "Local-use, and u-byte-aware: at
  /48 the embedded v4 is not contiguous"; 04 Forms table and constraint 11 quote
  RFC 8215 §5 — nodes "must not make any assumptions regarding the syntax or
  properties of those addresses (e.g., the existence and location of embedded
  IPv4 addresses)" — and 04 gotcha 11 names extracting under this prefix as an
  error. `[CODE]` `[DOC]` `[TEST]` (04 Forms/§Constraints 11, gotcha 11;
  `R/transition.R:70-71`, baseline row 3 "nat64_local (u-byte-aware)")
- **C3 — "the only complemented field" is false of Teredo, true only of
  raddr's overlay.** Baseline gotcha 58 and `R/transition.R:90-92` /
  `R/transition.R:194-195` say the client address "is the only complemented
  field"; 04's Teredo table and constraint/gotcha 2 show the 16-bit **mapped UDP
  port at bits 80..95 is also XOR 0xFFFF**, so the sentence is only true because
  the overlay stores no non-address fields — it must be restated as "the only
  complemented *address*". `[DOC]` `[DATA]` (04 §Teredo layout, gotcha 2;
  `R/transition.R:91-92`)
- **C4 — "No RFC assigns this" for `::ffff:0:0:0/96` is overstated.**
  `R/transition.R:45-46` (and baseline open question 16) says no RFC assigns it;
  03 gotcha 1 and 04 Forms give RFC 2765 §2.1 as the defining text, obsoleted by
  RFC 6145 → RFC 7915, **neither of which retains the form** (04 grepped both).
  Correct wording is "defined by RFC 2765 §2.1, dropped by its successors; no
  *current* RFC assigns it" — which closes O16 as answered. `[DOC]`
  (03 gotcha 1, 04 Forms row 3 + gotcha 8; `R/transition.R:45-46`)
- **C5 — the `::/96` carve-out `tail32 > 1` is narrower than the research
  rule.** `R/transition.R:38-42` excludes only `::` and `::1`; 04 gotcha 1 says
  the general rule is that `::a.b.c.d` with low 32 bits `< 0x01000000` "is almost
  certainly not an embedding at all", naming `::ffff` (= `::0.0.255.255`) and
  `::2` as further false positives. Research marks it a heuristic, so this is a
  deliberate-threshold question, not a proven bug. `[OPEN]` `[TEST]`
  (04 gotcha 1; `R/transition.R:38-42`)
- **C6 — `192.88.99.0/24`'s overlay note says "it embeds nothing", but the
  deprecated address has a defined 6to4 image.** `R/transition.R:62`; 04 Forms
  row 5 and bit-geometry row 6 give `2002:c058:6301::` as the 6to4 encoding of
  `192.88.99.1` (verified: c0=192, 58=88, 63=99, 01=1). The note is true of the
  IPv4 side but the reverse mapping is a real fact raddr can report. `[DOC]`
  (04 Forms row 5; `R/transition.R:61-62`)

## New

Highest-consequence first.

- **N1 — IPv4 multicast `224.0.0.0/4` is in neither vendored CSV and 02 supplies
  its whole structure.** 02 gotcha 4: multicast "is *not*" in the special-purpose
  registry — it has its own IANA registry under RFC 5771 — so "any implementation
  that builds its range table by parsing only the special-purpose registry
  silently produces no answer at all for the entire multicast /4". Baseline
  records `224.0.0.0/4` only as a competitor gap with no RFC citation.
  `[DATA]` `[OPEN]` (02 Ranges rows 224.x–239.x, gotcha 4)
- **N2 — IPv6 multicast `ff00::/8` and the scope nibble are entirely absent from
  raddr.** 03 §Multicast structure: the scope is bits 12–15 and is "a pure
  function of the address bits ... the one piece of IPv6 reachability semantics a
  pure offline classifier can state with full confidence" — including RFC 7346's
  full 16-value scope table, which supersedes RFC 4291's. This is the single
  largest offline-answerable fact raddr currently does not answer. `[DATA]`
  `[CODE]` `[OPEN]` (03 §Multicast structure, §SCOPE field)
- **N3 — 6over4 (RFC 2529 §4) is a standardised IPv4-in-IPv6 embedding the
  overlay does not carry.** Bits 64..95 zero, IPv4 at bits 96..127, under any /64
  (canonically `fe80::/64`); it collides structurally with the IPv4-compatible
  form and is distinguished only by the upper 64 bits. `[DATA]` `[CODE]` `[TEST]`
  (04 Forms row 12, §6over4 layout, gotcha 16)
- **N4 — RFC 6052 §2.3 gives a generic extraction algorithm that removes the
  six-offset table.** "for a /96 prefix take the last 32 bits directly; otherwise
  **delete the u-octet first**, forming a 120-bit string, then take the 32 bits
  immediately following the prefix ... Implementing §2.3 literally is safer than
  hard-coding six offset pairs." `[CODE]` `[DOC]` (04 §Bit geometry closing
  paragraph, gotcha 4)
- **N5 — Teredo's flags (bits 64..79) and obfuscated port (bits 80..95, XOR
  0xFFFF) are absent from the embeddings table.** `[DATA]` `[TEST]`
  (04 §Teredo layout)
- **N6 — RFC 5991 §3.1 randomised the Teredo flags, so flags ∈ {0x0000, 0x8000}
  must never be used as a validity test.** 04 constraint 9 / gotcha 17: a strict
  RFC 4380 flags check rejects every post-2010 client. `[DOC]` `[TEST]`
- **N7 — `fec0::/10` site-local now has a primary source: RFC 3879 §4,
  deprecated Sep 2004, deleted from RFC 4291 §2.4's table.** Baseline records it
  only as an uncited competitor-table entry. `[DATA]` `[DOC]` (03 Ranges,
  gotcha 4)
- **N8 — `200::/7` (former OSI NSAP-mapped, deprecated Dec 2004 by RFC 4048) is
  absent from raddr entirely.** `[DATA]` (03 Ranges, gotcha 4)
- **N9 — `fc00::/8` vs `fd00::/8` are different states and raddr stores only
  `fc00::/7`.** 03 gotcha 3: L=1 (`fd00::/8`) is locally assigned; L=0
  (`fc00::/8`) is "may be defined in the future" and **no allocation mechanism
  was ever defined**, so a "ULA" under `fc00::/8` is unspecified, not merely
  unusual. `[DATA]` `[OPEN]` (03 Ranges, gotcha 3)
- **N10 — NAT64 embedding is undecidable from the address alone.** 04 gotcha 5:
  matching only `64:ff9b::/96` misses every network-specific prefix, and "a
  library must accept a caller-supplied prefix and must not claim 'not NAT64'
  when it only means 'not the WKP'" — a direct API question for Epic J.
  `[OPEN]` `[CODE]`
- **N11 — RFC 6052 §3.1: the Well-Known Prefix MUST NOT carry non-global IPv4,
  and translators "MUST drop these packets".** So `64:ff9b::127.0.0.1` is
  syntactically valid and semantically invalid — a reportable fact raddr does not
  currently hold, and 04 constraint 13 warns the rule binds the WKP *only*.
  `[DATA]` `[TEST]` (04 constraints 1, 13; gotcha 13)
- **N12 — never match `64:ff9b::/47`.** RFC 8215 §5: the covering aggregate
  "includes a range of unallocated addresses"; match `64:ff9b::/96` and
  `64:ff9b:1::/48` separately. `[TEST]` (04 constraint 12, gotcha 12)
- **N13 — RFC 3056 §9: 6to4's `V4ADDR` MUST be global unicast** or the traffic
  "MUST be silently discarded", so `2002:0a00:0001::` is well-formed and invalid
  — the direct 6to4 analogue of N11, and evidence for the repo's open
  "blanket-block vs unwrap-and-classify" question. `[DATA]` `[DOC]`
  (04 constraint 7)
- **N14 — RFC 4380 §4: a Teredo *global* address MUST embed a global-scope
  client IPv4, while a link-local one MAY embed a private one.** `[DOC]`
  (04 constraint 8)
- **N15 — the Pref64 discovery addresses appear under *any* of the six
  geometries and *any* prefix**, not just the WKP; RFC 7050's own example returns
  `2001:db8:42::192.0.0.170` and `64:ff9b::192.0.0.170` from one query. `[DOC]`
  `[TEST]` (04 constraint 13, gotcha 19)
- **N16 — `169.254.0.0/24` and `169.254.255.0/24` are reserved inside link-local
  and have no registry row.** RFC 3927 §2.1: the first and last 256 addresses
  "MUST NOT be selected by a host using this dynamic configuration mechanism".
  `[DATA]` (02 Ranges rows 7–8, gotcha 23; §Semantics 12)
- **N17 — `192.0.0.1/32` (DS-Lite AFTR, RFC 6333 §5.7) and `192.0.0.2/32` (B4,
  §6.5) are named addresses inside `192.0.0.0/29` with no registry rows.**
  `[DATA]` (02 Ranges rows 12–13)
- **N18 — `192.88.99.1/32`, the actual deprecated anycast address, is not in
  raddr** — the repo holds the `/24` and `192.88.99.2/32` only. `[DATA]`
  (02 Ranges row 22)
- **N19 — RFC 2544 §C.2.2.2 contains a typo: it reads `192.18.0.0` through
  `198.19.255.255`.** raddr's CSV cites RFC 2544 for `198.18.0.0/15`; the correct
  citation is RFC 6815 §4.2, and transcribing from RFC 2544 alone yields a range
  spanning six /8s of live global unicast. `[DATA]` `[TEST]` (02 gotcha 1)
- **N20 — `240.0.0.0/4`'s real-world status is stack-dependent and 02 marks it
  `UNVERIFIED`;** treat it as reserved per RFC 1112 §4 and record, rather than
  assert, the divergence. `[DOC]` `[OPEN]` (02 §Semantics 6)
- **N21 — `2000::/3` is not the definition of global unicast.** RFC 4291 §2.4
  defines it as "(everything else)"; hardcoding `2000::/3` both over-claims
  (`2001:db8::/32`, `2002::/16`) and under-claims (ULA, `5f00::/16` — verified
  inside the "Reserved by IETF" `4000::/3`). `[DOC]` (03 gotcha 6)
- **N22 — `fe80::/10` is the reservation; RFC 4291 §2.5.6 fixes the next 54 bits
  to zero, so only `fe80::/64` is conformant** and `febf::1` matches the /10
  without being a valid link-local address. Bears directly on `R/dialects.R:196-197`.
  `[DOC]` `[TEST]` (03 gotcha 7)
- **N23 — multicast site-local (scop 5) was never deprecated;** RFC 3879 killed
  only the *unicast* `fec0::/10`, and dropping scop 5 broke DHCPv6 server
  discovery. `[DOC]` (03 gotcha 8)
- **N24 — `2001:20::/28` and `2001:30::/28` are `Globally Reachable = True` in
  the registry while their RFCs permit routers to drop them** — evidence that the
  boolean answers a narrow question and is not a routability verdict. `[DOC]`
  (03 gotcha 9)
- **N25 — `ff3x::/32` is not the only SSM range;** RFC 7371 §4.1.2 adds
  `ffbx::/32`. `[DATA]` (03 gotcha 18)
- **N26 — scope value `3` flipped from Reserved to Realm-Local (RFC 7346),** and
  `6,7,9,A,B,C,D` are *Unassigned* (assignable later) whereas `0` and `F` are
  *Reserved* — a distinction a levels enum must preserve. `[DATA]` `[OPEN]`
  (03 §SCOPE field, gotcha 15)
- **N27 — the IPv4-mapped SSRF class has a 2024–2026 CVE cluster** (CVE-2024-29415,
  CVE-2026-44492 axios, CVE-2026-42449, CVE-2026-47684, CVE-2026-44232, three
  GHSAs), whose root cause is textual: Node normalises `::ffff:169.254.169.254`
  to `::ffff:a9fe:a9fe` and the range check only knew the dotted form. Directly
  extends the repo's seven-CVE list. `[DOC]` `[TEST]` (04 gotcha 7)
- **N28 — anycast has no prefix** (RFC 4291 §2.6), and Subnet-Router anycast
  (§2.6.1) makes the all-zeros host address *legitimately in use* in IPv6, unlike
  IPv4's network address. `[DOC]` (03 gotcha 19, §Semantics 10)

## Non-CIDR ranges

Every assignment in the three files expressed as something raddr's CIDR-only
matcher cannot store as one prefix. **14 items.**

IPv4 (all from 02):

1. `0.0.0.0/8` **minus** `0.0.0.0/32` — `{0,<Host>}` "Specified host on this
   network", RFC 1122 §3.2.1.3; a set difference, no registry row (02 gotcha 16).
2. `224.0.2.0 – 224.0.255.255` — AD-HOC Block I, RFC 5771 §6; 02 gotcha 19 says
   outright it "is not expressible as a single prefix".
3. `224.3.0.0 – 224.4.255.255` — AD-HOC Block II, RFC 5771 §6; two /16s.
4. `224.5.0.0 – 224.255.255.255` — reserved multicast, RFC 5771 §3.
5. `225.0.0.0 – 231.255.255.255` — reserved multicast, RFC 5771 §3; seven /8s.
6. `234.0.0.0 – 238.255.255.255` — reserved multicast, RFC 5771 §3; five /8s,
   and already superseded in part by RFC 6034's `234/8`.
7. `233.0.0.0 – 233.251.255.255` — GLOP, RFC 5771 §9; rounding up to `233/8`
   swallows AD-HOC Block III and MCAST-TEST-NET (02 gotcha 19).
8. `233.251.240.0/24 – 233.251.255.0/24` — GLOP documentation, RFC 6676 §2.2;
   sixteen /24s (contiguous, so expressible as `233.251.240.0/20`, but not as
   written).
9. `169.254.1.0 – 169.254.254.255` — the usable autoconfiguration range, derived
   from RFC 3927 §2.1's two reserved /24s.
10. "the high order /24 in every scoped region" — RFC 2365 §9 scope-relative
    assignments; depends on a scope boundary, not on the address.
11. `{<Network>,-1}`, `{<Network>,<Subnet>,-1}`, `{<Network>,-1,-1}` — directed,
    subnet-directed and all-subnets broadcast, RFC 919 §7 / RFC 922 §7 /
    RFC 1122 §3.2.1.3; **mask-dependent, not prefixes at all** — `10.1.2.255` is
    a host on a /16 and a broadcast on a /24 (02 §Semantics 1).

IPv6 (all from 03):

12. `ff3x::/32` — SSM, RFC 4607 §1 / RFC 3306 §6; the `x` is a free scope nibble,
    so this is **sixteen disjoint /32s**, and it is *not* `ff30::/28` (verified:
    `/28` would leave bits 28..31 free, but `/32` pins group 2 to `0000`).
13. `ffbx::/32` — SSM under a set ff1 high bit, RFC 7371 §4.1.2; same shape as 12.
14. `ff0x::c` (SSDP), `ff0x::fb` (mDNSv6), `ff0x::101` (NTP) — scope-wildcard
    group addresses from the IANA multicast registry; sixteen discrete addresses
    each.

Not counted, but note: `ff00::/16 … ff0f::/16` (03 Ranges) *is* CIDR-expressible
as `ff00::/12`, and `ff70::/12` (embedded-RP, R=1⇒P=1⇒T=1 ⇒ flgs=`0111`) is a
genuine single prefix — verified by bit arithmetic.

## Source conflicts

- **S1 — 03 contradicts itself on where `100:0:0:1::/64` sits.** Its Ranges row
  says the prefix "sits *inside* `100::/8` but *outside* `100::/64`" (correct);
  gotcha 11 calls it "the *next* /64 but one". **The row is right and gotcha 11
  is wrong**, verified by arithmetic: `100::/64` spans
  `0100:0000:0000:0000::`–`0100:0000:0000:0000:ffff:…`, so the immediately
  adjacent /64 begins at `0100:0000:0000:0001::` = `100:0:0:1::/64`. There is no
  intervening /64. Consequence is only to the prose; both files agree the two
  blocks are disjoint and both inside `100::/8`. `[DOC]`
- **S2 — 03 gotcha 7 claims `fe80::/10` is "one of only two entries" with
  `Forwardable = False`.** This is contradicted by the vendored CSV, where many
  IPv6 rows (`::/128`, `::1/128`, `::ffff:0:0/96`, `100::/64`, `2001:db8::/32`,
  `fc00::/7`, …) carry `Forwardable False`. **The CSV wins** — it is the upstream
  data and the repo already parses it. Do not act on the "only two" claim.
- **S3 — 03 and 04 label `::ffff:0:0:0/96` differently.** 03 Ranges calls it
  "historic (SIIT-era)" and cites RFC 2765 §2.1; 04 Forms says "**No current RFC
  assigns** `::ffff:0:0:0/96`. Treat it as a legacy literal only," backed by a
  grep of RFC 6145 and RFC 7915 finding no occurrence of the form. **04 is
  right** — it did the obsolescence chain, 03 only named the original. Both agree
  it is absent from the IANA registry, so C4's wording follows 04.
- **S4 — 02 and 04 disagree on the section for `192.88.99.1`.** 02 Ranges cites
  RFC 3068 §2.4; 04 Forms cites RFC 3068 §2.3. **§2.3 is more likely right** — it
  is what 04 fetched the canonical `.txt` for and what `R/transition.R:61`
  already cites for the `/24`. Low consequence; verify against the RFC before
  changing anything.
- **S5 — 04 cites RFC 8215 §4/§5 for `64:ff9b:1::/48`, 03 cites §3, and
  `R/transition.R:70` cites §3.** 04's §5 is the one that carries the normative
  "no assumptions" rule that drives C2, so the citation should become §5 (or
  §3, §5) regardless of which names the assignment.
- **S6 — 03's own stale-RFC-6890 lists disagree with each other.** Its opening
  caveat names six missing prefixes; gotcha 16 names twelve. Gotcha 16 is the
  superset and is the one to cite. No data consequence.

## Confirms (load-bearing only)

- **F1 — the RFC 6052 six-length geometry and the u-byte are transcribed
  correctly.** 04's per-length breakdown matches `R/transition.R:126-134` and
  `:143` exactly, including the `/64` displacement to bit 72 — the case 04
  gotcha 3 calls "wrong by exactly 8 bits" in naive implementations, and the case
  baseline gotcha 57 singles out. This was hand-transcribed with no upstream
  file, so independent corroboration is the point.
- **F2 — the ISATAP interface-identifier values are exact.** 04 gotcha 14
  prescribes "bits 80..95 == `0x5EFE` with bits 64..79 ∈ {`0x0000`, `0x0200`}";
  `R/transition.R:149-159` stores precisely those two permitted values with the
  mask clearing the single distinguishing bit.
- **F3 — `2002::/16` is NOT deprecated.** 03 gotcha 10 and 04 gotcha 10 both
  quote RFC 7526 §4 verbatim ("the basic unicast 6to4 mechanism ... and the
  associated 6to4 IPv6 prefix 2002::/16 are not deprecated") — the repo carries
  `2002::/16` as current and `192.88.99.0/24` as deprecated, and that split is
  right. Confirms a judgement call the repo logged as a live design question.
- **F4 — longest-prefix-match is mandatory, not a preference.** 02 gotcha 11
  ("the sharpest nesting inversion in IPv4") and 03 §Semantics 9 independently
  reach the repo's conclusion at `R/classify.R:4-7`.
- **F5 — the registry's policy columns are genuinely non-boolean over time.**
  02 gotcha 8 records RFC 8190 §2.2 flipping `255.255.255.255/32`'s
  Reserved-by-Protocol and §2.3 turning TEREDO's Globally Reachable into `N/A`,
  corroborating the repo's refusal to collapse `N/A` and empty into `False`.
- **F6 — `224.0.0.0/4` really is absent from the special-purpose registry**
  (02 gotcha 4), confirming the baseline's parenthetical rather than leaving it
  an assumption.

**≈31 further CONFIRMS dropped** as routine agreement — every IANA row whose
prefix, name and RFC in 02/03 matched the vendored CSVs verbatim, the
`2001:2::/48` Errata 1752 correction, the `3fff::/20` and `5f00::/16` and
`100:0:0:1::/64` recent assignments, the `2001:10::/28` termination date, the
`::/96` deprecation, the ORCHIDv2 and DET prefixes, and the Teredo server-at-32 /
client-at-96 offsets.

## Counts

Contradicts 6 · New 28 · Non-CIDR 14 · Source conflicts 6 · Confirms kept 6
(≈31 dropped).
