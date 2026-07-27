# IPv4 address ranges: primary-source inventory

Research notes for `raddr`. Every claim below carries an RFC number and, where the RFC
is sectioned, a section number. Anything not substantiated from a primary source is
marked `UNVERIFIED`.

Two primary sources are used:

- The RFC text at `www.rfc-editor.org`.
- The IANA IPv4 Special-Purpose Address Registry
  (`https://www.iana.org/assignments/iana-ipv4-special-registry/`), which RFC 6890 §2.2
  establishes as the authoritative running list. The registry is cited as "IANA SPAR"
  below. It is a primary source, but it is *derived* from RFCs and lags/leads them in
  both directions (see Gotchas 6, 12, 14).

The registry's policy columns are defined in RFC 6890 §2.2.1 — Source, Destination,
Forwardable, Global, Reserved-by-Protocol — and RFC 8190 §2.1 renames "Global" to
"Globally Reachable". Verbatim from RFC 6890 §2.2.1:

- Source — "whether an address from the allocated special-purpose address block is
  valid when used as the source address"
- Destination — "whether an address from the allocated special-purpose address block is
  valid when used as the destination address"
- Forwardable — "whether a router may forward an IP datagram whose destination address
  is drawn from the allocated special-purpose address block"
- Global / Globally Reachable — "whether an IP datagram whose destination address is
  drawn from the allocated special-purpose address block is forwardable beyond a
  specified administrative domain"
- Reserved-by-Protocol — "whether the special-purpose address block is reserved by IP,
  itself"

`routable?` in the table below is shorthand for the Globally Reachable column where the
registry has one, and is derived from the defining RFC's own forwarding language where
it does not (multicast, class E sub-blocks).

## Ranges

