#!/bin/sh
# The verify chain, in one place: floor drift, then lintr, then spelling, then
# roxygen docs drift, then the URL check, then R CMD check --as-cran.
# Fail-fast, in that order.
#
#     sh data-raw/verify.sh              # the whole chain
#     NO_MANUAL=1 sh data-raw/verify.sh  # skip the PDF manual
#     NO_DOCS_DRIFT=1 sh data-raw/verify.sh  # skip the docs-drift step
#
# WHY THIS FILE EXISTS. The chain had two definitions and was acquiring a
# third. .pre-commit-config.yaml carried it inline as one long argv element,
# and .github/workflows/R-CMD-check.yaml -- deleted 2026-09-05, RADD-ithxwzpr
# -- restated it as a lint job plus a check job. Adding .gitlab-ci.yml as a
# third copy is how a claim like "the same chain CI runs" quietly stops being
# true -- nothing would have caught a drift between three hand-maintained
# copies except a reader comparing them. Both callers now invoke this script,
# so a change to the chain is one edit and every caller moves with it.
# RADD-fgciezpx asked for exactly this shape: each CI provider installs an
# environment and calls a repository script, which is what keeps a move to any
# other provider small. That property is why deleting the GitHub workflow cost
# nothing: what a provider needs from this repository is one script, not a
# committed config for a host the project is not using.
#
# WHY THE STEPS RUN SEPARATELY RATHER THAN AS ONE Rscript CALL. The hook's
# inline form chained them with `;` inside a single expression, so a lint
# failure and a check failure arrive looking alike. Three invocations under
# `set -e` fail in the same order with the same status but announce which step
# failed. The since-deleted GitHub workflow reached the same conclusion by other
# means: it split `verify` into its own job so "a lint or spelling failure is
# legible immediately rather than being found five times in parallel across the
# matrix".
#
# WHY NO_MANUAL IS A KNOB AND NOT A DEFAULT. `--no-manual` skips the PDF manual,
# which needs a LaTeX toolchain. CI images do not carry one and gain nothing
# from it, so .gitlab-ci.yml passes it; the pre-push hook does NOT, because the
# host has the toolchain and the manual is one more thing --as-cran will check
# at submission. docs/ci-workflow-lint.md examined that asymmetry against the
# r-lib/actions sources and found it correct as written, so it is preserved here
# as an argument rather than flattened for tidiness. data-raw/build-release.sh
# remains what checks the manual on the release artifact itself.
#
# WHY rcmdcheck AND NOT `R CMD check` DIRECTLY. `error_on = "warning"` is the
# reason. The gate treats a WARNING as a failure, which a bare `R CMD check`
# exit status does not do -- it exits 0 on warnings. The container rows in
# data-raw/check-matrix.sh call `R CMD check` directly instead, and that is a
# deliberate difference: they exist to TRANSCRIBE a status line for a human to
# read, not to gate a push.
#
# Requires R with lintr, spelling, rcmdcheck and the roxygen2 that DESCRIPTION's
# Config/roxygen2/version pins installed, plus the package's own declared
# closure, and git outside CI. Nothing is written inside the working tree:
# rcmdcheck builds and checks under a temporary directory of its own choosing,
# which matters because `tmp/` is gitignored but not Rbuildignored and would
# reach `R CMD check` as a "non-standard things in the check directory" NOTE,
# and the docs-drift step regenerates into a throwaway export of its own.

set -eu

cd "$(dirname "$0")/.."

if [ "${NO_MANUAL:-0}" = 1 ]; then
    CHECK_ARGS='c("--as-cran", "--no-manual")'
else
    CHECK_ARGS='"--as-cran"'
fi

# FIRST, AND NOT BECAUSE IT IS THE MOST IMPORTANT. It is the cheapest -- it
# reads five files and compares strings -- and it is the only step here that
# checks the repository's own claims about itself rather than the package's
# code. `R (>= 4.0.0)` and `vctrs (>= 0.7.0)` are measured (RADD-dcquzofl,
# RADD-lfjdkynn) and nothing connected those measurements to the numbers they
# measure, so raising a floor silently reverted it to an unchecked declaration:
# the shape of RADD-vppmbsia. Running it here rather than only in the
# pre-commit hook is what puts it on the remote's side of the line, where
# .gitlab-ci.yml gates a merge request. RADD-olitgnsw.
#
# --self-test first, in the same invocation. The guard is green on this tree by
# construction -- the numbers it compares were copied into the files it reads --
# so eleven `ok` rows are also what a script stuck at OK would print. The
# self-test mutates a throwaway copy of the five files and requires the guard to
# reject each one. It costs nothing and it is the difference between evidence
# and a decoration.
echo "==> data-raw/check-floor-drift.R --self-test"
Rscript data-raw/check-floor-drift.R --self-test

# Same shape, same reason: a claim about .gitlab-ci.yml that nothing checked
# is exactly how SEOR-dyzgzyot's cache silently held nothing, and how a
# deny-list agent-file filter (SEOR-wqxhftpv) would silently start publishing
# a new agent file family. Both scripts read .gitlab-ci.yml as text -- no
# docker, no git subprocess, nothing this host or the CI image might not have.
echo "==> data-raw/check-libpaths-fix.R --self-test"
Rscript data-raw/check-libpaths-fix.R --self-test

