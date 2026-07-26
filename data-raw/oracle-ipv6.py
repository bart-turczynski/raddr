"""Measure inet_pton, inet_aton and getaddrinfo on IPv6 literals.

The IPv6 companion to data-raw/oracle-ipv4.py, and the same argument applies:
the "in reality" dialects of docs/architecture.md section 3.1 are claims about
an implementation rather than a standard, so raddr models them against a
measurement. Run this and data-raw/oracle-ipv6.R after any libc upgrade; the
fixture they write is asserted by tests/testthat/test-ipv6.R, so drift fails
loudly.

    python3 data-raw/oracle-ipv6.py > tests/testthat/fixtures/ipv6-libc.csv

Four things this measures that a document would not tell you:

* whether Apple's inet_pton accepts a zone ID at all, and what it does with it
  if it does -- section 5.1 records that it folds the interface index into the
  address bytes, which is why raddr stores the zone in its own field;
* what getaddrinfo reports as the scope ID, separately from the address, which
  is the shape raddr's record already has;
* that inet_aton has no IPv6 reading whatsoever. It is measured rather than
  asserted, because addr_curl() composes it (section 3.2) and the composition
  is only meaningful if the aton half really is a rejection for every IPv6
  literal;
* what Python's `ipaddress` accepts. Section 3.1 names it as a reference for
  the `strict` dialect, and the RFC 4291 IPv6 grammar has enough corners that
  reading the grammar and reading an implementation of it are different acts.
  The `pyip` column is evidence for a paper dialect, exactly as the ada column
  in data-raw/oracle-ipv6.R is; it is not a libc measurement.

Addresses are written as the fully expanded eight-hextet lowercase form, so the
fixture says nothing about RFC 5952 formatting, which is its own body of work.

Recorded on macOS Darwin 25.4.0 arm64, Apple libc, 2026-07-26.
"""
import csv
import ctypes
import ctypes.util
import ipaddress
import socket
import sys

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)


class in_addr(ctypes.Structure):
    _fields_ = [("s_addr", ctypes.c_uint32)]


libc.inet_pton.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p]
libc.inet_pton.restype = ctypes.c_int
libc.inet_aton.argtypes = [ctypes.c_char_p, ctypes.POINTER(in_addr)]
libc.inet_aton.restype = ctypes.c_int

REJECT = ""


def expand(raw):
    """Sixteen bytes as the fully expanded eight-hextet lowercase form."""
    return ":".join(
        "%04x" % int.from_bytes(raw[i:i + 2], "big") for i in range(0, 16, 2)
    )


def pton6(s):
    buf = (ctypes.c_ubyte * 16)()
    rc = libc.inet_pton(socket.AF_INET6, s.encode(), ctypes.byref(buf))
    return expand(bytes(buf)) if rc == 1 else REJECT


def aton(s):
    """inet_aton is AF_INET by signature. Measured, not assumed."""
    buf = in_addr()
    rc = libc.inet_aton(s.encode(), ctypes.byref(buf))
    if rc == 0:
        return REJECT
    return ".".join(str(b) for b in buf.s_addr.to_bytes(4, "little"))


def getaddrinfo6(s):
    """Returns (expanded address, scope id). The scope is reported beside the
    address rather than inside it, which is the shape raddr's record has."""
    try:
        info = socket.getaddrinfo(
            s, None, socket.AF_INET6, 0, 0, socket.AI_NUMERICHOST
        )
    except (OSError, UnicodeError):
        return REJECT, REJECT
    host, _port, _flow, scope = info[0][4]
    # The reported host may carry the zone back as a suffix; the numeric scope
    # is the authoritative field, so the suffix is dropped here.
    host = host.split("%", 1)[0]
    return expand(socket.inet_pton(socket.AF_INET6, host)), str(scope)


def pyip(s):
    """Returns (expanded address, zone). Python's ipaddress accepts an RFC 4007
    zone ID and keeps it out of the bytes, which is the same split raddr uses,
    so the two halves are recorded separately."""
    try:
        addr = ipaddress.IPv6Address(s)
    except (ipaddress.AddressValueError, ValueError):
        return REJECT, REJECT
    return expand(addr.packed), addr.scope_id or REJECT


