# Block semantics: what each IANA special-purpose block is actually for

Research notes for `raddr`. Primary sources: the IANA IPv4/IPv6 Special-Purpose Address
Registries and the defining RFCs at www.rfc-editor.org. Registry attribute values quoted
below are those in the vendored CSVs (`inst/extdata/iana-ipv4-special-registry.csv`,
`inst/extdata/iana-ipv6-special-registry.csv`), which match the live registries as fetched
on 2026-07-27.

## Registry vocabulary (read this first)

The five policy columns come from RFC 6890, Section 2.2.1, as amended by RFC 8190:

- **Source** — "whether an address ... is valid when used as the source address of an IP
  datagram that **transits two devices**" (RFC 6890, Section 2.2.1).
- **Destination** — same, as destination address.
- **Forwardable** — "whether a router may forward an IP datagram whose destination address
  is drawn from the ... block **between external interfaces**" (RFC 6890, Section 2.2.1).
- **Globally Reachable** — "whether an IP datagram whose destination address is drawn from
  the ... block is forwardable **beyond a specified administrative domain**". RFC 8190
  renamed this from "Global" precisely because "global" was being misread as "public
  Internet address" (RFC 8190, Section 3).
- **Reserved-by-Protocol** — "whether the special-purpose address block is reserved by IP,
  itself" (RFC 6890, Section 2.2.1), i.e. a conformant IP stack must special-case it.

Constraint: "If the value of 'Destination' is FALSE, the values of 'Forwardable' and
'Global' must also be false" (RFC 6890, Section 2.2.1). There is **no** rule tying Source
to anything, which is why several blocks are Source=True / Destination=False.

Registry footnotes (verbatim from the IANA pages):

- IPv4 **[1]** (attached to 127.0.0.0/8): "Several protocols have been granted exceptions
  to this rule. For examples, see [RFC8029] and [RFC5884]."
- IPv4 **[2]** (attached to 192.0.0.0/24): "Not useable unless by virtue of a more specific
  reservation."
- IPv6 **[1]** (attached to 2001::/23): "Unless allowed by a more specific allocation."
- IPv6 **[2]** (attached to 2001::/32): "See Section 5 of [RFC4380] for details."
- IPv6 **[3]** (attached to 2002::/16): "See [RFC3056] for details."
- IPv6 **[4]** (attached to fc00::/7): "See [RFC4193] for more details on the routability of
  Unique-Local addresses. The Unique-Local prefix is drawn from the IPv6 Global Unicast
  Address range, but is specified as not globally routed."

Two structural facts that drive most misclassification:

1. The registry is a **longest-prefix-match** structure, not a flat list. Several blocks
   contain more-specific blocks with *opposite* policy values.
2. "Globally Reachable = False" does **not** mean "private". It means "not forwardable
   beyond an administrative domain". Documentation, benchmarking, discard, and translation
   prefixes are all False for entirely different reasons than RFC 1918 is False.

---

## Block semantics

### IPv4

#### 0.0.0.0/8 — "This network"

- **Defining RFC:** RFC 791, Section 3.2 (address formats / special case of network zero).
  Allocation date 1981-09.
- **Purpose:** Refers to "this network" — the local network, without naming it. Only
  meaningful during bootstrap, before a host knows its own network number.
- **Registry:** Source True, Destination False, Forwardable False, Globally Reachable
  False, Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** Not "private" and not "reserved for future use". It is
  Source=True, so a DHCP DISCOVER with source 0.0.0.0 is *legal on the wire*; a classifier
  that reports "invalid address" for 0.0.0.0 will flag legitimate bootstrap traffic.
  Also, only 0.0.0.0/8 is special — 0.1.2.3 is in the block but has no assigned meaning
  beyond it.

#### 0.0.0.0/32 — "This host on this network"

- **Defining RFC:** RFC 1122, Section 3.2.1.3 ("{0,0}" — this host on this network).
  Allocation date recorded as 1981-09.
- **Purpose:** The unspecified address. Legal only as a source, and only until the host
  learns its address.
- **Registry:** identical policy values to 0.0.0.0/8 (Source True, everything else False,
  Reserved-by-Protocol True).
- **Status:** Current.
- **Misclassification risk:** It is a *more-specific inside* 0.0.0.0/8 with the same values,
  so it is harmless for policy lookups — but it is the canonical test that a lookup returns
  the **most specific** match. A library that returns 0.0.0.0/8 for input `0.0.0.0` is
  matching wrongly even though the answer happens to be right.

#### 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 — Private-Use

- **Defining RFC:** RFC 1918, Section 3 (address allocation). Allocation date 1996-02.
- **Purpose:** Address space for enterprises that do not need globally unique addresses.
  Routers "should" filter them; RFC 1918 Section 5 requires that routing information for
  private networks not be propagated on inter-enterprise links.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol **False**.
- **Status:** Current (RFC 1918 is BCP 5).
- **Misclassification risk:** Forwardable=True surprises people — these *are* routed, just
  not across administrative boundaries. Reserved-by-Protocol=False means IP itself does not
  special-case them; only policy does. Treating "private" as a synonym for
  "not globally reachable" over-collects: it sweeps in documentation, benchmarking,
  loopback, CGN and discard space, which have different remediation.

#### 100.64.0.0/10 — Shared Address Space

- **Defining RFC:** RFC 6598, Section 7 (allocation); rationale in Sections 1 and 3;
  operational rules in Section 4. Allocation date 2012-04.
- **Purpose:** Numbering the interface between a Service Provider CGN and CPE. RFC 6598
  Section 1 introduces it because RFC 1918 space collides when a subscriber uses the *same*
  RFC 1918 range on the LAN side of the CPE that the ISP uses on the WAN side; a
  provider needs space that is guaranteed not to clash with the subscriber's own.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol False — the same tuple as RFC 1918.
- **Status:** Current (BCP 153).
- **Misclassification risk:** This is the single most commonly mishandled IPv4 block.
  - Calling it **public** is wrong: RFC 6598 Section 4 says "Packets with Shared Address
    Space source or destination addresses MUST NOT be forwarded across Service Provider
    boundaries", and providers must filter route advertisements for it.
  - Calling it **RFC 1918 private** is also wrong, and operationally worse: RFC 6598
    Section 4 forbids using it as if it were subscriber private space, and Section 3
    explains the whole point is that it must be *distinct* from any RFC 1918 range the
    subscriber may already use. Geolocation, abuse attribution and rate-limiting all break
    if 100.64/10 is bucketed as "customer LAN": these addresses are *shared by many
    subscribers* behind one CGN, so a single 100.64/10 address does not identify a host.
  - DNS: RFC 6598 Section 4 requires reverse queries for the block not to leak to the
    global DNS. Unlike RFC 1918, there is **no AS112 direct delegation** for
    100.64.0.0/10 in RFC 7534's zone list (see AS112 below) — so leaked queries have no
    sink. `UNVERIFIED`: whether any later RFC added a 100.64/10 zone to the AS112 set.

