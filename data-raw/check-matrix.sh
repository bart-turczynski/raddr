#!/bin/sh
# Run the reachable part of the CI matrix locally, and account for the rest.
#
#     sh data-raw/check-matrix.sh > docs/check-matrix.md
#
# THE SIX ROWS THIS FILE ACCOUNTS FOR came from .github/workflows/R-CMD-check.yaml,
# which declared six matrix rows plus a verify job and never executed once. That
# file was deleted on 2026-09-05 (RADD-ithxwzpr) after the GitHub account hosting
# the repository stayed suspended from 2026-07-20 with the appeal unanswered. The
# row set is kept here as the accounting frame because it is a reasonable
# description of what CRAN checks, not because a workflow is waiting on it.
#
# The gap it was written against is unchanged: AGENTS.md concedes that the local
# gate checks one platform and one R version -- macOS arm64 on R 4.6.0. GitLab CI
# now covers native amd64 release and devel (docs/gitlab-ci.md), so this script is
# no longer the only thing standing in for a pipeline. It remains the only local
# route to the rows below, and it still cannot become a replacement for CI: one of
# the six rows is unreachable from a Mac at all.
#
# THE MECHANISM IS BORROWED, NOT INVENTED. data-raw/check-r-floor.sh already
# runs `R CMD check --as-cran` inside `docker build --platform linux/amd64` from
# a rocker/r-ver image. This generalizes that across R versions instead of
# starting a second approach, and data-raw/build-release.sh is the precedent for
# the host-side half: build into a temporary directory, check the tarball, emit
# the transcript on stdout.
#
# WHICH ROWS RUN, AND WHY THE SET IS A SUBSET RATHER THAN A MIRROR.
#
#   ubuntu-latest / release  RUN. A different platform and a different libc from
#                            the host, and nothing currently covers it under
#                            R CMD check. data-raw/oracle-libc-linux.sh varies
#                            libc but runs oracles, not a package check.
#   ubuntu-latest / devel    RUN. Catches upcoming breakage; nothing covers it.
#   macos-latest / release   RUN, natively. This IS the host. Containerizing it
#                            would measure something other than the machine the
#                            gate runs on, which is the one thing already known.
#   ubuntu / oldrel-1, -2    SKIPPED deliberately. AGENTS.md records that these
#                            "only probe toward the floor without reaching it",
#                            and the floor itself is measured at R 4.0.0 with
#                            Status OK by data-raw/check-r-floor.sh
#                            (docs/r-floor-check.md). Two rows between a covered
#                            floor and a covered release earn little.
#   windows-latest / release UNREACHABLE. Recorded as an open gap. Not
#                            simulated, not approximated, not quietly dropped.
#   verify (lintr, spelling) COVERED ELSEWHERE: it is the pre-push hook.
#
# THE SNAPSHOT-PIN TRAP, WHICH THIS HAS TO RESPECT ROW BY ROW. AGENTS.md
# records that "a dated snapshot pin freezes the entire closure, not just R, so a
# run that varies the pin is not varying one thing and cannot attribute a failure
# to R alone". check-r-floor.sh learned it concretely: its first run reported
# 1 ERROR and 7 test failures that were not R 4.0 findings at all, because the
# pinned snapshot carried vctrs 0.6.5 and so reproduced RADD-vppmbsia.
#
# The conclusion for THIS script is the opposite choice, and it is deliberate
# rather than lazy: neither container row pins a date. check-r-floor.sh pins
# because live CRAN cannot satisfy R 4.0 at all (glue 1.8.1 declares R >= 4.1),
# so pinning is the exception forced by the floor, not the default. Here the
# rows ask about platform and about upcoming R, and both questions are only
# meaningful against packages as they are now. Each row therefore takes its
# image's own current repository -- p3m binaries for the release row, CRAN
# source for devel, since p3m serves no binaries built against R-devel -- and
# the installed versions are RECORDED in the transcript, because "current" is
# not reproducible and only the record makes a run checkable after the fact.
# Every row also asserts vctrs >= 0.7.0 before checking anything, so a silent
# 0.6.5 cannot turn RADD-vppmbsia into a fresh platform finding a second time.
#
# WHAT A FAILING ROW MEANS. It is a finding, and this script reports it rather
# than working around it. A row that cannot build for an infrastructure reason
# is recorded as blocked and the other rows still run; `set -eu` is in force but
# every docker and check invocation captures its own exit status.
#
# Requires Docker and R. The two images it builds --- raddr-matrix:ubuntu-release
# and raddr-matrix:ubuntu-devel --- are left on the machine on purpose, so that
# re-running skips the dependency install stage; `docker rmi` them to reclaim the
# space. Everything else is written under `mktemp -d` and removed on exit, which
# honors TMPDIR: nothing is ever written inside the working tree, because `tmp/`
# is gitignored but not Rbuildignored and would reach `R CMD check` as a
# "non-standard things in the check directory" NOTE.

