# raddr architecture

The design record, with the decisions, invariants and the reasoning behind
them, is [`docs/architecture.md`](https://gitlab.com/bart-turczynski/raddr/-/blob/main/docs/architecture.md). Read it before
changing the API.

## Layout

- `R/`: the package source. `man/` and `NAMESPACE` are roxygen2 output.
- `tests/testthat/`: the testthat suite, including the bundled
  web-platform-tests URL corpus under `fixtures/`.
- `vignettes/`: long-form documentation.
- `inst/extdata/`: the bundled IANA registry snapshots.
- `data-raw/`: the verify chain (`verify.sh`), measurement scripts, oracles
  and the scripts that build the bundled data.
- `bench/`: benchmarks.
- `docs/`: durable project notes and run transcripts. Not the pkgdown site,
  which builds into `public/`.
- `scripts/`: the citation, BugReports and toolchain gates shared with the
  rest of the fleet.
