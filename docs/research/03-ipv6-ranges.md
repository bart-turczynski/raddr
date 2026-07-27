# IPv6 Address Ranges — Primary-Source Inventory

Research notes for `raddr`. Every claim carries an RFC number and, where possible, a section.
Anything not directly substantiated from a primary source is marked `UNVERIFIED`.

Primary sources consulted: RFC 4291, 4007, 7346, 7371, 4193, 3879, 4048, 3849, 9637, 9602,
7343, 4843, 9374, 3306, 3307, 3956, 4607, 6034, 2928, 6890, 8190, 7526, 8215, 6666, 9780,
7535, 7534, 6052, 4380, 2765, 3056, 5180; plus the IANA *IPv6 Special-Purpose Address
Registry*, *IPv6 Address Space* registry, and *IPv6 Multicast Address Space* registry.

**Registry-vs-RFC caveat.** RFC 6890 is the RFC that created the special-purpose registry, but
it froze in 2013. It is *stale*: it lacks `3fff::/20`, `5f00::/16`, `64:ff9b:1::/48`,
`2001:20::/28`, `2001:30::/28`, `100:0:0:1::/64`, and it still lists `2001:10::/28` (ORCHIDv1)
as live. The IANA registry, as amended by RFC 8190, is the current authority. Prefer the
registry; cite the assigning RFC.

---

## Ranges

