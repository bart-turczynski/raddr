# Windows, via win-builder — transcript

Submitted 2026-08-02 from a clean `dev` at `5478163` (`v0.1.1-10-g5478163`),
built with `R CMD build` into a scratch directory outside the working tree.
The artifact was `raddr_0.1.1.tar.gz`, 342934 bytes, sha256
`bf2b6383551168f0012f0d06e7cf72ff68f074ed004d68345cd6d92ba770d7fe`.

Both win-builder queues were uploaded to over FTP, response 226 each, and
**both have now returned `Status: 1 NOTE`** (`RADD-xxuzwmuj`). One upload per
queue produced one run and one email each; there was no second submission.

Per `docs/release-build.md`, that sha256 records what one run produced and is not
a verified-artifact fingerprint: `R CMD build` embeds a `Packaged:` timestamp, so
rebuilding this same tree produces different bytes. Compare extracted contents,
never tarball checksums.

**Note added 2026-08-02, after the fact.** The tree checked here declared
`Version: 0.1.1`, which was true at `5478163` and is no longer true of `dev`:
`RADD-xuqkzgdl` moved the development version to `0.1.1.9000` the same day,
because the `v0.1.1` tag and `dev` were both claiming 0.1.1 while pointing at
different trees. Nothing above is restated — the runs checked what they checked.
What changed is that the number they checked it under now belongs to the tag
alone.

## Result

**`Status: 1 NOTE` on both**, with the same note on each.

| | R-devel | R-release |
| --- | --- | --- |
| result URL | `https://win-builder.r-project.org/v1y4h2q88Yd8/` | `https://win-builder.r-project.org/eo4W4VtKXGmM/` |
| R | R Under development (unstable) (2026-07-30 r90327 ucrt) | R version 4.6.1 (2026-06-24 ucrt) |
| log directory | `d:/RCompile/CRANguest/R-devel/` | `d:/RCompile/CRANguest/R-release/` |
| check began | 2026-08-02 14:04:07 UTC | 2026-08-02 14:10:07 UTC |
| tests | `[37s] OK` — `spelling.R`, then `testthat.R` at 36s | `[38s] OK` — `spelling.R`, then `testthat.R` at 37s |
| vignettes | re-built OK | re-built OK |
| manual | PDF `[17s] OK`, HTML OK | PDF `[17s] OK`, HTML OK |

Both ran on `x86_64-w64-mingw32`, Windows Server 2022 x64 (build 20348), R
compiled by gcc 14.3.0 / GNU Fortran 14.3.0. Installation was clean and staged
on both, with no warnings: the package byte-compiles, loads from temporary and
final locations, and keeps no record of the temporary installation path.

**The two runs agree completely**, down to the note text and to within a second
on every timed stage. That is the expected result and it is worth one line, not
a paragraph: R-devel and R-release differ by six weeks of R development, and this
package is pure R with two dependencies and no compiled code. A disagreement
would have been the finding. Agreement is the null result.

## The one thing Windows found that nothing else had

The note is the familiar incoming-feasibility note, plus **one line no other
environment has ever reported** — identical on both runs, quoted here from
R-devel:

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Bart Turczynski <bartek@turczynski.pl>'

New submission

Possibly misspelled words in DESCRIPTION:
  IANA (16:56)

Found the following (possibly) invalid URLs:
  URL: https://github.com/bart-turczynski/raddr
    From: DESCRIPTION
          man/raddr-package.Rd
    Status: 404
    Message: Not Found
  URL: https://github.com/bart-turczynski/raddr/issues
    From: DESCRIPTION
          man/raddr-package.Rd
    Status: 404
    Message: Not Found
```

The two 404s are the GitHub account suspension, which `RADD-yrppvxdi` owns. They
are unchanged and this run does not move them.

`IANA` is new, and the reason it is new is worth more than the finding itself.

**It is not a Windows behaviour difference. It is a tool that exists there and
nowhere else here.** `checking CRAN incoming feasibility` spell-checks
`DESCRIPTION` through `utils::aspell`, which silently checks nothing when no
aspell binary is on the host. Measured on the development machine: `aspell`,
`hunspell` and `ispell` are all absent, and `Sys.which("aspell")` is empty from
R. The Linux CI images are the same. So on macOS, on both `rocker` containers
and on both GitLab runners, that section of the check produced no output — not
because it passed, but because it never ran. CRAN's Windows builder has aspell,
so it ran there for the first time.

That is the same shape as the finding in `docs/gitlab-ci.md`, where the first
pipeline failed on a missing `libcurl4-openssl-dev` that no local row could have
surfaced. Both are checks that were quietly inert locally rather than passing.
Neither was a platform semantics difference, which is the thing the matrix was
built to vary — and both were found anyway, by running somewhere else.

**The finding itself is a false positive, and `inst/WORDLIST` does not suppress
it.** `IANA` is the Internet Assigned Numbers Authority, and it is already in
`inst/WORDLIST` at line 31 alongside `IANA's`. That file is consulted by the
`spelling` package's test — which is why `spelling.R` passes on the same run —
and *not* by `R CMD check`'s incoming feasibility, which uses its own dictionary.
The two spell checks are unrelated machinery that happen to share a subject. So
there is nothing to fix in the package; the correct response is to preempt it in
`cran-comments.md`, which is done.

