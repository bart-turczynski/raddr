#!/usr/bin/env Rscript
# Guard SEOR-wqxhftpv's pkgdown agent-file filter against .gitlab-ci.yml
# reverting to a deny-list, and against the keep-list quietly widening to
# admit a file it should not.
#
# Usage (from anywhere -- the package root is derived from this file's path):
#   Rscript data-raw/check-agent-md-filter.R
#   Rscript data-raw/check-agent-md-filter.R --self-test
#
# WHY THIS EXISTS. pkgdown renders every top-level .md
# (pkgdown:::package_mds() hardcodes its own skip list -- README/NEWS/LICENSE,
# cran-comments.md as no_render -- so _pkgdown.yml cannot exclude anything
# else). The `pages` job used to hide agent files with a deny-list, `rm -f
# AGENTS.md CLAUDE.md FP_AGENTS.md`: a new file in an existing family
# (FP_CLAUDE.md, as pslr carries) or a wholly new family (GEMINI.md) is
# structurally invisible to a list of names, and would have published as a
# page and been indexed into search.json.
#
# The fix inverts the direction of the list: every top-level .md is moved
# UNLESS it is named in `keep`, so an unlisted file -- whatever it is named --
# is hidden by construction rather than by someone remembering to add its
# name. That also means a stray unlisted file is NOT evidence this guard
# works: it was never going to get through either way. What DOES prove the
# keep-list is doing its job is the opposite mutation -- widening `keep` to
# admit a name it should not -- which is what --self-test exercises.
#
# The pinned set below is the live site measured on 2026-09-23:
# https://raddr-0129a6.gitlab.io/{CHANGELOG,CONTRIBUTING,SECURITY}.html all
# return 200, so all three are grandfathered rather than de-published
# (de-publishing any of them is a separate editorial call this ticket does not
# make). README.md, NEWS.md and cran-comments.md are pinned too, even though
# pkgdown special-cases them on its own -- moving one of those out from under
# pkgdown breaks the site rather than merely hiding a page, so this guard
# insists they stay off the move list regardless of what pkgdown would have
# done anyway.
#
# A STATIC PIN PASSED WHILE THE SITE LEAKED. The first keep-list moved files
# with file.rename() and discarded the result. On the runner that rename is
# cross-device (a mounted checkout, the container's own /tmp), so it failed
# with a warning on every file, and AGENTS.html, CLAUDE.html and FP_AGENTS.html
# were published from 2026-09-23 while every check below reported ok. Text
# cannot prove a move happened, so two checks now pin the runtime safety net
# instead: no file.rename() in the job, and a postcondition that stops the
# build while any unlisted .md is still at the top level.

known_agent_prefixes <- c("^AGENTS", "^CLAUDE", "^FP_", "^GEMINI")

expected_keep <- c(
  "README.md",
  "NEWS.md",
  "cran-comments.md",
  "CHANGELOG.md",
  "CONTRIBUTING.md",
  "SECURITY.md"
)

package_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  self <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
  if (length(self) != 1L) {
    return(normalizePath(".", mustWork = TRUE))
  }
  normalizePath(file.path(dirname(self), ".."), mustWork = TRUE)
}

# Pull the character vector out of `keep <- c("a", "b", ...)` in the pages
# job's script. Anchored on the assignment target, not a line number, so
# reformatting the surrounding YAML does not silently stop this from matching.
extract_keep_list <- function(lines) {
  hit <- grep("keep <- c\\(", lines, perl = TRUE)
  if (length(hit) != 1L) {
    stop(
      sprintf(
        "`keep <- c(...)` matched %d lines in .gitlab-ci.yml; the pages job's",
        length(hit)
      ),
      " filter moved and this script must move with it",
      call. = FALSE
    )
  }
  line <- lines[[hit]]
  inner <- regmatches(
    line,
    regexec("keep <- c\\(([^)]*)\\)", line, perl = TRUE)
  )[[1]][[2]]
  trimws(gsub('"', "", strsplit(inner, ",")[[1]]))
}

