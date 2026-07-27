# 04 — IPv4/IPv6 transition and translation: exact bit geometry of embedded IPv4 addresses

Scope: every standardised form in which a 32-bit IPv4 address is carried inside a 128-bit
IPv6 address. All bit offsets are **integers counted from the most significant bit of the
128-bit address**, where the MSB is **bit 0** and the LSB is **bit 127**. A segment
described as "offset 96, length 32" therefore occupies bits 96..127 inclusive.

Byte/group cross-reference used throughout: bit 0 starts group 1 (`x::`), bit 16 group 2,
bit 32 group 3, bit 48 group 4, bit 64 group 5, bit 80 group 6, bit 96 group 7, bit 112
group 8. Bits 64..71 are the high-order octet of group 5.

Primary sources fetched from `www.rfc-editor.org` (canonical `.txt`) plus the IANA IPv6
Special-Purpose Address Registry.

---

## Forms

| form | outer prefix (or 'none') | RFC + section | status | what is embedded |
|---|---|---|---|---|
| IPv4-Compatible IPv6 address | `::/96` (80 zero bits + 16 zero bits) | RFC 4291 §2.5.5.1 | **Deprecated.** RFC 4291 §2.5.5.1: "The 'IPv4-Compatible IPv6 address' is now deprecated because the current IPv6 transition mechanisms no longer use these addresses. New or updated implementations are not required to support this address type." | a 32-bit IPv4 address, verbatim |
| IPv4-Mapped IPv6 address | `::ffff:0:0/96` | RFC 4291 §2.5.5.2; IANA IPv6 Special-Purpose Registry entry `::ffff:0:0/96` "IPv4-mapped Address" (ref. RFC 4291) | Current. Used to represent an IPv4 node's address as an IPv6 address (chiefly in socket APIs). | a 32-bit IPv4 address, verbatim |
| IPv4-Translated IPv6 address | `0::ffff:0:0:0/96` (i.e. `ffff` at bits 64..79, zeros at 80..95) | RFC 2765 §2.1 (glossary): "IPv4-translated: An address of the form 0::ffff:0:a.b.c.d which refers to an IPv6-enabled node… 0::ffff:0:0:0/96 is chosen to checksum to zero" | **Historic / not currently assigned.** RFC 2765 was obsoleted by RFC 6145, which was obsoleted by RFC 7915. Grep of the full texts of RFC 6145 and RFC 7915 finds **no** occurrence of "IPv4-translated" or `ffff:0:` — the form was dropped. It is **absent from the IANA IPv6 Special-Purpose Address Registry**. **No current RFC assigns `::ffff:0:0:0/96`.** Treat it as a legacy literal only. | a 32-bit IPv4 address, verbatim |
| 6to4 | `2002::/16` | RFC 3056 §2 | Current (unicast 6to4 is *not* deprecated — RFC 7526: "The basic unicast 6to4 mechanism defined in [RFC3056] and the associated 6to4 IPv6 prefix 2002::/16 are not deprecated."). Widely considered legacy in practice. IANA registry: `2002::/16` "6to4" (ref. RFC 3056). | the site's 32-bit IPv4 address (`V4ADDR`) |
| 6to4 relay anycast | not an IPv6 form — IPv4 prefix `192.88.99.0/24`, anycast host `192.88.99.1` | RFC 3068 §2.3; deprecated by RFC 7526 §4 | **Deprecated.** RFC 7526 §4: "This document formally deprecates the anycast 6to4 transition mechanism defined in [RFC3068] and the associated anycast IPv4 address 192.88.99.1." RFC 3068 and RFC 6732 moved to **Historic**. IANA has marked `192.88.99.0/24` "Deprecated (6to4 Relay Anycast)". "The prefix 192.88.99.0/24 MUST NOT be reassigned for other use except by a future IETF Standards Action." | nothing is embedded *in* IPv6; but the corresponding 6to4 address `2002:c058:6301::/48` embeds `192.88.99.1` under ordinary 6to4 geometry |
| Teredo | `2001::/32` (`2001:0000::/32`) | RFC 4380 §4; flags field updated by RFC 5991 §3.1 | Current-but-sunsetting. IANA registry: `2001::/32` "TEREDO" (refs. RFC 4380, RFC 8190). | **two** IPv4 addresses: the Teredo **server** IPv4 (plaintext) and the Teredo **client**'s mapped IPv4 (**bitwise complemented**), plus a 16-bit mapped UDP port (**bitwise complemented**) |
| RFC 6052 IPv4-embedded IPv6 (NAT64 / SIIT / stateless translation) | Well-Known Prefix `64:ff9b::/96`, or a Network-Specific Prefix of length 32/40/48/56/64/96 | RFC 6052 §2.1, §2.2, §2.3 | Current, Standards Track. IANA registry: `64:ff9b::/96` "IPv4-IPv6 Translat." (ref. RFC 6052). | a 32-bit IPv4 address, **possibly split into two segments** by the reserved u-octet |
| NAT64 / DNS64 | any `Pref64::/n` per RFC 6052 (`n` ∈ {32,40,48,56,64,96}) | RFC 6146 §3.3, §1 ("in [RFC6052] and an IPv6 prefix assigned to the stateful NAT64"); RFC 6147 | Current | identical to RFC 6052 — NAT64 defines no new geometry. RFC 6146: "Pref64::/n as well as the address format are defined in [RFC6052]." |
| 464XLAT | PLAT-side prefix per RFC 6052; CLAT-side a separate prefix | RFC 6877 §2, §6.3 | Current | identical to RFC 6052. Note RFC 6877 §2: "The CLAT uses different IPv6 prefixes for CLAT-side and PLAT-side IPv4 addresses and therefore does not comply" with the RFC 6052 §3.3 same-prefix recommendation. |
| Pref64 discovery addresses | `Pref64::/n` + `192.0.0.170` or `192.0.0.171` | RFC 7050 §2 (definitions), §3, §8 (IANA); RFC 7051 (problem statement / analysis) | Current | one of the two Well-Known IPv4 Addresses, embedded "at any of the locations allowed by RFC 6052" (RFC 7050 §2, definition of `Pref64::WKA`) |
| Local-use translation prefix | `64:ff9b:1::/48` | RFC 8215 §4, §5 | Current. IANA registry: `64:ff9b:1::/48` "IPv4-IPv6 Translat." (ref. RFC 8215). | **Undefined by the RFC.** RFC 8215 §5: nodes "must not make any assumptions regarding the syntax or properties of those addresses (e.g., the existence and location of embedded IPv4 addresses)". |
| ISATAP | **none** — any /64 unicast or link-local prefix | RFC 5214 §6.1 | Current (Informational). | a 32-bit IPv4 address in the low 32 bits of the interface identifier; may be **private** ("ISATAP enables automatic tunneling whether global or private IPv4 addresses are used") |
| 6over4 | **none** — any /64 prefix; canonically `fe80::/64` for link-local | RFC 2529 §4 | Historic in practice; the RFC is Standards Track but the mechanism is unused. `UNVERIFIED` whether an IETF action formally reclassified RFC 2529. | the 32-bit IPv4 address as the whole interface identifier, "padded at the left with zeros to a total of 64 bits" |

