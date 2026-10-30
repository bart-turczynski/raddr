# raddr architecture

The design record, with the decisions, invariants and the reasoning behind
them, is [`docs/architecture.md`](https://gitlab.com/bart-turczynski/raddr/-/blob/main/docs/architecture.md). Read it before
changing the API.

## Layout

- `R/`: the package source. `man/` and `NAMESPACE` are roxygen2 output: edit
  the roxygen comments in `R/` and regenerate with `devtools::document()`.
- `tests/testthat/`: the testthat suite, including the bundled
  web-platform-tests URL corpus under `fixtures/`.
- `vignettes/`: long-form documentation, built into the pkgdown articles.
- `DESCRIPTION`: package metadata and dependencies.
- `inst/extdata/`: the bundled IANA registry snapshots.
- `data-raw/`: the floor-drift and URL checks the local gate runs,
  measurement scripts, oracles and the scripts that build the bundled data.
- `bench/`: benchmarks.
- `docs/`: durable project notes and run transcripts. Not the pkgdown site,
  which builds into `site/`.
- `scripts/`: the citation, BugReports, NEWS, toolchain, docs-drift,
  README-drift and hook checks shared with the rest of the fleet.
- `.fleet-ci/` and `.fleet-ci.yml`: fleet-ci's vendored local gate and its
  settings (`docs/ci.md`). Re-run fleet-ci's `bin/vendor`; never edit
  `.fleet-ci/`.
