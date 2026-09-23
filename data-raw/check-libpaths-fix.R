#!/usr/bin/env Rscript
# Guard SEOR-dyzgzyot's fix against .gitlab-ci.yml drifting back to the shape
# that made the CI cache never hold the built library.
#
# Usage (from anywhere -- the package root is derived from this file's path):
#   Rscript data-raw/check-libpaths-fix.R
#   Rscript data-raw/check-libpaths-fix.R --self-test
#
# WHY THIS EXISTS. rocker's own Renviron.site sets
# `R_LIBS=${R_LIBS-'/usr/local/lib/R/site-library:...'}`, and R_LIBS wins first
# place in .libPaths() ahead of R_LIBS_USER. Measured with docker before the
# fix (`docker run --rm -e R_LIBS_USER=/tmp/rlib rocker/r-ver:4.5.1 sh -c
# 'mkdir -p /tmp/rlib && Rscript -e ".libPaths()"'`):
#   [1] "/usr/local/lib/R/site-library" "/usr/local/lib/R/library" "/tmp/rlib"
# so every install.packages() call in the CI job installed into the image
# rather than into $CI_PROJECT_DIR/.rlib, and died with the container -- the
# cache was never holding anything. The fix is one line appended to
# Rprofile.site, re-measured after with the same docker invocation:
#   [1] "/tmp/rlib" "/usr/local/lib/R/site-library" "/usr/local/lib/R/library"
#
# WHAT THIS SCRIPT CANNOT MECHANIZE. It does not run docker and does not run
# R inside the job's own image -- data-raw/verify.sh runs on the host, not
# inside rocker/r-ver, so it cannot observe .libPaths() ordering directly. What
# it CAN check without a subprocess is that the fix line is still literally
# present in .gitlab-ci.yml, ahead of the mkdir that makes $R_LIBS_USER
# resolvable, and that the pipeline itself carries an assertion that proves the
# fix at the only place that can actually observe it: inside the job, on the
# image, after both lines have run. That in-pipeline assertion is what
# `.gitlab-ci.yml` runs every time this job does; this script only guards that
# neither piece has been quietly dropped.

package_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  self <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  if (length(self) != 1L) {
    return(normalizePath(".", mustWork = TRUE))
  }
  normalizePath(file.path(dirname(self), ".."), mustWork = TRUE)
}

fix_line <- ".libPaths(c(Sys.getenv(\"R_LIBS_USER\"), .libPaths()))"
mkdir_line <- 'mkdir -p "$R_LIBS_USER"'
assert_fragment <- paste0(
  "normalizePath(lp[[1]]) == ",
  "normalizePath(Sys.getenv(\"R_LIBS_USER\"))"
)

# One assertion per anchor, so a failure names which of the three things
# dropped rather than just reporting "check failed".
checks <- function(lines) {
  fix_at <- grep(fix_line, lines, fixed = TRUE)
  mkdir_at <- grep(mkdir_line, lines, fixed = TRUE)
  assert_at <- grep(assert_fragment, lines, fixed = TRUE)
  r_libs_user_at <- grep(
    'R_LIBS_USER: "$CI_PROJECT_DIR/.rlib"',
    lines,
    fixed = TRUE
  )

  list(
    list(
      "R_LIBS_USER points into $CI_PROJECT_DIR (so the cache can carry it)",
      length(r_libs_user_at) == 1L
    ),
    list(
      "Rprofile.site fix line present exactly once",
      length(fix_at) == 1L
    ),
    list(
      "mkdir -p \"$R_LIBS_USER\" present exactly once",
      length(mkdir_at) == 1L
    ),
    list(
      "fix line runs before the mkdir (both from the .r-job before_script)",
      length(fix_at) == 1L &&
        length(mkdir_at) == 1L &&
        fix_at[[1]] < mkdir_at[[1]],
      quiet = length(fix_at) != 1L || length(mkdir_at) != 1L
    ),
    list(
      "an in-pipeline assertion proves .libPaths()[1] == R_LIBS_USER",
      length(assert_at) == 1L
    )
  )
}

run_checks <- function(root) {
  checks(readLines(file.path(root, ".gitlab-ci.yml"), warn = FALSE))
}

report <- function(results) {
  ok <- vapply(results, `[[`, logical(1), 2)
  for (i in seq_along(results)) {
    cat(sprintf("%-4s %s\n", if (ok[[i]]) "ok" else "DRIFT", results[[i]][[1]]))
  }
  if (!all(ok)) {
    cat(
      "\nThe CI cache-fix guard from SEOR-dyzgzyot no longer holds.",
      "See the header of data-raw/check-libpaths-fix.R for what each line",
      "does and why it must stay in this order.\n",
      sep = "\n"
    )
  }
  all(ok)
}

# --- Proving the guard can disagree ------------------------------------------
# Mirrors data-raw/check-floor-drift.R's --self-test shape: mutate a throwaway
# copy of .gitlab-ci.yml and require the guard to reject each mutation.

self_test <- function(root) {
  src <- readLines(file.path(root, ".gitlab-ci.yml"), warn = FALSE)

  cases <- list(
    list("the file as-is is green", TRUE, function(x) x),
    list(
      "the Rprofile.site fix line stripped",
      FALSE,
      function(x) x[!grepl(fix_line, x, fixed = TRUE)]
    ),
    list(
      "the in-pipeline assertion stripped",
      FALSE,
      function(x) x[!grepl(assert_fragment, x, fixed = TRUE)]
    )
  )

  ok <- TRUE
  for (case in cases) {
    got <- all(vapply(checks(case[[3]](src)), `[[`, logical(1), 2))
    hit <- identical(got, case[[2]])
    ok <- ok && hit
    cat(sprintf(
      "%-4s self-test: %-45s %s\n",
      if (hit) "ok" else "FAIL",
      case[[1]],
      if (got) "green" else "DRIFT"
    ))
  }
  if (!ok) {
    cat(
      "\nThe guard did not disagree with a tree it should have rejected.\n",
      sep = "\n"
    )
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
