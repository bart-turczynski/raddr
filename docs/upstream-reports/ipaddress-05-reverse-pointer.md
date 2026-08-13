# DRAFT — not yet submitted

**Target:** https://github.com/davidchall/ipaddress/issues (new issue)
**raddr tracking issue:** RADD-gutuomse (O18)
**Blocked on:** GitHub account suspension. Submit verbatim once lifted.
**Measured:** 2026-07-30, macOS 25.4.0 arm64, R 4.6.0, ipaddress 1.0.3.

---

## Title

`reverse_pointer()` on IPv6: names end in `ip.arpa` instead of `ip6.arpa`, and vectorized calls accumulate labels across elements

## Body

### Summary

Two independent defects in `reverse_pointer()`, both confined to the IPv6 branch
and both in the same few lines of `src/reverse_pointer.cpp`:

1. **The suffix is `ip.arpa`, not `ip6.arpa`.** Every IPv6 name the function
   returns is one character short of the name reverse DNS actually uses, so none
   of them resolve.
2. **The output accumulates.** Element *k* of the result carries the nibbles of
   elements 1..*k*. Only a length-1 call is correct. Cost is quadratic in vector
   length.

IPv4 is correct on both counts.

### 1. IPv6 names use `ip.arpa`

```r
library(ipaddress)

reverse_pointer(ip_address("2001:db8::1"))
#> [1] "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip.arpa"
#                                                                        ^^^^^^^
#  expected:                                                             ip6.arpa
```

The nibble sequence is right — 32 hex nibbles, low-order first, dot-separated.
Only the suffix is wrong, by the single character `6`.

Why `ip6.arpa` is the expected name:

- **RFC 3596 section 2.5** defines the IPv6 address-to-name domain as
  `IP6.ARPA`, with nibbles "encoded in reverse order, i.e., the low-order nibble
  is encoded first". This is the section `man/reverse_pointer.Rd` already cites
  under *Details*.
- **IANA's `.arpa` registry** lists `ip6.arpa` ("For mapping IPv6 addresses to
  Internet domain names", RFC 3152) and `in-addr.arpa` (RFC 1035). It has **no
  `ip.arpa` entry** — the name is not a registered `.arpa` sub-zone at all.

So this is not a formatting preference. `ip.arpa` is not a delegated zone, which
means every IPv6 name this function has returned since it was added is
unresolvable — and it looks correct enough to pass review, because it differs
from the right answer by one character in a 71-character string.

### 2. The IPv6 branch accumulates across elements

```r
v <- reverse_pointer(ip_address(c("::1", "2001:db8::1")))

lengths(strsplit(v, ".", fixed = TRUE))
#> [1] 34 66          # element 2 has 32 extra labels

v[2]
#> [1] "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip.arpa"
```

Element 2 is `::1`'s nibbles followed by `2001:db8::1`'s. It grows linearly with
position:

```r
lengths(strsplit(reverse_pointer(ip_address(rep("::1", 5))), ".", fixed = TRUE))
#> [1]  34  66  98 130 162      # +32 nibbles per position
```

A length-1 call is correct, so this only appears once the input is a vector —
which is the normal case for this package.

The cost is quadratic. Element *k* is `64k + 7` characters, so the total output
is about `32n²` bytes:

| n | elapsed | `nchar()` of last element |
|---|---|---|
| 1000 | 0.033 s | 64,007 |
| 2000 | 0.169 s | 128,007 |
| 4000 | 0.628 s | 256,007 |
| 8000 | 2.358 s | 512,007 |

Four times the work per doubling. For contrast, IPv4 at `n = 8000` is 0.002 s —
about a thousandfold difference, entirely from the defect rather than from IPv6
being harder. Extrapolating the `32n²` figure rather than measuring it: a
million-address vector would need on the order of 10¹³ bytes of output, so the
call cannot complete.

### Cause

Both defects are visible in `src/reverse_pointer.cpp` (quoting rather than citing
line numbers, since those drift):

```cpp
  std::ostringstream os;        // <-- outside the loop
  char buffer[40];

  for (std::size_t i=0; i<vsize; ++i) {
    ...
    } else if (address[i].is_ipv6()) {
      ...
      std::string str(buffer);
      std::reverse(str.begin(), str.end());
      std::copy(str.begin(), str.end(), std::ostream_iterator<char>(os, "."));

      output[i] = os.str() + "ip.arpa";     // <-- os never cleared; suffix missing the 6
```

