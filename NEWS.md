# raddr (development version)

## Documentation

* The reality dialects are now documented as modelling **Apple** `inet_pton()`
  and `inet_aton()`, not POSIX and BSD. The same oracles were run under glibc
  2.36 and musl 1.2.5 (`data-raw/oracle-libc-linux.sh`, needs Docker), and there
  is no reality-side reading all three libcs agree on: glibc and musl reject the
  leading zeros Apple reads as decimal, and reject the overflow Apple wraps
  modulo 2^32. Behavior is unchanged — raddr modelled Apple before and still
  does, because a dialect that varied with the host would not be a function.
* `addr_getaddrinfo()` and `addr_curl()` are Apple readings across the whole of
  `fe80::/10`: the scope lift they apply there is Apple's alone, and glibc and
  musl do not perform it. Previously documented as a boundary detail.
* Retracted an unmeasured claim that glibc's `inet_aton()` "ignores trailing
  garbage" where Apple and musl reject it. Measured, glibc matches Apple exactly
  and **musl** is the outlier, refusing even a bare trailing space.
* Four Linux fixtures are committed beside the Apple ones and asserted by
  `tests/testthat/test-libc.R`, so a libc upgrade changes a tracked file rather
  than passing quietly.

# raddr 0.1.0

First release. `addr_parse()` takes no mode argument: it reports what an IP
address literal means under every supported dialect at once, with the reason
codes that explain each reading, and never collapses disagreeing sources into a
single answer.

## Parsing

* `addr_parse()` returns a `raddr_parse` record carrying the input, the reading
  each dialect arrived at, the per-dialect outcome, and the reason codes.
* Six dialects, on two axes. On paper: `addr_strict()` (RFC dotted-quad and
  RFC 4291 IPv6 text) and `addr_whatwg()` (WHATWG URL host parser). In reality:
  `addr_pton()` (POSIX `inet_pton`) and `addr_aton()` (BSD `inet_aton`). Two
  precedence orderings over the reality primitives: `addr_getaddrinfo()` and
  `addr_curl()`.
* Accessors read one field out of a parse without re-parsing: `addr_input()`,
  `addr_outcome()`, `addr_reading()`, `addr_codes()`, `addr_status()`, and
  `addr_is_divergent()` for the literals the dialects disagree about.
* `addr_codes_registry()` documents all 23 reason codes, each stating what it
  does and does not prove.

## The address type

* `raddr_address()` is a vctrs record vector holding IPv4 and IPv6 values, with
  `format()`, `as.character()`, comparison, equality, and combination methods.
* `addr_family()`, `addr_zone()`, `addr_expand()`, and `addr_format()` — the
  latter emitting RFC 5952 canonical text.

## Classification against the IANA registries

* `addr_classify()` returns a `raddr_class` record; `addr_category()`,
  `addr_address_space()`, and `addr_registry()` read its fields. Registry rows
  that say nothing are reported as such rather than guessed at, and two
  different `N/A`s stay distinguishable.
* Bundled snapshots: IANA special-purpose address registries (2025-10-09),
  the category map and transition-mechanism table (2026-07-27).
* `addr_registry_version()`, `addr_address_space_version()`,
  `addr_category_version()`, `addr_transition_version()`, and
  `addr_registry_outdated()` for checking snapshot age.

## Containment, encoding, embeddings

* `addr_within()` and `addr_within_any()` test CIDR containment, including the
  longest-prefix-match carve-outs inside non-globally-reachable parents.
* Round-trip conversions: `addr_to_bytes()`, `addr_to_hex()`,
  `addr_to_binary()`, `addr_to_integer()` and their inverses.
* `addr_reverse_pointer()` builds `in-addr.arpa` and `ip6.arpa` names.
* `addr_embeddings()` and `addr_embedded_kind()` decode NAT64, Teredo, and
  6to4 embeddings.

## Verification and docs

* The full web-platform-tests URL host corpus and the IANA registry corpus run
  on every check, including on CRAN — no snapshots, no `skip_on_cran()`.
* Three vignettes: `introduction`, `reason-codes`, and `edge-cases`, the last
  with every table computed at build time rather than transcribed.

The API is not yet stable. Pure R, no network access at any point.