#### 127.0.0.0/8 — Loopback

- **Defining RFC:** RFC 1122, Section 3.2.1.3. Allocation date 1981-09.
- **Purpose:** Internal host loopback. RFC 1122 Section 3.2.1.3 states that addresses of
  this form must never appear outside a host.
- **Registry:** Source False [1], Destination False [1], Forwardable False [1], Globally
  Reachable False [1], Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** Two traps.
  1. It is a **/8**, not 127.0.0.1/32. 127.53.0.9 is loopback. Classifiers that hardcode
     `== 127.0.0.1` under-match.
  2. All four False values carry footnote [1]: "Several protocols have been granted
     exceptions to this rule. For examples, see [RFC8029] and [RFC5884]." MPLS LSP ping
     (RFC 8029) uses 127/8 destinations in the MPLS payload, and BFD for MPLS LSPs
     (RFC 5884) does likewise. So "127/8 on the wire is always an attack/bogon" is a false
     positive generator on any MPLS network.

#### 169.254.0.0/16 — Link Local

- **Defining RFC:** RFC 3927 (IPv4 Link-Local addresses); Section 2.1 defines the block and
  Section 2.6 forbids routing. Allocation date 2005-05.
- **Purpose:** Autoconfigured addresses for a single link when no DHCP server or manual
  configuration is available.
- **Registry:** Source True, Destination True, **Forwardable False**, Globally Reachable
  False, Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** Forwardable=False is what separates it from RFC 1918 —
  169.254/16 is not merely "not global", it must not cross *any* router, per RFC 3927
  Section 2.6. A classifier that lumps link-local in with "private" loses that distinction.
  Also 169.254.169.254 (cloud metadata service) lives here and is the classic SSRF target:
  it is link-local, not private, and blocking only RFC 1918 does not stop it.

#### 192.0.0.0/24 — IETF Protocol Assignments

- **Defining RFC:** RFC 6890, Section 2.1. Allocation date 2010-01.
- **Purpose:** A reservoir from which the IETF carves individual protocol addresses. It is
  not itself usable.
- **Registry:** all five booleans False, Reserved-by-Protocol False, plus footnote [2]:
  "Not useable unless by virtue of a more specific reservation."
- **Status:** Current.
- **Misclassification risk:** This is the block where longest-prefix-match matters most.
  The /24 says "nothing here is reachable", but it contains more-specifics that are
  Forwardable and even Globally Reachable (192.0.0.9/32, 192.0.0.10/32). A classifier that
  matches shortest-prefix, or that stops at the first match in file order, will report
  "not reachable" for PCP and TURN anycast — which are *deliberately* reachable.

#### 192.0.0.0/29 — IPv4 Service Continuity Prefix

- **Defining RFC:** RFC 7335 (IANA Considerations), generalising the DS-Lite reservation of
  RFC 6333. Allocation date 2011-06.
- **Purpose:** A non-routed IPv4 interface for hosts that need IPv4 addresses for backward
  compatibility inside an IPv6-only network but never emit IPv4 packets "on the wire".
  Originally DS-Lite B4 only (RFC 6333); RFC 7335 widened it to any transition mechanism,
  including 464XLAT.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol False.
- **Status:** Current. Registry text was changed from "DS-Lite [RFC6333]" to "IPv4 Service
  Continuity Prefix [RFC7335]".
- **Misclassification risk:** The /29 covers **192.0.0.0–192.0.0.7 only**. 192.0.0.8,
  192.0.0.9 and 192.0.0.10 are *outside* it, each with its own /32 entry and different
  policy. Off-by-one prefix arithmetic here produces silently wrong answers for three
  distinct protocols. Also note this /29 is Forwardable=True while its parent /24 is
  Forwardable=False — a more-specific that *widens* permissions.

#### 192.0.0.8/32 — IPv4 dummy address

- **Defining RFC:** RFC 7600, Section 6 (IANA Considerations); used per requirement R-22 in
  Section 4.8. Allocation date 2015-03.
- **Purpose:** A placeholder **source** address for ICMPv4 errors synthesised from ICMPv6
  errors inside a 4rd (IPv4 Residual Deployment) domain, so the originating IPv4 host gets
  an error without the provider revealing real infrastructure addresses.
- **Registry:** Source True, Destination **False**, Forwardable False, Globally Reachable
  False, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** It is a legal source and an illegal destination — the
  asymmetry is the whole point. A boolean "is this address usable?" API cannot express it.
  Traffic *from* 192.0.0.8 is expected; traffic *to* it is not.

#### 192.0.0.9/32 — Port Control Protocol Anycast

- **Defining RFC:** RFC 7723 (IANA Considerations), following the anycast-assignment
  procedure of RFC 4085, Section 3.4. Allocation date 2015-10.
- **Purpose:** A well-known anycast destination so a host can reach its nearest PCP server
  without configuration.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** See the joint note under 192.0.0.10/32.

#### 192.0.0.10/32 — Traversal Using Relays around NAT (TURN) Anycast

- **Defining RFC:** RFC 8155 (IANA Considerations). Allocation date 2017-02.
- **Purpose:** Anycast discovery of a TURN server: a client sends an Allocate request to the
  anycast address, the nearest server replies 300 (Try Alternate) with its real unicast
  address in ALTERNATE-SERVER.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Why 192.0.0.9 and 192.0.0.10 are globally reachable inside a block that is not:**
  The parent 192.0.0.0/24 is *unusable* only "by virtue of a more specific reservation"
  (registry footnote [2]) — it is a pool, and its False row is a default, not a ceiling.
  These two addresses are **anycast service addresses**: the discovery model only works if
  a packet addressed to them can be forwarded across administrative boundaries to whichever
  operator is nearest. RFC 7723 makes the design explicit — using an IANA-assigned
  well-known anycast address "enables border gateways to block such outgoing packets", and
  in the default-free zone routers drop them naturally because BGP carries no route. In
  other words, Globally Reachable=True here means *"the protocol requires this address to be
  routable in principle, and containment is a routing/policy decision"*, not *"you will find
  a route to it on the public Internet"*. The same reasoning covers 2001:1::1/128,
  2001:1::2/128 and 2001:1::3/128 on the IPv6 side.
- **Misclassification risk:** A classifier that answers from the /24 will call these
  "unreachable IETF-reserved", so a security tool will treat legitimate PCP/TURN discovery
  traffic as bogon. Conversely, a classifier that reports Globally Reachable=True as
  "public Internet address, geolocatable, attributable to an operator" is also wrong —
  there is no owner and often no route.

#### 192.0.0.170/32 and 192.0.0.171/32 — NAT64/DNS64 Discovery

- **Defining RFC:** RFC 8880 (which formally registers `ipv4only.arpa` as a special-use
  name), building on RFC 7050, Section 2.2. Allocation date 2013-02.
- **Purpose:** Fixed A-record constants returned for `ipv4only.arpa`. A client that sees
  them synthesised into AAAA answers can derive the local NAT64 prefix by inspecting where
  the known constants landed inside the returned IPv6 address.
