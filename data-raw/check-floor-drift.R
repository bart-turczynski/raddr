#!/usr/bin/env Rscript
# Guard the floors DESCRIPTION DECLARES against the floors the transcripts
# under docs/ actually MEASURED, which is what open item RADD-olitgnsw asked
# for.
#
# Usage (from anywhere -- the package root is derived from this file's path):
#   Rscript data-raw/check-floor-drift.R
#
# WHY THIS EXISTS. Two declared floors are measured and both hold:
# `R (>= 4.0.0)` by data-raw/check-r-floor.sh (RADD-dcquzofl) and
# `vctrs (>= 0.7.0)` at exactly 0.7.0 by data-raw/check-dep-floor.sh
# (RADD-lfjdkynn). Nothing connected either measurement to the number it
# measures. Raise a floor in DESCRIPTION, or add an entry to Imports, and both
# transcripts go on reading `Status: OK` while describing a package that no
# longer exists -- the declaration quietly reverts to being checked by nothing,
# which is the exact shape of RADD-vppmbsia, the one real correctness bug in
# 0.1.0. What stood between here and there was a sentence in a tracker issue,
# in a directory git does not carry.
#
# WHAT THIS IS NOT. It re-runs nothing. No Docker, no network, no package
# closure -- it reads five files and compares strings, and it cannot tell you a
# floor is CORRECT. It tells you the transcript on disk was produced against
# the numbers now declared. A green run is a claim about provenance, not about
# R 4.0.0.
#
# WHAT IT CANNOT MECHANIZE, stated so RADD-olitgnsw is not read as discharged.
# Two of that issue's four triggers are file state and are now code: a raised
# floor, and a new Imports entry. Two are not. A dependency release that drops
# support for R 4.0.0 invalidates the floor without changing one byte of this
# repository, and a CRAN resubmission is an act rather than a state. Both need
# the network or a person, and the issue stays open carrying them.
#
# WHY EVERY ANCHOR MUST MATCH EXACTLY ONE LINE. A guard that silently stops
# matching is worse than no guard, because it reports OK forever and gives no
# sign why. Every extraction below fails loudly on zero matches and on two, so
# re-formatting a transcript breaks this script rather than blinding it.
#
# WHY EQUALITY AND NOT `>=` ON THE IMPORTS FLOORS. RADD-lfjdkynn's own finding:
# an earlier script asserted `>=`, installed vctrs 0.7.2, and produced something
# that looked like a floor measurement and was not one. A transcript showing a
# dependency ABOVE its declared floor is evidence the constraint is satisfiable,
# which was never the question.

paths <- c(
  description = "DESCRIPTION",
  r_script = "data-raw/check-r-floor.sh",
  dep_script = "data-raw/check-dep-floor.sh",
  r_doc = "docs/r-floor-check.md",
  dep_doc = "docs/dep-floor-check.md"
)

# The package root, derived from --file= rather than from the working directory,
# so a caller that has not cd'd into the root still gets the right files.
package_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  self <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  if (length(self) != 1L) {
    return(normalizePath(".", mustWork = TRUE))
  }
  normalizePath(file.path(dirname(self), ".."), mustWork = TRUE)
}

read_file <- function(root, key) {
  readLines(file.path(root, paths[[key]]), warn = FALSE)
}

# Exactly one line must match, and the pattern must carry exactly one capture
# group. Anything else is a file that moved out from under this script.
#
# `missing` is the one concession, and only imports_checks() uses it: a package
# absent from the transcript is an ordinary finding there -- it is what a NEW
# Imports entry looks like -- rather than evidence the transcript was
# reformatted. Two matches stays fatal in both callers, because a pattern that
# has become ambiguous is picking its answer arbitrarily.
anchor <- function(lines, pattern, where, missing = NULL) {
  hits <- regmatches(lines, regexec(pattern, lines, perl = TRUE))
  hits <- hits[lengths(hits) > 0L]
  if (length(hits) == 0L && !is.null(missing)) {
    return(missing)
  }
  if (length(hits) != 1L) {
    stop(
      sprintf(
        paste0(
          "anchor `%s` matched %d lines in %s; that file moved and ",
          "this script must move with it"
        ),
        pattern, length(hits), where
      ),
      call. = FALSE
    )
  }
  hits[[1L]][[2L]]
}

# Parse one Depends/Imports field into name -> declared floor. An entry with no
# version constraint yields NA, which is itself a finding: an unversioned
# Imports entry asserts "any version works" and is checked by nothing.
parse_deps <- function(field) {
  if (is.na(field) || !nzchar(trimws(field))) {
    return(character())
  }
  entries <- trimws(strsplit(field, ",")[[1L]])
  entries <- entries[nzchar(entries)]
  names <- sub("^([[:alnum:].]+).*$", "\\1", entries)
  floors <- rep(NA_character_, length(entries))
  versioned <- grepl(">=", entries, fixed = TRUE)
  floors[versioned] <- sub(
    "^[^(]+\\(\\s*>=\\s*([^)]+)\\).*$", "\\1", entries[versioned]
  )
  stats::setNames(trimws(floors), names)
}