---

## Bit geometry

### Master table

`offset` = bits from the MSB of the 128-bit address (MSB = bit 0).

| form | prefix length | segment offset (bits from MSB) | segment length (bits) | complemented? | notes |
|---|---|---|---|---|---|
| IPv4-Compatible (RFC 4291 §2.5.5.1) | 96 | 96 | 32 | no | Layout is `80 bits zero \| 16 bits zero \| 32-bit IPv4`. Single segment. Deprecated form. |
| IPv4-Mapped (RFC 4291 §2.5.5.2) | 96 | 96 | 32 | no | Layout is `80 bits zero \| 16 bits 0xFFFF \| 32-bit IPv4`. The `ffff` occupies bits **80..95**. Single segment. |
| IPv4-Translated (RFC 2765 §2.1) | 96 | 96 | 32 | no | Layout is `64 bits zero \| 16 bits 0xFFFF (bits 64..79) \| 16 bits zero (bits 80..95) \| 32-bit IPv4`. The `ffff` sits **one 16-bit group earlier** than in IPv4-mapped. Not currently assigned — see Forms table. |
| 6to4 (RFC 3056 §2) | 16 | 16 | 32 | no | RFC 3056 §2 diagram: `\| 3 \| 13 \| 32 \| 16 \| 64 bits \|` = `FP(001) \| TLA 0x0002 \| V4ADDR \| SLA ID \| Interface ID`. `V4ADDR` therefore occupies bits **16..47**; `SLA ID` bits 48..63; interface ID bits 64..127. The site prefix is `2002:V4ADDR::/48`. |
| 6to4 relay anycast (RFC 3068 §2.3) | n/a | n/a | n/a | n/a | `192.88.99.0/24` is an **IPv4** anycast prefix; there is no IPv6-side embedding of its own. Its 6to4 image is `2002:c058:6301::` (0xc0=192, 0x58=88, 0x63=99, 0x01=1) under ordinary 6to4 geometry. |
| Teredo — **server** IPv4 (RFC 4380 §4) | 32 | 32 | 32 | **no** | Plaintext. Follows the 32-bit `2001:0000::/32` prefix. |
| Teredo — **client** IPv4 (RFC 4380 §4) | 32 | 96 | 32 | **YES** — bitwise complement | RFC 4380 §4: "both the 'mapped UDP port' and 'mapped IPv4 address' of the client are obfuscated. Each bit in the address and port number is reversed; this can be done by an exclusive OR of the 16-bit port number with the hexadecimal value 0xFFFF, and an exclusive OR of the 32-bit address with the hexadecimal value 0xFFFFFFFF." Recover with `addr XOR 0xFFFFFFFF`. |
| Teredo — flags (RFC 4380 §4, RFC 5991 §3.1) | 32 | 64 | 16 | no | Not an IPv4 address. Occupies bits **64..79**. |
| Teredo — obfuscated UDP port (RFC 4380 §4) | 32 | 80 | 16 | **YES** — bitwise complement | Not an IPv4 address. Occupies bits **80..95**. Recover with `port XOR 0xFFFF`. |
| RFC 6052 §2.2 — prefix /32 | 32 | 32 | 32 | no | **Single segment.** RFC 6052 §2.2: "When the prefix is 32 bits long, the IPv4 address is encoded in positions 32 to 63." u-octet at bits **64..71**, *after* the whole embedded address. |
| RFC 6052 §2.2 — prefix /40 (segment 1) | 40 | 40 | 24 | no | **Split.** "When the prefix is 40 bits long, 24 bits of the IPv4 address are encoded in positions 40 to 63, with the remaining 8 bits in position 72 to 79." u-octet at bits **64..71**, *between* the two segments. |
| RFC 6052 §2.2 — prefix /40 (segment 2) | 40 | 72 | 8 | no | see above |
| RFC 6052 §2.2 — prefix /48 (segment 1) | 48 | 48 | 16 | no | **Split.** "…16 bits of the IPv4 address are encoded in positions 48 to 63, with the remaining 16 bits in position 72 to 87." u-octet at bits **64..71**, between the segments. |
| RFC 6052 §2.2 — prefix /48 (segment 2) | 48 | 72 | 16 | no | see above |
| RFC 6052 §2.2 — prefix /56 (segment 1) | 56 | 56 | 8 | no | **Split.** "…8 bits of the IPv4 address are encoded in positions 56 to 63, with the remaining 24 bits in position 72 to 95." u-octet at bits **64..71**, between the segments. |
| RFC 6052 §2.2 — prefix /56 (segment 2) | 56 | 72 | 24 | no | see above |
| RFC 6052 §2.2 — prefix /64 | 64 | **72** | 32 | no | **Single segment, but displaced.** "When the prefix is 64 bits long, the IPv4 address is encoded in positions 72 to 103." u-octet at bits **64..71**, *before* the embedded address. This is the only length where the embedded address does not start at the prefix boundary. |
| RFC 6052 §2.2 — prefix /96 | 96 | 96 | 32 | no | **Single segment.** "When the prefix is 96 bits long, the IPv4 address is encoded in positions 96 to 127." **No u-octet is inserted**; bits 64..71 are part of the prefix and MUST be zero by administrative construction. No suffix. |
| Well-Known Prefix `64:ff9b::/96` (RFC 6052 §2.1) | 96 | 96 | 32 | no | The WKP is 96 bits long "and can only be used in the last form of the table" (RFC 6052 §2.2). |
| `64:ff9b:1::/48` (RFC 8215) | 48 (prefix only) | **undefined** | undefined | n/a | RFC 8215 §5 forbids assuming "the existence and location of embedded IPv4 addresses". Geometry is whatever the deployed mechanism uses; it may be RFC 6052 /48, or something else entirely. Do **not** extract by default. |
| ISATAP (RFC 5214 §6.1) | none (any /64) | 96 | 32 | no | Interface identifier occupies bits 64..127. Within it: bits **64..79** = `0x0000` (u=0) or `0x0200` (u=1); bits **80..95** = `0x5EFE`; bits **96..127** = the IPv4 address. |
| 6over4 (RFC 2529 §4) | none (any /64; canonically `fe80::/64`) | 96 | 32 | no | RFC 2529 §4: the IID is "the 32-bit IPv4 address of that interface… padded at the left with zeros to a total of 64 bits." So bits **64..95 are zero** and bits **96..127** carry the IPv4 address. |

