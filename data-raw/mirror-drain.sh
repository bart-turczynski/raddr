#!/bin/sh
# Refresh the mirror copies of this repository, then prove they match.
#
#     sh data-raw/mirror-drain.sh
#
# Why this exists. AGENTS.md prescribes `git push backup --all && git push
# backup --tags` to refresh the local mirror. That command adds and updates but
# it never DELETES, so a branch deleted locally lives on in the mirror forever.
# The drift was measured on 2026-08-01: the mirror carried three heads --
# feature/ssrfr-api-seams, chore/hard-case-conformance, chore/peer-benchmarks --
# with no local counterpart, all three ancestors of `dev` and so redundant
# labels rather than unique work. Nothing was lost, which is exactly why the
# drift was invisible. This script closes that by pruning, and then by checking
# rather than assuming that the prune worked.
#
# WHY AN EXPLICIT REFSPEC AND NOT `--mirror`. `git push --mirror` propagates
# every ref under refs/*, including ones the server owns. GitLab keeps merge
# request state in refs/merge-requests/*, so a mirror push aimed at a GitLab
# remote can reach further than intended. The refspec below touches heads and
# tags and nothing else, which is the whole of what a mirror of this repository
# needs to agree on.
#
# WHY `--no-verify`. The pre-push hook runs the verify gate: lintr, spelling,
# then rcmdcheck --as-cran. That gate exists to guard what ENTERS the canonical
# history. A mirror receives commits that already passed it on the way to the
# primary remote, so re-running it here checks the same tree a second time and
# tells you nothing new. This also sidesteps a cost that was measured rather
# than assumed on 2026-08-01: git runs the pre-push hook ONCE PER PUSH URL, so
# the alternative design -- one remote carrying several pushurls, fanning out on
# a single `git push` -- runs the full --as-cran check once per target. A
# two-URL remote with a counting hook fired it twice for one push. That is what
# ruled the fan-out out, and it is why mirror traffic is kept on this separate
# ungated path instead.
#
# WHAT IS NOT A MIRROR TARGET. `origin` (GitLab) is the working remote, not a
# mirror: work reaches it through the ordinary gated branch -> push -> MR flow,
# so pushing to it from here would bypass the gate that flow depends on. It is
# listed under VERIFY_TARGETS instead, so a divergence still gets reported.
#
# UNREACHABLE TARGETS ARE REPORTED, NOT FATAL. `github` has 403'd since
# 2026-07-20. A mirror refresh that aborted on the first dead remote would skip
# the live ones behind it, so each target is handled independently and the exit
# status reflects the whole run.
set -eu

# Remotes that receive a pruning force-push: they are copies, and copies do not
# get an opinion about what the local repository says. Add `github` here once
# the account suspension lifts and it can accept a push again.
#
# Both lists are overridable from the environment so the script can be pointed
# at throwaway remotes. That is not a convenience: the strict/working asymmetry
# below is a behavioural claim, and it was checked by driving this script
# against scratch repositories carrying each fault class in turn rather than by
# waiting for a real mirror to break.
MIRROR_TARGETS="${MIRROR_TARGETS:-backup}"

# Remotes that are compared but never pushed to from this script. See the note
# above on why `origin` belongs here.
VERIFY_TARGETS="${VERIFY_TARGETS:-origin}"

if [ ! -d .git ]; then
	echo "not at the root of a git repository" >&2
	exit 1
fi

# Local heads and tags, normalised to "<refname> <sha>" and sorted, so it can be
# compared against the same shape derived from a remote.
refs_local() {
	git show-ref --heads --tags | awk '{print $2" "$1}' | sort
}

# The same shape read off a remote. `git ls-remote --tags` reports an annotated
# tag twice -- once as the tag object and once peeled to the commit, suffixed
# "^{}" -- while `git show-ref` reports only the tag object, so the peeled lines
# are dropped to make the two comparable. v0.1.0 is annotated, so this is load
# bearing and not a defensive flourish.
refs_remote() {
	git ls-remote --heads --tags "$1" 2>/dev/null |
		grep -v '\^{}$' |
		awk '{print $2" "$1}' | sort
}

