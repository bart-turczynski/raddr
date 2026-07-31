# raddr (development version)

## Bug fixes

* `addr_pton()`, `addr_strict()` and `addr_whatwg()` **accepted an IPv6 literal
  with a trailing newline and returned a different address than the literal
  named**, with no reason code. `addr_pton("1:2:3:4:5:6:7:8\n")` came back as
  `1:2:3:4:5:6:8000:0`, `"::1\n"` as `"::8000:0"`. All such literals are now
  rejected with `bad_hextet`.
* Two faults stacked. The hextet validator was, at the time, the only anchored
  pattern in the package running under `perl = TRUE`, and PCRE's `$` matches
  *before* a trailing newline where R's default TRE engine anchors at end of
  string — so
  `"8\n"` passed as a hextet. It is anchored with `\z` now. Behind it,
  `strtoi()` returned `NA` for the same piece and nothing checked the result,
  so the `NA_integer_` bit pattern was read back as the unsigned word
  `0x80000000` — which is where every wrong answer got its `8000`. The
  conversion is now reconciled with the validator, so a future miss is a
  rejection rather than a wrong address. IPv4 was never affected: its
  equivalent scan uses an unanchored negated class.

* `addr_address_space_version()` **reported a date IANA does not claim**. Both
  registry stamps were built from the `Last-Modified` header the CSV exports are
  served with, which is a site *deploy* timestamp rather than an editorial one —
  seven exports across four unrelated IANA registries carry the identical second.
  The stamps are now read from the page-level `Last Updated` field on IANA's own
  registry pages. `addr_registry_version()` is unchanged at `2025-10-09`, where
  the header happened to match; `addr_address_space_version()` moves
  **`2025-10-09` to `2025-10-10`**, because those two registries were edited on
  `2025-10-10` and `2025-10-23` after being deployed on `2025-10-09` and
  `2025-10-11`. Vendoring the address-space pair is what turned this from a
  documented caveat into a wrong number. No classification result changes: the
  four vendored CSVs are byte-identical.

## New features

* `addr_global_reachability()` exports the two-layer positive fact raddr
  already used internally to decide the antecedent of RFC 6052 §3.1, RFC 3056
  §9 and RFC 4380 §4: IANA's `globally_reachable` column where the
  special-purpose layer answered, `category = "global"` where only the
  address-space layer did, and `NA` where neither settled it. It is a **fact,
  not a verdict**, and the `NA` is a third answer rather than a missing one —
  today `192.88.99.0/24` and its 6to4 image. It takes a `raddr_address`, a
  `raddr_class` or a `raddr_embedding`, so the same question can be asked of an
  outer address and of what it embeds. Previously a policy layer had no
  sanctioned route to this fact and would have had to rebuild it from
  `category`, which is exactly the deny-list `addr_category()` warns against.

* `addr_nat64_embeddings()` reads the IPv4 address embedded under a
  **caller-supplied** RFC 6052 Network-Specific Prefix. `addr_classify()` names
  NAT64 only from the two written-down prefixes and still does: an operator's
  own prefix is invisible to a prefix table, and nothing about this call
  changes what classification concludes. Because supplying a prefix is an
  assertion rather than a discovery, every row comes back as `nat64_nsp`, a
  `kind` classification can never emit. The reserved u-byte at bits 64-71
  splits the embedded octets at `/40`, `/48` and `/56`, so a contiguous 32-bit
  read from the prefix boundary returns a plausible wrong address — under a
  `/48`, `192.0.2.33` reads as `192.0.0.2`. That splice is the reason this
  belongs in raddr rather than in each consumer. Checked against RFC 6052
  §2.4's own worked example at all six permitted lengths.

* `addr_registry_snapshot()` returns one content-addressed id for the whole
  vendored payload — a `sha256:` digest over a canonical manifest of the four
  source keys and their per-file checksums, in a fixed order. It is the value to
  quote in a bug report, since it pins the data independently of the package
  version. It deliberately says nothing about currency: a hash has no order, and
  the two editorial stamps stay separate because they describe separate tables.

## Performance

* The eleven remaining regex patterns on the address-parse path now run under
  `perl = TRUE`. `addr_strict()` is **10% faster on IPv6** (3.55 s to 3.18 s per
  1e6) and **7% faster on IPv4** (1.47 s to 1.35 s), `addr_pton()` 8% faster on
  IPv6, and the internal WHATWG "ends in a number" gate is **1.8x** (0.57 s to
  0.32 s). `addr_whatwg()`, `addr_aton()` and IPv4 `addr_pton()` are unchanged,
  because the one migrated site on their path is the leading-zero rejection and
  `addr_strict()` is the only dialect that rejects leading zeros.
* The IPv6 hextet validator is a negated character scan plus a width rather than
  an anchored regex over every piece — 0.363 s to **0.214 s** on the 8e6 pieces
  `addr_pton()` splits per 1e6 addresses. With the engine change above,
  `addr_strict()` on IPv6 is **18% faster** overall (3.55 s to 2.91 s) and
  `addr_pton()` 23%. Both dialects keep the bound they had: the strict rules
  bound the raw width of a hextet, Apple's bound the significant digits, so
  `0000000000000000` is still a legal zero and `00001` is still one digit to
  `addr_pton()` and one too many to `addr_strict()`.
* Answers are unchanged: 1091 adversarial literals compared across all seven
  entry points, `addr_codes()`, `ends_in_a_number()` and both `integer_to_addr()`
  families, with **no row moving**. That is not a free swap. PCRE differs from
  TRE twice — `$` also matches before a trailing newline, and `.` does *not*
  match one — so eight anchors became `\z` and the two greedy runs to a final
  separator took `(?s)`. Bolting `perl = TRUE` on without those rewrites moves
  122 of the same rows, which is what the new `tests/testthat/test-regex-engine.R`
  exists to prevent.
* `addr_classify()` is **15.7x faster on IPv6** — 0.88 s per 1e6 addresses,
  down from 13.9 s. `extract_embeddings()` scattered its result back to one
  element per address by chopping into a `vctrs` slice per address, so it asked
  for a million slices of a nested record to deliver as few as nineteen. It now
  chops only the groups that have rows. Answers are unchanged, `identical()` on
  both a hand-built corner corpus and 1e6 random rows.
* That cost was flat in the number of embeddings and linear in the vector
  length, so it was invisible in a total and only showed up in
  `bench/classify.R`'s decomposition (`docs/architecture.md` §11.1.7). IPv4 is
  unaffected: it returns before the scatter, having no transition formats.

## Documentation

* The reality dialects are now documented as modeling **Apple** `inet_pton()`
  and `inet_aton()`, not POSIX and BSD. The same oracles were run under glibc
  2.36 and musl 1.2.5 (`data-raw/oracle-libc-linux.sh`, needs Docker), and there
  is no reality-side reading all three libcs agree on: glibc and musl reject the
  leading zeros Apple reads as decimal, and reject the overflow Apple wraps
  modulo 2^32. Behavior is unchanged — raddr modeled Apple before and still
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
