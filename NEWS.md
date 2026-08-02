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
  `addr_pton()` and `addr_aton()`. Two precedence orderings over the reality
  primitives: `addr_getaddrinfo()` and `addr_curl()`.
* The reality dialects model **Apple**'s `inet_pton()` and `inet_aton()`
  specifically, not POSIX and BSD in the abstract. The same oracles were run
  under glibc 2.36 and musl 1.2.5 (`data-raw/oracle-libc-linux.sh`), and there
  is no reality-side reading all three libcs agree on: glibc and musl reject
  the leading zeros Apple reads as decimal, and reject the overflow Apple wraps
  modulo 2^32. `addr_getaddrinfo()` and `addr_curl()` are Apple readings across
  the whole of `fe80::/10`, where the scope lift they apply is Apple's alone.
  Four Linux fixtures are committed beside the Apple ones and asserted by
  `tests/testthat/test-libc.R`, so a libc upgrade changes a tracked file rather
  than passing quietly.
* Accessors read one field out of a parse without re-parsing: `addr_input()`,
  `addr_outcome()`, `addr_reading()`, `addr_codes()`, `addr_status()`, and
  `addr_is_divergent()` for the literals the dialects disagree about.
* `addr_codes_registry()` documents every reason code, each stating what it
  does and does not prove, and grades the classify codes by the force of the
  rule they report.

## The address type

* `raddr_address()` is a vctrs record vector holding IPv4 and IPv6 values, with
  `format()`, `as.character()`, comparison, equality, and combination methods.
* `addr_family()`, `addr_zone()`, `addr_expand()`, and `addr_format()` — the
  latter emitting RFC 5952 canonical text.
* raddr requires vctrs 0.7.0 or later. Earlier versions modify record vectors
  in place instead of returning a modified copy, which made the readings held
  in a parse depend on the order they were read in: `addr_reading(p, "curl")`
  returned `NA` and left `p` corrupted, so a later `addr_reading(p, "aton")`
  returned `NA` too for a literal it had read as an address before the first
  call. The answer is the version floor rather than a defensive copy, because
  vctrs 0.7.0 fixed the bug upstream and a workaround would outlive it.
* raddr requires rlang 1.1.7 or later. This adds no constraint in practice —
  vctrs 0.7.0 requires the same version — but it is declared rather than left
  to be inherited, so that no `Imports:` entry claims to work with any version
  while nothing checks it. Both floors are checked: `data-raw/check-dep-floor.sh`
  runs the full check against exactly these versions on R 4.0.0.

## Classification against the IANA registries

* `addr_classify()` returns a `raddr_class` record; `addr_category()`,
  `addr_address_space()`, and `addr_registry()` read its fields. Registry rows
  that say nothing are reported as such rather than guessed at, and two
  different `N/A`s stay distinguishable.
* `addr_global_reachability()` is the two-layer positive fact behind the RFC
  6052 §3.1, RFC 3056 §9 and RFC 4380 §4 rules: IANA's `globally_reachable`
  column where the special-purpose layer answered, `category = "global"` where
  only the address-space layer did, and `NA` where neither settled it. A
  **fact, not a verdict** — the `NA` is a third answer rather than a missing
  one, and a policy layer must branch on all three. It takes a `raddr_address`,
  a `raddr_class` or a `raddr_embedding`, so the same question can be put to an
  outer address and to what it embeds.
* Bundled snapshots: the IANA special-purpose address registries
  (`2025-10-09`), the address-space pair (`2025-10-10`), the category map and
  the transition-mechanism table (`2026-07-27`). The two registry stamps are
  read from the page-level `Last Updated` field on IANA's own registry pages
  rather than from the `Last-Modified` header the CSV exports are served with,
  which is a site *deploy* timestamp: seven exports across four unrelated
  registries carry the identical second.
* `addr_registry_version()`, `addr_address_space_version()`,
  `addr_category_version()`, `addr_transition_version()`, and
  `addr_registry_outdated()` for checking snapshot age.
* `addr_registry_snapshot()` returns one content-addressed id for the whole
  vendored payload — a `sha256:` digest over a canonical manifest of the four
  source keys and their per-file checksums, in a fixed order. It is the value
  to quote in a bug report, since it pins the data independently of the package
  version. It deliberately says nothing about currency: a hash has no order.

## Containment, encoding, embeddings

* `addr_within()` and `addr_within_any()` test CIDR containment, including the
  longest-prefix-match carve-outs inside non-globally-reachable parents.
* Round-trip conversions: `addr_to_bytes()`, `addr_to_hex()`,
  `addr_to_binary()`, `addr_to_integer()` and their inverses.
* `addr_reverse_pointer()` builds `in-addr.arpa` and `ip6.arpa` names.
* `addr_embeddings()` and `addr_embedded_kind()` decode NAT64, Teredo, and
  6to4 embeddings. Both Teredo addresses are reported — the server in the clear
  and the bitwise-complemented client — because reducing the pair to one is the
  consumer's decision, not raddr's.
* `addr_nat64_embeddings()` reads the IPv4 address embedded under a
  **caller-supplied** RFC 6052 Network-Specific Prefix. `addr_classify()` names
  NAT64 only from the two written-down prefixes and still does: an operator's
  own prefix is invisible to a prefix table, and nothing about this call
  changes what classification concludes. Because supplying a prefix is an
  assertion rather than a discovery, every row comes back as `nat64_nsp`, a
  `kind` classification can never emit. The reserved u-byte at bits 64-71
  splits the embedded octets at `/40`, `/48` and `/56`, so a contiguous 32-bit
  read from the prefix boundary returns a plausible wrong address — under a
  `/48`, `192.0.2.33` reads as `192.0.0.2`. Checked against RFC 6052 §2.4's own
  worked example at all six permitted lengths.

## Verification and docs

* The full web-platform-tests URL host corpus and the IANA registry corpus run
  on every check, including on CRAN — no snapshots, no `skip_on_cran()`.
* Three vignettes: `introduction`, `reason-codes`, and `edge-cases`, the last
  with every table computed at build time rather than transcribed.
* The design record is `docs/architecture.md`, and the reason-code table in it
  is checked against the registry in both directions on every run: no
  undocumented code, and no orphan entry left behind by a rename.

The API is not yet stable. Pure R, no network access at any point.