### RFC 6052 §2.2 — all six prefix lengths, laid out explicitly

Verbatim Figure 1 (RFC 6052 §2.2). The header row is a bit ruler; `u` is the reserved octet
at bits 64..71.

```
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |PL| 0-------------32--40--48--56--64--72--80--88--96--104---------|
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |32|     prefix    |v4(32)         | u | suffix                    |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |40|     prefix        |v4(24)     | u |(8)| suffix                |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |48|     prefix            |v4(16) | u | (16)  | suffix            |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |56|     prefix                |(8)| u |  v4(24)   | suffix        |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |64|     prefix                    | u |   v4(32)      | suffix    |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 |96|     prefix                                    |    v4(32)     |
 +--+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
```

Per-length breakdown, with the u-octet position called out:

| PL | u-octet bits | embedded IPv4 segments | split? | where the u-octet falls relative to the IPv4 address |
|---|---|---|---|---|
| /32 | 64..71 | `[32..63]` (32 bits) | **no** | entirely **after** the address |
| /40 | 64..71 | `[40..63]` (24) + `[72..79]` (8) | **YES** | **inside**, after IPv4 octets 1–3 |
| /48 | 64..71 | `[48..63]` (16) + `[72..87]` (16) | **YES** | **inside**, after IPv4 octets 1–2 |
| /56 | 64..71 | `[56..63]` (8) + `[72..95]` (24) | **YES** | **inside**, after IPv4 octet 1 |
| /64 | 64..71 | `[72..103]` (32) | **no** | entirely **before** the address |
| /96 | n/a (bits 64..71 lie inside the prefix; no octet is inserted) | `[96..127]` (32) | **no** | not inserted at all |

**Which lengths split the address:** /40, /48, /56 split it into exactly two segments.
**Which do not:** /32, /64, /96 carry it as one contiguous 32-bit run.

**Why /64 is the one length where the embedded address does not begin immediately after the
prefix.** The reserved octet occupies a *fixed absolute* position — bits 64..71 — regardless
of prefix length. RFC 6052 §2.2: "Bits 64 to 71 of the address are reserved for
compatibility with the host identifier format defined in the IPv6 addressing architecture
[RFC4291]. These bits MUST be set to zero." For a /32, /40, /48 or /56 prefix, bit 64 lies
*after* the prefix boundary, so the embedded address starts at the prefix boundary and is
interrupted (or, for /32, merely followed) by the u-octet. For a /96 prefix the u-octet
position lies *inside* the prefix, so nothing is inserted. Only for a /64 prefix does the
prefix end exactly at bit 64 — the very bit where the reserved octet begins — so the
reserved octet is emitted first and the embedded address is pushed to bit **72**. A naive
implementation that computes "offset = prefix length" gets /32, /40, /48, /56 and /96 right
by construction of the first segment, and gets **/64 wrong by exactly 8 bits**, producing a
plausible but incorrect IPv4 address.

