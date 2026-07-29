## R CMD check results

0 errors | 0 warnings | 1 note

The note is from `checking CRAN incoming feasibility`, and reports two things:

* New submission.
* Two URLs return 404 — `https://github.com/bart-turczynski/raddr` and
  `https://github.com/bart-turczynski/raddr/issues`, cited from `DESCRIPTION`
  and `man/raddr-package.Rd`. The repository is not publicly reachable at the
  time of this check because the GitHub account hosting it is suspended, not
  because the addresses are wrong. If that is not resolved before submission,
  both fields will be dropped rather than left pointing at a 404.

## Test environments

* local: macOS 26.4.1 (aarch64-apple-darwin23), R 4.6.0 (2026-04-24)

No other platform has been checked. The package is pure R — no compiled code,
no `SystemRequirements`, and no network access at any point — and depends only
on rlang and vctrs.

## Downstream dependencies

None — this is a new package.
