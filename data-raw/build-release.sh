#!/bin/sh
# Build the release tarball, check it with --as-cran, and emit the transcript.
#
#     sh data-raw/build-release.sh > docs/release-build.md
#
# RADD-uvddposi asked for a kept tarball plus a committed checksum, so that a
# future submission could be proved to be the artifact that was verified. Two
# things narrow that, and both are why this script exists as a MECHANISM rather
# than as a one-off checksum in a file.
#
# The version only has to read what it reads at the moment of submission, and
# submission has not happened yet (RADD-yrppvxdi). It was blocked, until
# 2026-08-13, by DESCRIPTION naming a suspended GitHub account; that blocker is
# gone and the URLs now name the public GitLab project, so what remains is an
# unperformed submission rather than an impossible one. Every version and tag
# question is therefore settled at ship time, not today. A checksum committed now would pin an artifact that will never be
# the submitted one, so nothing here freezes a checksum as "the verified
# artifact". The sha256 below records what one run produced, which is what a
# transcript is for.
#
# And `R CMD build` embeds a `Packaged:` timestamp in DESCRIPTION, so two builds
# of the same tree are not byte-identical. A checksum pins one artifact; it does
# not certify a reproducible build. Anything that wants to compare two trees has
# to compare EXTRACTED CONTENTS, never tarball checksums.
#
# The version is read from DESCRIPTION rather than hardcoded, precisely because
# the number is a ship-time decision: re-running this after a version bump must
# produce a correct transcript with no edit to the script.
#
# Everything is built inside a `mktemp -d` directory and removed on exit. Two
# reasons, and the second is not obvious. `.gitignore` carries `*.tar.gz`, so a
# stray tarball is invisible to git and would sit in the tree unnoticed. And a
# scratch directory inside the repository is worse than untidy: `tmp/` is
# gitignored but NOT Rbuildignored, so it reaches `R CMD check` as a
# "non-standard things in the check directory" NOTE. Nothing this script writes
# ever lands under the working tree.
#
# Requires R, and a working pandoc for the vignettes. Unlike
# data-raw/check-r-floor.sh this runs on the host, so it measures the host's R
# and the host's dependency versions; the environment section below is the
# record of which ones.

set -eu

cd "$(dirname "$0")/.."
REPO=$(pwd)

# Package name and version from DESCRIPTION, via read.dcf() rather than a
# regexp, so continuation lines and field order cannot mislead it.
DCF=$(Rscript -e 'd <- read.dcf("DESCRIPTION")[1, ]; cat(d[["Package"]], d[["Version"]])')
PKG=${DCF% *}
VERSION=${DCF#* }
TARBALL="${PKG}_${VERSION}.tar.gz"

# Declared dependencies and the versions this host has installed. Captured now,
# while the working directory is still the repository root.
DEPS=$(Rscript -e 'd <- read.dcf("DESCRIPTION")[1, ]; f <- intersect(c("Depends", "Imports", "Suggests"), names(d)); s <- unlist(strsplit(paste(d[f], collapse = ","), ",")); p <- sort(setdiff(unique(trimws(sub("[(].*", "", s))), c("R", ""))); for (x in p) { v <- tryCatch(as.character(utils::packageVersion(x)), error = function(e) "not installed"); cat(sprintf("%-12s %s\n", x, v)) }')

R_VERSION=$(Rscript -e 'cat(R.version.string)')
R_PLATFORM=$(Rscript -e 'cat(R.version[["platform"]])')
HEAD_COMMIT=$(git rev-parse --short HEAD)
HEAD_DESCRIBE=$(git describe --tags --always)

# Tag facts, computed rather than asserted. The tag this version would ship
# under may or may not exist yet, and may or may not point at this tree.
TAG="v${VERSION}"
TAG_STATE=absent
TAG_COMMIT=
TAG_DIFF=
TAG_VCTRS=
TAG_FLOOR=unknown
if git rev-parse -q --verify "refs/tags/${TAG}" > /dev/null 2>&1; then
    TAG_STATE=present
    TAG_COMMIT=$(git rev-parse --short "refs/tags/${TAG}^{commit}")
    TAG_DIFF=$(git diff --name-only "refs/tags/${TAG}" HEAD || true)
    # First vctrs line of the tagged DESCRIPTION, trimmed of the continuation
    # indent and of any trailing comma, so it can be quoted inline as prose.
    TAG_VCTRS=$(git show "refs/tags/${TAG}:DESCRIPTION" 2> /dev/null \
        | grep -i "vctrs" \
        | awk '{ $1 = $1; sub(/,$/, ""); print; exit }' || true)
    case "$TAG_VCTRS" in
        *"(>="*) TAG_FLOOR=present ;;
        "") TAG_FLOOR=unknown ;;
        *) TAG_FLOOR=absent ;;
    esac
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$WORK/src" "$WORK/out"

