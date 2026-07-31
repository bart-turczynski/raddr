"""Read NUL-delimited literals and report Python ipaddress readings.

Output is two NUL-delimited fields per input: the normalized address, then the
scope ID. A rejection is two empty fields. IPv6 is fully expanded so this
probe measures parsing rather than formatting.
"""

import ipaddress
import sys


def reading(literal):
    try:
        address = ipaddress.ip_address(literal)
    except ValueError:
        return "", ""

    if address.version == 4:
        return str(address), ""
    raw = address.packed
    expanded = ":".join(
        f"{int.from_bytes(raw[i:i + 2], 'big'):04x}"
        for i in range(0, 16, 2)
    )
    return expanded, address.scope_id or ""


def main():
    payload = sys.stdin.buffer.read()
    literals = payload.split(b"\0")
    if literals and literals[-1] == b"":
        literals.pop()

    output = bytearray()
    for raw in literals:
        try:
            literal = raw.decode("utf-8")
            address, zone = reading(literal)
        except UnicodeError:
            address, zone = "", ""
        output.extend(address.encode("utf-8"))
        output.append(0)
        output.extend(zone.encode("utf-8"))
        output.append(0)
    sys.stdout.buffer.write(output)


if __name__ == "__main__":
    main()