- **Registry:** all five booleans False except Reserved-by-Protocol **True**.
- **Status:** Current.
- **Misclassification risk:** These are **DNS payload constants, not endpoints**. RFC 8880
  characterises the `ipv4only.arpa` query as "an improvised client-to-middlebox
  communication protocol" and requires DNS64 resolvers to answer locally without querying
  authoritative servers, so the addresses should never be a packet's source or destination.
  A classifier that says "192.0.0.170 — IETF protocol assignment, unreachable" is
  technically right but useless; the useful answer is "this is a NAT64 discovery sentinel,
  its presence in a DNS answer is normal and expected". They are also *outside*
  192.0.0.0/29, so the service-continuity rule does not apply to them.

#### 192.0.2.0/24 (TEST-NET-1), 198.51.100.0/24 (TEST-NET-2), 203.0.113.0/24 (TEST-NET-3) — Documentation

- **Defining RFC:** RFC 5737, Section 1 and Section 3 (operational implications).
  192.0.2.0/24 originates in RFC 1166. Allocation date 2010-01.
- **Purpose:** Addresses for use in documentation and example configurations, guaranteed
  never to be assigned to a real network.
- **Registry:** all five booleans False; Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Source=False and Destination=False means these are *invalid on
  the wire in both directions* — stricter than RFC 1918, which is Source/Destination True.
  A classifier that reports "private, safe to ignore" hides a real signal: seeing TEST-NET
  traffic almost always means someone pasted an example config into production. RFC 5737
  Section 3 tells operators to treat them as non-routable and add them to filters.

#### 192.31.196.0/24 — AS112-v4 (DNAME redirection)

- **Defining RFC:** RFC 7535 (AS112 Redirection Using DNAME), IANA Considerations.
  Allocation date 2014-12.
- **Purpose:** Addresses (specifically 192.31.196.1) for the `blackhole.as112.arpa`
  nameserver, the target of DNAME redirection so that arbitrary zones can be pointed at
  AS112 without reconfiguring AS112 servers.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.

#### 192.175.48.0/24 — Direct Delegation AS112 Service

- **Defining RFC:** RFC 7534 (AS112 Nameserver Operations). Allocation date 1996-01 — the
  oldest allocation date in the IPv4 registry after the 1981/1984/1989 protocol reservations.
- **Purpose:** Anycast prefix for the AS112 nameservers that are *directly delegated* the
  reverse zones for private space: `10.in-addr.arpa`, `16.172.in-addr.arpa` through
  `31.172.in-addr.arpa`, `168.192.in-addr.arpa`, and `254.169.in-addr.arpa`.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **What AS112 is, and why these are globally reachable:** Hosts using RFC 1918 space leak
  reverse-DNS (PTR) queries for names that have no global answer. Left alone, those queries
  land on the root servers. AS112 is, in RFC 7534's words, "a distributed sink for such
  queries in order to reduce the load on the corresponding authoritative servers": volunteer
  operators worldwide announce the same prefixes into BGP from AS 112, and each node answers
  authoritatively (NXDOMAIN-style empty zones) to whoever is nearest. **The prefixes must be
  globally reachable because the entire mechanism is "anyone, anywhere, can announce this
  and absorb the junk"** — that is anycast at Internet scale, deliberately unowned.
- **Misclassification risk (all four AS112 prefixes):** They sit in the *special-purpose*
  registry, so naive logic ("in the special registry ⇒ not public") marks them
  non-reachable, which is exactly backwards: they are among the most globally routed
  addresses in the registry. They are equally not "someone's public address" — no single
  organisation owns them, so WHOIS/geolocation/abuse attribution is meaningless. Note the
  pairing: 192.175.48.0/24 + 2620:4f:8000::/48 are direct-delegation (RFC 7534);
  192.31.196.0/24 + 2001:4:112::/48 are DNAME redirection (RFC 7535). Different RFCs, same
  project.

#### 192.52.193.0/24 — AMT (Automatic Multicast Tunneling)

- **Defining RFC:** RFC 7450, IANA Considerations (anycast prefix); the Relay Discovery
  Address is the prefix with the low-order octet set to 1, i.e. 192.52.193.1.
  Allocation date 2014-12.
- **Purpose:** Anycast discovery of a public AMT relay, which tunnels multicast content over
  unicast UDP to receivers on networks without native multicast.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Same shape as AS112 — RFC 7450 requires public relays to
  advertise a route to the prefix via BGP, so it is genuinely globally routed despite being
  "special-purpose". Do not report it as reserved/bogon.

#### 192.88.99.0/24 — Deprecated (6to4 Relay Anycast)

- **Defining RFC:** originally RFC 3068; deprecated by RFC 7526 (BCP 196), which moves
  RFC 3068 and RFC 6732 to Historic. Allocation date 2001-06, **Termination date 2015-03**.
- **Purpose (historic):** 192.88.99.1 was the anycast address of a 6to4 relay router, so a
  6to4 site could reach "the nearest" relay without configuration.
- **Registry:** the policy columns are **empty** — a terminated entry carries no
  Source/Destination/Forwardable/Globally Reachable/Reserved-by-Protocol values at all.
- **Status:** Deprecated. RFC 7526 says anycast 6to4 "is unsuitable for widespread
  deployment and use in the Internet", and that redelegation of the prefix for any other use
  requires an IETF Standards Action. Note RFC 7526 deprecates *only the anycast prefix*;
  the basic unicast 6to4 mechanism of RFC 3056 and the 2002::/16 prefix are **not**
  deprecated.
- **Misclassification risk:** Any code that models the registry rows as five non-nullable
  booleans will either crash or silently coerce the empty strings to False on this row —
  and False is a *fabricated* answer, not the registry's answer. The honest output is
  "deprecated, no policy values". Second trap: traffic to 192.88.99.1 still appears in the
  wild years after termination, and some networks still announce the /24.

#### 192.88.99.2/32 — 6a44-relay anycast address

- **Defining RFC:** RFC 6751 (Native IPv6 behind IPv4-to-IPv4 NAT CPE — 6a44), Experimental.
  Allocation date 2012-10.
- **Purpose:** Anycast address a 6a44 client sends "bubbles" to in order to reach its 6a44
  relay; 6a44 is an ISP-participating alternative to Teredo.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable
  **False**, Reserved-by-Protocol False.
- **Status:** Current but Experimental. Globally Reachable is False because 6a44 is designed
  to be deployed *within* a participating ISP's network, not across the Internet.
- **Misclassification risk:** This is a **live /32 nested inside a deprecated /24**. A
  classifier that short-circuits on "192.88.99.0/24 is deprecated" gives the wrong answer
  for 192.88.99.2, and one that inherits the deprecated row's empty policy values will
  report no policy for an address that has a full policy row.

#### 198.18.0.0/15 — Benchmarking

