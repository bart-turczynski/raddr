# Hard-case parser conformance across peer libraries

Measured 2026-07-31 by `data-raw/peer-conformance.R`. This is a
**conformance comparison, not a speed benchmark**. It runs every unique
non-missing literal from the committed fixture, boundary, and generated
adversarial corpora, normalizes accepted addresses, and keeps zone IDs in a
separate field where the peer exposes one.

The rule for a "perfect" answer is not majority vote. A result is triaged
against the contract the implementation claims:

- RFC-style address text is compared with raddr `strict`, Python
  `ipaddress`, Go `net/netip`, Rust `std::net`, and the textual grammar in
  [RFC 4291 §2.2](https://datatracker.ietf.org/doc/html/rfc4291#section-2.2).
- A reading outside that grammar is compared with every named raddr dialect.
  If it matches `pton`, `aton`, WHATWG, or a composition, it is a different
  contract rather than a vote against `strict`.
- Zone handling is judged separately from the address bits. Accept-and-keep,
  reject, and accept-and-discard are three materially different answers.

## Reproduce

From the package root:

```sh
Rscript data-raw/peer-conformance.R
```

The command writes the complete 2,063-row result to
`_scratch/peer-conformance.csv` and stops on any untriaged canonical
divergence. The committed helpers use a NUL-delimited wire format so spaces,
tabs, line breaks, and empty strings reach Python, Go, and Rust unchanged.

Run environment:

| implementation | version |
|---|---|
| R | 4.6.0 |
| raddr | 0.1.0.9000 |
| R `ipaddress` | 1.0.3 |
| R `iptools` | 0.7.2 |
| Python `ipaddress` | CPython 3.14.6 |
| Go `net/netip` | go1.26.5 darwin/arm64 |
| Rust `std::net` | rustc 1.91.1 |
| R `IP` | 0.1.6 source; not runnable on this R version |

The source corpus has 2,139 rows, 2,063 unique non-missing literals, and one
missing-value contract row. Deduplication removes repeated evidence, not a
case: every distinct string is still executed.

## Canonical libraries

| parser | accepted | zone-free divergences from raddr `strict` | accepted zoned rows |
|---|---:|---:|---:|
| raddr `strict` | 659 | — | 0 |
| Python `ipaddress` | 685 | **0** | 26 |
| Go `net/netip` | 688 | **0** | 29 |
| Rust `std::net::IpAddr` | 659 | **0** | 0 |

This settles the core grammar: **raddr `strict` is unchanged.** Rust agrees on
all 2,063 rows. Python and Go agree on every zone-free row; their additional
acceptances are zone extensions, not alternative IPv4 or IPv6 address bits.
Python documents four decimal IPv4 integers with no leading zeros and a
non-empty `%scope_id` that may not contain another `%`.
[Go's parser tests](https://go.dev/src/net/netip/netip_test.go) explicitly
reject leading-zero IPv4 octets, while
[`ParseAddr`](https://pkg.go.dev/net/netip) accepts an IPv6 zone. Rust documents
decimal dotted quad with no octal or hexadecimal notation and has no zone slot
on `Ipv6Addr`.

The three extra Go rows are `fe80::1%lo0%en0`, `fe80::1%lo0%x`, and
`fe80::1%%`. Go treats everything after the first `%` as the zone string.
Python rejects them because its documented zone grammar forbids `%`. Neither
answer changes raddr: `strict` follows RFC 4291 and rejects every zone, while
the reality dialects store one zone separately and reject a second marker.

The Python helper expands from `.packed`, not `.exploded`.
`IPv6Address("fe80::1%lo0").exploded` still raises on Python 3.14.6; that known
accessor defect must not be misreported as a parser rejection.

## R peers

R `ipaddress` and `iptools` produced identical normalized answers on every
row. Both link to AsioHeaders, so the shared behavior is consistent with a
shared Asio parser; that mechanism is an inference, while the equality is
measured.

| triage | rows | representative input | decision |
|---|---:|---|---|
| agrees with `strict` | 1,667 | `127.0.0.1`, `1.2.3.`, `4294967296` | correct for the shared accept/reject result |
| matches `pton` + its compositions | 249 | `192.0.048.1`, `00001::` | a reality grammar, not strict |
| matches only `pton` | 31 | over-wide zero-padded IPv6 hextets | a reality grammar, not strict |
| matches `pton` + `getaddrinfo` | 7 | `0177.0.0.1`, `192.0.010.1` | decimal leading zeros, not RFC-style text |
| matches every lenient raddr dialect | 2 | extremely wide zero-padded IPv4 parts | a non-strict reading |
| accepts and discards one zone | 83 | `fe80::1%lo0` | lossy; not a perfect address value |
| truncates at first `%` | 24 | `fe80::1%lo0%en0`, `fe80::1%%` | lossy and over-permissive |

Both R peers accept 1,055 rows: all 659 accepted by `strict`, plus 396
additional rows. Of those additions, 289 are fully explained by an existing
raddr reality dialect. The remaining 107 are zone-bearing inputs: 83 lose one
zone and 24 discard everything from the first `%` onward, including a second
zone marker and any following junk.

This explains the headline examples:

| input | raddr `strict` | R `ipaddress` / `iptools` | triage |
|---|---|---|---|
| `0177.0.0.1` | reject | `177.0.0.1` | Apple-`pton`-style decimal leading zeros |
| `::ffff:1.2.3.04` | reject | `::ffff:102:304` | Apple-`pton`-style dotted tail |
| `00001::` | reject | `1::` | significant-width rather than raw-width limit |
| `fe80::1%lo0` | reject | `fe80::1` | zone accepted and discarded |
| `fe80::1%lo0%en0` | reject | `fe80::1` | truncated at first `%` |

The R `ipaddress` manual says `ip_address()` accepts dot-decimal IPv4 or
hexadecimal IPv6 and replaces invalid input with `NA`; it does not document the
leading-zero, over-wide-hextet, or zone-truncation grammar. `iptools` documents
that `ip_to_numeric()` returns numeric zero for either an invalid input or an
IPv6 address. The probe therefore uses `ip_classify()` before conversion:
`ip_to_numeric()` alone cannot distinguish rejection from the valid address
`0.0.0.0`.

R `IP` 0.1.6 could not be measured on R 4.6.0. Its final CRAN source fails to
compile before parsing because `Rf_findVarInFrame` is no longer declared in
the public R headers. The result is recorded as **not runnable**, not patched
and not guessed from documentation.

## Settled answers

1. Keep `addr_strict()` as the RFC-style, zone-free grammar. The full
   cross-language corpus found no defect.
2. Keep Python/Go zone acceptance out of `strict`; it is an extension supported
   by their data models. Keep zones in raddr's reality dialects, where raddr
   has a field that can preserve them.
3. Do not imitate the R peers' unnamed leniency. Their non-zone readings are
   already expressible as `addr_pton()`-family answers, and their zone behavior
   loses information.
4. Never use `iptools::ip_to_numeric()` as a validity oracle. Its documented
   zero sentinel collides with a valid address.
5. Treat `IP` as unavailable on this runtime until an unmodified release
   builds; a locally patched peer is not canonical evidence.
