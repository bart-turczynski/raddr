# Agent Instructions

Use committed docs for durable project knowledge. Keep raw planning notes, temporary context, and generated scratch work in `_scratch/`.

Do not commit `_scratch/`, `.fp/`, secrets, dependencies, build outputs, or local caches.

## Git hygiene

This project uses the [pre-commit](https://pre-commit.com) framework. Its config (`.pre-commit-config.yaml`) is cloned with the repo; each clone enables the hooks once:

```bash
pre-commit install && pre-commit install --hook-type pre-push
```

`pre-commit` is a Python tool. For non-Python templates, install it with `uv tool install pre-commit` or `pipx install pre-commit`.

### Per-commit checks

On every commit, lightweight hooks run: end-of-file fixer, trailing-whitespace trimming, merge-conflict detection, YAML/TOML validation, mixed-line-ending and case-conflict guards, and `check-added-large-files` — a portable 5 MB size guard that blocks accidentally committing heavy blobs (a big blob bloats `.git` history even after deletion).

### Pre-push verify gate

On `git push`, the `verify` hook runs the project's verify command: `lintr::lint_package()`, then `spelling::spell_check_package()`, then `rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "warning")`. Server-side branch protection is unavailable on this GitHub plan, so this local pre-push gate is the stand-in for branch protection.

`.github/workflows/R-CMD-check.yaml` mirrors that chain across platforms. **It has never run.** It was written on 2026-07-31, and the repository has had no reachable remote since 2026-07-20, so until a first successful push the local hook is not a stand-in for CI — it is the only gate there is. This file previously described the hook's chain as "the same chain CI runs" while no `.github/` directory existed at all; the workflow now exists so that sentence becomes true on the first push rather than remaining a claim with nothing behind it. It has since been linted statically: actionlint 1.7.12 reports zero problems, and the three judgement calls actionlint cannot make — an `http-user-agent` key set on the r-devel matrix row only, `needs: lint` against a DESCRIPTION carrying no `Config/Needs` field, and `--no-manual` in CI but not in the hook — were each resolved against the `r-lib/actions` sources and found correct as written, with `docs/ci-workflow-lint.md` as the transcript (`RADD-ushiurrv`). That makes the file well-formed and its inputs understood; it does not make it exercised.

#### What the local gate does not cover

The hook checks whatever host invokes it, which for the whole of 0.1.0's development was **one platform and one R version**: macOS arm64 (Darwin 25.4.0) on R 4.6.0. CRAN checks Windows, Linux and r-devel. That gap cannot be closed locally, and it is worth stating rather than discovering at submission.

Two qualifications, because the gap is narrower than "single platform" suggests and also wider in one specific place:

- **Narrower than it sounds for semantics.** The package's platform-varying behavior is already measured rather than assumed. The reality dialects model Apple's libc deliberately (architecture §3.1), and `data-raw/oracle-libc-linux.sh` runs the same oracles under glibc 2.36 and musl 1.2.5 with `tests/testthat/test-libc.R` asserting the divergence set (§3.3.0). So a cross-platform CI failure would be a build or check-mechanics failure, not a wrong address reading — the readings have three libcs behind them already.
- **The declared R floor is now measured, and it holds.** `DESCRIPTION` declares `Depends: R (>= 4.0.0)`, and `data-raw/check-r-floor.sh` runs `R CMD check --as-cran` against exactly that on x86_64 Linux: **Status OK, 0 errors, 0 warnings, 0 notes**, vignettes re-building and the full suite passing. The transcript is `docs/r-floor-check.md` (`RADD-dcquzofl`). The workflow's `oldrel-1` and `oldrel-2` entries still only probe toward the floor without reaching it, so that script — not CI — is what stands behind the number.
- **The gap that actually bit was dependency versions, not platform or R version.** Worth recording as its own axis, because nothing above covers it and it is where the one real correctness bug in 0.1.0 came from. The gate checks whatever *dependency versions* the host happens to have, which for the whole of 0.1.0 meant one set. `Imports: vctrs` carried no version floor, and vctrs < 0.7.0 modifies `vctrs_rcrd` types in place in `vec_assign()` — so `addr_reading(p, "curl")` silently corrupted the record, on every R version, for anyone holding the vctrs that was current on CRAN from 2023-12-02 to 2026-01-16 (`RADD-vppmbsia`, fixed by declaring `vctrs (>= 0.7.0)`). Two lessons stick. A dated snapshot pin freezes the *entire* closure, not just R, so a run that varies the pin is not varying one thing and cannot attribute a failure to R alone. And an unversioned `Imports:` entry is the same shape of unguarded claim as the R floor was: it asserts "any version works" and nothing checks it.

### Backups, while there is no reachable remote

`origin` returns HTTP 403 (account suspended since 2026-07-20), so pushing is not available and the repository lives on one disk. Two local layers stand in, following the convention already used by sibling repos in `~/Projects/_backups/`:

- A `--mirror` clone at `~/Projects/_backups/raddr.git`, wired as the `backup` remote. Refresh with `git push backup --all && git push backup --tags`.
- Timestamped full bundles, `raddr_<branch>_<YYYYmmdd-HHMMSS>.bundle`, written with `git bundle create <path> --all` and checked with `git bundle verify`. A bundle is a single self-contained file holding every ref, so it is the copy to move off the machine.

Both are on the same physical disk as the working tree, which protects against a bad rebase but not against losing the disk. Moving a bundle off-machine is a manual step and remains one.

### The tracker is not in git unless it is snapshotted

`.fp/` is gitignored, so no commit, bundle or clone contains the issue tracker — while `docs/architecture.md` cites `RADD-*` ids throughout as the evidence behind its decisions. Run `sh data-raw/snapshot-tracker.sh` to regenerate `docs/tracker-snapshot.md`, which is the only copy of that reasoning in git. Refresh it before taking a bundle you intend to keep. `fp` stays authoritative; the snapshot is a backstop, and it is overwritten wholesale on every run.

@FP_AGENTS.md