## What this closes, and what it does not

The `windows-latest` / `release` row of `.github/workflows/R-CMD-check.yaml` is
**answered**: R 4.6.1 on Windows is the row, and it checks clean. That was the
last of the six rows checked by nothing, so the matrix no longer has an unheld
claim in it. R-devel on Windows is a bonus the matrix never asked for.

Nothing about a Windows *CI pipeline* changes. GitLab's two Windows shared
runners still report `active=false` / `paused=true`, re-measured 2026-08-02, so
that route does not exist on this plan. This was one check, not a pipeline, and
re-running it is a manual act that nothing enforces.


---

# 0.1.2 — Windows, via win-builder — transcript

Submitted 2026-09-06 against the `v0.1.2` tag. **Nothing below restates or
amends the 0.1.1 transcript above**; that run checked what it checked.

Both queues returned **`Status: 2 NOTEs`**. The tests passed on both flavors —
`[38s] OK`, `spelling.R` then `testthat.R` at 38s — so nothing in the package's
behavior is implicated. One of the two notes is expected and defended in
`cran-comments.md`. The other is an artifact of **how the tarball was built**,
not of what the package contains, and it means these two runs did not check the
artifact that should be submitted.

## Result

| | R-devel | R-release |
| --- | --- | --- |
| result URL | `https://win-builder.r-project.org/JsM16pcprR0G/` | `https://win-builder.r-project.org/PJaGSqZF1512/` |
| R | R Under development (unstable) (2026-09-04 r90492 ucrt) | R version 4.6.1 (2026-06-24 ucrt) |
| log directory | `d:/RCompile/CRANguest/R-devel/raddr.Rcheck` | `d:/RCompile/CRANguest/R-release/raddr.Rcheck` |
| check began | 2026-09-06 14:39:16 UTC | 2026-09-06 14:26:51 UTC |
| install / check | 5s / 103s | 5s / 106s |
| tests | `[38s] OK` — `spelling.R`, then `testthat.R` at 38s | `[38s] OK` — `spelling.R`, then `testthat.R` at 38s |
| vignettes | re-built OK | re-built OK |
| manual | PDF `[17s] OK`, HTML OK | PDF `[17s] OK`, HTML OK |
| result | `Status: 2 NOTEs` | `Status: 2 NOTEs` |

Both on `x86_64-w64-mingw32`, Windows Server 2022 x64 (build 20348), R compiled
by gcc 14.3.0 / GNU Fortran 14.3.0, session charset UTF-8. The two runs agree
completely, note text included.

### NOTE 1 — CRAN incoming feasibility (expected)

```
New submission

Possibly misspelled words in DESCRIPTION:
  IANA (16:56)

Found the following (possibly) invalid URLs:
  URL: https://gitlab.com/bart-turczynski/raddr/-/issues
    From: DESCRIPTION
          man/raddr-package.Rd
    Status: 404
    Message: Not Found
```

All three components are already answered in `cran-comments.md`. `IANA` is the
Internet Assigned Numbers Authority and is in `inst/WORDLIST`, which CRAN's
incoming `aspell` run does not consult. The `/-/issues` 404 is GitLab-wide
anti-scraping behavior for logged-out clients, measured 2026-09-06 with same-run
controls: raddr's own repo root returned 200 while `gitlab-org/gitlab`,
`gitlab-runner` and `inkscape` all returned 404 identically on their `/-/issues`
paths.

### NOTE 2 — hidden files and directories (a build artifact, not package content)

```
* checking for hidden files and directories ... NOTE
Found the following hidden files and directories:
  .git
These were most likely included in error.
```

**This is the worktree trap, and it recurred.** The tarball was built by
`devtools::check_win_release()` / `check_win_devel()` pointed at a detached git
**worktree**. In a worktree, `.git` is not a directory — it is a 73-byte regular
*file* holding a `gitdir:` pointer. `R CMD build` excludes `.git`
*directories*, so the file slips straight through, and raddr's
`.Rbuildignore` does not catch it either: it lists `^\.gitlab-ci\.yml$`,
`^\.gitattributes$` and `^\.gitignore$`, but no `^\.git$`.

