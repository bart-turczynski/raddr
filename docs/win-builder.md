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