set -eu

cd "$(dirname "$0")/.."
REPO=$(pwd)

RELEASE_IMAGE=rocker/r-ver:latest
DEVEL_IMAGE=rocker/r-ver:devel
RELEASE_TAG=raddr-matrix:ubuntu-release
DEVEL_TAG=raddr-matrix:ubuntu-devel

DATE=$(date -u +%Y-%m-%d)
HEAD_COMMIT=$(git rev-parse --short HEAD)
HEAD_DESCRIBE=$(git describe --tags --always)

# An explicit template rather than a bare `mktemp -d`, because macOS ignores
# TMPDIR for the bare form and answers from _CS_DARWIN_USER_TEMP_DIR instead. The
# template makes TMPDIR authoritative on every platform, which is what lets a
# caller put the scratch space somewhere it has chosen.
TMP_BASE=${TMPDIR:-/tmp}
WORK=$(mktemp -d "${TMP_BASE%/}/raddr-matrix.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Split a container row's stdout into .env, .build and .check on the markers the
# inner script prints. Anything before the first marker is dropped.
split_row() {
    awk -v p="$1" '
        /^@@@RADDR:/ { f = p "." substr($0, 10); next }
        f { print > f }
    ' "$1.log"
}

# The Status: line of a check log, or a stand-in saying why there is none.
status_of() {
    if [ -f "$1" ]; then
        S=$(grep "^Status:" "$1" | tail -n 1 || true)
    else
        S=
    fi
    if [ -z "$S" ]; then
        S="Status: (no status line; see the raw output below)"
    fi
    echo "$S"
}

# Every ERROR, WARNING and NOTE block: header line through to the next check
# step. Anchored on "* " so the trailing "Status: 1 NOTE" summary line, which
# also ends in NOTE, does not open a block of its own. Same awk as
# data-raw/build-release.sh.
findings_of() {
    if [ -f "$1" ]; then
        F=$(awk '
            /^\* .*(ERROR|WARNING|NOTE)$/ { p = 1; print; next }
            /^\* / { p = 0 }
            p { print }
        ' "$1")
    else
        F=
    fi
    if [ -z "$F" ]; then
        F="(none: no ERROR, WARNING or NOTE block in the log)"
    fi
    echo "$F"
}

# A container row's environment block, or -- if the row never reached the first
# marker -- its whole stdout instead, so that a failure cannot be invisible in
# the transcript. $1 section file, $2 row log.
env_or_log() {
    if [ -f "$1" ]; then
        cat "$1"
    elif [ -s "$2" ]; then
        echo "(No environment block: the row failed before reaching it. Its whole"
        echo "stdout follows instead, because a row that fails is a finding.)"
        echo
        cat "$2"
    else
        echo "(No environment block and no output at all: the row never started,"
        echo "which normally means its image build failed. See the image build below.)"
    fi
}

# A short human phrase for the wall time a row took.
elapsed() {
    M=$(( $1 / 60 ))
    S=$(( $1 % 60 ))
    echo "${M}m ${S}s"
}

# ---------------------------------------------------------------------------
# The two container rows
#
# $1 base image, $2 tag to build, $3 output prefix under $WORK.
#
# Stage one builds an image with the whole declared closure already installed,
# so a re-run does not reinstall it under emulation. Stage two builds and checks
# the tarball INSIDE the container, so the vignette code runs on that R too
# rather than being carried in from the host.
# ---------------------------------------------------------------------------

container_row() {
    ROW_IMAGE=$1
    ROW_TAG=$2
    ROW_OUT=$3

    {
        echo "FROM $ROW_IMAGE"
        cat <<'DOCKERFILE'

# pandoc so the vignettes really re-build instead of being skipped;
# libhunspell-dev and libxml2-dev for spelling, which tests/spelling.R runs and
# which reaches hunspell and xml2 through its own Imports; qpdf for the PDF
# checks --as-cran performs.
#
# libuv1-dev is the one entry here that was discovered rather than anticipated,
# and it is worth naming because it stands for a whole class of difference
# between these rows and CI. fs 2.1.0 links libuv, and fs is how testthat and
# rmarkdown both reach the filesystem through pkgload, so without it seven
# packages fail to install and the devel row cannot check anything. The release
# row never noticed: it installs a p3m BINARY of fs, which is already linked. So
# the requirement only exists for a row that builds from source. In CI this
# whole category is invisible because setup-r-dependencies resolves declared
# system requirements automatically; this apt line is the hand-maintained
# stand-in for that, and a future source-built row may well need another entry.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      pandoc libhunspell-dev libxml2-dev libuv1-dev qpdf \
 && rm -rf /var/lib/apt/lists/*

# The image's own repository is used as it ships -- no date pin. See the header
# for why that is the right answer for these two rows and the wrong one for
# data-raw/check-r-floor.sh.
#
# Every Suggests package is installed deliberately, for the reason the workflow
# gives: a check that skips is not a check that passed.
# tests/testthat/test-hedgehog.R skips whole when hedgehog is absent, and the
# bignum, bit64 and digest paths do the same.
RUN Rscript -e 'p <- c("rlang", "vctrs", "bignum", "bit64", "digest", "hedgehog", "knitr", "rmarkdown", "spelling", "testthat"); install.packages(p, Ncpus = 4); ok <- vapply(p, requireNamespace, logical(1), quietly = TRUE); print(ok); if (!all(ok)) quit(status = 1)'

# Asserted rather than assumed, because vctrs is the one dependency whose
# version has already produced a wrong conclusion. vctrs < 0.7.0 modifies
# vctrs_rcrd types in place in vec_assign(), which corrupts raddr_address
# (RADD-vppmbsia); DESCRIPTION declares vctrs (>= 0.7.0) against it. A row that
# resolved 0.6.5 would report six test failures that have nothing to do with the
# platform or the R version this row exists to vary.
RUN Rscript -e 'v <- packageVersion("vctrs"); message("vctrs: ", v); if (v < "0.7.0") quit(status = 1)'
DOCKERFILE
    } > "$WORK/$ROW_OUT.dockerfile"

    T0=$(date +%s)

    IMAGE_RC=0
    # --progress=plain so the log is readable text rather than a redrawn
    # terminal, since its tail ends up in the transcript.
    docker build --progress=plain --platform linux/amd64 -t "$ROW_TAG" - \
        < "$WORK/$ROW_OUT.dockerfile" > "$WORK/$ROW_OUT.image" 2>&1 || IMAGE_RC=$?
    echo "$IMAGE_RC" > "$WORK/$ROW_OUT.image-rc"

    if [ "$IMAGE_RC" -ne 0 ]; then
        echo "$(( $(date +%s) - T0 ))" > "$WORK/$ROW_OUT.secs"
        echo 0 > "$WORK/$ROW_OUT.rc"
        return 0
    fi

    # The heredoc is quoted: nothing below is expanded by the host shell.
    ROW_RC=0
    docker run --rm -i --platform linux/amd64 -v "$REPO:/src:ro" "$ROW_TAG" \
        bash -s > "$WORK/$ROW_OUT.log" 2>&1 <<'INNER' || ROW_RC=$?
set -eu
mkdir -p /work && cd /work

# The tree is copied in with cp rather than with the `tar -cf - | tar -xf -`
# pipe that data-raw/check-r-floor.sh uses, and the reason is a real limit of
# this harness rather than a preference.
#
# Under `--platform linux/amd64` on Apple silicon, GNU tar 1.35 as shipped by
# Ubuntu 26.04 -- the devel image's base -- cannot extract into a subdirectory
# at all: every file below the top level fails with "Cannot open: Function not
# implemented", ENOSYS, while top-level files extract fine. It is the x86_64
# emulator not implementing the directory-relative open that this tar uses, not
# a sandbox restriction: `--security-opt seccomp=unconfined` does not change it,
# and the 24.04 release image is unaffected. cp goes through a syscall the
# emulator does implement, so it works on both images and the two rows stay
# identical in how they are set up.
find /src -mindepth 1 -maxdepth 1 \
     ! -name .git ! -name _scratch ! -name .fp \
     -exec cp -a -t /work/ {} +

echo '@@@RADDR:env'
Rscript -e 'cat(R.version.string, "\n"); cat("platform:", R.version[["platform"]], "\n"); cat("svn rev:", R.version[["svn rev"]], "\n")'
grep PRETTY_NAME /etc/os-release
Rscript -e 'cat("repos:  ", getOption("repos")[["CRAN"]], "\n")'
echo
echo "Installed non-base packages, which are the record of what \"current\""
echo "resolved to on this run. No date is pinned; see the script header."
echo
Rscript -e 'ip <- installed.packages(); ip <- ip[is.na(ip[, "Priority"]), c("Package", "Version"), drop = FALSE]; write.table(ip[order(rownames(ip)), ], quote = FALSE, row.names = FALSE, col.names = FALSE)'

echo '@@@RADDR:build'
BUILD_RC=0
R CMD build . 2>&1 || BUILD_RC=$?
[ "$BUILD_RC" -eq 0 ] || echo "R CMD build exited $BUILD_RC"

echo '@@@RADDR:check'
# --no-manual because these images carry no LaTeX toolchain, which is exactly
# what the workflow passes too. The CRAN incoming checks are left ON, unlike
# check-r-floor.sh: they are what a submission would meet, and mirroring the
# workflow is the point of this run. They reach the network to resolve the
# DESCRIPTION URLs.
CHECK_RC=0
R CMD check --as-cran --no-manual raddr_*.tar.gz 2>&1 || CHECK_RC=$?
[ "$CHECK_RC" -eq 0 ] || echo "R CMD check exited $CHECK_RC"
INNER

    echo "$ROW_RC" > "$WORK/$ROW_OUT.rc"
    echo "$(( $(date +%s) - T0 ))" > "$WORK/$ROW_OUT.secs"
    split_row "$WORK/$ROW_OUT"
}

# ---------------------------------------------------------------------------
# The host row: macos-latest / release, run on the actual host
# ---------------------------------------------------------------------------

host_row() {
    ROW_OUT=host
    T0=$(date +%s)

    mkdir -p "$WORK/src" "$WORK/out"
    tar -C "$REPO" -cf - --exclude=./.git --exclude=./_scratch --exclude=./.fp . \
        | tar -C "$WORK/src" -xf -

    {
        Rscript -e 'cat(R.version.string, "\n"); cat("platform:", R.version[["platform"]], "\n")'
        echo "os:       $(uname -srm)"
        echo
        echo "Declared dependencies, as installed on this host:"
        echo
        Rscript -e 'd <- read.dcf("DESCRIPTION")[1, ]; f <- intersect(c("Depends", "Imports", "Suggests"), names(d)); s <- unlist(strsplit(paste(d[f], collapse = ","), ",")); p <- sort(setdiff(unique(trimws(sub("[(].*", "", s))), c("R", ""))); for (x in p) { v <- tryCatch(as.character(utils::packageVersion(x)), error = function(e) "not installed"); cat(sprintf("%-12s %s\n", x, v)) }'
    } > "$WORK/$ROW_OUT.env" 2>&1

    BUILD_RC=0
    ( cd "$WORK/out" && R CMD build "$WORK/src" ) > "$WORK/$ROW_OUT.build" 2>&1 || BUILD_RC=$?
    [ "$BUILD_RC" -eq 0 ] || echo "R CMD build exited $BUILD_RC" >> "$WORK/$ROW_OUT.build"

    CHECK_RC=0
    # The same arguments the two container rows and the workflow use, so the
    # three rows differ in platform and R version and in nothing else that this
    # script controls. build-release.sh is what checks the manual on the host.
    ( cd "$WORK/out" && R CMD check --as-cran --no-manual raddr_*.tar.gz ) \
        > "$WORK/$ROW_OUT.check" 2>&1 || CHECK_RC=$?
    [ "$CHECK_RC" -eq 0 ] || echo "R CMD check exited $CHECK_RC" >> "$WORK/$ROW_OUT.check"

    echo "$CHECK_RC" > "$WORK/$ROW_OUT.rc"
    echo 0 > "$WORK/$ROW_OUT.image-rc"
    echo "$(( $(date +%s) - T0 ))" > "$WORK/$ROW_OUT.secs"
}

# ---------------------------------------------------------------------------
# Run the three reachable rows
# ---------------------------------------------------------------------------

echo "row 1/3: macos-latest / release, on the host" >&2
host_row
echo "row 2/3: ubuntu-latest / release, in $RELEASE_IMAGE" >&2
container_row "$RELEASE_IMAGE" "$RELEASE_TAG" ubuntu-release
echo "row 3/3: ubuntu-latest / devel, in $DEVEL_IMAGE" >&2
container_row "$DEVEL_IMAGE" "$DEVEL_TAG" ubuntu-devel

# ---------------------------------------------------------------------------
# Read the results back
# ---------------------------------------------------------------------------

HOST_STATUS=$(status_of "$WORK/host.check")
HOST_FINDINGS=$(findings_of "$WORK/host.check")
HOST_SECS=$(elapsed "$(cat "$WORK/host.secs")")

REL_STATUS=$(status_of "$WORK/ubuntu-release.check")
REL_FINDINGS=$(findings_of "$WORK/ubuntu-release.check")
REL_SECS=$(elapsed "$(cat "$WORK/ubuntu-release.secs")")
REL_IMAGE_RC=$(cat "$WORK/ubuntu-release.image-rc")

DEV_STATUS=$(status_of "$WORK/ubuntu-devel.check")
DEV_FINDINGS=$(findings_of "$WORK/ubuntu-devel.check")
DEV_SECS=$(elapsed "$(cat "$WORK/ubuntu-devel.secs")")
DEV_IMAGE_RC=$(cat "$WORK/ubuntu-devel.image-rc")

# One R version string per row, pulled out of the environment blocks so the
# table can name what actually ran rather than what was requested.
HOST_R=$(head -n 1 "$WORK/host.env" | sed 's/ *$//')
if [ -f "$WORK/ubuntu-release.env" ]; then
    REL_R=$(head -n 1 "$WORK/ubuntu-release.env" | sed 's/ *$//')
else
    REL_R="(image build failed)"
fi
if [ -f "$WORK/ubuntu-devel.env" ]; then
    DEV_R=$(head -n 1 "$WORK/ubuntu-devel.env" | sed 's/ *$//')
else
    DEV_R="(image build failed)"
fi

# Per-row disposition cells, computed from what happened rather than asserted.
row_cell() {
    if [ "$2" -ne 0 ]; then
        echo "**blocked on infrastructure: the image would not build**"
    else
        case "$1" in
            *"no status line"*)
                echo "**did not complete: the check produced no Status line, see the raw output**"
                ;;
            *ERROR* | *WARNING*) echo "**covered by this run — $1**" ;;
            *) echo "covered by this run — $1" ;;
        esac
    fi
}

HOST_CELL=$(row_cell "$HOST_STATUS" 0)
REL_CELL=$(row_cell "$REL_STATUS" "$REL_IMAGE_RC")
DEV_CELL=$(row_cell "$DEV_STATUS" "$DEV_IMAGE_RC")

# The verdict for the opening summary, wrapped here rather than in the heredoc
# because its length varies with what happened.
VERDICT="All three reachable rows check clean, apart from the one expected
\`--as-cran\` incoming NOTE explained below."
for S in "$HOST_STATUS" "$REL_STATUS" "$DEV_STATUS"; do
    case "$S" in
        *ERROR* | *WARNING* | *"no status line"*)
            VERDICT="At least one reachable row reported more than the expected
incoming NOTE. The findings below are the record of it, and they are the
authoritative part of this file."
            ;;
    esac
done
if [ "$REL_IMAGE_RC" -ne 0 ] || [ "$DEV_IMAGE_RC" -ne 0 ]; then
    VERDICT="$VERDICT At least one container row was blocked on infrastructure
before it could check anything."
fi

# ---------------------------------------------------------------------------
# The transcript
# ---------------------------------------------------------------------------

# Piped through a trailing-whitespace strip, because most of what follows is raw
# R CMD check and image-build output and that output carries trailing spaces.
# Without this the repository's own trailing-whitespace pre-commit hook rewrites
# the generated file on the way in, so the committed bytes stop matching what the
# script emits and every later run shows churn that is not a result changing --
# the file can never be clean twice running. data-raw/snapshot-tracker.sh solves
# the same problem for the same reason, there for `fp` output rather than check
# output. Nothing in a check log depends on a trailing space, and the hook would
# strip them anyway; doing it here is what keeps the two in agreement.
cat <<EOF | sed 's/[[:space:]]*$//'
# The CI matrix, run locally — transcript

Generated by \`sh data-raw/check-matrix.sh\` on ${DATE}, against the tree at
\`${HEAD_COMMIT}\` (\`${HEAD_DESCRIBE}\`). Three of the six matrix rows this file
accounts for were run here: macOS release on the host, Ubuntu release in a
container, and Ubuntu devel in a container.
**${VERDICT}**
Two of the remaining rows were skipped deliberately, one is unreachable from this
machine, and the \`verify\` job is already the pre-push hook. The per-row accounting
below is the point of this file: a reader should be able to tell exactly what this
buys and what it does not.

| CI matrix row | R that actually ran | Disposition |
| --- | --- | --- |
| \`macos-latest\` / \`release\` | ${HOST_R} | ${HOST_CELL} (host row, ${HOST_SECS}) |
| \`ubuntu-latest\` / \`release\` | ${REL_R} | ${REL_CELL} (${REL_SECS}) |
| \`ubuntu-latest\` / \`devel\` | ${DEV_R} | ${DEV_CELL} (${DEV_SECS}) |
| \`ubuntu-latest\` / \`oldrel-1\` | — | deliberately skipped: probes toward a floor that is already measured |
| \`ubuntu-latest\` / \`oldrel-2\` | — | deliberately skipped: same reason |
| \`windows-latest\` / \`release\` | — | **unreachable locally: an open gap, checked by nothing** |
| \`verify\` job (lintr, spelling) | host | covered elsewhere: the pre-push \`verify\` hook in \`.pre-commit-config.yaml\` |

One row that is not in the matrix belongs in the same table, because it is what makes
two of the skips defensible: R 4.0.0, the floor \`DESCRIPTION\` declares, is covered
elsewhere by \`data-raw/check-r-floor.sh\`, transcript \`docs/r-floor-check.md\`,
Status OK.

## What this is, and what it is not

This is a local stand-in. It was adopted when no CI could run at all: the six-row
GitHub workflow it accounts for never executed once, because the account hosting the
repository was suspended on 2026-07-20 and the appeal went unanswered. That workflow
was deleted on 2026-09-05 rather than left committed and unexercised, and CI now runs
on GitLab instead (\`docs/gitlab-ci.md\`). So this file no longer sits beside a
waiting workflow — it is the local route to rows a pipeline does not cover.

It is the second half of a pair. \`docs/ci-workflow-lint.md\` establishes statically
that the workflow is well-formed — actionlint clean, and its three unverifiable
judgement calls resolved against the \`r-lib/actions\` sources — and closes by saying
that this "does not say a run will pass". This file is what answers that, for three of
the six rows, by running the checks somewhere rather than reading the file.

It is not a replacement for CI, and it cannot become one. Three things separate the
two, and it is worth naming them rather than letting the table imply parity.

**Windows is unchecked by anything.** \`windows-latest\` / \`release\` cannot be run
from macOS. There is no container for it here, no cross-compilation, and no
approximation that would mean anything — Windows differs from the rows below in path
handling, in file encoding defaults, and in the C library underneath, which is
precisely the class of difference a check is supposed to surface. The row is recorded
as an open gap. It stays open until either the account is restored or a Windows
machine is available.

**This runs once, by hand, on one laptop.** CI runs on every push and every pull
request, in parallel, on machines nobody has configured by hand. A transcript is
evidence about the moment it was produced; a workflow is a standing gate. Re-running
this script is a manual act, and nothing enforces that it happens.

**The rows here are a reasoned subset, not a shortfall — but they are still a
subset.** Two of the six were skipped on the argument set out below, and that argument
could be wrong. It is recorded so it can be disagreed with.

## Per-row reasoning

**\`macos-latest\` / \`release\` — run natively, as the host row.** This row is the
machine the local gate has always run on, so it is deliberately *not* containerized:
a container would measure something other than the host, and the host is the one
platform whose behavior is already known. Running it anyway matters for one reason.
It is the reference point. Without a host row in the same transcript, produced by the
same script with the same arguments, a container finding could not be told apart from
a difference in how the check was invoked.

**\`ubuntu-latest\` / \`release\` — run in a container, and the highest-value row
here.** It varies platform and libc together, and nothing else in the project covers
that under \`R CMD check\`. \`data-raw/oracle-libc-linux.sh\` does run under glibc and
musl, but it runs the address-parsing oracles, not a package check: it says nothing
about whether the package builds, whether the vignettes re-build, or whether the test
suite passes there. This row is the first time \`R CMD check\` has seen this package on
a current Linux.

**\`ubuntu-latest\` / \`devel\` — run in a container.** It is the only thing that looks
forward. A failure here is a warning about a future R release rather than a defect
today, and that distinction is worth keeping in mind when reading its findings: a
devel-only finding is not necessarily a bug in the package.

**\`ubuntu-latest\` / \`oldrel-1\` and \`oldrel-2\` — deliberately skipped.** The
reason is recorded in \`AGENTS.md\` and in the workflow's own comment: these two rows
"only probe toward the floor without reaching it". They cannot reach it in CI either,
because \`setup-r-dependencies\` resolves against current CRAN, where \`rappdirs\` and
\`glue\` declare \`R (>= 4.1)\` and so cannot install on 4.0 at all. Meanwhile the floor
itself *is* measured: \`data-raw/check-r-floor.sh\` checks the package under R 4.0.0
with pinned snapshots and reports Status OK, 0 errors, 0 warnings, 0 notes
(\`docs/r-floor-check.md\`). With a covered floor below them and a covered release
above them, two intermediate R versions earn little for two more slow emulated image
builds. This is a judgement call, not a fact, and it is the one most worth revisiting
if a version-sensitive bug ever appears.

**\`windows-latest\` / \`release\` — unreachable.** Stated above and not softened here.

**The \`verify\` job — covered elsewhere.** It runs \`lintr::lint_package()\` and
\`spelling::spell_check_package()\`, which is exactly what the pre-push \`verify\` hook
runs, in the same order, on the host. Both are host-independent: they read source and
prose, not platform behavior. Re-running them in a container would consume time to
re-confirm something the hook confirms on every push, so this script does not run them
at all. The hook is the coverage.

## The snapshot-pin decision, per row

\`AGENTS.md\` records the trap plainly: "a dated snapshot pin freezes the *entire*
closure, not just R, so a run that varies the pin is not varying one thing and cannot
attribute a failure to R alone." That is not a hypothetical. The first run of
\`data-raw/check-r-floor.sh\` reported 1 ERROR and 7 test failures that were not R 4.0
findings at all: its pinned snapshot carried vctrs 0.6.5, which modifies
\`vctrs_rcrd\` types in place in \`vec_assign()\` and so corrupted \`raddr_address\`
(\`RADD-vppmbsia\`). Six of the seven were that bug, on a package-version axis nobody
was varying on purpose.

So the package source is a per-row decision here, and each row's is deliberate.

**Host row: no pin is possible, and none is wanted.** The host's installed library is
what the pre-push gate uses, so recording it is the honest thing to do rather than
choosing it. The declared dependencies and their installed versions are in the
environment block below.

**Ubuntu release row: current, not pinned.** The image resolves
\`p3m.dev/cran/__linux__/noble/latest\` — a moving current source. That is chosen, not
inherited by accident. This row's question is the platform, so freezing the closure to
a date would vary dependency versions *alongside* the platform, which is the exact
confound quoted above. Keeping the closure current means it lines up as nearly as two
package repositories can with the host row's, so a divergence between the two rows
points at the platform rather than at the package set.

**Ubuntu devel row: current, and source rather than binary.** The image ships
\`cloud.r-project.org\`, and current is right for a second reason: the row asks whether
*upcoming* R breaks the package, which is only meaningful against packages as they are
now. A dated pin would test R-devel against a frozen past closure, which is the worst
of both. Source rather than binary is forced rather than chosen: p3m serves no
binaries built against R-devel, and dropping an R 4.6 binary into R-devel would make
any resulting failure unattributable.

**Why this is the opposite choice to \`check-r-floor.sh\`, and why that is
consistent.** That script pins because live CRAN cannot satisfy R 4.0 at all — vctrs
needs glue, and glue 1.8.1 declares \`R (>= 4.1)\`. Pinning there is an exception forced
by the floor. It is not the default, and applying it here would import the confound
without buying anything.

**What the reader still cannot attribute, stated rather than glossed.** The release
row and the devel row differ in three things at once: R version, Ubuntu release
(24.04 noble against 26.04 resolute, which is what the two images ship), and package
repository (p3m binaries against CRAN source). A finding that appears on devel and not
on release is therefore *not* attributable to R-devel by itself without further
narrowing. The installed-package listings in both environment blocks exist so that
narrowing can start from a record instead of a guess.

**One thing every row asserts before checking anything.** vctrs must be >= 0.7.0.
\`DESCRIPTION\` declares that floor, and a row that quietly resolved 0.6.5 would report
six test failures that had nothing to do with the platform or the R version the row
exists to vary. The container rows fail their image build rather than produce such a
transcript.

## How the rows were run

Both container rows use \`docker build --platform linux/amd64\`, the same mechanism
\`data-raw/check-r-floor.sh\` uses. The platform is explicit because \`ubuntu-latest\`
runners are x86_64, so \`x86_64-pc-linux-gnu\` is the platform string worth matching;
on Apple silicon that means the whole row runs under emulation, which is slow and is
the reason the dependency closure is baked into an image that later runs re-use. The
two images are left on the machine on purpose, so that re-running skips the install
stage; \`docker rmi\` on \`${RELEASE_TAG}\` and \`${DEVEL_TAG}\` reclaims the space.
Emulation is itself a difference from a real x86_64 runner, and the second paragraph
below is a concrete instance of that rather than a hypothetical one.

Each container row builds and checks the tarball *inside* the container, from a
read-only mount of the working tree, so the vignette code runs on that R rather than
being carried in from the host. The host row does the same thing in a \`mktemp -d\`
directory. Nothing is written inside the working tree by any row: a scratch directory
in the repository would reach \`R CMD check\` as a "non-standard things in the check
directory" NOTE, because \`tmp/\` is gitignored but not Rbuildignored.

Two things about this harness had to be discovered by running it, and both are
recorded because they are the actual cost of standing in for CI by hand rather than
incidental detail. Neither is a defect in the package.

The first is a **system requirement**. \`fs\` 2.1.0 links libuv, and both \`testthat\`
and \`rmarkdown\` reach \`fs\` through \`pkgload\`, so on the devel row — the only row
that builds from source — seven packages failed to install until \`libuv1-dev\` was
added to the image. The release row never noticed, because it installs an already
linked p3m binary. In CI this whole class of problem is invisible:
\`setup-r-dependencies\` resolves declared system requirements automatically. The apt
line in this script is a hand-maintained stand-in for that, so a future source-built
row may well need another entry, and a failure of this shape should be read as a
missing \`-dev\` package before anything else.

The second is a **limit of emulation itself**, and it is the sharpest reminder that
this is a stand-in. Under \`--platform linux/amd64\` on Apple silicon, the GNU tar 1.35
that Ubuntu 26.04 ships cannot extract into a subdirectory at all: every file below
the top level fails with \`Cannot open: Function not implemented\`, while top-level
files extract normally. It is the x86_64 emulator not implementing the
directory-relative open that this tar version uses —
\`--security-opt seccomp=unconfined\` makes no difference, and the 24.04 release image
is unaffected. So the tree is copied in with \`cp\` rather than the \`tar\` pipe
\`data-raw/check-r-floor.sh\` uses. A real \`ubuntu-latest\` runner would have hit
neither of these, which is the point: an emulated container is close to that runner,
and not the same thing.

Both of those were resolved on 2026-08-02 against a **native** amd64 run, and they
resolved differently — see \`docs/gitlab-ci.md\` (\`RADD-fgciezpx\`). The first is
real: the native devel job builds \`fs\` from source too and needs the same
\`libuv1-dev\`, so it was a genuine system requirement rather than an emulation
artifact. The second does not exist off the emulator at all, because a runner
clones with git and never reaches \`tar\`. Both paragraphs above stand as written
regardless, because they describe what THIS run experienced, and a transcript that
is edited to reflect a later run is no longer a transcript.

All three rows pass \`--as-cran --no-manual\`, which is exactly what the workflow
passes, so the three differ in platform and R version and in nothing this script
controls. The manual is skipped for the workflow's own reason — it needs a LaTeX
toolchain that neither container carries and that nothing in this package's checks
depends on — and the host's manual is covered separately by
\`data-raw/build-release.sh\` (\`docs/release-build.md\`), which checks with the manual
left in. Unlike \`check-r-floor.sh\`, the CRAN incoming checks are
left **on**: they are what a submission would meet, and mirroring the workflow is the
point of this run.

## The NOTE to expect on every row

\`checking CRAN incoming feasibility\` reports a NOTE on every row that reaches the
network, and it is expected rather than a defect. It says two things. The package is a
**new submission**, which is true and which CRAN wants flagged. And \`BugReports:\` —
\`https://gitlab.com/bart-turczynski/raddr/-/work_items\` — draws a **syntactic** NOTE:
R flags any gitlab.com \`BugReports:\` path not ending in \`/issues\` and suggests
appending it. That rule predates GitLab's issues-to-work-items migration, and the URL
it suggests, \`/-/work_items/issues\`, returns 403. Do not adopt it and do not drop
the field; the declared URL resolves 200, as does \`URL:\`.

A row with no network access would not produce the NOTE at all, and its absence would
mean the incoming checks did not run rather than that they passed. The findings blocks
below are the authoritative record either way: if one of them shows something other
than that NOTE, the block is what counts and this paragraph is not.

## Findings

### \`macos-latest\` / \`release\` — the host row

\`\`\`
${HOST_STATUS}
\`\`\`

\`\`\`
${HOST_FINDINGS}
\`\`\`

### \`ubuntu-latest\` / \`release\`

\`\`\`
${REL_STATUS}
\`\`\`

\`\`\`
${REL_FINDINGS}
\`\`\`

### \`ubuntu-latest\` / \`devel\`

\`\`\`
${DEV_STATUS}
\`\`\`

\`\`\`
${DEV_FINDINGS}
\`\`\`

## Row 1 raw output — \`macos-latest\` / \`release\`, on the host

### Environment

\`\`\`
$(cat "$WORK/host.env")
\`\`\`

### R CMD build

\`\`\`
$(cat "$WORK/host.build")
\`\`\`

### R CMD check --as-cran --no-manual

\`\`\`
$(cat "$WORK/host.check")
\`\`\`

## Row 2 raw output — \`ubuntu-latest\` / \`release\`

### Environment

\`\`\`
$(env_or_log "$WORK/ubuntu-release.env" "$WORK/ubuntu-release.log")
\`\`\`

### Image build (tail)

\`\`\`
$(tail -n 25 "$WORK/ubuntu-release.image")
\`\`\`

### R CMD build

\`\`\`
$(cat "$WORK/ubuntu-release.build" 2> /dev/null || echo "(no build block: the row did not get that far)")
\`\`\`

### R CMD check --as-cran --no-manual

\`\`\`
$(cat "$WORK/ubuntu-release.check" 2> /dev/null || echo "(no check block: the row did not get that far)")
\`\`\`

## Row 3 raw output — \`ubuntu-latest\` / \`devel\`

### Environment

\`\`\`
$(env_or_log "$WORK/ubuntu-devel.env" "$WORK/ubuntu-devel.log")
\`\`\`

### Image build (tail)

\`\`\`
$(tail -n 25 "$WORK/ubuntu-devel.image")
\`\`\`

### R CMD build

\`\`\`
$(cat "$WORK/ubuntu-devel.build" 2> /dev/null || echo "(no build block: the row did not get that far)")
\`\`\`

### R CMD check --as-cran --no-manual

\`\`\`
$(cat "$WORK/ubuntu-devel.check" 2> /dev/null || echo "(no check block: the row did not get that far)")
\`\`\`
EOF
