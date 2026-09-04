#!/bin/sh
# Check the package against the DEPENDENCY versions DESCRIPTION declares as its
# floor, which is what open item RADD-lfjdkynn asked for.
#
#     sh data-raw/check-dep-floor.sh > docs/dep-floor-check.md
#
# data-raw/check-r-floor.sh measured the R floor and left the dependency floor
# unmeasured. `Imports: vctrs (>= 0.7.0)` is a declaration and not a
# measurement: no run has ever installed 0.7.0. The existing floor script
# installs vctrs 0.7.2 and asserts `>= 0.7.0`, which proves the constraint is
# SATISFIABLE and not that the declared minimum works. This script is the
# measurement.
#
# That gap matters more here than it would in most packages. RADD-vppmbsia was
# a dependency-version bug, not a platform or R-version bug: vctrs < 0.7.0
# modifies vctrs_rcrd types in place in vec_assign(), and raddr_address is a
# vctrs_rcrd, so addr_reading(p, "curl") silently corrupted the record on every
# R version for anyone holding the vctrs current on CRAN from 2023-12-02 to
# 2026-01-16. The fix was to declare a floor. Declaring a floor and checking one
# are different acts, and only the first has happened.
#
# TWO AXES MOVE HERE AT ONCE, AND THAT IS DELIBERATE BUT NOT FREE.
#
# This runs on R 4.0.0, the declared R floor, rather than on a current R. The
# case for it: DESCRIPTION promises `R (>= 4.0.0)` AND `vctrs (>= 0.7.0)`
# jointly, so their conjunction is a configuration a user can really have, and
# it is the weakest one the package claims to support. Nothing else checks it.
#
# The case against it, which is the same confound data-raw/check-r-floor.sh
# warns about at length: a failure here does not attribute. It could be R 4.0,
# it could be vctrs 0.7.0, it could be the pair. Read a failure as "something in
# the declared minimum configuration", never as "vctrs 0.7.0 is broken".
#
# ATTRIBUTION FALLBACK, if this run fails. Re-run with BASE set to an image
# carrying a current R and the same vctrs downgrade:
#
#     BASE=rocker/r-ver:4.4.2 sh data-raw/check-dep-floor.sh
#
# A pass there and a failure here isolates the fault to R 4.0 or to the pair; a
# failure in both isolates it to vctrs 0.7.0. Run it before editing DESCRIPTION.
#
# WHY THIS BUILDS ON THE EXISTING FLOOR IMAGE. raddr-rfloor:4.0.0 already
# carries the whole R 4.0 closure from two pinned snapshots, including bignum
# built under a raised C++ standard -- R 4.0 defaults to C++11 and the BH
# headers bignum needs require C++14, which is a ninety-line problem that image
# already solves. Rebuilding it here would duplicate that and drift from it.
# Run data-raw/check-r-floor.sh first if the image is absent; this script says
# so rather than silently building something subtly different.
#
# WHY THE CRAN ARCHIVE RATHER THAN A THIRD SNAPSHOT DATE. A dated snapshot
# names a moment, not a version, so pinning vctrs 0.7.0 by date means finding
# the window between its release and 0.7.1 -- and re-finding it whenever the
# snapshot host prunes. The archive tarball names the version directly, which is
# the thing actually under test. The cost is a source build, which is why cpp11
# is installed first: the 0.7.2 in the base image arrived as a Posit binary and
# left no LinkingTo toolchain behind it.
#
# Requires Docker, as data-raw/check-r-floor.sh and oracle-libc-linux.sh do.

set -eu

cd "$(dirname "$0")/.."

# The version under test. This is the number DESCRIPTION declares; change both
# together or the transcript stops meaning anything.
VCTRS_TARGET=0.7.0

BASE=${BASE:-raddr-rfloor:4.0.0}
IMAGE=raddr-depfloor:$VCTRS_TARGET

if ! docker image inspect "$BASE" >/dev/null 2>&1; then
    echo "base image $BASE is absent." >&2
    echo "run 'sh data-raw/check-r-floor.sh' first to build it, or set BASE." >&2
    exit 1
fi

# Stage one: the base closure with vctrs pinned DOWN to exactly the declared
# floor. Downgrading rather than resolving forward is the whole point -- the
# question is what a user holding the oldest permitted vctrs experiences.
docker build --platform linux/amd64 -t "$IMAGE" --build-arg BASE="$BASE" - >&2 <<DOCKERFILE
ARG BASE
FROM \$BASE

# cpp11 is LinkingTo for vctrs and is absent from the base image, where vctrs
# arrived as a compiled binary. Installed from the repository the base image
# already configured in Rprofile.site, so no new snapshot date enters here.
RUN Rscript -e 'install.packages("cpp11"); if (!requireNamespace("cpp11", quietly = TRUE)) quit(status = 1)'