- **Defining RFC:** RFC 2544, Section C.2.2.2 (the text there is well known to contain a
  typo, writing "192.18.0.0 through 198.19.255.255"; the registry entry is 198.18.0.0/15).
  Allocation date 1999-03.
- **Purpose:** Address space for the BMWG's device-benchmarking test setups. RFC 2544
  Section C.2.2.2: "This assignment was made to minimize the chance of conflict in case a
  testing device were to be accidentally connected to part of the Internet."
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** A /15, so it spans 198.18.x.x *and* 198.19.x.x — classifiers
  that assume /16 miss half of it. And because 198.18/15 sits in the middle of otherwise
  ordinary 198.x space, "looks routable" heuristics based on the first octet fail here.
  It is not private space: seeing it in production means a test harness escaped.

#### 240.0.0.0/4 — Reserved

- **Defining RFC:** RFC 1112, Section 4 ("Class E", reserved for future addressing modes).
  Allocation date 1989-08.
- **Purpose:** Reserved. Never allocated, and many stacks refuse to configure it.
- **Registry:** all five booleans False, Reserved-by-Protocol **True**.
- **Status:** Current (reserved). There have been repeated IETF proposals to reclassify it
  as usable unicast; none has been adopted. `UNVERIFIED`: status of any current draft.
- **Misclassification risk:** 255.255.255.255/32 is *inside* 240.0.0.0/4 but has different
  values (Destination=True). Match the more-specific. Also, "reserved" ≠ "private" ≠
  "invalid": some operating systems will happily send from 240/4 while others reject it, so
  a classifier should report reserved-by-protocol rather than making a reachability claim.

#### 255.255.255.255/32 — Limited Broadcast

- **Defining RFC:** RFC 919, Section 7 (limited broadcast), with registry values updated by
  RFC 8190. Allocation date 1984-10.
- **Purpose:** The limited broadcast address — delivered to all hosts on the local link, and
  never forwarded by routers.
- **Registry:** Source **False**, Destination **True**, Forwardable False, Globally
  Reachable False, Reserved-by-Protocol **True**. RFC 8190 specifically changed
  Reserved-by-Protocol here from False to True.
- **Status:** Current.
- **Misclassification risk:** The only IPv4 row with Source=False *and* Destination=True.
  Any model that assumes Source ⊇ Destination, or that treats the columns as a single
  ordinal "usability" scale, gets this row wrong. It is also inside 240.0.0.0/4, so it is a
  second longest-prefix-match test.

### IPv6

#### ::/128 — Unspecified Address

- **Defining RFC:** RFC 4291, Section 2.5.2. Allocation date 2006-02.
- **Purpose:** "No address" — used as a source during address autoconfiguration (e.g.
  Duplicate Address Detection).
- **Registry:** Source True, Destination False, Forwardable False, Globally Reachable False,
  Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** The IPv6 twin of 0.0.0.0/32, and legal as a source. RFC 4291
  Section 2.5.2 forbids it as a destination. Reporting "invalid" breaks DAD analysis.

#### ::1/128 — Loopback Address

- **Defining RFC:** RFC 4291, Section 2.5.3. Allocation date 2006-02.
- **Registry:** all five booleans False, Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** IPv6 loopback is a **single address**, not a /8 like IPv4's
  127.0.0.0/8. Code that ports the IPv4 rule by analogy ("::1/64" or similar) is wrong.
  Note also there is no IPv6 equivalent of the RFC 8029/5884 loopback exception footnote.

#### ::ffff:0:0/96 — IPv4-mapped Address

- **Defining RFC:** RFC 4291, Section 2.5.5.2. Allocation date 2006-02.
- **Purpose:** Represents an IPv4 address inside an IPv6 address for use in a dual-stack
  socket API. RFC 4291 Section 2.5.5.2 scopes it to node-internal representation.
- **Registry:** all five booleans False, Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:** The biggest single source of wrong answers in this list.
  `::ffff:10.0.0.1` and `::ffff:8.8.8.8` both match this row and would both be reported
  "not reachable, reserved by protocol" — but the *semantically correct* answer requires
  unwrapping the embedded IPv4 address and classifying that. Security filters that check
  only the IPv6 registry can be bypassed with `::ffff:127.0.0.1`. A good classifier should
  flag the block and offer the IPv4 classification of the embedded address; the registry
  row alone is not the useful answer.

#### 64:ff9b::/96 — IPv4-IPv6 Translation (Well-Known Prefix)

- **Defining RFC:** RFC 6052, Section 2.1 and Section 3.1. Allocation date 2010-10.
- **Purpose:** The Well-Known Prefix for algorithmic NAT64 address translation.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Globally Reachable=True — RFC 6052 notes the WKP "MAY appear
  in inter-domain routing tables" when providers offer translation. But RFC 6052 Section 3.1
  also states: "The Well-Known Prefix MUST NOT be used to represent non-global IPv4
  addresses", and translators "MUST NOT translate packets in which an address is composed of
  the Well-Known Prefix and a non-global IPv4 address; they MUST drop these packets."
  So `64:ff9b::10.0.0.1` is *invalid* even though the /96 is reachable — a per-address rule
  the registry row cannot express. Classifiers should decode the embedded IPv4 and check it.

#### 64:ff9b:1::/48 — IPv4-IPv6 Translation (local use)

- **Defining RFC:** RFC 8215. Allocation date 2017-06.
- **Purpose:** Local-use prefixes for translation, so an operator can run *multiple*
  translation mechanisms without burning global unicast space, and without the WKP's
  restrictions.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable
  **False**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Two adjacent-looking translation prefixes with **opposite**
  global reachability: 64:ff9b::/96 is True, 64:ff9b:1::/48 is False. The difference is
  intra-domain vs inter-domain intent. Prefix-length carelessness (treating anything under
  `64:ff9b::` as one block) collapses the distinction. Note also these two do **not**
  overlap: the /96 is `64:ff9b:0000:...`, the /48 is `64:ff9b:0001::/48`.

#### 100::/64 — Discard-Only Address Block

- **Defining RFC:** RFC 6666. Allocation date 2012-06.
- **Purpose:** A standard next-hop / destination for Remote Triggered Black Hole filtering,
  so operators do not have to repurpose documentation or ULA space as a discard target.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** RFC 6666 warns the prefix "SHOULD NOT be announced to or
  accepted from third-party autonomous systems", because leaking it can drag a DDoS into a
  neighbour's network. Reporting it as merely "private-ish" loses the operational meaning:
  a packet destined here is one the operator has decided to destroy. Treating it as "safe
  internal address" in an SSRF/egress filter is also wrong-headed — it is a sink, not a host.

#### 100:0:0:1::/64 — Dummy IPv6 Prefix

- **Defining RFC:** RFC 9780, Section 1 (purpose) and Section 7.1 (IANA). Allocation date
  **2025-04** — the newest entry in either registry.
- **Purpose:** Destination addresses for IP/UDP encapsulation of management, control and OAM
  packets, replacing the previous non-conformant practice of using IPv4-mapped IPv6
  loopback addresses (which RFC 4291 does not permit on the wire).