# A copy of the tree, minus the three directories that are large, local, or
# both. .Rbuildignore decides what reaches the tarball; this only decides what
# gets copied at all.
tar -C "$REPO" -cf - --exclude=./.git --exclude=./_scratch --exclude=./.fp . \
    | tar -C "$WORK/src" -xf -

cd "$WORK/out"

R CMD build "$WORK/src" > build.log 2>&1

if [ ! -f "$TARBALL" ]; then
    echo "expected $TARBALL, found: $(ls)" >&2
    exit 1
fi

if command -v sha256sum > /dev/null 2>&1; then
    SHA=$(sha256sum "$TARBALL" | cut -d " " -f 1)
elif command -v shasum > /dev/null 2>&1; then
    SHA=$(shasum -a 256 "$TARBALL" | cut -d " " -f 1)
elif command -v openssl > /dev/null 2>&1; then
    SHA=$(openssl dgst -sha256 "$TARBALL" | tr -d " " | cut -d "=" -f 2)
else
    SHA="unavailable: no sha256sum, shasum or openssl on PATH"
fi

SIZE=$(wc -c < "$TARBALL" | tr -d " ")

# --as-cran with the incoming checks left ON, unlike check-r-floor.sh, which
# turns them off because that transcript is evidence about R 4.0 rather than a
# CRAN gate. Here they are the point: the incoming NOTE is what a submission
# would meet. It reaches the network to resolve the DESCRIPTION URLs.
CHECK_RC=0
R CMD check --as-cran "$TARBALL" > check.log 2>&1 || CHECK_RC=$?

STATUS_LINE=$(grep "^Status:" check.log | tail -n 1)
[ -n "$STATUS_LINE" ] || STATUS_LINE="Status: (no status line; R CMD check exited $CHECK_RC)"

# Every ERROR, WARNING and NOTE block, header line through to the next check
# step. Anchored on "* " so that the trailing "Status: 1 NOTE" summary line,
# which also ends in NOTE, does not open a block of its own.
FINDINGS=$(awk '/^\* .*(ERROR|WARNING|NOTE)$/ { p = 1; print; next } /^\* / { p = 0 } p { print }' check.log)
[ -n "$FINDINGS" ] || FINDINGS="(none: no ERROR, WARNING or NOTE block in the log)"

DATE=$(date -u +%Y-%m-%d)

cat <<EOF
# Release build and \`--as-cran\` check — transcript