`os` is declared before the loop and never cleared, so `os.str()` returns
everything appended so far. The IPv4 branch escapes both defects because it uses
`snprintf` into `buffer` and never touches `os`.

### Why this went unnoticed

Worth stating plainly, because it also explains why a fix needs a new test rather
than just a corrected expectation: **the test suite asserts the current output.**
`tests/testthat/test-reverse_pointer.R` hard-codes

```r
expect_equal(
  reverse_pointer(ip_address("2001:db8::1")),
  "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip.arpa"
)
```

so defect 1 is pinned by a passing test. And every input in that file — plus both
`@examples` in the docs — is a single address, so defect 2 never had an
opportunity to show up.

### Suggested fix

Small, and both parts are one patch:

```cpp
  for (std::size_t i=0; i<vsize; ++i) {
    ...
      std::ostringstream os;                 // per iteration
      ...
      output[i] = os.str() + "ip6.arpa";     // add the 6
```

Either move the declaration inside the loop or reset it per iteration
(`os.str(""); os.clear();`). Moving it also removes the quadratic behavior, since
each `os.str()` then copies only one element's worth.

For tests, the two that would have caught these:

```r
expect_match(reverse_pointer(ip_address("2001:db8::1")), "\\.ip6\\.arpa$")
expect_equal(
  reverse_pointer(ip_address(c("::1", "2001:db8::1")))[[2]],
  reverse_pointer(ip_address("2001:db8::1"))
)
```

The second — "element *i* of a vectorized call equals the scalar call" — is worth
applying beyond this function.

Note that fixing defect 1 changes output for every existing IPv6 caller. It is
still a fix rather than a breaking change, since the old names could not resolve,
but it probably belongs in NEWS as a behavior change.

### Context

Found while building [raddr](https://gitlab.com/bart-turczynski/raddr), an
offline IP parsing and classification package, whose own reverse-pointer
implementation was cross-checked against this one and against CPython's
`ipaddress`. Fourth and fifth reports from the same comparison, alongside the
`0x80000000` equality issue, the NAT64 gap, and the silently discarded IPv6 zone.

---

## Notes to self (not part of the submission)

- **Filed as one issue, not two,** unlike the O11 pair. O11's two bugs were in
  different functions; these two are adjacent lines in one function, fixed by one
  patch, and pinned by the same test file. Splitting them would mean two issues
  whose fixes conflict. The body numbers them so neither gets lost in triage.
- **Duplicate check, 2026-07-30, over the web** (the suspension blocks
  authenticated access only): 12 issues total, only #101 open, nothing touching
  `reverse_pointer`, `ip6.arpa` or vectorized output. **66 PRs, zero open**, so
  no fix is in flight. PR #57 "Pointer used by reverse DNS" is where both defects
  entered — the `ostringstream` was outside the loop in that diff too, and the
  suffix was already `"ip.arpa"`, so neither is a later regression.
- **Deliberately did not claim an RFC 2119 violation.** RFC 3596 section 2.5 uses
  no MUST/SHALL — it is descriptive ("is defined", "is represented"). Checked at
  the source rather than assumed. The report rests on the stronger and simpler
  fact that `ip.arpa` is not a registered `.arpa` zone, so the names cannot
  resolve; that needs no normative keyword.
- **The `32n²` figure is arithmetic, not a measurement,** and the draft says so.
  Derived from the measured `64k + 7` per-element growth, which matches the table
  exactly at every n. Did not actually run n = 1e6.
- Architecture O18 said "IPv4 is correct on both counts, modulo the trailing dot,
  which is a choice". Confirmed: IPv4 output has no trailing dot
  (`1.2.0.192.in-addr.arpa`), and neither does IPv6. Left it out of the report —
  a relative name without the root dot is the normal convention here and is not
  a defect.
- The nibble reversal itself is correct; I verified the order rather than assuming
  it, since a reversed-string trick is exactly where an off-by-one would hide.
  Only the suffix and the accumulation are wrong, and the report says only that.