- **Registry:** Source True, Destination False, Forwardable False, Globally Reachable False,
  Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Almost no library released before mid-2025 knows this block.
  It is also adjacent to but **distinct from** 100::/64 (discard) — `100::1` is discard
  space, `100:0:0:1::1` is the dummy prefix. Confusing the two is easy from the text form.
  The Destination=False value looks paradoxical for a prefix whose stated job is to be a
  destination; it means these packets are consumed locally, never transited between devices.

#### 2001::/23 — IETF Protocol Assignments

- **Defining RFC:** RFC 2928. Allocation date 2000-09.
- **Purpose:** The IPv6 counterpart of 192.0.0.0/24 — the pool the IETF carves protocol
  prefixes out of.
- **Registry:** all five booleans "False [1]", where footnote [1] reads "Unless allowed by a
  more specific allocation."
- **Status:** Current.
- **Misclassification risk:** Identical to the 192.0.0.0/24 trap, but larger: 2001::/23
  contains Teredo (2001::/32), the three anycast /128s, benchmarking, AMT, AS112-v6,
  ORCHIDv2, and DETs — most of which have permissive values. Answering from the /23 is wrong
  for nearly every address that is actually in use. Also, 2001:db8::/32 is **not** inside
  2001::/23 (the /23 spans 2001:0000:: – 2001:01ff::), a boundary that is easy to get wrong.

#### 2001::/32 — TEREDO

- **Defining RFC:** RFC 4380, with registry values updated by RFC 8190. Allocation date
  2006-01.
- **Purpose:** Prefix for Teredo, IPv6 tunnelling over UDP through IPv4 NATs.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  "N/A [2]"**, Reserved-by-Protocol False. Footnote [2]: "See Section 5 of [RFC4380] for
  details."
- **Status:** Current in the registry; largely abandoned in practice. `UNVERIFIED`: whether
  Teredo has been formally deprecated by any RFC (it has not, as of this registry snapshot).
- **Why N/A:** Reachability of a Teredo address is a property of the *individual address*,
  not the prefix. A Teredo address encodes a server address, flags, and the client's mapped
  IPv4 address and port; whether packets get through depends on the NAT type and on whether
  any relay advertises the prefix. RFC 4380 Section 5.4: "Teredo relays are IPv6 routers
  that advertise reachability of the Teredo service IPv6 prefix ... (A minimal Teredo relay
  may serve just a local host, and would not advertise the prefix beyond this host.)"
  There is no relay obligation to advertise globally, so no single boolean is truthful —
  hence RFC 8190 changed the value from a boolean to N/A.

#### 2001:1::1/128 — Port Control Protocol Anycast

- **Defining RFC:** RFC 7723 (IANA Considerations). Allocation date 2015-10.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable True,
  Reserved-by-Protocol False.
- **Status:** Current. Rationale identical to 192.0.0.9/32 above.

#### 2001:1::2/128 — TURN Anycast

- **Defining RFC:** RFC 8155 (IANA Considerations). Allocation date 2017-02.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable True,
  Reserved-by-Protocol False.
- **Status:** Current. Rationale identical to 192.0.0.10/32 above.

#### 2001:1::3/128 — DNS-SD Service Registration Protocol Anycast

- **Defining RFC:** RFC 9665, Section 10.5. Allocation date **2024-04**.
- **Purpose:** "A fixed anycast address that can be commonly used as a destination for SRP
  Updates when no SRP registrar is explicitly configured" (RFC 9665, Section 10.5).
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable True,
  Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Recent; pre-2024 libraries fall back to the 2001::/23 row and
  report "not usable". Note the three /128s are consecutive but assigned by three unrelated
  RFCs a decade apart — do not model them as one 2001:1::/126.

#### 2001:2::/48 — Benchmarking

- **Defining RFC:** RFC 5180, Section 8, **as corrected by RFC Errata ID 1752**. Allocation
  date 2008-04.
- **Purpose:** IPv6 counterpart of 198.18.0.0/15 for BMWG device benchmarking.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable False,
  Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** The published RFC text says the wrong prefix. RFC 5180
  Section 8 as printed reads "The IANA has allocated 2001:0200::/48 for IPv6 benchmarking";
  Errata 1752 corrects this to "The IANA has assigned 2001:0002::/48". A library built by
  reading RFC 5180 rather than the registry will encode 2001:200::/48 — which is real,
  allocated, globally routed address space belonging to a network in the APNIC region, not
  benchmarking space. This is a case where the RFC is wrong and the registry is right.

#### 2001:3::/32 — AMT

- **Defining RFC:** RFC 7450 (IANA Considerations); discovery address 2001:3::1.
  Allocation date 2014-12.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current. Same rationale as 192.52.193.0/24.

#### 2001:4:112::/48 — AS112-v6 (DNAME redirection)

- **Defining RFC:** RFC 7535. Allocation date 2014-12.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current. See the AS112 discussion under 192.175.48.0/24.

#### 2001:10::/28 — Deprecated (previously ORCHID)

- **Defining RFC:** RFC 4843 (ORCHIDv1, Experimental). Allocation date 2007-03,
  **Termination date 2014-03**.
- **Purpose (historic):** Overlay Routable Cryptographic Hash Identifiers, v1.
- **Registry:** policy columns **empty**, exactly like 192.88.99.0/24.
- **Status:** Deprecated. RFC 7343 states the prefix "was returned to IANA in March 2014"
  because ORCHIDv2's format is not backward compatible with ORCHIDv1 (v1 had no way to
  identify which hash algorithm was used).
- **Misclassification risk:** Same empty-row problem as 192.88.99.0/24. Also easy to confuse
  with the live 2001:20::/28 — one hex digit apart.

#### 2001:20::/28 — ORCHIDv2

- **Defining RFC:** RFC 7343. Allocation date 2014-07.
- **Purpose:** Cryptographic-hash identifiers that look like IPv6 addresses at the socket
  API so unmodified applications can carry them, but that identify endpoints rather than
  locate them (used by HIP and similar overlays).
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Globally Reachable=True is misleading if read as "routable".
  RFC 7343 says ORCHIDs "should not appear in actual IPv6 headers", that "Routers MAY be
  configured not to forward any packets containing an ORCHID as a source or a destination
  address", and — critically — that "Router software MUST NOT include any special handling
  code for ORCHIDs". The True value exists precisely *because* IP itself must not treat them
  specially; containment is configuration, not protocol. These are identifiers, not
  destinations, and no amount of routing will reach one.

#### 2001:30::/28 — Drone Remote ID Protocol Entity Tags (DETs)