`routable?` below means "globally reachable" in the RFC 8190 sense (§2: *"a boolean value
indicating whether an IP datagram whose destination address is drawn from the allocated
special-purpose address block is forwardable beyond a specified administrative domain"*), not
"will your kernel forward it".

| prefix | name | defining RFC + section | status | routable? | notes |
|---|---|---|---|---|---|
| `::/128` | Unspecified | RFC 4291 §2.5.2 (table §2.4) | current | no | *"must never be assigned to any node… indicates the absence of an address"*. Registry: Source=True, Destination=False. Legal as a source (DAD, DHCPv6 solicit), never as a destination. |
| `::1/128` | Loopback | RFC 4291 §2.5.3 (table §2.4) | current | no | *"may be used by a node to send an IPv6 packet to itself"*. Exactly one address — see Gotcha 2. |
| `::/96` | IPv4-compatible IPv6 | RFC 4291 §2.5.5.1 | **deprecated** | no | 80 zero bits + 16 zero bits + IPv4. RFC 4291 §2.5.5.1: *"now deprecated because the current IPv6 transition mechanisms no longer use these addresses"*. IANA IPv6 Address Space registry note on `::/8`: *"::/96 deprecated by RFC4291"*. Overlaps `::/128` and `::1/128`. |
| `::ffff:0:0/96` | IPv4-mapped IPv6 | RFC 4291 §2.5.5.2 | current | no | 80 zero bits + `FFFF` + IPv4. Represents an IPv4-only node inside an IPv6 API/socket. Registry: Source=False, Destination=False, Reserved-by-Protocol=True — must not appear on the wire. |
| `::ffff:0:0:0/96` | IPv4-translated | RFC 2765 §2.1 | historic (SIIT-era) | no | *"an address of the form 0::ffff:0:a.b.c.d which refers to an IPv6-enabled node"*. Distinct from IPv4-mapped by 16 bits. Not in the IANA special-purpose registry. See Gotcha 1. |
| `64:ff9b::/96` | IPv4/IPv6 translation (Well-Known Prefix) | RFC 6052 §2.1 | current | **yes** | NAT64 WKP. Allowed NSP lengths 32/40/48/56/64/96 (§2.2); bits 64–71 MUST be zero (§2.2); WKP *"MUST NOT be used to represent non-global IPv4 addresses"* (§3.1). Registry: Globally Reachable=True. |
| `64:ff9b:1::/48` | Local-use IPv4/IPv6 translation | RFC 8215 §3 | current | no | Technology-agnostic local translation prefix; the RFC 6052 §3.1 restrictions *"do not apply"* (RFC 8215 §5). Lets several translators coexist in one network. |
| `100::/64` | Discard-Only | RFC 6666 §4 | current | no | Remote-Triggered Black Hole sink. *"IPv6 traffic with a destination address within this prefix SHOULD NOT be forwarded to or accepted from third-party autonomous systems"*; may be nulled. |
| `100:0:0:1::/64` | Dummy IPv6 Prefix | RFC 9780 §7.1 | current (2025-04) | no | **Verified**: the prefix is `100:0:0:1::/64`. Destination for IP/UDP-encapsulated management/control/OAM packets (BFD over P2MP MPLS LSPs). Registry: Source=True, Destination=False, Forwardable=False. Replaces an earlier illegal use of an IPv4-mapped loopback. Note it sits *inside* `100::/8` but *outside* `100::/64`. |
| `200::/7` | OSI NSAP-mapped (former) | RFC 4048 §§1,3; formerly RFC 3513 §2.4 | **deprecated** (Dec 2004) | no | RFC 4048: *"IANA has marked the IPv6 address prefix 0000 001, reserved for NSAP Allocation in [RFC3513], simply as Reserved."* IANA IPv6 Address Space: `200::/7` Reserved by IETF, *"Deprecated December 2004; formerly OSI NSAP-mapped prefix"*. Not usable, but also no longer a *typed* range. |
| `400::/6`, `800::/5`, `1000::/4` | Reserved by IETF | RFC 4291 §2.4 (implied by "everything else"); IANA IPv6 Address Space | current (unassigned) | no | Unallocated. |
| `2000::/3` | Global Unicast | RFC 4291 §2.4 / §2.5.4; IANA IPv6 Address Space | current | yes | The only block IANA hands to the RIRs today. **Not** the definition of "global unicast" — see Gotcha 6. |
| `2001::/23` | IETF Protocol Assignments | RFC 2928 §3 (via IANA registry) | current | no | RFC 2928 §3 assigns Sub-TLA IDs `2001:0000::/29`–`2001:01F8::/29` to IANA *"for assignment for testing and experimental usage"*. The *name* "IETF Protocol Assignments" and the `/23` framing come from the IANA registry, not RFC 2928's own text — `UNVERIFIED` as literal RFC 2928 wording. Registry booleans are all False, but sub-blocks override (RFC 8190). |
| `2001::/32` | Teredo | RFC 4380 §2.6, §4 | current | no (Globally Reachable = N/A) | *"an IPv6 addressing prefix whose value is 2001:0000::/32"*. Fields: prefix / server IPv4 / flags / obfuscated port / obfuscated client IPv4. |
| `2001:1::1/128` | Port Control Protocol Anycast | RFC 7723 | current | yes | Single host address, per IANA registry. |
| `2001:1::2/128` | TURN Anycast | RFC 8155 | current | yes | Single host address. |
| `2001:1::3/128` | DNS-SD Service Registration Protocol Anycast | RFC 9665 | current (2024-04) | yes | Single host address. |
| `2001:2::/48` | Benchmarking | RFC 5180 + Errata 1752 | current | no | The published RFC 5180 text said `2001:0200::/48`; **Errata 1752** corrects it to `2001:2::/48`. See Gotcha 12. |
| `2001:3::/32` | AMT (Automatic Multicast Tunneling) | RFC 7450 | current | yes | |
| `2001:4:112::/48` | AS112-v6 (DNAME redirection) | RFC 7535 §8.1 | current | yes | *"IANA has assigned one IPv6 /48 netblock"*, nameserver at `2001:4:112::1`. IPv4 counterpart `192.31.196.0/24`. |
| `2001:10::/28` | ORCHID (v1) | RFC 4843 §2, §7 | **deprecated / expired** (terminated 2014-03) | no | RFC 4843 §7: *"By default, the prefix will be returned to IANA in 2014"*. RFC 7343 §6: *"the prefix… was returned to IANA in March 2014"*. IANA registry name is literally *"Deprecated (previously ORCHID)"* with a **Termination Date of 2014-03** — the only terminated entry in the registry. |
| `2001:20::/28` | ORCHIDv2 | RFC 7343 §6 | current | yes (registry) | *Overlay Routable Cryptographic Hash Identifiers*: endpoint identifiers, not locators (§1). §3: routers *"MAY be configured not to forward any packets containing an ORCHID as a source or a destination address"*. Registry says Globally Reachable=True even though these are not routed as locators — see Gotcha 9. |
| `2001:30::/28` | Drone Remote ID Protocol Entity Tags (DETs) | RFC 9374 §3.1 | current (2022-12) | yes (registry) | Hierarchical HHITs. §3.1: the prefix *"MUST be distinct from that used in the flat-space HIT as allocated in [RFC7343]"*. |
| `2001:db8::/32` | Documentation | RFC 3849 §2 | current | no | §3: operators *"should add this address prefix to the list of non-routeable IPv6 address space"*. Still valid — RFC 9637 *updates*, does not obsolete, RFC 3849. |
| `2002::/16` | 6to4 | RFC 3056 §2 | current (mechanism largely dead) | N/A | RFC 7526 §4 deprecates *only* the **anycast** 6to4 mechanism of RFC 3068 and `192.88.99.0/24`: *"The basic unicast 6to4 mechanism defined in [RFC3056] and the associated 6to4 IPv6 prefix 2002::/16 are not deprecated."* Registry Globally Reachable = N/A. See Gotcha 10. |
| `2620:4f:8000::/48` | Direct Delegation AS112 Service | RFC 7534 §3.4 | current | yes | *"each AS112 node… announces the prefixes 192.175.48.0/24 and 2620:4f:8000::/48 to the Internet with origin AS 112"*. Nameservers at `::6` and `::42`. Note this is inside `2000::/3` global unicast. |
| `3fff::/20` | Documentation | RFC 9637 §6 | current (2024-07) | no | §4: *"they MUST NOT be used for actual traffic, MUST NOT be globally advertised, and SHOULD NOT be used internally for routed production traffic."* §5: should be treated as bogon. **New in 2024** — see Gotcha 5. |
| `4000::/3`, `6000::/3`, `8000::/3`, `a000::/3`, `c000::/3`, `e000::/4`, `f000::/5`, `f800::/6` | Reserved by IETF | RFC 4291 §2.4; IANA IPv6 Address Space | current (unassigned) | no | `4000::/3` is now *partially* allocated: it contains `5f00::/16`. IANA's note also records that `5f00::/8` was the 6bone block, returned per RFC 5156. |
| `5f00::/16` | Segment Routing (SRv6) SIDs | RFC 9602 §6 | current (2024-04) | no | Registry: Forwardable=True, Globally Reachable=False. §5: SIDs must not leak out of the SR domain; global DNS *"SHOULD NOT reference addresses assigned from this block"*. Sits inside the otherwise-reserved `4000::/3`. |
| `fc00::/7` | Unique Local Address (ULA) | RFC 4193 §3.1 | current | no | Registry (per RFC 8190): Globally Reachable=False, with a footnote that this is inside Global Unicast but *"not globally routed"*. RFC 4193 §4.1: exterior routing sessions *"must be to ignore receipt of and not advertise prefixes in the FC00::/7 block"*. |
| `fc00::/8` | ULA, L=0 | RFC 4193 §3.1, §3.2 | **undefined** | no | The L bit *"Set to 0 may be defined in the future"*. No allocation authority exists. See Gotcha 3. |
| `fd00::/8` | ULA, locally assigned (L=1) | RFC 4193 §3.2 | current | no | Global ID *"MUST be generated with a pseudo-random algorithm"* (40-bit, SHA-1 of timestamp + system ID). Layout: 7-bit prefix / L / 40-bit Global ID / 16-bit Subnet ID / 64-bit Interface ID (§3.1). §4.4: AAAA/PTR *"not recommended to be installed in the global DNS"*. |
| `fe80::/10` | Link-Local Unicast | RFC 4291 §2.4, §2.5.6 | current | no | Registry: Forwardable=**False**, Reserved-by-Protocol=True. RFC 4291 §2.5.6 fixes the next 54 bits to zero, so in practice only `fe80::/64` is used. See Gotcha 7. |
| `fec0::/10` | Site-Local Unicast | RFC 3879 §4; formerly RFC 3513 §2.5.6 | **deprecated** (Sep 2004) | no | *"This document formally deprecates the IPv6 site-local unicast prefix defined in [RFC3513], i.e., 1111111011 binary or FEC0::/10."* *"The special behavior of this prefix MUST no longer be supported in new implementations"*; routers *"SHOULD be configured to prevent routing of this prefix by default"*. Existing deployments MAY continue. Removed from RFC 4291 §2.4's table entirely. |
| `ff00::/8` | Multicast | RFC 4291 §2.4, §2.7 | current | scope-dependent | See **Multicast structure** below. |
| `ff00::/16` … `ff0f::/16` | Reserved multicast (well-known scope range) | RFC 4291 §2.7.1 | current | scope-dependent | *"Reserved Multicast Addresses: FF00:0:0:0:0:0:0:0 through FF0F:0:0:0:0:0:0:0"* — flgs=0, i.e. permanently assigned, all 16 scopes. |
| `ff3x::/32` | Source-Specific Multicast (SSM) | RFC 4607 §1; derived in RFC 3306 §6 | current | scope-dependent | RFC 3306 §6: *"Set P = 1. Set plen = 0. Set network prefix = 0"* → *"an SSM range of FF3x::/32 (where 'x' is any valid scope value)"*. RFC 4607 §1 reserves it. |
| `ff70::/12` | Embedded-RP multicast | RFC 3956 §3 | current | scope-dependent | R=1 ⇒ P=1 ⇒ T=1, producing the pattern `FF70::/12`. |
| `ffbx::/32` | SSM with ff1 high bit set | RFC 7371 §4.1.2 | current (future assignment) | scope-dependent | *"if the most significant flag bit in ff1 is set, then we would get the SSM range ffbx::/32"*. |

Not IPv6 but frequently confused into IPv6 tables: `234/8` (unicast-prefix-based **IPv4**
multicast, RFC 6034) and `233/8` (GLOP, RFC 3180). RFC 6034 explicitly says it *"specifies a
mechanism similar to [RFC3306]"* for IPv4 and does not obsolete RFC 3180. **RFC 6034 assigns no
IPv6 range** — it is the IPv4 mirror of RFC 3306.

---

## Multicast structure

RFC 4291 §2.7, as updated by RFC 7346 (scopes), RFC 3306 (P), RFC 3956 (R), and RFC 7371 (flag
field naming).

```
  |   8    |  4 |  4 |                  112 bits                   |
  +--------+----+----+---------------------------------------------+
  |11111111|flgs|scop|                  group ID                   |
  +--------+----+----+---------------------------------------------+
```

### Flags nibble (bits 8–11), `|0|R|P|T|`

| bit | name | 0 means | 1 means | RFC |
|---|---|---|---|---|
| 8 (high) | reserved / `X` | — | reserved for future assignment; *"X may be set to 0 or 1"* | RFC 4291 §2.7 (*"must be initialized to 0"*); relaxed by RFC 7371 §2 |
| 9 | **R** (Rendezvous Point) | no RP embedded | RP address embedded in the group address | RFC 3956 §3 |
| 10 | **P** (Prefix) | not prefix-based | address assigned based on the network prefix | RFC 3306 §4 |
| 11 (low) | **T** (Transient) | permanently assigned (well-known) by IANA | transient / dynamically assigned | RFC 4291 §2.7 |

Hard dependencies, both stated normatively:

- RFC 3306 §4: *"If P = 1, T MUST be set to 1"* — so `P=1,T=0` is malformed.
- RFC 3956 §3: R=1 *"indicates a multicast address that embeds the address on the RP. Then P
  MUST be set to 1, and consequently T MUST be set to 1"* — so R=1 forces flgs = `0111` = `7`,
  giving `ff70::/12`.

RFC 7371 §2 renames the RFC 4291 flags nibble to **ff1** and redefines bits 17–20 (the RFC 3306
"reserved" octet's high nibble / the RFC 3956 rsvd+RIID region) as a second generic flag field
**ff2**.

### Unicast-prefix-based layout (RFC 3306 §4)

```
  |   8    |  4 |  4 |   8    |    8   |       64       |    32    |
  +--------+----+----+--------+--------+----------------+----------+
  |11111111|flgs|scop|reserved|  plen  | network prefix | group ID |
  +--------+----+----+--------+--------+----------------+----------+
```
`reserved` MUST be zero; `plen` is *"the actual number of bits in the network prefix field that
identify the subnet when P = 1"*.

### Embedded-RP layout (RFC 3956 §3)

```
  |   8    |  4 |  4 | 4  | 4  |  8  |       64       |    32    |
  +--------+----+----+----+----+-----+----------------+----------+
  |11111111|flgs|scop|rsvd|RIID|plen | network prefix | group ID |
  +--------+----+----+----+----+-----+----------------+----------+
```
RP address = first `plen` bits of the network prefix, zero-filled to 128, with the low 4 bits
replaced by RIID (§4). RIID=0 is reserved, so at most 15 RPs per prefix.

### Group ID allocation (RFC 3307)

- Permanent IANA-assigned group IDs: `0x00000001`–`0x3FFFFFFF`, T=0 and P=0.
- Permanent group *identifiers* (same ID across scopes/servers): `0x40000000`–`0x7FFFFFFF`.
- Dynamic: T=1, `0x80000000`–`0xFFFFFFFF` (server-allocated or host pseudo-random).
- Only the low 32 bits map uniquely to link-layer multicast MACs, hence the 32-bit group ID in
  the prefix-based formats.

### SCOPE field (bits 12–15) — every value

Authoritative current table is **RFC 7346 §2**, which supersedes RFC 4291 §2.7's table.

| scop | meaning | RFC | boundary |
|---|---|---|---|
| `0` | Reserved | RFC 4291 §2.7, RFC 7346 §2 | — |
| `1` | Interface-Local | RFC 4291 §2.7, RFC 7346 §2 | automatically derived; loopback only, never leaves the node |
| `2` | Link-Local | RFC 4291 §2.7, RFC 7346 §2 | automatically derived; single link |
| `3` | **Realm-Local** (was *Reserved* in RFC 4291) | RFC 7346 §§1,2 | automatically derived; realm/technology-specific (e.g. mesh) |
| `4` | Admin-Local | RFC 4291 §2.7, RFC 7346 §2 | must be administratively configured |
| `5` | Site-Local | RFC 4291 §2.7, RFC 7346 §2 | administratively configured. **Multicast site-local is NOT deprecated** — RFC 3879 deprecates only the *unicast* `fec0::/10`. |
| `6` | Unassigned | RFC 7346 §2 | — |
| `7` | Unassigned | RFC 7346 §2 | — |
| `8` | Organization-Local | RFC 4291 §2.7, RFC 7346 §2 | administratively configured |
| `9` | Unassigned | RFC 7346 §2 | — |
| `A` | Unassigned | RFC 7346 §2 | — |
| `B` | Unassigned | RFC 7346 §2 | — |
| `C` | Unassigned | RFC 7346 §2 | — |
| `D` | Unassigned | RFC 7346 §2 | — |
| `E` | Global | RFC 4291 §2.7, RFC 7346 §2 | — |
| `F` | Reserved | RFC 4291 §2.7, RFC 7346 §2 | — |

**The scope is a pure function of the address bits.** Nibble 4 (bits 12–15, the third hex digit
of the address) *is* the scope. `ff05::2` is site-local because the `5` says so — no routing
table, no interface state, no configuration is consulted. This is the one piece of IPv6
reachability semantics a pure offline classifier can state with full confidence.

RFC 7346 §2 also notes that interface-local, link-local, and realm-local boundaries are
*automatically derived*, whereas admin-, site-, and organization-local boundaries must be
administratively configured — so scope 4/5/8 membership is only meaningful relative to a
configured zone the library cannot see.

### Well-known groups likely to be seen

Names/RFCs from the IANA *IPv6 Multicast Address Space* registry.

| address | name | RFC |
|---|---|---|
| `ff01::1` | All Nodes (interface-local) | RFC 4291 §2.7.1 |
| `ff02::1` | All Nodes (link-local) | RFC 4291 §2.7.1 |
| `ff01::2` | All Routers (interface-local) | RFC 4291 §2.7.1 |
| `ff02::2` | All Routers (link-local) | RFC 4291 §2.7.1 |
| `ff05::2` | All Routers (site-local) | RFC 4291 §2.7.1 |
| `ff02::5` | OSPFIGP | RFC 2328 / RFC 5340 |
| `ff02::6` | OSPFIGP Designated Routers | RFC 2328 / RFC 5340 |
| `ff02::9` | RIP Routers (RIPng) | RFC 2080 |
| `ff02::a` | EIGRP Routers | RFC 7868 |
| `ff02::c` / `ff0x::c` | SSDP (UPnP) | UPnP Forum (registry lists no RFC) |
| `ff02::d` | All PIM Routers | IANA registry (PIM-SM: RFC 7761) |
| `ff02::16` | All MLDv2-capable routers | RFC 9777 (per IANA registry; formerly RFC 3810) |
| `ff02::fb`, `ff05::fb`, `ff0x::fb` | mDNSv6 | RFC 6762 |
| `ff02::1:2` | All_DHCP_Relay_Agents_and_Servers | RFC 9915 per IANA registry (historically RFC 8415/3315) |
| `ff05::1:3` | All_DHCP_Servers | RFC 9915 per IANA registry |
| `ff02::1:3` | Link-Local Multicast Name Resolution (LLMNR) | RFC 4795 |
| `ff0x::101` | Network Time Protocol (NTP) | RFC 5905 |
| `ff02::1:ff00:0/104` | Solicited-Node | RFC 4291 §2.7.1 |

The solicited-node group is `FF02:0:0:0:0:1:FFXX:XXXX`, formed from *"the low-order 24 bits of an
address (unicast or anycast)"* (RFC 4291 §2.7.1). Every node must join one per configured
unicast/anycast address — so the group is derivable from a unicast address, and vice versa the
low 24 bits are recoverable from the group.

RFC 4291 §2.7 also states that multicast addresses *"must not be used as source addresses"* and
must not appear in a Routing header.

---

## Scope and zones

RFC 4007 is the model; RFC 4291 supplies the address-type inputs.

**Scope (RFC 4007 §3).** *"Every IPv6 address other than the unspecified address has a specific
scope; that is, a topological span within which the address may be used as a unique
identifier."* Two unicast scopes survive: **link-local** and **global**. (Site-local unicast was
the third; RFC 3879 §4 killed it.) Multicast carries its scope in the address (RFC 4291 §2.7).

**Zones (RFC 4007 §5).** A *zone* is a connected topological region of a given scope. The same
non-global address may be reused in different zones of the same scope — `fe80::1` on eth0 and
`fe80::1` on eth1 are different interfaces. Zone boundaries are set by administrators, are
relatively static, and **cut through nodes, not links**: each interface belongs to exactly one
zone per scope.

**Zone indices (RFC 4007 §6).** Because identical addresses can exist in multiple zones, a node
needs an internal *zone index* to disambiguate. Indices must be unique within the node across
all scopes; index **0** is reserved to mean "the default zone"; implementations may accept
interface names as zone identifiers.

**Which types are scoped.** Link-local unicast and *all* multicast (every scope from
interface-local through global) require zone qualification. Global unicast and loopback do not.

**Textual notation (RFC 4007 §11).** `<address>%<zone_id>`, e.g. `fe80::1%1` or
`fe80::1234%ne0`. Omitting `%zone_id` selects the default zone. The `%` form *"must be used only
within a node"* and must not be transmitted on the wire — it is not part of the address, so it
does not belong in a header, a DNS record, or a URI's host component.

**Why link-local needs a zone.** `fe80::/10` is not globally unique and, per the IANA registry,
is `Forwardable = False`. A multihomed node with N interfaces has N link-local zones, all of
which may legitimately contain the same address. A bare `fe80::1` therefore does not identify an
interface — it identifies at most an address *within an unnamed zone*, and the stack cannot pick
an egress interface from it. Same argument applies to any multicast group with scop ≤ 5 on a
multihomed node.

---

## Semantics a prefix table cannot express

Cases where "look up the longest matching prefix" gives a wrong or incomplete answer:

1. **Multicast scope.** Scope is a 4-bit field, not a prefix. `ff02::1` and `ff05::1` share no
   useful prefix relationship with each other but differ only in scope. A prefix table would need
   16 entries per group. Decode the nibble (RFC 4291 §2.7; RFC 7346 §2).
2. **Multicast flags.** T/P/R are individually meaningful bits, and their legal combinations are
   constrained (`P=1 ⇒ T=1`, RFC 3306 §4; `R=1 ⇒ P=1 ⇒ T=1`, RFC 3956 §3). "Is this a
   well-known group?" = "is T=0?", not "does it match `ff0x::/16`?" — though the two coincide for
   scop values in the reserved `ff00::/16`–`ff0f::/16` range.
3. **Solicited-node membership** is computed from the low 24 bits of a *different* address
   (RFC 4291 §2.7.1). No prefix relation exists between a unicast address and its solicited-node
   group beyond the shared `ff02::1:ff00:0/104`.
4. **Embedded RP extraction** requires reading `plen`, `RIID`, and the network prefix out of the
   group address (RFC 3956 §4). The *fact* of a matching `ff70::/12` prefix says nothing about
   which RP.
5. **Unicast-prefix-based multicast** carries a 64-bit unicast prefix and a `plen` inside the
   group address (RFC 3306 §4). The "owner" of `ff3e:40:2001:db8::1234` is derivable, but only by
   parsing fields.
6. **ULA global-ID quality.** RFC 4193 §3.2 requires the 40-bit global ID be *"generated with a
   pseudo-random algorithm"*. `fd00::1` matches `fd00::/8` perfectly yet violates the generation
   rule. A prefix table cannot distinguish a compliant ULA from a lazy one.
7. **Zone requirement.** Whether an address is *usable* depends on a zone that is not in the
   address (RFC 4007 §§5,6). `fe80::1` classified without a zone is under-specified, not wrong.
8. **Source vs destination legality.** The IANA registry's Source/Destination/Forwardable/
   Globally-Reachable booleans (RFC 8190 §2) are four independent answers per prefix. `::/128` is
   a legal source and an illegal destination; `::ffff:0:0/96` is neither. A one-column "is this
   special?" table loses this.
9. **Registry booleans do not nest.** RFC 8190 notes that a parent block may be non-globally-
   reachable while a sub-block differs — `2001::/23` is all-False, yet `2001:1::1/128`,
   `2001:3::/32`, `2001:4:112::/48`, `2001:20::/28`, `2001:30::/28` inside it are Globally
   Reachable=True. Longest-prefix-match is mandatory; first-match or shortest-match is a bug.
10. **Anycast is not a range.** RFC 4291 §2.6: anycast addresses are *"allocated from the unicast
    address space"* and are *"syntactically indistinguishable from unicast addresses"*. No prefix
    test can identify one. The single structural exception is Subnet-Router anycast (§2.6.1):
    n-bit subnet prefix followed by all zeros — i.e. the "subnet zero address", which in IPv6 is
    a valid *anycast* address, not a broadcast address and not unusable.
11. **Interface-ID structure.** RFC 4291 §2.5.1 requires 64-bit modified EUI-64 interface IDs for
    all prefixes outside `000::/3`; RFC 7136 subsequently deprecated the u/g bit semantics for
    IIDs. Whether an address is EUI-64-derived, privacy-generated (RFC 8981), or manually set is
    a property of the low 64 bits, not the prefix. `UNVERIFIED` as to RFC 7136/8981 section
    numbers — not fetched.
12. **6to4 and Teredo embed IPv4.** `2002::/16` embeds an IPv4 address in bits 16–47 (RFC 3056
    §2); Teredo embeds server and *obfuscated* client IPv4 (RFC 4380 §4, client IPv4 and port are
    stored bitwise-inverted). Prefix match tells you the tunnel type; the useful fact (the IPv4
    endpoint) requires field extraction, and for Teredo, un-obfuscation.
13. **NAT64 prefix length is variable.** RFC 6052 §2.2 allows NSPs of 32/40/48/56/64/96 bits, with
    bits 64–71 forced to zero — so extracting the embedded IPv4 from a translated address depends
    on a locally configured prefix length that is not visible in the address.

---

## Gotchas

1. **IPv4-mapped vs IPv4-compatible vs IPv4-translated are three different things.**
   - *IPv4-mapped* `::ffff:0:0/96` — RFC 4291 §2.5.5.2. **Current.** Means "an IPv4-only node,
     seen through an IPv6 API". Never on the wire (registry: Reserved-by-Protocol=True).
   - *IPv4-compatible* `::/96` — RFC 4291 §2.5.5.1. **Deprecated**, *"because the current IPv6
     transition mechanisms no longer use these addresses"*. Was for automatic tunnelling.
   - *IPv4-translated* `::ffff:0:0:0/96` — RFC 2765 §2.1, *"an address of the form
     `0::ffff:0:a.b.c.d`"*, meaning an **IPv6-enabled** node behind SIIT — the exact opposite
     population from IPv4-mapped, and one hex group longer. It is not in the IANA registry.

   Mapped and translated differ by 16 bits (`::ffff:` vs `::ffff:0:`) and their meanings are
   inverted. Compatible and translated both *look* like "zeros then IPv4" to a sloppy regex.
   Compounding this: `::1` and `::` themselves match `::/96`, so any naive "IPv4-compatible"
   test classifies loopback and unspecified as IPv4-compatible. Test `::/128` and `::1/128`
   first.

2. **`::1/128` is one address; IPv4 loopback is `127.0.0.0/8`, sixteen million addresses.**
   RFC 4291 §2.5.3 defines *"the unicast address 0:0:0:0:0:0:0:1"* — singular. There is no
   `::/8`-style loopback block in IPv6. Code ported from IPv4 that tests "first octet == 127" has
   no IPv6 analogue; the correct test is exact equality with `::1`. The trap in the other
   direction: `::ffff:127.0.0.1` is an *IPv4-mapped* address whose embedded IPv4 is loopback —
   it is not `::1`, and treating it as IPv6 loopback (or as remote) has been a real
   security-bypass class. RFC 9780 §7.1 exists partly because an earlier spec illegally used an
   IPv6-mapped IPv4 loopback address for exactly this reason.

3. **`fc00::/7` is the reservation; only `fd00::/8` is actually assignable.**
   RFC 4193 §3.1 allocates `FC00::/7` and defines the L bit; §3.2 states L=1 (→ `fd00::/8`) means
   locally assigned, while L=0 (→ `fc00::/8`) is *"may be defined in the future"*. **No allocation
   mechanism for `fc00::/8` was ever defined** — the centrally-assigned-ULA draft died. So:
   generating a "ULA" under `fc00::/8` is not merely unusual, it is unspecified. A classifier
   should distinguish `fd00::/8` (valid locally-assigned ULA) from `fc00::/8` (reserved,
   undefined) rather than flattening both to "ULA".

4. **Deprecated ranges still hardcoded in filters.**
   - `fec0::/10` site-local: deprecated by RFC 3879 §4 in September 2004, deleted from RFC 4291's
     §2.4 table entirely. Still present in bogon lists, ACL templates, and old stacks' address
     selection tables. RFC 3879 says the *"special behavior… MUST no longer be supported in new
     implementations"* — but existing deployments MAY continue, so you will still see it.
   - `::/96` IPv4-compatible: deprecated, still tested for in address-selection code.
   - `200::/7` NSAP: deprecated December 2004 by RFC 4048; still appears as "NSAP" in tables
     copied from RFC 3513.
   - `2001:10::/28` ORCHIDv1: **terminated 2014-03**. IANA renamed the entry *"Deprecated
     (previously ORCHID)"*. Any table sourced from RFC 6890 (2013) still lists it as live ORCHID
     and is missing ORCHIDv2 entirely.

5. **`3fff::/20` is a documentation prefix and it is new (RFC 9637, July 2024).**
   Nearly every pre-2024 range table, bogon list, and IP library knows only `2001:db8::/32`. A
   `3fff::` address is legitimately a documentation address, and RFC 9637 §5 says it *"should be
   marked as and considered bogon"*. Conversely, RFC 9637 **updates but does not obsolete** RFC
   3849 — `2001:db8::/32` remains valid. Both are documentation; neither replaces the other.

6. **"Global unicast" ≠ `2000::/3`.**
   RFC 4291 §2.4's table defines Global Unicast as *"(everything else)"* — every prefix that is
   not `::/128`, `::1/128`, `ff00::/8`, or `fe80::/10`. `2000::/3` is merely the block IANA
   currently delegates to RIRs (IANA IPv6 Address Space registry). `fc00::/7` is architecturally
   *global unicast* that is deliberately not globally routed (RFC 8190 footnote on the registry
   entry). Hardcoding "global unicast == `2000::/3`" both over-claims (it includes `2001:db8::/32`,
   `2002::/16`, `2001::/32`) and under-claims (it excludes ULA and `5f00::/16`). Worse, IANA's
   own table lists `4000::/3` as "Reserved by IETF" while `5f00::/16` sits inside it and is
   assigned — the top-level table is not authoritative for sub-blocks.

7. **`fe80::/10` is the reservation; `fe80::/64` is what exists.**
   RFC 4291 §2.5.6 defines the link-local format as `1111111010` followed by **54 zero bits**
   followed by a 64-bit interface ID. So `febf::1` matches `fe80::/10` but is not a
   conformant link-local address. Filters written as `/10` are safe (superset); code that
   *constructs* or *validates* link-local addresses should use `/64`. Also note the registry marks
   `fe80::/10` `Forwardable = False` — one of only two entries where that is true.

8. **Multicast site-local (scop 5) was never deprecated.**
   RFC 3879 deprecates the *unicast* prefix `fec0::/10`. `ff05::/16` — including `ff05::2`
   (all routers, site-local) and `ff05::1:3` (all DHCP servers) — is current, in active use, and
   in the IANA registry. Implementations that "removed site-local support" and dropped scop 5
   multicast broke DHCPv6 server discovery.

9. **Registry "Globally Reachable = True" does not mean "routed on the Internet".**
   `2001:20::/28` (ORCHIDv2) and `2001:30::/28` (DETs) are both `Globally Reachable=True` in the
   registry, yet RFC 7343 §1 says ORCHIDs are *"endpoint identifiers… not as identifiers for
   network location at the IP layer"* and §3 permits routers to drop them. Conversely
   `5f00::/16` is `Forwardable=True, Globally Reachable=False` — forwardable inside an SR domain,
   never outside. The boolean answers a narrow question (RFC 8190 §2) and is not a routability
   verdict.

10. **6to4: the anycast relay is dead, the prefix is not.**
    RFC 7526 §4 deprecates RFC 3068's anycast mechanism and IPv4 `192.88.99.1` / `192.88.99.0/24`
    and declares RFC 6732 unnecessary — but states explicitly that *"the basic unicast 6to4
    mechanism defined in [RFC3056] and the associated 6to4 IPv6 prefix 2002::/16 are not
    deprecated."* Tables that mark `2002::/16` "deprecated by RFC 7526" are wrong. The registry
    lists its Globally Reachable value as `N/A`, not False.

11. **`100::/64` (discard) and `100:0:0:1::/64` (dummy) are different, non-overlapping, and both
    inside `100::/8`.** RFC 6666 §4 assigns `100::/64` as an RTBH sink. RFC 9780 §7.1 assigns
    `100:0:0:1::/64` — the *next* /64 but one — as a dummy destination for OAM encapsulation, with
    `Destination=False, Forwardable=False`. A `/8`-granularity table collapses them and the rest
    of `100::/8` (which is otherwise "Reserved by IETF") into one wrong answer.

12. **`2001:2::/48` benchmarking: the RFC text is wrong, the erratum is right.**
    RFC 5180 as published named `2001:0200::/48`. **Errata ID 1752** corrects this to
    `2001:2::/48`, and the IANA registry cites `[RFC5180][RFC Errata 1752]`. Anyone transcribing
    from the RFC body gets a prefix that is outside `2001::/23` and belongs to APNIC.

13. **`5f00::/16` changed meaning.** IANA's IPv6 Address Space registry records that `5f00::/8`
    was the **6bone** block, returned per RFC 5156. In April 2024 RFC 9602 assigned `5f00::/16`
    to **SRv6 SIDs**. Old tables may still say "6bone (returned)"; very old ones say "6bone
    (live)". Both are wrong for `5f00::/16` today.

14. **`ff00::/8` is not uniformly "multicast, drop it".** Interface-local (scop 1) traffic must
    never leave the node; link-local (scop 2) must never be forwarded; global (scop E) may be
    routed. RFC 7346 §2 further notes only scopes 1/2/3 have automatically-derived boundaries —
    4/5/8 depend on configuration you cannot see. And RFC 4291 §2.7 forbids multicast addresses
    as *source* addresses entirely, which a symmetric src/dst prefix check will miss.

15. **Scope value `3` flipped from Reserved to Realm-Local.** RFC 4291 §2.7 listed scop 3 as
    Reserved; RFC 7346 §§1,2 redefines it as **Realm-Local**. Implementations that validate
    against RFC 4291's table reject valid RFC 7346 addresses. Values `6,7,9,A,B,C,D` remain
    Unassigned (not Reserved — a meaningful distinction: unassigned values may be assigned later,
    `0` and `F` will not be).

16. **RFC 6890 is a stale snapshot.** It is the RFC that many libraries cite for "IPv6 special
    purpose addresses", and it is 13 years out of date: missing `3fff::/20`, `5f00::/16`,
    `64:ff9b:1::/48`, `2001:20::/28`, `2001:30::/28`, `100:0:0:1::/64`, `2001:1::1/128`,
    `2001:1::2/128`, `2001:1::3/128`, `2001:3::/32`, `2001:4:112::/48`, `2620:4f:8000::/48`; and
    it still lists `2001:10::/28` as ORCHID. Cite RFC 6890 for the *framework*, the IANA registry
    for the *contents*.

17. **RFC 6034 assigns no IPv6 range.** It defines unicast-prefix-based **IPv4** multicast in
    `234/8`, described as *"a mechanism similar to [RFC3306]"*. It does not obsolete RFC 3180's
    GLOP `233/8`. Filing it under IPv6 ranges (as its co-citation with RFC 3306 invites) is a
    category error.

18. **`ff3x::/32` SSM is not the only SSM range.** RFC 7371 §4.1.2: *"if the most significant flag
    bit in ff1 is set, then we would get the SSM range ffbx::/32"*. A hardcoded `ff3x::/32` test
    is incomplete under the updated architecture.

19. **Anycast has no prefix.** RFC 4291 §2.6 — anycast is drawn from unicast space and is
    syntactically indistinguishable. Any library that reports "anycast" from a prefix lookup is
    either reporting a specific *assigned* anycast address (`2001:1::1`, `2001:1::2`, `2001:1::3`,
    `2001:4:112::1`, `2620:4f:8000::/48`) or is wrong. Subnet-Router anycast (§2.6.1, prefix
    followed by all zeros) is the one *structural* form, and it means the "all-zeros host" address
    is legitimately in use, unlike IPv4's network address.

20. **The `%zone` suffix is not part of the address.** RFC 4007 §11's `fe80::1%eth0` notation
    *"must be used only within a node"*. Parsers must accept it from user input, strip it before
    any prefix comparison, and never emit it into a packet, a DNS record, or a URI host. (URI
    syntax requires percent-encoding the `%` as `%25`. `UNVERIFIED` — RFC 6874 not fetched.)
