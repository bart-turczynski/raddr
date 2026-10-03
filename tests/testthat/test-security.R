# OSS Index dependency vulnerability audit (oysteR / Sonatype), in seor's
# shape (seor tests/testthat/test-security.R; SEOR-lavybtkr).
#
# `oysteR::audit_description()` resolves the DESCRIPTION and audits the
# package's hard dependencies against the Sonatype OSS Index. It is a network
# test that requires OSS Index credentials (OSSINDEX_USER / OSSINDEX_TOKEN):
# the API rejects unauthenticated requests with HTTP 401.
#
# Scope: hard dependencies only -- `Depends` + `Imports`, never `Suggests`.
# `oysteR::expect_secure()` also audits `Suggests`, which drags in the dev
# tooling's own trees (oysteR's reaches `curl` through httr), so the gate would
# fail on a vulnerability in the auditor rather than in anything a user of
# raddr installs. A package's security posture is what it makes users install,
# so the audit calls `audit_description()` directly with the narrower
# `fields`. `expect_secure()` sets a CRAN mirror internally and
# `audit_description()` does not, hence the explicit `repos` option.
#
# WHERE THIS RUNS, AND WHY THE PRECONDITIONS ARE NOT ALWAYS SKIPS. Everywhere
# ordinary -- a local `testthat::test_local()`, `R CMD check` -- a missing
# precondition is a skip: a developer without OSS Index credentials is not a
# security regression. In the one place that exists to run this audit, the
# `security-audit` CI job, it is not: a job that skips and reports success has
# audited nothing (PUNY-rsxtbbln, SEOR-fkvlzltx). That job sets
# OSSINDEX_AUDIT_REQUIRED=true, and under that flag every precondition below
# becomes a hard failure naming what is missing. The flag is set in
# `.gitlab-ci.yml` and nowhere else.

test_that("the OSS Index allow-list is well formed", {
  expect_equal(oss_index_allowlist_violations(oss_index_allowlist), character())
})

test_that("the allow-list validator rejects rows that are not decisions", {
  sound <- list(
    id = "CVE-2026-18924",
    package = "curl",
    version_seen = "8.0.0",
    review = as.Date("2026-12-01"),
    reason = paste(
      "A rationale long enough to be an argument rather than a placeholder,",
      "naming the advisory, the exposure assessed and why it is accepted."
    )
  )
  expect_equal(oss_index_allowlist_violations(list(sound)), character())

  broken <- function(field, value) {
    row <- sound
    row[[field]] <- value
    oss_index_allowlist_violations(list(row))
  }

  expect_match(
    broken("id", "GHSA-xxxx"),
    "single CVE identifier",
    fixed = TRUE
  )
  expect_match(broken("package", ""), "single package name", fixed = TRUE)
  expect_match(
    broken("version_seen", "not-a-version"),
    "parseable version",
    fixed = TRUE
  )
  expect_match(broken("review", "2026-12-01"), "single Date", fixed = TRUE)
  expect_match(
    broken("reason", "unfixable"),
    "too short to be an argument",
    fixed = TRUE
  )

  expect_match(
    oss_index_allowlist_violations(list(sound[-5])),
    "missing field(s): reason",
    fixed = TRUE
  )
  expect_match(
    oss_index_allowlist_violations(list(c(sound, list(owner = "me")))),
    "unknown field(s): owner",
    fixed = TRUE
  )
  expect_match(
    oss_index_allowlist_violations(list(sound, sound)),
    "duplicate allow-list id",
    fixed = TRUE
  )
})

test_that("hard dependencies report only allow-listed OSS Index advisories", {
  # The dedicated, credentialed audit job. A precondition it cannot meet is a
  # failure there, never a skip -- see the header.
  required <- identical(Sys.getenv("OSSINDEX_AUDIT_REQUIRED"), "true")
  no_credentials <- Sys.getenv("OSSINDEX_USER") == "" ||
    Sys.getenv("OSSINDEX_TOKEN") == ""

  if (required) {
    if (!requireNamespace("oysteR", quietly = TRUE)) {
      stop(
        "OSSINDEX_AUDIT_REQUIRED is set but {oysteR} is not installed, so ",
        "this job cannot audit anything. Install it or unset the flag; do ",
        "not let the job report success."
      )
    }
    if (no_credentials) {
      stop(
        "OSSINDEX_AUDIT_REQUIRED is set but OSSINDEX_USER / OSSINDEX_TOKEN ",
        "are absent, so OSS Index would reject every request with HTTP 401 ",
        "and this job would report success having audited nothing. Add both ",
        "as CI/CD variables (project Settings > CI/CD > Variables); the ",
        "commands are in the `security-audit` job in .gitlab-ci.yml."
      )
    }
    # Deliberately no skip_if_offline() on this path: a network the job cannot
    # reach is the same vacuous green as a credential it does not have, so let
    # the audit attempt the call and fail on the transport error.
  } else {
    skip_on_cran()
    skip_if_not_installed("oysteR")
    skip_if_offline()
    skip_if(
      no_credentials,
      "OSS Index credentials (OSSINDEX_USER / OSSINDEX_TOKEN) not set"
    )
  }

  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  options(repos = c(CRAN = "https://cran.rstudio.com"))

  audit <- oysteR::audit_description(
    dirname(system.file("DESCRIPTION", package = "raddr")),
    fields = c("Depends", "Imports"),
    verbose = FALSE
  )
  found <- oss_index_reported(audit)
  allowed <- vapply(oss_index_allowlist, function(row) row$id, character(1))

  # An audit that resolved nothing is not a clean audit. Without this an empty
  # result satisfies rules A and B vacuously, which is the same green-on-
  # nothing failure the credential guard above exists to stop.
  expect_gt(nrow(audit), 0)

  # Rule A -- an advisory reported and not allow-listed.
  expect_equal(sort(setdiff(found$id, allowed)), character())

  # Rule B -- an allow-listed advisory no longer reported. The list may not
  # over-permit, so a row that has outlived its justification fails here.
  expect_equal(sort(setdiff(allowed, found$id)), character())

  # Rule C -- drift warns, never fails. See helper-security.R.
  for (row in oss_index_allowlist) {
    if (Sys.Date() > row$review) {
      warning(
        sprintf(
          "OSS Index allow-list row %s is past its %s review date.",
          row$id,
          format(row$review)
        ),
        call. = FALSE
      )
    }
    hit <- found[found$id == row$id, ]
    if (
      nrow(hit) > 0 &&
        package_version(hit$version[1]) > package_version(row$version_seen)
    ) {
      warning(
        sprintf(
          paste(
            "OSS Index allow-list row %s was written against %s %s;",
            "the audit now reports %s. Re-read the advisory."
          ),
          row$id,
          row$package,
          row$version_seen,
          hit$version[1]
        ),
        call. = FALSE
      )
    }
  }
})