| prefix | name | defining RFC + section | status | routable? | notes |
|---|---|---|---|---|---|
| 0.0.0.0/8 | "This network" | RFC 791 §3.2; IANA SPAR | current | no | RFC 791 §3.2: "A value of zero in the network field means this network. This is only used in certain ICMP messages." Registry: Source True, Destination False, Forwardable False, Globally Reachable False, Reserved-by-Protocol True. |
| 0.0.0.0/32 | "This host on this network" | RFC 1122 §3.2.1.3; IANA SPAR | current | no | Separate, more-specific registry row from 0.0.0.0/8. RFC 1122 §3.2.1.3: `{0, 0}` "MUST NOT be sent, except as a source address as part of an initialization procedure". RFC 6890 Table 2 collapsed this into a single 0.0.0.0/8 row named "This host on this network"; the registry now splits it. |
| 0.0.0.0/8 minus 0.0.0.0/32, i.e. `{0, <Host>}` | "Specified host on this network" | RFC 1122 §3.2.1.3 | current | no | RFC 1122 §3.2.1.3: "It MUST NOT be sent, except as a source address". Has no registry row of its own. |
| 10.0.0.0/8 | Private-Use | RFC 1918 §3 | current | no | RFC 1918 §3 calls it the "24-bit block". Registry: Source/Destination/Forwardable True, Globally Reachable False. |
| 100.64.0.0/10 | Shared Address Space | RFC 6598 §7 | current | no | RFC 6598 §4: "Packets with Shared Address Space source or destination addresses MUST NOT be forwarded across Service Provider boundaries." Forwardable True *within* a provider. Not RFC 1918 space (RFC 6598 abstract). |
| 127.0.0.0/8 | Loopback | RFC 1122 §3.2.1.3 | current | no | Whole /8, not just 127.0.0.1. RFC 1122 §3.2.1.3: "`{127, <any>}` Internal host loopback address. Addresses of this form MUST NOT appear outside a host." Registry marks Source/Destination/Forwardable/Globally Reachable all False with footnote [1]: "Several protocols have been granted exceptions to this rule. For examples, see RFC8029 and RFC5884." |
| 169.254.0.0/16 | Link Local | RFC 3927 §2.1 | current | no | RFC 3927 §2.7: "An IPv4 packet whose source and/or destination address is in the 169.254/16 prefix MUST NOT be sent to any router for forwarding, and any network device receiving such a packet MUST NOT forward it, regardless of the TTL." |
| 169.254.0.0/24 | Link-local reserved (low) | RFC 3927 §2.1 | current | no | "The first 256 and last 256 addresses in the 169.254/16 prefix are reserved for future use and MUST NOT be selected by a host using this dynamic configuration mechanism." No separate registry row. |
| 169.254.255.0/24 | Link-local reserved (high) | RFC 3927 §2.1 | current | no | Same sentence as above. Usable autoconf range is therefore 169.254.1.0 – 169.254.254.255. |
| 172.16.0.0/12 | Private-Use | RFC 1918 §3 | current | no | RFC 1918 §3 "20-bit block", range 172.16.0.0 – 172.31.255.255. |
| 192.0.0.0/24 | IETF Protocol Assignments | RFC 6890 §2.1 (orig. RFC 5736) | current | no | Registry footnote [2] on this row: "Not useable unless by virtue of a more specific reservation." All five booleans False. Container for the /29 and /32 assignments below. |
| 192.0.0.0/29 | IPv4 Service Continuity Prefix | RFC 7335 §6 (orig. RFC 6333 §10) | current | no | RFC 6333 §10: "IANA has allocated a well-known IPv4 192.0.0.0/29 network prefix. That range is used to number the Dual-Stack Lite interfaces." RFC 7335 §6 renamed it from "DS-Lite" to "IPv4 Service Continuity Prefix" so 464XLAT can share it. Forwardable True. |
| 192.0.0.1/32 | DS-Lite AFTR | RFC 6333 §5.7 | current | no | AFTR-side address, "the IPv4 address of the default router for such Dual-Stack Lite hosts". No separate registry row. |
| 192.0.0.2/32 | DS-Lite B4 | RFC 6333 §6.5 | current | no | RFC 6333 §6.5: a B4 "MAY use any other addresses within the 192.0.0.0/29 range" if 192.0.0.2 is unavailable. RFC 7335 §4: "a host MUST NOT enable two active IPv4 continuity solutions simultaneously in a way that would cause a node to have overlapping 192.0.0.0/29 address space." |
| 192.0.0.8/32 | IPv4 dummy address | RFC 7600 §6 | current | no | Source address for synthesized ICMPv4 errors (RFC 7600 §4.8). Registry: Source True, Destination False. |
| 192.0.0.9/32 | Port Control Protocol Anycast | RFC 7723 §4.1 | current | **yes** | Globally Reachable True. Sits *inside* 192.0.0.0/24, whose own booleans are all False. |
| 192.0.0.10/32 | Traversal Using Relays around NAT Anycast | RFC 8155 §8.1 | current | **yes** | Globally Reachable True. Same nesting inversion as PCP anycast. |
| 192.0.0.170/32, 192.0.0.171/32 | NAT64/DNS64 Discovery | RFC 7050 §8.2 (also RFC 8880) | current | no | All of Source/Destination/Forwardable/Globally Reachable False, Reserved-by-Protocol True. These are DNS names' A-record sentinels, never packet endpoints. |
| 192.0.2.0/24 | Documentation (TEST-NET-1) | RFC 5737 §3 | current | no | RFC 5737 §4: "SHOULD NOT appear on the public Internet"; operators "SHOULD add these address blocks to the list of non-routeable address spaces". |
| 192.31.196.0/24 | AS112-v4 | RFC 7535 §8.1 | current | **yes** | DNAME-based AS112 redirection; 192.31.196.1 is the nameserver address. Globally Reachable True — it is deliberately anycast on the public Internet. |
| 192.52.193.0/24 | AMT | RFC 7450 §7.1.1 | current | **yes** | Automatic Multicast Tunneling relay-discovery anycast. RFC 7450 §4.1.5.2: relays "advertise a route to the address prefix (e.g., via BGP)". Registry: Globally Reachable True. |
| 192.88.99.0/24 | Deprecated (6to4 Relay Anycast) | RFC 7526 §4, §7 (orig. RFC 3068 §2.3) | **deprecated** | no | RFC 7526 §7: IANA "has marked the 192.88.99.0/24 prefix ... as 'Deprecated (6to4 Relay Anycast)' ... The Boolean values for the address block 192.88.99.0/24 have been removed." RFC 7526 §4: "The prefix 192.88.99.0/24 MUST NOT be reassigned for other use except by a future IETF Standards Action." Registry carries Termination Date 2015-03. |
| 192.88.99.1/32 | 6to4 Relay Anycast address | RFC 3068 §2.4 | **deprecated** | no | RFC 7526 §4 "formally deprecates the anycast 6to4 transition mechanism defined in [RFC3068] and the associated anycast IPv4 address 192.88.99.1". IPv6 counterpart 2002:c058:6301:: (RFC 3068 §2.5). |
| 192.88.99.2/32 | 6a44-relay anycast address | RFC 6751; IANA SPAR | current (per registry) | no | Still an active registry row with Source/Destination/Forwardable True, *inside* the deprecated /24. RFC 6751 is Experimental. `UNVERIFIED`: whether the IETF intends this row to survive RFC 7526's deprecation of the parent — I found no RFC text reconciling the two. |
| 192.168.0.0/16 | Private-Use | RFC 1918 §3 | current | no | RFC 1918 §3 "16-bit block". |
| 192.175.48.0/24 | Direct Delegation AS112 Service | RFC 7534 §7.2.3 | current | **yes** | Globally Reachable True. RFC 7534 §7.1: "The autonomous system number 112, the IPv4 prefix 192.175.48.0/24, and the IPv6 prefix 2620:4f:8000::/48 were assigned by ARIN." AS 112 itself (RFC 7534 §7.2.2). |
| 198.18.0.0/15 | Benchmarking | RFC 2544 §C.2.2.2, updated by RFC 6815 §4.2 | current | no | RFC 6815 §4.2: "The network addresses 198.18.0.0 through 198.19.255.255 have been assigned to the BMWG by the IANA for this purpose." Registry: Forwardable True but Globally Reachable False. |
| 198.51.100.0/24 | Documentation (TEST-NET-2) | RFC 5737 §3 | current | no | See TEST-NET-1. |
| 203.0.113.0/24 | Documentation (TEST-NET-3) | RFC 5737 §3 | current | no | See TEST-NET-1. |
| 224.0.0.0/4 | Multicast (class D) | RFC 1112 §4; RFC 5771 §3 | current | conditional | RFC 1112 §4: "Host groups are identified by class D IP addresses, i.e., those with '1110' as their high-order four bits ... host group addresses range from 224.0.0.0 to 239.255.255.255." **Not in the IANA Special-Purpose registry** — it has its own registry. Routability varies per sub-block below. |
| 224.0.0.0/32 | Reserved, never assigned | RFC 1112 §4 | current | no | "The address 224.0.0.0 is guaranteed not to be assigned to any group." |
| 224.0.0.1/32 | All-hosts group | RFC 1112 §4 | current | no | "assigned to the permanent group of all IP hosts (including gateways)"; "used to address all multicast hosts on the directly connected network. There is no multicast address (or any other IP address) for all hosts on the total Internet." |
| 224.0.0.0/24 | Local Network Control Block | RFC 5771 §4 | current | no | "protocol control traffic that is not forwarded off link" (RFC 5771 §4). Assignment policy: Expert Review / IESG Approval / Standards Action (§4.1). |
| 224.0.1.0/24 | Internetwork Control Block | RFC 5771 §5 | current | yes | "protocol control traffic that MAY be forwarded through the Internet" (RFC 5771 §5). |
| 224.0.2.0 – 224.0.255.255 | AD-HOC Block I | RFC 5771 §6 | current | yes | "MAY be globally routed" (RFC 5771 §6). Not a CIDR-aligned block — it is a range. |
| 224.2.0.0/16 | SDP/SAP Block | RFC 5771 §7 | current | yes | Addresses "chosen randomly ... by applications that receive addresses through ... Session Announcement Protocol"; no IANA assignment required (§7.1). |
| 224.3.0.0 – 224.4.255.255 | AD-HOC Block II | RFC 5771 §6 | current | yes | Two /16s. |
| 224.1.0.0/16; 224.5.0.0 – 224.255.255.255; 225.0.0.0 – 231.255.255.255; 234.0.0.0 – 238.255.255.255 | Reserved multicast | RFC 5771 §3 | current | n/a | Reserved per RFC 5771 §3. Note 234/8 was subsequently carved out — see next row. |
| 234.0.0.0/8 | Unicast-Prefix-Based Multicast (UBM) | RFC 6034 §3, §6 | current | yes | RFC 6034 §3: "A multicast address with the prefix 234/8 indicates that the address is a Unicast-Based Multicast (UBM) address." Post-dates RFC 5771's listing of 234/8 as reserved. |
| 232.0.0.0/8 | Source-Specific Multicast (SSM) | RFC 5771 §8 | current | yes | "traffic is forwarded to receivers from only those multicast sources"; "no IANA assignment policy is required" (§8.1). Group address alone is meaningless without an (S,G) pair. |
| 233.0.0.0 – 233.251.255.255 | GLOP | RFC 5771 §9 | current | yes | "globally-scoped, statically-assigned addresses" derived from a 16-bit ASN (§9). |
| 233.252.0.0/14 | AD-HOC Block III | RFC 5771 §9.2 | current | yes | Extended GLOP space. |
| 233.252.0.0/24 | MCAST-TEST-NET (documentation) | RFC 5771 §9.2; RFC 6676 §2 | current | no | RFC 6676 §2: "the IPv4 multicast addresses allocated for documentation purposes are 233.252.0.0 - 233.252.0.255 (233.252.0.0/24)". |
| 233.251.240.0/24 – 233.251.255.0/24 | GLOP documentation addresses | RFC 6676 §2.2 | current | no | Derived from documentation ASNs 64496–64511. |
| 234.192.0.2, 234.198.51.100, 234.203.0.113 | UBM documentation addresses | RFC 6676 §2.3 | current | no | Unicast-prefix-based documentation addresses built from the TEST-NETs. |
| 239.0.0.0/8 | Administratively Scoped Block | RFC 2365 §4; RFC 5771 §10 | current | no | RFC 2365 §4: "The administratively scoped IPv4 multicast address space is defined to be the range 239.0.0.0 to 239.255.255.255." RFC 5771 §10: "for local use within a domain"; no IANA policy needed (§10.1). |
| 239.255.0.0/16 | IPv4 Local Scope | RFC 2365 §6.1 | current | no | "239.255.0.0/16 is defined to be the IPv4 Local Scope." May grow downward into 239.254.0.0/16 and 239.253.0.0/16 (§6.1.1). |
| 239.192.0.0/14 | IPv4 Organization Local Scope | RFC 2365 §6.2 | current | no | Exact quote from §6.2. |
| 239.0.0.0/10, 239.64.0.0/10, 239.128.0.0/10 | Unassigned scope expansion | RFC 2365 §6.2.1 | current | no | "unassigned and available for expansion". |
| top /24 of every scope | Scope-relative assignments | RFC 2365 §9 | current | no | "The high order /24 in every scoped region is reserved for relative assignments." So e.g. 239.255.255.0/24 is not a normal group range. |
| 239.255.255.245/32 | Scope-relative documentation address | RFC 6676 §2.1 | current | no | Scope-relative offset 10. |
| 240.0.0.0/4 | Reserved (class E) | RFC 1112 §4 | current | no | RFC 1112 §4: "Class E IP addresses, i.e., those with '1111' as their high-order four bits, are reserved for future addressing modes." Registry: all booleans False, Reserved-by-Protocol True. Note the *defining* RFC is 1112, not 791 — RFC 791 §3.2 only says "111 escape to extended addressing mode ... The extended addressing mode is undefined." |
| 255.255.255.255/32 | Limited Broadcast | RFC 919 §7; RFC 8190 §2.2 | current | no | RFC 919 §7: "The address 255.255.255.255 denotes a broadcast on a local hardware network, which must not be forwarded." RFC 1122 §3.2.1.3: `{-1,-1}` "MUST NOT be used as a source address". RFC 8190 §2.2 flipped Reserved-by-Protocol from False to True. |
| `{<Network>, -1}` | Directed (net-directed) broadcast | RFC 919 §7; RFC 1122 §3.2.1.3 | current | n/a | Not a fixed prefix — depends on the network's own mask. RFC 919 §7 example: "broadcast to all of net 36 by using 36.255.255.255". Destination-only. |
| `{<Network>, <Subnet>, -1}` | Subnet-directed broadcast | RFC 922 §7; RFC 1122 §3.2.1.3 | current | n/a | Depends on the *local subnet mask*, which is not derivable from the address. Destination-only. |
| `{<Network>, -1, -1}` | All-subnets broadcast | RFC 922 §4, §6.2, §7 | current | n/a | RFC 922 §7: "The 'all subnets' number is also all ones; this means that a host wishing to broadcast to all hosts on a remote IP network need not know how the destination address is divided up." Forwarding uses reverse-path checks (§6.2). |