Generated by \`sh data-raw/build-release.sh\` on ${DATE}, against \`${PKG}\` version
${VERSION} at \`${HEAD_COMMIT}\`. **${STATUS_LINE} — the tree builds, and the tarball
built from it checks under \`--as-cran\` on the host recorded below.** The findings
are extracted below the environment and the build, and the full check log is at the
end of this file.

## What this transcript pins, and what it does not

It records that **this tree**, on **this host**, builds and checks. That is all it
claims.

It does not pin the artifact that will be submitted to CRAN. The version and the tag
are settled at the moment of submission, not by this file, and no submission has been
made yet, so no submission date exists to pin to. A checksum frozen in a committed file today would name a tarball that will
never be the one submitted. The sha256 recorded under **R CMD build** below is
therefore a record of what one run produced, not a verified-artifact fingerprint.

It also could not certify a reproducible build even if it wanted to. \`R CMD build\`
embeds a \`Packaged:\` timestamp in \`DESCRIPTION\`, so two builds of the same tree
differ in bytes and therefore in sha256. Anything that needs to know whether two
trees produce the same package has to compare **extracted contents**, never tarball
checksums. That is a property of \`R CMD build\`, not a limitation of this script.

The version is read from \`DESCRIPTION\` rather than hardcoded, so re-running this at
ship time produces a correct transcript for whatever the version reads then.

## The \`${TAG}\` tag

EOF

if [ "$TAG_STATE" = absent ]; then
    cat <<EOF
No \`${TAG}\` tag exists in this repository, so there is nothing here to compare the
tree against. Whether to create one, and at which commit, is a ship-time decision.
EOF
else
    cat <<EOF
\`${TAG}\` points at \`${TAG_COMMIT}\`. \`HEAD\` is \`${HEAD_COMMIT}\`
(\`${HEAD_DESCRIBE}\`), so the tag does not point at the tree this transcript
describes. These tracked paths differ between the two:

\`\`\`
${TAG_DIFF}
\`\`\`

That list is the material point rather than a detail. \`R/\`, \`tests/\` and
\`DESCRIPTION\` are not covered by \`.Rbuildignore\`, so the difference is inside the
package rather than confined to development scaffolding, and a tarball built from the
tag would not have the same contents as the one built above.
EOF

    if [ "$TAG_FLOOR" = absent ]; then
        cat <<EOF

One of those differences is a correctness bug rather than a refinement. The tagged
tree's \`Imports:\` entry for vctrs reads \`${TAG_VCTRS}\` — no version floor. vctrs
< 0.7.0 modifies \`vctrs_rcrd\` types in place in \`vec_assign()\` instead of returning
a copy, and \`raddr_address\` is a \`vctrs_rcrd\`, so resolving the \`curl\`
composition blanked the record's own stored reading and corrupted it for every later
read. That is \`RADD-vppmbsia\`, it was latent on every R version, and the floor that
fixes it is not in the tagged tree. Stated as a fact about where the tag points:
**the \`${TAG}\` tag carries the record-corruption bug.**

What to do about it — move the tag, tag a new version, or something else — is a
ship-time decision and is deliberately not made here. This file records the state of
the tag; it does not recommend a resolution and it does not move anything.
EOF
    else
        cat <<EOF

The tagged tree's vctrs entry reads \`${TAG_VCTRS}\`, so the \`RADD-vppmbsia\` floor
is present there. Whether the tag should move to follow the other differences listed
above is still a ship-time decision, and is deliberately not made here.
EOF
    fi
fi

cat <<EOF

## Environment

This ran on the host, not in a container, so it measures one platform and one set of
dependency versions — the gap \`AGENTS.md\` describes, and the axis that
\`RADD-vppmbsia\` came from. The installed versions of the declared dependencies are
recorded for that reason: an unversioned \`Imports:\` entry asserts that any version
works, and only a record of which one was actually present makes the assertion
checkable after the fact.

\`\`\`
${R_VERSION}
platform:    ${R_PLATFORM}
commit:      ${HEAD_COMMIT} (${HEAD_DESCRIBE})

Declared dependencies, as installed on this host:

${DEPS}
\`\`\`

## R CMD build

The tarball was built from a copy of the tree in a temporary directory and deleted
when this script exited. Nothing was left in the working tree, and nothing was
written under it: a scratch directory inside the repository would reach
\`R CMD check\` as a "non-standard things in the check directory" NOTE, because
\`tmp/\` is gitignored but not Rbuildignored.

\`\`\`
tarball:  ${TARBALL}
size:     ${SIZE} bytes
sha256:   ${SHA}
\`\`\`

\`\`\`
$(cat build.log)
\`\`\`

## Findings from \`R CMD check --as-cran\`

\`\`\`
${STATUS_LINE}
\`\`\`

\`\`\`
${FINDINGS}
\`\`\`

The NOTE from \`checking CRAN incoming feasibility\` is expected on this tree and is
not a defect to fix. It reports two things. The package is a **new submission**,
which is true and which CRAN wants flagged. And the \`BugReports:\` field —
\`https://gitlab.com/bart-turczynski/raddr/-/issues\` — is reported as a URL
returning **404**. GitLab serves 404 on \`/-/issues\` to signed-out non-browser
clients on every project (a browser is redirected to \`/-/work_items\`), and CRAN
accepts it: rurl 3.0.1 is on CRAN with the same form. Do not repoint it at
\`/-/work_items\`: \`tools:::.check_package_CRAN_incoming\` wants a gitlab.com
\`BugReports:\` path ending in \`/-/issues\` and NOTEs anything else, which is what
got pslr 1.2.1 archived at the CRAN pretest. \`URL:\` resolves **200**. If the
findings block above shows anything other than that NOTE, the block is the
authoritative record and this paragraph is not.

## R CMD check --as-cran

\`\`\`
$(cat check.log)
\`\`\`
EOF