CASES = [
    # the canonical shapes
    "::", "::1", "1::", "fe80::1", "2001:db8::1",
    "2001:0db8:0000:0000:0000:0000:0000:0001",
    "1:2:3:4:5:6:7:8", "0:0:0:0:0:0:0:0",
    "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
    # case folding, and hextet width
    "FE80::1", "Fe80::1", "0001:0002:0003:0004:0005:0006:0007:0008",
    "00001::", "1::00001", "1:2:3:4:5:6:7:00008",
    # how wide a hextet may run once the leading zeros are discounted
    "01234::", "12345::", "0abcd::", "abcde::", "0000000000001::",
    "0000000000012345::", "ffff1::",
    # where :: may sit, and how many there may be
    "::1:2:3:4:5:6:7", "1:2:3:4:5:6:7::", "1::8", "1:2::7:8",
    "1::2::3", "::1::", ":::", "::::",
    # a lone colon, and colons in the wrong places
    ":", ":1", "1:", ":1:2", "1:2:", "1:::2", "::1:", ":1::",
    # arity: too few and too many groups
    "1:2:3:4:5:6:7", "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7:8::",
    "::1:2:3:4:5:6:7:8", "1", "12345",
    # the dotted-quad tail
    "::1.2.3.4", "::ffff:1.2.3.4", "::ffff:127.0.0.1", "64:ff9b::1.2.3.4",
    "1:2:3:4:5:6:1.2.3.4", "1:2:3:4:5:6:7:1.2.3.4",
    "::ffff:0:1.2.3.4", "1.2.3.4",
    # the tail's own grammar: leading zeros, short forms, hex, octal, bounds
    "::1.2.3.04", "::1.2.3.004", "::01.2.3.4", "::1.2.3", "::1.2.3.4.5",
    "::1.2.3.", "::.1.2.3", "::0x1.2.3.4", "::1.2.3.256", "::1.2.3.999",
    "::0.0.0.0", "::255.255.255.255", "::1.2.3.4:5",
    "::1.2.3.0000004", "::00000000001.2.3.4", "::1.02.3.4",
    # zone IDs -- named, numeric, absent and bogus
    "fe80::1%lo0", "fe80::1%en0", "fe80::1%1", "fe80::1%2", "fe80::1%0",
    "fe80::1%", "fe80::1%bogus0", "%lo0", "::1%lo0", "::%lo0",
    "fe80::1%lo0%en0", "2001:db8::1%lo0",
    # which addresses the interface index gets folded into, and over what
    "fe80::1%LO0", "fe80:1::1%lo0", "fe80:abcd::1%lo0", "fe80::1:2:3:4%lo0",
    "ff02::1%lo0", "ff01::1%lo0", "ff05::1%lo0", "fec0::1%lo0",
    "fe80::1%lo0 ", "fe80::1 %lo0", "::ffff:1.2.3.4%lo0",
    "1:2:3:4:5:6:7:8%lo0", "fe80::%lo0", "fe80::1%99999999999",
    # getaddrinfo runs the fold in reverse: on fe80::/10 it lifts the second
    # hextet out into the scope ID and clears it, zone ID or no zone ID. This
    # is a pure function of the input, unlike inet_pton's fold, so raddr models
    # it -- see section 3.5.
    "fe80:abcd::1", "fe80:1::1", "fe80:ffff::1", "fe80:abcd:1234::1",
    "fe80:1:2:3:4:5:6:7", "fe80::1:0:0:0", "fe80:abcd::1%1",
    "fe81:1::1", "fe8f:1::1", "fe90:1::1", "fea0:1::1", "febf:1::1",
    "fec0:1::1", "fe7f:1::1", "ff02:1::1", "ff02:abcd::1", "2001:abcd::1",
    # non-hex digits and other junk
    "::g", "::1g", "1:2:3:4:5:6:7:g", "::-1", "::+1", "12345678::",
    # brackets belong to the URL layer, not the address layer
    "[::1]", "[::1", "::1]",
    # whitespace, which is where the IPv4 dialects diverged most
    "::1 ", " ::1", "::1\t", "::1 x", "::1junk", "",
]


# Control characters are escaped in the fixture so the file stays plain ASCII
# and git's line-ending normalization cannot quietly rewrite a test input.
#
# The space is escaped too, which the IPv4 oracle does not need to do. A zone ID
# runs to the end of the literal, so it can carry a trailing space -- and a zone
# is the last column here, which puts that space at the end of a line where the
# repository's trailing-whitespace hook eats it. Escaping every space is simpler
# than escaping only the ones that land there.
ESCAPES = {"\t": "\\t", "\r": "\\r", "\n": "\\n", "\v": "\\v", "\f": "\\f",
           " ": "\\s", "\\": "\\\\"}


def escape(s):
    return "".join(ESCAPES.get(ch, ch) for ch in s)


def main():
    out = csv.writer(sys.stdout, lineterminator="\n")
    out.writerow(
        ["input", "pton", "aton", "getaddrinfo", "gai_scope", "pyip",
         "pyip_zone"]
    )
    for case in CASES:
        gai, scope = getaddrinfo6(case)
        strict, zone = pyip(case)
        row = [case, pton6(case), aton(case), gai, scope, strict, zone]
        out.writerow([escape(field) for field in row])


if __name__ == "__main__":
    main()