RFC 6052 §2.3 states the extraction algorithm generically: for a /96 prefix take the last 32
bits directly; otherwise **delete the u-octet first**, forming a 120-bit string, then take
the 32 bits immediately following the prefix. Implementing §2.3 literally is safer than
hard-coding six offset pairs.

### Teredo layout, absolute bits (RFC 4380 §4)

```
 bits   0..31   :  Teredo prefix   2001:0000::/32          (plaintext)
 bits  32..63   :  Server IPv4                             (plaintext)
 bits  64..79   :  Flags (16 bits)                         (not an address)
 bits  80..95   :  Obfuscated mapped UDP port              (XOR 0xFFFF)
 bits  96..127  :  Obfuscated mapped Client IPv4           (XOR 0xFFFFFFFF)
```

Flags field, RFC 4380 §4 (bit numbering local to the 16-bit field, i.e. add 64 for absolute):

```
      0       0 0       1
     |0       7 8       5
     +----+----+----+----+
     |Czzz|zzUG|zzzz|zzzz|
     +----+----+----+----+
```

Updated by RFC 5991 §3.1:

```
                       1
   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
  |C|z|Random1|U|G|    Random2    |
  +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### ISATAP layout (RFC 5214 §6.1)

Verbatim, with bit numbering local to the 64-bit interface identifier (add 64 for absolute
offsets in the 128-bit address):

```
|0              1|1              3|3                              6|
|0              5|6              1|2                              3|
+----------------+----------------+--------------------------------+
|000000ug00000000|0101111011111110|mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm|
+----------------+----------------+--------------------------------+
```

- IID bits 0..15 (absolute **64..79**): the top 16 bits of the IANA OUI `00-00-5E` with the
  u and g bits at IID bits 6 and 7 (absolute bits **70** and **71**). `u=0,g=0` → `0x0000`;
  `u=1,g=0` → `0x0200`.
- IID bits 16..31 (absolute **80..95**): remaining OUI byte `5E` plus the type value `0xFE`
  → `0x5EFE`.
- IID bits 32..63 (absolute **96..127**): the 32-bit IPv4 address (`m` bits).

RFC 5214 §6.1: "When the IPv4 address is known to be globally unique, the 'u' bit
(universal/local) is set to 1; otherwise, the 'u' bit is set to 0." So both `::0:5efe:a.b.c.d`
and `::200:5efe:a.b.c.d` are valid ISATAP interface identifiers, differing only in absolute
bit 70.

### 6over4 layout (RFC 2529 §4)

Verbatim link-local diagram from RFC 2529 §4:

```
 +-------+-------+-------+-------+-------+-------+------+------+
 |  FE      80      00      00      00      00      00     00  |
 +-------+-------+-------+-------+-------+-------+------+------+
 |  00      00   |  00   |  00   |   IPv4 Address              |
 +-------+-------+-------+-------+-------+-------+------+------+
