# GitLab CI — the first pipeline this package has ever run

Recorded 2026-08-02 for `RADD-fgciezpx`, against the tree at `97e694c` on branch
`chore/gitlab-ci`.

`.github/workflows/R-CMD-check.yaml` has never executed once. It was authored
blind on 2026-07-31, when the repository had no reachable remote at all; a remote
arrived on 2026-08-01 and did not retire it, because GitLab does not read
`.github/`. `AGENTS.md` has said in as many words that "the local hook is not a
stand-in for CI — it is the only gate there is". This document is the measurement
that makes that sentence false.

## Result

| pipeline | commit | job | runner | status | duration |
|---|---|---|---|---|---|
| [2725127124](https://gitlab.com/bart-turczynski/raddr/-/pipelines/2725127124) | `800dddd` | `check:linux-release` | `5-green.saas-linux-small-amd64` | **success** | 108.6s |
| 2725127124 | `800dddd` | `check:linux-devel` | — | **failed** (`script_failure`) | 292.9s |
| [2725132733](https://gitlab.com/bart-turczynski/raddr/-/pipelines/2725132733) | `97e694c` | `check:linux-release` | `5-green.saas-linux-small-amd64` | **success** | 115.1s |
| 2725132733 | `97e694c` | `check:linux-devel` | `3-green.saas-linux-small-amd64` | **success** | 527.9s |

Both jobs on `97e694c` report **`Status: 1 NOTE`** — `0 errors ✔ | 0 warnings ✔ |
1 note ✖`. The note is the same one every other environment reports, and it is
not a finding:

```
❯ checking CRAN incoming feasibility ... NOTE
  Maintainer: ‘Bart Turczynski <bartek@turczynski.pl>’

  New submission

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

Those two 404s are the GitHub account suspension, which `RADD-yrppvxdi` owns as
the CRAN submission blocker. Nothing here moves them.

## The environments, as they resolved on this run

No date is pinned, deliberately. These jobs ask about platform and about upcoming
R, and both questions are only meaningful against packages as they are now — the
opposite of `data-raw/check-r-floor.sh`, which pins precisely because it asks a
different question. Since "current" is not reproducible, this record is the only
thing that makes the run checkable after the fact.

| | `check:linux-release` | `check:linux-devel` |
|---|---|---|
| image | `rocker/r-ver:latest` | `rocker/r-ver:devel` |
| R | 4.6.1 (2026-06-24) | Under development (unstable) (2026-08-01 r90334) |
| platform | `x86_64-pc-linux-gnu` | `x86_64-pc-linux-gnu` |
| repository | `https://p3m.dev/cran/__linux__/noble/latest` | `https://cloud.r-project.org` |
| dependency form | p3m binaries | source builds |
| check duration | 49.5s | 1m 5.8s |

Package versions were identical across both jobs: `rlang` 1.3.0, `vctrs` 0.7.3,
`bignum` 0.3.2, `bit64` 4.8.2, `digest` 0.6.39, `hedgehog` 0.2, `knitr` 1.51,
`rmarkdown` 2.31, `spelling` 2.3.2, `testthat` 3.3.2, `lintr` 3.4.0,
`rcmdcheck` 1.4.0, `fs` 2.1.0, `curl` 7.1.0.

Every Suggests package is installed deliberately, for the reason the GitHub
workflow gives: a check that skips is not a check that passed.
`tests/testthat/test-hedgehog.R` skips whole when `hedgehog` is absent, and the
`bignum`, `bit64` and `digest` paths do the same.

## What CI adds that no local measurement could

Five of the six rows in the dormant GitHub matrix are already answered by
measurements in this directory — `docs/check-matrix.md` for the two Ubuntu rows
and the macOS one, `docs/r-floor-check.md` and `docs/dep-floor-check.md` for the
two `oldrel` rows. So this pipeline was not built to add a row. It was built for
four things a laptop structurally cannot assert about itself, and all four now
hold:

1. **A clean clone.** Every local measurement runs against a working tree that
   has been lived in.
2. **A clean package library.** The host library accumulated over the whole of
   0.1.0's development, so an accidental dependency on something installed but
   never declared would be invisible to it and fatal for a user.
3. **Native amd64.** See below.
4. **A result tied to a commit.** The pre-push hook proves a tree passed on the
   way out and leaves no artifact saying which one.

## The finding: a system requirement the local matrix could not have found

The first pipeline's devel job failed, and it failed on exactly the class of
thing CI exists to surface. Verbatim from job 15664708185:

```
* installing *source* package ‘curl’ ...
** this is package ‘curl’ version ‘7.1.0’
Using PKG_CFLAGS=
Using PKG_LIBS=-lcurl
--------------------------- [ANTICONF] --------------------------------
Configuration failed because libcurl was not found. Try installing:
 * deb: libcurl4-openssl-dev (Debian, Ubuntu, etc)
...
<stdin>:1:10: fatal error: curl/curl.h: No such file or directory
compilation terminated.
--------------------------------------------------------------------
ERROR: configuration failed for package ‘curl’

Warning message:
In install.packages(m, Ncpus = 4) :
  installation of 2 packages failed:  ‘curl’, ‘rcmdcheck’
```

The chain of causation is more interesting than the fix:

- `rcmdcheck` imports `curl`. `data-raw/verify.sh` calls `rcmdcheck` rather than
  `R CMD check` because only `rcmdcheck` offers `error_on = "warning"`, which is
  what makes a WARNING fail the gate instead of exiting 0. **So `curl` is a build
  dependency of the gate, not of `raddr`.**
- `check:linux-release` installs a p3m *binary* of `curl`, already linked, and
  never sees a requirement at all. `check:linux-devel` resolves against
  `cloud.r-project.org` — p3m serves no binaries built against R-devel — builds
  from source, and needs the headers.
- **`data-raw/check-matrix.sh`'s devel row never hit this**, because that script
  calls `R CMD check` directly and so never installs `rcmdcheck` at all.

Fixed by adding `libcurl4-openssl-dev` and `libssl-dev` to the apt line
(`97e694c`). This is the `libuv1-dev` finding a second time: a system requirement
invisible wherever a binary is available and fatal wherever one is not. On
GitHub, `setup-r-dependencies` resolves this whole category automatically; the
apt line in `.gitlab-ci.yml` is the hand-maintained stand-in for that, so expect
a future source-built dependency to add another entry, and read a failure of this
shape as a missing `-dev` package before anything else.

## What this settles about the two caveats in `docs/check-matrix.md`

That document carries two cautions, because its Ubuntu rows run under amd64
emulation on an arm64 Mac. They are not settled the same way, and collapsing them
would lose the distinction.

**The `libuv1-dev` requirement is real and is not an emulation artifact.** The
native devel job builds `fs` 2.1.0 from source — `* installing *source* package
‘fs’ ...`, job 15664737722 — which is the same code path that failed under
emulation without the header package, and it needed the same apt entry to
succeed. The caveat correctly identified a genuine system requirement; what it
could not say was whether the requirement survived off the emulator. It does.

**The GNU tar 1.35 failure is an artifact of the local harness and does not exist
in CI.** Under `--platform linux/amd64` on Apple silicon, that tar cannot extract
into a subdirectory at all, which is why `check-matrix.sh` copies the tree in with
`cp`. CI never encounters it: the runner clones with git, and the class of problem
is absent rather than worked around. This confirms the caveat's own reading — that
it was a limit of emulation and not of the package.

**Both caveats stay in `docs/check-matrix.md` as written.** They are true
statements about the 2026-07-31 run that document transcribes, and rewriting a
generated transcript to reflect a later, different run would falsify it. What
changed is their significance, which is recorded here and cross-referenced from
`data-raw/check-matrix.sh`.

## What CI still does not cover

Stated so the gap is not quietly closed by implication.

- **Windows is still checked by nothing.** `RADD-xxuzwmuj` holds it, and the
  answer there is win-builder, not a runner: GitLab's two Windows shared runners
  (1506020, 1506021) report `online=true` but `status=paused`.
- **macOS beyond the pre-push hook.** A self-hosted Mac runner is *rejected*, not
  pending — see `RADD-fgciezpx` for why a route to an already-covered platform is
  worth nothing, and why a shell executor on a primary workstation is an
  unattractive trade.
- **Minimum dependency versions.** Measured at exactly `vctrs` 0.7.0 on R 4.0.0
  by `data-raw/check-dep-floor.sh` (`docs/dep-floor-check.md`).
- **Semantic diversity across libc.** Already measured under glibc 2.36 and musl
  1.2.5 by `data-raw/oracle-libc-linux.sh`, independent of any pipeline.

## Notes on the harness itself

- **Neither rocker image ships `git`**, and the clone works anyway: GitLab's
  docker executor clones with its helper image rather than the build image. This
  was an open question when `.gitlab-ci.yml` was written and is recorded so it is
  not re-investigated.
- **`glab ci lint` rejected the first draft.** A plain YAML scalar may not
  contain `": "`, and the `vctrs` assert calls `message("vctrs: ", v)`. Every
  command in `before_script` and `script` is a literal block scalar for that
  reason.
- **`.rlib/` is `R_LIBS_USER`**, and it has to live under the project directory
  because that is the only thing GitLab's cache can carry — which puts a package
  library inside the package root while `R CMD build` runs. It is in both
  `.Rbuildignore` and `.gitignore` accordingly.
- **The cache is a speed optimisation, never a correctness input.** It is keyed
  on `DESCRIPTION`, and shared-runner caches are best-effort and frequently cold.
  Every job asserts `vctrs >= 0.7.0` before checking anything, so a stale cache
  serving 0.6.5 cannot turn `RADD-vppmbsia` into a fresh platform finding.
- **The devel job is scheduled or manual, not per-merge-request**, and the reason
  is cost rather than value: 528s against the release job's 115s, because every
  dependency is a source build on a free-tier minute budget.

## Reproducing

```sh
glab ci run -b <branch>          # runs both jobs, whatever the branch rules say
glab api projects/85027325/pipelines/<id>/jobs
glab api projects/85027325/jobs/<job-id>/trace
```

Pipelines run on merge requests, on pushes to `main` and `dev`, on schedules, and
when started by hand from the UI or the API. A branch push with a merge request
already open does not run twice.
