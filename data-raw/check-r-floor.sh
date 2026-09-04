#!/bin/sh
# Check the package against the R version DESCRIPTION declares as its floor,
# which is what open item RADD-dcquzofl asked for.
#
#     sh data-raw/check-r-floor.sh > docs/r-floor-check.md
#
# Every check run during 0.1.0's development used one host: macOS arm64 on
# R 4.6.0. `Depends: R (>= 4.0.0)` was therefore a declaration and not a
# measurement, the same shape as `Language: en-US` before RADD-bxjyndha put
# spelling behind it. This script is the measurement.
#
# Two things about the environment are deliberate and neither is incidental.
#
# The image is amd64 only -- rocker publishes no arm64 manifest for 4.0.0, so
# this runs under emulation on Apple silicon. It is worth being precise about
# what that buys, because an earlier version of this comment called it a
# feature: the run is x86_64-pc-linux-gnu, so it does vary platform as well as
# R version, and it is the first Linux check the package has ever had. But
# varying two things at once is a CONFOUND, not a bonus. It is what made the
# vctrs bug in RADD-vppmbsia look like a libc difference for as long as it did.
# Read a failure here as "something in this environment", never as "R 4.0".
#
# The repository is pinned to dated Posit Package Manager snapshots rather than
# live CRAN, because live CRAN cannot satisfy the package on R 4.0 at all: vctrs
# needs glue, and glue 1.8.1 declares R (>= 4.1).
#
# There are TWO snapshot dates, and the split is the whole point rather than a
# convenience. RADD-vppmbsia is why: a single snapshot freezes the entire
# closure, not just R, so pinning one date silently varies every dependency
# version alongside the R version. The first run of this script used 2025-11-03
# for everything and therefore tested R 4.0 against vctrs 0.6.5 -- which
# corrupts a vctrs_rcrd in vec_assign() on EVERY R version -- and the resulting
# six failures were nearly attributed to R 4.0.
#
#   SNAPSHOT (2025-11-03) resolves everything. It is the latest snapshot whose
#   whole closure -- Imports and Suggests, recursively -- declares a floor at or
#   below 4.0.0. It must be late rather than contemporary with R 4.0, because
#   the suite uses expect_no_error() and so needs testthat >= 3.1.5.
#
#   SNAPSHOT_VCTRS (2026-03-25) then upgrades rlang and vctrs, and nothing else.
#   This is the latest snapshot on which raddr's own Imports are installable on
#   R 4.0: vctrs 0.7.2 and rlang 1.1.7 both declare R (>= 4.0.0), and glue is
#   still 1.8.0 (R >= 3.6) there, before the 1.8.1 bump to R (>= 4.1).
#
# Why two dates rather than one late one. The Suggests closure cannot be moved
# forward: rappdirs 0.3.4 declares R (>= 4.1), and rmarkdown reaches it through
# bslib and sass, so a 2026-03-25 rmarkdown cannot install on R 4.0 at all.
# Measured, not guessed -- that is what the requireNamespace() gate below caught
# when this script first tried to resolve everything from the later date.
#
# Why two dates rather than the one earlier one, which is the more important
# direction. A snapshot freezes the ENTIRE closure, not just R, so a single pin
# silently varies every dependency version alongside the R version. The first
# run of this script used 2025-11-03 throughout and therefore checked R 4.0
# against vctrs 0.6.5, which corrupts a vctrs_rcrd in vec_assign() on every R
# version (RADD-vppmbsia) -- and its six failures were very nearly attributed to
# R 4.0. DESCRIPTION now declares vctrs (>= 0.7.0), so a run that left 0.6.5 in
# place would not be checking the package as declared.
#
# The split is legitimate rather than a dodge, and it lands on exactly the
# distinction the floor is about: Depends and Imports are what the PACKAGE
# requires of a user's R, and that closure IS satisfiable on 4.0. The Suggests
# are test and vignette scaffolding that no user of raddr loads, so their
# declared floors constrain how this transcript gets produced, not what the
# package supports.
#
# Requires Docker, as data-raw/oracle-libc-linux.sh already does.

set -eu

cd "$(dirname "$0")/.."

SNAPSHOT=2025-11-03
SNAPSHOT_VCTRS=2026-03-25
IMAGE=raddr-rfloor:4.0.0

# Stage one: an image with the closure already installed, so re-running the
# check does not re-compile forty packages under emulation.
docker build --platform linux/amd64 -t "$IMAGE" - >&2 <<DOCKERFILE
FROM rocker/r-ver:4.0.0