Ranges documented: 47 rows.

## Semantics that a prefix table cannot express

1. **Subnet-directed broadcast is mask-dependent, not prefix-dependent.** RFC 1122
   §3.2.1.3 defines `{<Network>, <Subnet>, -1}` and `{<Network>, -1}`. Whether
   `10.1.2.255` is a broadcast address depends entirely on the local subnet mask —
   it is a host address on a /16 and a broadcast address on a /24. A pure
   address-to-prefix lookup can never answer "is this a broadcast address"; only
   `(address, mask)` can. RFC 922 §7 makes the same point about "all subnets":
   `36.255.255.255` "may denote all the hosts on a single hardware network, or all the
   hosts on a subnetted IP network".

2. **The same address has different legality as source vs destination.** This is why
   RFC 6890 §2.2.1 has *two* separate boolean columns. Concrete pairs:
   - `0.0.0.0` — Source True, Destination False (IANA SPAR). RFC 1122 §3.2.1.3:
     `{0,0}` "MUST NOT be sent, except as a source address as part of an initialization
     procedure" (i.e. DHCP discovery).
   - `255.255.255.255` — Source False, Destination True. RFC 1122 §3.2.1.3: limited
     broadcast "MUST NOT be used as a source address".
   - `192.0.0.8/32` (4rd dummy) — Source True, Destination False (IANA SPAR): it exists
     only to appear in the source field of synthesized ICMPv4 errors (RFC 7600 §4.8).
   A single "is this address special" boolean discards this axis entirely.

