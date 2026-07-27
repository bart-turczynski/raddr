# Classifying IP Addresses — Library Divergence Inventory

Research notes for `raddr`. This document is about **classification and predicates**, not text
parsing (that is `05-parser-gotchas.md`). Every claim carries a source. Anything not directly
substantiated from a primary source is marked `UNVERIFIED`.

Primary sources consulted: the IANA IPv4 and IPv6 Special-Purpose Address Registries; CPython
`Lib/ipaddress.py` and issue/PR trackers; Go `src/net/ip.go` and `src/net/netip/netip.go` plus
the golang/go issue tracker; rust-lang/rust `library/core/src/net/ip_addr.rs` and tracking issue
#27709; OpenJDK `Inet4Address.java` / `Inet6Address.java` and bugs.openjdk.org; `ruby/ipaddr`
`lib/ipaddr.rb`; php-src `ext/filter/logical_filters.c`; `indutny/node-ip`, `whitequark/ipaddr.js`,
`rs/node-netmask`; `davidchall/ipaddress` and `hrbrmstr/iptools` on CRAN; NVD, GitHub Security
Advisories and the GitLab Advisory Database.

**The thesis in one line.** The IANA special-purpose registries record **six independent
columns** — Source, Destination, Forwardable, Globally Reachable, Reserved-by-Protocol, and a
Termination Date — and two of those columns are allowed to say **`N/A`**. Every library surveyed
here collapses that into one or two booleans named `is_private` / `is_global` /
`IsGlobalUnicast`, and each one collapses it *differently*. The result is that for a large set of
addresses, two well-maintained standard libraries give opposite answers to what looks like the
same question, and at least eleven CVEs have been filed against the consequences.

---

## Predicate comparison

Ranges are read from the cited source, not from executing code (per research constraints). The
"agrees with IANA?" column compares against the current
[IPv4 Special-Purpose Address Registry](https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml)
and [IPv6 Special-Purpose Address Registry](https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml),
specifically the **Globally Reachable** column where the predicate claims to be about
reachability, and otherwise against the RFC the predicate names.

### Python `ipaddress` (CPython, current `main`)