# The downgrade, asserted with EXACT equality rather than a floor comparison.
# A '>=' assert is what left this gap in the first place: it passes on 0.7.2 and
# would pass here on anything the resolver happened to leave in place, producing
# a transcript that looks like a floor measurement and is not one.
#
# Two URLs are tried because a version's location depends on whether it is still
# current: released versions live in src/contrib and superseded ones move to
# src/contrib/Archive. 0.7.0 is superseded today, so Archive is tried first and
# the other is the fallback rather than the reverse.
RUN Rscript -e 'v <- "$VCTRS_TARGET"; \
      urls <- c(paste0("https://cran.r-project.org/src/contrib/Archive/vctrs/vctrs_", v, ".tar.gz"), \
                paste0("https://cran.r-project.org/src/contrib/vctrs_", v, ".tar.gz")); \
      for (u in urls) { try(install.packages(u, repos = NULL, type = "source"), silent = TRUE); \
        if (requireNamespace("vctrs", quietly = TRUE) && as.character(packageVersion("vctrs")) == v) break }; \
      got <- as.character(packageVersion("vctrs")); \
      message("vctrs installed: ", got, " (target ", v, ")"); \
      if (got != v) { message("EXACT downgrade failed; transcript would be meaningless"); quit(status = 1) }'

# Re-assert the whole closure still loads after the downgrade. vctrs is a
# dependency of testthat and of the vignette toolchain, so a downgrade that
# satisfies raddr can still strand something the CHECK needs -- and that failure
# would otherwise surface later disguised as a test error.
RUN Rscript -e 'p <- c("rlang", "vctrs", "testthat", "bignum", "bit64", "digest", "hedgehog", "knitr", "rmarkdown", "spelling"); ok <- vapply(p, requireNamespace, logical(1), quietly = TRUE); print(ok); if (!all(ok)) quit(status = 1)'
DOCKERFILE

# Stage two: build and check the tarball inside the container. Quoted heredoc --
# nothing below is expanded by the host shell; the target arrives by environment.
docker run --rm -i --platform linux/amd64 \
    -v "$PWD:/src:ro" -e VCTRS_TARGET="$VCTRS_TARGET" -e BASE="$BASE" "$IMAGE" bash -s <<'INNER'
set -eu
mkdir -p /work && cd /work
tar -C /src -cf - --exclude=.git --exclude=_scratch --exclude=.fp . | tar -xf -

echo '## Environment'
echo
echo '```'
Rscript -e 'cat(R.version.string, "\n"); cat("platform:", R.version$platform, "\n")'
echo "base image:   $BASE"
echo "vctrs target: $VCTRS_TARGET  (the floor DESCRIPTION declares)"
echo
echo "Both the R version and the vctrs version sit at their declared floors, so"
echo "a failure below does not attribute to either one alone. See the header of"
echo "data-raw/check-dep-floor.sh for the fallback run that separates them."
echo
Rscript -e 'ip <- installed.packages(); ip <- ip[is.na(ip[, "Priority"]), c("Package", "Version"), drop = FALSE]; write.table(ip[order(rownames(ip)), ], quote = FALSE, row.names = FALSE, col.names = FALSE)'
echo '```'
echo
echo '## What the declared floors actually resolve to'
echo
echo '```'
# rlang carries NO floor in DESCRIPTION, so its effective minimum is whatever
# vctrs drags in. Printing both makes the inherited constraint visible instead
# of leaving it to be rediscovered, which is half of what RADD-lfjdkynn asks.
Rscript -e '
  vd <- packageDescription("vctrs");
  cat("vctrs installed:      ", as.character(packageVersion("vctrs")), "\n", sep = "");
  cat("vctrs Imports:        ", gsub("\\s+", " ", vd$Imports), "\n", sep = "");
  cat("vctrs Depends:        ", gsub("\\s+", " ", vd$Depends), "\n", sep = "");
  cat("rlang installed:      ", as.character(packageVersion("rlang")), "\n", sep = "");
  cat("\nraddr imports from rlang: abort, arg_match0, is_string (NAMESPACE).\n");
  cat("raddr DESCRIPTION declares no rlang floor, so the number above is\n");
  cat("inherited from vctrs rather than asserted by raddr.\n")'
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
# off because the incoming checks test DESCRIPTION metadata and URLs rather than
# R semantics -- BugReports: 404s for anonymous clients because GitLab serves
# 404 on /-/issues site-wide, not because the link is broken, which the host
# chain already records. Neither omission is dependency-sensitive; this
# transcript is evidence about the declared floors, not a CRAN gate.
_R_CHECK_CRAN_INCOMING_=false R CMD check --as-cran --no-manual raddr_*.tar.gz 2>&1
echo '```'
INNER
