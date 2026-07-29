#!/bin/sh
# Run the libc oracles on glibc and musl, which is what open items O6 and O6b
# asked for.
#
#     sh data-raw/oracle-libc-linux.sh
#
# The Apple rows come from running data-raw/oracle-ipv4.py and
# data-raw/oracle-ipv6.py directly; those two fixtures are the ones the dialect
# tests assert against, because Apple is the libc raddr models (section 3.1).
# The Linux rows are recorded rather than modelled: they are what makes the
# "platform-varying" label in section 3.1 a measurement instead of a hedge, and
# tests/testthat/test-libc.R asserts the *divergence set* so that a libc upgrade
# in either image changes a committed file rather than passing quietly.
#
# Two images, because glibc and musl are not the same answer -- musl's
# inet_aton refuses the trailing whitespace that glibc's and Apple's accept, and
# that is the whole of the difference between them (section 3.3).
#
# Requires Docker. Nothing else in the package does, which is why this is a
# separate script rather than a branch inside the Python oracles: the corpus
# they run is byte-identical, only the libc under it changes.

set -eu

cd "$(dirname "$0")/.."
FIX=tests/testthat/fixtures

run() {
    image=$1
    libc=$2
    install=$3
    for probe in oracle-ipv4 oracle-ipv6 oracle-zone-native; do
        case $probe in
            oracle-ipv4) out=$FIX/ipv4-libc-$libc.csv ;;
            oracle-ipv6) out=$FIX/ipv6-libc-$libc.csv ;;
            *)           out=$FIX/zone-native-$libc.csv ;;
        esac
        printf '%s <- %s (%s)\n' "$out" "$probe" "$image" >&2
        # The install chain is braced before it is redirected: `a && b >/dev/null`
        # would silence only `b`, and the package manager's chatter would land
        # in the fixture ahead of its header row.
        docker run --rm -v "$PWD/data-raw:/oracle:ro" "$image" \
            sh -c "{ $install ; } >/dev/null 2>&1; python3 /oracle/$probe.py" >"$out"
    done
}

run debian:bookworm-slim glibc 'apt-get update && apt-get install -y python3'
run alpine:3.20          musl  'apk add --no-cache python3'

# Apple's own row for the zone probe, which needs no container -- the point of
# the probe is that it uses whatever interface names the host actually has.
python3 data-raw/oracle-zone-native.py >$FIX/zone-native-apple.csv
printf '%s <- oracle-zone-native (local)\n' "$FIX/zone-native-apple.csv" >&2