3. **127/8 is a whole /8, but its semantics are per-address in practice.** RFC 1122
   §3.2.1.3 says `{127, <any>}` "MUST NOT appear outside a host" — the entire /8, all
   16,777,216 addresses, not just 127.0.0.1. But the registry's blanket "False" on
   Source/Destination/Forwardable carries footnote [1]: "Several protocols have been
   granted exceptions to this rule. For examples, see RFC8029 and RFC5884." So
   forwarding a 127/8 destination is spec-violating in general and spec-conformant for
   MPLS LSP ping. A prefix table says "loopback"; it cannot say "unless you are
   RFC 8029."

4. **Multicast group addresses are not endpoints.** For 232.0.0.0/8 (RFC 5771 §8),
   "traffic is forwarded to receivers from only those multicast sources" — the group
   address alone identifies nothing; reachability is a property of the `(S,G)` pair.
   Similarly 224.0.0.0/24 (RFC 5771 §4) is "not forwarded off link" while 224.0.1.0/24
   (RFC 5771 §5) "MAY be forwarded through the Internet", so "is this multicast address
   routable" splits at a /24 boundary inside a /4.

5. **239/8 scope is administrative, not numeric.** RFC 2365 §6.1 pins the Local Scope
   at 239.255.0.0/16 but §6.1.1 says it "may grow downward from 239.255.0.0/16 into the
   reserved ranges 239.254.0.0/16 and 239.253.0.0/16" — the actual boundary is a local
   configuration decision. RFC 2365 §9 further reserves "the high order /24 in every
   scoped region" for scope-relative assignments, so the meaning of an address depends
   on which scope's boundary router you ask.

