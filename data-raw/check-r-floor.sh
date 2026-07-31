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
# this runs under emulation on Apple silicon. That is a feature here: it makes
# the run x86_64-pc-linux-gnu, so it varies platform and R version at once and
# is the first Linux check the package has ever had.
#
# The repository is pinned to a dated Posit Package Manager snapshot rather
# than live CRAN, because live CRAN cannot satisfy the package on R 4.0 at all:
# vctrs needs glue, and glue 1.8.1 declares R (>= 4.1). 2025-11-03 is the
# latest snapshot whose whole closure -- Imports and Suggests, recursively --
# still declares a floor at or below 4.0.0. It matters that the date is late
# rather than contemporary with R 4.0: testthat must be at least 3.1.5 for the
# expect_no_error() the suite uses, so a 2021-era snapshot would fail for a
# reason that has nothing to do with R 4.0.
#
# Requires Docker, as data-raw/oracle-libc-linux.sh already does.

set -eu

cd "$(dirname "$0")/.."

SNAPSHOT=2025-11-03
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
DOCKERFILE

# Stage two: build and check the tarball inside the container, so the vignette
# code runs on 4.0 too rather than only being carried in from the host. The
# heredoc is quoted -- nothing below is expanded by the host shell; $SNAPSHOT
# arrives through the environment instead.
docker run --rm -i --platform linux/amd64 \
    -v "$PWD:/src:ro" -e SNAPSHOT="$SNAPSHOT" "$IMAGE" bash -s <<'INNER'
set -eu
mkdir -p /work && cd /work
tar -C /src -cf - --exclude=.git --exclude=_scratch --exclude=.fp . | tar -xf -

echo '## Environment'
echo
echo '```'
Rscript -e 'cat(R.version.string, "\n"); cat("platform:", R.version$platform, "\n")'
echo "snapshot: https://packagemanager.posit.co/cran/$SNAPSHOT"
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
# than R semantics -- the two GitHub URLs 404 while the account is suspended,
# which the host chain already records. Neither omission is R-version-
# sensitive; this transcript is evidence about R 4.0, not a CRAN gate.
_R_CHECK_CRAN_INCOMING_=false R CMD check --as-cran --no-manual raddr_*.tar.gz 2>&1
echo '```'
INNER