```

Bits 0..63 = `fe80::/64`; bits 64..95 = zero; bits 96..127 = the IPv4 address.

---

## Constraints and validity rules

1. **RFC 6052 §3.1 — Well-Known Prefix must not carry non-global IPv4.** "The Well-Known
   Prefix MUST NOT be used to represent non-global IPv4 addresses, such as those defined in
   [RFC1918] or listed in Section 3 of [RFC5735]. Address translators MUST NOT translate
   packets in which an address is composed of the Well-Known Prefix and a non-global IPv4
   address; they MUST drop these packets." So `64:ff9b::10.0.0.1`, `64:ff9b::192.168.1.1`,
   `64:ff9b::127.0.0.1`, `64:ff9b::0.0.0.0` etc. are **syntactically valid but semantically
   invalid**. This is a `must-drop`, not a `should`.
2. **RFC 6052 §3.1 — WKP should not build IPv4-translatable addresses.** "The Well-Known
   Prefix SHOULD NOT be used to construct IPv4-translatable IPv6 addresses", because more
   specific prefixes derived from the WKP cannot be advertised in inter-domain routing
   (§3.2).
3. **RFC 6052 §2.2 — the u-octet MUST be zero.** "Depending of the prefix length, the 4
   octets of the address may be separated by the reserved octet 'u', whose 8 bits MUST be set
   to zero." And for /96 Network-Specific Prefixes: "the administrators MUST ensure that the
   bits 64 to 71 are set to zero. A simple way to achieve that is to construct the /96
   Network-Specific Prefix by picking a /64 prefix, and then adding 4 octets set to zero."
   A non-zero bits-64..71 value in a would-be RFC 6052 address is a conformance violation —
   but see gotcha 6 about the suffix.
4. **RFC 6052 §2.2 — the suffix SHOULD be zero, but a non-zero suffix does not invalidate.**
   "These bits are reserved for future extensions and SHOULD be set to zero. Address
   translators who receive IPv4-embedded IPv6 addresses where these bits are not zero SHOULD
   ignore the bits' value and proceed as if the bits' value were zero." So a non-zero suffix
   must **not** cause extraction to fail.
5. **RFC 6052 §2.2 — only six prefix lengths are legal.** "The prefixes can only have one of
   the following lengths: 32, 40, 48, 56, 64, or 96. (The Well-Known Prefix is 96 bits long,
   and can only be used in the last form of the table.)" There is no /44, /52, /72, /80.
6. **RFC 6052 §3.2 — routing constraint.** IPv4-embedded prefixes more specific than the WKP
   must not be advertised in BGP; NSPs must be aggregated. Not a parsing rule, but it means a
   WKP-derived /104 seen in routing is anomalous.
7. **RFC 3056 §9 (Security Considerations) — 6to4 `V4ADDR` must be a global unicast address.**
   "any 6to4 traffic whose source or destination address embeds a V4ADDR which is not in the
   format of a global unicast address MUST be silently discarded by both encapsulators and
   decapsulators." RFC 1918 private addresses, broadcast, multicast, and loopback are
   excluded. So `2002:0a00:0001::` (embedding `10.0.0.1`) is syntactically well-formed but
   must be discarded.
8. **RFC 4380 §4 — Teredo global addresses must embed a global-scope client IPv4.** "the
   identifiers used in global addresses MUST include a global scope unicast IPv4 address,
   while the identifiers used in link-local addresses MAY include a private IPv4 address."
   A `2001:0::/32` address whose de-complemented client IPv4 is RFC 1918 violates this; an
   `fe80::` address using the same 64-bit identifier format does not.
9. **RFC 4380 §4 — Teredo flags.** "The bits 'UG' should be set to the value '00', indicating
   a non-global unicast identifier; The bit 'C' (cone) should be set to 1 if the client
   believes it is behind a cone NAT, to 0 otherwise… The bits indicated with 'z' must be set
   to zero and ignored on receipt. Thus, there are two currently specified values of the
   Flags field: '0x0000' (all null) if the cone bit is set to 0, and '0x8000' if the cone bit
   is set to 1." **RFC 5991 §3.1 supersedes this**: bits 2..5 and 8..15 of the flags field
   become `Random1`/`Random2`, precisely so that the address is not predictable. Therefore an
   implementation **must not** validate a Teredo address by requiring flags ∈ {0x0000,
   0x8000} — post-RFC-5991 clients emit arbitrary values in the random bits. Only U, G (bits
   6, 7 of the field; absolute bits 70, 71) and the single `z` at field bit 1 are constrained.
10. **RFC 5214 §6.1 — ISATAP IPv4 may be private.** "ISATAP enables automatic tunneling
    whether global or private IPv4 addresses are used." The u bit is the only signal, and it
    is advisory: u=1 means "known to be globally unique". Do not reject `::0:5efe:10.0.0.1`.
11. **RFC 8215 §5 — no assumptions about `64:ff9b:1::/48`.** "By default, IPv6 nodes and
    applications must not treat IPv6 addresses within 64:ff9b:1::/48 differently from other
    globally scoped IPv6 addresses. In particular, they must not make any assumptions
    regarding the syntax or properties of those addresses (e.g., the existence and location
    of embedded IPv4 addresses) or the type of associated translation mechanism." Also:
    "Note that 64:ff9b:1::/48 (or any more-specific prefix) is distinct from the WKP
    64:ff9b::/96. Therefore, the restrictions on the use of the WKP described in Section 3.1
    of [RFC6052] do not apply." So constraint 1 above does **not** extend to `64:ff9b:1::/48`.
12. **RFC 8215 §5 — do not use the covering aggregate.** "Operators tempted to use the
    covering aggregate prefix 64:ff9b::/47 to refer to all special-use prefixes currently
    reserved for IPv4/IPv6 translation should be warned that this aggregate includes a range
    of unallocated addresses". A classifier must not match on `64:ff9b::/47`.
13. **RFC 7050 §2, §8 — Pref64 discovery.** "Two well-known IPv4 addresses are defined for
    Pref64::/n discovery purposes: 192.0.0.170 and 192.0.0.171." Registered as
    `192.0.0.170/32` and `192.0.0.171/32` in the IANA IPv4 Special-Purpose Registry, served
    by `ipv4only.arpa` (`IPV4ONLY.ARPA. IN A 192.0.0.170` / `192.0.0.171`). `Pref64::WKA` is
    defined as "an IPv6 address consisting of Pref64::/n and WKA **at any of the locations
    allowed by RFC 6052**" — i.e. the discovery client must try all six geometries. RFC 7051
    is the companion analysis document and defines the Well-Known Prefix as `64:ff9b::/96`
    (§ definitions); it specifies no new geometry.
14. **RFC 6146 §3.3 — NAT64 introduces no new geometry.** "Pref64::/n as well as the address
    format are defined in [RFC6052]." Multiple `Pref64::/n` may be assigned simultaneously.
15. **RFC 6877 §2 — 464XLAT deliberately violates the RFC 6052 §3.3 same-prefix advice.**
    "The CLAT uses different IPv6 prefixes for CLAT-side and PLAT-side IPv4 addresses and
    therefore does not comply" with §3.3. A single 464XLAT deployment therefore has **two**
    distinct translation prefixes in play.
16. **RFC 4291 §2.5.5.1 — IPv4-compatible addresses are deprecated**; implementations "are
    not required to support this address type". Classifying `::a.b.c.d` as a live embedding
    is therefore a policy choice, not a protocol requirement.
17. **Interface identifiers are generally not meaningful.** RFC 7136 §5: the IID "MUST be
    viewed as an opaque bit string by third parties" and the u/g bits carry no meaning in a
    general IID. RFC 4941 (obsoleted by **RFC 8981**) defines temporary addresses with
    randomized IIDs; RFC 7217 defines stable, semantically opaque, per-prefix IIDs. Together
    these mean the low 64 bits of an arbitrary IPv6 address must be presumed random. Any
    "IPv4 detected in the interface identifier" heuristic (ISATAP, 6over4, or the folk habit
    of writing `2001:db8::192.0.2.1`) is only trustworthy when a specific marker is present —
    `5efe` at bits 80..95 for ISATAP, an explicit configured prefix for 6over4. **Absent a
    marker there is no way to distinguish an embedded IPv4 address from 32 random bits.**

---

## Gotchas

Every documented way an implementation extracts the wrong embedded IPv4 address.

1. **`::` and `::1` read as IPv4-compatible embeddings of `0.0.0.0` and `0.0.0.1`.** The
   unspecified address `::` (IANA: `::/128`, "Unspecified Address", RFC 4291) and the loopback
   `::1` (IANA: `::1/128`, "Loopback Address", RFC 4291) both match the bit pattern of RFC 4291
   §2.5.5.1 — 96 leading zero bits followed by 32 bits. A pattern-only matcher will report
   `0.0.0.0` and `0.0.0.1`. Both are separate, higher-priority IANA registry entries and must be
   excluded before any IPv4-compatible test. The general rule: `::a.b.c.d` where the low 32 bits
   are less than `0x01000000` (i.e. `0.x.x.x`) is almost certainly not an embedding at all. Also
   `::ffff` (= `::0.0.255.255`) and `::2` etc. Note some libraries print `::1` as `::0.0.0.1`.
2. **Forgetting Teredo's complement — or applying it to the wrong field.** RFC 4380 §4
   complements *only* the client IPv4 (bits 96..127) and the UDP port (bits 80..95). The
   **server** IPv4 at bits 32..63 is plaintext. Two symmetric failures: (a) reporting the raw
   bits 96..127 as the client address — for a client at `192.0.2.45` the raw bits are
   `0x3FFFFDD2`, which prints as the entirely plausible `63.255.253.210`; (b) complementing
   the server address too, turning `192.0.2.1` into `63.255.253.254`. Both produce
   wrong-but-routable-looking IPv4 addresses with no error.
3. **Assuming RFC 6052 geometry is computable from prefix length alone (the /64 trap).** The
   embedded address begins at bit `PL` for PL ∈ {32,40,48,56,96} but at bit **72** for PL=64,
   because the reserved u-octet at bits 64..71 (RFC 6052 §2.2) is absolute, not relative.
   `offset = PL` is wrong by exactly 8 bits for /64 and silently yields a shifted address.
4. **Ignoring the u-octet split for /40, /48 and /56.** Reading 32 contiguous bits starting at
   bit `PL` for a /40, /48 or /56 prefix straddles the zero u-octet, so the extracted address
   has a zero byte spliced into it and the true final octet(s) dropped. E.g. under a /48
   prefix, true IPv4 `192.0.2.33` is stored as bits 48..63 = `c000` and bits 72..87 = `0221`;
   a naive 32-bit read at offset 48 yields `c0000002` = `192.0.0.2`. Plausible. Wrong.
   Implement RFC 6052 §2.3 (delete the u-octet, then read 32 contiguous bits) instead of
   hard-coding offsets.
5. **Assuming the Well-Known Prefix is the only NAT64 prefix.** RFC 6052 §2.2 permits any
   Network-Specific Prefix of length 32/40/48/56/64/96; RFC 6146 §3.5.4 permits **multiple**
   `Pref64::/n` on one NAT64; RFC 8215 adds `64:ff9b:1::/48`; RFC 6877 §2 has 464XLAT running
   two prefixes at once. Consequences: (a) an address under a site NSP such as
   `2001:db8:122:344::192.0.2.33` is a real NAT64 address and matching only `64:ff9b::/96`
   misses it; (b) conversely, **NAT64 embedding is undecidable from the address alone**
   without out-of-band prefix knowledge (RFC 7050's whole purpose). A library must accept a
   caller-supplied prefix and must not claim "not NAT64" when it only means "not the WKP".
6. **Assuming the RFC 6052 suffix is zero, and rejecting when it is not.** RFC 6052 §2.2:
   receivers "SHOULD ignore the bits' value and proceed as if the bits' value were zero." A
   strict "suffix must be zero" validator wrongly rejects conformant traffic. Conversely, a
   *non-zero* u-octet at bits 64..71 is a MUST violation — the two fields have different
   strictness and must not be conflated.
7. **Treating IPv4-mapped as equal to the bare IPv4 address — the SSRF class.** `::ffff:127.0.0.1`
   is an IPv6 address with a distinct binary representation, not `127.0.0.1`. This is the single
   most exploited item in this document. Real advisories, all 2024–2026:
   - **CVE-2024-29415** — Node.js `ip` package ≤ 2.0.1: `isPublic()` fails to canonicalise
     `::fFFf:127.0.0.1` before range-checking, so an IPv4-mapped loopback passes as public.
   - **CVE-2026-44492** — `axios`: IPv4-mapped IPv6 addresses bypass `NO_PROXY` exclusions,
     enabling SSRF.
   - **CVE-2026-42449** — `n8n-mcp`: IPv4-mapped IPv6 bypasses SSRF protection in
     `validateUrlSync()`.
   - **CVE-2026-47684** — `@sync-in/server`: bypass of `regExpPrivateIP` via IPv4-mapped IPv6.
   - **CVE-2026-44232** — `dssrf`: "every IPv6 category bypasses `is_url_safe`".
   - **GHSA-vrcj-hv2q-c58m** (twenty-server), **GHSA-26h3-8ww8-v5fc** (Discourse),
     **GHSA-wv3h-5fx7-966h** (Directus) — the same normalisation gap.

   The recurring root cause is worth stating exactly, because it is a *parsing* bug: Node's URL
   parser normalises `::ffff:169.254.169.254` to the **hex** form `::ffff:a9fe:a9fe`, while the
   private-range check only recognised the **dotted-quad** rendering. Two textual spellings of
   one 128-bit value took different code paths. The lesson for `raddr`: classify on the 128-bit
   value, never on the text; and expose IPv4-mapped detection as an explicit, always-available
   step so callers can canonicalise before applying policy. Directus's fix — "adding a
   normalization step that converts IPv4-Mapped IPv6 addresses to their canonical IPv4 form
   prior to validation" — is the correct shape.
8. **Confusing IPv4-mapped `::ffff:0:0/96` with IPv4-translated `::ffff:0:0:0/96`.** They
   differ only in which 16-bit group holds `ffff`: bits **80..95** for mapped, bits **64..79**
   for translated. Both put the IPv4 address at bits 96..127, so an extractor keyed on the
   trailing 32 bits gets the right *address* but the wrong *classification*. And since no
   current RFC assigns `::ffff:0:0:0/96` (RFC 2765 obsoleted by RFC 6145 → RFC 7915, neither
   of which retains the form; absent from the IANA registry), classifying it as a live
   translation form is wrong on its own terms.
9. **Reading 6to4's `V4ADDR` at the wrong offset.** RFC 3056 §2 puts it at bits **16..47** —
   immediately after the 16-bit `2002` prefix, *not* at bits 32..63 (which is where Teredo's
   server address lives) and not in the interface identifier. `2002:c000:0204::` embeds
   `192.0.2.4`; reading bits 32..63 instead yields `2.4.0.0`. **[corrected
   2026-07-27]** — this line said `0.0.0.0`. Bits 32..63 of `2002:a.b.c.d::` are
   the low half of V4ADDR followed by the SLA ID, i.e. `c.d.0.0`, which is
   `0.0.0.0` only when `c` and `d` are both zero. The gotcha stands and the
   wrong read is still plausible-looking; only the number was wrong.
10. **Treating `2002::/16` as deprecated because RFC 7526 deprecated 6to4 anycast.** RFC 7526
    deprecates only RFC 3068's anycast mechanism and `192.88.99.1`; it says explicitly "The
    basic unicast 6to4 mechanism defined in [RFC3056] and the associated 6to4 IPv6 prefix
    2002::/16 are not deprecated." Conversely, treating `192.88.99.0/24` as live is also
    wrong: IANA marks it "Deprecated (6to4 Relay Anycast)" and it "MUST NOT be reassigned
    for other use except by a future IETF Standards Action."
11. **Extracting an IPv4 address from `64:ff9b:1::/48` using RFC 6052 /48 geometry.** RFC 8215
    §5 forbids assuming the existence or location of an embedded IPv4 address under this
    prefix; the prefix is deliberately technology-agnostic. Any extraction is a guess.
12. **Matching `64:ff9b::/47` to catch both translation prefixes.** RFC 8215 §5 warns the
    aggregate "includes a range of unallocated addresses… that the IETF could potentially
    reserve in the future for entirely different purposes." Match `64:ff9b::/96` and
    `64:ff9b:1::/48` separately.
13. **Applying the RFC 6052 §3.1 non-global-IPv4 prohibition to the wrong prefixes.** It binds
    the Well-Known Prefix `64:ff9b::/96` only. RFC 8215 §5 says explicitly it does not apply
    to `64:ff9b:1::/48`, and it never applied to Network-Specific Prefixes — `2001:db8:122:344::10.0.0.1`
    under an NSP is legitimate. Over-applying the rule rejects valid addresses.
14. **Missing the `0200:5efe` ISATAP variant.** RFC 5214 §6.1 defines the u bit at IID bit 6
    (absolute bit **70**): `0x0000` when the IPv4 address is not known globally unique,
    `0x0200` when it is. Matching only `::0:5efe:*` misses every globally-unique-marked ISATAP
    address, and matching only `::200:5efe:*` misses every private one. Match on bits 80..95
    == `0x5EFE` with bits 64..79 ∈ {`0x0000`, `0x0200`}.
15. **Rejecting ISATAP or 6over4 addresses carrying RFC 1918 IPv4.** RFC 5214 §6.1: "ISATAP
    enables automatic tunneling whether global or private IPv4 addresses are used." RFC 2529
    §4 likewise notes the u bit is zero because the identifier "is not globally unique."
    Private embedded addresses are expected, not anomalous.
16. **Confusing 6over4 with the IPv4-compatible form.** Both place the IPv4 address at bits
    96..127 with zeros at bits 64..95 (RFC 2529 §4). They are distinguished purely by the
    upper 64 bits: `::/64` → IPv4-compatible; `fe80::/64` → 6over4 link-local; any other /64 →
    an ordinary global address whose low bits happen to look like an IPv4 address. Under
    RFC 7136 §5 / RFC 7217 / RFC 8981 the last case is by far the most likely, since IIDs are
    opaque and often random. Report low confidence.
17. **Validating a Teredo address by requiring flags ∈ {0x0000, 0x8000}.** RFC 4380 §4 lists
    those as the only two values, but RFC 5991 §3.1 supersedes it with
    `|C|z|Random1|U|G|Random2|` precisely to defeat address prediction. A post-2010 Teredo
    client emits pseudo-random flag bits; a strict RFC 4380 flags check rejects it.
18. **Rejecting Teredo when the server or client field is unusual.** Neither field is
    constrained to be non-zero. `2001::` itself is a syntactically valid Teredo-prefixed
    address whose de-complemented client IPv4 is `255.255.255.255` and whose de-complemented
    port is `65535`. Report the values; do not infer they are meaningful.
19. **Assuming the discovery addresses are only ever seen under the WKP.** RFC 7050 §2 defines
    `Pref64::WKA` as `192.0.0.170`/`192.0.0.171` embedded "at any of the locations allowed by
    RFC 6052" — i.e. under *any* of the six geometries, under *any* prefix. RFC 7050's own
    worked example returns `2001:db8:42::192.0.0.170`, `2001:db8:43::192.0.0.170` **and**
    `64:ff9b::192.0.0.170` from a single query. An implementation that only checks
    `64:ff9b::192.0.0.170` misses the NSP cases.
20. **Assuming a single translation prefix per host or network.** RFC 6146 §3.5.4 allows
    multiple `Pref64::/n` on one NAT64; RFC 6877 §2 requires two distinct prefixes in 464XLAT
    (CLAT-side and PLAT-side). "The NAT64 prefix" is not a well-defined singular.
21. **Round-tripping through text and losing the form.** `::ffff:192.0.2.1`, `::ffff:c000:201`,
    and `0:0:0:0:0:ffff:c000:0201` are one address in three spellings (RFC 4291 §2.2 permits
    the mixed dotted-quad form for "addresses containing an embedded IPv4 address"). Comparing
    or classifying on strings rather than on the 128-bit value is the mechanism behind
    gotcha 7's CVE cluster.
22. **Reading `2001:db8::192.0.2.1`-style literals as embeddings.** RFC 4291 §2.2 allows the
    dotted-quad tail as a *textual convenience for any address*, not a declaration of
    embedding. The mere presence of dotted-quad text carries zero protocol meaning; only the
    prefix does.

---

## Sources

- https://www.rfc-editor.org/rfc/rfc4291.txt — IP Version 6 Addressing Architecture (§2.2, §2.5.1, §2.5.5.1, §2.5.5.2)
- https://www.rfc-editor.org/rfc/rfc2765.txt — Stateless IP/ICMP Translation Algorithm (SIIT), §2.1 (obsoleted)
- https://www.rfc-editor.org/rfc/rfc6145.txt — IP/ICMP Translation Algorithm (obsoletes 2765; obsoleted by 7915)
- https://www.rfc-editor.org/rfc/rfc7915.txt — IP/ICMP Translation Algorithm (obsoletes 6145)
- https://www.rfc-editor.org/rfc/rfc3056.txt — Connection of IPv6 Domains via IPv4 Clouds (6to4), §2, §5.2, §9
- https://www.rfc-editor.org/rfc/rfc3068.txt — An Anycast Prefix for 6to4 Relay Routers, §2.3 (Historic)
- https://www.rfc-editor.org/rfc/rfc7526.txt — Deprecating the Anycast Prefix for 6to4 Relay Routers, §4, §7
- https://www.rfc-editor.org/rfc/rfc4380.txt — Teredo, §2, §4
- https://www.rfc-editor.org/rfc/rfc5991.txt — Teredo Security Updates, §3.1
- https://www.rfc-editor.org/rfc/rfc6052.txt — IPv6 Addressing of IPv4/IPv6 Translators, §2.1, §2.2, §2.3, §3.1, §3.2, §3.3, §5
- https://www.rfc-editor.org/rfc/rfc6146.txt — Stateful NAT64, §1, §3.3, §3.5.4
- https://www.rfc-editor.org/rfc/rfc6147.txt — DNS64
- https://www.rfc-editor.org/rfc/rfc6877.txt — 464XLAT, §2, §6.3
- https://www.rfc-editor.org/rfc/rfc7050.txt — Discovery of the IPv6 Prefix Used for IPv6 Address Synthesis, §2, §3, §8
- https://www.rfc-editor.org/rfc/rfc7051.txt — Analysis of Solution Proposals for Hosts to Learn NAT64 Prefix
- https://www.rfc-editor.org/rfc/rfc8215.txt — Local-Use IPv4/IPv6 Translation Prefix, §3, §4, §5, §6
- https://www.rfc-editor.org/rfc/rfc5214.txt — ISATAP, §6.1
- https://www.rfc-editor.org/rfc/rfc2529.txt — Transmission of IPv6 over IPv4 Domains without Explicit Tunnels (6over4), §4, §5
- https://www.rfc-editor.org/rfc/rfc7136.txt — Significance of IPv6 Interface Identifiers, §5
- https://www.rfc-editor.org/rfc/rfc7217.txt — Stable, Opaque IIDs with SLAAC
- https://www.rfc-editor.org/rfc/rfc8981.txt — Temporary Address Extensions for SLAAC (obsoletes RFC 4941)
- https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml — IANA IPv6 Special-Purpose Address Registry
- https://www.sentinelone.com/vulnerability-database/cve-2024-29415/ — CVE-2024-29415 (Node.js `ip` package)
- https://github.com/advisories/GHSA-56c3-vfp2-5qqj — CVE-2026-42449 (n8n-mcp)
- https://zeropath.com/blog/cve-2026-44492-axios-ipv4-mapped-ipv6-ssrf-bypass — CVE-2026-44492 (axios)
- https://advisories.gitlab.com/npm/@sync-in/server/CVE-2026-47684/ — CVE-2026-47684 (Sync-in Server)
- https://advisories.gitlab.com/npm/dssrf/CVE-2026-44232/ — CVE-2026-44232 (dssrf)
- https://github.com/twentyhq/twenty/security/advisories/GHSA-vrcj-hv2q-c58m — twenty-server
- https://github.com/discourse/discourse/security/advisories/GHSA-26h3-8ww8-v5fc — Discourse
- https://github.com/directus/directus/security/advisories/GHSA-wv3h-5fx7-966h — Directus