# A bare repository refuses to delete the branch its HEAD points at: "deletion
# of the current branch prohibited". A mirror clone inherits HEAD from whatever
# branch was checked out when it was made, NOT from the default branch, so the
# mirror ends up pinning a topic branch. That is harmless right up until the
# branch is merged and pruned, at which point every future refresh fails on it
# -- which is exactly what happened on 2026-08-01, when `backup` still pointed
# at chore/o12-row-disposition after it merged.
#
# Only fixable here for a mirror on the local filesystem, where HEAD is a file
# this script can write. On a hosted remote the equivalent is the project's
# default branch setting, which git cannot change over the wire, so that case is
# reported and left alone.
ensure_remote_head() {
	remote="$1"
	head_ref=$(git ls-remote --symref "$remote" HEAD 2>/dev/null |
		awk '$1 == "ref:" {print $2; exit}')
	[ -n "$head_ref" ] || return 0
	# Still points at something local has: nothing to do.
	git show-ref --verify --quiet "$head_ref" && return 0

	url=$(git remote get-url "$remote" 2>/dev/null || echo "")
	default_ref=refs/heads/main
	git show-ref --verify --quiet "$default_ref" || return 0

	if [ -d "$url" ]; then
		git -C "$url" symbolic-ref HEAD "$default_ref"
		echo "  HEAD pointed at ${head_ref#refs/heads/}, which local no longer has; repointed to main"
	else
		echo "  WARNING: HEAD points at ${head_ref#refs/heads/}, which local no longer has."
		echo "  Change the default branch on the host; a prune of that ref will fail until then."
		status=1
	fi
}

status=0
tmp="${TMPDIR:-/tmp}/mirror-drain.$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT INT TERM

refs_local > "$tmp/local"
echo "local: $(wc -l < "$tmp/local" | tr -d ' ') heads and tags"
echo

for remote in $MIRROR_TARGETS; do
	echo "=== $remote (mirror) ==="
	if ! git ls-remote --exit-code "$remote" >/dev/null 2>&1; then
		echo "  UNREACHABLE -- skipped, not refreshed"
		status=1
		echo
		continue
	fi
	ensure_remote_head "$remote"
	if git push --no-verify --prune "$remote" \
		'+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*'; then
		:
	else
		echo "  PUSH FAILED"
		status=1
	fi
	echo
done

# Verification is the point of the script, not a postscript to it: a mirror you
# have not compared is a mirror you are assuming. Every target is checked,
# including the ones that were only pushed to a moment ago.
#
# THE TWO MODES ARE NOT THE SAME CHECK, and the difference was found by running
# this script rather than by reasoning about it. A mirror must match local
# exactly, so any difference at all is a fault. A working remote must not, and
# demanding it does makes the script cry wolf: creating a local branch before
# pushing it is the ordinary first half of the branch -> push -> MR flow, and it
# leaves local holding a ref the remote has never seen. So for a working remote
# only two things are faults -- a ref both sides have but disagree on, and a ref
# the REMOTE holds that local does not, which is the direction that means
# someone else pushed or that a local branch was deleted without being deleted
# there. A local-only ref is reported as unpushed and changes nothing.
verify_target() {
	remote="$1"
	mode="$2"
	echo "=== $remote (verify) ==="
	if ! git ls-remote --exit-code "$remote" >/dev/null 2>&1; then
		echo "  UNREACHABLE -- cannot verify"
		status=1
		echo
		return
	fi
	refs_remote "$remote" > "$tmp/remote"

	join "$tmp/local" "$tmp/remote" | awk '$2 != $3' > "$tmp/disagree"
	cut -d' ' -f1 "$tmp/local" > "$tmp/lname"
	cut -d' ' -f1 "$tmp/remote" > "$tmp/rname"
	comm -13 "$tmp/lname" "$tmp/rname" > "$tmp/remote_only"
	comm -23 "$tmp/lname" "$tmp/rname" > "$tmp/local_only"

	faults=0
	if [ -s "$tmp/disagree" ]; then
		echo "  DISAGREES on $(wc -l < "$tmp/disagree" | tr -d ' ') ref(s) (ref, local, $remote):"
		sed 's/^/    /' "$tmp/disagree"
		faults=1
	fi
	if [ -s "$tmp/remote_only" ]; then
		echo "  ON $remote BUT NOT LOCAL:"
		sed 's/^/    /' "$tmp/remote_only"
		faults=1
	fi
	if [ -s "$tmp/local_only" ]; then
		if [ "$mode" = strict ]; then
			echo "  LOCAL BUT NOT ON $remote:"
			faults=1
		else
			echo "  unpushed (expected on a working remote):"
		fi
		sed 's/^/    /' "$tmp/local_only"
	fi
	if [ "$faults" -eq 0 ]; then
		echo "  OK: $(wc -l < "$tmp/remote" | tr -d ' ') heads and tags on $remote"
	else
		status=1
	fi
	echo
}

for remote in $MIRROR_TARGETS; do
	verify_target "$remote" strict
done
for remote in $VERIFY_TARGETS; do
	verify_target "$remote" working
done

if [ "$status" -eq 0 ]; then
	echo "all targets match local"
else
	echo "at least one target is unreachable or diverges; see above" >&2
fi

exit "$status"