Source: [`Lib/ipaddress.py`](https://raw.githubusercontent.com/python/cpython/main/Lib/ipaddress.py)

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| py `ipaddress` | `IPv4Address.is_private` | `0.0.0.0/8`, `10/8`, `100.64.0.0/10`, `127/8`, `169.254/16`, `172.16/12`, `192.0.0.0/24` **minus** `192.0.0.9/32` and `192.0.0.10/32`, `192.0.0.170/31`, `192.0.2.0/24`, `192.168/16`, `198.18/15`, `198.51.100.0/24`, `203.0.113.0/24`, `240/4`, `255.255.255.255/32` | [`_IPv4Constants._private_networks`](https://raw.githubusercontent.com/python/cpython/main/Lib/ipaddress.py) | Yes — it is the registry's `Globally Reachable == False` set verbatim. But see the `100.64.0.0/10` carve-out below; the docstring says *"`is_private` is `False` for `100.64.0.0/10`"* even though the network is in the list |
| py | `IPv4Address.is_global` | `not in _public_network and not is_private` | same | Yes, modulo `100.64.0.0/10` |
| py | `IPv6Address.is_private` | `::1/128`, `::/128`, `::ffff:0:0/96`, `64:ff9b:1::/48`, `100::/64`, `2001::/23` **minus** `2001:1::1/128`, `2001:1::2/128`, `2001:3::/32`, `2001:4:112::/48`, `2001:20::/28`, `2001:30::/28`; plus `2001:db8::/32`, `2002::/16`, `3fff::/20`, `fc00::/7`, `fe80::/10`. **For IPv4-mapped addresses it delegates to `ipv4_mapped.is_private`** | same | Mostly. `2002::/16` (6to4) is IANA `N/A`, not `False` — Python resolves the registry's non-answer to "private". `64:ff9b::/96` is IANA `True` and correctly absent |
| py | `IPv6Address.is_global` | `ipv4_mapped.is_global` if 4-in-6, else `not is_private` | same | as above |
| py | `is_reserved` | v4: `240.0.0.0/4`. v6: `_reserved_networks` (the unallocated-by-RFC-4291 blocks) | same | v4 disagrees with `is_private`, which also claims `240/4` |
| py | `is_link_local` | v4 `169.254.0.0/16`; v6 `fe80::/10` | same | Yes |
| py | `is_loopback` | v4 `127.0.0.0/8`; v6 `::1` exactly | same | Yes |
| py | `is_multicast` | v4 `224.0.0.0/4`; v6 `ff00::/8` | same | Yes (RFC 4291) |
| py | `is_unspecified` | v4 `0.0.0.0/32`; v6 `::/128` | same | Narrower than IANA's `0.0.0.0/8` "This network" entry — but that is RFC-correct |
| py | `IPv6Address.is_site_local` | `fec0::/10` | same | Range is right; the concept is deprecated by [RFC 3879](https://www.rfc-editor.org/rfc/rfc3879) and `fec0::/10` is **not in the IANA special registry at all** |

### Go `net` and `net/netip`

Sources: [`src/net/ip.go`](https://raw.githubusercontent.com/golang/go/master/src/net/ip.go),
[`src/net/netip/netip.go`](https://raw.githubusercontent.com/golang/go/master/src/net/netip/netip.go)

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| go `net` | `IP.IsPrivate` | `10/8`, `172.16/12`, `192.168/16`, `fc00::/7` — and nothing else | [ip.go](https://raw.githubusercontent.com/golang/go/master/src/net/ip.go) | Not a registry predicate; it is RFC 1918 + RFC 4193 only. Doc says so: *"according to RFC 1918 (IPv4 addresses) and RFC 4193 (IPv6 addresses)"* |
| go | `IP.IsGlobalUnicast` | everything except `255.255.255.255`, `0.0.0.0`, `::`, `127/8`, `::1`, `224/4`, `ff00::/8`, `169.254/16`, `fe80::/10` | ip.go | **No, and deliberately.** Doc: *"It returns true even if ip is in IPv4 private address space or local IPv6 unicast address space."* Returns `true` for `10.0.0.1`, `100.64.0.1`, `240.0.0.1`, `2001:db8::1`, `fc00::1` |
| go | `IP.IsLoopback` | v4 `127.0.0.0/8`; v6 `::1` | ip.go | Yes |
| go | `IP.IsLinkLocalUnicast` | v4 `169.254.0.0/16`; v6 `fe80::/10` | ip.go | Yes |
| go | `IP.IsLinkLocalMulticast` | v4 `224.0.0.0/24`; v6 scope nibble `2` | ip.go | Yes (RFC 4291 §2.7) |
| go | `IP.IsInterfaceLocalMulticast` | v6 only, scope nibble `1` (`ff01::/16` family). Always `false` for IPv4 | ip.go | Yes |
| go | `IP.IsUnspecified` | `0.0.0.0` or `::` | ip.go | Yes |
| go | `netip.Addr.IsPrivate` etc. | same ranges, but each predicate begins `if ip.Is4In6() { ip = ip.Unmap() }` | [netip.go](https://raw.githubusercontent.com/golang/go/master/src/net/netip/netip.go) | Same as `net.IP` since the CVE-2024-24790 fix — **except `IsUnspecified`, which does no unmapping** |

`IsPrivate` in `main` now carries an explicit disclaimer: *"IsPrivate does not describe a
security property of addresses, and should not be used for access control."* That sentence is
absent from [`net@go1.24.0`](https://pkg.go.dev/net@go1.24.0#IP.IsPrivate) and
[`net@go1.25.0`](https://pkg.go.dev/net@go1.25.0#IP.IsPrivate), so it landed in the Go 1.26 cycle,
following [golang/go#79925](https://github.com/golang/go/issues/79925). The specific CL hash is
`UNVERIFIED`.

### Rust `std::net`

Source: [`library/core/src/net/ip_addr.rs`](https://raw.githubusercontent.com/rust-lang/rust/master/library/core/src/net/ip_addr.rs)

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| rust | `Ipv4Addr::is_private` **(stable 1.7)** | `10/8`, `172.16/12`, `192.168/16` | ip_addr.rs | RFC 1918 only, like Go |
| rust | `Ipv4Addr::is_shared` **(unstable, `feature(ip)`)** | `100.64.0.0/10` | ip_addr.rs | Yes — Rust is the only stdlib surveyed with a dedicated CGNAT predicate |
| rust | `Ipv4Addr::is_reserved` **(unstable)** | `240.0.0.0/4` **excluding** `255.255.255.255` | ip_addr.rs | Deliberate divergence. Doc: *"This implementation explicitly excludes it, since it is obviously not reserved for future use."* IANA lists `255.255.255.255/32` as a separate "Limited Broadcast" entry |
| rust | `Ipv4Addr::is_benchmarking` **(unstable)** | `198.18.0.0/15` | ip_addr.rs | Yes |
| rust | `Ipv4Addr::is_documentation` **(stable 1.7)** | `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | ip_addr.rs | Yes (RFC 5737) |
| rust | `Ipv4Addr::is_global` **(unstable)** | `!(0/8 ∪ private ∪ shared ∪ 127/8 ∪ 169.254/16 ∪ 192.0.0.0/24∖{.9,.10} ∪ documentation ∪ benchmarking ∪ reserved ∪ broadcast)` | ip_addr.rs | Yes — tracks the registry's Globally Reachable column, including the `192.0.0.9`/`192.0.0.10` carve-outs |
| rust | `Ipv6Addr::is_unique_local` **(stable 1.84)** | `fc00::/7` | ip_addr.rs | Yes |
| rust | `Ipv6Addr::is_unicast_link_local` **(stable 1.84)** | `fe80::/10` | ip_addr.rs | Yes |
| rust | `Ipv6Addr::is_documentation` **(unstable)** | `2001:db8::/32`, `3fff::/20` | ip_addr.rs | Yes (RFC 3849 + RFC 9637) |
| rust | `Ipv6Addr::is_global` **(unstable)** | excludes `::`, `::1`, `::ffff:0:0/96`, `64:ff9b:1::/48`, `100::/64`, `2001::/23` ∖ {`2001:1::1`, `2001:1::2`, `2001:3::/32`, `2001:4:112::/48`, `2001:20::/28`, `2001:30::/28`}, `2002::/16`, documentation, `5f00::/16`, `fc00::/7`, `fe80::/10` | ip_addr.rs | Closest match of any stdlib. But it resolves `2002::/16`'s IANA `N/A` to non-global |
| rust | `Ipv6Addr::is_unicast_global` **(unstable)** | `is_unicast && !loopback && !link_local && !unique_local && !unspecified && !documentation && !benchmarking` | ip_addr.rs | **Disagrees with its own sibling `is_global`** — does not exclude 6to4, Teredo, IPv4-mapped, NAT64 or `5f00::/16` |
| rust | `Ipv6Addr::is_ipv4_mapped` **(unstable)** | `::ffff:0:0/96` | ip_addr.rs | Yes |
| rust | `Ipv6Addr::to_ipv4` **(stable 1.0)** | matches **both** `::a.b.c.d` and `::ffff:a.b.c.d` | ip_addr.rs | Too permissive; `to_ipv4_mapped` (stable 1.63) was added to fix that |

Stability: `is_global`, `is_shared`, `is_benchmarking`, `is_reserved`, `is_unicast`,
`is_unicast_global`, `multicast_scope`, `is_ipv4_mapped` and the v6/`IpAddr` `is_documentation`
are all still `#[unstable(feature = "ip", issue = "27709")]` as of July 2026, per master and the
[stable docs](https://doc.rust-lang.org/stable/std/net/struct.Ipv4Addr.html).
[rust-lang/rust#27709](https://github.com/rust-lang/rust/issues/27709) was opened 12 Aug 2015 and
is still open — roughly eleven years unstabilised. The uncontroversial members
(`is_unique_local`, `is_unicast_link_local`) were split off and shipped in 1.84.0, leaving the
gate holding only the contested residue.

### Java `java.net.InetAddress`

Sources: [`Inet4Address.java`](https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/net/Inet4Address.java),
[`Inet6Address.java`](https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/java/net/Inet6Address.java)

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| java | `isSiteLocalAddress` (v4) | `10/8`, `172.16/12`, `192.168/16` | Inet4Address.java, comment `// refer to RFC 1918` | RFC 1918 only. No `100.64/10` |
| java | `isSiteLocalAddress` (v6) | **`fec0::/10`** | Inet6Address.java | **No.** `fec0::/10` was deprecated by RFC 3879 in 2004 and is absent from the IANA special registry. There is **no JDK predicate at all for `fc00::/7`** — see [JDK-8375307](https://bugs.openjdk.org/browse/JDK-8375307), open |
| java | `isLinkLocalAddress` | v4 `169.254.0.0/16`; v6 `fe80::/10` | both | Yes |
| java | `isAnyLocalAddress` | v4 **`0.0.0.0/32` only**; v6 `::/128` | both | Narrower than the registry's `0.0.0.0/8`. [JDK-8300121](https://bugs.openjdk.org/browse/JDK-8300121) asks for `/8`; open since 2023 |
| java | `isLoopbackAddress` | v4 `127.0.0.0/8`; v6 `::1/128` | both | Yes |
| java | `isMulticastAddress` | v4 `224.0.0.0/4`; v6 `ff00::/8` | both | Yes |
| java | `isMCGlobal` | v4 `224.0.1.0`–`238.255.255.255`; v6 scope nibble `0xe` | both | Yes |
| java | `isMCNodeLocal` | v4 **hardcoded `return false;`**; v6 scope nibble `1` | both | Asymmetric by design |
| java | `isMCLinkLocal` | v4 `224.0.0.0/24`; v6 scope `2` | both | Yes |
| java | `isMCSiteLocal` | v4 `239.255.0.0/16`; v6 scope `5` | both | Yes |
| java | `isMCOrgLocal` | v4 `239.192.0.0/14`; v6 scope `8` | both | Yes |

Java has **no** `isPrivate`, `isGlobal`, `isReserved`, `isUniqueLocal` or `isDocumentation`.
IPv4-mapped input is converted to an `Inet4Address` on construction — per the
[`Inet6Address` Javadoc](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/net/Inet6Address.html):
*"Java will never return an IPv4-mapped address … it will be converted into an IPv4 address."*
That makes Java consistent on 4-in-6, unlike PHP.

### Ruby `IPAddr`

Source: [`ruby/ipaddr lib/ipaddr.rb`](https://github.com/ruby/ipaddr/blob/master/lib/ipaddr.rb) (`IPAddr::VERSION = "1.2.9"`)

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| ruby | `private?` | v4 `10/8`, `172.16/12`, `192.168/16`; v6 **`fc00::/7` only**, plus the IPv4-mapped equivalents of the three v4 blocks | ipaddr.rb | RFC 1918 + RFC 4193. Note: **contrary to a common belief, Ruby's `private?` has never included `fec0::/10`** — the string `fec0` does not appear in the file |
| ruby | `link_local?` (alias `link_local_unicast?`) | v4 `169.254/16`; v6 `fe80::/10`; plus `::ffff:169.254.0.0/16` | ipaddr.rb | Yes |
| ruby | `loopback?` | v4 `127/8`; v6 `::1` exactly; plus `::ffff:127.0.0.0/8` | ipaddr.rb | Yes |
| ruby | `multicast?` | v4 `224.0.0.0/4`; v6 `ff00::/8`; plus IPv4-mapped | ipaddr.rb | Yes |
| ruby | `link_local_multicast?` | v4 `224.0.0.0/24`; v6 `ff02::/16`; IPv4-mapped branch uses mask `0xffff0000` where the comment claims `/24` | ipaddr.rb | **Bug** — `::ffff:224.0.255.1` wrongly returns `true`. See Gotcha 14 |
| ruby | `ipv4_mapped?` | `::ffff:0:0/96` | ipaddr.rb | Yes |
| ruby | `ipv4_compat?` | `::/96` excluding `::` and `::1`; emits an obsolescence warning under `$VERBOSE` | ipaddr.rb | Yes (RFC 4291 deprecates it) |

Ruby has **no** `global?`, **no** `site_local?`, **no** `unicast?`, **no** `reserved?`. No CVE has
ever been filed against `IPAddr` — OSV queries for `RubyGems/ipaddr` return empty and there is no
`gems/ipaddr` directory in `rubysec/ruby-advisory-db`. `UNVERIFIED` as an exhaustive negative.

### PHP `filter_var` with `FILTER_VALIDATE_IP`

Source: [`ext/filter/logical_filters.c`](https://github.com/php/php-src/blob/master/ext/filter/logical_filters.c).
**The implementation was rewritten in PHP 8.3.16 / 8.4.3 (16 Jan 2025)**; anything asserted here
must be version-qualified.

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| php ≥ 8.3.16 | `FILTER_FLAG_NO_PRIV_RANGE` | `10/8`, `172.16/12`, `192.168/16`, `fc00::/7` | logical_filters.c; [docs](https://www.php.net/manual/en/filter.constants.php) | RFC 1918 + RFC 4193 only |
| php ≥ 8.3.16 | `FILTER_FLAG_NO_RES_RANGE` | v4 `0.0.0.0/8`, `127/8`, `169.254/16`, `240/4`; v6 `::/128`, `::1/128`, `::ffff:0:0/96`, `fe80::/10` | logical_filters.c; docs | Partial. Notably `255.255.255.255` is caught only incidentally by the `240/4` branch |
| php ≥ 8.3.16 | `FILTER_FLAG_GLOBAL_RANGE` (≥ 8.2.0) | only `192.88.99.0/24` and `64:ff9b::/32` are marked `global = true`; everything unrecognised **passes** | logical_filters.c | No. The function `return SUCCESS`es for unclassified addresses **before** the flag checks, so an address in no known block satisfies `GLOBAL_RANGE` by default |
| php ≤ 8.2 / ≤ 8.3.15 | `NO_RES_RANGE` (v6) | `::`, `::1`, `5f00::/8`, `fe80::/10`, `2001:db8::/32`, `2001:10::/28`, **`3ff3::/16`** | logical_filters.c, old impl | No — `::ffff:0:0/96` was missing (that is GH-16944), and `3ff3::/16` is a garbled constant; the historical 6bone prefix was `3ffe::/16` |

The header comment on the new implementation reads: *"From the tables in RFC 6890 - Special-Purpose
IP Address Registries. Including errata."* PHP is the only implementation surveyed that names a
registry document as its source of truth in code. Nonetheless it still leaves `100.64.0.0/10`,
`224.0.0.0/4`, `ff00::/8` and `fec0::/10` with **no flag at all**.

### Node.js ecosystem

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| npm `ip` (all versions incl. 2.0.1) | `isPrivate` | regex-matched: `10.*`, `192.168.*`, `172.(16-31).*`, `169.254.*`, `f[cd]xx:`, `fe80:`, `::1`, `::`, each optionally prefixed `::ffff:` | [lib/ip.js](https://raw.githubusercontent.com/indutny/node-ip/main/lib/ip.js) | No. Misses `100.64/10`, `0.0.0.0/8`, `240/4`, `192.0.0.0/24`, `198.18/15`, NAT64, 6to4, Teredo |
| npm `ip` | `isPublic` | `!isPrivate` | same | Inherits every gap above |
| npm `ip` | `isLoopback` | `127.*`, `0177.*`, `0x7f.*`, `fe80::1`, `::1`, `::` — the `::ffff:` regex **lacks the `/i` flag and lacks a `$` anchor** | same | No. `::fFFf:127.0.0.1` escapes; `127.0.0.1.evil.com` matches |
| `ipaddr.js` | `IPv4.range()` | returns one of `unspecified` `0/8`, `broadcast` `255.255.255.255/32`, `multicast` `224/4`, `linkLocal` `169.254/16`, `loopback` `127/8`, `carrierGradeNat` `100.64/10`, `private` `10/8`+`172.16/12`+`192.168/16`, `reserved` `192.0.0.0/24`+`192.0.2.0/24`+`192.88.99.0/24`+`198.18/15`+`198.51.100.0/24`+`203.0.113.0/24`+`240/4`, `as112`, `amt`, default `unicast` | [lib/ipaddr.js](https://raw.githubusercontent.com/whitequark/ipaddr.js/main/lib/ipaddr.js) | Closest of the JS libraries. It reports a **label**, not a verdict — the healthiest design here |
| `ipaddr.js` | `IPv6.range()` | `unspecified` `::/128`, `linkLocal` `fe80::/10`, `multicast` `ff00::/8`, `loopback` `::1/128`, `uniqueLocal` `fc00::/7`, `ipv4Mapped` `::ffff:0:0/96`, `deprecatedSiteLocal` `fec0::/10`, `discard` `100::/64`, `rfc6145` `::ffff:0:0:0/96`, `rfc6052` `64:ff9b::/96` + `64:ff9b:1::/48`, `6to4` `2002::/16`, `teredo` `2001::/32`, `benchmarking` `2001:2::/48`, `amt` `2001:3::/32`, `as112v6`, `deprecatedOrchid` `2001:10::/28`, `orchid2` `2001:20::/28`, `droneRemoteIdProtocolEntityTags` `2001:30::/28`, `segmentRouting` `5f00::/16`, `reserved` `2001::/23`+`2001:db8::/32`+`3fff::/20` | same | Good coverage, but **first-match-in-insertion-order, not longest-prefix** — see Gotcha 11 |
| `netmask` | `Netmask` containment | n/a — a prefix container, not a classifier; downstream `private-ip` used it as one | [rs/node-netmask](https://github.com/rs/node-netmask) | n/a |
| `ssrfcheck` ≥ 1.2.0 | `isPrivateIP` | 26 IPv4 CIDRs incl. `0/8`, `100.64/10`, `192.0.0.0/24` + five /32 carve-outs, `192.31.196.0/24`, `192.52.193.0/24`, `192.88.99.0/24`, `192.175.48.0/24`, `224/4`, `240/4`, `255.255.255.255/32`; plus an IPv6 direct blocklist **and a separate "unwrap the embedded IPv4 and recheck" list** covering `::ffff:0:0/96`, `::ffff:0:0:0/96`, `64:ff9b::/96`, `64:ff9b:1::/48`, `::/96` | [src/is-private-ip.js](https://raw.githubusercontent.com/felippe-regazio/ssrfcheck/main/src/is-private-ip.js) | Most complete of the JS classifiers; the two-tier unwrap design is the correct shape |
| `ssrf-req-filter` | block iff `ipaddr.range() !== 'unicast'` | delegates entirely to ipaddr.js | [lib/index.js](https://unpkg.com/ssrf-req-filter@1.1.0/lib/index.js) | Inherits ipaddr.js. **Fails open**: `if (!ipaddr.isValid(ip)) { return true; }` |
| `request-filtering-agent` | `allowPrivateIPAddress:false`, `allowMetaIPAddress:false` | ipaddr.js `range() !== 'unicast'`, plus explicit `0.0.0.0`/`::` handling | [source](https://raw.githubusercontent.com/azu/request-filtering-agent/master/src/request-filtering-agent.ts) | Inherits ipaddr.js. The **only** library surveyed whose docs name `169.254.169.254` explicitly |

### R packages

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| R `ipaddress` (1.0.3.9000) | `is_private()` | `0.0.0.0/8`, `10/8`, `127/8`, `169.254/16`, `172.16/12`, `192.0.0.0/29`, `192.0.0.170/31`, `192.0.2.0/24`, `192.168/16`, `198.18/15`, `198.51.100.0/24`, `203.0.113.0/24`, `240/4`, `::/127`, `::ffff:0:0/96`, `100::/64`, `2001::/23`, `2001:db8::/32`, `fc00::/7`, `fe80::/10` | [`R/reserved.R`](https://github.com/davidchall/ipaddress/blob/master/R/reserved.R) | **No — it is a stale Python ~3.8-era snapshot.** Uses `192.0.0.0/29` where Python/IANA use `192.0.0.0/24` with carve-outs; **omits `64:ff9b:1::/48`, `2002::/16`, `3fff::/20`**; has no exception mechanism at all |
| R `ipaddress` | `is_global()` | `!is_within_any(x, 100.64.0.0/10) & !is_private(x)` | same | Reproduces Python's three-valued `100.64.0.0/10` behaviour, but on the stale table — so `is_global()` returns `TRUE` for `2002::/16` and `3fff::/20` |
| R `ipaddress` | `is_reserved()` | `240/4`, `::/3`, `4000::/2`, `8000::/2`, `c000::/3`, `e000::/4`, `f000::/5`, `f800::/6`, `fe00::/9` | same | Means "outside RFC 4291 global unicast", not the IANA Reserved-by-Protocol column |
| R `ipaddress` | `is_site_local()` | v4 hardcoded `FALSE`; v6 `fec0::/10` (via Asio) | [`src/reserved.cpp`](https://github.com/davidchall/ipaddress/blob/master/src/reserved.cpp) | Deprecated concept, as with Java |
| R `ipaddress` | `is_loopback()` | v4 `127/8`; v6 **`::1/128` only** (Asio) | same | Yes |
| R `ipaddress` | `is_6to4()` / `is_teredo()` / `is_ipv4_mapped()` | `2002::/16` / `2001::/32` / `::ffff:0:0/96` | [`R/ipv6_transition.R`](https://github.com/davidchall/ipaddress/blob/master/R/ipv6_transition.R) | Yes — and it exposes the *labels* without folding them into `is_private` |
| R `iptools` (0.7.2) | `is_multicast()` | v4 `224/4`; v6 `ff00::/8` (Asio) | [asio_bindings.cpp](https://github.com/hrbrmstr/iptools) | The **only** special-range predicate in the package. No `is_private`, no `is_global`, no `is_loopback` |
| R `iptools` | dataset `iana_special_assignments` | vendored IPv4 special registry CSV, **"Last updated 2014-08-07"**; IPv6 special registry not vendored at all | package data | Stale by ~12 years; classification is left to the user via `ip_in_any()` |
| R `IP` (0.1.6) | `ipv4.reserved()`, `ipv6.reserved()`, `ipv6.unicast()`, … | returns **range tables**, not booleans; data in a binary `R/sysdata.rda` | [CRAN](https://cran.r-project.org/package=IP) | `UNVERIFIED` — grep of NAMESPACE, R sources and man pages for "IANA", "registry", "RFC", "special-purpose" returns zero hits. The package makes **no documented provenance claim** |

R `ipaddress`'s DESCRIPTION says it is *"inspired by the Python 'ipaddress' module"*, and its
roxygen block links the four IANA registries but claims **no registry version or snapshot date**.

### Other SSRF guards

| library | predicate | exact ranges it covers | source | agrees with IANA? |
|---|---|---|---|---|
| Python `advocate` | `AddrValidator` | rejects v4 on `is_private ∨ is_loopback ∨ is_link_local ∨ is_multicast ∨ is_reserved ∨ is_unspecified ∨ ¬is_global`; v6 adds `is_site_local`; explicitly blocks `192.88.99.0/24` and `64:ff9b::/96`; **extracts and re-validates embedded IPv4** | [addrvalidator.py](https://raw.githubusercontent.com/JordanMilne/Advocate/master/advocate/addrvalidator.py) | Best design in the survey: it delegates to `ipaddress.is_global`, so its table tracks CPython's registry updates instead of going stale |
| Go `doyensec/safeurl` ≥ 0.2.4 | `privateNetworks` | v4: `10/8`, `172.16/12`, `192.168/16`, `127/8`, `0/8`, `169.254/16`, `192.0.0.0/24`, `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`, `192.88.99.0/24`, `198.18/15`, `224/4`, `240/4`, `255.255.255.255/32`, `100.64/10`. v6: `::/128`, `::1/128`, `100::/64`, `2001::/23`, `2001:2::/48`, `2001:db8::/32`, `2001::/32`, `fc00::/7`, `fe80::/10`, `ff00::/8`, `2002::/16`, `64:ff9b::/96`, `64:ff9b:1::/48`, `5f00::/16`, `2001:10::/28`, `2001:20::/28`, `3fff::/20`, `100:0:0:1::/64` | [ip.go](https://raw.githubusercontent.com/doyensec/safeurl/main/ip.go) | Good post-CVE-2026-54452. Blocks `64:ff9b::/96` even though IANA marks it Globally Reachable `True` — defensible for SSRF, wrong as a reachability claim. **No `::ffff:0:0/96` entry** (`UNVERIFIED` whether Go's `net.IP.Contains` normalisation makes this moot) |
| PHP Symfony `IpUtils::PRIVATE_SUBNETS` | pre-fix | omitted `::/96`, `2002::/16`, `2001::/32`, `64:ff9b::/96`, `64:ff9b:1::/48` | [GHSA-38cx-cq6f-5755](https://github.com/symfony/symfony/security/advisories/GHSA-38cx-cq6f-5755) | Fixed 2026 — see CVE table |

---

## Disagreement cases

Each case is a single address, the answers different libraries give, and which answer is
defensible. Answers are derived from the source read above, not from execution.

### 1. `100.64.0.1` — Shared Address Space (RFC 6598 / CGNAT). **Is it private?**

IANA: `Source True`, `Destination True`, `Forwardable True`, **`Globally Reachable False`**,
`Reserved-by-Protocol False`
([registry](https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml)).

| library | answer |
|---|---|
| Python `ipaddress` | `is_private == False` **and** `is_global == False` — both false, deliberately |
| Go `net` | `IsPrivate() == false`, `IsGlobalUnicast() == true` |
| Rust std | `is_private() == false`, `is_shared() == true`, `is_global() == false` |
| Java | no predicate matches — nothing is true |
| Ruby `IPAddr` | `private? == false`; no other predicate applies |
| PHP ≥ 8.3.16 | passes `NO_PRIV_RANGE` **and** `NO_RES_RANGE` — an explicit no-flag branch in the source |
| npm `ip` | `isPrivate() == false`, `isPublic() == true` |
| `ipaddr.js` | `range() == 'carrierGradeNat'` |
| R `ipaddress` | `is_private() == FALSE`, `is_global() == FALSE` |
| `ssrfcheck`, `safeurl`, `advocate` | blocked |

**Which is defensible:** all of them, which is the point. IANA says not globally reachable but
forwardable; the address is private *to the carrier* and public *to the subscriber*. Python's
answer — `is_private == False && is_global == False` — is the only one that is honest about the
question having no boolean answer, and CPython documents it as such: *"`is_private` has value
opposite to `is_global`, except for the `100.64.0.0/10` IPv4 range where they are both `False`."*
The Go maintainers considered adding it to `IsPrivate` in
[#79925](https://github.com/golang/go/issues/79925) and declined; Tailscale and NetBird use
`100.64/10` as their private overlay space, which argues the other way. `ipaddr.js`'s answer — a
*label*, `carrierGradeNat` — sidesteps the question entirely and is the model `raddr` should
follow.

### 2. `192.0.0.9` and `192.0.0.10` — globally-reachable carve-outs inside a non-global /24

IANA: `192.0.0.0/24` "IETF Protocol Assignments" is Globally Reachable `False`, but
`192.0.0.9/32` (Port Control Protocol Anycast) and `192.0.0.10/32` (TURN Anycast) are Globally
Reachable **`True`**. `192.0.0.8/32` (IPv4 dummy address) is `False`. `192.0.0.170/32` and
`192.0.0.171/32` (NAT64/DNS64 Discovery) are `False` and Reserved-by-Protocol `True`.

| library | answer for `192.0.0.9` |
|---|---|
| Python ≥ 3.12.4 | `is_private == False`, `is_global == True` — carve-out present in `_private_networks_exceptions` |
| Python < 3.12.4 | `is_private == True`, `is_global == False` — **this is CVE-2024-4032** |
| Rust std (≥ 1.77) | `is_global() == true` — explicit `octets[3] != 9 && octets[3] != 10` test |
| Go | `IsPrivate() == false`, `IsGlobalUnicast() == true` (by accident — Go has no `192.0.0.0/24` concept) |
| PHP ≥ 8.3.16 | `192.0.0.0/24` branch sets **no flag**, so it passes `NO_PRIV_RANGE` and `NO_RES_RANGE` but fails `GLOBAL_RANGE` |
| `ipaddr.js` | `range() == 'reserved'` (whole `/24`) |
| R `ipaddress` | uses `192.0.0.0/29`, so `192.0.0.9` is **outside** the block → `is_private == FALSE` (right answer, wrong reason) |
| Java, Ruby, npm `ip` | no predicate matches |

**Which is defensible:** Python ≥ 3.12.4 and Rust. This is the cleanest demonstration that a
boolean over a prefix cannot represent the registry — the registry contains a /24 that is
non-global containing two /32s that are global. `ipaddr.js`'s "the whole /24 is reserved" is a
label, not a reachability claim, so it is not wrong so much as answering a different question.

### 3. `0.0.0.0` and `0.1.2.3` — "This network"

IANA: `0.0.0.0/8` "This network" — Source `True`, Destination `False`, Forwardable `False`,
Globally Reachable `False`, Reserved-by-Protocol `True`. Note **Source `True`, Destination
`False`**: it is a legal source address and an illegal destination.

| library | `0.0.0.0` | `0.1.2.3` |
|---|---|---|
| Python | `is_unspecified True`, `is_private True`, `is_global False` | `is_unspecified False`, `is_private True`, `is_global False` |
| Go | `IsUnspecified true`, `IsGlobalUnicast false`, `IsPrivate false` | `IsUnspecified false`, **`IsGlobalUnicast true`**, `IsPrivate false` |
| Rust | `is_unspecified true`, `is_global false` | `is_global false` (`octets[0]==0`) |
| Java | `isAnyLocalAddress true` | **`isAnyLocalAddress false`** — [JDK-8300121](https://bugs.openjdk.org/browse/JDK-8300121), open |
| Ruby | no `unspecified?` predicate exists; `private? false` | `private? false` |
| PHP ≥ 8.3.16 | `NO_RES_RANGE` rejects (`ip[0]==0` covers the whole /8) | `NO_RES_RANGE` rejects |
| npm `ip` | `isPrivate` matches only the literal `::`/`::1` strings, not `0.0.0.0` | `isPublic true` |

**Which is defensible:** Python, Rust and PHP treat the whole `/8` as non-global; that matches
IANA. Java and Go treat only the exact address `0.0.0.0` as special, which is RFC 1122-faithful
for "unspecified" but leaves `0.1.2.3` classified as global unicast. Both are internally
coherent; they answer different questions. `0.0.0.0` reaching localhost on Linux is a separate,
kernel-level fact no library models.

### 4. `240.0.0.1` and `255.255.255.255` — Class E and limited broadcast

IANA: `240.0.0.0/4` "Reserved", Globally Reachable `False`. `255.255.255.255/32` "Limited
Broadcast" is a **separate entry**, Destination `True`, Globally Reachable `False`.

| library | `240.0.0.1` | `255.255.255.255` |
|---|---|---|
| Python | `is_reserved True`, `is_private True`, `is_global False` | `is_reserved True`, `is_private True` |
| Rust | `is_reserved() == true`, `is_global false` | **`is_reserved() == false`** by explicit design; `is_broadcast() == true` |
| Go | `IsGlobalUnicast() == true` — Class E is global unicast to Go | `IsGlobalUnicast() == false` (explicit `!ip.Equal(IPv4bcast)`) |
| Java | no predicate matches either | no predicate matches |
| Ruby | no predicate matches | no predicate matches |
| PHP ≥ 8.3.16 | `NO_RES_RANGE` rejects | rejected, but only via the `ip[0] >= 240` branch; the dedicated branch is dead code |
| npm `ip` | `isPublic() == true` for both | `isPublic() == true` |

**Which is defensible:** Rust's exclusion of `255.255.255.255` from `is_reserved` is the most
careful reading — IANA lists it separately with a different Destination value, so folding it into
"Reserved for future use" is a category error. Rust documents the choice: *"This implementation
explicitly excludes it, since it is obviously not reserved for future use."* Go's
`IsGlobalUnicast() == true` for `240.0.0.1` is correct *as an address-architecture statement* and
useless as a reachability statement.

### 5. `169.254.169.254` — cloud instance metadata

IANA: `169.254.0.0/16` Link Local — Forwardable `False`, Globally Reachable `False`,
Reserved-by-Protocol `True`. **The registry has nothing to say about `.169.254` specifically.**

| library | answer |
|---|---|
| Python | `is_link_local True`, `is_private True`, `is_global False` |
| Go | `IsLinkLocalUnicast true`, `IsPrivate false`, `IsGlobalUnicast false` |
| Rust | `is_link_local true`, `is_global false` |
| Java | `isLinkLocalAddress true`, `isSiteLocalAddress false` |
| Ruby | `link_local? true`, `private? false` |
| PHP | `NO_RES_RANGE` rejects; `NO_PRIV_RANGE` **passes** |
| `ipaddr.js` | `range() == 'linkLocal'` |
| npm `ip` | `isPrivate() == true` (169.254 regex) |

**No library in this survey special-cases `169.254.169.254`.** Every one covers it only as a side
effect of `169.254.0.0/16`. `request-filtering-agent` is the only one that even names it in the
documentation. Consequence: any bug that breaks link-local classification silently unblocks cloud
metadata — npm `ip`'s `::fFFf:169.254.169.254` is the live example. Note also that **Alibaba
Cloud's metadata endpoint is `100.100.100.200`**, inside `100.64.0.0/10`, so it is *not* covered by
any link-local rule and is missed entirely by Go, Java, Ruby, PHP and npm `ip`.

**Which is defensible:** none of them are wrong; the registry genuinely does not distinguish this
address, and a library that hardcoded it would be encoding a cloud-vendor convention as an
Internet fact. This belongs in a separate, clearly-labelled non-IANA overlay.

### 6. `::ffff:10.0.0.1` — IPv4-mapped IPv6 wrapping RFC 1918 space

IANA: `::ffff:0:0/96` — Source `False`, Destination `False`, Forwardable `False`, Globally
Reachable `False`, Reserved-by-Protocol `True`. The registry says nothing about the embedded IPv4.

| library | answer |
|---|---|
| Python | `is_private True` — delegates via `ipv4_mapped` |
| Go `net.IP` | `IsPrivate() == true` — `To4()` collapses 4-in-6 |
| Go `netip.Addr` | `true` **since** the CVE-2024-24790 fix; `false` before |
| Rust | no `Ipv6Addr::is_private` exists at all; `is_global() == false` because `::ffff:0:0/96` is excluded wholesale |
| Java | input is converted to `Inet4Address` on construction → `isSiteLocalAddress() == true` |
| Ruby ≥ 1.2.6 | `private? true` |
| PHP ≥ 8.3.16 | matches the `::ffff:0:0/96` branch → **`reserved`, not `private`** → `NO_PRIV_RANGE` **passes** |
| `ipaddr.js` `parse()` | `range() == 'ipv4Mapped'` — **never recurses into the embedded IPv4**. Use `ipaddr.process()` |
| npm `ip` | `isPrivate() == true` for `::ffff:10.0.0.1`; but `isLoopback('::fFFf:127.0.0.1') == false` (missing `/i`) — CVE-2024-29415 |
| `ssrfcheck`, `advocate` | unwrap and re-check the embedded IPv4 — correct |

**Which is defensible:** two answers are legitimate. "It is in `::ffff:0:0/96`, which is
non-global, full stop" (Rust) and "the semantics are those of the embedded IPv4" (Python, Go,
Java, Ruby) both make sense. What is **not** defensible is PHP's: classifying it as `reserved` but
not `private`, so that a filter asking "exclude private ranges" lets `::ffff:10.0.0.1` through. And
`ipaddr.js`'s `'ipv4Mapped'` label is fine as a label but lethal for any consumer that denies a
*named list* like `['private','loopback','linkLocal']` rather than denying everything
`!== 'unicast'`.

### 7. `64:ff9b::a00:1` — NAT64 well-known prefix embedding `10.0.0.1`

IANA: `64:ff9b::/96` "IPv4-IPv6 Translat." — Forwardable `True`, **Globally Reachable `True`**.
`64:ff9b:1::/48` is Globally Reachable `False`.

| library | answer |
|---|---|
| Python | `is_private False`, `is_global True` for `64:ff9b::/96`; `is_private True` for `64:ff9b:1::/48`. **Does not inspect the embedded IPv4** |
| Rust | `is_global() == true` for `64:ff9b::/96`, `false` for `64:ff9b:1::/48`. Does not inspect the embedding |
| Go | `IsGlobalUnicast() == true`, `IsPrivate() == false` |
| `ipaddr.js` | `range() == 'rfc6052'`, embedded IPv4 never examined |
| `advocate`, `safeurl`, `ssrfcheck` | blocked outright |

**Which is defensible:** IANA says `64:ff9b::/96` **is** globally reachable, and it is —
the *prefix* is routable, and the translator on the far side decides what the embedded IPv4 means.
So Python/Rust/Go are right as reachability claims and wrong as SSRF guards. The two questions
have different answers and no boolean can carry both. This is the sharpest example in the whole
document of why `raddr` should report the registry fact and label the embedding separately rather
than emit a verdict.

### 8. `2002:0a00:0001::1` — 6to4 embedding `10.0.0.1`; and `2001:0:...` Teredo

IANA: `2002::/16` 6to4 — Forwardable `True`, **Globally Reachable `N/A`** (footnote referencing
RFC 3056 / 7526). `2001::/32` TEREDO — **Globally Reachable `N/A`** as well. These are the only
two entries in the IPv6 registry where the Globally Reachable column declines to answer.

| library | answer for `2002::/16` |
|---|---|
| Python | `is_private == True` (it is in `_private_networks`) → `is_global == False` |
| Rust (≥ 1.77) | `is_global() == false`. [PR #119006](https://github.com/rust-lang/rust/pull/119006) **removed** `2002::/16` from global, reading `N/A` as false |
| Go | `IsGlobalUnicast() == true`, `IsPrivate() == false` |
| `ipaddr.js` | `range() == '6to4'` / `'teredo'` |
| R `ipaddress` | **`is_global() == TRUE`** — `2002::/16` is absent from its table; it exposes `is_6to4()` separately |
| Java, Ruby, PHP (no flag) | nothing matches |

**Which is defensible: none of the booleans.** IANA wrote `N/A`. Python and Rust turn `N/A` into
`False`; Go and R turn it into `True`. Both are inventions. This is the load-bearing case for
`raddr`'s three-valued design: the correct output is *"the registry declines to state"*, plus the
separate fact that the address embeds `10.0.0.1`.

### 9. `fc00::1` vs `fd00::1` — Unique-Local

IANA: a single entry `fc00::/7` "Unique-Local", Globally Reachable **`False` with footnote [4]**
(pointing at RFC 4193's provision that ULAs may be routed by agreement between sites). RFC 4193
splits the /7: `fd00::/8` is locally-assigned, `fc00::/8` is reserved for a future
centrally-assigned registry **that was never created**.

| library | `fc00::1` | `fd00::1` |
|---|---|---|
| Python | `is_private True` | `is_private True` |
| Go | `IsPrivate true`, `IsGlobalUnicast **true**` | same |
| Rust | `is_unique_local() true` (stable 1.84) | same |
| Java | **nothing matches** — `isSiteLocalAddress()` tests `fec0::/10` only. [JDK-8375307](https://bugs.openjdk.org/browse/JDK-8375307) open | same |
| Ruby | `private? true` | same |
| PHP | `NO_PRIV_RANGE` rejects | same |
| `ipaddr.js` | `range() == 'uniqueLocal'` | same |
| npm `ip` | `/^f[cd][0-9a-f]{2}:/i` matches | matches |

**Which is defensible:** every library treats the /7 as one block, and that matches IANA's single
registry row. Nobody distinguishes `fc00::/8` from `fd00::/8`, even though `fc00::/8` has no
defined assignment authority and an address there is arguably *less* legitimate than one in
`fd00::/8`. The interesting divergence is Java's total absence of coverage, and Go's `fc00::1`
being simultaneously `IsPrivate() == true` and `IsGlobalUnicast() == true` — two predicates in one
package that a reader would expect to be mutually exclusive.

### 10. `fec0::1` — deprecated site-local

IANA: **not in the IPv6 special-purpose registry at all.** RFC 3879 (2004) deprecated the prefix;
RFC 4291 §2.5.7 says new implementations must treat it as global unicast.

| library | answer |
|---|---|
| Java | `isSiteLocalAddress() == true` — still live in the JDK |
| Python | `is_site_local == True`; but **not** in `_private_networks`, so `is_private == False` and `is_global == True` |
| Ruby | **no `site_local?` method exists**; `private?` is `false` |
| Go | `IsGlobalUnicast() == true`, `IsPrivate() == false` |
| Rust | no predicate; `is_global() == true` |
| PHP | no branch at all → unclassified → passes every flag |
| `ipaddr.js` | `range() == 'deprecatedSiteLocal'` (added after 1.9.1; in 1.9.1 it returns `'unicast'`) |
| R `ipaddress` | `is_site_local() == TRUE` (via Asio), `is_private() == FALSE` |
| `advocate` | rejects on `is_site_local` |

**Which is defensible:** Ruby's — the concept was deleted from the architecture twenty-two years
ago and a library that offers `site_local?` invites callers to depend on it. Python's split is the
subtlest trap in the document: `is_site_local == True` **and** `is_global == True` at the same
time, on the same address. `ipaddr.js`'s `deprecatedSiteLocal` label is the honest middle ground.

### 11. `2001:db8::1` — documentation prefix

IANA: `2001:db8::/32` Documentation — Source `False`, Destination `False`, Globally Reachable
`False`. Same for `3fff::/20` (RFC 9637, 2024).

| library | `2001:db8::1` | `3fff::1` |
|---|---|---|
| Python (current) | `is_private True`, `is_global False` | `is_private True`, `is_global False` |
| Rust | `is_documentation() true`, `is_global false` | `is_documentation() true` (added by RFC 9637 support) |
| Go | `IsGlobalUnicast() == true`, `IsPrivate() == false` | `IsGlobalUnicast() == true` |
| PHP ≥ 8.3.16 | no flag → passes `NO_PRIV_RANGE` and `NO_RES_RANGE` | not recognised at all |
| PHP ≤ 8.2 | `NO_RES_RANGE` **rejected** it | not recognised |
| R `ipaddress` | `is_private() == TRUE` (its own example documents this) | **`is_global() == TRUE`** — `3fff::/20` absent from the table |
| `ipaddr.js` | `range() == 'reserved'` | `'reserved'` (main branch only) |

**Which is defensible:** Python and Rust. Note PHP *regressed* here: `2001:db8::/32` was rejected
by `NO_RES_RANGE` before 8.3.16 and is not rejected after. And `3fff::/20` is a clean test of
registry freshness — anything that predates 2024 gets it wrong.

### 12. `224.0.0.1` — multicast, under PHP

| library | answer |
|---|---|
| PHP ≥ 8.3.16 | **falls through to "no special block" → passes `NO_PRIV_RANGE`, `NO_RES_RANGE` *and* `FILTER_FLAG_GLOBAL_RANGE`.** There is no multicast handling in `logical_filters.c` at all |
| everyone else | `is_multicast` / `IsMulticast` / `isMulticastAddress` → `true` |
| `ssrfcheck` < 1.2.0 | classified public — **CVE-2025-8267** |

**Which is defensible:** PHP's is straightforwardly a gap; `224.0.0.0/4` is not in the
special-purpose registry (it is in the main IPv4 address-space registry as "Multicast"), which is
probably how a registry-derived table missed it. A good illustration that the *special-purpose*
registry alone is not a complete classification source — `02-ipv4-ranges.md` covers the
address-space registry that fills the gap.

---

## Known bugs and CVEs

| identifier | library | affected versions | what was misclassified | consequence | fix |
|---|---|---|---|---|---|
| [CVE-2024-4032](https://nvd.nist.gov/vuln/detail/CVE-2024-4032) | CPython `ipaddress` | < 3.8.20, 3.9.x < 3.9.20, 3.10.x < 3.10.15, 3.11.x < 3.11.10, 3.12.x < 3.12.4, 3.13.0a1–a5 | `_private_networks` missed `100.64.0.0/10` and `192.0.0.8/32`; `192.0.0.0/24` had no carve-out for the globally-reachable `192.0.0.9/32` and `192.0.0.10/32`; IPv6 missed `64:ff9b:1::/48`; `2001::/23` lacked the six globally-reachable exceptions | `is_private`/`is_global` gave the wrong answer for both directions — some non-global addresses reported global (SSRF filter bypass) and some global addresses reported private (over-blocking). CVSS 7.5 HIGH (`AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N`, CISA-ADP) | 3.8.20, 3.9.20, 3.10.15, 3.11.10, 3.12.4, 3.13.0a6. [gh-113171](https://github.com/python/cpython/issues/113171) / [PR #113179](https://github.com/python/cpython/pull/113179) |
| [CVE-2024-24790](https://github.com/golang/go/issues/67680) | Go `net/netip` | Go < 1.21.11, < 1.22.4 (`UNVERIFIED` exact patch levels) | `netip.Addr.IsPrivate`, `IsLoopback`, `IsLinkLocalUnicast` etc. returned `false` for IPv4-mapped IPv6 forms that returned `true` in plain IPv4 form. `net.IP` was correct; `netip.Addr` was not | SSRF / access-control bypass via `::ffff:127.0.0.1`, `::ffff:10.0.0.1`. Release-blocking; GHSA-49gw-vxvf-fc2g. Reported by Enze Wang (Alioth) and Jianjun Chen (Zhongguancun Lab) | added `if ip.Is4In6() { ip = ip.Unmap() }` to each predicate. **`IsUnspecified` still does not unmap** |
| [CVE-2023-42282](https://nvd.nist.gov/vuln/detail/CVE-2023-42282) | npm `ip` | ≤ 1.1.8 and = 2.0.0 | `0x7f.1` and other alternate numeric encodings classified as globally routable by `isPublic()` | SSRF. NVD CVSS 9.8 CRITICAL; **GitHub Advisory DB scored it Low** — the discrepancy caused the maintainer dispute below | 1.1.9 / 2.0.1, commit [`6a3ada9`](https://github.com/indutny/node-ip/commit/6a3ada9b471b09d5f0f5be264911ab564bf67894) — added `normalizeToLong` |
| [CVE-2024-29415](https://nvd.nist.gov/vuln/detail/CVE-2024-29415) | npm `ip` | **all versions through 2.0.1 — no fix exists** | `127.1`, `127.0.1`, `127.00.0x1`, `01200034567`, `012.1.2.3`, `fe80::0001`, `000:0:0000::01`, `::fFFf:127.0.0.1` all report `isPublic() == true`. Root causes: `isPrivate` skips numeric normalisation whenever the loose `ipv6Regex` matches, and `isLoopback`'s `::ffff:` regex lacks the `/i` flag | SSRF. CVSS 8.1 HIGH. CWE-918 + CWE-941. Incomplete fix for CVE-2023-42282 | **none.** [PR #143](https://github.com/indutny/node-ip/pull/143) and [#144](https://github.com/indutny/node-ip/pull/144) never merged; repository archived read-only. Maintainer Fedor Indutny: *"I believe that the security impact of the bug is rather dubious"* and *"I'm very curious how an untrusted input could end up being passed into ip.isPrivate or ip.isPublic"* ([BleepingComputer](https://www.bleepingcomputer.com/news/security/dev-rejects-cve-severity-makes-his-github-repo-read-only/)) |
| [CVE-2021-28918](https://nvd.nist.gov/vuln/detail/CVE-2021-28918) | npm `netmask` | ≤ 1.0.6 | Leading zeros stripped and the octet parsed as decimal: `0177.0.0.1` (octal `127.0.0.1`) read as `177.0.0.1` | SSRF / RFI / LFI across ~280,000 dependent projects. CVSS 9.1 CRITICAL | 2.0.0. [GHSA-pch5-whg9-qr2r](https://github.com/advisories/GHSA-pch5-whg9-qr2r) |
| [CVE-2021-29418](https://nvd.nist.gov/vuln/detail/CVE-2021-29418) | npm `netmask` | < 2.0.1 (i.e. 2.0.0 still broken) | Invalid octal digits such as `9` still slipped through the rewritten parser | Access-control bypass. CVSS 5.3 MODERATE. Incomplete fix for CVE-2021-28918 | 2.0.1, commit `rs/node-netmask@3f19a05` |
| CVE-2021-29424 | Perl `Net::Netmask` | < 2.0000 | Same octal bug class in the Perl module | Access-control bypass | 2.0000. Included here because it is the same defect in a different language, found in the same sweep |
| [CVE-2020-28360](https://sick.codes/sick-2020-022/) | npm `private-ip` | ≤ 1.0.5 | Regex "not comprehensive enough to cover localhost variations, nor many of the industry standard private IP ranges" | SSRF | patched by switching to the `netmask` package with ARIN reserved ranges — which is precisely how netmask's own octal bug propagated downstream |
| [CVE-2025-8267](https://www.miggo.io/vulnerability-database/cve/CVE-2025-8267) | npm `ssrfcheck` | < 1.2.0 | `224.0.0.0/4` omitted from `PRIVATE_CIDRS`, so all multicast was classified public | SSRF to UPnP / mDNS internal services. CVSS 8.8 HIGH | 1.2.0, commit [`9507b49`](https://github.com/felippe-regazio/ssrfcheck/commit/9507b49fd764f2a1a1d1e3b9ee577b7545e6950e) — a one-line addition |
| [CVE-2026-54452](https://advisories.gitlab.com/golang/github.com/doyensec/safeurl/CVE-2026-54452/) | Go `doyensec/safeurl` | < 0.2.4 | `privateNetworks` missing `64:ff9b:1::/48`, `5f00::/16`, `3fff::/20`, `100:0:0:1::/64` | SSRF. CWE-918. Published 2026-07-17. A pure "hardcoded table went stale as IANA added rows" failure | 0.2.4 |
| [CVE-2026-48736 / GHSA-38cx-cq6f-5755](https://github.com/symfony/symfony/security/advisories/GHSA-38cx-cq6f-5755) | Symfony `IpUtils::PRIVATE_SUBNETS` | `http-client` ≥5.4 <5.4.53; `http-foundation` ≥6.4 <6.4.41, ≥7.0 <7.4.13, ≥8.0 <8.0.13 | Omitted the IPv6 transition forms `::/96`, `2002::/16` (6to4), `2001::/32` (Teredo), `64:ff9b::/96` and `64:ff9b:1::/48` | SSRF in `NoPrivateNetworkHttpClient`. Exploit shape: `http://[2002:7f00:1::]/` reaches `127.0.0.1` | 5.4.53, 6.4.41, 7.4.13, 8.0.13 |
| [GH-16944](https://github.com/php/php-src/issues/16944) (no CVE) | PHP `filter_var` | ≤ 8.2.x, ≤ 8.3.15 | `filter_var('::ffff:0:1', FILTER_VALIDATE_IP, FILTER_FLAG_NO_RES_RANGE)` passed — `::ffff:0:0/96` was absent from the reserved list. The old table also contained the bogus constants `5f00::/8` and `3ff3::/16` (the historical 6bone prefix was `3ffe::/16`) | IPv4-mapped IPv6 bypassed reserved-range filtering | rewritten in 8.3.16 / 8.4.3 against RFC 6890, [PR #17111](https://github.com/php/php-src/pull/17111) |
| [ruby/ipaddr `c1383a3`](https://github.com/ruby/ipaddr/commit/c1383a3356) (no CVE) | Ruby `IPAddr` | ≤ 1.2.8 (every Ruby release through late 2025) | The IPv4-mapped guard was `@addr & 0xffff_0000_0000 == 0xffff_0000_0000` — it checked only that group 5 equals `ffff`, not that groups 1–4 are zero. `2001:718:1404:c8:0:ffff:ac19:c80e` reported `private?`; `2001:db8:1:1:0:ffff:7f00:1` reported `loopback?` | **Over**-classification: public addresses reported private. A false-positive / availability bug, not an SSRF bypass | 1.2.9 (2026-04-25) |
| [JDK-8375307](https://bugs.openjdk.org/browse/JDK-8375307) (open) | Java `Inet6Address` | all | `isSiteLocalAddress()` matches `fec0::/10` only; **no JDK predicate matches `fc00::/7`** | A ULA is invisible to every JDK classification method | unfixed, status New since 2026-01-13 |
| [JDK-8300121](https://bugs.openjdk.org/browse/JDK-8300121) (open) | Java `InetAddress` | all | `isAnyLocalAddress()` covers `0.0.0.0/32`, not `0.0.0.0/8` per RFC 6890 §2.2.2 | `0.1.2.3` classified as an ordinary address | unfixed, fixVersion `tbd` since 2023-01-12 |
| [JDK-4670299](https://bugs.openjdk.org/browse/JDK-4670299) (fixed 1.4.1) | Java `Inet4Address` | < 1.4.1 | `isSiteLocalAddress()` matched `172.32.0.0`–`172.255.255.255` | Over-broad private classification | the `& 0xF0` mask now in the source |
| [JDK-4406189](https://bugs.openjdk.org/browse/JDK-4406189) (fixed 1.4.0) | Java `Inet4Address` | < 1.4.0 | `isMCGlobal()` returned `false` for `224.0.1.0`–`238.255.255.255` | Multicast scope misclassified | fixed |
| [golang/go#79925](https://github.com/golang/go/issues/79925) (closed, not planned) | Go `net` | all | Not a bug report but a proposal: `IsPrivate` is the ecosystem's de-facto SSRF primitive and does not recognise 6to4, Teredo, NAT64, ISATAP or CGNAT | Go maintainer **Damien Neil**: *"From what I've seen, `IsPrivate` was a mistake. Just about every use of it that I've seen seems to misuse it."* | closed not planned; the fallback ask — a doc warning — appears to have landed separately in the Go 1.26 cycle |
| [ruby/ipaddr `link_local_multicast?`](https://github.com/ruby/ipaddr/blob/master/lib/ipaddr.rb) (unreported) | Ruby `IPAddr` | current | IPv4-mapped branch uses mask `0xffff0000` where the comment and the plain-IPv4 branch both say `/24`. `::ffff:224.0.255.1` returns `true` | Minor over-classification | unreported as of this survey. `UNVERIFIED` that no issue exists |

---

## Gotchas

1. **`is_private` and `is_global` are not complements, and at least one library says so out
   loud.** CPython documents: *"`is_private` has value opposite to `is_global`, except for the
   `100.64.0.0/10` IPv4 range where they are both `False`."* Any consumer that computes
   `!is_private` as a stand-in for "reachable" is wrong for the whole of CGNAT space. `raddr`
   should never expose two booleans whose relationship needs a footnote.

2. **`Globally Reachable` is a three-valued column, and two IPv6 entries say `N/A`.** `2001::/32`
   (Teredo) and `2002::/16` (6to4) both carry `N/A` with a footnote. Python and Rust resolve `N/A`
   to `False`; Go and R `ipaddress` resolve it to `True`. Neither is a reading of the registry —
   both are inventions. Preserving `N/A` as a distinct outcome is the single strongest argument
   for `raddr`'s design.

3. **`fc00::/7`'s `False` carries footnote [4].** IANA marks Unique-Local as not globally
   reachable *with a caveat* pointing at RFC 4193's provision for inter-site routing by agreement.
   A boolean discards the footnote. Nobody surveyed surfaces it.

4. **A non-global prefix can contain globally reachable /32s.** `192.0.0.0/24` is
   Globally Reachable `False` but contains `192.0.0.9/32` (PCP Anycast) and `192.0.0.10/32` (TURN
   Anycast), both `True`. `2001::/23` similarly contains six globally-reachable carve-outs. Any
   classifier built on "is this address inside a listed prefix" without an exception mechanism is
   structurally incapable of being right. R `ipaddress` has no exception mechanism at all.

5. **"Global unicast" and "globally reachable" are different questions and Go answers the first
   one.** `net.IP.IsGlobalUnicast()` is an RFC 4291 *address-architecture* category. It returns
   `true` for `10.0.0.1`, `100.64.0.1`, `240.0.0.1`, `2001:db8::1` and `fc00::1`. Go's own doc
   says so. Callers routinely read the name as reachability. Go 1.26 added a security disclaimer
   to `IsPrivate` for exactly this reason; `IsGlobalUnicast` still has none.

6. **A predicate named after an RFC covers that RFC and nothing else.** Go's and Rust's
   `is_private` are RFC 1918 + RFC 4193, full stop — no `127/8`, no `169.254/16`, no `100.64/10`,
   no `fe80::/10`. Python's `is_private` is the *registry's* non-global set, which includes all of
   those. Two functions with the same name in two standard libraries return opposite answers for
   `127.0.0.1`. There is no correct answer; there is only a documented one.

7. **Two predicates in the same library can both be true when a reader expects exclusivity.**
   Go: `fc00::1` is `IsPrivate() == true` **and** `IsGlobalUnicast() == true`. Python: `fec0::1` is
   `is_site_local == True` **and** `is_global == True`. Rust: `is_global` and `is_unicast_global`
   disagree on 6to4, Teredo, IPv4-mapped, NAT64 and `5f00::/16`.

8. **Java classifies deprecated address space and does not classify current address space.**
   `Inet6Address.isSiteLocalAddress()` tests `fec0::/10`, deprecated by RFC 3879 in 2004 and absent
   from the IANA registry; there is no JDK method anywhere that matches `fc00::/7`. Twenty-two
   years on, [JDK-8375307](https://bugs.openjdk.org/browse/JDK-8375307) is still open.

9. **IPv4-mapped IPv6 gets four different treatments.** (a) Collapse to IPv4 and use IPv4 semantics
   — Go `net.IP`, Java (at construction), Ruby, Python. (b) Treat `::ffff:0:0/96` as one
   non-global block and stop — Rust. (c) Label it `ipv4Mapped` and never look inside — `ipaddr.js`.
   (d) Classify it `reserved` but **not** `private`, so `NO_PRIV_RANGE` lets it through — PHP.
   Only (d) is indefensible, and it is live in every PHP ≥ 8.3.16.

10. **Transition-form embedding is a separate axis that no boolean can carry.**
    `64:ff9b::a00:1` is in a prefix IANA marks Globally Reachable `True` and embeds `10.0.0.1`.
    Both facts are true simultaneously. `2002:7f00:1::` is `N/A`-reachable and embeds `127.0.0.1` —
    the exact Symfony CVE-2026-48736 exploit. Report the prefix fact and the embedding fact as two
    fields, never one verdict.

11. **`ipaddr.js`'s `range()` is first-match-in-insertion-order, not longest-prefix.**
    `subnetMatch` iterates the `SpecialRanges` object and returns the first key whose subnet
    matches. `2001:2::1` is inside both `teredo` (`2001::/32`) and `benchmarking` (`2001:2::/48`);
    `teredo` is declared first, so `benchmarking` is unreachable for that address. Range **names
    are also unstable across versions**: `deprecated` (`2001:10::/28`) was renamed
    `deprecatedOrchid` on main, and 1.9.1 lacks `as112`, `amt`, `discard`, `benchmarking`,
    `orchid2`, `deprecatedSiteLocal`, `segmentRouting`, `198.18.0.0/15` and the second `rfc6052`
    entry entirely. Any deny-list keyed on range-name strings silently degrades on upgrade.

12. **Denying a named list is not the same as denying everything that is not unicast.**
    `ssrf-req-filter` blocks `range() !== 'unicast'` and is incidentally safe on IPv4-mapped
    addresses. A consumer that instead blocks `['private','loopback','linkLocal','reserved']`
    lets `::ffff:127.0.0.1` straight through, because its range is `ipv4Mapped`. Same library,
    same data, opposite outcome.

13. **Hardcoded tables go stale, and the staleness is invisible.** `3fff::/20` was registered by
    RFC 9637 in 2024; anything older classifies it as ordinary global unicast. `5f00::/16` (SRv6
    SIDs, RFC 9602) is the same story. CVE-2026-54452 is exactly this failure and nothing else.
    R `iptools` ships an IPv4 special registry snapshot dated **2014-08-07** and does not vendor
    the IPv6 registry at all. R `ipaddress` links the registries in its documentation but claims
    no version and hardcodes a Python ~3.8-era snapshot. **A classifier that cannot state which
    registry revision it encodes cannot be audited.**

14. **The IPv4 special-purpose registry is not a complete classification source.**
    `224.0.0.0/4` is not in it — multicast lives in the main IPv4 address-space registry. PHP's
    registry-derived rewrite therefore has **no multicast handling at all**, and `224.0.0.1`
    passes `NO_PRIV_RANGE`, `NO_RES_RANGE` *and* `FILTER_FLAG_GLOBAL_RANGE`. `ssrfcheck` shipped
    the same omission as CVE-2025-8267.

15. **Fail-open is the default in several guards.** `ssrf-req-filter`:
    `if (!ipaddr.isValid(ip)) { return true; }` — anything unparseable is allowed.
    `request-filtering-agent` **warns rather than throws** on a malformed CIDR in the deny list, so
    a typo silently disables a rule. PHP's `php_filter_validate_ip` `return SUCCESS`es for
    unclassified addresses **before** evaluating `FILTER_FLAG_GLOBAL_RANGE`, so an address in no
    known block satisfies "must be global" by default.

16. **`0.0.0.0/8` is `Source: True, Destination: False` — one prefix, two answers.** Any single
    boolean has to pick one. Python/Rust/PHP pick "non-global" for the whole `/8`; Java and Go
    special-case only the exact address `0.0.0.0`, leaving `0.1.2.3` as ordinary global unicast.
    The registry's Source/Destination split is the fact; both booleans are lossy projections of it.

17. **`255.255.255.255` is a separate registry row, not part of `240.0.0.0/4`.** IANA lists
    Limited Broadcast independently with `Destination: True` where `240.0.0.0/4` has
    `Destination: False`. Python folds it into `is_reserved`; Rust deliberately does not, and
    documents why. PHP's dedicated branch for it is unreachable dead code shadowed by
    `ip[0] >= 240`.

18. **`0.0.0.0` and `100.100.100.200` are not link-local, and metadata guards assume everything
    is.** No library surveyed special-cases `169.254.169.254`, which is fine — but every SSRF
    guard's metadata protection is therefore *entirely* a side effect of blocking
    `169.254.0.0/16`. Alibaba Cloud's metadata endpoint is `100.100.100.200` in CGNAT space, which
    Go, Java, Ruby, PHP and npm `ip` do not cover under any predicate.

19. **`fc00::/8` and `fd00::/8` are not the same thing, and nobody distinguishes them.** RFC 4193
    reserves `fc00::/8` for a centrally-assigned registry **that was never created**; only
    `fd00::/8` is defined for locally-assigned ULAs. IANA lists one row for the `/7`, so every
    library follows suit. An address in `fc00::/8` is arguably less legitimate than one in
    `fd00::/8`, and no classifier says so.

20. **`is_reserved` means four different things.** Python v4: `240.0.0.0/4`. Rust v4:
    `240.0.0.0/4` minus broadcast. `ipaddr.js` v4: seven documentation/benchmarking/IETF blocks
    *plus* `240/4`. R `ipaddress`: the IPv6 blocks outside RFC 4291 global unicast. IANA's actual
    `Reserved-by-Protocol` column is a fifth thing again — it is `True` for `127.0.0.0/8`,
    `169.254.0.0/16`, `::1/128` and `::ffff:0:0/96`, none of which any library calls "reserved".
    The word carries no portable meaning.

21. **CVE severity for classification bugs is itself contested.** CVE-2023-42282 is CVSS 9.8
    CRITICAL at NVD and **Low** in the GitHub Advisory Database. The gap drove the npm `ip`
    maintainer to archive the repository, which is why CVE-2024-29415 has **no fix and never
    will**. A classification library's threat model depends entirely on whether callers use it for
    access control — which the library cannot know, and which is precisely why `raddr` should
    report facts and decline to imply a verdict.

22. **The most-correct implementations are the ones that delegate.** Python `advocate` is the only
    SSRF guard in the survey with no hardcoded range table worth speaking of; it calls
    `ipaddress.is_global` and inherits every CPython registry update for free. Every library with
    a hand-maintained CIDR list in this document has shipped at least one staleness CVE. The
    lesson for `raddr` is that the vendored-registry approach in Epic H is not a nicety — it is
    the only structure that has not failed.