- **Defining RFC:** RFC 9374. Allocation date 2022-12.
- **Purpose:** Hierarchical Host Identity Tags used as self-asserting, cryptographically
  verifiable identifiers for unmanned aircraft in Remote ID systems. The prefix encodes a
  Registered Assigning Authority and an HHIT Domain Authority so a DET can be resolved to a
  registry via DNS.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Like ORCHIDv2 (from which it derives), these are
  **identifiers, not addresses**. "Globally reachable" here means "globally unique and
  resolvable", not "you can send a packet to a drone at this address". A classifier that
  answers "public IPv6 address" for a DET is technically consistent with the registry and
  substantively wrong. Post-2022; older libraries miss it entirely.

#### 2001:db8::/32 — Documentation

- **Defining RFC:** RFC 3849. Allocation date 2004-07.
- **Purpose:** Address space for documentation and examples.
- **Registry:** all five booleans False, Reserved-by-Protocol False.
- **Status:** Current, and now supplemented (not replaced) by 3fff::/20.
- **Misclassification risk:** Not inside 2001::/23 (see above). Source=False and
  Destination=False makes it stricter than ULA; seeing it on the wire is a configuration
  bug, not "private traffic".

#### 2002::/16 — 6to4

- **Defining RFC:** RFC 3056. Allocation date 2001-02.
- **Purpose:** Automatic tunnelling of IPv6 over IPv4: an address of the form
  `2002:V4ADDR::/48` derives its /48 from a globally unique IPv4 address, and packets are
  encapsulated to that embedded IPv4 destination.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  "N/A [3]"**, Reserved-by-Protocol False. Footnote [3]: "See [RFC3056] for details."
- **Status:** The prefix and the unicast mechanism are **not** deprecated (RFC 7526 states
  "the basic unicast 6to4 mechanism defined in RFC 3056 ... [is] not deprecated"); only the
  192.88.99.0/24 anycast relay prefix is. RFC 3056 remains Proposed Standard. In practice
  6to4 is effectively dead.
- **Why N/A:** Reachability is a property of the *embedded* IPv4 address, so it varies
  address-by-address within the /16 and cannot be a prefix-level boolean. RFC 3056 further
  requires that "any 6to4 traffic whose source or destination address embeds a V4ADDR which
  is not in the format of a global unicast address MUST be silently discarded" — so
  `2002:0a00:0001::` (embedding 10.0.0.1) is invalid while `2002:0808:0808::` (embedding
  8.8.8.8) may well be reachable.
- **Misclassification risk:** Coercing N/A to False labels a large, historically routed
  chunk of IPv6 as unreachable; coercing it to True claims reachability that depends on
  someone running a relay. The correct behaviour is to preserve N/A and, if you want a real
  answer, decode the embedded IPv4 and classify *that*.

#### 2620:4f:8000::/48 — Direct Delegation AS112 Service

- **Defining RFC:** RFC 7534. Allocation date 2011-05.
- **Registry:** Source True, Destination True, Forwardable True, **Globally Reachable
  True**, Reserved-by-Protocol False.
- **Status:** Current. See AS112 under 192.175.48.0/24.
- **Misclassification risk:** Extra trap: this prefix is drawn from ordinary 2620::/23
  global unicast space, so it looks like an ordinary allocation *and* is one of the very few
  special-purpose IPv6 entries outside 2001::/16, 64:ff9b::, fc00::/7 and fe80::/10.
  Range-based shortcuts that only inspect those regions will never see it.

#### 3fff::/20 — Documentation

- **Defining RFC:** RFC 9637; block registered in Section 6, rationale in Sections 1 and 3,
  guidance in Sections 4 and 5. Allocation date **2024-07**.
- **Purpose:** A second, much larger documentation prefix. RFC 9637 Section 1 explains that
  2001:db8::/32 is "inadequate to describe many realistic, current deployment scenarios";
  Section 3 notes allocations larger than a /32 are now 25.9% of IPv6 unicast assignments,
  so examples involving a large ISP could not be written using a single /32.
- **Registry:** all five booleans False, Reserved-by-Protocol False — identical to
  2001:db8::/32.
- **Status:** Current.
- **Misclassification risk:** The most consequential recent addition. Any library whose
  block table predates mid-2024 will classify 3fff::/20 as **ordinary global unicast**,
  because 3fff:: falls inside 2000::/3. That is a security-relevant false negative: RFC 9637
  Section 4 says documentation prefixes "MUST NOT be used for actual traffic, MUST NOT be
  globally advertised", and Section 5 says packets with these addresses "should be dropped
  and disallowed over the public Internet". Note also the unusual /20 boundary —
  3fff:: through 3fff:0fff:ffff... i.e. 3fff:0000::/20 covers 3fff:0000:: – 3fff:0fff::,
  so 3fff:1000:: is *not* documentation space.

#### 5f00::/16 — Segment Routing (SRv6) SIDs

- **Defining RFC:** RFC 9602; registered in Section 6, rationale in Section 5, leak warning
  in Section 7. Allocation date **2024-04**.
- **Purpose:** A dedicated block for SRv6 Segment Identifiers. RFC 9602 notes SRv6 SIDs
  "look and act like other mechanisms that use IPv6 addresses with different formats" but
  are "not intended for assignment onto interfaces on end hosts" — they are instructions
  encoded as addresses, processed as routing prefixes by transit nodes.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable
  **False**, Reserved-by-Protocol False.
- **Status:** Current.
- **Misclassification risk:** Like 3fff::/20, invisible to older libraries — and 5f00:: sits
  inside 2000::/3, so it is classified as global unicast by anything that predates 2024-04.
  RFC 9602 Section 5 explains the block exists so operators can filter SRv6 at SR-domain
  edges; Section 7 warns that where the block is *not* used, extra care is needed "so that
  SRv6 packets do not leak out of SR Domains". Semantically these are neither hosts nor
  networks: a 5f00::/16 address in a packet capture is a routing instruction, and reporting
  it as "a host that isn't publicly reachable" misses the point.

#### fc00::/7 — Unique-Local (ULA)

- **Defining RFC:** RFC 4193, with registry values updated by RFC 8190. Allocation date
  2005-10.
- **Purpose:** Locally assigned globally unique-ish addresses for site-internal use, with a
  40-bit pseudo-random Global ID to make collisions between merging sites improbable.
- **Registry:** Source True, Destination True, Forwardable True, Globally Reachable
  **"False [4]"**, Reserved-by-Protocol False. Footnote [4]: "See [RFC4193] for more details
  on the routability of Unique-Local addresses. The Unique-Local prefix is drawn from the
  IPv6 Global Unicast Address range, but is specified as not globally routed."
- **Status:** Current.
- **Misclassification risk:**
  - fc00::/7 is registered as a whole, but RFC 4193 Section 3.1 only defines the L=1 half,
    **fd00::/8** (locally assigned). **fc00::/8** (L=0, centrally assigned) has never been
    defined by any RFC. A classifier reporting `fc00::1` as "valid ULA" is over-generous;
    the honest answer is "in the registered ULA block, but its half is undefined".
    `UNVERIFIED`: any draft reviving fc00::/8.
  - ULA is *not* the IPv6 equivalent of RFC 1918 in every respect — RFC 4193 requires the
    Global ID be pseudo-randomly generated, and ULAs are globally unique by construction,
    which RFC 1918 addresses are not. Deduplication and merger logic that assumes "private
    ⇒ ambiguous" is wrong for ULA.
  - Footnote [4] exists to head off the observation that fc00::/7 is carved out of global
    unicast space; a classifier that decides reachability from the 2000::/3 rule alone will
    get it backwards.

