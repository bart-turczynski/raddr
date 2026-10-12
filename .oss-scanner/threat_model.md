# raddr threat model

## What this project does and where untrusted input enters

raddr is a pure-R package (no `src/`, no compiled code, no network access). It
reports what an IP address literal means under each standard and implementation
that disagrees about it, and classifies the parsed value against bundled
snapshots of the IANA special-purpose and address-space registries. It returns
facts and reason codes, never an allow/deny verdict. `rurl` and the SSRF guard
`ssrfr` import it, and `ssrfr` builds its policy on raddr's readings,
classifications and embeddings. A raddr error that turns a loopback, private or
metadata address into a "public" one is therefore an SSRF bypass in `ssrfr`.

Treat every address literal as attacker-controlled. It enters through:

- `addr_parse(x)`: the four primitive readings at once (`strict`, `whatwg`,
  `pton`, `aton`), with per-dialect outcomes and reason codes. The
  compositions below are not in it; call them directly.
- The six single-dialect parsers: `addr_strict()` (RFC dotted-quad, RFC 4291),
  `addr_whatwg()` (WHATWG URL host parser), `addr_pton()` and `addr_aton()`
  (Apple libc), and the compositions `addr_getaddrinfo()` (pton, then aton,
  behind a whitespace gate, plus the `fe80::/10` scope lift) and `addr_curl()`
  (aton, then getaddrinfo).
- The decoders `hex_to_addr()`, `binary_to_addr()`, `bytes_to_addr()` and
  `integer_to_addr()`, which take strings, raw vectors or numbers.
- Everything downstream of a parsed value: `addr_classify()`,
  `addr_category()`, `addr_embeddings()`, `addr_embedded_kind()`,
  `addr_global_reachability()`, `addr_within()` / `addr_within_any()`,
  `addr_format()`, `addr_expand()`, `addr_reverse_pointer()`.

