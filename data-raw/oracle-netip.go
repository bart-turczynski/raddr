// Measure Go's net/netip on the same inputs the other oracles cover.
//
// docs/architecture.md section 3.1 groups Python ipaddress, Go and Rust
// together as one "strict" dialect -- the RFC grammar, on paper. Python is
// already measured (the pyip column). Go is not, so the grouping rests on an
// assertion about an implementation nobody ran. This program runs it, and any
// row where Go and Python disagree falsifies the grouping rather than raddr.
//
// Invoked by data-raw/oracle-ipv4.R and data-raw/oracle-ipv6.R:
//
//	go run data-raw/oracle-netip.go -family 4 < literals.bin > answers.bin
//
// The wire format is NUL-separated on both sides. The fixtures escape control
// characters so they stay plain ASCII, but the escaping is applied by R's
// sequential unescape_control() and is not a grammar this program should try
// to reimplement -- a second copy of that function is a second thing to get
// wrong. So R unescapes, and passes raw bytes with a delimiter that cannot
// occur in any literal the corpus carries.
//
// Input:  literal NUL literal NUL ...
// Output: addr NUL zone NUL addr NUL zone NUL ...   (one pair per input)
//
// An address netip rejects, or one that parses into the other family, comes
// back as the empty string -- the same "reject" convention the CSV fixtures
// use. The zone is reported separately rather than folded into the address,
// because section 5.3.6 says that where two absences mean different things the
// field that tells them apart has to be shipped.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"net/netip"
	"os"
)

// expand writes the fully expanded 8-group form the IPv6 fixtures store, so
// the recorded answer says nothing about formatting -- that is Epic E's
// subject, not this oracle's.
func expand(a netip.Addr) string {
	b := a.As16()
	out := make([]byte, 0, 39)
	for i := 0; i < 16; i += 2 {
		if i > 0 {
			out = append(out, ':')
		}
		out = append(out, []byte(fmt.Sprintf("%02x%02x", b[i], b[i+1]))...)
	}
	return string(out)
}

func answer(literal string, family int) (string, string) {
	a, err := netip.ParseAddr(literal)
	if err != nil {
		return "", ""
	}
	// netip keeps 4-in-6 addresses as v6 (Is4() is false, Is4In6() is true),
	// which is the distinction raddr's v6_4in6 also keeps. Asking the v4
	// oracle about one is out of family and is recorded as a rejection.
	if family == 4 {
		if !a.Is4() {
			return "", ""
		}
		return a.Unmap().String(), a.Zone()
	}
	if a.Is4() {
		return "", ""
	}
	return expand(a), a.Zone()
}

func main() {
	family := flag.Int("family", 0, "address family to report: 4 or 6")
	flag.Parse()
	if *family != 4 && *family != 6 {
		fmt.Fprintln(os.Stderr, "oracle-netip: -family must be 4 or 6")
		os.Exit(2)
	}

	in, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintln(os.Stderr, "oracle-netip:", err)
		os.Exit(1)
	}

	// A trailing delimiter leaves an empty final element that is not an input.
	parts := bytes.Split(in, []byte{0})
	if len(parts) > 0 && len(parts[len(parts)-1]) == 0 {
		parts = parts[:len(parts)-1]
	}

	out := bytes.NewBuffer(nil)
	for _, p := range parts {
		addr, zone := answer(string(p), *family)
		out.WriteString(addr)
		out.WriteByte(0)
		out.WriteString(zone)
		out.WriteByte(0)
	}
	if _, err := os.Stdout.Write(out.Bytes()); err != nil {
		fmt.Fprintln(os.Stderr, "oracle-netip:", err)
		os.Exit(1)
	}
}
