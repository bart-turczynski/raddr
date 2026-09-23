# raddr

R package. Reports what an IP address literal means under each standard and implementation that disagrees about it, and classifies parsed values against the IANA special-purpose registries. Pure R, offline.

**Shower, not protector.** Output is facts and reason codes — never an allow/deny verdict or a risk score. A *dialect* is one reading of a literal (`strict`, `whatwg`, `pton`, `aton`), not a locale.

Verify with `sh data-raw/verify.sh`: floor drift, lintr, spelling, `rcmdcheck --as-cran`. The pre-push hook and `.gitlab-ci.yml` both call that one file. Each clone runs `pre-commit install && pre-commit install --hook-type pre-push` once.

Before implementing, load the issue with `fp context <id>`; before creating one, check `fp tree` for duplicates.

Planning notes stay in `_scratch/`, uncommitted alongside `.fp/`. Transcripts under `docs/` record what was true when the run happened; never edit one to match a later state. Remaining `github.com` strings are third-party provenance or transcripts, and stay.

For the epistemic rules this project works by, see `docs/working-method.md`.
For the verify gate, CI, and what neither covers, see `docs/verification-gates.md`.
For remotes, mirrors, bundles and the tracker snapshot, see `docs/remotes-and-backups.md`.
For design decisions, see `docs/architecture.md`.

## A red gate on an untouched tree

Toolchain drift makes the verify gate go red on a tree nobody changed, and it
looks exactly like a defect in the change being made. `scripts/check-toolchain.R`
runs ahead of the expensive step and names it in one line: roxygen2's installed
version against this package's `Config/roxygen2/version`, and any installed
package built under a newer R than the one running. Both have happened, and both
cost an afternoon (SEOR-tcytizic).

If that check passes and the gate is still red on a tree you have not touched,
say so and keep the evidence rather than assuming your change caused it.

@FP_AGENTS.md