#### fe80::/10 — Link-Local Unicast

- **Defining RFC:** RFC 4291, Section 2.5.6. Allocation date 2006-02.
- **Purpose:** Automatically configured addresses valid on a single link; mandatory on every
  IPv6 interface, and the basis of Neighbor Discovery and of IPv6 next-hop addressing.
- **Registry:** Source True, Destination True, **Forwardable False**, Globally Reachable
  False, Reserved-by-Protocol True.
- **Status:** Current.
- **Misclassification risk:**
  - Registered as **/10** but RFC 4291 Section 2.5.6 defines the format with 54 zero bits
    after `1111111010`, i.e. addresses are effectively fe80::/64. Everything from fe80:: to
    febf:ffff... matches the registry row, but only fe80::/64 is a well-formed link-local
    address.
  - Link-local addresses are **not unique across links**: `fe80::1` on eth0 and `fe80::1`
    on eth1 are different endpoints. Any classifier that returns a verdict for a
    link-local address without acknowledging the zone/scope ID (`fe80::1%eth0`) is producing
    an answer that cannot be acted on.
  - Unlike ULA, this is Forwardable=False and Reserved-by-Protocol=True: it is a protocol
    rule, not a policy preference.

---

## Recently assigned blocks

Blocks added or materially changed in roughly the last five years. Any library whose table
was frozen before these dates will silently misclassify them — and, for the three inside
2000::/3, misclassify them as *ordinary global unicast*, which is the dangerous direction.

| Block | Name | RFC | Allocation date | What older libraries say instead |
|---|---|---|---|---|
| 100:0:0:1::/64 | Dummy IPv6 Prefix | RFC 9780 | **2025-04** | falls through to no match / "global unicast" |
| 3fff::/20 | Documentation | RFC 9637 | **2024-07** | global unicast (inside 2000::/3) |
| 5f00::/16 | Segment Routing (SRv6) SIDs | RFC 9602 | **2024-04** | global unicast (inside 2000::/3) |
| 2001:1::3/128 | DNS-SD SRP Anycast | RFC 9665 | **2024-04** | inherits 2001::/23 "False [1]" |
| 2001:30::/28 | DRIP Entity Tags (DETs) | RFC 9374 | **2022-12** | inherits 2001::/23 "False [1]" |

Slightly older but still commonly missing:

| Block | Name | RFC | Allocation date |
|---|---|---|---|
| 192.0.0.10/32 | TURN Anycast | RFC 8155 | 2017-02 |
| 2001:1::2/128 | TURN Anycast | RFC 8155 | 2017-02 |
| 64:ff9b:1::/48 | IPv4-IPv6 Translat. (local use) | RFC 8215 | 2017-06 |
| 192.0.0.9/32 | PCP Anycast | RFC 7723 | 2015-10 |
| 2001:1::1/128 | PCP Anycast | RFC 7723 | 2015-10 |
| 192.0.0.8/32 | IPv4 dummy address | RFC 7600 | 2015-03 |

Also note RFC 8190 (2017) is a *values* change, not a new block: it renamed "Global" to
"Globally Reachable", flipped 255.255.255.255/32's Reserved-by-Protocol from False to True,
and introduced the non-boolean N/A value used by Teredo.

## Deprecated blocks still in the wild

| Block | Name | Deprecating RFC | Termination date | Notes |
|---|---|---|---|---|
| 192.88.99.0/24 | 6to4 Relay Anycast | RFC 7526 (BCP 196), which moves RFC 3068 and RFC 6732 to Historic | **2015-03** | Policy columns are empty in the registry. Redelegation requires IETF Standards Action. 192.88.99.2/32 (RFC 6751) is still live *inside* it. Traffic to 192.88.99.1 still appears years later. |
| 2001:10::/28 | previously ORCHID (ORCHIDv1) | RFC 7343 (prefix "returned to IANA in March 2014"); original RFC 4843 | **2014-03** | Policy columns empty. Superseded by 2001:20::/28 (ORCHIDv2), one hex digit away. |

These are the **only two rows in either registry with a termination date**, and the only two
with empty policy columns. Related deprecations that are *not* registry rows:

- **IPv4-compatible IPv6 addresses** (`::a.b.c.d`, i.e. ::/96) were deprecated by RFC 4291,
  Section 2.5.5.1. There is no ::/96 row in the registry, so a classifier driven purely by
  the registry will not flag them, yet they still appear in old code and old captures.
- **6to4 anycast** is deprecated, but **6to4 itself is not** — RFC 7526 explicitly leaves
  RFC 3056 and 2002::/16 undeprecated. Do not mark 2002::/16 deprecated.
- **Teredo (2001::/32)** is widely described as obsolete but has *not* been formally
  deprecated by an RFC; it is a current registry entry with Globally Reachable = N/A.

## Gotchas

1. **Longest-prefix-match is mandatory, and more-specifics can be *more* permissive.**
   192.0.0.0/24 is all-False, yet 192.0.0.9/32 and 192.0.0.10/32 inside it are Globally
   Reachable=True. 2001::/23 is "False [1]", yet it contains AMT, AS112-v6, ORCHIDv2, DETs
   and three anycast /128s that are Globally Reachable=True. First-match-in-file-order or
   shortest-match lookups produce confidently wrong answers (RFC 6890, Section 2.1; registry
   footnotes IPv4 [2] and IPv6 [1]).

2. **Two rows have `N/A` for Globally Reachable, not True/False: 2001::/32 (Teredo) and
   2002::/16 (6to4).** In both cases reachability is a property of the individual address —
   Teredo because relay advertisement is voluntary and per-deployment (RFC 4380,
   Section 5.4), 6to4 because reachability follows the embedded IPv4 address (RFC 3056).
   RFC 8190 introduced N/A precisely so implementers would stop pretending a boolean exists.
   Coercing N/A to False (common) mislabels large historically routed ranges; coercing to
   True over-promises. Store it as a third state.

3. **Two rows have a termination date and *no policy values at all*: 192.88.99.0/24
   (2015-03) and 2001:10::/28 (2014-03).** The CSV cells are empty strings, not "False".
   Parsers that type these columns as non-nullable logical will coerce empty to NA or to
   FALSE; only NA is honest. Report "deprecated" rather than a fabricated policy.

4. **A live block can be nested inside a deprecated one.** 192.88.99.2/32 (6a44,
   RFC 6751, allocated 2012-10) sits inside the deprecated 192.88.99.0/24. Short-circuiting
   on the parent's deprecation is wrong.