echo "==> data-raw/check-agent-md-filter.R --self-test"
Rscript data-raw/check-agent-md-filter.R --self-test

echo "==> lintr::lint_package()"
Rscript -e 'lints <- lintr::lint_package(); if (length(lints)) { print(lints); quit(status = 1) }'

# spelling::spell_check_package() is what RADD-bxjyndha wired in to stop the
# Language: en-US field in DESCRIPTION from being an unguarded claim. It runs
# here as well as in tests/spelling.R because that test skips on CRAN and under
# rcmdcheck, neither of which sets NOT_CRAN; this call is the authoritative one.
echo "==> spelling::spell_check_package()"
Rscript -e 'words <- spelling::spell_check_package(); if (nrow(words)) { print(words); quit(status = 1) }'

# man/, NAMESPACE and DESCRIPTION must be what roxygen regenerates from R/. A
# stale .Rd is still valid .Rd, so neither lintr above nor the check below can
# see it: the logo sweep left man/raddr-package.Rd stale on main, found only by
# chance in raddr !85 (SEOR-nwfmerhu). Offline, so it runs ahead of the URL
# check.
#
# IT CHECKS THE COMMIT BEING PUSHED, ON A THROWAWAY EXPORT. roxygenise() writes
# into the tree it is given -- on drift it rewrites man/, NAMESPACE and maybe
# DESCRIPTION -- so run in place it would edit the developer's checkout
# mid-push and hand those edits to the rcmdcheck below. And a working tree
# answers the wrong question: a stale committed man/ passes when the fix is on
# disk but uncommitted, and an untracked man/*.Rd counts as present. So the
# step exports PRE_COMMIT_TO_REF (pre-commit sets it to the local sha a
# pre-push hook is pushing, and the hook's environment reaches this script),
# else HEAD, with `git archive` into a temporary directory, runs that commit's
# own scripts/check-docs-drift.R there, and removes the directory on every exit
# path, the traps covering a failure and an interrupt. The diff it prints on
# drift is the fix; devtools::document() in the checkout applies it.
#
# CI's images (rocker/r-ver) carry no git, so there, and only when CI=true, it
# runs on the job's checkout instead: that checkout IS the commit, nothing
# untracked sits in it that roxygen reads, and it is thrown away with the job.
# On drift the step exits 1, so the rewritten files never reach rcmdcheck; on
# a pass roxygen has written nothing, since DESCRIPTION is among the files it
# compares. Without git outside CI the step refuses rather than touch the tree.
#
# NO_DOCS_DRIFT=1 skips it, and only the deep-check legs set it. Drift is a
# property of the commit, not of the R version, so check:linux-release answers
# it once per pipeline; the legs vary R, and the floor leg's dated snapshot
# serves a roxygen2 older than the Config/roxygen2/version pin this gate
# requires. Same shape as NO_MANUAL: a knob CI passes, never a default.
if [ "${NO_DOCS_DRIFT:-0}" = 1 ]; then
    echo "==> scripts/check-docs-drift.R skipped (NO_DOCS_DRIFT=1)"
elif command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    docs_ref=${PRE_COMMIT_TO_REF:-HEAD}
    echo "==> scripts/check-docs-drift.R on a git-archive export of $docs_ref"
    docs_tmp=$(mktemp -d "${TMPDIR:-/tmp}/raddr-docs-drift.XXXXXX")
    trap 'rm -rf "$docs_tmp"' EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    # To a file, then extracted, not piped: POSIX sh has no pipefail, so a
    # failed `git archive | tar` would be judged by tar alone.
    git archive --format=tar -o "$docs_tmp/export.tar" "$docs_ref"
    mkdir "$docs_tmp/pkg"
    tar -xf "$docs_tmp/export.tar" -C "$docs_tmp/pkg"
    Rscript "$docs_tmp/pkg/scripts/check-docs-drift.R" "$docs_tmp/pkg"
    rm -rf "$docs_tmp"
    trap - EXIT HUP INT TERM
elif [ "${CI:-}" = true ]; then
    echo "==> scripts/check-docs-drift.R on the CI checkout (no git in this image)"
    Rscript scripts/check-docs-drift.R .
else
    echo "verify: the docs-drift step needs git to export the commit; it will not" >&2
    echo "verify: regenerate into this working tree. Install git, or set NO_DOCS_DRIFT=1." >&2
    exit 1
fi

# Every URL the package declares must resolve (the fleet standard's URL check,
# SEOR-lavybtkr). --as-cran fetches them too, but reports a dead one only as a
# NOTE, which error_on = "warning" lets through. Network, so it runs after the
# offline steps. data-raw/check-urls.R's header has the rules.
echo "==> data-raw/check-urls.R"
Rscript data-raw/check-urls.R

# rcmdcheck reads a check that halted partway as 0/0/0 and returns normally,
# so error_on never fires. The guard also fails on R CMD check's own exit
# status (SEOR-maavnxdm). It is single-quoted so the shell leaves `$status`
# alone; only $CHECK_ARGS is expanded.
echo "==> rcmdcheck::rcmdcheck(args = $CHECK_ARGS, error_on = \"warning\") + exit-status guard"
Rscript -e "res <- rcmdcheck::rcmdcheck(args = $CHECK_ARGS, error_on = \"warning\"); "'if (!identical(as.integer(res$status), 0L)) stop("R CMD check exited with status ", res$status, "; the run did not complete.", call. = FALSE)'