check <- function(label, expected, actual, source) {
  list(label = label, expected = expected, actual = actual, source = source)
}

# One comparison: `expected` against whatever the anchor pulls out of the file
# named by `key`. Every row below is one of these, so the table of what is
# compared against what stays readable as a table.
check_anchor <- function(label, expected, root, key, pattern, missing = NULL) {
  check(
    label, expected,
    anchor(read_file(root, key), pattern, paths[[key]], missing),
    paths[[key]]
  )
}

# The R floor appears in five places and every one of them is a number a human
# typed. The docker image tags are included deliberately: check-dep-floor.sh
# builds on the image check-r-floor.sh leaves behind, so a bumped R floor that
# reaches only one of the two scripts produces a dependency transcript taken on
# the wrong R.
r_floor_checks <- function(root, r_floor) {
  list(
    check_anchor(
      "R floor measured", r_floor, root, "r_doc",
      "^R version ([0-9.]+) "
    ),
    check_anchor(
      "R floor under the dependency run", r_floor, root, "dep_doc",
      "^R version ([0-9.]+) "
    ),
    check_anchor(
      "R floor image base", r_floor, root, "r_script",
      "^FROM rocker/r-ver:(.+)$"
    ),
    check_anchor(
      "R floor image tag", r_floor, root, "r_script",
      "^IMAGE=raddr-rfloor:(.+)$"
    ),
    check_anchor(
      "R floor image reused", r_floor, root, "dep_script",
      "^BASE=\\$\\{BASE:-raddr-rfloor:(.+)\\}$"
    )
  )
}

# Every Imports entry, against the installed-package table the dependency
# transcript prints. Exact equality: see the header. The transcript lists the
# whole closure, so an entry absent from it is an entry that run never saw.
imports_checks <- function(root, imports) {
  lapply(names(imports), function(pkg) {
    floor <- imports[[pkg]]
    if (is.na(floor)) {
      return(check(
        sprintf("Imports: %s declares a floor", pkg),
        "a version floor", "no version constraint", paths[["description"]]
      ))
    }
    check_anchor(
      sprintf("Imports: %s measured at its floor", pkg), floor,
      root, "dep_doc", sprintf("^%s ([0-9][^ ]*)$", pkg),
      missing = "nothing -- that run never installed it"
    )
  })
}

# The vctrs floor is pinned twice more: once as the number check-dep-floor.sh
# downgrades to, and once as the number that run recorded having been asked for.
# Its own header says "change both together or the transcript stops meaning
# anything"; this is what makes that a check rather than an instruction.
vctrs_target_checks <- function(root, imports) {
  if (!"vctrs" %in% names(imports) || is.na(imports[["vctrs"]])) {
    return(list())
  }
  floor <- imports[["vctrs"]]
  list(
    check_anchor(
      "vctrs downgrade target", floor, root, "dep_script",
      "^VCTRS_TARGET=(.+)$"
    ),
    check_anchor(
      "vctrs target recorded", floor, root, "dep_doc",
      "^vctrs target: ([^ ]+) "
    )
  )
}

# A transcript that drifted into a failure is as stale as one taken against the
# wrong number, and neither script exits non-zero on a bad status -- both are
# redirected into their file, so the status line IS the result.
status_checks <- function(root) {
  list(
    check_anchor(
      "R floor run passed", "OK", root, "r_doc", "^Status: (.+)$"
    ),
    check_anchor(
      "dependency floor run passed", "OK", root, "dep_doc", "^Status: (.+)$"
    )
  )
}

passed <- function(checks) {
  vapply(checks, function(x) identical(x$expected, x$actual), logical(1))
}

report <- function(checks) {
  ok <- passed(checks)
  width <- max(nchar(vapply(checks, `[[`, "", "label")))
  for (i in seq_along(checks)) {
    x <- checks[[i]]
    cat(sprintf(
      "%-4s %-*s %s\n", if (ok[[i]]) "ok" else "DRIFT", width, x$label,
      if (ok[[i]]) x$actual else sprintf("expected %s, %s has %s",
                                         x$expected, x$source, x$actual)
    ))
  }
  if (all(ok)) {
    return(invisible(TRUE))
  }
  cat(
    "\nThe declared floors and the measured ones have diverged.",
    "A floor nothing has measured is an unchecked claim (RADD-vppmbsia).",
    "Re-run the affected script and refresh its transcript:",
    "",
    "  sh data-raw/check-r-floor.sh   > docs/r-floor-check.md",
    "  sh data-raw/check-dep-floor.sh > docs/dep-floor-check.md",
    "",
    "Both need Docker and are slow under emulation. Read the headers first:",
    "check-dep-floor.sh moves R and vctrs together, so a failure there does",
    "not attribute to either alone, and it carries a BASE= fallback that",
    "separates them. See RADD-olitgnsw.",
    sep = "\n"
  )
  cat("\n")
  invisible(FALSE)
}