6. **240/4 per spec vs 240/4 in practice.** RFC 1112 §4 reserves class E "for future
   addressing modes" and the registry marks it Reserved-by-Protocol True with every
   other boolean False. `UNVERIFIED`: several widely deployed stacks reportedly accept
   240/4 as ordinary unicast on local links while routers and other stacks drop it
   outright; I found no RFC that changes 240/4's status, only expired Internet-Drafts,
   which are not primary sources. Treat 240/4 as reserved per spec and record that
   real-world behaviour is stack-dependent rather than asserting either answer.

7. **"Not globally reachable" is not the same as "not forwardable".** RFC 6890 §2.2.1
   distinguishes Forwardable ("a router may forward") from Global/Globally Reachable
   ("forwardable beyond a specified administrative domain"). 10.0.0.0/8, 100.64.0.0/10,
   198.18.0.0/15 and 192.0.0.0/29 all have Forwardable True and Globally Reachable
   False. Packets in these ranges are routed every day — just not across the boundary
   in question. A single "private/public" bit conflates two different questions.

8. **Reachability depends on which administrative domain is asking.** RFC 6598 §4:
   "Packets with Shared Address Space source or destination addresses MUST NOT be
   forwarded across Service Provider boundaries" — inside the provider they are
   ordinary. RFC 1918 §3: private routing info "shall not be propagated on
   inter-enterprise links". The address does not tell you where the observer stands.