# pandoc so the vignettes actually re-build on 4.0 instead of being skipped;
# libhunspell-dev and libxml2-dev for spelling, which tests/spelling.R runs
# (it reaches hunspell and xml2 through its own Imports).
RUN apt-get update \\
 && apt-get install -y --no-install-recommends \\
      pandoc libhunspell-dev libxml2-dev qpdf \\
 && rm -rf /var/lib/apt/lists/*

# Appended, so it overrides the 2020-06-04 binary snapshot the image ships.
RUN echo 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/$SNAPSHOT"))' \\
    >> /usr/local/lib/R/etc/Rprofile.site

RUN Rscript -e 'p <- c("rlang", "vctrs", "bit64", "digest", "hedgehog", "knitr", "rmarkdown", "spelling", "testthat"); install.packages(p, Ncpus = 4); ok <- vapply(p, requireNamespace, logical(1), quietly = TRUE); print(ok); if (!all(ok)) quit(status = 1)'

# bignum last, and behind a raised C++ standard. This compensates for R itself
# rather than for anything in raddr, and the reason is worth naming precisely:
# R 4.0's DEFAULT C++ standard is C++11 -- Makeconf ships `CXX = g++
# -std=gnu++11` -- and the BH headers bignum includes need C++14
# (std::remove_cv_t, std::decay_t, std::is_final). R raised its default to
# C++14 in 4.1 and C++17 in 4.3, so the same two packages build cleanly on any
# supported R and fail only here. bignum never asks for CXX11; it inherits the
# era's default.
#
# The edit targets CXX in Makeconf. Two lesser levers do not work: etc/
# Makevars.site is not consulted for this on 4.0, and CXX11STD governs only
# packages that explicitly declare CXX_STD = CXX11, which bignum does not.
#
# Applied after everything else installs, so only bignum is built under the
# raised standard and nothing already compiled is disturbed. raddr is pure R,
# so no package under check compiles C++ at all.
#
# Without this bignum will not install, and the failure would be silent in the
# worst way: its five tests are guarded by skip_if_not_installed(), so the
# check would go green while the transcript overstated what it had covered.
RUN sed -i 's|^CXX = g++ -std=gnu++11\$|CXX = g++ -std=gnu++17|' /usr/local/lib/R/etc/Makeconf \\
 && grep -q '^CXX = g++ -std=gnu++17\$' /usr/local/lib/R/etc/Makeconf \\
 && Rscript -e 'install.packages("bignum"); if (!requireNamespace("bignum", quietly = TRUE)) quit(status = 1)'

# Finally, upgrade the two packages raddr actually declares, from the later
# snapshot. This is the step the whole two-date arrangement exists for: without
# it the run would check R 4.0 against vctrs 0.6.5 and re-report RADD-vppmbsia
# as an R 4.0 failure, which is the mistake the first run of this script made.
#
# Scoped to rlang and vctrs deliberately. install.packages() only pulls a
# dependency forward when the installed one is missing or too old, so cli 3.6.x,
# glue 1.8.0 and lifecycle 1.0.5 from the earlier snapshot all stay put -- which
# is what keeps glue off 1.8.1 and therefore off R (>= 4.1). rlang comes along
# because vctrs 0.7.2 requires rlang (>= 1.1.7) and the earlier snapshot has
# 1.1.6.
#
# Asserted rather than assumed. A silent 0.6.5 here would produce a transcript
# that looks like a floor measurement and is not one.
RUN Rscript -e 'install.packages(c("rlang", "vctrs"), repos = "https://packagemanager.posit.co/cran/$SNAPSHOT_VCTRS", Ncpus = 4); v <- packageVersion("vctrs"); message("vctrs: ", v, ", rlang: ", packageVersion("rlang")); if (v < "0.7.0") quit(status = 1); ok <- vapply(c("rlang", "vctrs", "testthat", "bignum", "bit64", "digest", "hedgehog", "knitr", "rmarkdown", "spelling"), requireNamespace, logical(1), quietly = TRUE); print(ok); if (!all(ok)) quit(status = 1)'
DOCKERFILE

# Stage two: build and check the tarball inside the container, so the vignette
# code runs on 4.0 too rather than only being carried in from the host. The
# heredoc is quoted -- nothing below is expanded by the host shell; both
# snapshot dates arrive through the environment instead.
docker run --rm -i --platform linux/amd64 \
    -v "$PWD:/src:ro" -e SNAPSHOT="$SNAPSHOT" \
    -e SNAPSHOT_VCTRS="$SNAPSHOT_VCTRS" "$IMAGE" bash -s <<'INNER'
set -eu
mkdir -p /work && cd /work
tar -C /src -cf - --exclude=.git --exclude=_scratch --exclude=.fp . | tar -xf -

echo '## Environment'
echo
echo '```'
Rscript -e 'cat(R.version.string, "\n"); cat("platform:", R.version$platform, "\n")'
echo "closure snapshot:      https://packagemanager.posit.co/cran/$SNAPSHOT"
echo "rlang/vctrs snapshot:  https://packagemanager.posit.co/cran/$SNAPSHOT_VCTRS"
echo
echo "vctrs must be >= 0.7.0 for this transcript to mean anything; see"
echo "RADD-vppmbsia. The installed versions below are the record of that."
echo
Rscript -e 'ip <- installed.packages(); ip <- ip[is.na(ip[, "Priority"]), c("Package", "Version"), drop = FALSE]; write.table(ip[order(rownames(ip)), ], quote = FALSE, row.names = FALSE, col.names = FALSE)'
echo '```'
echo
echo '## R CMD build'
echo
echo '```'
R CMD build . 2>&1
echo '```'
echo
echo '## R CMD check --as-cran'
echo
echo '```'
# --no-manual because the image carries no LaTeX, and _R_CHECK_CRAN_INCOMING_
# off because the incoming checks test DESCRIPTION metadata and URLs rather
# than R semantics -- BugReports: 404s for anonymous clients because GitLab
# serves 404 on /-/issues site-wide, not because the link is broken, which
# the host chain already records. Neither omission is R-version-
# sensitive; this transcript is evidence about R 4.0, not a CRAN gate.
_R_CHECK_CRAN_INCOMING_=false R CMD check --as-cran --no-manual raddr_*.tar.gz 2>&1
echo '```'
INNER
