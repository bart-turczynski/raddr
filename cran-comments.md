This is a new submission of raddr 0.1.2.

**Build the tarball from a clean export of the tag, not from a git worktree.**
`R CMD build` excludes `.git` *directories*; in a worktree `.git` is a regular
*file*, so it is not excluded and raises a `checking for hidden files and
directories` NOTE. That happened on the first 0.1.2 Windows attempt
(`docs/win-builder.md`, "0.1.2"). `git archive` of `v0.1.2^{commit}` into an
empty directory is what the rows below were measured against. RADD-uegdokgx
carries the durable fix for the version after this one.

## R CMD check results

0 errors | 0 warnings | 1 note

The note is from `checking CRAN incoming feasibility`, and reports two things:

* New submission.
* One URL returns 404 — `https://gitlab.com/bart-turczynski/raddr/-/issues`,
  the `BugReports:` field, cited from `DESCRIPTION` and `man/raddr-package.Rd`.
  The issue tracker is enabled and the page loads normally in a browser, which
  redirects it to `https://gitlab.com/bart-turczynski/raddr/-/work_items`.
  GitLab has migrated issues to work items and serves `404` on the legacy
  `/-/issues` path to any client that is not signed in, on every project —
  confirmed against `gitlab.com/gitlab-org/gitlab`, whose tracker is
  unambiguously public and answers the same way. What is stale is the path, not
  the project, and this is not a block on scripted clients: measured 2026-09-10
  from one anonymous client in a single run, `/-/work_items` returns `200` for
  both projects, as does the repository root
  `https://gitlab.com/bart-turczynski/raddr`. The address is correct and is the
  one users need; it is not dropped. `BugReports:` will name the `work_items`
  path from the next version, so that the change goes through a release cycle
  rather than a submission.

`DESCRIPTION` deliberately carries no `https://CRAN.R-project.org/package=raddr`
URL. That address 404s until the package is accepted — re-measured 2026-09-05 —
so adding it now would inject a second, avoidable invalid-URL finding on top of
the one explained above. It goes in on acceptance.

Two earlier notes reported against 0.1.1 are gone rather than unexplained. The
`Version contains large components` line went with the `.9000` development
suffix: 0.1.2 is a release version. The `IANA` possibly-misspelled-word line was
always a false positive — IANA is the Internet Assigned Numbers Authority, whose
special-purpose registry is the data this package ships — and it appears only
where a spell checker is installed, so it is reported by the Windows
environments and by no other. `inst/WORDLIST` carries it, and the package's own
`spelling::spell_check_package()` run is part of the pre-push gate.

## Version history

0.1.0 and 0.1.1 were both tagged during development, on 2026-07-31 and
2026-08-02, and neither was submitted to CRAN or published anywhere else. They
remain in the repository as honest records of what was checked when. 0.1.2 is
the first release offered for publication, and the reason-code registry's
`since` column names it for that reason.

## Test environments

All rows below were run against the `v0.1.2` tree.

* local: macOS 26.4.1 (aarch64-apple-darwin23), R 4.6.0 (2026-04-24) — 1 note
* GitLab CI, native x86_64 Linux (`x86_64-pc-linux-gnu`): R 4.6.1 (2026-06-24)
  — 1 note
* GitLab CI, native x86_64 Linux (`x86_64-pc-linux-gnu`): R Under development
  (unstable) (2026-09-04 r90492) — 1 note
* win-builder, Windows Server 2022 x64 (build 20348),
  `x86_64-w64-mingw32`: R 4.6.1 (2026-06-24 ucrt) — 1 note
* win-builder, Windows Server 2022 x64 (build 20348),
  `x86_64-w64-mingw32`: R Under development (unstable) (2026-09-04 r90492 ucrt)
  — 1 note

The two CI rows ran from a clean clone into a clean package library at the
tagged commit `e1ed138`, pipeline 2822895536. Both report the same single note
as the local run, and the check header on both names `raddr 0.1.2`.

The two win-builder rows were run on 2026-09-06 against a `git archive` export
of `v0.1.2^{commit}` — `https://win-builder.r-project.org/lMls79w3xp1X/`
(release) and `https://win-builder.r-project.org/1FrmvA2DvQWe/` (devel), both
transcribed in `docs/win-builder.md`. Tests, vignette re-building and both
manual renderings passed on each, and both report the same single note as every
other row. An earlier pair of runs the same day returned `Status: 2 NOTEs`
because the tarball had been built from a worktree; that is the banner at the
top of this file, and those runs are transcribed too rather than discarded.

## Downstream dependencies

None — this is a new package.
