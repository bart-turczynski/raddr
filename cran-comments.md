This is a new submission of raddr 0.1.1.

## R CMD check results

0 errors | 0 warnings | 1 note

The note is from `checking CRAN incoming feasibility`, and reports three things:

* New submission.
* One possibly misspelled word in `DESCRIPTION`: `IANA`, the Internet Assigned
  Numbers Authority, whose special-purpose address registry is the data this
  package ships. It is spelled correctly. This appears only where a spell
  checker is installed — on the environments below that have no `aspell`, the
  check produces no output rather than passing — so it is reported by the two
  Windows environments alone, and by both of them.
* One URL returns 404 — `https://gitlab.com/bart-turczynski/raddr/-/issues`,
  the `BugReports:` field, cited from `DESCRIPTION` and `man/raddr-package.Rd`.
  The issue tracker is enabled and the page loads normally in a browser. GitLab
  serves `404` rather than `403` for the `/-/issues` path of *any* project to a
  client that is not signed in — it is anti-scraping behavior applied
  project-independently, confirmed against `gitlab.com/gitlab-org/gitlab`, whose
  tracker is unambiguously public and answers the same way. The repository root
  `https://gitlab.com/bart-turczynski/raddr` returns `200` to the same
  anonymous client, so the project is reachable and only this one path is
  cloaked. The address is correct and is the one users need; it is not dropped.

## Test environments

* local: macOS 26.4.1 (aarch64-apple-darwin23), R 4.6.0 (2026-04-24)
* Ubuntu (container, emulated x86_64): R 4.6.1 (2026-06-24) — 1 note
* Ubuntu (container, emulated x86_64): R Under development (unstable)
  (2026-07-30 r90327) — 1 note
* x86_64 Linux (container): R 4.0.0, the floor `DESCRIPTION` declares — OK,
  0 errors, 0 warnings, 0 notes
* GitLab CI, native x86_64 Linux: R 4.6.1 (2026-06-24) — 1 note
* GitLab CI, native x86_64 Linux: R Under development (unstable)
  (2026-07-30 r90334) — 1 note
* Windows Server 2022 x64, via win-builder: R 4.6.1 (2026-06-24 ucrt),
  `x86_64-w64-mingw32` — 1 note
* Windows Server 2022 x64, via win-builder: R Under development (unstable)
  (2026-07-30 r90327 ucrt), `x86_64-w64-mingw32` — 1 note

The two Windows runs agree completely, including the note text. Windows is
checked by no CI here — the account hosting the repository is suspended, and the
GitLab remote's two Windows shared runners are paused at the platform level — so
those two runs are a manual submission, not a standing gate.

The emulated container rows were run locally rather than on CI. They are
emulated amd64 on an arm64 host, so they are close to a CI runner and not
identical to one; the two native GitLab rows above were added precisely because
they are not emulated.

The package is pure R — no compiled code, no `SystemRequirements`, and no
network access at any point — and depends only on rlang and vctrs.

## Downstream dependencies

None — this is a new package.