9. **A more-specific special-purpose reservation overrides its container.** IANA SPAR
   footnote [2] on 192.0.0.0/24: "Not useable unless by virtue of a more specific
   reservation." So the /24 is unusable, yet 192.0.0.9/32 (RFC 7723 §4.1) and
   192.0.0.10/32 (RFC 8155 §8.1) inside it are Globally Reachable True. Longest-prefix
   match is mandatory; first-match-wins over a list sorted any other way is wrong.

10. **Deprecation does not free the prefix.** RFC 7526 §7: the booleans for
    192.88.99.0/24 "have been removed" — there is no answer to "is this forwardable",
    not a False answer. RFC 7526 §4: the prefix "MUST NOT be reassigned for other use
    except by a future IETF Standards Action." A schema with a mandatory boolean cannot
    represent this state.

11. **Link-local carries a hard forwarding prohibition that outranks TTL.** RFC 3927
    §2.7: such a packet "MUST NOT be sent to any router for forwarding, and any network
    device receiving such a packet MUST NOT forward it, regardless of the TTL." And
    RFC 3927 §1.9: "A host SHOULD NOT have both an operable routable address and an IPv4
    Link-Local address configured on the same interface" — so 169.254/16 also implies
    something about the host's configuration state, not just the packet.

12. **The autoconfigurable part of 169.254/16 is smaller than the prefix.** RFC 3927
    §2.1 reserves "the first 256 and last 256 addresses". An address like
    169.254.0.5 is link-local *and* not a legal autoconfiguration result.

## Gotchas

1. **RFC 2544 contains a typo in the benchmarking range.** RFC 2544 §C.2.2.2 literally
   reads "The network addresses 192.18.0.0 through 198.19.255.255 are have been assigned
   to the BMWG" — `192.18.0.0`, not `198.18.0.0`. RFC 6815 §4.2 states the range
   correctly as "198.18.0.0 through 198.19.255.255". An implementation transcribing from
   RFC 2544 alone gets a range spanning six /8s of live global unicast space.

2. **240.0.0.0/4 is defined by RFC 1112 §4, not RFC 791.** RFC 791 §3.2 only defines
   classes A/B/C and says "111 escape to extended addressing mode ... The extended
   addressing mode is undefined." Class D and Class E are both introduced by RFC 1112
   §4. Citing RFC 791 for class E is a very common and wrong citation.

3. **255.255.255.255/32 is not inside 240.0.0.0/4 for classification purposes — except
   numerically it is.** The limited broadcast address is a distinct registry row citing
   RFC 919 §7, while its containing /4 cites RFC 1112 §4. Longest-prefix match resolves
   this, but implementations that check `>= 240.0.0.0` first and stop will label the
   broadcast address "reserved (class E)".

4. **224.0.0.0/4 and 240.0.0.0/4 asymmetry in the registries.** 240.0.0.0/4 *is* in the
   IANA Special-Purpose Address Registry; 224.0.0.0/4 is *not* — multicast lives in its
   own IANA registry under RFC 5771. Any implementation that builds its range table by
   parsing only the special-purpose registry silently produces no answer at all for the
   entire multicast /4.

5. **RFC 5735 and RFC 5736 are obsolete and cite obsolete facts.** RFC 6890 states it
   "obsoletes RFCs 4773, 5156, 5735, and 5736." RFC 5735 §3 lists 192.0.0.0/24 as
   defined by RFC 5736, 192.88.99.0/24 as active 6to4 anycast per RFC 3068, and
   224.0.0.0/4 per RFC 3171 — all three are now wrong (RFC 6890 §2.1, RFC 7526 §4,
   RFC 5771 respectively). RFC 5735 also predates 100.64.0.0/10 (RFC 6598, 2012) and
   192.0.0.0/29 (RFC 6333). RFC 5735 remains a popular copy-paste source precisely
   because it presents one tidy list.

6. **The RFC 6890 tables are themselves stale.** RFC 6890's IPv4 registry snapshot has
   16 entries and omits 192.31.196.0/24 (RFC 7535 §8.1), 192.52.193.0/24 (RFC 7450
   §7.1.1), 192.175.48.0/24 (RFC 7534 §7.2.3), 192.0.0.8/32 (RFC 7600 §6),
   192.0.0.9/32 (RFC 7723 §4.1), 192.0.0.10/32 (RFC 8155 §8.1), 192.0.0.170/32 and
   192.0.0.171/32 (RFC 7050 §8.2), 192.88.99.2/32 (RFC 6751), and 0.0.0.0/32. It also
   still shows 192.88.99.0/24 as Globally Reachable True and names 192.0.0.0/29
   "DS-Lite" rather than "IPv4 Service Continuity Prefix" (renamed by RFC 7335 §6).
   RFC 6890 defines the *framework*; the registry, not RFC 6890's tables, is the data.

