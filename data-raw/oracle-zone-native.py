"""Ask the zone-ID questions with the *local* interface names substituted in.

`data-raw/oracle-ipv6.py` writes `%lo0` and `%en0`, which are Apple interface
names. Run that corpus on Linux and every zone-name row comes back a rejection
-- but for the wrong reason. `lo0` does not exist there; the loopback is `lo`.
The row measures the container's interface table, not glibc.

So the zone questions are asked again here, with `{lo}` and `{other}` filled in
from `socket.if_nameindex()` on whatever host this runs on. Each platform is
asked about names it actually has, which is what makes the answers comparable:
the finding is the *rule* each libc applies to a resolvable name, not whether a
particular string happened to resolve.

    python3 data-raw/oracle-zone-native.py > tests/testthat/fixtures/zone-native-<libc>.csv

Three questions section 3.5.3 could not settle from the Apple corpus alone:

* does `inet_pton` accept a zone ID at all, and does it fold the interface index
  into the address bytes -- section 5.1 records that Apple's does;
* does `getaddrinfo` lift an embedded scope out of `fe80::/10`, clearing the
  second hextet -- section 3.5.3 records that Apple's does, and `addr_curl()`
  inherits it through the section 3.2 composition;
* which addresses may carry a zone at all. Apple takes one on anything; the
  question is whether that is universal.

The `input` column is the literal after substitution, so the fixture is readable
on its own; `template` keeps the unsubstituted form so rows line up across
platforms that spell their loopback differently.
"""
import csv
import ctypes
import ctypes.util
import socket
import sys

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.inet_pton.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p]
libc.inet_pton.restype = ctypes.c_int

REJECT = ""

TEMPLATES = [
    # a resolvable name, on a link-local address: the fold and the lift
    "fe80::1%{lo}",
    # the same name in the wrong case, which Apple does not resolve
    "fe80::1%{LO}",
    # a numeric zone, which needs no interface table at all
    "fe80::1%1",
    # a name that resolves nowhere
    "fe80::1%bogus0",
    # a second hextet to lift or fold *over*, with and without a zone
    "fe80:abcd::1%{lo}",
    "fe80:abcd::1",
    "fe80:abcd::1%1",
    "fe80::1",
    "fe80:1::1",
    "fe80::%{lo}",
    # which address families may carry a zone: global, loopback, multicast
    "2001:db8::1%{lo}",
    "::1%{lo}",
    "ff02::1%{lo}",
    "1:2:3:4:5:6:7:8%{lo}",
    # a second interface, to show the index is the interface's and not a constant
    "fe80::1%{other}",
]


def expand(raw):
    return ":".join(
        "%04x" % int.from_bytes(raw[i:i + 2], "big") for i in range(0, 16, 2)
    )


def pton6(s):
    buf = (ctypes.c_ubyte * 16)()
    rc = libc.inet_pton(socket.AF_INET6, s.encode(), ctypes.byref(buf))
    return expand(bytes(buf)) if rc == 1 else REJECT


def getaddrinfo6(s):
    try:
        info = socket.getaddrinfo(
            s, None, socket.AF_INET6, 0, 0, socket.AI_NUMERICHOST
        )
    except (OSError, UnicodeError):
        return REJECT, REJECT
    host, _port, _flow, scope = info[0][4]
    return expand(socket.inet_pton(socket.AF_INET6, host.split("%", 1)[0])), str(scope)


def names():
    """The local loopback and the first interface that is not it.

    Taken from the interface table rather than hardcoded, because that table is
    exactly what the Apple corpus accidentally measured.
    """
    table = [name for _index, name in socket.if_nameindex()]
    lo = next((n for n in table if n.startswith("lo")), table[0])
    other = next((n for n in table if n != lo), lo)
    return lo, other


def main():
    lo, other = names()
    print("interfaces: %s" % ", ".join(n for _i, n in socket.if_nameindex()),
          file=sys.stderr)
    out = csv.writer(sys.stdout, lineterminator="\n")
    out.writerow(["template", "input", "pton", "getaddrinfo", "gai_scope"])
    for template in TEMPLATES:
        literal = template.format(lo=lo, LO=lo.upper(), other=other)
        gai, scope = getaddrinfo6(literal)
        out.writerow([template, literal, pton6(literal), gai, scope])


if __name__ == "__main__":
    main()
