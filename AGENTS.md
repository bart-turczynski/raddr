# raddr

R package. Reports what an IP address literal means under each standard and implementation that disagrees about it, and classifies parsed values against the IANA special-purpose registries. Pure R, offline.

**Shower, not protector.** Output is facts and reason codes — never an allow/deny verdict or a risk score. A *dialect* is one reading of a literal (`strict`, `whatwg`, `pton`, `aton`), not a locale.

## Verification

Gate: local
Verify: .fleet-ci/gate auto

The merge gate is fleet-ci's local gate, run in the fleet image by the pre-push hook (install it once per clone with `pre-commit install`, then `.fleet-ci/pre-push --install`); its settings are `.fleet-ci.yml`. Until it is installed, the warn-only `fleet-ci-hook-installed` hook prints a WARNING on every push, which then ran only the hygiene hooks. A diff against `main` that the classifier calls docs-only (`docs/**/*.md` and the like, minus `.fleet-ci.yml`'s `docs_exclude`) gets T0, spelling and `pkgdown::check_pkgdown()`; any other gets T1, the cheap gates (floor drift, lintr, docs drift, the URL, README and NEWS-heading checks) and one `R CMD check --as-cran`.
Branch pushes, merge requests and pushes to `main` create no pipeline, and an empty pipeline list is not a pass. CI runs fleet-ci's template: T2 on the weekly `deep-check` schedule, T3 on a `RELEASE=1` web pipeline and on the `v*` tag (seor ADR 0012; `design/ci.md` has the event table and the gaps). The declared dependency floors are re-measured at release, not in the gate: see `docs/verification-gates.md`, *Dependency floors are re-measured at release*. The R floor is the exception: it follows the fleet rule (oldest R minor the CI can test) and T2's `x-floor` job tests it.

The gate refuses a push to `main` that adds more than one first-parent merge, and skips a push to the local `backup` mirror (its URL is a path). `sh data-raw/mirror-drain.sh` still pushes the mirror with `--no-verify`, for the pre-commit hooks: an agent asks the owner before running it (a gate bypass is confirm-first).

## Working rules

Before implementing, load the issue with `fp context <id>`; before creating one, check `fp tree` for duplicates. Git follows the house `agent-workflow` skill, and fp status changes stay decoupled from git (the `fp` skill's `references/decoupling.md`).

A NEWS.md bullet is one terse line: one source line, at most 32 words, only for a change a package user acts on or notices (behavior, API, dependencies, R or system requirements, installation). Where a standard decides the change, cite the clause in a few words, such as "(RFC 4291 §2.5.5)"; the reasoning goes in the issue. At most one issue or MR reference, at the end. No bullet for housekeeping (CI, gates, lint, spelling, metadata, agent files) and no Internal section. The `news-terse` pre-push hook enforces it.

Planning notes stay in `_scratch/`, uncommitted alongside `.fp/`. Transcripts under `docs/` record what was true when the run happened; never edit one to match a later state. Remaining `github.com` strings are third-party provenance or transcripts, and stay.

For the epistemic rules this project works by, see `docs/working-method.md`.
For the tiers, the hook and the gaps the fleet-ci migration accepted, see `design/ci.md`.
For the history of the verify gate and CI, and what neither covers, see `docs/verification-gates.md`.
For remotes, mirrors, bundles and the tracker snapshot, see `docs/remotes-and-backups.md`.
For design decisions, see `docs/architecture.md`.

## A red gate on an untouched tree

The gate runs in the image the fleet-ci pin names, so this machine's R
library cannot turn it red. A dependency that moved on CRAN can: the gate
resolves the dependencies afresh on every run. The pre-push
`check-toolchain` hook (`scripts/check-toolchain.R`) still checks this
machine, roxygen2 and pandoc against the pins, so that a local
`devtools::document()` or `build_readme()` writes what the gate accepts
(SEOR-tcytizic).

If the gate is red on a tree you have not touched, say so and keep the
evidence (`FLEET_GATE_KEEP=<dir>` keeps the container's output) rather than
assuming your change caused it.
