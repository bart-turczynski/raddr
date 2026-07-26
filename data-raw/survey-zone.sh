#!/bin/sh
# Survey how other implementations handle the RFC 4007 IPv6 zone ID.
#
# This is a *design* measurement, not a fixture: it decides what raddr's
# `strict` dialect does (docs/architecture.md section 3.5.2) and it backs the
# separate `zone` field (section 5.1). Nothing in tests/ reads its output, so it
# is not regenerated on a schedule -- re-run it when the question comes up
# again, or when one of these implementations ships a major version.
#
# Every tool is optional. A missing one is reported and skipped, so this is
# useful on a machine that has three of them.
#
# Run from the package root:
#   sh data-raw/survey-zone.sh
#
# Recorded 2026-07-27 on macOS Darwin 25.4.0 arm64. See section 3.5.2 for the
# table this produced and what raddr concluded from it.

CASES='fe80::1%lo0 fe80::1%1 fe80::1% %lo0 fe80::1%lo0%en0 1:2:3:4:5:6:7:8%lo0 ::1%lo0 fe80::1%bogus0 fe80::1%LO0 fe80::1%99999999999'

have() { command -v "$1" >/dev/null 2>&1; }
skip() { printf '\n== %s ==\n  not installed, skipped\n' "$1"; }

# --- R: ipaddress ------------------------------------------------------------
#
# The one to read first. It accepts a zone, truncates at the first "%" and
# discards the rest silently; there is no accessor to recover it.
if have Rscript; then
  printf '\n== R ipaddress ==\n'
  Rscript -e '
    if (!requireNamespace("ipaddress", quietly = TRUE)) {
      cat("  package not installed, skipped\n"); quit()
    }
    cases <- strsplit(Sys.getenv("CASES"), " ")[[1]]
    out <- suppressWarnings(as.character(ipaddress::ip_address(cases)))
    cat(sprintf("  %-22s %s\n", cases, ifelse(is.na(out), "REJECT", out)), sep = "")
    cat(sprintf("  version %s; zone accessors: %s\n",
      as.character(utils::packageVersion("ipaddress")),
      paste(c("none", grep("zone|scope", getNamespaceExports("ipaddress"),
        value = TRUE, ignore.case = TRUE)), collapse = " ")))
  ' 2>&1
else
  skip "R ipaddress"
fi

# --- Python: ipaddress -------------------------------------------------------
#
# Also the section 3.5 oracle for the `strict` dialect. Keeps the zone as
# .scope_id, which is the design raddr's separate field agrees with.
#
# Read the address through .packed, NOT through .exploded: on every CPython
# tried, .exploded raises AddressValueError for an address carrying a scope_id,
# even though the object is valid and str() renders it. See section 3.5.2. Using
# .exploded here reports "Python rejects every zone", which is wrong, and is the
# reason data-raw/oracle-ipv6.py reads .packed too.
if have python3; then
  printf '\n== Python ipaddress ==\n'
  CASES="$CASES" python3 -c '
import ipaddress, os
for c in os.environ["CASES"].split():
    try:
        a = ipaddress.IPv6Address(c)
    except ValueError:
        print("  %-22s REJECT" % c)
        continue
    try:
        exploded = a.exploded
    except ValueError as e:
        exploded = "<%s on .exploded>" % type(e).__name__
    print("  %-22s OK   %s  scope_id=%s  exploded=%s"
          % (c, a.packed.hex(), a.scope_id, exploded))
'
else
  skip "Python ipaddress"
fi

# --- Rust: std::net::Ipv6Addr ------------------------------------------------
if have rustc; then
  printf '\n== Rust std::net::Ipv6Addr ==\n'
  dir=$(mktemp -d)
  cat > "$dir/z.rs" <<'RUST'
use std::net::Ipv6Addr;
use std::str::FromStr;
fn main() {
    for c in std::env::args().skip(1) {
        match Ipv6Addr::from_str(&c) {
            Ok(a) => println!("  {:<22} OK   {}", c, a),
            Err(_) => println!("  {:<22} REJECT", c),
        }
    }
}
RUST
  if rustc -O -o "$dir/z" "$dir/z.rs" 2>/dev/null; then
    # shellcheck disable=SC2086
    "$dir/z" $CASES
  else
    echo "  failed to compile, skipped"
  fi
  rm -rf "$dir"
else
  skip "Rust std"
fi

# --- Go: net/netip -----------------------------------------------------------
if have go; then
  printf '\n== Go net/netip ==\n'
  dir=$(mktemp -d)
  cat > "$dir/z.go" <<'GO'
package main

import (
	"fmt"
	"net/netip"
	"os"
)

func main() {
	for _, c := range os.Args[1:] {
		a, err := netip.ParseAddr(c)
		if err != nil {
			fmt.Printf("  %-22s REJECT\n", c)
		} else {
			fmt.Printf("  %-22s OK   %s  zone=%q\n", c, a.String(), a.Zone())
		}
	}
}
GO
  # shellcheck disable=SC2086
  (cd "$dir" && go mod init z >/dev/null 2>&1 && go run z.go $CASES) ||
    echo "  failed to run, skipped"
  rm -rf "$dir"
else
  skip "Go net/netip"
fi

# --- Ruby: IPAddr ------------------------------------------------------------
if have ruby; then
  printf '\n== Ruby IPAddr ==\n'
  CASES="$CASES" ruby -ripaddr -e '
    ENV["CASES"].split.each do |c|
      begin
        puts "  %-22s OK   %s" % [c, IPAddr.new(c).to_s]
      rescue StandardError
        puts "  %-22s REJECT" % c
      end
    end
  '
else
  skip "Ruby IPAddr"
fi

# --- PHP: filter_var, and inet_pton ------------------------------------------
#
# Two answers from one runtime. filter_var is the paper-ish validator and
# rejects every zone; inet_pton is a second binding to the same libc the
# section 3.5.3 oracle measured, and reproduces the interface-index fold.
if have php; then
  printf '\n== PHP filter_var / inet_pton ==\n'
  CASES="$CASES" php -r '
    foreach (explode(" ", getenv("CASES")) as $c) {
      $p = @inet_pton($c);
      $f = filter_var($c, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6);
      printf("  %-22s filter=%-7s pton=%s\n", $c,
        $f === false ? "REJECT" : "OK",
        $p === false ? "REJECT" : bin2hex($p));
    }
  '
else
  skip "PHP"
fi

# --- Node: net.isIPv6, and the WHATWG URL parser (ada) -----------------------
#
# Two layers, and they disagree: the host validator accepts a zone, the URL
# parser does not. That split is section 3.4's point about where brackets and
# zones belong.
if have node; then
  printf '\n== Node net.isIPv6 / new URL (ada) ==\n'
  CASES="$CASES" node -e '
    const net = require("net");
    for (const c of process.env.CASES.split(" ")) {
      let url = "REJECT";
      try { url = new URL("http://[" + c.replace(/%/g, "%25") + "]/").hostname; }
      catch (e) { /* stays REJECT */ }
      console.log("  " + c.padEnd(22) +
        " isIPv6=" + (net.isIPv6(c) ? "OK    " : "REJECT") +
        " URL=" + url);
    }
  '
else
  skip "Node"
fi

printf '\n'