5. **"Globally Reachable = False" is not a synonym for "private".** RFC 1918, CGN space,
   documentation, benchmarking, discard, SRv6 SIDs, ULA, link-local and translation prefixes
   are all False for different reasons and demand different responses. Only RFC 1918
   (and arguably fc00::/7) means "someone's internal network".

6. **"Globally Reachable = True" inside the special registry does not mean "a normal public
   address".** AS112, AMT, PCP/TURN/SRP anycast, ORCHIDv2 and DETs are all True. None is
   owned by a single organisation; several (ORCHIDv2, DETs) are identifiers that are never
   valid packet destinations at all despite the True value (RFC 7343: ORCHIDs "should not
   appear in actual IPv6 headers"). True means "the policy permits crossing administrative
   boundaries", not "geolocatable host".

7. **100.64.0.0/10 is neither private nor public.** RFC 6598 Section 4 forbids forwarding it
   across Service Provider boundaries, so it is not public; Section 3 explains it exists
   *because* it must not collide with the subscriber's own RFC 1918 space, so it is not
   RFC 1918 either. Treat it as public and you route unroutable traffic; treat it as private
   and you assume one address = one subscriber, which is false behind a CGN, breaking abuse
   attribution, rate-limiting, allowlisting and geolocation.

8. **The AS112 prefixes are the inverse trap.** 192.31.196.0/24, 192.175.48.0/24,
   2001:4:112::/48 and 2620:4f:8000::/48 are in the special registry *and* are globally
   routed anycast operated by volunteers (RFC 7534, RFC 7535). "In the special registry ⇒
   bogon" is exactly backwards for these four.

9. **192.0.0.0/29 is `.0`–`.7` only.** 192.0.0.8, .9, .10, .170 and .171 are all *outside*
   it and each has its own row with different values. Off-by-one prefix maths here silently
   swaps five protocols' semantics.

10. **Source and Destination are independent.** 255.255.255.255/32 is Source=False /
    Destination=True. 0.0.0.0/8, 0.0.0.0/32, ::/128, 192.0.0.8/32 and 100:0:0:1::/64 are
    Source=True / Destination=False. There is exactly one implication rule — Destination
    False ⇒ Forwardable and Globally Reachable False (RFC 6890, Section 2.2.1) — and no
    others. Any single "is this address valid?" boolean is lossy.

11. **127.0.0.0/8's four False values carry an exception footnote.** IPv4 footnote [1]:
    MPLS LSP ping (RFC 8029) and BFD for MPLS LSPs (RFC 5884) legitimately put 127/8
    addresses on the wire. Flagging all 127/8 sightings as spoofing generates false
    positives on MPLS networks. Also, it is the whole /8 — 127.1.2.3 is loopback — while
    IPv6's ::1/128 is a *single* address.

12. **::ffff:0:0/96 must be unwrapped.** The registry row for IPv4-mapped addresses says
    "not usable", but the useful classification is that of the embedded IPv4 address. A
    filter that checks the IPv6 registry only is bypassable with `::ffff:127.0.0.1` or
    `::ffff:169.254.169.254`.

13. **64:ff9b::/96 (Globally Reachable True) and 64:ff9b:1::/48 (False) are different
    blocks with opposite semantics**, and the WKP additionally forbids embedding non-global
    IPv4 addresses — "translators MUST NOT translate packets in which an address is composed
    of the Well-Known Prefix and a non-global IPv4 address; they MUST drop these packets"
    (RFC 6052, Section 3.1). A per-address rule the row cannot express.

14. **3fff::/20 (RFC 9637, 2024-07) and 5f00::/16 (RFC 9602, 2024-04) both sit inside
    2000::/3.** Libraries with pre-2024 tables report them as ordinary global unicast — a
    false negative for documentation space that "MUST NOT be globally advertised"
    (RFC 9637, Section 4) and for SRv6 SIDs that must be filtered at SR-domain edges
    (RFC 9602, Section 5).

15. **RFC 5180's printed prefix is wrong.** Section 8 says 2001:0200::/48; Errata ID 1752
    corrects it to 2001:0002::/48, which is what IANA registered. Encoding 2001:200::/48 as
    benchmarking space mislabels real, allocated, globally routed address space. Trust the
    registry over the RFC text here.

16. **fc00::/7 is registered, but only fd00::/8 is defined.** RFC 4193 Section 3.1 defines
    the L=1 (locally assigned) half; fc00::/8 has no defining specification. Reporting
    `fc00::1` as a valid ULA overstates the case.

17. **fe80::/10 is registered but fe80::/64 is the real format** (RFC 4291, Section 2.5.6,
    which mandates 54 zero bits). And link-local addresses are not unique across links, so
    any verdict about one is incomplete without a zone/scope identifier.

18. **240.0.0.0/4 contains 255.255.255.255/32 with different values**, and 0.0.0.0/8
    contains 0.0.0.0/32. Both are cheap regression tests that a lookup is really doing
    longest-prefix-match rather than returning the first containing block.

19. **192.0.0.170/32 and 192.0.0.171/32 are DNS payload constants, not endpoints.** They are
    correct-and-expected inside an `ipv4only.arpa` answer (RFC 8880; RFC 7050, Section 2.2)
    and anomalous anywhere else. Reporting only "IETF protocol assignment, unreachable"
    loses the actionable meaning.

20. **Documentation prefixes are stricter than private space.** 192.0.2.0/24,
    198.51.100.0/24, 203.0.113.0/24, 2001:db8::/32 and 3fff::/20 are all Source=False *and*
    Destination=False — invalid in both directions (RFC 5737, Section 3; RFC 3849;
    RFC 9637, Sections 4 and 5). RFC 1918 space is Source=True/Destination=True. Bucketing
    documentation space as "private, ignore" suppresses a strong signal that an example
    config reached production.

21. **Identifier blocks are not address blocks.** ORCHIDv2 (2001:20::/28, RFC 7343), DETs
    (2001:30::/28, RFC 9374) and SRv6 SIDs (5f00::/16, RFC 9602) all use IPv6 syntax for
    things that are not host addresses. RFC 7343 is explicit that "Router software MUST NOT
    include any special handling code for ORCHIDs" — which is *why* the registry marks them
    forwardable. Reachability language is category-inappropriate for these three.

22. **Some special-purpose IPv6 blocks live outside the "usual" regions.**
    2620:4f:8000::/48 (AS112) comes from ordinary 2620::/23 global unicast space. Any
    shortcut that only inspects 2000::/3-with-known-exceptions, fc00::/7, fe80::/10 and
    2001::/16 will miss it — and it is globally routed.

23. **Registry allocation dates are not creation dates.** 0.0.0.0/8 is dated 1981-09 from
    RFC 791, 192.175.48.0/24 is dated 1996-01, and 192.88.99.0/24 is dated 2001-06 with a
    2015-03 termination. Do not use the allocation date to infer how modern a block is or
    how recently the row's *values* changed — RFC 8190 changed several rows' values in 2017
    without touching their allocation dates.