7. **"Global" was renamed to "Globally Reachable" by RFC 8190 §2.1.** Code and schemas
   written against RFC 6890's column names will not match the current registry's
   headers. RFC 8190 §2.1: "the use of the term 'global' defined in [RFC6890] is
   replaced with 'globally reachable.'"

8. **RFC 8190 §2.2 flipped Reserved-by-Protocol for 255.255.255.255/32 from False to
   True.** A table built from RFC 6890 alone disagrees with the current registry on this
   single cell. Same document, §2.3, changed the IPv6 TEREDO row's Globally Reachable
   from False to "N/A" — proof that these columns are not stably boolean over time.

9. **192.88.99.0/24's booleans do not exist; they are not False.** RFC 7526 §7: "The
   Boolean values for the address block 192.88.99.0/24 have been removed." Parsers that
   coerce empty registry cells to `false` invent a claim the IETF deliberately declined
   to make. It is also the only IPv4 row with a non-N/A Termination Date (2015-03).

10. **192.88.99.2/32 is still live inside the deprecated 192.88.99.0/24.** The registry
    carries 6a44-relay anycast (RFC 6751) with Source/Destination/Forwardable True while
    its parent is deprecated with no booleans. Blanket-blocking the /24 as "deprecated,
    therefore dead" contradicts a more-specific active row. `UNVERIFIED`: no RFC I found
    reconciles RFC 6751 with RFC 7526 §4.

11. **192.0.0.0/24 is "not useable" yet contains two globally reachable anycast
    addresses.** Registry footnote [2] reads "Not useable unless by virtue of a more
    specific reservation", and 192.0.0.9/32 (RFC 7723 §4.1) and 192.0.0.10/32 (RFC 8155
    §8.1) both have Globally Reachable True. This is the sharpest nesting inversion in
    IPv4: the container's answer is the *opposite* of the leaf's. Any implementation
    that resolves by shortest prefix, insertion order, or "first special-purpose row
    that matches" gets these two addresses wrong.

12. **RFC 7335 §6 renamed 192.0.0.0/29 but the old name is everywhere.** Old: "DS-Lite
    [RFC6333]". New: "IPv4 Service Continuity Prefix [RFC7335]". Range tables keyed on
    the name string, or that cite RFC 6333 as the current definer, are out of date; the
    prefix is now shared with 464XLAT (RFC 7335 §3).

13. **100.64.0.0/10 is routinely omitted from private-IP and SSRF filters.** It was
    assigned in 2012 (RFC 6598 §7), well after the RFC 1918 list most filters encode.
    RFC 6598 §4 requires that it not cross provider boundaries, so from a server's
    perspective a 100.64/10 destination is an internal-network reachability risk exactly
    like RFC 1918 space, yet RFC 6598's abstract explicitly says it "is distinct from
    RFC 1918 private address space" — which is why authors of allow/deny lists skip it.

14. **169.254.0.0/16 is the single most consequential SSRF omission.** RFC 3927 §2.1
    defines it as link-local; in practice 169.254.169.254 is the cloud instance-metadata
    address. A filter that blocks only RFC 1918 §3's three blocks plus 127/8 leaves
    metadata credentials exposed. `UNVERIFIED`: the 169.254.169.254 convention is vendor
    practice, not defined by any RFC — RFC 3927 assigns the prefix only.

15. **127.0.0.1 is not the loopback range.** RFC 1122 §3.2.1.3 covers `{127, <any>}` —
    the whole /8. Filters that compare against the literal string `127.0.0.1` are
    bypassed by 127.0.0.2, 127.1, 0x7f.0.0.1, and 2130706433. Related: 0.0.0.0 is a
    separate registry row (0.0.0.0/32, RFC 1122 §3.2.1.3) and on many stacks connects to
    localhost, but it is *not* in 127/8 and is missed by loopback-only checks.

