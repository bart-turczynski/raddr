This is a new submission of raddr 0.1.1.

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
* Ubuntu (container, emulated x86_64): R 4.6.1 (2026-06-24) — 1 note
* Ubuntu (container, emulated x86_64): R Under development (unstable)
  (2026-07-30 r90327) — 1 note
* x86_64 Linux (container): R 4.0.0, the floor `DESCRIPTION` declares — OK,
  0 errors, 0 warnings, 0 notes

**Windows has not been checked.** No Windows machine is available here, and
nothing else in the list approximates it. That is the one gap I know of and
would rather state than leave for the reviewer to find.

The three container rows were run locally rather than on CI, which has never
executed: the GitHub account hosting the repository is suspended, which is also
what the URL note above is about. They are emulated amd64 on an arm64 host, so
they are close to a CI runner and not identical to one.

The package is pure R — no compiled code, no `SystemRequirements`, and no
network access at any point — and depends only on rlang and vctrs.

## Downstream dependencies

None — this is a new package.
