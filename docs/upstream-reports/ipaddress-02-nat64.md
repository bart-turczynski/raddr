# DRAFT — not yet submitted

**Target:** https://github.com/davidchall/ipaddress/issues (new issue)
**raddr tracking issue:** RADD-pyinlkit (O11a)
**Blocked on:** GitHub account suspension. Submit verbatim once lifted.
**Measured:** 2026-07-30, macOS 25.4.0 arm64, R 4.6.0, ipaddress 1.0.3.

---

## Title

No NAT64 support: `64:ff9b::/96` and `64:ff9b:1::/48` have no predicate or extractor, and `is_global()` is wrong for the RFC 8215 prefix

## Body

### Summary

Two related gaps around the IPv4/IPv6 translation prefixes:

1. **Missing API.** There is no `is_nat64()` / `extract_nat64()`, so NAT64
   addresses cannot be recognised and the embedded IPv4 address cannot be
   recovered — even though the package already ships exactly this API shape for
   three *other* embedding schemes.
2. **A concrete classification error.** `is_global()` returns `TRUE` for
   `64:ff9b:1::/48`, but IANA's IPv6 Special-Purpose Address Registry records
   that block as **Globally Reachable = False**. Python's `ipaddress` returns
   `False` for the same address.

The second is the part that is straightforwardly a bug rather than a feature
request.

### 1. The missing member of an existing family

`ipaddress` 1.0.3 already provides a predicate-plus-extractor pair for every
other IPv4-in-IPv6 embedding it knows about:

| Scheme | Predicate | Extractor |
|---|---|---|
| IPv4-mapped | `is_ipv4_mapped()` | `extract_ipv4_mapped()` |
| 6to4 | `is_6to4()` | `extract_6to4()` |
| Teredo | `is_teredo()` | `extract_teredo_server()`, `extract_teredo_client()` |
| **NAT64** | **—** | **—** |

Both existing extractors work as you would expect:

```r
library(ipaddress)
extract_6to4(ip_address("2002:0102:0304::"))        #> "1.2.3.4"
extract_ipv4_mapped(ip_address("::ffff:1.2.3.4"))   #> "1.2.3.4"

any(grepl("nat64", getNamespaceExports("ipaddress"), ignore.case = TRUE))
#> [1] FALSE
```

The two blocks in question are registered in IANA's IPv6 Special-Purpose Address
Registry as "IPv4-IPv6 Translat.":

- `64:ff9b::/96` — RFC 6052, the Well-Known Prefix, allocated 2010-10
- `64:ff9b:1::/48` — RFC 8215, local-use translation, allocated 2017-06

An `extract_nat64()` for `64:ff9b::/96` is the simple case: the embedded IPv4
address is the low 32 bits. (RFC 6052 §2.2 also defines embeddings for /32, /40,
/48, /56 and /64 prefixes, where the octets are split around the `u` byte; if
that generality is unwanted, handling only the /96 Well-Known Prefix would still
cover the common deployment.)

### 2. `is_global()` is wrong for `64:ff9b:1::/48`

```r
library(ipaddress)
for (s in c("64:ff9b::1.2.3.4", "64:ff9b:1::1.2.3.4")) {
  x <- ip_address(s)
  cat(sprintf("%-20s is_global=%-6s is_reserved=%s\n", s, is_global(x), is_reserved(x)))
}
#> 64:ff9b::1.2.3.4     is_global=TRUE   is_reserved=TRUE
#> 64:ff9b:1::1.2.3.4   is_global=TRUE   is_reserved=TRUE
```

IANA's registry rows for the two blocks differ in exactly this field:

| Block | Source | Destination | Forwardable | **Globally Reachable** | Reserved-by-Protocol |
|---|---|---|---|---|---|
| `64:ff9b::/96` | True | True | True | **True** | False |
| `64:ff9b:1::/48` | True | True | True | **False** | False |

So `TRUE` is right for `64:ff9b::/96` and wrong for `64:ff9b:1::/48`. Python's
`ipaddress` module distinguishes them correctly:

```python
>>> import ipaddress
>>> ipaddress.IPv6Address('64:ff9b::1.2.3.4').is_global
True
>>> ipaddress.IPv6Address('64:ff9b:1::1.2.3.4').is_global
False
```

That looks like `64:ff9b:1::/48` simply being absent from whatever table backs
`is_global()`, so the address falls through to a default of "global". Adding the
row would fix it independently of anything in part 1.

### Why this matters

NAT64 traffic is the case where an IPv6-only client reaches IPv4 hosts, so
`64:ff9b::/96` addresses routinely carry an embedded IPv4 address that is the
actual endpoint. Two consequences:

- Without an extractor, callers hand-roll the low-32-bit slice, and hand-rolled
  versions tend to get `64:ff9b:1::/48` wrong (different prefix length, so a
  different embedding offset).
- The `is_global()` error points the wrong way for anything using it as a
  reachability or filtering signal: a local-use translation prefix is reported as
  globally reachable.

### Context

Found while building [raddr](https://github.com/bart-turczynski/raddr), an
offline IP parsing/classification package with registry-backed classification.
The IANA field values quoted above were read from raddr's vendored copy of the
registry rather than restated from memory, and the Python comparison is included
because agreement between two independent implementations is worth more than
either one alone.

Filed alongside two other reports from the same comparison (equality on
`0x80000000` words; discarded IPv6 zone IDs).

---

## Notes to self (not part of the submission)

- **The `is_global()` error is new** — RADD-pyinlkit described only the missing
  predicate/extractor. Verified two ways per the "check normative claims at the
  source" rule: against the vendored IANA CSV
  (`inst/extdata/iana-ipv6-special-registry.csv`, the two `ff9b` rows) and
  against Python's `ipaddress`, which gets it right. This turns a feature
  request into a feature request *plus* a bug, which is far more likely to move.
- **Reframed part 1 substantially.** "ipaddress has no NAT64 support" is weak on
  its own. Measured that the package already has `is_6to4`/`extract_6to4`,
  `is_teredo`/`extract_teredo_*` and `is_ipv4_mapped`/`extract_ipv4_mapped` — so
  NAT64 is the one missing member of a family that otherwise exists three times
  over. That is the argument.
- **Deliberately avoided RFC 2119 language.** RFC 8215 does not invoke RFC 2119
  for this, so the draft says "registered in IANA's registry with Globally
  Reachable = False" rather than claiming a MUST. Same care as the earlier
  RFC 4291 correction.
- Mentioned RFC 6052 §2.2's non-/96 embeddings as optional scope so the
  maintainer is not blindsided later, while making clear /96-only would be
  useful.
- `is_reserved = TRUE` for both blocks in *both* R and Python; left it alone
  rather than guessing at `is_reserved`'s intended semantics.