16. **0.0.0.0/8 and 0.0.0.0/32 are two different registry rows with different defining
    RFCs.** The /8 cites RFC 791 §3.2 ("This network"); the /32 cites RFC 1122 §3.2.1.3
    ("This host on this network"). RFC 6890's Table 2 had only one row, a /8 bearing the
    /32's name. Anyone reproducing RFC 6890 rather than the registry loses the
    distinction — and RFC 1122 §3.2.1.3 in fact defines a *third* case, `{0, <Host>}`
    ("Specified host on this network"), which has no registry row at all.

17. **The 172.16/12 boundary is miscoded constantly.** RFC 1918 §3 gives
    "172.16.0.0 - 172.31.255.255 (172.16/12 prefix)". Common wrong forms: 172.16/16
    (too narrow), 172.0.0.0/8 (far too wide), and regex `172\.1[6-9]|172\.2[0-9]` which
    silently drops 172.30 and 172.31.

18. **RFC 5771's own reserved list is already outdated by RFC 6034.** RFC 5771 §3 lists
    234.0.0.0 – 238.255.255.255 as reserved; RFC 6034 §3 subsequently assigned 234/8 to
    unicast-prefix-based multicast and §6 records the IANA assignment. Two Standards
    Track/Proposed Standard documents, direct conflict, later one wins.

19. **RFC 5771's blocks are ranges, not CIDR prefixes.** AD-HOC Block I is
    "224.0.2.0 – 224.0.255.255" (RFC 5771 §6) and GLOP is "233.0.0.0 – 233.251.255.255"
    (§9) — neither is expressible as a single prefix. A CIDR-only data model must
    decompose them, and rounding GLOP up to 233.0.0.0/8 swallows AD-HOC Block III
    (233.252.0.0/14, §9.2) and MCAST-TEST-NET (RFC 6676 §2).

20. **239.0.0.0/8 is not uniformly "site-local".** RFC 2365 §6.2 pins Organization Local
    Scope at 239.192.0.0/14 and §6.1 pins Local Scope at 239.255.0.0/16; §6.2.1 leaves
    239.0.0.0/10, 239.64.0.0/10 and 239.128.0.0/10 unassigned. Treating all of 239/8 as
    one scope loses the distinction the RFC exists to make.

21. **AS112 and AMT prefixes look private and are not.** 192.31.196.0/24 (RFC 7535
    §8.1), 192.175.48.0/24 (RFC 7534 §7.2.3) and 192.52.193.0/24 (RFC 7450 §7.1.1) all
    appear in the special-purpose registry and all have Globally Reachable True — they
    are anycast on the public Internet by design. Blocking everything in the
    special-purpose registry as "not real Internet" breaks them.

22. **192.0.2.0/24 is TEST-NET-1, but 198.18.0.0/15 is not documentation.** RFC 5737 §3
    covers the three TEST-NETs; RFC 2544 §C.2.2.2 / RFC 6815 §4.2 covers benchmarking.
    They are frequently merged into one "example addresses" bucket, but their registry
    booleans differ: TEST-NETs are Source/Destination False, benchmarking is
    Source/Destination/Forwardable True.

23. **RFC 3927 §2.1's reserved sub-ranges are almost never modelled.** 169.254.0.0/24
    and 169.254.255.0/24 "MUST NOT be selected by a host using this dynamic
    configuration mechanism". An implementation reporting "link-local, autoconfigurable"
    for 169.254.0.1 is wrong on the second half.

24. **RFC 1918 §3's class terminology confuses readers into wrong masks.** The RFC calls
    172.16/12 "the 20-bit block" (20 host bits, /12 prefix) and 192.168/16 "the 16-bit
    block". Implementers who read "20-bit block" as a /20 produce 172.16.0.0/20.

25. **RFC 3068 is obsoleted but its own text does not say so.** RFC 7526 §4 deprecates
    the mechanism "defined in [RFC3068]" and also deprecates RFC 6732; RFC 3068's body
    text still reads as a live Standards Track spec (§2.3, §2.4, §2.5). Fetching the
    RFC body without checking its status header yields a confidently wrong "current"
    classification for 192.88.99.0/24.

26. **Both RFC 5735 and RFC 5736 are Informational, not Standards Track**, and RFC 5736
    itself warns that "address prefixes listed in the IPv4 Special Purpose Address
    Registry are not guaranteed routability in any particular local or global context."
    Registry membership answers "is this specially assigned", never "can I reach it".