The same NOTE appeared in the local `--as-cran` run on 2026-09-04 for the same
reason and was settled then with a control: building the artifact from
`git archive` of the tag — an export with no `.git` at all — and checking that
produced `Status: 1 NOTE`, the incoming-feasibility one alone. That control was
re-derived on 2026-09-06 against `v0.1.2^{commit}`: the export contains
`.gitignore`, `.gitattributes` and `.gitlab-ci.yml` (all `.Rbuildignore`d) and
no `.git`, and `R CMD build` on it yields a 343115-byte
`raddr_0.1.2.tar.gz` carrying no `.git`, no `docs/`, no `data-raw/`, no
`cran-comments.md`, no `AGENTS.md`, and no `Remotes:` field.

Per `docs/release-build.md` that byte count records what one run produced and is
not a fingerprint — `R CMD build` embeds a `Packaged:` timestamp, so the same
tree rebuilds to different bytes. The 2026-09-04 control measured 343114 bytes
for the same content. Compare extracted contents, never tarball checksums.

## What this closes, and what it does not

Closed: the package's behavior under Windows on both R flavors. Tests, vignette
re-building, and both manual renderings pass, and the two flavors agree.

**Not closed: a Windows run against the artifact that will actually be
submitted.** These two checked a worktree-built tarball. The fix is a process
one — build from a clean export, never from a worktree — and it costs no change
to the package and no re-cutting of `v0.1.2`. Adding `^\.git$` to
`.Rbuildignore` would make it durable rather than procedural, but that edits
tarball content and would force the tag to be re-cut; it belongs in the next
version, alongside the `docs/architecture.md` link repoint already deferred
there for the same reason.


---

# 0.1.2, re-run against a clean export — Windows, via win-builder — transcript

Submitted 2026-09-06, after the runs in the section above returned
`Status: 2 NOTEs` against a worktree-built tarball. **Nothing above is restated
or amended**; those runs checked what they checked. This section records what a
clean artifact returns.

The tarball was built by `devtools::check_win_*()` from a `git archive` export
of `v0.1.2^{commit}` into an empty directory — a tree containing `.gitignore`,
`.gitattributes` and `.gitlab-ci.yml` (all `.Rbuildignore`d) and **no `.git`**.

**Both queues returned `Status: 1 NOTE`.** The hidden-files NOTE is gone.

## Result

| | R-devel | R-release |
| --- | --- | --- |
| result URL | `https://win-builder.r-project.org/1FrmvA2DvQWe/` | `https://win-builder.r-project.org/lMls79w3xp1X/` |
| R | R Under development (unstable) (2026-09-04 r90492 ucrt) | R version 4.6.1 (2026-06-24 ucrt) |
| log directory | `d:/RCompile/CRANguest/R-devel/raddr.Rcheck` | `d:/RCompile/CRANguest/R-release/raddr.Rcheck` |
| check began | 2026-09-06 16:40:14 UTC | 2026-09-06 16:41:54 UTC |
| install / check | 5s / 106s | 5s / 103s |
| tests | `[39s] OK` — `spelling.R`, then `testthat.R` at 39s | `[38s] OK` — `spelling.R`, then `testthat.R` at 38s |
| vignettes | re-built OK | re-built OK |
| manual | PDF `[17s] OK`, HTML OK | PDF `[16s] OK`, HTML OK |
| result | `Status: 1 NOTE` | `Status: 1 NOTE` |

Both on `x86_64-w64-mingw32`, Windows Server 2022 x64 (build 20348), R compiled
by gcc 14.3.0 / GNU Fortran 14.3.0, session charset UTF-8. The two runs agree,
note text included.

### The one remaining NOTE — CRAN incoming feasibility (expected)

```
New submission

Possibly misspelled words in DESCRIPTION:
  IANA (16:56)

Found the following (possibly) invalid URLs:
  URL: https://gitlab.com/bart-turczynski/raddr/-/issues
    From: DESCRIPTION
          man/raddr-package.Rd
    Status: 404
    Message: Not Found
```

Byte-identical to NOTE 1 of the worktree runs, and answered in
`cran-comments.md`.

## What this closes

**The Windows row.** It was the last one owed, and it is now measured against an
artifact built the same way the submitted one will be.

It also settles the `.git` question empirically rather than by argument. The
only difference between this pair of runs and the pair above is how the tarball
was built — same tag, same commit, same tree contents. One pair returns
`2 NOTEs` and the other `1 NOTE`, which is the diagnosis confirmed by
controlled comparison rather than inferred from the note text.

What is still owed at submission time is procedural, not a check: the tarball
that goes to CRAN must be built from a clean export too. `RADD-uegdokgx` carries
the durable fix — `^\.git$` in `.Rbuildignore` — deferred to the version after
0.1.2 because it edits tarball content and would force `v0.1.2` to be re-cut.
