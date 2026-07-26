# raddr

Report what an IP address literal means under each of the standards and
implementations that disagree about it, and classify parsed values against the
IANA special-purpose address registries.

> **Status: pre-alpha.** The design is settled (`docs/architecture.md`); the
> package code is not written yet. Nothing below is installable.

## The problem, in one string

One literal, one machine, three different hosts:

```
"0177.0.0.1"
  strict (RFC dotted-quad; Python ipaddress, Go, Rust)  ->  reject
  whatwg (= what browsers do)                           ->  127.0.0.1
  pton   (POSIX inet_pton, Apple libc)                  ->  177.0.0.1
  aton   (BSD inet_aton)                                ->  127.0.0.1
```

Every existing library picks one of those readings and discards the rest. raddr
does not pick. `addr_parse()` takes no mode argument — it returns every reading,
always, with the reason codes that explain each one.

### Dialects sit on two axes

Not one list, but what a *standard* requires ("on paper") versus what an
*implementation* actually does ("in reality"):

| Axis | Dialect | Models | Stability |
|---|---|---|---|
| paper | `strict` | RFC dotted-quad grammar; Python `ipaddress`, Go, Rust | fixed |
| paper | `whatwg` | WHATWG URL host parser; what browsers do | fixed, versioned spec |
| reality | `pton` | POSIX `inet_pton` | **platform-varying** |
| reality | `aton` | BSD `inet_aton` | stable in practice |

Two more dialects are precedence orderings over the same reality primitives, not
separate parsers:

```
addr_getaddrinfo  =  pton, falling back to aton
addr_curl         =  aton, falling back to pton
```

### Measured divergence

Measured on macOS Darwin 25.4.0 arm64, curl 7.1.0 / libcurl 8.14.1, Apple libc,
2026-07-26:

| input | `strict` | `whatwg` | `pton` | `aton` | `getaddrinfo` | `curl` |
|---|---|---|---|---|---|---|
| `127.0.0.1` | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 |
| `0177.0.0.1` | reject | 127.0.0.1 | 177.0.0.1 | 127.0.0.1 | 177.0.0.1 | 127.0.0.1 |
| `192.0.010.1` | reject | 192.0.8.1 | 192.0.10.1 | 192.0.8.1 | 192.0.10.1 | 192.0.8.1 |
| `192.0.048.1` | reject | reject | 192.0.48.1 | reject | 192.0.48.1 | 192.0.48.1 |
| `4294967296` | reject | reject | reject | 0.0.0.0 | 0.0.0.0 | 0.0.0.0 |
| `1.2.3.` | reject | 1.2.0.3 | reject | reject | reject | reject |
| `2130706433` | reject | 127.0.0.1 | reject | 127.0.0.1 | 127.0.0.1 | 127.0.0.1 |
| `10.048.1.1` | reject | reject | 10.48.1.1 | reject | 10.48.1.1 | 10.48.1.1 |

Two rows carry most of the package's value:

- **`192.0.048.1`** — curl reaches a host a browser refuses to dial.
- **`4294967296`** — `aton` wraps modulo 2^32 to `0.0.0.0`; the standards reject.

## raddr is a shower, not a protector

It reports facts. It never returns a verdict, a risk score, or an allow/deny
decision. Security policy is a separate concern and belongs to a separate
package.

### What raddr will never do

| Excluded | Owner |
|---|---|
| DNS resolution, hostname lookup | `ssrfr` / `curl` |
| HTTP, redirects, connection pinning | `ssrfr` |
| Allow/deny policy, risk scores, verdicts | `ssrfr` |
| Cloud-metadata endpoint tables | `ssrfr` |
| "Most restrictive reading wins" convenience | `ssrfr` |
| Geolocation, ASN, country data | nowhere |
| IDNA, punycode | `punycoder` |
| Public-suffix logic | `pslr` |
| URL parsing, scheme/port policy, reg-name-vs-IP host form | `rurl` |
| General CIDR set algebra (collapse, exclude, subnets) | `ipaddress` |
| `X-Forwarded-For` extraction (HTTP header parsing, not address parsing) | `ssrfr` |
| Visualization | `ggip` |

### Why not just use `ipaddress`?

`ipaddress` is a good package and raddr does not replace it — the table above
assigns CIDR set algebra to it permanently. But it answers a different question.
It gives you *one* reading of a literal and is silent about the rest: it
transforms `0177.0.0.1` into `177.0.0.1` without a word, which is exactly the
transformation that changes which host you reach. raddr's premise is that
`0177.0.0.1` has several defensible answers and that you should see all of them.

raddr is pure R, performs no network access, and depends on `vctrs` and `rlang`.

## Setup

Install package dependencies (from `DESCRIPTION`) plus the dev tooling used by
the checks:

```sh
Rscript -e 'pak::local_install_deps(dependencies = TRUE)'
```

Enable the git hooks once per clone:

```sh
pre-commit install && pre-commit install --hook-type pre-push
```

## Verification

```sh
Rscript -e 'lints <- lintr::lint_package(); if (length(lints)) { print(lints); quit(status = 1) }' && Rscript -e 'rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "warning")'
```

`R CMD check` runs the testthat suite, so the tests are verified as part of the
check.

## Project Layout

- `R/` contains the package source.
- `man/` contains generated help pages (regenerate with `devtools::document()`).
- `NAMESPACE` and `man/` are roxygen2-generated — edit the roxygen comments in `R/`, not these.
- `tests/testthat/` contains the testthat tests.
- `vignettes/` contains long-form documentation.
- `DESCRIPTION` declares package metadata and dependencies.
- `docs/architecture.md` is the settled design record — read it before changing the API.
- `_scratch/` is local-only planning space and is ignored by git.