run_checks <- function(root) {
  desc <- read.dcf(file.path(root, paths[["description"]]))[1L, ]
  depends <- parse_deps(desc[["Depends"]])
  imports <- parse_deps(desc[["Imports"]])
  if (!"R" %in% names(depends) || is.na(depends[["R"]])) {
    stop("DESCRIPTION declares no `Depends: R (>= ...)` floor", call. = FALSE)
  }
  c(
    r_floor_checks(root, depends[["R"]]),
    vctrs_target_checks(root, imports),
    imports_checks(root, imports),
    status_checks(root)
  )
}

# --- Proving the guard can disagree ------------------------------------------
#
# A guard that passes on every input is indistinguishable from a guard that
# passes on this one, and this one is green today by construction: the numbers
# were copied INTO the files it reads. tests/testthat/test-registry.R makes the
# same move for the snapshot id -- flip one hex digit and the id must move --
# and the reason is the same. Without the cases below, `ok` on eleven rows is
# also what a stuck script prints.
#
# The mutations are DERIVED from what DESCRIPTION currently declares rather than
# written as literals, so they keep working when the floors move, which is the
# one event this whole file exists for.

temp_root <- function(root) {
  dest <- tempfile("floor-drift-")
  for (dir in unique(dirname(paths))) {
    dir.create(file.path(dest, dir), recursive = TRUE, showWarnings = FALSE)
  }
  for (p in paths) {
    file.copy(file.path(root, p), file.path(dest, p))
  }
  dest
}

mutate <- function(root, key, from, to) {
  target <- file.path(root, paths[[key]])
  lines <- readLines(target, warn = FALSE)
  hit <- grep(from, lines, fixed = TRUE)
  if (length(hit) == 0L) {
    stop(sprintf("self-test cannot find `%s` in %s", from, paths[[key]]),
      call. = FALSE
    )
  }
  lines[hit] <- gsub(from, to, lines[hit], fixed = TRUE)
  writeLines(lines, target)
  root
}

# TRUE green, FALSE drift, NA an anchor that stopped matching. Only TRUE is a
# failure of the self-test: the other two are the guard doing its job.
outcome <- function(root) {
  tryCatch(all(passed(run_checks(root))), error = function(e) NA)
}

outcome_label <- function(x) {
  if (is.na(x)) {
    "anchor lost"
  } else if (x) {
    "green"
  } else {
    "drift"
  }
}

self_test <- function(root) {
  desc <- read.dcf(file.path(root, paths[["description"]]))[1L, ]
  r_floor <- parse_deps(desc[["Depends"]])[["R"]]
  imports <- parse_deps(desc[["Imports"]])
  versioned <- names(imports)[!is.na(imports)]
  pkg <- versioned[[1L]]
  declared <- sprintf("%s (>= %s)", pkg, imports[[pkg]])

  cases <- list(
    list(
      "the copy itself is green", TRUE,
      function(x) x
    ),
    list(
      "a raised R floor", FALSE,
      function(x) {
        mutate(x, "description", sprintf("R (>= %s)", r_floor),
          sprintf("R (>= %s.1)", r_floor)
        )
      }
    ),
    list(
      sprintf("a raised %s floor", pkg), FALSE,
      function(x) {
        mutate(x, "description", declared,
          sprintf("%s (>= %s.1)", pkg, imports[[pkg]])
        )
      }
    ),
    list(
      sprintf("%s left unversioned", pkg), FALSE,
      function(x) mutate(x, "description", declared, pkg)
    ),
    list(
      "a transcript recording a failure", FALSE,
      function(x) mutate(x, "r_doc", "Status: OK", "Status: 1 ERROR")
    ),
    list(
      "a transcript reformatted past an anchor", NA,
      function(x) mutate(x, "dep_doc", "R version ", "R  version ")
    )
  )

  ok <- TRUE
  for (case in cases) {
    got <- outcome(case[[3L]](temp_root(root)))
    hit <- identical(got, case[[2L]])
    ok <- ok && hit
    cat(sprintf(
      "%-4s self-test: %-40s %s\n", if (hit) "ok" else "FAIL", case[[1L]],
      outcome_label(got)
    ))
  }
  if (!ok) {
    cat(
      "\nThe guard did not disagree with a tree it should have rejected.",
      "Until that is fixed, a green run above says nothing. See RADD-olitgnsw.",
      sep = "\n"
    )
    cat("\n")
  }
  ok
}

main <- function() {
  root <- package_root()
  if ("--self-test" %in% commandArgs(trailingOnly = TRUE) && !self_test(root)) {
    quit(status = 1L)
  }
  if (!report(run_checks(root))) {
    quit(status = 1L)
  }
}

main()
