"""Measure inet_pton, inet_aton and getaddrinfo on this machine.

These are the "in reality" dialects of docs/architecture.md section 3.1, and
they are claims about an implementation rather than a standard, so raddr models
them against a measurement rather than against a document. Run this and
data-raw/oracle-ipv4.R after any libc or curl upgrade; the fixture they write is
asserted by tests/testthat/test-ipv4.R, so drift fails loudly.

    python3 data-raw/oracle-ipv4.py > tests/testthat/fixtures/ipv4-libc.csv

Recorded on macOS Darwin 25.4.0 arm64, Apple libc, 2026-07-26.
"""
import csv
import ctypes
import ctypes.util
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


def dotted(s_addr):
    return ".".join(str(b) for b in s_addr.to_bytes(4, "little"))


def pton(s):
    buf = in_addr()
    rc = libc.inet_pton(socket.AF_INET, s.encode(), ctypes.byref(buf))
    return dotted(buf.s_addr) if rc == 1 else REJECT


def aton(s):
    buf = in_addr()
    rc = libc.inet_aton(s.encode(), ctypes.byref(buf))
    return dotted(buf.s_addr) if rc != 0 else REJECT


def getaddrinfo(s):
    try:
        info = socket.getaddrinfo(
            s, None, socket.AF_INET, 0, 0, socket.AI_NUMERICHOST
        )
        return info[0][4][0]
    except (OSError, UnicodeError):
        # Python's idna codec rejects some inputs before libc sees them; those
        # are rejections either way.
        return REJECT


CASES = [
    # the headline divergences
    "127.0.0.1", "0177.0.0.1", "192.0.010.1", "192.0.048.1",
    "4294967296", "1.2.3.", "2130706433", "10.048.1.1",
    # arity, and the short forms
    "1.2.3.4.5", "1.2.3", "1.2", "1", "", "127.1", "127.0.1",
    # dots in the wrong places
    "1.2.3.4.", ".1.2.3.4", "1.2.3.4..", "1..2.3", ".", "..", "0.", ".0",
    # leading zeros, and how wide they may run
    "00000000177.0.0.1", "0000000000000000001.0.0.1",
    "010.010.010.010", "0.0.0.010", "0.0.0.0", "255.255.255.255",
    # per-part bounds at each arity
    "256.0.0.1", "1.256.0.1", "1.2.3.256", "999.0.0.1",
    "127.16777215", "127.16777216", "127.0.65535", "127.0.65536",
    "1.2.3.255", "1.4294967296", "1.2.4294967296", "1.2.3.4294967296",
    # hex
    "0x7f.0.0.1", "0x7f000001", "0X7F000001", "0xff.0xff.0xff.0xff",
    "0x100000000", "0x0", "0xg", "0x1p", "00x1", "0x7f.1",
    # a digitless 0x, which inet_aton allows everywhere but the final part
    "0x", "0X", "0x.1", "0x.0x", "1.0x", "0x.0x.0", "0x.0x.0x.0x", "1.2.0x",
    # octal
    "0177.0.0.01", "07777777777", "040000000000", "08", "09", "00", "0", "01",
    # whole-host numbers, and what happens past 2^32
    "16777217", "4294967295", "4294967297",
    "18446744073709551615", "18446744073709551616",
    "99999999999999999999999999", "0xffffffffffffffffff",
    # inet_aton stops at the first whitespace and ignores the rest
    "1.2.3.4 ", "1.2.3.4\t", "1.2.3.4\r\n", "1.2.3.4  ", "1.2.3.4 x",
    "1.2.3.4x", " 1.2.3.4", "\t1.2.3.4", "1.2 .3.4", "1 ", " ",
    "127.0.0.1 junk", "1.2.3.4\x0b", "1.2.3.4\x0c",
    # not numbers at all
    "1e2", "+1.2.3.4", "-1.2.3.4",
]


# Control characters are escaped in the fixture so the file stays plain ASCII
# and git's line-ending normalization cannot quietly rewrite a test input.
ESCAPES = {"\t": "\\t", "\r": "\\r", "\n": "\\n", "\v": "\\v", "\f": "\\f",
           "\\": "\\\\"}


def escape(s):
    return "".join(ESCAPES.get(ch, ch) for ch in s)


def main():
    out = csv.writer(sys.stdout, lineterminator="\n")
    out.writerow(["input", "pton", "aton", "getaddrinfo"])
    for case in CASES:
        out.writerow(
            [escape(case), pton(case), aton(case), getaddrinfo(case)]
        )


if __name__ == "__main__":
    main()
