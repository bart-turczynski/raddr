# Continuous integration

raddr runs fleet-ci's tiered CI (seor ADR 0012) since the fleet-ci migration
(`SEOR-aukvuvtw`, 2026-10-30). `.gitlab-ci.yml` includes fleet-ci's
`templates/r-package.yml`, pinned by commit SHA (v1.2.4), and sets only
package variables plus one `x-*` job, `x-floor`; `.fleet-ci.yml` holds the
local gate's settings, and `.fleet-ci/` is fleet-ci's vendored gate (re-run
fleet-ci's `bin/vendor`, never edit it). The job names below are the
template's. The former shape, `data-raw/verify.sh` run by a `verify` pre-push
hook and by `check:linux-release` on every push to `main`, is recorded in
`docs/verification-gates.md`.

| Tier | Where | What runs |
| --- | --- | --- |
| hygiene hooks | pre-commit, at commit and at push | `.pre-commit-config.yaml`. At commit: the hygiene fixers (end of file, trailing whitespace, line endings; fixtures and `.fleet-ci/` excluded), the large-file, merge-conflict, YAML and case-conflict checks, codespell, and `floor-drift` when a floor input changes. At push: codespell again, the citation, BugReports, NEWS-terseness and toolchain checks, the `check-news.py` self-test when that script changes, and the `fleet-ci-hook-installed` check (refuses the push when fleet-ci's hook is not installed) |
| T0 | every push whose diff against `main` is docs-only (`docs/**/*.md`, `design/**/*.md`, `_pkgdown.yml`, minus `.fleet-ci.yml`'s `docs_exclude`), locally, the pre-push hook | the gate's docs tier, `.fleet-ci/gate` in the fleet image (`fleet-r`): spelling, the pkgdown destination check and `pkgdown::check_pkgdown()` |
| T1 | every other push, locally, the pre-push hook | the gate's full tier: T0's checks, then floor drift with its self-test (`data-raw/check-floor-drift.R`), lintr, docs drift (`scripts/check-docs-drift.R`), the URL check (`data-raw/check-urls.R`), README drift (`scripts/check-readme-drift.sh`), the NEWS heading (`scripts/check-news-version.R`), and one `R CMD check --as-cran --no-manual` (`NOT_CRAN=true`, incoming checks off) that fails on an ERROR, a WARNING, a failed test or a skip not on `allowed_skips` |
| T2 | the weekly `deep-check` schedule; every T3 run | `t2-check-release`, `t2-check-oldrel`, `t2-check-devel`, `x-floor` (R 4.1.3, in place of `t2-floor`), `t2-locale` (`R CMD check` under `LC_ALL=C`), `t2-ascran` (incoming and URLs on), `coverage` (fails below 95%), `osv-audit`, `security-audit`, `citation-version` |
| T3 | a `RELEASE=1` web pipeline on `main`; a `v*` tag | all of T2 plus `t3-manual` (the PDF manual); the tag, or `RELEASE=1` on a tag, adds `pages` |

Pushes to `main` or a branch, merge requests and API pipelines (`glab ci run`)
create no pipeline at all, and neither does a web pipeline without
`RELEASE=1` (or `PAGES=1` on a tag). An empty pipeline list is not a pass:
the merge gate is the local gate (T0 or T1), run before the branch leaves the
machine.

## Before a CRAN release

1. Start T3 on `main` from **Build > Pipelines > Run pipeline**, ref `main`,
   variable `RELEASE=1`. API pipelines create nothing. `PAGES=1` on a `v*`
   tag runs `pages` alone.
2. Run `sh data-raw/check-matrix.sh > docs/check-matrix.md` on the Mac. Its
   host row is the only macOS check left: the former `verify` hook ran
   `R CMD check --as-cran` on the macOS host before every push, and the
   gate now runs in a Linux container.
3. The R-hub amd64 run, win-builder and the dependency-floor re-measurement,
   as `docs/verification-gates.md` gives them (*Linux amd64 is checked at
   release*, *Dependency floors are re-measured at release*).

## The hook, once per clone

```sh
pre-commit install
.fleet-ci/pre-push --install
```

`pre-commit install` writes both hook types (`default_install_hook_types`);
`.fleet-ci/pre-push --install` then replaces the pre-push one with
fleet-ci's, which runs the gate on each pushed ref's tip and then the
pre-commit pre-push stage. Two commands drop it: `pre-commit install -f`, and
`pre-commit install -f --hook-type pre-push`; re-run the install after
either. Without `-f`, `pre-commit install` (with or without
`--hook-type pre-push`) moves the hook to `hooks/pre-push.legacy`
(pre-commit's migration mode), which still runs the gate first; `-f
--hook-type pre-commit` leaves it alone. `.fleet-ci/gate auto` runs the gate
by hand on `HEAD`. A pass is stamped by tree, tier, classifier version, image
and (full tier) resolved dependency lock, and a stamped commit is skipped.
The gate refuses a push carrying more than one ref to `main`, and a push to
`main` that adds more than one first-parent merge.

The gate checks the pushed commit, exported from git, never the working
tree, so an uncommitted fix cannot pass it (the former docs-drift step
worked on a `git archive` export for the same reason). It needs a running
Docker daemon and the registry login (`docker login registry.gitlab.com`;
seor ADR 0013).

The gate skips a push to a local mirror: when the push URL is local by
git's rule (the `backup` remote's path, or `file:///` with an empty host) it
prints `gate: skipped, <remote> is a local mirror` and exits 0. Under
pre-commit's migration mode the skip ends only the gate's hook, and the
pre-commit pre-push stage still runs, so `data-raw/mirror-drain.sh` still
pushes the mirror with `--no-verify`: a backup must never be stopped by a
lint failure or need the network.

## The NOTE policy

An `R CMD check` NOTE fails nothing, as before: the former verify failed on
an ERROR or a WARNING only (`error_on = "warning"`, no NOTE list), so
`.fleet-ci.yml` sets no `allowed_notes`. That holds in T1 and in the three
T2 legs that would apply the list (`t2-check-release`, `t2-check-oldrel`,
`t2-check-devel`); `t2-ascran`, `t2-locale`, `t3-manual` and `x-floor` never
apply it. Read `t2-ascran`'s NOTEs, the only leg with the incoming
feasibility and URL checks, before a submission.

## Project settings CI depends on, which are not in this repository

These live in GitLab's project settings, so a clone does not carry them:

- **Pipeline schedule 4467064** (Build > Pipeline schedules), "Weekly deep
  check (fleet standard)", `0 21 * * 2` Europe/Warsaw on `main`, carrying
  `SCHEDULE_KIND=deep-check` (read back 2026-10-30). Required: it is T2's only
  unattended run, and every pipeline on `main` carries `coverage`, so the
  coverage badge reads it.
- **Pipeline schedule 4472813**, `SCHEDULE_KIND=dependency-audit`. The
  template starts no pipeline for it any more (the audits run in T2); its
  removal is owner-gated.
- **`OSSINDEX_USER` / `OSSINDEX_TOKEN`** (Settings > CI/CD > Variables;
  `OSSINDEX_TOKEN` masked; the user is the literal `x`). `security-audit`
  sets `OSSINDEX_AUDIT_REQUIRED=true`, so without them it fails rather than
  passing having audited nothing.
- **fleet-ci's job token allowlist** must admit raddr, or every fleet image
  pull fails (fleet-ci README, "The registry is private").
- **Shared runners off** (`shared_runners_enabled: false`, read back
  2026-10-30). The template's jobs carry no `tags:`, so the project runner,
  which accepts untagged jobs, is the only place they can land.
- **`pages_access_level: enabled`**: the site lives at
  `https://bart-turczynski.gitlab.io/raddr/`, which `_pkgdown.yml` and
  `DESCRIPTION` name. `pages` publishes pkgdown's `destination`, `site/`
  (`docs/` is hand-written project context, never the site), with only the
  top-level `.md` files on `.fleet-ci.yml`'s `pages_keep`; the gate's docs
  tier checks that destination too.

Never set `SCHEDULE_KIND` as a project or group variable: every schedule
would inherit it.

## Gaps accepted in the fleet-ci migration

- **The floor leg is `x-floor`, not the template's `t2-floor`
  (`FLEET_FLOOR: "false"`).** `t2-floor` installs into a bare
  `rocker/r-ver:4.1.3` with no apt step, and that image has no curl binary:
  every R curl since 7.0.0 wants libcurl >= 7.73, focal has 7.68, and curl's
  configure then fetches a static libcurl with that binary or fails.
  rcmdcheck, oysteR and rosv all need curl. `x-floor` (on `.t2-job`) keeps
  the former `deep-check:floor` install (the 2026-04-21 p3m snapshot, the
  apt line, every Suggests package, the vctrs assert) and runs
  `R CMD check --as-cran` with incoming off; `.gitlab-ci.yml` has the
  detail. Unlike the former leg it builds no vignettes (no pandoc in the
  image), runs no lintr, spelling, URL or floor-drift step (T1 runs them,
  whatever the R version), and keeps no library cache, so each weekly run
  installs the closure from source.
- **No sanitizer leg (`FLEET_SANITIZERS: "false"`).** raddr has no compiled
  code; the former CI had none either.
- **`--as-cran` runs on R release only.** The former `deep-check` legs ran
  `data-raw/verify.sh`, so `R CMD check --as-cran` with incoming on, under R
  release, oldrel (4.5) and devel. The template's `t2-check-release`,
  `t2-check-oldrel` and `t2-check-devel` run `--no-manual` without
  `--as-cran`, so on a current R only `t2-ascran` (release) runs `--as-cran`;
  besides it, only `x-floor` (R 4.1.3) does, with incoming off. An
  `--as-cran`-only finding on oldrel or devel now surfaces at win-builder,
  or at CRAN.
- **No incoming check before a merge.** The former hook ran `--as-cran`
  with incoming on, on the host, before every push; T1's check runs with
  `_R_CHECK_CRAN_INCOMING_=false` and `_R_CHECK_CRAN_INCOMING_REMOTE_=false`.
  The incoming feasibility and URL checks run in `t2-ascran` (T2 and T3),
  and `data-raw/check-urls.R` still checks every declared URL in T1.
- **The live OSS Index audit runs in every suite-running job with
  `NOT_CRAN=true`, not only in `security-audit`.** T1 and the T2 check legs
  set `NOT_CRAN=true`, where the former verify left it unset, so
  `skip_on_cran()` no longer keeps `test-security.R`'s audit test out. In
  `t2-check-release`, `t2-check-oldrel`, `t2-check-devel`, `t2-locale` and
  `t3-manual` it finds `OSSINDEX_USER` and `OSSINDEX_TOKEN` (project
  variables reach every job they are not scoped away from) and calls OSS
  Index, and `test-osv.R` calls osv.dev. An OSS Index outage, an HTTP 429,
  a new advisory, or the shutdown of the endpoint oysteR 0.1.4 calls
  (2026-12-31) turns all of them red, and on a `v*` tag that blocks
  `pages`. Scoping the credentials to the audit job is a fleet follow-up
  (seor SEOR-yrsmlrvp).
- **T1 drops `test-security.R`'s two offline tests.** `exclude_tests` drops
  the whole file, so the allow-list well-formedness test and the validator's
  rejection test no longer run before a push; they run in T2. Moving them
  into a file of their own changes `tests/`, so it is a follow-up.
- **No server-side drift checks.** The former `check:linux-release`,
  `readme`, `news-version` and `citation-version` jobs ran the whole verify
  chain (floor drift, lintr, spelling, docs drift, URLs), README drift, the
  NEWS heading, `check-citation.py`, `check-bugreports.py` and
  `check-news.py` on every push to `main`, which caught a web edit and a
  `--no-verify` push. Those runs are gone; only the local gate and the
  pre-push hooks run them, and T2's `citation-version` runs
  `check-citation.py` alone. The validators that read the former CI are
  retired with it: `data-raw/check-libpaths-fix.R` (no job keeps an R
  library cache) and `data-raw/check-agent-md-filter.R` (the `pages` keep
  list is `.fleet-ci.yml`'s `pages_keep`, which the template enforces).
- **No runner tag.** The former CI's `default: tags: [local-docker]` is
  gone: the template sets no `tags`, and rules-sim refuses a package
  `default:`. That is safe because shared runners are off for raddr
  (`shared_runners_enabled: false`, read back with a project GET on
  2026-10-30): an untagged job has only the project runner to land on, and
  that runner accepts untagged jobs. If shared runners were ever enabled,
  jobs could land on GitLab's SaaS runners instead.
- **The NOTE policy is unchanged, so no NOTE fails anything** (see "The
  NOTE policy" above). The gate's check reports one NOTE today, a
  `spelling.Rout.save` comparison difference in how the fleet image's R
  echoes `tests/spelling.R`'s comment lines; the former hook on the macOS
  host saw none. Re-saving that file changes `tests/`, a follow-up.
- **The PDF manual is checked in T3 only.** The former hook built it on
  every push (the host has LaTeX; `NO_MANUAL` was unset there); the gate
  checks `--no-manual` (`fleet-r` has no TeX), and `t3-manual` builds it in
  `fleet-r-tex`.
- **macOS is checked before a release only.** The former hook ran on the
  macOS host; the gate runs in a Linux container, so `data-raw/check-matrix.sh`'s
  host row, run before a CRAN release, is the only macOS check left.
- **`t2-locale`'s leg runs under `LC_ALL=C`**, the template's default, which
  the former CI never ran (it had no locale leg, and neither did the
  hook). It passed, tests included (one NOTE, the `spelling.Rout.save`
  difference), when run once through the gate on a throwaway commit
  (`locales: [en_US.UTF-8]`, `locale_legs: [C]`, 2026-10-30): under `C`,
  `R CMD check`'s syntax check switches to `en_US.UTF-8` for the UTF-8
  sources, which CI's image ships and the gate's own locale directory holds
  only when listed. The gate itself runs no locale leg, to keep T1 at one
  `R CMD check`.
- **`pages` deploys from a `v*` tag only**, not on every push to `main`, so
  the site documents the release CRAN serves. The template moves an
  unlisted top-level `.md` out of the site's source with `file.rename()` and
  does not check that the move happened; on this runner that call failed
  once before ("Invalid cross-device link", 2026-09-23) and the former job
  published `AGENTS.html` until its copy-then-unlink fix and the
  `check-agent-md-filter.R` pin. Check the first tag's site for
  `AGENTS.html` and `CLAUDE.html`.
- **No CI run of a branch.** The former web pipeline on any ref ran
  `check:linux-release` against a branch; the template admits a web pipeline
  only with `RELEASE=1` on `main` or a tag.
- **The dependency audits run weekly in T2 and in every release pipeline**,
  no longer on their own `dependency-audit` schedule, which now starts no
  pipeline.
- **Comments in `tests/` still name the former hook and jobs**
  (`tests/spelling.R`, `test-osv.R`, `test-security.R`); a CI migration
  edits neither `tests/` nor its saved output.
- **Pandoc** comes from the fleet image (`.fleet-ci/toolchain`, 3.10), which
  reproduces the committed `README.md`. `scripts/check-toolchain.R` checks a
  local pandoc against it, so a local `build_readme()` writes what the gate
  accepts.
