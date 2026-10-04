
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# raddr

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/raddr)](https://CRAN.R-project.org/package=raddr)
[![CRAN
downloads](https://cranlogs.r-pkg.org/badges/raddr)](https://CRAN.R-project.org/package=raddr)
[![CRAN
checks](https://badges.cranchecks.info/worst/raddr.svg)](https://cran.r-project.org/web/checks/check_results_raddr.html)
[![r-universe](https://bart-turczynski.r-universe.dev/raddr/badges/version)](https://bart-turczynski.r-universe.dev/raddr)
[![Pipeline](https://gitlab.com/bart-turczynski/raddr/badges/main/pipeline.svg)](https://gitlab.com/bart-turczynski/raddr/-/pipelines)
[![Coverage](https://gitlab.com/bart-turczynski/raddr/badges/main/coverage.svg)](https://gitlab.com/bart-turczynski/raddr/-/pipelines)
[![Docs](https://img.shields.io/website?url=https%3A%2F%2Fbart-turczynski.gitlab.io%2Fraddr%2F&label=docs&logo=gitlab&logoColor=white&up_message=pkgdown&up_color=1f75cb)](https://bart-turczynski.gitlab.io/raddr/)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![Project Status:
Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Zenodo](https://img.shields.io/badge/Zenodo-all_software-1682D4?logo=zenodo&logoColor=white)](https://zenodo.org/search?q=metadata.creators.person_or_org.identifiers.identifier:0000-0002-8788-7980)
[![OpenSSF Best
Practices](https://www.bestpractices.dev/projects/15190/badge)](https://www.bestpractices.dev/projects/15190)
[![License](https://img.shields.io/gitlab/license/bart-turczynski%2Fraddr)](https://gitlab.com/bart-turczynski/raddr/-/blob/main/LICENSE.md)
[![Dependencies](https://tinyverse.netlify.app/badge/raddr)](https://CRAN.R-project.org/package=raddr)
[![Last
commit](https://img.shields.io/gitlab/last-commit/bart-turczynski%2Fraddr)](https://gitlab.com/bart-turczynski/raddr/-/commits/main)
<!-- badges: end -->

Report what an IP address literal means under each of the standards and
implementations that disagree about it, and classify parsed values
against the IANA special-purpose address registries.

The string `"0177.0.0.1"` is rejected by the RFC dotted-quad grammar,
read as `127.0.0.1` by browsers and BSD `inet_aton`, and read as
`177.0.0.1` by some `inet_pton` implementations, Apple’s among them.
Most libraries pick one reading and discard the rest. raddr returns
every reading, with the reason codes that explain each one, so code that
validates, logs or compares addresses can see where the readings split.
It reports facts, never an allow/deny verdict or a risk score. The full
case, with the measured divergence tables, is the *Why raddr* article,
`vignette("why-raddr", package = "raddr")`.

## Installation

Install the released version from CRAN:

``` r
install.packages("raddr")
```

Or the development version from r-universe:

``` r
install.packages(
  "raddr",
  repos = c("https://bart-turczynski.r-universe.dev", "https://cloud.r-project.org")
)
```

raddr is pure R with no compiled code, so a source install needs no
compiler and no system libraries. It performs no network access and
depends only on `vctrs` and `rlang`.

## Example

``` r
library(raddr)

addr_parse("0177.0.0.1")
#> <raddr_parse[1]>
#> [1] 127.0.0.1
#> Status: divergent 1
#>
#> [1] "0177.0.0.1"
#>   strict  <rejected: leading_zero>
#>   whatwg  127.0.0.1
#>   pton    177.0.0.1
#>   aton    127.0.0.1

# The browser reading reaches loopback; the inet_pton reading reaches a
# routable address.
addr_classify(addr_whatwg("0177.0.0.1"))
#> <raddr_class[1]>
#> [1] loopback 127.0.0.0/8
#> Registry: special-purpose 2025-10-09
addr_classify(addr_pton("0177.0.0.1"))
#> <raddr_class[1]>
#> [1] global 177.0.0.0/8
#> Registry: address space 2025-10-10
```

## Learn more

The documentation site is <https://bart-turczynski.gitlab.io/raddr/>,
with the articles listed under
[Articles](https://bart-turczynski.gitlab.io/raddr/articles/index.html):

- [Introduction to
  raddr](https://bart-turczynski.gitlab.io/raddr/articles/introduction.html):
  the dialects, the parse record, and classification, worked through.
- *Why raddr*, `vignette("why-raddr", package = "raddr")`: the measured
  disagreement between standards and implementations, and what raddr
  leaves to other packages.
- [Reason
  codes](https://bart-turczynski.gitlab.io/raddr/articles/reason-codes.html):
  every code the parse and classify layers emit.
- [Edge
  cases](https://bart-turczynski.gitlab.io/raddr/articles/edge-cases.html):
  the inputs where readings and registries are easiest to get wrong.
