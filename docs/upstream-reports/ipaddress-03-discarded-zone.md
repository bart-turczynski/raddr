# DRAFT — not yet submitted

**Target:** https://github.com/davidchall/ipaddress/issues (new issue)
**raddr tracking issue:** RADD-exojkzzj (O16)
**Blocked on:** GitHub account suspension. Submit verbatim once lifted.
**Measured:** 2026-07-30, macOS 25.4.0 arm64, R 4.6.0, ipaddress 1.0.3.

---

## Title

IPv6 zone IDs are silently discarded: `fe80::1%lo0` and `fe80::1%en0` parse to the same value and compare equal

## Body

### Summary

`ip_address()` accepts an IPv6 zone ID (RFC 4007 scope identifier, the `%iface`
suffix) and silently drops it. The zone is not stored, no accessor recovers it,
and no warning is emitted. Two addresses that differ only by interface therefore
become indistinguishable.

### Reproducer

```r
library(ipaddress)

as.character(ip_address("fe80::1%lo0"))
#> [1] "fe80::1"
as.character(ip_address("fe80::1%en0"))
#> [1] "fe80::1"

ip_address("fe80::1%lo0") == ip_address("fe80::1%en0")
#> [1] TRUE          # different interfaces, same value

# nothing in the package recovers it
grep("zone|scope", ls(asNamespace("ipaddress")), value = TRUE, ignore.case = TRUE)
#> character(0)
```

### Malformed zone syntax is accepted too

Because the input is truncated at the first `%` rather than validated, several
strings that are not well-formed addresses are accepted and silently become
`fe80::1`:

```r
for (s in c("fe80::1%lo0", "fe80::1%", "fe80::1%%",
            "fe80::1%lo0%en0%wat", "fe80::1%999", "fe80::1%nonexistent-if")) {
  x <- ip_address(s)
  cat(sprintf("%-24s -> %-10s is.na=%s\n", s, as.character(x), is.na(x)))
}
#> fe80::1%lo0              -> fe80::1    is.na=FALSE
#> fe80::1%                 -> fe80::1    is.na=FALSE
#> fe80::1%%                -> fe80::1    is.na=FALSE
#> fe80::1%lo0%en0%wat      -> fe80::1    is.na=FALSE
#> fe80::1%999              -> fe80::1    is.na=FALSE
#> fe80::1%nonexistent-if   -> fe80::1    is.na=FALSE
```

Two of these are rejected by the platform resolver. On this machine (macOS
25.4.0, Apple libc, arm64) `inet_pton(AF_INET6, ...)`:

| Input | Apple `inet_pton` | `ipaddress` 1.0.3 |
|---|---|---|
| `fe80::1%lo0` | accept | accept |
| `fe80::1%` | accept | accept |
| `fe80::1%999` | accept | accept |
| `fe80::1%nonexistent-if` | accept | accept |
| `fe80::1%%` | **reject** | accept |
| `fe80::1%lo0%en0%wat` | **reject** | accept |

So the multi-`%` forms are accepted by `ipaddress` and rejected by the platform.
I have only measured Apple's libc here and am not claiming this row-for-row for
glibc or musl — the point is narrow: truncating at the first `%` admits strings
that at least one production resolver refuses.

### Why this matters

A link-local address without its zone is not actionable. `fe80::/10` is
per-interface by construction, so `fe80::1` on `lo0` and `fe80::1` on `en0` are
different destinations; collapsing them to one value loses the only thing that
disambiguates them. Combined with the silent acceptance above, code that reads
user- or config-supplied addresses gets a value that looks clean, compares equal
to a different host, and carries no signal that information was dropped.

### Possible directions

Listing options rather than prescribing, since this touches the storage layout:

1. **Reject** — treat a zone as a parse error and return `NA` with a warning.
   Cheapest, and honest, but breaks anyone currently relying on the truncation.
2. **Preserve** — store the zone alongside the address and expose it
   (`zone_id()` or similar), include it in equality, and render it in
   `as.character()`. Most useful, largest change; note it also has to decide
   whether `fe80::1%lo0 == fe80::1` is `FALSE` (probably) and how a zone
   interacts with network containment.
3. **Warn and drop** — keep today's value but emit a warning so the loss is at
   least visible. A stopgap, not a fix.

Even without choosing, validating the zone syntax rather than truncating at the
first `%` would close the malformed-input rows above.

### Context

Found while building [raddr](https://github.com/bart-turczynski/raddr), an
offline IP parsing/classification package. Third report from the same
cross-implementation comparison, alongside the `0x80000000` equality issue and
the NAT64 gap. Related: CPython's `ipaddress` has a different zone defect —
`IPv6Address('fe80::1%lo0').exploded` raises `AddressValueError` — which is being
reported separately upstream; noting it only as evidence that zone handling is a
common blind spot rather than an exotic requirement.

---

## Notes to self (not part of the submission)

- **The `inet_pton` claim in RADD-exojkzzj needed narrowing.** The issue said
  truncating at the first `%` "also accepts rows Apple's inet_pton rejects",
  which reads as though the zone forms generally get rejected. Measured: Apple's
  `inet_pton` **accepts** `%lo0`, `%`, `%999` and `%nonexistent-if`, and rejects
  only `%%` and `%lo0%en0%wat`. The issue's own example is one of the two real
  ones, so the claim survives — but only for multi-`%` forms, and the draft says
  exactly that.
- Also checked `getaddrinfo`, which accepts all three of `%lo0`,
  `%nonexistent-if` and `%999` — so "the resolver validates the interface name"
  is not a claim I can make either. Left it out.
- Scoped the platform claim to Apple libc / this machine explicitly, rather than
  generalising across libcs.
- Added the `==` consequence (`fe80::1%lo0 == fe80::1%en0` → `TRUE`), which the
  issue did not state and which is the most legible harm.
- Offered three directions instead of one, because option 2 has real design
  consequences (equality, containment, storage) that are the maintainer's call.