checks <- function(lines) {
  # A YAML `#` comment line may still quote the old deny-list as history (it
  # does, in the comment above `pages:`), so only a line that is not a comment
  # counts as a reversion.
  code_lines <- lines[!grepl("^\\s*#", lines, perl = TRUE)]
  deny_list_at <- grep(
    "rm -f AGENTS.md CLAUDE.md FP_AGENTS.md",
    code_lines,
    fixed = TRUE
  )
  moves_to_tmp <- any(grepl("/tmp/agent-md", code_lines, fixed = TRUE))
  renames <- any(grepl("file.rename(", code_lines, fixed = TRUE))
  postcondition <- any(grepl(
    "refusing to publish it",
    code_lines,
    fixed = TRUE
  ))
  deletes_only <- any(grepl("^\\s*rm -f", code_lines, perl = TRUE))

  keep <- tryCatch(extract_keep_list(lines), error = function(e) NULL)

  agent_named <- if (is.null(keep)) {
    character()
  } else {
    keep[Reduce(`|`, lapply(known_agent_prefixes, grepl, x = keep))]
  }

  list(
    list("no reversion to the old rm -f deny-list", length(deny_list_at) == 0L),
    list(
      "hidden files are moved into /tmp/agent-md, not deleted",
      moves_to_tmp
    ),
    list(
      "nothing in the pages job still deletes rather than moves",
      !deletes_only
    ),
    list(
      "no file.rename() (it fails cross-device on the runner, only warning)",
      !renames
    ),
    list(
      "build refuses to run while an unlisted .md remains at the top level",
      postcondition
    ),
    list("a `keep <- c(...)` keep-list is present and parses", !is.null(keep)),
    list(
      "keep-list matches the pinned, currently-published set exactly",
      !is.null(keep) && setequal(keep, expected_keep)
    ),
    list(
      "keep-list admits no agent-file name (AGENTS*/CLAUDE*/FP_*/GEMINI*)",
      length(agent_named) == 0L
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
      "\nThe pkgdown agent-file keep-list guard from SEOR-wqxhftpv no longer",
      "holds. See the header of data-raw/check-agent-md-filter.R.\n",
      sep = "\n"
    )
  }
  all(ok)
}

# --- Proving the guard can disagree ------------------------------------------
# The only meaningful mutation for a fail-closed keep-list is WIDENING it to
# admit a name it should not -- narrowing it, or adding an unrelated stray
# file elsewhere in the tree, is invisible to this mechanism by design and
# proves nothing about whether the guard works.

self_test <- function(root) {
  src <- readLines(file.path(root, ".gitlab-ci.yml"), warn = FALSE)
  hit <- grep("keep <- c\\(", src, perl = TRUE)

  cases <- list(
    list("the file as-is is green", TRUE, function(x) x),
    list(
      "keep-list widened to admit AGENTS.md",
      FALSE,
      function(x) {
        x[[hit]] <- sub(
          'keep <- c\\("README.md"',
          'keep <- c("AGENTS.md", "README.md"',
          x[[hit]],
          perl = TRUE
        )
        x
      }
    ),
    list(
      "reverted to the old rm -f deny-list",
      FALSE,
      function(x) {
        x[[hit]] <- "      rm -f AGENTS.md CLAUDE.md FP_AGENTS.md"
        x
      }
    ),
    list(
      "move reverted to an unchecked file.rename()",
      FALSE,
      function(x) {
        x[[hit]] <- sub(
          "copied <- file.copy(drop, \"/tmp/agent-md\", overwrite = TRUE);",
          "invisible(file.rename(drop, file.path(\"/tmp/agent-md\", drop)));",
          x[[hit]],
          fixed = TRUE
        )
        x
      }
    ),
    list(
      "postcondition before build_site removed",
      FALSE,
      function(x) {
        x[[hit]] <- sub(
          "refusing to publish it",
          "moving on",
          x[[hit]],
          fixed = TRUE
        )
        x
      }
    )
  )

  ok <- TRUE
  for (case in cases) {
    got <- all(vapply(checks(case[[3]](src)), `[[`, logical(1), 2))
    hit_ok <- identical(got, case[[2]])
    ok <- ok && hit_ok
    cat(sprintf(
      "%-4s self-test: %-45s %s\n",
      if (hit_ok) "ok" else "FAIL",
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