Trusted: the calling R code and the arguments it chooses (the CIDR `blocks` of
`addr_within*()`, the caller's NAT64 `prefix`, `max_age`), and the bundled
registry data (`inst/extdata/*.csv`, compiled into `R/sysdata.rda` by
`data-raw/build-registry.R`). A registry entry that IANA changed after the
snapshot date is out of scope (`SECURITY.md`); a classification that
contradicts the bundled snapshot is in scope.

## Components that matter most / least

Most, in order:

- `R/ipv4.R`: the vectorized IPv4 number parser and its four rule sets (hex,
  octal, leading zeros, 1-4 parts, trailing dot, 2^32 wrap, stop at whitespace,
  digitless `0x`). Every rule is a claim about one standard or implementation.
- `R/ipv6.R`: hextet validation, `::` elision, the dotted-quad tail, zone IDs.
  PCRE anchors (`\z` against `$`, `(?s)`) have already produced one
  wrong-address defect here.
- `R/dialects.R`, `R/parse.R`: the compositions, the getaddrinfo whitespace gate
  (applied to the text before `%`), the `fe80::/10` scope lift, and the
  `raddr_parse` record and its status.
- `R/classify.R`, `R/registry.R`, `R/category.R`: longest-prefix match over the
  special-purpose layer with the address-space layer as fallback (multicast
  comes from the fallback), the five IANA policy columns, the classify codes.
- `R/embedding.R`, `R/transition.R`: IPv4 extracted from IPv4-mapped,
  -compatible and -translated addresses, 6to4, Teredo (both server and
  complemented client), NAT64 and ISATAP. A missed or wrong embedding hides an
  inner loopback or private address.
- `R/within.R`: CIDR containment; block parsing must refuse rather than
  silently match nothing.
- `R/address.R`: the record type. Words are signed integers, so `0x80000000`
  is `NA_integer_` as a bit pattern, not missingness; any code that treats it
  as missing misreads `128.0.0.0` or the AS112 prefix `2620:4f:8000::/48`.

Less: `R/format.R` (RFC 5952 text), `R/encoding.R`, `R/integer.R`,
`R/reverse.R`, `R/codes.R`. Still in scope, mostly for correctness and DoS.

Out of scope: `data-raw/` (maintainer-run oracles in Python, Go, Rust and
shell, never shipped), `bench/`, `docs/`, `scripts/`, `vignettes/`, and the
dependencies `vctrs` and `rlang` unless raddr uses them unsafely.
The vendored WPT corpus under `tests/testthat/fixtures/wpt/` is test data.

## How to exercise it

The image has the source at `/src`, raddr installed, every Import and Suggest
installed, gdb and valgrind installed, and no network at scan time. There is
no native code, so gdb and valgrind only help with a crash inside R itself:

- `R -d gdb --debugger-args='-batch -ex run -ex bt' -e 'library(raddr); addr_parse("0x7f.1")'`
- `R -d valgrind -e 'library(raddr); addr_parse("0x7f.1")'`

The rest:

- Full suite: `Rscript -e 'testthat::test_local("/src")'`. The OSS Index and
  OSV audits (`test-security.R`, `test-osv.R`) skip offline; that is expected.
  The image build has network, so its own smoke test leaves those two files
  out.
- The four primitive readings of each literal:
  `Rscript -e 'library(raddr); addr_parse(c("0177.0.0.1", "0x7f.1", "::ffff:127.0.0.1", "fe80:abcd::1"))'`
- The compositions, which `addr_parse()` does not run:
  `Rscript -e 'library(raddr); x <- c("0177.0.0.1", "127.1 junk", "fe80:abcd::1"); print(addr_getaddrinfo(x)); print(addr_curl(x))'`
- Classification of one reading, with every column:
  `Rscript -e 'library(raddr); as.data.frame(addr_classify(addr_whatwg("0x7f.1")))'`
- Embedded addresses, the three-valued reachability fact of the outer block,
  and the codes that judge the inner address:
  `Rscript -e 'library(raddr); a <- addr_strict(c("2002:7f00:1::1", "64:ff9b::7f00:1")); print(addr_embeddings(a)); print(addr_global_reachability(a)); print(as.data.frame(addr_classify(a))[c("globally_reachable", "codes")])'`
- Containment:
  `Rscript -e 'library(raddr); addr_within_any(addr_aton("2130706433"), c("127.0.0.0/8", "::1/128"))'`
- Corpora worth reusing, all under `tests/testthat/fixtures/`:
  `ipv4-oracle.csv` and `ipv6-oracle.csv` (Apple libc and curl, measured),
  `ipv4-libc-glibc.csv` / `-musl.csv` and the IPv6 pair, `zone-native-*.csv`,
  `wpt-hosts.csv` (derived from the pinned WPT `urltestdata.json`) and
  `raddr_extra_urltestdata.json`. `tests/testthat/helper-slow.R` holds naive
  second implementations useful as differential oracles.

## How you rate severity

raddr has no native code, so memory-safety classes do not arise from its own
sources. The rubric:

- **Critical**: a reading or classification error through which `ssrfr`'s
  default policy would admit a loopback (`127.0.0.0/8`, `::1`, and their
  embedded forms) or cloud-metadata address (`169.254.169.254`,
  `fd00:ec2::254`): for example `addr_classify()` reporting
  `globally_reachable = TRUE` for an address the bundled snapshot marks
  otherwise, or an embedding of `127.0.0.1` that `addr_embeddings()` does not
  report.
- **High**: the same kind of error reaching private, link-local, multicast or
  other non-global ranges; a dialect reading that differs from the standard or
  implementation it names (an `addr_whatwg()` result a WHATWG-conformant parser
  would not produce, an `addr_pton()` / `addr_aton()` result the recorded Apple
  oracle contradicts), so a caller checks one host and connects to another;
  `addr_within_any()` answering `FALSE` for an address inside a block, or
  accepting a malformed block instead of raising `raddr_error_block`; a
  decoder (`hex_to_addr()` and siblings) returning a different address than
  its input encodes.
- **Medium**: denial of service from small input: time or memory superlinear in
  the length of one literal or of the vector, catastrophic regex backtracking,
  or a crash of the R process (a segfault, not an R error).
- **Low**: wrong results with no security consequence: a wrong or missing
  reason code, non-canonical RFC 5952 text, a wrong reverse-pointer name, other
  standards nonconformance; anything that needs the caller to pass a hostile
  `blocks`, `prefix` or other trusted argument.

## Anything to leave alone

These are documented design choices (`docs/architecture.md`):

- R-level errors on invalid trusted arguments: `raddr_error_block` for a bad,
  missing or host-bits-set block (`192.168.1.1/24` is refused, not masked),
  type errors from the decoders, and `addr_classify()` refusing a character
  vector or a `raddr_parse` (principle P1: a string is never classified).
- The single-dialect parsers return `NA` with no reason on rejection; the
  outcome-bearing form is `addr_parse()` (section 6.1).
- The reality dialects model **Apple** libc, not glibc or musl. The image runs
  glibc, whose `inet_pton()` rejects leading zeros Apple accepts; that
  divergence is recorded in the Linux fixtures and asserted by
  `test-libc.R`, not a bug.
- `addr_getaddrinfo()` and `addr_curl()` lift the second hextet of a
  `fe80::/10` address into the zone; reality dialects accept any zone text
  (`%bogus0`); the zone never affects equality.
- `addr_whatwg()` is the WHATWG IPv4/IPv6 host parser only. It does not
  percent-decode or run IDNA; that is `rurl`'s and `punycoder`'s job. A
  reg-name such as `0x7f.0.0.0x7g` returns `NA` by design. So does a bracketed
  IPv6 host: `addr_whatwg("[::1]")` is `NA`, because stripping the brackets is
  the URL layer's job and raddr is handed the text between them
  (`docs/architecture.md`).
- In `addr_within*()` a `::ffff:a.b.c.d` address is searched in the IPv6 space,
  so it is not inside `10.0.0.0/8`; the embedded IPv4 is reported separately by
  `addr_embeddings()`. A missing embedding is in scope; the containment rule is
  not.
- `category` is descriptive, not a policy input, and there is deliberately no
  "not global" helper. `addr_global_reachability()` returns `NA` where neither
  registry layer settles the question; that third value is intended.
- `globally_reachable` (and `addr_global_reachability()`) describes the outer
  address's own registry block only. `64:ff9b::7f00:1` is `TRUE` there although
  it carries `127.0.0.1`. An embedded address is judged through
  `addr_embeddings()` and the classify codes `nat64_wk_embedded_not_global`,
  `sixtofour_embedded_not_global` and `teredo_client_not_global`. A wrong or
  missing embedded classification there is still rated Critical; the outer
  column ignoring the inner address is not.

Patch format: a minimal R fix in the package's style (vectorized, base R
string operations, no new Imports); a `testthat` regression test in the
`tests/testthat/test-*.R` file for that area; a `NEWS.md` entry under the
development version, citing the standard and clause when the fix is a
conformance fix.
