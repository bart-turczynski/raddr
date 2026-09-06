This is a new submission of raddr 0.1.2.

**NOT READY TO SUBMIT.** The Windows row is outstanding. See "Outstanding
before submission" at the end of this file, and do not paste this into the
submission form until that section is empty.

## R CMD check results

0 errors | 0 warnings | 1 note

The note is from `checking CRAN incoming feasibility`, and reports two things:

* New submission.
* One URL returns 404 — `https://gitlab.com/bart-turczynski/raddr/-/issues`,
  the `BugReports:` field, cited from `DESCRIPTION` and `man/raddr-package.Rd`.
  The issue tracker is enabled and the page loads normally in a browser. GitLab
  serves `404` rather than `403` for the `/-/issues` path of *any* project to a
  client that is not signed in — it is anti-scraping behavior applied
  project-independently, confirmed against `gitlab.com/gitlab-org/gitlab`, whose
  tracker is unambiguously public and answers the same way. The repository root
  `https://gitlab.com/bart-turczynski/raddr` returns `200` to the same
  anonymous client, so the project is reachable and only this one path is
  cloaked. Both statuses were re-measured on 2026-09-05. The address is correct
  and is the one users need; it is not dropped.

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

The two CI rows ran from a clean clone into a clean package library at the
tagged commit `e1ed138`, pipeline 2822895536. Both report the same single note
as the local run, and the check header on both names `raddr 0.1.2`.

## Outstanding before submission

The rows below were measured against the 0.1.1 tree and have **not** been re-run
on 0.1.2. They must be re-run against the exact tarball submitted, and this file
updated from their output, before anything is sent to CRAN.

* Windows Server 2022 x64, via win-builder — R release and R-devel. **This is
  the only row still owed.** It is an upload to a third party and is therefore a
  deliberate step rather than something a gate performs.

  0.1.2 was uploaded to both queues on 2026-09-06 and both returned
  `Status: 2 NOTEs`; the runs are transcribed in `docs/win-builder.md` under
  "0.1.2". **The row stays open, and the reason is this section's own standard:
  they must be re-run against the exact tarball submitted, and those two were
  not.** The package itself is fine — tests, vignette re-building and both
  manual renderings passed on both flavors, and the two runs agree. But the
  tarball was built by `devtools::check_win_*()` pointed at a detached git
  **worktree**, where `.git` is a 73-byte regular *file* rather than a
  directory; `R CMD build` excludes `.git` directories, and `.Rbuildignore`
  carries no `^\.git$`, so it rode into the artifact and raised a second NOTE
  for a hidden file that is not package content.

  Re-run them against a clean export of the tag — `git archive` of
  `v0.1.2^{commit}` into an empty directory, which contains no `.git` at all —
  and the second NOTE goes away, leaving the incoming-feasibility NOTE below.
  That was verified locally on 2026-09-06: the export builds a 343115-byte
  `raddr_0.1.2.tar.gz` carrying no `.git`, no `docs/`, no `data-raw/`, no
  `cran-comments.md`, no `AGENTS.md`, and no `Remotes:`.

  Adding `^\.git$` to `.Rbuildignore` would make this durable rather than
  procedural, but it edits tarball content and would force `v0.1.2` to be
  re-cut. Deferred to the next version alongside the `docs/architecture.md`
  link repoint, for the same reason (RADD-uegdokgx).
* Ubuntu release and devel in containers (`docs/check-matrix.md`), and R 4.0.0
  at the declared floor (`docs/r-floor-check.md`, `docs/dep-floor-check.md`).
  These were measured on earlier trees. They are not re-listed above, but the
  two native CI rows now cover Linux release and devel on 0.1.2 directly, and
  they cover it without an emulator, which the container rows could not.

What changed between 0.1.1 and 0.1.2 is `DESCRIPTION` (the version, and the two
URL fields repointed from a suspended GitHub account to GitLab),
`man/raddr-package.Rd` regenerated for those URLs, `NEWS.md`, `inst/WORDLIST`,
comments added to two files under `R/`, and new tests. There is no change to
executable code: stripping comment and blank lines from
`git diff v0.1.1..dev -- R/` leaves an empty diff. That makes a regression on
another platform unlikely, but "unlikely" is not a check result, which is why
the rows above stay listed rather than carried over.

## Downstream dependencies

None — this is a new package.
