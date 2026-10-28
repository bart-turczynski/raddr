# raddr 0.1.2.9000

* raddr now requires R >= 4.1.0, up from 4.0.0 (`SEOR-lavybtkr`).
* `oysteR` and `rosv` are new in `Suggests` (`SEOR-fftbjnpl`).
* `addr_registry_outdated()`'s help says what `TRUE` means; with the current snapshot it turns `TRUE` on 2026-10-10 (`RADD-poetjkbw`).
* `addr_global_reachability()`'s help lists all four blocks that answer `NA`, 6to4 and Teredo included.
* The documentation site moved to <https://bart-turczynski.gitlab.io/raddr/> (`SEOR-hcmtspmv`).
* New `vignette("why-raddr")` shows where IP address parsers disagree, with measured divergence tables.

# raddr 0.1.2

First published release. 0.1.0 and 0.1.1 were tagged during development, on
2026-07-31 and 2026-08-02, and neither was submitted anywhere; 0.1.2 supersedes
both and is the version to install. Everything in the notes below is present
here.

* `URL:` and `BugReports:` name the GitLab repository. They previously named a GitHub account that no longer exists, so both fields resolved to 404.
* The reason-code table's `since` column reads `0.1.2`, the first obtainable release; exports, the six dialects and the reason codes are otherwise identical to 0.1.1.

# raddr 0.1.1

Tagged during development on 2026-08-02 and never submitted anywhere.
Everything in the 0.1.0 notes below is present here. The difference from 0.1.0
is two dependency floors that the 0.1.0 tag predates, one of which fixes a
silent correctness bug.

* raddr requires vctrs 0.7.0 or later. Earlier versions modify record vectors in place, so `addr_reading(p, "curl")` returned `NA` and corrupted `p` for later readings such as `"aton"`.
* raddr requires rlang 1.1.7 or later. This adds no constraint in practice, since vctrs 0.7.0 requires the same version.

# raddr 0.1.0

Tagged during development and never published. `addr_parse()` takes no mode
argument: it reports what an IP address literal means under every supported
dialect at once, with the reason codes that explain each reading, and never
collapses disagreeing sources into a single answer.

## Parsing

* `addr_parse()` returns a `raddr_parse` record carrying the input, the reading each dialect arrived at, the per-dialect outcome, and the reason codes.
* Six dialects. On paper: `addr_strict()` (RFC dotted-quad and RFC 4291 IPv6 text) and `addr_whatwg()` (WHATWG URL host parser). In reality: `addr_pton()`, `addr_aton()`, and the precedence orderings `addr_getaddrinfo()` and `addr_curl()`.
* The reality dialects model **Apple**'s `inet_pton()` and `inet_aton()`, not POSIX: glibc and musl reject Apple's decimal leading zeros and modulo-2^32 wrap.
* `addr_getaddrinfo()` and `addr_curl()` apply Apple's scope lift across all of `fe80::/10`; glibc and musl don't.
* Accessors read one field out of a parse without re-parsing: `addr_input()`, `addr_outcome()`, `addr_reading()`, `addr_codes()`, `addr_status()`, and `addr_is_divergent()` for the literals the dialects disagree about.
* `addr_codes_registry()` documents every reason code, each stating what it does and does not prove, and grades the classify codes by the force of the rule they report.

## The address type

* `raddr_address()` is a vctrs record vector holding IPv4 and IPv6 values, with `format()`, `as.character()`, comparison, equality, and combination methods.
* `addr_family()`, `addr_zone()`, `addr_expand()`, and `addr_format()` — the latter emitting RFC 5952 canonical text.

## Classification against the IANA registries

* `addr_classify()` returns a `raddr_class` record; `addr_category()`, `addr_address_space()`, and `addr_registry()` read its fields. Registry rows that say nothing are reported as such rather than guessed at, and two different `N/A`s stay distinguishable.
* `addr_global_reachability()` answers from IANA's `globally_reachable` column, else `category = "global"`, else `NA`, for an address, class or embedding: a fact, not a verdict (RFC 6052 §3.1, RFC 3056 §9, RFC 4380 §4).
* Bundled snapshots: the IANA special-purpose address registries (`2025-10-09`), the address-space pair (`2025-10-10`), the category map and the transition-mechanism table (`2026-07-27`).
* `addr_registry_version()`, `addr_address_space_version()`, `addr_category_version()`, `addr_transition_version()`, and `addr_registry_outdated()` for checking snapshot age.
* `addr_registry_snapshot()` returns one `sha256:` id for the whole vendored payload, to quote in a bug report; it pins the data independently of the package version.

## Containment, encoding, embeddings

* `addr_within()` and `addr_within_any()` test CIDR containment, including the longest-prefix-match carve-outs inside non-globally-reachable parents.
* Round-trip conversions: `addr_to_bytes()`, `addr_to_hex()`, `addr_to_binary()`, `addr_to_integer()` and their inverses.
* `addr_reverse_pointer()` builds `in-addr.arpa` and `ip6.arpa` names.
* `addr_embeddings()` and `addr_embedded_kind()` decode NAT64, Teredo, and 6to4 embeddings. Both Teredo addresses are reported: the server in the clear and the bitwise-complemented client.
* `addr_nat64_embeddings()` reads the IPv4 address embedded under a caller-supplied RFC 6052 Network-Specific Prefix, skipping the reserved u-byte at bits 64-71; every row comes back as `nat64_nsp`.

## Documentation

* Three vignettes: `introduction`, `reason-codes`, and `edge-cases`, the last with every table computed at build time rather than transcribed.

The API is not yet stable. Pure R, no network access at any point.
