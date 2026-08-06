#!/bin/sh
# The verify chain, in one place: floor drift, then lintr, then spelling, then
# R CMD check --as-cran. Fail-fast, in that order.
#
#     sh data-raw/verify.sh              # the whole chain
#     NO_MANUAL=1 sh data-raw/verify.sh  # skip the PDF manual
#
# WHY THIS FILE EXISTS. The chain had two definitions and was acquiring a third.
# .pre-commit-config.yaml carried it inline as one long argv element, and
# .github/workflows/R-CMD-check.yaml restated it as a lint job plus a check job.
# Adding .gitlab-ci.yml as a third copy is how a claim like "the same chain CI
# runs" quietly stops being true -- nothing would have caught a drift between
# three hand-maintained copies except a reader comparing them. Both callers now
# invoke this script, so a change to the chain is one edit and every caller
# moves with it. RADD-fgciezpx asked for exactly this shape: each CI provider
# installs an environment and calls a repository script, which is also what
# makes a later migration back to GitHub small.
#
# WHY THE STEPS RUN SEPARATELY RATHER THAN AS ONE Rscript CALL. The hook's
# inline form chained them with `;` inside a single expression, so a lint
# failure and a check failure arrive looking alike. Three invocations under
# `set -e` fail in the same order with the same status but announce which step
# failed. The GitHub workflow reached the same conclusion by other means: it
# splits `verify` into its own job so "a lint or spelling failure is legible
# immediately rather than being found five times in parallel across the matrix".
#
# WHY NO_MANUAL IS A KNOB AND NOT A DEFAULT. `--no-manual` skips the PDF manual,
# which needs a LaTeX toolchain. CI images do not carry one and gain nothing
# from it, so both workflows pass it; the pre-push hook does NOT, because the
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
# Requires R with lintr, spelling and rcmdcheck installed, plus the package's
# own declared closure. Nothing is written inside the working tree: rcmdcheck
# builds and checks under a temporary directory of its own choosing, which
# matters because `tmp/` is gitignored but not Rbuildignored and would reach
# `R CMD check` as a "non-standard things in the check directory" NOTE.

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

echo "==> lintr::lint_package()"
Rscript -e 'lints <- lintr::lint_package(); if (length(lints)) { print(lints); quit(status = 1) }'

# spelling::spell_check_package() is what RADD-bxjyndha wired in to stop the
# Language: en-US field in DESCRIPTION from being an unguarded claim. It runs
# here as well as in tests/spelling.R because that test skips on CRAN and under
# rcmdcheck, neither of which sets NOT_CRAN; this call is the authoritative one.
echo "==> spelling::spell_check_package()"
Rscript -e 'words <- spelling::spell_check_package(); if (nrow(words)) { print(words); quit(status = 1) }'

echo "==> rcmdcheck::rcmdcheck(args = $CHECK_ARGS, error_on = \"warning\")"
Rscript -e "rcmdcheck::rcmdcheck(args = $CHECK_ARGS, error_on = \"warning\")"
