# IANA address registries — primary-source inventory

**Retrieved:** 2026-07-27 (all fetches over HTTPS from `www.iana.org` and `www.rfc-editor.org`).

This document is a transcription of the IANA registries that `raddr` classifies against.
Every table below is reproduced from the registry's own CSV export, at the registry's own
granularity, without collapsing, merging, normalising, or re-sorting rows. Where the CSV and
the rendered XHTML differ, both forms are recorded and the difference is called out in
[Registry gotchas](#registry-gotchas).

Cell rendering conventions used throughout:

- An empty registry cell is shown as `*(empty)*`. The underlying value is the **empty string**,
  not `N/A`, not `False`, not `-`.
- A value that contains an embedded newline in the CSV is shown joined with `<br>`; the raw CSV
  value has a literal `\n` followed by eight spaces of indentation.
- Footnote markers such as `[1]`, `[2]`, `(*)` are reproduced **inside** the cell exactly where
  IANA puts them, including when they sit inside the address/prefix column.
- Pipe characters and `<` are backslash-escaped for Markdown only.

## Source metadata

| registry | page `Last Updated` | file fetched | HTTP `Last-Modified` |
|---|---|---|---|
| IPv4 Address Space | 2025-10-10 | `ipv4-address-space.csv` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv4 Address Space | 2025-10-10 | `ipv4-address-space.xhtml` | Sat, 11 Oct 2025 00:26:15 GMT |
| IPv6 Address Space | 2025-10-23 | `ipv6-address-space-1.csv` | Sat, 11 Oct 2025 00:06:16 GMT |
| IPv6 Address Space | 2025-10-23 | `ipv6-address-space.xhtml` | Thu, 23 Oct 2025 18:31:17 GMT |
| IPv4 Special-Purpose | 2025-10-09 | `iana-ipv4-special-registry-1.csv` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv4 Special-Purpose | 2025-10-09 | `iana-ipv4-special-registry.xhtml` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv6 Special-Purpose | 2025-10-09 | `iana-ipv6-special-registry-1.csv` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv6 Special-Purpose | 2025-10-09 | `iana-ipv6-special-registry.xhtml` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv6 Global Unicast Assignments | 2025-10-10 | `ipv6-unicast-address-assignments.csv` | Sat, 11 Oct 2025 00:06:16 GMT |
| IPv6 Global Unicast Assignments | 2025-10-10 | `ipv6-unicast-address-assignments.xhtml` | Sat, 11 Oct 2025 00:26:15 GMT |
| IPv4 Multicast | 2026-06-26 | `multicast-addresses.xhtml` | Sat, 27 Jun 2026 04:21:22 GMT |
| IPv4 Multicast | 2026-06-26 | `multicast-addresses-1.csv` | Tue, 04 Nov 2025 08:36:20 GMT |
| IPv4 Multicast | 2026-06-26 | `glop.csv`, `unicast-prefix-based.csv`, `multicast-addresses-13.csv` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv6 Multicast | 2026-04-07 | `ipv6-multicast-addresses.xhtml` | Tue, 07 Apr 2026 18:26:20 GMT |
| IPv6 Multicast | 2026-04-07 | `node-local.csv`, `link-local.csv`, `site-local.csv`, `variable.csv` | Tue, 07 Apr 2026 18:26:20 GMT |
| IPv6 Multicast | 2026-04-07 | `ipv6-scope.csv` | Thu, 09 Oct 2025 21:51:16 GMT |
| IPv6 Multicast | 2026-04-07 | `unicast-multicast-group-ids.csv`, `dynamic-multicast-group-ids.csv` | Thu, 19 Mar 2026 09:21:20 GMT |
| RFC 4291 | — | `https://www.rfc-editor.org/rfc/rfc4291.txt` | not sent |
| RFC 7371 | — | `https://www.rfc-editor.org/rfc/rfc7371.txt` | not sent |

`Last-Modified` is **not** a content-change timestamp for every file: many unrelated CSVs across
different registries share the identical second `Thu, 09 Oct 2025 21:51:16 GMT`, which is a site
build/deploy timestamp. The per-page `Last Updated` field inside the XHTML is IANA's own editorial
date and is the more meaningful signal, but it is page-level: the IPv4 multicast page says
`2026-06-26` while several of its own CSV exports carry a 2025 `Last-Modified`.

## 1. IANA IPv4 Address Space Registry

URL: <https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.xhtml>
CSV: <https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.csv>

256 records, one per /8. **The prefix column is not CIDR.** It is IANA's own `NNN/8` shorthand:
`000/8`, `001/8`, ..., `255/8`. `000/8` must be expanded to `0.0.0.0/8`, `010/8` to `10.0.0.0/8`,
and so on. Leading zeros are significant to the string form and absent from the CIDR form.

The CSV column headers are, verbatim: `Prefix,Designation,Date,WHOIS,RDAP,Status [1],Note` — note
the footnote marker `[1]` embedded in the **header** of the Status column.

The table below maps IANA's columns onto the requested schema: `prefix` = Prefix (with the CIDR
expansion added in brackets for clarity — IANA does not supply it), `name` = Designation,
`RFC(s)` = the RFCs cited by the referenced footnotes (IANA supplies no RFC column here at all;
the RFCs live only in footnote prose), `date` = Date, `notes` = Status + Note markers.

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 000/8 [= 0.0.0.0/8] | IANA - Local Identification | RFC791 §3.2; RFC1122 §3.2.1.3 | 1981-09 | Status=RESERVED; Note=[2][3] |
| 001/8 [= 1.0.0.0/8] | APNIC | *(empty)* | 2010-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 002/8 [= 2.0.0.0/8] | RIPE NCC | *(empty)* | 2009-09 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 003/8 [= 3.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 004/8 [= 4.0.0.0/8] | Administered by ARIN | *(empty)* | 1992-12 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 005/8 [= 5.0.0.0/8] | RIPE NCC | *(empty)* | 2010-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 006/8 [= 6.0.0.0/8] | Army Information Systems Center | *(empty)* | 1994-02 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 007/8 [= 7.0.0.0/8] | Administered by ARIN | *(empty)* | 1995-04 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 008/8 [= 8.0.0.0/8] | Administered by ARIN | *(empty)* | 1992-12 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 009/8 [= 9.0.0.0/8] | Administered by ARIN | *(empty)* | 1992-08 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 010/8 [= 10.0.0.0/8] | IANA - Private Use | RFC1918 | 1995-06 | Status=RESERVED; Note=[4] |
| 011/8 [= 11.0.0.0/8] | DoD Intel Information Systems | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 012/8 [= 12.0.0.0/8] | AT&T Bell Laboratories | *(empty)* | 1995-06 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 013/8 [= 13.0.0.0/8] | Administered by ARIN | *(empty)* | 1991-09 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 014/8 [= 14.0.0.0/8] | APNIC | RFC1356 | 2010-04 | Status=ALLOCATED; Note=[5]; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 015/8 [= 15.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 016/8 [= 16.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-11 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 017/8 [= 17.0.0.0/8] | Apple Computer Inc. | *(empty)* | 1992-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 018/8 [= 18.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-01 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 019/8 [= 19.0.0.0/8] | Ford Motor Company | *(empty)* | 1995-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 020/8 [= 20.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-10 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 021/8 [= 21.0.0.0/8] | DDN-RVN | *(empty)* | 1991-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 022/8 [= 22.0.0.0/8] | Defense Information Systems Agency | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 023/8 [= 23.0.0.0/8] | ARIN | *(empty)* | 2010-11 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 024/8 [= 24.0.0.0/8] | ARIN | *(empty)* | 2001-05 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 025/8 [= 25.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1995-01 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 026/8 [= 26.0.0.0/8] | Defense Information Systems Agency | *(empty)* | 1995-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 027/8 [= 27.0.0.0/8] | APNIC | *(empty)* | 2010-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 028/8 [= 28.0.0.0/8] | DSI-North | *(empty)* | 1992-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 029/8 [= 29.0.0.0/8] | Defense Information Systems Agency | *(empty)* | 1991-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 030/8 [= 30.0.0.0/8] | Defense Information Systems Agency | *(empty)* | 1991-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 031/8 [= 31.0.0.0/8] | RIPE NCC | *(empty)* | 2010-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 032/8 [= 32.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-06 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 033/8 [= 33.0.0.0/8] | DLA Systems Automation Center | *(empty)* | 1991-01 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 034/8 [= 34.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-03 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 035/8 [= 35.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-04 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 036/8 [= 36.0.0.0/8] | APNIC | *(empty)* | 2010-10 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 037/8 [= 37.0.0.0/8] | RIPE NCC | *(empty)* | 2010-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 038/8 [= 38.0.0.0/8] | PSINet, Inc. | *(empty)* | 1994-09 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 039/8 [= 39.0.0.0/8] | APNIC | *(empty)* | 2011-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 040/8 [= 40.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-06 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 041/8 [= 41.0.0.0/8] | AFRINIC | *(empty)* | 2005-04 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 042/8 [= 42.0.0.0/8] | APNIC | *(empty)* | 2010-10 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 043/8 [= 43.0.0.0/8] | Administered by APNIC | *(empty)* | 1991-01 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 044/8 [= 44.0.0.0/8] | Administered by ARIN | *(empty)* | 1992-07 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 045/8 [= 45.0.0.0/8] | Administered by ARIN | *(empty)* | 1995-01 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 046/8 [= 46.0.0.0/8] | RIPE NCC | *(empty)* | 2009-09 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 047/8 [= 47.0.0.0/8] | Administered by ARIN | *(empty)* | 1991-01 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 048/8 [= 48.0.0.0/8] | Administered by ARIN | *(empty)* | 1995-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 049/8 [= 49.0.0.0/8] | APNIC | *(empty)* | 2010-08 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 050/8 [= 50.0.0.0/8] | ARIN | *(empty)* | 2010-02 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 051/8 [= 51.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1994-08 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 052/8 [= 52.0.0.0/8] | Administered by ARIN | *(empty)* | 1991-12 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 053/8 [= 53.0.0.0/8] | Daimler AG | *(empty)* | 1993-10 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 054/8 [= 54.0.0.0/8] | Administered by ARIN | *(empty)* | 1992-03 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 055/8 [= 55.0.0.0/8] | DoD Network Information Center | *(empty)* | 1995-04 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 056/8 [= 56.0.0.0/8] | Administered by ARIN | *(empty)* | 1994-06 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 057/8 [= 57.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1995-05 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 058/8 [= 58.0.0.0/8] | APNIC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 059/8 [= 59.0.0.0/8] | APNIC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 060/8 [= 60.0.0.0/8] | APNIC | *(empty)* | 2003-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 061/8 [= 61.0.0.0/8] | APNIC | *(empty)* | 1997-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 062/8 [= 62.0.0.0/8] | RIPE NCC | *(empty)* | 1997-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 063/8 [= 63.0.0.0/8] | ARIN | *(empty)* | 1997-04 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 064/8 [= 64.0.0.0/8] | ARIN | *(empty)* | 1999-07 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 065/8 [= 65.0.0.0/8] | ARIN | *(empty)* | 2000-07 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 066/8 [= 66.0.0.0/8] | ARIN | *(empty)* | 2000-07 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 067/8 [= 67.0.0.0/8] | ARIN | *(empty)* | 2001-05 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 068/8 [= 68.0.0.0/8] | ARIN | *(empty)* | 2001-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 069/8 [= 69.0.0.0/8] | ARIN | *(empty)* | 2002-08 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 070/8 [= 70.0.0.0/8] | ARIN | *(empty)* | 2004-01 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 071/8 [= 71.0.0.0/8] | ARIN | *(empty)* | 2004-08 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 072/8 [= 72.0.0.0/8] | ARIN | *(empty)* | 2004-08 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 073/8 [= 73.0.0.0/8] | ARIN | *(empty)* | 2005-03 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 074/8 [= 74.0.0.0/8] | ARIN | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 075/8 [= 75.0.0.0/8] | ARIN | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 076/8 [= 76.0.0.0/8] | ARIN | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 077/8 [= 77.0.0.0/8] | RIPE NCC | *(empty)* | 2006-08 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 078/8 [= 78.0.0.0/8] | RIPE NCC | *(empty)* | 2006-08 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 079/8 [= 79.0.0.0/8] | RIPE NCC | *(empty)* | 2006-08 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 080/8 [= 80.0.0.0/8] | RIPE NCC | *(empty)* | 2001-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 081/8 [= 81.0.0.0/8] | RIPE NCC | *(empty)* | 2001-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 082/8 [= 82.0.0.0/8] | RIPE NCC | *(empty)* | 2002-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 083/8 [= 83.0.0.0/8] | RIPE NCC | *(empty)* | 2003-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 084/8 [= 84.0.0.0/8] | RIPE NCC | *(empty)* | 2003-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 085/8 [= 85.0.0.0/8] | RIPE NCC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 086/8 [= 86.0.0.0/8] | RIPE NCC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 087/8 [= 87.0.0.0/8] | RIPE NCC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 088/8 [= 88.0.0.0/8] | RIPE NCC | *(empty)* | 2004-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 089/8 [= 89.0.0.0/8] | RIPE NCC | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 090/8 [= 90.0.0.0/8] | RIPE NCC | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 091/8 [= 91.0.0.0/8] | RIPE NCC | *(empty)* | 2005-06 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 092/8 [= 92.0.0.0/8] | RIPE NCC | *(empty)* | 2007-03 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 093/8 [= 93.0.0.0/8] | RIPE NCC | *(empty)* | 2007-03 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 094/8 [= 94.0.0.0/8] | RIPE NCC | *(empty)* | 2007-07 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 095/8 [= 95.0.0.0/8] | RIPE NCC | *(empty)* | 2007-07 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 096/8 [= 96.0.0.0/8] | ARIN | *(empty)* | 2006-10 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 097/8 [= 97.0.0.0/8] | ARIN | *(empty)* | 2006-10 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 098/8 [= 98.0.0.0/8] | ARIN | *(empty)* | 2006-10 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 099/8 [= 99.0.0.0/8] | ARIN | *(empty)* | 2006-10 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 100/8 [= 100.0.0.0/8] | ARIN | RFC6598 | 2010-11 | Status=ALLOCATED; Note=[6]; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 101/8 [= 101.0.0.0/8] | APNIC | *(empty)* | 2010-08 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 102/8 [= 102.0.0.0/8] | AFRINIC | *(empty)* | 2011-02 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 103/8 [= 103.0.0.0/8] | APNIC | *(empty)* | 2011-02 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 104/8 [= 104.0.0.0/8] | ARIN | *(empty)* | 2011-02 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 105/8 [= 105.0.0.0/8] | AFRINIC | *(empty)* | 2010-11 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 106/8 [= 106.0.0.0/8] | APNIC | *(empty)* | 2011-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 107/8 [= 107.0.0.0/8] | ARIN | *(empty)* | 2010-02 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 108/8 [= 108.0.0.0/8] | ARIN | *(empty)* | 2008-12 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 109/8 [= 109.0.0.0/8] | RIPE NCC | *(empty)* | 2009-01 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 110/8 [= 110.0.0.0/8] | APNIC | *(empty)* | 2008-11 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 111/8 [= 111.0.0.0/8] | APNIC | *(empty)* | 2008-11 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 112/8 [= 112.0.0.0/8] | APNIC | *(empty)* | 2008-05 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 113/8 [= 113.0.0.0/8] | APNIC | *(empty)* | 2008-05 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 114/8 [= 114.0.0.0/8] | APNIC | *(empty)* | 2007-10 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 115/8 [= 115.0.0.0/8] | APNIC | *(empty)* | 2007-10 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 116/8 [= 116.0.0.0/8] | APNIC | *(empty)* | 2007-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 117/8 [= 117.0.0.0/8] | APNIC | *(empty)* | 2007-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 118/8 [= 118.0.0.0/8] | APNIC | *(empty)* | 2007-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 119/8 [= 119.0.0.0/8] | APNIC | *(empty)* | 2007-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 120/8 [= 120.0.0.0/8] | APNIC | *(empty)* | 2007-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 121/8 [= 121.0.0.0/8] | APNIC | *(empty)* | 2006-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 122/8 [= 122.0.0.0/8] | APNIC | *(empty)* | 2006-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 123/8 [= 123.0.0.0/8] | APNIC | *(empty)* | 2006-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 124/8 [= 124.0.0.0/8] | APNIC | *(empty)* | 2005-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 125/8 [= 125.0.0.0/8] | APNIC | *(empty)* | 2005-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 126/8 [= 126.0.0.0/8] | APNIC | *(empty)* | 2005-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 127/8 [= 127.0.0.0/8] | IANA - Loopback | RFC1122 §3.2.1.3 | 1981-09 | Status=RESERVED; Note=[7] |
| 128/8 [= 128.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 129/8 [= 129.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 130/8 [= 130.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 131/8 [= 131.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 132/8 [= 132.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 133/8 [= 133.0.0.0/8] | Administered by APNIC | *(empty)* | 1997-03 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 134/8 [= 134.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 135/8 [= 135.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 136/8 [= 136.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 137/8 [= 137.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 138/8 [= 138.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 139/8 [= 139.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 140/8 [= 140.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 141/8 [= 141.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 142/8 [= 142.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 143/8 [= 143.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 144/8 [= 144.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 145/8 [= 145.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 146/8 [= 146.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 147/8 [= 147.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 148/8 [= 148.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 149/8 [= 149.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 150/8 [= 150.0.0.0/8] | Administered by APNIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 151/8 [= 151.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 152/8 [= 152.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 153/8 [= 153.0.0.0/8] | Administered by APNIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 154/8 [= 154.0.0.0/8] | Administered by AFRINIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 155/8 [= 155.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 156/8 [= 156.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 157/8 [= 157.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 158/8 [= 158.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 159/8 [= 159.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 160/8 [= 160.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 161/8 [= 161.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 162/8 [= 162.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 163/8 [= 163.0.0.0/8] | Administered by APNIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 164/8 [= 164.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 165/8 [= 165.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 166/8 [= 166.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 167/8 [= 167.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 168/8 [= 168.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 169/8 [= 169.0.0.0/8] | Administered by ARIN | RFC3927 | 1993-05 | Status=LEGACY; Note=[8]; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 170/8 [= 170.0.0.0/8] | Administered by ARIN | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 171/8 [= 171.0.0.0/8] | Administered by APNIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 172/8 [= 172.0.0.0/8] | Administered by ARIN | RFC1918 | 1993-05 | Status=LEGACY; Note=[9]; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 173/8 [= 173.0.0.0/8] | ARIN | *(empty)* | 2008-02 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 174/8 [= 174.0.0.0/8] | ARIN | *(empty)* | 2008-02 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 175/8 [= 175.0.0.0/8] | APNIC | *(empty)* | 2009-08 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 176/8 [= 176.0.0.0/8] | RIPE NCC | *(empty)* | 2010-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 177/8 [= 177.0.0.0/8] | LACNIC | *(empty)* | 2010-06 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 178/8 [= 178.0.0.0/8] | RIPE NCC | *(empty)* | 2009-01 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 179/8 [= 179.0.0.0/8] | LACNIC | *(empty)* | 2011-02 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 180/8 [= 180.0.0.0/8] | APNIC | *(empty)* | 2009-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 181/8 [= 181.0.0.0/8] | LACNIC | *(empty)* | 2010-06 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 182/8 [= 182.0.0.0/8] | APNIC | *(empty)* | 2009-08 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 183/8 [= 183.0.0.0/8] | APNIC | *(empty)* | 2009-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 184/8 [= 184.0.0.0/8] | ARIN | *(empty)* | 2008-12 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 185/8 [= 185.0.0.0/8] | RIPE NCC | *(empty)* | 2011-02 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 186/8 [= 186.0.0.0/8] | LACNIC | *(empty)* | 2007-09 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 187/8 [= 187.0.0.0/8] | LACNIC | *(empty)* | 2007-09 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 188/8 [= 188.0.0.0/8] | Administered by RIPE NCC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 189/8 [= 189.0.0.0/8] | LACNIC | *(empty)* | 1995-06 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 190/8 [= 190.0.0.0/8] | LACNIC | *(empty)* | 1995-06 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 191/8 [= 191.0.0.0/8] | Administered by LACNIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 192/8 [= 192.0.0.0/8] | Administered by ARIN | RFC5737, RFC7526, RFC6751, RFC1918; RFC5736 | 1993-05 | Status=LEGACY; Note=[10][11]; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 193/8 [= 193.0.0.0/8] | RIPE NCC | *(empty)* | 1993-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 194/8 [= 194.0.0.0/8] | RIPE NCC | *(empty)* | 1993-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 195/8 [= 195.0.0.0/8] | RIPE NCC | *(empty)* | 1993-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 196/8 [= 196.0.0.0/8] | Administered by AFRINIC | *(empty)* | 1993-05 | Status=LEGACY; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 197/8 [= 197.0.0.0/8] | AFRINIC | *(empty)* | 2008-10 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 198/8 [= 198.0.0.0/8] | Administered by ARIN | RFC2544, RFC5737 | 1993-05 | Status=LEGACY; Note=[12]; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 199/8 [= 199.0.0.0/8] | ARIN | *(empty)* | 1993-05 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 200/8 [= 200.0.0.0/8] | LACNIC | *(empty)* | 2002-11 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 201/8 [= 201.0.0.0/8] | LACNIC | *(empty)* | 2003-04 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 202/8 [= 202.0.0.0/8] | APNIC | *(empty)* | 1993-05 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 203/8 [= 203.0.0.0/8] | APNIC | RFC5737 | 1993-05 | Status=ALLOCATED; Note=[13]; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 204/8 [= 204.0.0.0/8] | ARIN | *(empty)* | 1994-03 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 205/8 [= 205.0.0.0/8] | ARIN | *(empty)* | 1994-03 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 206/8 [= 206.0.0.0/8] | ARIN | *(empty)* | 1995-04 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 207/8 [= 207.0.0.0/8] | ARIN | *(empty)* | 1995-11 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 208/8 [= 208.0.0.0/8] | ARIN | *(empty)* | 1996-04 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 209/8 [= 209.0.0.0/8] | ARIN | *(empty)* | 1996-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 210/8 [= 210.0.0.0/8] | APNIC | *(empty)* | 1996-06 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 211/8 [= 211.0.0.0/8] | APNIC | *(empty)* | 1996-06 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 212/8 [= 212.0.0.0/8] | RIPE NCC | *(empty)* | 1997-10 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 213/8 [= 213.0.0.0/8] | RIPE NCC | *(empty)* | 1993-10 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 214/8 [= 214.0.0.0/8] | US-DOD | *(empty)* | 1998-03 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 215/8 [= 215.0.0.0/8] | US-DOD | *(empty)* | 1998-03 | Status=LEGACY; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 216/8 [= 216.0.0.0/8] | ARIN | *(empty)* | 1998-04 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 217/8 [= 217.0.0.0/8] | RIPE NCC | *(empty)* | 2000-06 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 218/8 [= 218.0.0.0/8] | APNIC | *(empty)* | 2000-12 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 219/8 [= 219.0.0.0/8] | APNIC | *(empty)* | 2001-09 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 220/8 [= 220.0.0.0/8] | APNIC | *(empty)* | 2001-12 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 221/8 [= 221.0.0.0/8] | APNIC | *(empty)* | 2002-07 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 222/8 [= 222.0.0.0/8] | APNIC | *(empty)* | 2003-02 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 223/8 [= 223.0.0.0/8] | APNIC | *(empty)* | 2010-04 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 224/8 [= 224.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 225/8 [= 225.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 226/8 [= 226.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 227/8 [= 227.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 228/8 [= 228.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 229/8 [= 229.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 230/8 [= 230.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 231/8 [= 231.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 232/8 [= 232.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 233/8 [= 233.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 234/8 [= 234.0.0.0/8] | Multicast | RFC5771; RFC6034 | 1981-09 | Status=RESERVED; Note=[14][15] |
| 235/8 [= 235.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 236/8 [= 236.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 237/8 [= 237.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 238/8 [= 238.0.0.0/8] | Multicast | RFC5771 | 1981-09 | Status=RESERVED; Note=[14] |
| 239/8 [= 239.0.0.0/8] | Multicast | RFC5771; RFC2365 | 1981-09 | Status=RESERVED; Note=[14][16] |
| 240/8 [= 240.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 241/8 [= 241.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 242/8 [= 242.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 243/8 [= 243.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 244/8 [= 244.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 245/8 [= 245.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 246/8 [= 246.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 247/8 [= 247.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 248/8 [= 248.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 249/8 [= 249.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 250/8 [= 250.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 251/8 [= 251.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 252/8 [= 252.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 253/8 [= 253.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 254/8 [= 254.0.0.0/8] | Future use | RFC1112 | 1981-09 | Status=RESERVED; Note=[17] |
| 255/8 [= 255.0.0.0/8] | Future use | RFC1112; RFC919, RFC922 | 1981-09 | Status=RESERVED; Note=[17][18] |

### IPv4 Address Space footnotes (verbatim from the XHTML)

- **[1]** Indicates the status of address blocks as follows: RESERVED: designated by the IETF for specific non-global-unicast purposes as noted. LEGACY: allocated by the central Internet Registry (IR) prior to the Regional Internet Registries (RIRs). This address space is now administered by individual RIRs as noted, including maintenance of WHOIS Directory and reverse DNS records. Assignments from these blocks are distributed globally on a regional basis. ALLOCATED: delegated entirely to specific RIR as indicated. UNALLOCATED: not yet allocated or reserved.
- **[2]** 0.0.0.0/8 reserved for self-identification [RFC791], section 3.2. Reserved by protocol. For authoritative registration, see [IPv4 Special-Purpose Address Space].
- **[3]** 0.0.0.0/32 reserved for self-identification [RFC1122], section 3.2.1.3. Reserved by protocol. For authoritative registration, see [IPv4 Special-Purpose Address Space].
- **[4]** Reserved for Private-Use Networks [RFC1918]. Complete registration details for 10.0.0.0/8 are found in [IPv4 Special-Purpose Address Space].
- **[5]** This was reserved for Public Data Networks [RFC1356]. See [Public Data Network Numbers]. It was recovered in February 2008 and was subsequently allocated to APNIC in April 2010.
- **[6]** 100.64.0.0/10 reserved for Shared Address Space [RFC6598]. Complete registration details for 100.64.0.0/10 are found in [IPv4 Special-Purpose Address Space].
- **[7]** 127.0.0.0/8 reserved for Loopback [RFC1122], section 3.2.1.3. Reserved by protocol. For authoritative registration, see [IPv4 Special-Purpose Address Space].
- **[8]** 169.254.0.0/16 reserved for Link Local [RFC3927]. Reserved by protocol. For authoritative registration, see [IPv4 Special-Purpose Address Space].
- **[9]** 172.16.0.0/12 reserved for Private-Use Networks [RFC1918]. Complete registration details are found in [IPv4 Special-Purpose Address Space].
- **[10]** 192.0.2.0/24 reserved for TEST-NET-1 [RFC5737]. 192.88.99.0/24 reserved for 6to4 Relay Anycast [RFC7526]. 192.88.99.2/32 reserved for 6a44 Relay Anycast [RFC6751] (possibly collocated with 6to4 Relay at 192.88.99.1/32 - see [RFC7526]). 192.168.0.0/16 reserved for Private-Use Networks [RFC1918]. Complete registration details are found in [IPv4 Special-Purpose Address Space].
- **[11]** 192.0.0.0/24 reserved for IANA IPv4 Special Purpose Address Registry [RFC5736]. Complete registration details for 192.0.0.0/24 are found in [IPv4 Special-Purpose Address Space].
- **[12]** 198.18.0.0/15 reserved for Network Interconnect Device Benchmark Testing [RFC2544]. Complete registration details for 198.18.0.0/15 are found in [IPv4 Special-Purpose Address Space]. 198.51.100.0/24 reserved for TEST-NET-2 [RFC5737]. Complete registration details for 198.51.100.0/24 are found in [IPv4 Special-Purpose Address Space].
- **[13]** 203.0.113.0/24 reserved for TEST-NET-3 [RFC5737]. Complete registration details for 203.0.113.0/24 are found in [IPv4 Special-Purpose Address Space].
- **[14]** Multicast (formerly "Class D") [RFC5771] registered in [IPv4 Multicast Address Space]
- **[15]** Unicast-Prefix-Based IPv4 Multicast Addresses [RFC6034]
- **[16]** Administratively Scoped IP Multicast [RFC2365]
- **[17]** Reserved for future use (formerly "Class E") [RFC1112]. Reserved by protocol. For authoritative registration, see [IPv4 Special-Purpose Address Space].
- **[18]** 255.255.255.255 is reserved for "limited broadcast" destination address [RFC919] and [RFC922]. Complete registration details for 255.255.255.255/32 are found in [IPv4 Special-Purpose Address Space].

## 2. IANA IPv6 Address Space Registry

URL: <https://www.iana.org/assignments/ipv6-address-space/ipv6-address-space.xhtml>
CSV: <https://www.iana.org/assignments/ipv6-address-space/ipv6-address-space-1.csv>

**20 records**, verified row-by-row against both the CSV and the rendered XHTML table (they agree
exactly, including prefix spelling). 16 of the 20 are `Reserved by IETF`; the other 4 are
`Global Unicast` (2000::/3), `Unique Local Unicast` (fc00::/7), `Link-Scoped Unicast` (fe80::/10)
and `Multicast` (ff00::/8).

**The CSV filename is `ipv6-address-space-1.csv`, not `ipv6-address-space.csv`.** The latter 404s.

**The first two prefixes are spelled `::/8` and `100::/8`, not `0000::/8` and `0100::/8`.** IANA
uses RFC 5952-ish zero compression in this registry. Any inventory that hard-codes `0000::/8` will
not string-match the registry. The registry does *not* contain a `0100::/8` row, a `0200::/7` row,
or a `0400::/6` row under those spellings; they are `100::/8`, `200::/7`, `400::/6`.

This registry is a **complete partition of the IPv6 address space** — the 20 prefixes tile
::/0 exactly, with no gaps and no overlaps. That is the one registry here that can be used as a
total function.

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| ::/8 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | This range has been partially allocated. See [IPv6 Special-Purpose Address Space] for details. ::/96, formerly defined as the "IPv4-compatible IPv6 address" prefix, was deprecated by [RFC4291]. |
| 100::/8 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | This range has been partially allocated. See [IPv6 Special-Purpose Address Space] for details. |
| 200::/7 | Reserved by IETF | [RFC4048] | (no date column in this registry) | Deprecated as of December 2004 [RFC4048]. Formerly an OSI NSAP-mapped prefix set [RFC4548]. |
| 400::/6 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| 800::/5 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| 1000::/4 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| 2000::/3 | Global Unicast | [RFC3513][RFC4291] | (no date column in this registry) | The IPv6 Unicast space encompasses the entire IPv6 address range<br>with the exception of ff00::/8, per [RFC4291]. IANA unicast address<br>assignments are currently limited to the IPv6 unicast address<br>range of 2000::/3. IANA assignments from this block are registered<br>in [IPv6 Global Unicast Address Space]. |
| 4000::/3 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | This range has been partially allocated. See [IPv6 Special-Purpose Address Space] for details. 5f00::/8 (with 3ffe::/16, as noted at [IPv6 Global Unicast Address Space]) was used for the 6bone, but returned [RFC5156]. |
| 6000::/3 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| 8000::/3 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| a000::/3 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| c000::/3 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| e000::/4 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| f000::/5 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| f800::/6 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| fc00::/7 | Unique Local Unicast | [RFC4193] | (no date column in this registry) | See [IPv6 Special-Purpose Address Space] for details. |
| fe00::/9 | Reserved by IETF | [RFC3513][RFC4291] | (no date column in this registry) | *(empty)* |
| fe80::/10 | Link-Scoped Unicast | [RFC3513][RFC4291] | (no date column in this registry) | See [IPv6 Special-Purpose Address Space] for details. |
| fec0::/10 | Reserved by IETF | [RFC3879] | (no date column in this registry) | Deprecated by [RFC3879] in September 2004. Formerly a Site-Local scoped address prefix. |
| ff00::/8 | Multicast | [RFC3513][RFC4291] | (no date column in this registry) | See [IPv6 Multicast Address Space] for details. |

IANA supplies **no date column at all** in this registry. The `date` column above is filled with
an explicit placeholder rather than a guessed value. Deprecation years appear only as free text
inside the Notes column (`200::/7` "Deprecated as of December 2004", `fec0::/10` "Deprecated by
[RFC3879] in September 2004").

## 3. IANA IPv4 Special-Purpose Address Registry

URL: <https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry.xhtml>
CSV: <https://www.iana.org/assignments/iana-ipv4-special-registry/iana-ipv4-special-registry-1.csv>

**25 records.** Governing document: RFC 6890 (which obsoletes RFC 5735 and RFC 5736).

Full 10-column reproduction. The five policy columns are verbatim, including footnote markers and
including the empty cells on the terminated `192.88.99.0/24` row (those cells are the **empty
string** in both CSV and XHTML — they are not `N/A`, not `False`).

| Address Block | Name | RFC | Allocation Date | Termination Date | Source | Destination | Forwardable | Globally Reachable | Reserved-by-Protocol |
|---|---|---|---|---|---|---|---|---|---|
| 0.0.0.0/8 | "This network" | [RFC791], Section 3.2 | 1981-09 | N/A | True | False | False | False | True |
| 0.0.0.0/32 | "This host on this network" | [RFC1122], Section 3.2.1.3 | 1981-09 | N/A | True | False | False | False | True |
| 10.0.0.0/8 | Private-Use | [RFC1918] | 1996-02 | N/A | True | True | True | False | False |
| 100.64.0.0/10 | Shared Address Space | [RFC6598] | 2012-04 | N/A | True | True | True | False | False |
| 127.0.0.0/8 | Loopback | [RFC1122], Section 3.2.1.3 | 1981-09 | N/A | False [1] | False [1] | False [1] | False [1] | True |
| 169.254.0.0/16 | Link Local | [RFC3927] | 2005-05 | N/A | True | True | False | False | True |
| 172.16.0.0/12 | Private-Use | [RFC1918] | 1996-02 | N/A | True | True | True | False | False |
| 192.0.0.0/24 [2] | IETF Protocol Assignments | [RFC6890], Section 2.1 | 2010-01 | N/A | False | False | False | False | False |
| 192.0.0.0/29 | IPv4 Service Continuity Prefix | [RFC7335] | 2011-06 | N/A | True | True | True | False | False |
| 192.0.0.8/32 | IPv4 dummy address | [RFC7600] | 2015-03 | N/A | True | False | False | False | False |
| 192.0.0.9/32 | Port Control Protocol Anycast | [RFC7723] | 2015-10 | N/A | True | True | True | True | False |
| 192.0.0.10/32 | Traversal Using Relays around NAT Anycast | [RFC8155] | 2017-02 | N/A | True | True | True | True | False |
| 192.0.0.170/32, 192.0.0.171/32 | NAT64/DNS64 Discovery | [RFC8880][RFC7050], Section 2.2 | 2013-02 | N/A | False | False | False | False | True |
| 192.0.2.0/24 | Documentation (TEST-NET-1) | [RFC5737] | 2010-01 | N/A | False | False | False | False | False |
| 192.31.196.0/24 | AS112-v4 | [RFC7535] | 2014-12 | N/A | True | True | True | True | False |
| 192.52.193.0/24 | AMT | [RFC7450] | 2014-12 | N/A | True | True | True | True | False |
| 192.88.99.0/24 | Deprecated (6to4 Relay Anycast) | [RFC7526] | 2001-06 | 2015-03 | *(empty)* | *(empty)* | *(empty)* | *(empty)* | *(empty)* |
| 192.88.99.2/32 | 6a44-relay anycast address | [RFC6751] | 2012-10 | N/A | True | True | True | False | False |
| 192.168.0.0/16 | Private-Use | [RFC1918] | 1996-02 | N/A | True | True | True | False | False |
| 192.175.48.0/24 | Direct Delegation AS112 Service | [RFC7534] | 1996-01 | N/A | True | True | True | True | False |
| 198.18.0.0/15 | Benchmarking | [RFC2544] | 1999-03 | N/A | True | True | True | False | False |
| 198.51.100.0/24 | Documentation (TEST-NET-2) | [RFC5737] | 2010-01 | N/A | False | False | False | False | False |
| 203.0.113.0/24 | Documentation (TEST-NET-3) | [RFC5737] | 2010-01 | N/A | False | False | False | False | False |
| 240.0.0.0/4 | Reserved | [RFC1112], Section 4 | 1989-08 | N/A | False | False | False | False | True |
| 255.255.255.255/32 | Limited Broadcast | [RFC8190]<br>[RFC919], Section 7 | 1984-10 | N/A | False | True | False | False | True |

Requested `prefix | name | RFC(s) | date | notes` view of the same 25 records:

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 0.0.0.0/8 | "This network" | [RFC791], Section 3.2 | 1981-09 | Source=True; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 0.0.0.0/32 | "This host on this network" | [RFC1122], Section 3.2.1.3 | 1981-09 | Source=True; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 10.0.0.0/8 | Private-Use | [RFC1918] | 1996-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 100.64.0.0/10 | Shared Address Space | [RFC6598] | 2012-04 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 127.0.0.0/8 | Loopback | [RFC1122], Section 3.2.1.3 | 1981-09 | Source=False [1]; Destination=False [1]; Forwardable=False [1]; Globally Reachable=False [1]; Reserved-by-Protocol=True |
| 169.254.0.0/16 | Link Local | [RFC3927] | 2005-05 | Source=True; Destination=True; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 172.16.0.0/12 | Private-Use | [RFC1918] | 1996-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.0.0.0/24 [2] | IETF Protocol Assignments | [RFC6890], Section 2.1 | 2010-01 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.0.0.0/29 | IPv4 Service Continuity Prefix | [RFC7335] | 2011-06 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.0.0.8/32 | IPv4 dummy address | [RFC7600] | 2015-03 | Source=True; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.0.0.9/32 | Port Control Protocol Anycast | [RFC7723] | 2015-10 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 192.0.0.10/32 | Traversal Using Relays around NAT Anycast | [RFC8155] | 2017-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 192.0.0.170/32, 192.0.0.171/32 | NAT64/DNS64 Discovery | [RFC8880][RFC7050], Section 2.2 | 2013-02 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 192.0.2.0/24 | Documentation (TEST-NET-1) | [RFC5737] | 2010-01 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.31.196.0/24 | AS112-v4 | [RFC7535] | 2014-12 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 192.52.193.0/24 | AMT | [RFC7450] | 2014-12 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 192.88.99.0/24 | Deprecated (6to4 Relay Anycast) | [RFC7526] | 2001-06 | TERMINATED 2015-03; Source=(empty); Destination=(empty); Forwardable=(empty); Globally Reachable=(empty); Reserved-by-Protocol=(empty) |
| 192.88.99.2/32 | 6a44-relay anycast address | [RFC6751] | 2012-10 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.168.0.0/16 | Private-Use | [RFC1918] | 1996-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 192.175.48.0/24 | Direct Delegation AS112 Service | [RFC7534] | 1996-01 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 198.18.0.0/15 | Benchmarking | [RFC2544] | 1999-03 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 198.51.100.0/24 | Documentation (TEST-NET-2) | [RFC5737] | 2010-01 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 203.0.113.0/24 | Documentation (TEST-NET-3) | [RFC5737] | 2010-01 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 240.0.0.0/4 | Reserved | [RFC1112], Section 4 | 1989-08 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 255.255.255.255/32 | Limited Broadcast | [RFC8190]<br>[RFC919], Section 7 | 1984-10 | Source=False; Destination=True; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |

### IPv4 Special-Purpose footnotes (verbatim)

- **[1]** Several protocols have been granted exceptions to this rule. For examples, see [RFC8029] and [RFC5884].
- **[2]** Not useable unless by virtue of a more specific reservation.

`[1]` is attached to all four of `127.0.0.0/8`'s non-`Reserved-by-Protocol` policy cells
(`False [1]` x4). `[2]` is attached to the **Address Block** cell of `192.0.0.0/24`, i.e. the
literal CSV value of that field is `192.0.0.0/24 [2]`, which is not a parseable CIDR string.

## 4. IANA IPv6 Special-Purpose Address Registry

URL: <https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry.xhtml>
CSV: <https://www.iana.org/assignments/iana-ipv6-special-registry/iana-ipv6-special-registry-1.csv>

**25 records.** Governing document: RFC 6890.

| Address Block | Name | RFC | Allocation Date | Termination Date | Source | Destination | Forwardable | Globally Reachable | Reserved-by-Protocol |
|---|---|---|---|---|---|---|---|---|---|
| ::1/128 | Loopback Address | [RFC4291] | 2006-02 | N/A | False | False | False | False | True |
| ::/128 | Unspecified Address | [RFC4291] | 2006-02 | N/A | True | False | False | False | True |
| ::ffff:0:0/96 | IPv4-mapped Address | [RFC4291] | 2006-02 | N/A | False | False | False | False | True |
| 64:ff9b::/96 | IPv4-IPv6 Translat. | [RFC6052] | 2010-10 | N/A | True | True | True | True | False |
| 64:ff9b:1::/48 | IPv4-IPv6 Translat. | [RFC8215] | 2017-06 | N/A | True | True | True | False | False |
| 100::/64 | Discard-Only Address Block | [RFC6666] | 2012-06 | N/A | True | True | True | False | False |
| 100:0:0:1::/64 | Dummy IPv6 Prefix | [RFC9780] | 2025-04 | N/A | True | False | False | False | False |
| 2001::/23 | IETF Protocol Assignments | [RFC2928] | 2000-09 | N/A | False [1] | False [1] | False [1] | False [1] | False |
| 2001::/32 | TEREDO | [RFC4380]<br>[RFC8190] | 2006-01 | N/A | True | True | True | N/A [2] | False |
| 2001:1::1/128 | Port Control Protocol Anycast | [RFC7723] | 2015-10 | N/A | True | True | True | True | False |
| 2001:1::2/128 | Traversal Using Relays around NAT Anycast | [RFC8155] | 2017-02 | N/A | True | True | True | True | False |
| 2001:1::3/128 | DNS-SD Service Registration Protocol Anycast | [RFC9665] | 2024-04 | N/A | True | True | True | True | False |
| 2001:2::/48 | Benchmarking | [RFC5180][RFC Errata 1752] | 2008-04 | N/A | True | True | True | False | False |
| 2001:3::/32 | AMT | [RFC7450] | 2014-12 | N/A | True | True | True | True | False |
| 2001:4:112::/48 | AS112-v6 | [RFC7535] | 2014-12 | N/A | True | True | True | True | False |
| 2001:10::/28 | Deprecated (previously ORCHID) | [RFC4843] | 2007-03 | 2014-03 | *(empty)* | *(empty)* | *(empty)* | *(empty)* | *(empty)* |
| 2001:20::/28 | ORCHIDv2 | [RFC7343] | 2014-07 | N/A | True | True | True | True | False |
| 2001:30::/28 | Drone Remote ID Protocol Entity Tags (DETs) Prefix | [RFC9374] | 2022-12 | N/A | True | True | True | True | False |
| 2001:db8::/32 | Documentation | [RFC3849] | 2004-07 | N/A | False | False | False | False | False |
| 2002::/16 [3] | 6to4 | [RFC3056] | 2001-02 | N/A | True | True | True | N/A [3] | False |
| 2620:4f:8000::/48 | Direct Delegation AS112 Service | [RFC7534] | 2011-05 | N/A | True | True | True | True | False |
| 3fff::/20 | Documentation | [RFC9637] | 2024-07 | N/A | False | False | False | False | False |
| 5f00::/16 | Segment Routing (SRv6) SIDs | [RFC9602] | 2024-04 | N/A | True | True | True | False | False |
| fc00::/7 | Unique-Local | [RFC4193]<br>[RFC8190] | 2005-10 | N/A | True | True | True | False [4] | False |
| fe80::/10 | Link-Local Unicast | [RFC4291] | 2006-02 | N/A | True | True | False | False | True |

Requested `prefix | name | RFC(s) | date | notes` view of the same 25 records:

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| ::1/128 | Loopback Address | [RFC4291] | 2006-02 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| ::/128 | Unspecified Address | [RFC4291] | 2006-02 | Source=True; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| ::ffff:0:0/96 | IPv4-mapped Address | [RFC4291] | 2006-02 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |
| 64:ff9b::/96 | IPv4-IPv6 Translat. | [RFC6052] | 2010-10 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 64:ff9b:1::/48 | IPv4-IPv6 Translat. | [RFC8215] | 2017-06 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 100::/64 | Discard-Only Address Block | [RFC6666] | 2012-06 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 100:0:0:1::/64 | Dummy IPv6 Prefix | [RFC9780] | 2025-04 | Source=True; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 2001::/23 | IETF Protocol Assignments | [RFC2928] | 2000-09 | Source=False [1]; Destination=False [1]; Forwardable=False [1]; Globally Reachable=False [1]; Reserved-by-Protocol=False |
| 2001::/32 | TEREDO | [RFC4380]<br>[RFC8190] | 2006-01 | Source=True; Destination=True; Forwardable=True; Globally Reachable=N/A [2]; Reserved-by-Protocol=False |
| 2001:1::1/128 | Port Control Protocol Anycast | [RFC7723] | 2015-10 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:1::2/128 | Traversal Using Relays around NAT Anycast | [RFC8155] | 2017-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:1::3/128 | DNS-SD Service Registration Protocol Anycast | [RFC9665] | 2024-04 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:2::/48 | Benchmarking | [RFC5180][RFC Errata 1752] | 2008-04 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| 2001:3::/32 | AMT | [RFC7450] | 2014-12 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:4:112::/48 | AS112-v6 | [RFC7535] | 2014-12 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:10::/28 | Deprecated (previously ORCHID) | [RFC4843] | 2007-03 | TERMINATED 2014-03; Source=(empty); Destination=(empty); Forwardable=(empty); Globally Reachable=(empty); Reserved-by-Protocol=(empty) |
| 2001:20::/28 | ORCHIDv2 | [RFC7343] | 2014-07 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:30::/28 | Drone Remote ID Protocol Entity Tags (DETs) Prefix | [RFC9374] | 2022-12 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 2001:db8::/32 | Documentation | [RFC3849] | 2004-07 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 2002::/16 [3] | 6to4 | [RFC3056] | 2001-02 | Source=True; Destination=True; Forwardable=True; Globally Reachable=N/A [3]; Reserved-by-Protocol=False |
| 2620:4f:8000::/48 | Direct Delegation AS112 Service | [RFC7534] | 2011-05 | Source=True; Destination=True; Forwardable=True; Globally Reachable=True; Reserved-by-Protocol=False |
| 3fff::/20 | Documentation | [RFC9637] | 2024-07 | Source=False; Destination=False; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=False |
| 5f00::/16 | Segment Routing (SRv6) SIDs | [RFC9602] | 2024-04 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False; Reserved-by-Protocol=False |
| fc00::/7 | Unique-Local | [RFC4193]<br>[RFC8190] | 2005-10 | Source=True; Destination=True; Forwardable=True; Globally Reachable=False [4]; Reserved-by-Protocol=False |
| fe80::/10 | Link-Local Unicast | [RFC4291] | 2006-02 | Source=True; Destination=True; Forwardable=False; Globally Reachable=False; Reserved-by-Protocol=True |

### IPv6 Special-Purpose footnotes (verbatim)

- **[1]** Unless allowed by a more specific allocation.
- **[2]** See Section 5 of [RFC4380] for details.
- **[3]** See [RFC3056] for details.
- **[4]** See [RFC4193] for more details on the routability of Unique-Local addresses. The Unique-Local prefix is drawn from the IPv6 Global Unicast Address range, but is specified as not globally routed.

Marker placement:

- `[1]` on all four non-`Reserved-by-Protocol` policy cells of `2001::/23` (`False [1]`).
- `[2]` on the **Globally Reachable** cell of `2001::/32` (TEREDO), whose value is `N/A [2]` —
  a third truth value, not a boolean.
- `[3]` appears **twice** for one record: in the **Address Block** cell of `2002::/16`
  (literal value `2002::/16 [3]`) *and* in its **Globally Reachable** cell (`N/A [3]`).
- `[4]` on the **Globally Reachable** cell of `fc00::/7` (`False [4]`).

## 5. IPv4 Multicast Address Space Registry

URL: <https://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml>

Governing document: RFC 5771 (BCP 51). This is **not one table**. It is a container page holding
**15 independent sub-registries**, each with its own CSV export, its own `Reference`, its own
registration procedure, and — in one case — its own column headings. There is no top-level
"IPv4 multicast blocks" table anywhere on the page: the block structure exists **only in the
`<h2>` headings**, which mix CIDR, dotted ranges, and legacy `224.0.0/24`-style prefixes in the
same string.

### 5a. Block structure, reconstructed from the `<h2>` headings (verbatim heading text)

| prefix / range (as IANA writes it) | name | RFC(s) | date | notes |
|---|---|---|---|---|
| `224.0.0.0 - 224.0.0.255  (224.0.0/24)` | Local Network Control Block | [RFC5771] | — | CSV `multicast-addresses-1.csv`, 72 records |
| `224.0.1.0 - 224.0.1.255  (224.0.1/24)` | Internetwork Control Block | [RFC5771] | — | CSV `multicast-addresses-2.csv`, 192 records |
| `224.0.2.0 - 224.0.255.255` | AD-HOC Block I | [RFC5771] | — | CSV `multicast-addresses-3.csv`, 244 records; **not CIDR-aligned** |
| `224.1.0.0-224.1.255.255 (224.1/16)` | RESERVED | [RFC5771] | — | CSV `multicast-addresses-4.csv`, 6 records |
| `224.2.0.0-224.2.255.255 (224.2/16)` | SDP/SAP Block | [RFC5771] | — | CSV `multicast-addresses-5.csv`, 4 records |
| `224.3.0.0-224.4.255.255 (224.3/16, 224.4/16)` | AD-HOC Block II | [RFC5771] | — | CSV `multicast-addresses-6.csv`, 28 records; **two prefixes packed into one heading** |
| `224.5.0.0-224.251.255.255 (251 /16s)` | RESERVED | [RFC5771] | — | CSV `multicast-addresses-7.csv`, 1 record. **The "251 /16s" count is wrong: 224.5–224.251 is 247 /16s.** |
| `224.252.0.0-224.255.255.255 (224.252/14))` | DIS Transient Groups | [RFC2365] | — | CSV `multicast-addresses-8.csv`, 1 record. Heading has an **unbalanced closing parenthesis** and no opening one before the range. |
| `225.0.0.0-231.255.255.255 (7 /8s)` | RESERVED | [RFC5771] | — | CSV `multicast-addresses-9.csv`, 1 record |
| `232.0.0.0-232.255.255.255 (232/8)` | Source-Specific Multicast Block | [RFC5771] (contents cite [RFC4607]) | — | CSV `multicast-addresses-10.csv`, 3 records. **Its first column is headed `Relative`, not `Address(es)` — an IANA typo present in both CSV and HTML.** |
| (no range in heading) | GLOP Block | [RFC3180] | — | CSV `glop.csv`, 1 record covering `233.0.0.0-233.251.255.255` |
| `233.252.0.0-233.255.255.255 (233.252/14)` | AD-HOC Block III | [RFC5771] | — | CSV `multicast-addresses-11.csv`, 8 records |
| (no range in heading) | Unicast-Prefix-based IPv4 Multicast Addresses | [RFC6034] | 2010-08-11 | CSV `unicast-prefix-based.csv`, 1 record covering `234.0.0.0-234.255.255.255` |
| (no range in heading) | Scoped Multicast Ranges | [RFC5771] | — | CSV `multicast-addresses-12.csv`, 2 records covering `235.0.0.0-239.255.255.255` |
| (no range in heading) | Relative Addresses used with Scoped Multicast Addresses | [RFC5771] | — | CSV `multicast-addresses-13.csv`, 15 records. **These are 8-bit offsets (`0`–`255`), not addresses.** |

Registry-wide note attached to the Local Network Control Block:
> (*) It is only appropriate to use these values in explicitly-configured experiments; they
> MUST NOT be shipped as defaults in implementations. See [RFC3692] for details.

Every sub-registry below shares the column set
`Address(es), Description, References, Change Controller, Date Registered, Last Reviewed`
(except `multicast-addresses-10.csv`, see above). Nothing in this registry is expressed in CIDR;
everything is a single dotted address or a `start-end` dotted range.

### 5b. Local Network Control Block (224.0.0.0 - 224.0.0.255  (224.0.0/24))

CSV: `multicast-addresses-1.csv` — sub-registry Reference: `[RFC5771]` — 72 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.0.0.0 | Base Address (Reserved) | [RFC1112][Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.0.1 | All Systems on this Subnet | [RFC1112][Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.0.2 | All Routers on this Subnet | [Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.0.3 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.4 | DVMRP    Routers | [RFC1075][Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.0.5 | OSPFIGP  OSPFIGP All Routers | [RFC2328][OSPF_WG_Chairs] | *(empty)* | *(empty)* |
| 224.0.0.6 | OSPFIGP  OSPFIGP Designated Routers | [RFC2328][OSPF_WG_Chairs] | *(empty)* | *(empty)* |
| 224.0.0.7 | ST Routers | [RFC1190][Karen_Seo] | *(empty)* | *(empty)* |
| 224.0.0.8 | ST Hosts | [RFC1190][Karen_Seo] | *(empty)* | *(empty)* |
| 224.0.0.9 | RIP2 Routers | [RFC1723][Gary_S_Malkin] | *(empty)* | *(empty)* |
| 224.0.0.10 | EIGRP Routers | [RFC7868] | 1996-03-01 | *(empty)* |
| 224.0.0.11 | Mobile-Agents | [[Bill Simpson]] | *(empty)* | *(empty)* |
| 224.0.0.12 | DHCP Server / Relay Agent | [[Unknown]] | *(empty)* | *(empty)* |
| 224.0.0.13 | All PIM Routers | [Dino_Farinacci] | 1996-03-01 | *(empty)* |
| 224.0.0.14 | RSVP-ENCAPSULATION | [Bob_Braden] | 1996-04-01 | *(empty)* |
| 224.0.0.15 | all-cbt-routers | [Tony_Ballardie][RFC2189] | 1997-02-01 | *(empty)* |
| 224.0.0.16 | designated-sbm | [Fred_Baker] | 1997-06-01 | *(empty)* |
| 224.0.0.17 | all-sbms | [Fred_Baker] | 1997-06-01 | *(empty)* |
| 224.0.0.18 | VRRP | [RFC3768][RFC9568] | *(empty)* | *(empty)* |
| 224.0.0.19 | IPAllL1ISs | [Tony_Przygienda] | 1999-10-01 | *(empty)* |
| 224.0.0.20 | IPAllL2ISs | [Tony_Przygienda] | 1999-10-01 | *(empty)* |
| 224.0.0.21 | IPAllIntermediate Systems | [Tony_Przygienda] | 1999-10-01 | *(empty)* |
| 224.0.0.22 | IGMP | [Steve_Deering] | 1999-10-01 | *(empty)* |
| 224.0.0.23 | GLOBECAST-ID | [Piers_Scannell] | 2000-03-01 | *(empty)* |
| 224.0.0.24 | OSPFIGP-TE | [RFC4973] | *(empty)* | *(empty)* |
| 224.0.0.25 | router-to-switch | [Ishan_Wu] | 2000-03-01 | *(empty)* |
| 224.0.0.26 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.27 | Al MPP Hello | [Brian_Martinicky] | 2000-03-01 | *(empty)* |
| 224.0.0.28 | ETC Control | [Steve_Polishinski] | 2000-03-01 | *(empty)* |
| 224.0.0.29 | GE-FANUC | [Ian_Wacey] | 2000-05-01 | *(empty)* |
| 224.0.0.30 | indigo-vhdp | [Colin_Caughie] | 2000-05-01 | *(empty)* |
| 224.0.0.31 | shinbroadband | [Sakon_Kittivatcharapong] | 2000-05-01 | *(empty)* |
| 224.0.0.32 | digistar | [Brian_Kerkan] | 2000-05-01 | *(empty)* |
| 224.0.0.33 | ff-system-management | [Dave_Glanzer] | 2003-03-01 | *(empty)* |
| 224.0.0.34 | pt2-discover | [Ralph_Kammerlander] | 2000-06-01 | *(empty)* |
| 224.0.0.35 | DXCLUSTER | [Dirk_Koopman] | 2000-07-01 | *(empty)* |
| 224.0.0.36 | DTCP Announcement | [Patrick_Cipiere] | 2001-01-01 | *(empty)* |
| 224.0.0.37-224.0.0.68 | zeroconfaddr   (renew 12/02) | [Erik_Guttman] | 2001-12-01 | *(empty)* |
| 224.0.0.69 | all-AODV-RPL-nodes | [RFC9854] | 2025-03-10 | *(empty)* |
| 224.0.0.70-224.0.0.100 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.101 | cisco-nhap | [Mark_Bakke] | 2001-12-01 | *(empty)* |
| 224.0.0.102 | HSRP | [Ian_Wilson] | 2001-12-01 | *(empty)* |
| 224.0.0.103 | MDAP | [Johan_Deleu] | 2002-02-01 | *(empty)* |
| 224.0.0.104 | Nokia MC CH | [Morteza_Kalhour] | 2002-10-01 | *(empty)* |
| 224.0.0.105 | ff-lr-address | [Dave_Glanzer] | 2003-03-01 | *(empty)* |
| 224.0.0.106 | All-Snoopers | [RFC4286] | *(empty)* | *(empty)* |
| 224.0.0.107 | PTP-pdelay | [NIST: IEEE Std 1588][Kang_Lee] | 2007-02-02 | *(empty)* |
| 224.0.0.108 | Saratoga | [Lloyd_Wood] | 2007-08-30 | Last Reviewed=2011-03-17 |
| 224.0.0.109 | LL-MANET-Routers | [RFC5498] | *(empty)* | Last Reviewed=2011-02-23 |
| 224.0.0.110 | IGRS | [Xiaoyu_Zhou] | 2009-01-20 | *(empty)* |
| 224.0.0.111 | Babel | [RFC8966] | *(empty)* | *(empty)* |
| 224.0.0.112 | MMA Device Discovery | [Tom_White] | 2011-11-02 | *(empty)* |
| 224.0.0.113 | AllJoyn | [Craig_Dowell] | 2011-11-18 | *(empty)* |
| 224.0.0.114 | Inter RFID Reader Protocol | [Wayne_Wenyu_Liu] | 2012-06-12 | *(empty)* |
| 224.0.0.115 | JSDP | [J._Ryan_Stinnett] | 2014-07-01 | *(empty)* |
| 224.0.0.116 | Device discovery/config | [COMTECH_Kft.] | 2016-10-20 | *(empty)* |
| 224.0.0.117 | DLEP Discovery | [RFC8175] | 2017-04-03 | *(empty)* |
| 224.0.0.118 | MAAS | [Mike_Pontillo] | 2017-05-19 | *(empty)* |
| 224.0.0.119 | ALL_GRASP_NEIGHBORS | [RFC8990] | 2017-07-20 | *(empty)* |
| 224.0.0.120 | 3GPP MBMS SACH | [Charles_Lo] | 2022-11-02 | Change Controller=[_3GPP] |
| 224.0.0.121 | ALL_V4_RIFT_ROUTERS | [RFC9692] | 2023-02-17 | *(empty)* |
| 224.0.0.122 | Network Virtualization Overlay (NVO) BUM Traffic | [RFC9624] | 2024-02-02 | *(empty)* |
| 224.0.0.123-224.0.0.149 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.150 | Ramp AltitudeCDN MulticastPlus | [Giovanni_Marzot] | 2019-03-13 | Change Controller=[Ramp_Holdings] |
| 224.0.0.151 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.152 | WiseHome | [Erick_MacDonald_Filzek] | 2023-08-09 | Change Controller=[IOT_COMPANY_SOLUCOES_TECNOLOGICAS_LTDA] |
| 224.0.0.153-224.0.0.250 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.0.251 | mDNS | [RFC6762] | 2000-04-01 | *(empty)* |
| 224.0.0.252 | Link-local Multicast Name Resolution | [RFC4795] | *(empty)* | Last Reviewed=2011-03-17 |
| 224.0.0.253 | Teredo | [RFC4380] | *(empty)* | Last Reviewed=2010-02-14 |
| 224.0.0.254 | RFC3692-style Experiment (*) | [RFC4727] | *(empty)* | *(empty)* |
| 224.0.0.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |

### 5c. Internetwork Control Block (224.0.1.0 - 224.0.1.255  (224.0.1/24))

CSV: `multicast-addresses-2.csv` — sub-registry Reference: `[RFC5771]` — 192 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.0.1.0 | VMTP Managers Group | [RFC1045][Dave_Cheriton] | *(empty)* | *(empty)* |
| 224.0.1.1 | NTP Network Time Protocol | [RFC5905][David_Mills] | *(empty)* | *(empty)* |
| 224.0.1.2 | SGI-Dogfight | [Andrew_Cherenson] | *(empty)* | *(empty)* |
| 224.0.1.3 | Rwhod | [Steve_Deering_2] | *(empty)* | *(empty)* |
| 224.0.1.4 | VNP | [Dave_Cheriton] | *(empty)* | *(empty)* |
| 224.0.1.5 | Artificial Horizons - Aviator | [Bruce_Factor] | *(empty)* | *(empty)* |
| 224.0.1.6 | NSS - Name Service Server | [Bill_Schilit] | *(empty)* | *(empty)* |
| 224.0.1.7 | AUDIONEWS - Audio News Multicast | [Martin_Forssen] | *(empty)* | *(empty)* |
| 224.0.1.8 | SUN NIS+ Information Service | [Chuck_McManis] | *(empty)* | *(empty)* |
| 224.0.1.9 | MTP Multicast Transport Protocol | [Susie_Armstrong] | *(empty)* | *(empty)* |
| 224.0.1.10 | IETF-1-LOW-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.11 | IETF-1-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.12 | IETF-1-VIDEO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.13 | IETF-2-LOW-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.14 | IETF-2-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.15 | IETF-2-VIDEO | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.0.1.16 | MUSIC-SERVICE | *(empty)* | *(empty)* | *(empty)* |
| 224.0.1.17 | SEANET-TELEMETRY | *(empty)* | *(empty)* | *(empty)* |
| 224.0.1.18 | SEANET-IMAGE | *(empty)* | *(empty)* | *(empty)* |
| 224.0.1.19 | MLOADD | [Bob_Braden] | 1996-04-01 | *(empty)* |
| 224.0.1.20 | any private experiment | [Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.1.21 | DVMRP on MOSPF | [[John Moy]] | *(empty)* | *(empty)* |
| 224.0.1.22 | SVRLOC | [John_Veizades] | 1995-05-01 | *(empty)* |
| 224.0.1.23 | XINGTV | [Howard_Gordon] | *(empty)* | *(empty)* |
| 224.0.1.24 | microsoft-ds | [\<arnoldm&microsoft.com>] | *(empty)* | *(empty)* |
| 224.0.1.25 | nbc-pro | [\<bloomer&birch.crd.ge.com>] | *(empty)* | *(empty)* |
| 224.0.1.26 | nbc-pfn | [\<bloomer&birch.crd.ge.com>] | *(empty)* | *(empty)* |
| 224.0.1.27 | lmsc-calren-1 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| 224.0.1.28 | lmsc-calren-2 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| 224.0.1.29 | lmsc-calren-3 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| 224.0.1.30 | lmsc-calren-4 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| 224.0.1.31 | ampr-info | [Rob_Janssen] | 1995-01-01 | *(empty)* |
| 224.0.1.32 | mtrace | [Steve_Casner_2] | 1995-01-01 | *(empty)* |
| 224.0.1.33 | RSVP-encap-1 | [Bob_Braden] | 1996-04-01 | *(empty)* |
| 224.0.1.34 | RSVP-encap-2 | [Bob_Braden] | 1996-04-01 | *(empty)* |
| 224.0.1.35 | SVRLOC-DA | [John_Veizades] | 1995-05-01 | *(empty)* |
| 224.0.1.36 | rln-server | [Brian_Kean] | 1995-08-01 | *(empty)* |
| 224.0.1.37 | proshare-mc | [Mark_Lewis] | 1995-10-01 | *(empty)* |
| 224.0.1.38 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.1.39 | cisco-rp-announce | [Dino_Farinacci] | 1996-03-01 | *(empty)* |
| 224.0.1.40 | cisco-rp-discovery | [Dino_Farinacci] | 1996-03-01 | *(empty)* |
| 224.0.1.41 | gatekeeper | [Jim_Toga] | 1996-05-01 | *(empty)* |
| 224.0.1.42 | iberiagames | [Jose_Luis_Marocho] | 1996-07-01 | *(empty)* |
| 224.0.1.43 | nwn-discovery | [Arnoud_Zwemmer] | 1996-11-01 | *(empty)* |
| 224.0.1.44 | nwn-adaptor | [Arnoud_Zwemmer] | 1996-11-01 | *(empty)* |
| 224.0.1.45 | isma-1 | [Stephen_Dunne] | 1997-01-01 | *(empty)* |
| 224.0.1.46 | isma-2 | [Stephen_Dunne] | 1997-01-01 | *(empty)* |
| 224.0.1.47 | telerate | [Wenjie_Peng] | 1997-01-01 | *(empty)* |
| 224.0.1.48 | ciena | [Mike_Rodbell] | 1997-01-01 | *(empty)* |
| 224.0.1.49 | dcap-servers | [RFC2114] | *(empty)* | *(empty)* |
| 224.0.1.50 | dcap-clients | [RFC2114] | *(empty)* | *(empty)* |
| 224.0.1.51 | mcntp-directory | [Heiko_Rupp] | 1997-01-01 | *(empty)* |
| 224.0.1.52 | mbone-vcr-directory | [Wieland_Holdfelder] | 1997-01-01 | *(empty)* |
| 224.0.1.53 | heartbeat | [Louis_Mamakos] | 1997-03-01 | *(empty)* |
| 224.0.1.54 | sun-mc-grp | [Michael_DeMoney] | 1997-04-01 | *(empty)* |
| 224.0.1.55 | extended-sys | [David_Poole] | 1997-04-01 | *(empty)* |
| 224.0.1.56 | pdrncs | [Paul_Wissenbach] | 1997-06-01 | *(empty)* |
| 224.0.1.57 | tns-adv-multi | [Jerome_Albin] | 1997-06-01 | *(empty)* |
| 224.0.1.58 | vcals-dmu | [Masato_Shindoh] | 1997-08-01 | *(empty)* |
| 224.0.1.59 | zuba | [Dan_Jackson] | 1997-09-01 | *(empty)* |
| 224.0.1.60 | hp-device-disc | [Shivaun_Albright] | 1997-07-01 | *(empty)* |
| 224.0.1.61 | tms-production | [Asad_Gilani] | 1997-07-01 | *(empty)* |
| 224.0.1.62 | sunscalar | [Terry_Gibson] | 1997-08-01 | *(empty)* |
| 224.0.1.63 | mmtp-poll | [Bryan_Costales] | 1997-09-01 | *(empty)* |
| 224.0.1.64 | compaq-peer | [Victor_Volpe] | 1997-10-01 | *(empty)* |
| 224.0.1.65 | iapp | [Bob_Meier] | 1997-12-01 | *(empty)* |
| 224.0.1.66 | multihasc-com | [Darcy_Brockbank] | 1997-12-01 | *(empty)* |
| 224.0.1.67 | serv-discovery | [Chas_Honton] | 1997-12-01 | *(empty)* |
| 224.0.1.68 | mdhcpdisover | [RFC2730] | *(empty)* | *(empty)* |
| 224.0.1.69 | MMP-bundle-discovery1 | [Gary_Scott_Malkin] | 1998-02-01 | *(empty)* |
| 224.0.1.70 | MMP-bundle-discovery2 | [Gary_Scott_Malkin] | 1998-02-01 | *(empty)* |
| 224.0.1.71 | XYPOINT DGPS Data Feed | [NE-TEAM_at_telecomsys.com] | 1998-02-01 | *(empty)* |
| 224.0.1.72 | GilatSkySurfer | [Yossi_Gal] | 1998-02-01 | *(empty)* |
| 224.0.1.73 | SharesLive | [Shane_Rowatt] | 1997-03-01 | *(empty)* |
| 224.0.1.74 | NorthernData | [[Sheers]] | *(empty)* | *(empty)* |
| 224.0.1.75 | SIP | [[Schulzrinne]] | *(empty)* | *(empty)* |
| 224.0.1.76 | IAPP | [Henri_Moelard] | 1998-03 | *(empty)* |
| 224.0.1.77 | AGENTVIEW | [Ram_Iyer] | 1998-03-01 | *(empty)* |
| 224.0.1.78 | Tibco Multicast1 | [Raymond_Shum] | 1998-04-01 | *(empty)* |
| 224.0.1.79 | Tibco Multicast2 | [Raymond_Shum] | 1998-04-01 | *(empty)* |
| 224.0.1.80 | MSP | [Evan_Caves] | 1998-06-01 | *(empty)* |
| 224.0.1.81 | OTT (One-way Trip Time) | [Beverly_Schwartz] | 1998-06-01 | *(empty)* |
| 224.0.1.82 | TRACKTICKER | [Alan_Novick] | 1998-08-01 | *(empty)* |
| 224.0.1.83 | dtn-mc | [Bob_Gaddie] | 1998-08-01 | *(empty)* |
| 224.0.1.84 | jini-announcement | [Bob_Scheifler] | 1998-08-01 | *(empty)* |
| 224.0.1.85 | jini-request | [Bob_Scheifler] | 1998-08-01 | *(empty)* |
| 224.0.1.86 | sde-discovery | [Peter_Aronson] | 1998-08-01 | *(empty)* |
| 224.0.1.87 | DirecPC-SI | [Doug_Dillon] | 1998-08-01 | *(empty)* |
| 224.0.1.88 | B1RMonitor | [Ed_Purkiss] | 1998-09-01 | *(empty)* |
| 224.0.1.89 | 3Com-AMP3 dRMON | [Prakash_Banthia] | 1998-09-01 | *(empty)* |
| 224.0.1.90 | imFtmSvc | [Zia_Bhatti] | 1998-09-01 | *(empty)* |
| 224.0.1.91 | NQDS4 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.92 | NQDS5 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.93 | NQDS6 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.94 | NLVL12 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.95 | NTDS1 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.96 | NTDS2 | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.97 | NODSA | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.98 | NODSB | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.99 | NODSC | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.100 | NODSD | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.101 | NQDS4R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.102 | NQDS5R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.103 | NQDS6R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.104 | NLVL12R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.105 | NTDS1R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.106 | NTDS2R | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.107 | NODSAR | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.108 | NODSBR | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.109 | NODSCR | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.110 | NODSDR | [Michael_Rosenberg] | 1998-09-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.1.111 | MRM | [Liming_Wei] | 1998-10-01 | *(empty)* |
| 224.0.1.112 | TVE-FILE | [Dean_Blackketter] | 1998-11-01 | *(empty)* |
| 224.0.1.113 | TVE-ANNOUNCE | [Dean_Blackketter] | 1998-11-01 | *(empty)* |
| 224.0.1.114 | Mac Srv Loc | [Bill_Woodcock] | 1998-11-01 | *(empty)* |
| 224.0.1.115 | Simple Multicast | [Jon_Crowcroft] | 1998-11-01 | *(empty)* |
| 224.0.1.116 | SpectraLinkGW | [Mark_Hamilton] | 1998-11-01 | *(empty)* |
| 224.0.1.117 | dieboldmcast | [Gene_Marsh] | 1998-11-01 | *(empty)* |
| 224.0.1.118 | Tivoli Systems | [Jon_Gabriel] | 1998-12-01 | *(empty)* |
| 224.0.1.119 | pq-lic-mcast | [Bob_Sledge] | 1998-12-01 | *(empty)* |
| 224.0.1.120 | Pico | [Pico_Sales] | 2007-03-01 | Change Controller=[Pico] |
| 224.0.1.121 | Pipesplatform | [Daniel_Dissett] | 1998-12-01 | *(empty)* |
| 224.0.1.122 | LiebDevMgmg-DM | [Mike_Velten] | 1999-01-01 | *(empty)* |
| 224.0.1.123 | TRIBALVOICE | [Nigel_Thompson] | 1999-01-01 | *(empty)* |
| 224.0.1.124 | Unassigned (Retracted 1/29/01) | *(empty)* | *(empty)* | *(empty)* |
| 224.0.1.125 | PolyCom Relay1 | [[Coutiere]] | *(empty)* | *(empty)* |
| 224.0.1.126 | Infront Multi1 | [Morten_Lindeman] | 1999-03-01 | *(empty)* |
| 224.0.1.127 | XRX DEVICE DISC | [Michael_Wang] | 1999-03-01 | *(empty)* |
| 224.0.1.128 | CNN | [Joel_Lynch] | 1999-04-01 | *(empty)* |
| 224.0.1.129 | PTP-primary | [NIST: IEEE Std 1588][Kang_Lee] | 2007-02-02 | *(empty)* |
| 224.0.1.130 | PTP-alternate1 | [NIST: IEEE Std 1588][Kang_Lee] | 2007-02-02 | *(empty)* |
| 224.0.1.131 | PTP-alternate2 | [NIST: IEEE Std 1588][Kang_Lee] | 2007-02-02 | *(empty)* |
| 224.0.1.132 | PTP-alternate3 | [NIST: IEEE Std 1588][Kang_Lee] | 2007-02-02 | *(empty)* |
| 224.0.1.133 | ProCast | [Shai_Revzen] | 1999-04-01 | *(empty)* |
| 224.0.1.134 | 3Com Discp | [Peter_White] | 1999-04-01 | *(empty)* |
| 224.0.1.135 | CS-Multicasting | [Nedelcho_Stanev] | 1999-05-01 | *(empty)* |
| 224.0.1.136 | TS-MC-1 | [Darrell_Sveistrup] | 1999-06-01 | *(empty)* |
| 224.0.1.137 | Make Source | [Anthony_Daga] | 1999-06-01 | *(empty)* |
| 224.0.1.138 | Teleborsa | [Paolo_Strazzera] | 1999-06-01 | *(empty)* |
| 224.0.1.139 | SUMAConfig | [Walter_Wallach] | 1999-07-01 | *(empty)* |
| 224.0.1.140 | capwap-ac | [RFC5415] | *(empty)* | *(empty)* |
| 224.0.1.141 | DHCP-SERVERS | [Eric_Hall] | 1999-10-01 | *(empty)* |
| 224.0.1.142 | CN Router-LL | [Ian_Armitage] | 1999-08-01 | *(empty)* |
| 224.0.1.143 | EMWIN | [Antonio_Querubin] | 2008-02-04 | *(empty)* |
| 224.0.1.144 | Alchemy Cluster | [Stacey_O_Rourke][Stacey_O_Rourke_2] | 1999-08-01 | *(empty)* |
| 224.0.1.145 | Satcast One | [Julian_Nevell] | 1999-08-01 | *(empty)* |
| 224.0.1.146 | Satcast Two | [Julian_Nevell] | 1999-08-01 | *(empty)* |
| 224.0.1.147 | Satcast Three | [Julian_Nevell] | 1999-08-01 | *(empty)* |
| 224.0.1.148 | Intline | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.149 | 8x8 Multicast | [Mike_Roper] | 1999-09-01 | *(empty)* |
| 224.0.1.150 | Ramp AltitudeCDN MulticastPlus | [Giovanni_Marzot] | 2019-03-13 | Change Controller=[Ramp_Holdings] |
| 224.0.1.151 | Intline-1 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.152 | Intline-2 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.153 | Intline-3 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.154 | Intline-4 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.155 | Intline-5 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.156 | Intline-6 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.157 | Intline-7 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.158 | Intline-8 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.159 | Intline-9 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.160 | Intline-10 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.161 | Intline-11 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.162 | Intline-12 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.163 | Intline-13 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.164 | Intline-14 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.165 | Intline-15 | [Robert_Sliwinski] | 2000-02-01 | *(empty)* |
| 224.0.1.166 | marratech-cc | [Peter_Parnes] | 2000-02-01 | *(empty)* |
| 224.0.1.167 | EMS-InterDev | [Stephen_T_Lyda] | 2000-02-01 | *(empty)* |
| 224.0.1.168 | itb301 | [Bodo_Rueskamp] | 2000-03-01 | *(empty)* |
| 224.0.1.169 | rtv-audio | [Chris_Adams] | 2000-07-01 | *(empty)* |
| 224.0.1.170 | rtv-video | [Chris_Adams] | 2000-07-01 | *(empty)* |
| 224.0.1.171 | HAVI-Sim | [Stephan_Wasserroth] | 2000-07-01 | *(empty)* |
| 224.0.1.172 | Nokia Cluster | [Stacey_O_Rourke][Stacey_O_Rourke_2] | 1999-08-01 | *(empty)* |
| 224.0.1.173 | host-request | [Keith_Thompson] | 2001-06-01 | *(empty)* |
| 224.0.1.174 | host-announce | [Keith_Thompson] | 2001-06-01 | *(empty)* |
| 224.0.1.175 | ptk-cluster | [Robert_Hodgson] | 2001-12-01 | *(empty)* |
| 224.0.1.176 | Proxim Protocol | [Gajendra_Shukla] | 2002-02-01 | *(empty)* |
| 224.0.1.177 | Gemtek Systems | [Alex_Lee] | 2002-10-01 | *(empty)* |
| 224.0.1.178 | IEEE IAPP | [Stuart_Kerry] | 2003-01-01 | *(empty)* |
| 224.0.1.179 | 1451_Dot5_802_Discovery | [Ryon_Coleman] | 2006-04-11 | *(empty)* |
| 224.0.1.180 | 1451_Dot5_802_Group_1 | [Ryon_Coleman] | 2006-04-11 | *(empty)* |
| 224.0.1.181 | 1451_Dot5_802_Group_2 | [Ryon_Coleman] | 2006-04-11 | *(empty)* |
| 224.0.1.182 | 1451_Dot5_802_Group_3 | [Ryon_Coleman] | 2006-04-11 | *(empty)* |
| 224.0.1.183 | 1451_Dot5_802_Group_4 | [Ryon_Coleman] | 2006-04-11 | *(empty)* |
| 224.0.1.184 | VFSDP | [Adam_Yellen] | 2007-03-06 | *(empty)* |
| 224.0.1.185 | ASAP | [RFC5352] | *(empty)* | *(empty)* |
| 224.0.1.186 | SL-MANET-ROUTERS | [RFC6621] | *(empty)* | *(empty)* |
| 224.0.1.187 | All CoAP Nodes | [RFC7252] | 2013-07-25 | *(empty)* |
| 224.0.1.188 | BRSDP | [Vanya_Levy] | 2019-02-20 | Change Controller=[Semtech_Corporation] |
| 224.0.1.189 | Amateur radio DMR | [ETSI TS 102 361-3][Jean-Marc_MAGNIER] | 2021-02-08 | Change Controller=[Jean-Marc_MAGNIER] |
| 224.0.1.190 | All CoRE Resource Directories | [RFC9176] | 2021-03-16 | *(empty)* |
| 224.0.1.191-224.0.1.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |

### 5d. AD-HOC Block I (224.0.2.0 - 224.0.255.255)

CSV: `multicast-addresses-3.csv` — sub-registry Reference: `[RFC5771]` — 244 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.0.2.0 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.2.1 | "rwho" Group (BSD) (unofficial) | [Jon_Postel] | *(empty)* | *(empty)* |
| 224.0.2.2 | SUN RPC PMAPPROC_CALLIT | [Brendan_Eic] | *(empty)* | *(empty)* |
| 224.0.2.3 | EPSON-disc-set | [SEIKO_EPSON_Corp] | 2005-01-01 | *(empty)* |
| 224.0.2.4 | All C1222 Nodes | [RFC6142] | 2009-08-28 | *(empty)* |
| 224.0.2.5 | Monitoring Discovery Protocol | [Alan_Robertson] | 2012-04-17 | *(empty)* |
| 224.0.2.6 | BitSend MediaStreams | [Carl-Johan_Sjöberg] | 2012-04-25 | *(empty)* |
| 224.0.2.7-224.0.2.8 | rxWARN | [Caleb_Bell] | 2012-11-19 | *(empty)* |
| 224.0.2.9 | DATV streams | [Grant_Taylor] | 2016-10-04 | *(empty)* |
| 224.0.2.10 | swapapp_multicast | [Applykane] | 2017-05-19 | *(empty)* |
| 224.0.2.11 | LDA Discovery Service | [Juan_Ayas] | 2018-10-17 | Change Controller=[LDA_Audio_Tech] |
| 224.0.2.12 | CNP-HD-PLC | [Ernst_EDER] | 2018-11-15 | Change Controller=[LonMark_International] |
| 224.0.2.13 | BSE | [Rami_Chalhoub] | 2019-01-17 | Change Controller=[BSE] |
| 224.0.2.14 | OPC Discovery | [OPC_Foundation] | 2019-08-19 | Change Controller=[OPC_Foundation] |
| 224.0.2.15 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.2.16-224.0.2.17 | unidns | [Xie_Shao] | 2023-01-18 | Change Controller=[Xie_Shao] |
| 224.0.2.18 | vivoh-directory-1 | [Giovanni_Marzot_2] | 2023-10-13 | Change Controller=[Vivoh] |
| 224.0.2.19 | vivoh-directory-2 | [Giovanni_Marzot_2] | 2023-10-13 | Change Controller=[Vivoh] |
| 224.0.2.20-224.0.2.26 | RGB Spectrum | [Lynton_Auld] | 2024-11-04 | Change Controller=[RGB_Spectrum] |
| 224.0.2.27 | OSIBYTES/PYBLOX Global Service | [Ryan_Taylor] | 2025-11-13 | *(empty)* |
| 224.0.2.28-224.0.2.63 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.2.64-224.0.2.95 | Intercontinental Exchange, Inc. | [RIR_Admin] | 1996-04 | Change Controller=[Intercontinental_Exchange_Inc.]; Last Reviewed=2007-07 |
| 224.0.2.96-224.0.2.127 | BallisterNet | [Tom_Ballister] | 1997-07-01 | Change Controller=[Tom_Ballister]; Last Reviewed=2021-06-11 |
| 224.0.2.128-224.0.2.191 | WOZ-Garage | [Douglas_Marquardt] | 1997-02-01 | *(empty)* |
| 224.0.2.192-224.0.2.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 1997-02-01 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.3.0-224.0.3.255 | RFE Generic Service | [Daniel_Steinber] | *(empty)* | *(empty)* |
| 224.0.4.0-224.0.4.255 | RFE Individual Conferences | [Daniel_Steinber] | *(empty)* | *(empty)* |
| 224.0.5.0-224.0.5.127 | CDPD Groups | [[Bob Brenner]] | *(empty)* | *(empty)* |
| 224.0.5.128-224.0.5.191 | Intercontinental Exchange, Inc. | [RIR_Admin] | 1998-10-01 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.5.192-224.0.5.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2001-08-01 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.6.0-224.0.6.127 | Cornell ISIS Project | [[Tim Clark]] | *(empty)* | *(empty)* |
| 224.0.6.128-224.0.6.143 | MoeSingh | [Moe_Singh] | 2009-09-24 | *(empty)* |
| 224.0.6.144 | QDNE | [Architecture_Team] | 2018-01-03 | *(empty)* |
| 224.0.6.145-224.0.6.150 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.6.151 | Canon-Device-control | [Hiroshi_Okubo] | 2014-08-01 | *(empty)* |
| 224.0.6.152-224.0.6.191 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.6.192-224.0.6.255 | OneChicago multicast | [Brian_Trudeau] | 2014-09-19 | *(empty)* |
| 224.0.7.0-224.0.7.255 | Where-Are-You | [Bill_Simpson] | 1994-11-01 | *(empty)* |
| 224.0.8.0 | Cell Broadcast Encapsulation | [Meridian_Labs_LTD][LIRNEasia] | 2017-10-13 | Change Controller=[Meridian_Labs_LTD]<br>[LIRNEasia] |
| 224.0.8.1-224.0.8.255 | Civic Telemetry | [Meridian_Labs_LTD][LIRNEasia] | 2020-10-07 | Change Controller=[Meridian_Labs_LTD]<br>[LIRNEasia] |
| 224.0.9.0-224.0.9.255 | The Thing System | [Carl_Malamud] | 1998-04-01 | *(empty)* |
| 224.0.10.0-224.0.10.255 | DLSw Groups | [Choon_Lee] | 1996-04-01 | *(empty)* |
| 224.0.11.0-224.0.11.255 | NCC.NET Audio | [David_Rubin] | 1996-08-01 | *(empty)* |
| 224.0.12.0-224.0.12.63 | Microsoft and MSNBC | [Tom_Blank] | 1996-11-01 | *(empty)* |
| 224.0.12.64-224.0.12.231 | AsiaNext | [Lau_Wei_Lun] | 2023-03-03 | Change Controller=[Asia_Digital_Exchange] |
| 224.0.12.136-224.0.12.191 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.12.192-224.0.12.243 | Deribit | [Maarten_van_Malland] | 2025-10-10 | Change Controller=[Sentillia] |
| 224.0.12.244-224.0.12.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.13.0-224.0.13.255 | WorldCom Broadcast Services | [Tony_Barber] | 1997-01-01 | *(empty)* |
| 224.0.14.0-224.0.14.255 | NLANR | [Duane_Wessels] | 1997-02-01 | *(empty)* |
| 224.0.15.0-224.0.15.255 | Agilent Technologies | [IP_Admin] | 1997-02-01 | *(empty)* |
| 224.0.16.0-224.0.16.255 | XingNet | [Mika_Uusitalo] | 1997-04-01 | *(empty)* |
| 224.0.17.0-224.0.17.31 | Mercantile & Commodity Exchange | [Asad_Gilani] | 1997-07-01 | *(empty)* |
| 224.0.17.32-224.0.17.63 | NDQMD1 | [Michael_Rosenberg] | 1999-03-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.17.64-224.0.17.127 | ODN-DTV | [Richard_Hodges] | 1999-03-01 | *(empty)* |
| 224.0.17.128-224.0.17.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.18.0-224.0.18.255 | Dow Jones | [Wenjie_Peng] | 1997-01-01 | *(empty)* |
| 224.0.19.0-224.0.19.63 | Walt Disney Company | [Scott_Watson] | 1997-08-01 | *(empty)* |
| 224.0.19.64-224.0.19.95 | Cal Multicast | [Ed_Moran] | 1997-10-01 | *(empty)* |
| 224.0.19.96-224.0.19.127 | Intercontinental Exchange, Inc. | [RIR_Admin] | 1997-10 | Change Controller=[Intercontinental_Exchange_Inc.]; Last Reviewed=2007-07 |
| 224.0.19.128-224.0.19.191 | IIG Multicast | [Wayne_Carr] | 1997-12-01 | *(empty)* |
| 224.0.19.192-224.0.19.207 | Metropol | [James_Crawford] | 1998-05-01 | *(empty)* |
| 224.0.19.208-224.0.19.239 | Xenoscience, Inc. | [Mary_Timm] | 1998-07-01 | *(empty)* |
| 224.0.19.240-224.0.19.255 | MJDPM | [Matthew_Straight] | 2007-03-01 | *(empty)* |
| 224.0.20.0-224.0.20.63 | MS-IP/TV | [Tony_Wong] | 1998-07-01 | *(empty)* |
| 224.0.20.64-224.0.20.127 | Reliable Network Solutions | [Werner_Vogels] | 1998-08-01 | *(empty)* |
| 224.0.20.128-224.0.20.143 | TRACKTICKER Group | [Alan_Novick] | 1998-08-01 | *(empty)* |
| 224.0.20.144-224.0.20.207 | CNR Rebroadcast MCA | [Robert_Sautter] | 1999-08-01 | *(empty)* |
| 224.0.20.208-224.0.20.211 | CIX Trading | [Darren_Molloy] | 2025-09-18 | Change Controller=[CIX_Trading] |
| 224.0.20.212-224.0.20.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.21.0-224.0.21.127 | Talarian MCAST | [Geoff_Mendal] | 1999-01-01 | *(empty)* |
| 224.0.21.128-224.0.21.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.22.0-224.0.22.239 | WORLD MCAST | [Ian_Stewart] | 1999-06-01 | *(empty)* |
| 224.0.22.240-224.0.22.255 | Jones International | [Jim_Ginsburg] | 2007-10-31 | *(empty)* |
| 224.0.23.0 | ECHONET | [Takeshi_Saito] | 2003-02-01 | *(empty)* |
| 224.0.23.1 | Ricoh-device-ctrl | [Akihiro_Nishida] | 2003-02-01 | *(empty)* |
| 224.0.23.2 | Ricoh-device-ctrl | [Akihiro_Nishida] | 2003-02-01 | *(empty)* |
| 224.0.23.3-224.0.23.10 | Telefeed | [Wally_Beddoe] | 2003-04-01 | *(empty)* |
| 224.0.23.11 | SpectraTalk | [Madhav_Karhade] | 2003-05-01 | *(empty)* |
| 224.0.23.12 | KNXnet/IP | [Joost_Demarest] | 2003-07-01 | Change Controller=[KNX_Association]; Last Reviewed=2023-08-23 |
| 224.0.23.13 | TVE-ANNOUNCE2 | [Michael_Dolan] | 2003-10-01 | *(empty)* |
| 224.0.23.14 | DvbServDisc | [Bert_van_Willigen] | 2004-01-01 | *(empty)* |
| 224.0.23.15-224.0.23.31 | MJDPM | [Matthew_Straight] | 2007-03-01 | *(empty)* |
| 224.0.23.32 | Norman MCMP | [Kristian_A_Bognaes] | 2004-02-01 | *(empty)* |
| 224.0.23.33 | RRDP | [Tetsuo_Hoshi] | 2004-06-01 | *(empty)* |
| 224.0.23.34 | AF_NA | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.35 | AF_OPRA_NBBO | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.36 | AF_OPRA_FULL | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.37 | AF_NEWS | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.38 | AF_NA_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.39 | AF_OPRA_NBBO_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.40 | AF_OPRA_FULL_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.41 | AF_NEWS_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.42 | Control for IP Video | [Nadine_Guillaume] | 2005-02-01 | *(empty)* |
| 224.0.23.43 | acp-discovery | [Andy_Belk] | 2005-02-01 | *(empty)* |
| 224.0.23.44 | acp-management | [Andy_Belk] | 2005-02-01 | *(empty)* |
| 224.0.23.45 | acp-data | [Andy_Belk] | 2005-02-01 | *(empty)* |
| 224.0.23.46 | dof-multicast | [Bryant_Eastham] | 2006-06-16 | Last Reviewed=2015-04-23 |
| 224.0.23.47 | AF_DOB_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.48 | AF_OPRA_FULL2_CHI | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.49 | AF_DOB | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.50 | AF_OPRA_FULL2 | [Bob_Brzezinski] | 2005-10-28 | *(empty)* |
| 224.0.23.51 | Fairview | [Jim_Lyle] | 2006-08-07 | *(empty)* |
| 224.0.23.52 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2006-08-11 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.23.53 | MCP | [Tim_DeBaillie] | 2006-11-30 | *(empty)* |
| 224.0.23.54 | ServDiscovery | [Paul_Langille] | 2007-01-17 | *(empty)* |
| 224.0.23.55 | noaaport1 | [Antonio_Querubin] | 2008-02-04 | *(empty)* |
| 224.0.23.56 | noaaport2 | [Antonio_Querubin] | 2008-02-04 | *(empty)* |
| 224.0.23.57 | noaaport3 | [Antonio_Querubin] | 2008-02-04 | *(empty)* |
| 224.0.23.58 | noaaport4 | [Antonio_Querubin] | 2008-02-04 | *(empty)* |
| 224.0.23.59 | DigacIP7 | [Jonathan_Niedfeldt] | 2008-02-22 | *(empty)* |
| 224.0.23.60 | AtscSvcSig | [Jerry_Whitaker] | 2008-12-19 | *(empty)* |
| 224.0.23.61 | SafetyNET p (potentially IGMPv1) | [Pilz] | 2009-03-13 | *(empty)* |
| 224.0.23.62 | BluemoonGamesMC | [Christopher_Mettin] | 2009-05-12 | *(empty)* |
| 224.0.23.63 | iADT Discovery | [Paul_Suhler] | 2009-05-12 | *(empty)* |
| 224.0.23.64-224.0.23.80 | Moneyline | [Guido_Petronio] | 2004-01-01 | *(empty)* |
| 224.0.23.81-224.0.23.127 | Reserved (Moneyline) | *(empty)* | *(empty)* | *(empty)* |
| 224.0.23.128-224.0.23.157 | PHLX | [Michael_Rosenberg] | 2004-01-01 | Change Controller=[Nasdaq_Inc] |
| 224.0.23.158 | VSCP | [Charles_Tewiah] | 2005-09-01 | *(empty)* |
| 224.0.23.159 | LXI-EVENT | [Nick_Barendt] | 2005-11-04 | *(empty)* |
| 224.0.23.160 | solera_lmca | [Mark_Armstrong] | 2006-02-09 | *(empty)* |
| 224.0.23.161 | VBooster | [Alexander_Pevzner] | 2006-03-17 | *(empty)* |
| 224.0.23.162 | cajo discovery | [John_Catherino] | 2006-03-17 | *(empty)* |
| 224.0.23.163 | INTELLIDEN | [Jeff_Schenk] | 2006-03-31 | *(empty)* |
| 224.0.23.164 | IceEDCP | [Oliver_Lewis] | 2006-07-11 | *(empty)* |
| 224.0.23.165 | omasg | [Mark_Lipford] | 2006-07-11 | *(empty)* |
| 224.0.23.166 | MEDIASTREAM | [Maurice_Robberson] | 2006-08-15 | *(empty)* |
| 224.0.23.167 | Systech Mcast | [Dan_Jakubiec] | 2006-08-21 | *(empty)* |
| 224.0.23.168 | tricon-system-management | [John_Gabler] | 2007-07-06 | *(empty)* |
| 224.0.23.169 | MNET discovery | [Andy_Crick] | 2008-01-14 | *(empty)* |
| 224.0.23.170 | CCNx (not for global routing) | [Simon_Barber] | 2009-09-24 | *(empty)* |
| 224.0.23.171 | LLAFP | [Michael_Lyle] | 2009-11-11 | *(empty)* |
| 224.0.23.172 | UFMP | [Shachar_Dor] | 2010-02-04 | Change Controller=[Mellanox] |
| 224.0.23.173 | PHILIPS-HEALTH | [Mike_King] | 2010-02-26 | Change Controller=[Philips_Healthcare] |
| 224.0.23.174 | PHILIPS-HEALTH | [Mike_King] | 2010-02-26 | Change Controller=[Philips_Healthcare] |
| 224.0.23.175 | QDP | [Kevin_Gross] | 2010-03-12 | *(empty)* |
| 224.0.23.176 | CalAmp WCP | [Pierre_Oliver] | 2011-06-06 | *(empty)* |
| 224.0.23.177 | AES discovery | [Kevin_Gross_2] | 2012-08-28 | *(empty)* |
| 224.0.23.178 | JDP Java Discovery Protocol | [Florian_Weimer] | 2013-02-08 | *(empty)* |
| 224.0.23.179 | PixelPusher | [Jasmine_Strong] | 2014-06-04 | *(empty)* |
| 224.0.23.180 | network metronome | [George_Neville-Neil] | 2014-12-17 | *(empty)* |
| 224.0.23.181 | polaris-video-transport | [Geoff_Golder] | 2016-04-19 | *(empty)* |
| 224.0.23.182 | AMI-DISCOVERY | [Dmitri_Kisten] | 2025-12-01 | Change Controller=[Alcorn_McBride_Inc.] |
| 224.0.23.183-224.0.23.191 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.0.23.192-224.0.23.255 | PINKOTC | [Sergey_Shulgin] | 2008-08-12 | *(empty)* |
| 224.0.24.0-224.0.24.127 | AGSC UK VVs | [Andrew_Rowley] | 2006-06-09 | *(empty)* |
| 224.0.24.128-224.0.24.255 | EM-MULTI | [Soren_Martin_Sorensen] | 2006-08-07 | *(empty)* |
| 224.0.25.0-224.0.28.255 | CME Market Data | [Anthony_Lopresti] | 2007-03-22 | Change Controller=[CME_Group] |
| 224.0.29.0-224.0.30.255 | Deutsche Boerse | [Jan_Drwal] | 2007-03-22 | *(empty)* |
| 224.0.31.0-224.0.34.255 | CME Market Data | [Anthony_Lopresti] | 2007-07-17 | Change Controller=[CME_Group] |
| 224.0.35.0-224.0.35.255 | M2S | [Itamar_Gilad] | 2007-08-31 | *(empty)* |
| 224.0.36.0-224.0.36.255 | DigiPlay | [Robert_Taylor] | 2016-09-29 | *(empty)* |
| 224.0.37.0-224.0.38.255 | London Metal Exchange | [LME_Networks] | 2017-03-24 | Change Controller=[London_Metal_Exchange] |
| 224.0.39.0-224.0.40.255 | CDAS | [Oyvind_H_Olsen] | 2007-09-12 | *(empty)* |
| 224.0.41.0-224.0.41.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2007-11-28 | Change Controller=[Intercontinental_Exchange_Inc.]; Last Reviewed=2011-02-15 |
| 224.0.42.0-224.0.45.255 | Media Systems | [Media_Systems_OOO] | 2008-01-15 | Change Controller=[Media_Systems_OOO] |
| 224.0.46.0-224.0.50.255 | Deutsche Boerse | [Jan_Drwal] | 2008-01-25 | *(empty)* |
| 224.0.51.0-224.0.51.255 | ALCOM-IPTV | [TV_System_Administrators] | 2008-04-09 | Change Controller=[Ålands_Telekommunikation_Ab]; Last Reviewed=2018-02-20 |
| 224.0.52.0-224.0.53.255 | Euronext | [Euronext_Admin] | 2008-07-23 | Change Controller=[Euronext_Admin]; Last Reviewed=2014-11-24 |
| 224.0.54.0-224.0.57.255 | Telia Norway mcast | [Henrik_Lans] | 2008-08-20 | Change Controller=[Telia-Norway-Get-NOC] |
| 224.0.58.0-224.0.61.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2008-08-27 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.62.0-224.0.62.255 | BATS | [Cboe_POC] | 2008-12-24 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.63.0-224.0.63.255 | BATS Trading | [Cboe_POC] | 2009-03-13 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.64.0-224.0.67.255 | Euronext | [Euronext_Admin] | 2009-03-13 | Change Controller=[Euronext_Admin]; Last Reviewed=2014-11-24 |
| 224.0.68.0-224.0.69.255 | Nasdaq Inc. | [Michael_Rosenberg] | 2009-05-12 | Change Controller=[Nasdaq_Inc] |
| 224.0.70.0-224.0.71.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2009-06-16 | Change Controller=[Intercontinental_Exchange_Inc.]; Last Reviewed=2011-03-01 |
| 224.0.72.0-224.0.72.255 | TMX | [TMX_Network_Engineering] | 2009-08-28 | Change Controller=[TMX] |
| 224.0.73.0-224.0.74.255 | Direct Edge | [Cboe_POC] | 2009-08-28 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.75.0-224.0.75.255 | Nasdaq Inc. | [Michael_Rosenberg] | 2010-01-22 | Change Controller=[Nasdaq_Inc] |
| 224.0.76.0-224.0.76.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2010-02-26 | Change Controller=[Intercontinental_Exchange_Inc.]; Last Reviewed=2011-03-01 |
| 224.0.77.0-224.0.77.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2010-02-26 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.78.0-224.0.78.255 | ALCOM-IPTV | [TV_System_Administrators] | 2010-03-12 | Change Controller=[Ålands_Telekommunikation_Ab]; Last Reviewed=2018-02-20 |
| 224.0.79.0-224.0.81.255 | Nasdaq Inc. | [Michael_Rosenberg] | 2010-08-24 | Change Controller=[Nasdaq_Inc] |
| 224.0.82.0-224.0.85.255 | BATS Trading | [Cboe_POC] | 2011-01-31 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.86.0-224.0.101.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2011-02-10 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.102.0-224.0.102.127 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2011-04-13 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.102.128-224.0.102.255 | MVS-IPTV-2 | [Midwest_Video_Solutions] | 2014-06-12 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.103.0-224.0.104.255 | MVS-IPTV | [Midwest_Video_Solutions][Adam_DeMinter] | 2011-04-20 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.105.0-224.0.105.127 | MIAX Multicast | [Gamini_Karunaratne] | 2011-06-06 | Change Controller=[MIAX] |
| 224.0.105.128-224.0.105.255 | MVS-IPTV3 | [Justin_Beaman] | 2017-12-04 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.106.0-224.0.106.255 | TMX | [TMX_Network_Engineering] | 2011-06-16 | Change Controller=[TMX] |
| 224.0.107.0-224.0.108.255 | TSX Inc. | [TMX_Network_Engineering] | 2011-07-13 | Change Controller=[TMX] |
| 224.0.109.0-224.0.110.255 | TSX Inc. | [TMX_Network_Engineering] | 2011-10-25 | Change Controller=[TMX] |
| 224.0.111.0-224.0.111.255 | VoleraDataFeed | [Cboe_POC] | 2011-10-25 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.112.0-224.0.112.255 | JHB-STOCK-EXCH | [Clem_Verwey] | 2011-12-07 | *(empty)* |
| 224.0.113.0-224.0.114.255 | Deutsche Boerse | [Jan_Drwal] | 2011-12-19 | *(empty)* |
| 224.0.115.0-224.0.115.255 | TMX | [TMX_Network_Engineering] | 2012-06-12 | Change Controller=[TMX] |
| 224.0.116.0-224.0.116.255 | Intercontinental Exchange, Inc | [RIR_Admin] | 2012-06-19 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.117.0-224.0.119.255 | Nasdaq Inc. | [Michael_Rosenberg] | 2012-07-12 | Change Controller=[Nasdaq_Inc] |
| 224.0.120.0-224.0.120.255 | czechbone iptv | [Karel_Vesely] | 2013-01-15 | Change Controller=[Nej.cz] |
| 224.0.121.0-224.0.121.255 | AQUIS-EXCHANGE | [Paul_Roberts] | 2013-05-13 | Change Controller=[Aquis_Exchange_PLC] |
| 224.0.122.0-224.0.123.255 | DNS:NET TV | [Marlon_Berlin] | 2013-05-25 | *(empty)* |
| 224.0.124.0-224.0.124.255 | Boston Options Exchange | [David_Wilson][Michael_Caravetta] | 2013-05-30 | *(empty)* |
| 224.0.125.0-224.0.125.255 | Hanweck Associates | [Cboe_POC] | 2013-09-05 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.126.0-224.0.129.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2013-10-31 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.130.0-224.0.131.255 | BATS Trading | [Cboe_POC] | 2014-03-05 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.132.0-224.0.135.255 | Net By Net Holding IPTV | [Lev_V._Cherednikov] | 2014-04-12 | *(empty)* |
| 224.0.136.0-224.0.139.255 | Aequitas Innovations Inc. | [Cboe_POC] | 2014-05-16 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.140.0-224.0.140.255 | Instinet | [Instinet] | 2014-09-04 | Change Controller=[Instinet] |
| 224.0.141.0-224.0.141.255 | MIAX-2 | [Gamini_Karunaratne] | 2015-06-30 | Change Controller=[MIAX] |
| 224.0.142.0-224.0.142.255 | MIAX M3 | [Gamini_Karunaratne] | 2017-05-19 | Change Controller=[MIAX] |
| 224.0.143.0-224.0.143.255 | A2X-EXCHANGE | [Neal_Lawrence] | 2017-06-02 | *(empty)* |
| 224.0.144.0-224.0.151.255 | VZ-Multicast-Public | [Stephen_Ray_Middleton] | 2015-03-23 | *(empty)* |
| 224.0.152.0-224.0.152.255 | cse-md | [David_Brett] | 2016-04-19 | *(empty)* |
| 224.0.153.0-224.0.156.255 | Telia Norway mcast | [Henrik_Lans] | 2016-05-24 | Change Controller=[Telia-Norway-Get-NOC] |
| 224.0.157.0-224.0.157.255 | London Metal Exchange | [LME_Networks] | 2017-01-23 | Change Controller=[London_Metal_Exchange] |
| 224.0.158.0-224.0.159.255 | TriAct Canada Marketplace LP | [Hatice_Unal] | 2017-01-23 | *(empty)* |
| 224.0.160.0-224.0.165.255 | Deutsche Boerse | [Bernd_Uphoff] | 2016-07-07 | *(empty)* |
| 224.0.166.0-224.0.167.255 | Virgin Connect IPTV | [Vladimir_Shishkov] | 2017-02-17 | *(empty)* |
| 224.0.168.0-224.0.169.255 | Deutsche Boerse | [Bernd_Uphoff] | 2017-12-05 | *(empty)* |
| 224.0.170.0-224.0.170.255 | MVS-IPTV4 | [Justin_Beaman] | 2018-06-07 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.171.0-224.0.171.255 | COINBASE-MARKETS | [Gavin_McKee] | 2019-01-25 | Change Controller=[Coinbase] |
| 224.0.172.0-224.0.175.255 | Deutsche Boerse | [Bernd_Uphoff] | 2018-06-19 | *(empty)* |
| 224.0.176.0-224.0.179.255 | MIAX-EX-3-4-5 | [Gamini_Karunaratne] | 2018-07-31 | Change Controller=[MIAX] |
| 224.0.180.0-224.0.181.255 | CBOE Europe | [Cboe_POC] | 2019-02-13 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.182.0-224.0.183.255 | ALCOM-TV | [TV_System_Administrators] | 2019-02-28 | Change Controller=[Ålands_Telekommunikation_Ab] |
| 224.0.184.0-224.0.184.255 | AQUIS-EXCHANGE | [Paul_Roberts] | 2019-08-28 | Change Controller=[Aquis_Exchange_PLC] |
| 224.0.185.0-224.0.185.255 | Hanweck Associates | [Cboe_POC] | 2019-09-12 | Change Controller=[Cboe_Bats_LLC] |
| 224.0.186.0-224.0.186.255 | BOX Options Market | [Alexandre_Gomes] | 2019-10-02 | Change Controller=[BOX_TECHNOLOGY_CANADA_INC.] |
| 224.0.187.0-224.0.188.255 | MVS-IPTV5 | [Justin_Beaman] | 2019-11-13 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.189.0-224.0.189.255 | Ido Rosen | [Ido_Rosen] | 2021-03-23 | Change Controller=[Ido_Rosen] |
| 224.0.190.0-224.0.191.255 | RTP Media | [Vadim_B._Kantor] | 2020-10-01 | Change Controller=[RTP_Media] |
| 224.0.192.0-224.0.207.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2021-04-01 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.0.208.0-224.0.213.255 | Euronext | [Euronext_Admin] | 2021-04-13 | Change Controller=[Euronext_Admin] |
| 224.0.214.0-224.0.214.255 | OSK B2B mVPN distribution | [Attila_Miklóš] | 2021-06-11 | Change Controller=[IPadmin_-_Orange_Slovensko_a.s.] |
| 224.0.215.0-224.0.215.255 | Tradeweb CLOB | [Ruben_Hernandez] | 2022-01-06 | Change Controller=[Tradeweb_Markets_Inc] |
| 224.0.216.0-224.0.219.255 | RTP Media | [Vadim_B._Kantor] | 2021-07-30 | Change Controller=[RTP_Media] |
| 224.0.220.0-224.0.223.255 | Japan Exchange Group | [Japan_Exchange_Group] | 2021-09-07 | Change Controller=[Japan_Exchange_Group] |
| 224.0.224.0-224.0.224.255 | AQUIS-EXCHANGE | [Paul_Roberts] | 2021-12-21 | Change Controller=[Aquis_Exchange_PLC] |
| 224.0.225.0-224.0.225.255 | Kalejdo TV | [Kalejdo_TV] | 2022-08-26 | Change Controller=[Thomas_Sörlin] |
| 224.0.226.0-224.0.227.255 | MVS-IPTV6 | [Justin_Beaman] | 2022-06-09 | Change Controller=[Midwest_Video_Solutions] |
| 224.0.228.0-224.0.231.255 | London Metal Exchange | [LME_Networks] | 2022-02-01 | Change Controller=[London_Metal_Exchange] |
| 224.0.232.0-224.0.239.255 | Lucera Financial Infra | [Kevin_McNicholas] | 2022-02-17 | Change Controller=[Lucera_Financial_Infrastructures] |
| 224.0.240.0-224.0.243.255 | London Metal Exchange | [LME_Networks] | 2022-05-26 | Change Controller=[London_Metal_Exchange] |
| 224.0.244.0-224.0.244.255 | Clearpool AMS | [Charles_Gomes] | 2023-05-19 | Change Controller=[Clearpool] |
| 224.0.245.0-224.0.245.255 | OneChronos | [Kelly_Littlepage] | 2023-08-29 | Change Controller=[OCX_Group_Inc] |
| 224.0.246.0-224.0.246.255 | MEMX Memoir | [Javier_Torres] | 2024-01-22 | Change Controller=[Members_Exchange-MEMX] |
| 224.0.247.0-224.0.247.255 | BOX Options Market | [Alexandre_Gomes] | 2024-02-27 | Change Controller=[BOX_TECHNOLOGY_CANADA_INC.] |
| 224.0.248.0-224.0.249.255 | MEMX Memoir | [Muhammad_Mazhar_Cheema] | 2025-12-03 | Change Controller=[Members_Exchange-MEMX] |
| 224.0.250.0-224.0.251.255 | KPN Broadcast Services | [Ad_C_Spelt][KPN_IP_Office] | 2009-09-01 | *(empty)* |
| 224.0.252.0-224.0.252.255 | KPN Broadcast Services | [Ad_C_Spelt][KPN_IP_Office] | 2005-08-01 | *(empty)* |
| 224.0.253.0-224.0.253.255 | KPN Broadcast Services | [Ad_C_Spelt][KPN_IP_Office] | 2005-08-01 | *(empty)* |
| 224.0.254.0-224.0.254.255 | Intelsat IPTV | [Karl_Elad] | 2006-03-31 | Last Reviewed=2011-02-22 |
| 224.0.255.0-224.0.255.255 | Intelsat IPTV | [Karl_Elad] | 2006-03-31 | Last Reviewed=2011-02-22 |

### 5e. RESERVED (224.1.0.0-224.1.255.255 (224.1/16))

CSV: `multicast-addresses-4.csv` — sub-registry Reference: `[RFC5771]` — 6 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.1.0.0-224.1.0.37 | Reserved | [RFC5771] | *(empty)* | *(empty)* |
| 224.1.0.38 | dantz | [Richard_Zulch] | 2004-05-01 | *(empty)* |
| 224.1.0.39-224.1.1.255 | Reserved | [RFC5771] | *(empty)* | *(empty)* |
| 224.1.2.0-224.1.2.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2006-02-17 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.1.3.0-224.1.4.255 | NOB Cross media facilities | [Technicolor_NL_NOC] | 2006-05-22 | *(empty)* |
| 224.1.5.0-224.1.255.255 | Reserved | [RFC5771] | *(empty)* | *(empty)* |

### 5f. SDP/SAP Block (224.2.0.0-224.2.255.255 (224.2/16))

CSV: `multicast-addresses-5.csv` — sub-registry Reference: `[RFC5771]` — 4 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.2.0.0-224.2.127.253 | Multimedia Conference Calls | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.2.127.254 | SAPv1 Announcements | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.2.127.255 | SAPv0 Announcements (deprecated) | [Steve_Casner] | *(empty)* | *(empty)* |
| 224.2.128.0-224.2.255.255 | SAP Dynamic Assignments | [Steve_Casner] | *(empty)* | *(empty)* |

### 5g. AD-HOC Block II (224.3.0.0-224.4.255.255 (224.3/16, 224.4/16))

CSV: `multicast-addresses-6.csv` — sub-registry Reference: `[RFC5771]` — 28 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.3.0.0-224.3.0.63 | Nasdaqmdfeeds  (re-new/March 2003) | [Michael_Rosenberg] | 1999-03-01 | Change Controller=[Nasdaq_Inc] |
| 224.3.0.64-224.3.255.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.4.0.0-224.4.0.255 | London Stock Exchange Group | [Andrew_Padley] | 2006-03-31 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.1.0-224.4.1.255 | London Stock Exchange Group | [Andrew_Padley] | 2008-02-25 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.2.0-224.4.2.255 | London Stock Exchange Group | [Andrew_Padley] | 2008-02-29 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.3.0-224.4.4.255 | London Stock Exchange Group | [Andrew_Padley] | 2008-12-24 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.5.0-224.4.6.255 | London Stock Exchange Group | [Andrew_Padley] | 2009-05-12 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.7.0-224.4.7.255 | CBOE Holdings | [Cboe_POC] | 2012-04-10 | Change Controller=[Cboe_Bats_LLC] |
| 224.4.8.0-224.4.9.255 | Nasdaq Inc. | [Michael_Rosenberg] | 2012-04-11 | Change Controller=[Nasdaq_Inc] |
| 224.4.10.0-224.4.13.255 | London Stock Exchange Group | [Andrew_Padley] | 2012-04-11 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.14.0-224.4.17.255 | London Stock Exchange Group | [Andrew_Padley] | 2018-01-04 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.18.0-224.4.21.255 | London Stock Exchange Group | [Andrew_Padley] | 2021-02-04 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.22.0-224.4.23.255 | London Stock Exchange Group | [Andrew_Padley] | 2021-09-21 | Change Controller=[London_Stock_Exchange_Group] |
| 224.4.24.0-224.4.31.255 | Fenics Market Data | [Steve_Loizou] | 2023-01-18 | Change Controller=[Cantor_Fitzgerald] |
| 224.4.32.0-224.4.33.255 | Global Futures & Options Ltd | [David_Beattie] | 2023-03-15 | Change Controller=[Global_Futures_and_Options_Limited] |
| 224.4.34.0-224.4.39.255 | MIAX-3 | [Gamini_Karunaratne] | 2023-05-24 | Change Controller=[MIAX] |
| 224.4.40.0-224.4.43.255 | Japan Exchange Group | [Japan_Exchange_Group_-_Osaka_Exchange_Inc.] | 2024-06-25 | Change Controller=[Japan_Exchange_Group_-_Osaka_Exchange_Inc.] |
| 224.4.44.0-224.4.47.255 | CME Group | [Anthony_Lopresti] | 2024-08-02 | Change Controller=[CME_Group] |
| 224.4.48.0-224.4.63.255 | Intercontinental Exchange, Inc. | [RIR_Admin] | 2023-04-10 | Change Controller=[Intercontinental_Exchange_Inc.] |
| 224.4.64.0-224.4.71.255 | CME Group | [Anthony_Lopresti] | 2024-08-06 | Change Controller=[CME_Group] |
| 224.4.72.0-224.4.79.255 | FMX Market Data | [Steve_Loizou] | 2025-02-25 | Change Controller=[BCG_Group] |
| 224.4.80.0-224.4.84.255 | CBOE Holdings | [Cboe_POC] | 2025-04-01 | Change Controller=[Cboe_Bats_LLC] |
| 224.4.85.0-224.4.85.255 | A5X - Market Data Feed | [Cleverson_Arashiro] | 2026-01-27 | Change Controller=[A5X] |
| 224.4.86.0-224.4.86.255 | EuroCTP BV | [Pico_Network_Engineering] | 2026-03-10 | Change Controller=[Pico] |
| 224.4.87.0-224.4.87.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 224.4.88.0-224.4.95.255 | CME Group | [Anthony_Lopresti] | 2025-12-03 | Change Controller=[CME_Group] |
| 224.4.96.0-224.4.103.255 | LUME_Markets | [Kevin_McNicholas] | 2026-06-26 | Change Controller=[Lucera_Financial_Infrastructures] |
| 224.4.104.0-224.4.255.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |

### 5h. RESERVED (224.5.0.0-224.251.255.255 (251 /16s))

CSV: `multicast-addresses-7.csv` — sub-registry Reference: `[RFC5771]` — 1 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.5.0.0-224.251.255.255 | Reserved | [RFC5771] | *(empty)* | *(empty)* |

### 5i. DIS Transient Groups 224.252.0.0-224.255.255.255 (224.252/14))

CSV: `multicast-addresses-8.csv` — sub-registry Reference: `[RFC2365]` — 1 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 224.252.0.0-224.255.255.255 | DIS Transient Groups | [IANA][RFC2365] | *(empty)* | *(empty)* |

### 5j. RESERVED (225.0.0.0-231.255.255.255 (7 /8s))

CSV: `multicast-addresses-9.csv` — sub-registry Reference: `[RFC5771]` — 1 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 225.0.0.0-231.255.255.255 | Reserved | [RFC5771] | *(empty)* | *(empty)* |

### 5k. Source-Specific Multicast Block (232.0.0.0-232.255.255.255 (232/8))

CSV: `multicast-addresses-10.csv` — sub-registry Reference: `[RFC5771]` — 3 records.
CSV header verbatim: `Relative,Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 232.0.0.0 | Reserved | [RFC4607] | *(empty)* | *(empty)* |
| 232.0.0.1-232.0.0.255 | Reserved for IANA allocation | [RFC4607] | *(empty)* | *(empty)* |
| 232.0.1.0-232.255.255.255 | Reserved for local host allocation | [RFC4607] | *(empty)* | *(empty)* |

### 5l. GLOP Block

CSV: `glop.csv` — sub-registry Reference: `[RFC3180]` — 1 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 233.0.0.0-233.251.255.255 | GLOP Block | [RFC3180] | *(empty)* | *(empty)* |

### 5m. AD-HOC Block III (233.252.0.0-233.255.255.255 (233.252/14))

CSV: `multicast-addresses-11.csv` — sub-registry Reference: `[RFC5771]` — 8 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 233.252.0.0-233.252.0.255 | MCAST-TEST-NET | [IANA][RFC5771][RFC6676] | 2010-01-20 | Last Reviewed=2010-01-20 |
| 233.252.1.0-233.252.1.255 | Pico | [Pico_Sales] | 2010-08-12 | Change Controller=[Pico] |
| 233.252.2.0-233.252.7.255 | Tradition | [Tradition_Network_Operations_and_Command_Center] | 2010-08-12 | *(empty)* |
| 233.252.8.0-233.252.11.255 | BVMF_MKT_DATA | [Roberto_Costa_Simoes] | 2010-08-12 | *(empty)* |
| 233.252.12.0-233.252.13.255 | blizznet-tv-services | [Paul_Wallner] | 2010-09-14 | *(empty)* |
| 233.252.14.0-233.252.17.255 | BVMF_MKT_DATA_2 | [Guilherme_Longanezi] | 2016-09-27 | *(empty)* |
| 233.252.18.0-233.252.18.255 | Pico | [Pico_Sales] | 2021-12-17 | Change Controller=[Pico] |
| 233.252.19.0-233.255.255.255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |

### 5n. Unicast-Prefix-based IPv4 Multicast Addresses

CSV: `unicast-prefix-based.csv` — sub-registry Reference: `[RFC6034]` — 1 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 234.0.0.0-234.255.255.255 | Unicast-Prefix-based IPv4 Multicast Addresses | [RFC6034] | 2010-08-11 | *(empty)* |

### 5o. Scoped Multicast Ranges

CSV: `multicast-addresses-12.csv` — sub-registry Reference: `[RFC5771]` — 2 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 235.0.0.0-238.255.255.255 | Reserved | [RFC5771] | *(empty)* | *(empty)* |
| 239.0.0.0-239.255.255.255 | Organization-Local Scope | [David_Meyer][RFC2365] | 1997-01-01 | *(empty)* |

### 5p. Relative Addresses used with Scoped Multicast Addresses

CSV: `multicast-addresses-13.csv` — sub-registry Reference: `[RFC5771]` — 15 records.
CSV header verbatim: `Address(es),Description,References,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 0 | SAP Session Announcement Protocol | [Mark_Handley] | 1998-12-01 | *(empty)* |
| 1 | MADCAP Protocol | [RFC2730] | *(empty)* | *(empty)* |
| 2 | SLPv2 Discovery | [Erik_Guttman] | 2001-12-01 | *(empty)* |
| 3 | MZAP | [Dave_Thaler] | 2000-06-01 | *(empty)* |
| 4 | Multicast Discovery of DNS Services | [Bill_Manning] | 1999-08-01 | *(empty)* |
| 5 | SSDP | [UPnP_Forum] | 2006-06-27 | *(empty)* |
| 6 | DHCP v4 | [Eric_Hall] | 1999-10-01 | *(empty)* |
| 7 | AAP | [Stephen_Hanna] | 2000-07-01 | *(empty)* |
| 8 | MBUS | [RFC3259] | *(empty)* | *(empty)* |
| 9 | UPnP | [UPnP_Forum] | 2006-06-27 | *(empty)* |
| 10 | MCAST-TEST-NET-2 | [RFC6676] | *(empty)* | *(empty)* |
| 11-252 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| 253 | Reserved | *(empty)* | *(empty)* | *(empty)* |
| 254 | RFC3692-style Experiment (*) | [RFC4727] | *(empty)* | *(empty)* |
| 255 | Unassigned | *(empty)* | *(empty)* | *(empty)* |

## 6. IPv6 Multicast Address Space Registry

URL: <https://www.iana.org/assignments/ipv6-multicast-addresses/ipv6-multicast-addresses.xhtml>

Registry-level note, verbatim from the page:
> IPv6 multicast addresses are defined in "IP Version 6 Addressing Architecture" [RFC4291]. This
> defines fixed scope and variable scope multicast addresses. IPv6 multicast addresses are
> distinguished from unicast addresses by the value of the high-order octet of the addresses:
> a value of 0xFF (binary 11111111) identifies an address as a multicast address; any other value
> identifies an address as a unicast address. The rules for assigning new IPv6 multicast addresses
> are defined in [RFC3307]. **IPv6 multicast addresses not listed below are reserved.**
> Formerly known as IPv6 Multicast Address Space Registry

Six sub-registries plus the scope registry. Addresses are written in **fully expanded, uppercase,
non-RFC-5952 form** (`FF01:0:0:0:0:0:0:1`, not `ff01::1`) — except where a CIDR appears
(`FF02:0:0:0:0:1:FF00::/104`, `FF0X:0:0:0:0:DB8::/96`), which mixes two notations inside one column.

### 6a. IPv6 Multicast Address Scopes

CSV: <https://www.iana.org/assignments/ipv6-multicast-addresses/ipv6-scope.csv>
Registration procedure: IETF Review. Reference: [RFC7346]. 11 records.
Registry note, verbatim:
> The definition of any Realm-Local scope for a particular network technology should be published
> in an RFC. For example, such a scope definition would be appropriate for publication in an
> 'IPv6-over-foo' RFC. Any RFCs that define a Realm-Local scope will be listed in this registry as
> an additional reference in the Realm-Local scope entry. Such RFCs are expected to make an
> explicit request to IANA for inclusion in this registry.

The `Scope` column is a **4-bit hexadecimal nibble written as a bare character or range**
(`0`, `6-7`, `9-D`, `E`, `F`) — uppercase hex letters, ranges joined by a hyphen. It is not an
address and not a decimal integer.

| Scope | Name | Reference |
|---|---|---|
| 0 | Reserved | [RFC4291][RFC7346] |
| 1 | Interface-Local scope | [RFC4291][RFC7346] |
| 2 | Link-Local scope | [RFC4291][RFC7346] |
| 3 | Realm-Local scope | [RFC4291][RFC7346] |
| 4 | Admin-Local scope | [RFC4291][RFC7346] |
| 5 | Site-Local scope | [RFC4291][RFC7346] |
| 6-7 | Unassigned | *(empty)* |
| 8 | Organization-Local scope | [RFC4291][RFC7346] |
| 9-D | Unassigned | *(empty)* |
| E | Global scope | [RFC4291][RFC7346] |
| F | Reserved | [RFC4291][RFC7346] |

Mapped onto the requested schema (the scope nibble is the second nibble of the address, so scope
`N` corresponds to the prefix `ffN0::/12`):

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| `ff*0::/16` (scope nibble = `0`) | Reserved | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*1::/16` (scope nibble = `1`) | Interface-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*2::/16` (scope nibble = `2`) | Link-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*3::/16` (scope nibble = `3`) | Realm-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*4::/16` (scope nibble = `4`) | Admin-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*5::/16` (scope nibble = `5`) | Site-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*6-7::/16` (scope nibble = `6-7`) | Unassigned | *(empty)* | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*8::/16` (scope nibble = `8`) | Organization-Local scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*9-D::/16` (scope nibble = `9-D`) | Unassigned | *(empty)* | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*E::/16` (scope nibble = `E`) | Global scope | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |
| `ff*F::/16` (scope nibble = `F`) | Reserved | [RFC4291][RFC7346] | — | The scope nibble is the LOW nibble of the second octet; the HIGH nibble is ff1/flgs. A scope therefore does NOT correspond to a single CIDR prefix: scope 2 covers ff02::/16, ff12::/16, ff32::/16, ff72::/16, ... one /16 per flag value. |

**RFC 4291 §2.7 and this registry disagree.** RFC 4291 lists scope `3` as `reserved` and scopes
`6`, `7`, `9`, `A`, `B`, `C`, `D` as `(unassigned)` available for administrators to define
additional regions. RFC 7346 reassigned `3` to `Realm-Local scope`, and this registry reflects
RFC 7346. Anything citing only RFC 4291 for scope 3 is stale.

### 6b. Node-Local Scope Multicast Addresses

CSV: `node-local.csv` — Registration Procedure: Expert Review. Reference: [RFC4291][RFC3307]. — 21 records.
CSV header verbatim: `Address(es),Description,Reference,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| FF01:0:0:0:0:0:0:1 | All Nodes Address | [RFC4291] | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:2 | All Routers Address | [RFC4291] | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:C | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:FA | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:FB | mDNSv6 | [RFC6762] | 2005-10-05 | *(empty)* |
| FF01:0:0:0:0:0:0:FC-FF01:0:0:0:0:0:0:FD | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:100-FF01:0:0:0:0:0:0:178 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:181-FF01:0:0:0:0:0:0:184 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:18C | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:201-FF01:0:0:0:0:0:0:202 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:204-FF01:0:0:0:0:0:0:206 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:2C0-FF01:0:0:0:0:0:0:2FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:300 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:400-FF01:0:0:0:0:0:0:4FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:3486 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:6496-FF01:0:0:0:0:0:0:64B5 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:0:BAC0 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:1:1000/118 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:2:0-FF01:0:0:0:0:0:4:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:0:B:0-FF01:0:0:0:0:0:B:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF01:0:0:0:0:DB8::/96 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |

### 6c. Link-Local Scope Multicast Addresses

CSV: `link-local.csv` — Registration Procedure: Expert Review. Reference: [RFC4291][RFC3307]. — 56 records.
CSV header verbatim: `Address(es),Description,Reference,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| FF02:0:0:0:0:0:0:1 | All Nodes Address | [RFC4291] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:2 | All Routers Address | [RFC4291] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:3 | Unassigned | [Jon_Postel] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:4 | DVMRP Routers | [RFC1075][Jon_Postel] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:5 | OSPFIGP | [RFC2328][John_Moy] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:6 | OSPFIGP Designated Routers | [RFC2328][John_Moy] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:7 | ST Routers | [RFC1190][\<mystery contact>] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:8 | ST Hosts | [RFC1190][\<mystery contact>] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:9 | RIP Routers | [RFC2080] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:A | EIGRP Routers | [RFC7868] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:B | Mobile-Agents | [Bill_Simpson] | 1994-11-01 | *(empty)* |
| FF02:0:0:0:0:0:0:C | SSDP | [UPnP_Forum] | 2006-09-21 | *(empty)* |
| FF02:0:0:0:0:0:0:D | All PIM Routers | [Dino_Farinacci] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:E | RSVP-ENCAPSULATION | [Bob_Braden] | 1996-04-01 | *(empty)* |
| FF02:0:0:0:0:0:0:F | UPnP | [UPnP_Forum] | 2006-09-21 | *(empty)* |
| FF02:0:0:0:0:0:0:10 | All-BBF-Access-Nodes | [RFC6788] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:11 | All-Homenet-Nodes | [RFC7788] | 2016-01-05 | *(empty)* |
| FF02:0:0:0:0:0:0:12 | VRRP | [RFC9568] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:13 | ALL_GRASP_NEIGHBORS | [RFC8990] | 2017-07-20 | *(empty)* |
| FF02:0:0:0:0:0:0:14 | Network Virtualization Overlay (NVO) BUM Traffic | [RFC9624] | 2024-02-02 | *(empty)* |
| FF02:0:0:0:0:0:0:16 | All MLDv2-capable routers | [RFC9777] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:1A | all-RPL-nodes | [RFC6550] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:6A | All-Snoopers | [RFC4286] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:6B | PTP-pdelay | [http://ieee1588.nist.gov/][Kang_Lee] | 2007-02-02 | *(empty)* |
| FF02:0:0:0:0:0:0:6C | Saratoga | [Lloyd_Wood] | 2007-08-30 | *(empty)* |
| FF02:0:0:0:0:0:0:6D | LL-MANET-Routers | [RFC5498] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:6E | IGRS | [Xiaoyu_Zhou] | 2009-01-20 | *(empty)* |
| FF02:0:0:0:0:0:0:6F | iADT Discovery | [Paul_Suhler] | 2009-05-12 | *(empty)* |
| FF02:0:0:0:0:0:0:FA | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:FB | mDNSv6 | [RFC6762] | 2005-10-05 | *(empty)* |
| FF02:0:0:0:0:0:0:FC-FF02:0:0:0:0:0:0:FD | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:100-FF02:0:0:0:0:0:0:178 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:181-FF02:0:0:0:0:0:0:184 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:18C | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:201-FF02:0:0:0:0:0:0:202 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:204-FF02:0:0:0:0:0:0:206 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:2C0-FF02:0:0:0:0:0:0:2FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:300 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:400-FF02:0:0:0:0:0:0:4FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:3486 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:6496-FF02:0:0:0:0:0:0:64B5 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:0:A1F7 | ALL_V6_RIFT_ROUTERS | [RFC9692] | 2023-02-17 | *(empty)* |
| FF02:0:0:0:0:0:0:BAC0 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:1:1 | Link Name | [Dan_Harrington] | 1996-07-01 | *(empty)* |
| FF02:0:0:0:0:0:1:2 | All_DHCP_Relay_Agents_and_Servers | [RFC9915] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:1:3 | Link-local Multicast Name Resolution | [RFC4795] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:1:4 | DTCP Announcement | [Moritz_Vieth][Hanno_Tersteegen] | 2004-05-01 | *(empty)* |
| FF02:0:0:0:0:0:1:5 | afore_vdp | [Michael_Richardson] | 2010-11-30 | *(empty)* |
| FF02:0:0:0:0:0:1:6 | Babel | [RFC8966] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:1:7 | DLEP Discovery | [RFC8175] | 2017-04-03 | *(empty)* |
| FF02:0:0:0:0:0:1:1000/118 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:2:0-FF02:0:0:0:0:0:4:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:0:B:0-FF02:0:0:0:0:0:B:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF02:0:0:0:0:1:FF00::/104 | Solicited-Node Address | [RFC4291] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:2:FF00::/104 | Node Information Queries | [RFC4620] | *(empty)* | *(empty)* |
| FF02:0:0:0:0:DB8::/96 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |

### 6d. Site-Local Scope Multicast Addresses

CSV: `site-local.csv` — Registration Procedure: Expert Review. Reference: [RFC4291][RFC3307]. — 23 records.
CSV header verbatim: `Address(es),Description,Reference,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| FF05:0:0:0:0:0:0:2 | All Routers Address | [RFC4291] | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:C | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:FA | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:FB | mDNSv6 | [RFC6762] | 2005-10-05 | *(empty)* |
| FF05:0:0:0:0:0:0:FC-FF05:0:0:0:0:0:0:FD | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:100-FF05:0:0:0:0:0:0:178 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:181-FF05:0:0:0:0:0:0:184 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:18C | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:201-FF05:0:0:0:0:0:0:202 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:204-FF05:0:0:0:0:0:0:206 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:2C0-FF05:0:0:0:0:0:0:2FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:300 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:400-FF05:0:0:0:0:0:0:4FF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:3486 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:6496-FF05:0:0:0:0:0:0:64B5 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:0:BAC0 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:1:3 | All_DHCP_Servers | [RFC9915] | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:1:4 | Deprecated (2003-03-12) | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:1:5 | SL-MANET-ROUTERS | [RFC6621] | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:1:1000/118 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:2:0-FF05:0:0:0:0:0:4:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:0:B:0-FF05:0:0:0:0:0:B:FFFF | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |
| FF05:0:0:0:0:DB8::/96 | variable scope allocation | *(empty)* | *(empty)* | *(empty)* |

### 6e. Variable Scope Multicast Addresses

CSV: `variable.csv` — Registration Procedure: Expert Review. Reference: [RFC4291][RFC3307]. — 132 records.
CSV header verbatim: `Address(es),Description,Reference,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| FF0X:0:0:0:0:0:0:0 | Reserved Multicast Address | [RFC4291] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:C | SSDP | [UPnP_Forum] | 2006-09-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:FA | Matter | [Martin_Turon] | 2025-10-10 | Change Controller=[Connectivity_Standards_Alliance] |
| FF0X:0:0:0:0:0:0:FB | mDNSv6 | [RFC6762] | 2005-10-05 | *(empty)* |
| FF0X:0:0:0:0:0:0:FC | ALL_MPL_FORWARDERS | [RFC7731] | 2013-04-10 | *(empty)* |
| FF0X:0:0:0:0:0:0:FD | All CoAP Nodes | [RFC7252] | 2013-07-25 | *(empty)* |
| FF0X:0:0:0:0:0:0:FE | All CoRE Resource Directories | [RFC9176] | 2021-03-16 | *(empty)* |
| FF0X:0:0:0:0:0:0:FF | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:100 | VMTP Managers Group | [RFC1045][Dave_Cheriton] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:101 | Network Time Protocol (NTP) | [RFC5905][David_Mills] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:102 | SGI-Dogfight | [Andrew_Cherenson] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:103 | Rwhod | [Steve_Deering] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:104 | VNP | [Dave_Cheriton] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:105 | Artificial Horizons - Aviator | [Bruce_Factor] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:106 | NSS - Name Service Server | [Bill_Schilit] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:107 | AUDIONEWS - Audio News Multicast | [Martin_Forssen] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:108 | SUN NIS+ Information Service | [Chuck_McManis] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:109 | MTP Multicast Transport Protocol | [Susie_Armstrong] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10A | IETF-1-LOW-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10B | IETF-1-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10C | IETF-1-VIDEO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10D | IETF-2-LOW-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10E | IETF-2-AUDIO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:10F | IETF-2-VIDEO | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:110 | MUSIC-SERVICE | [[Guido van Rossum]] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:111 | SEANET-TELEMETRY | [[Andrew Maffei]] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:112 | SEANET-IMAGE | [[Andrew Maffei]] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:113 | MLOADD | [Bob_Braden] | 1996-04-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:114 | any private experiment | [Jon_Postel] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:115 | DVMRP on MOSPF | [John_Moy] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:116 | SVRLOC | [Erik_Guttman] | 2001-05-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:117 | XINGTV | [\<hgxing&aol.com>] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:118 | microsoft-ds | [Arnold_M] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:119 | pro | [Bloomer] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:11A | pfn | [Bloomer] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:11B | lmsc-calren-1 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:11C | lmsc-calren-2 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:11D | lmsc-calren-3 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:11E | lmsc-calren-4 | [Yea_Uang] | 1994-11-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:11F | ampr-info | [Rob_Janssen] | 1995-01-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:120 | mtrace | [Steve_Casner] | 1995-01-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:121 | RSVP-encap-1 | [Bob_Braden] | 1996-04-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:122 | RSVP-encap-2 | [Bob_Braden] | 1996-04-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:123 | SVRLOC-DA | [Erik_Guttman] | 2001-05-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:124 | rln-server | [Brian_Kean] | 1995-08-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:125 | proshare-mc | [Mark_Lewis] | 1995-10-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:126 | dantz | [Dotty_Yackle] | 1996-02-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:127 | cisco-rp-announce | [Dino_Farinacci] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:128 | cisco-rp-discovery | [Dino_Farinacci] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:129 | gatekeeper | [Jim_Toga] | 1996-05-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:12A | iberiagames | [Jose_Luis_Marocho] | 1996-07-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:12B | X Display | [John_McKernan] | 2003-05-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:12C | dof-multicast | [Bryant_Eastham] | 2005-04-01 | Last Reviewed=2015-04-23 |
| FF0X:0:0:0:0:0:0:12D | DvbServDisc | [Bert_van_Willigen] | 2005-09-16 | *(empty)* |
| FF0X:0:0:0:0:0:0:12E | Ricoh-device-ctrl | [Kohki_Ohhira] | 2006-06-20 | *(empty)* |
| FF0X:0:0:0:0:0:0:12F | Ricoh-device-ctrl | [Kohki_Ohhira] | 2006-06-20 | *(empty)* |
| FF0X:0:0:0:0:0:0:130 | UPnP | [UPnP_Forum] | 2006-09-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:131 | Systech Mcast | [Dan_Jakubiec] | 2006-09-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:132 | omasg | [Mark_Lipford] | 2006-09-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:133 | ASAP | [RFC5352] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:134 | unserding | [Sebastian_Freundt] | 2009-11-30 | *(empty)* |
| FF0X:0:0:0:0:0:0:135 | PHILIPS-HEALTH | [Mike_King][William_Holden] | 2010-02-26 | Change Controller=[Philips_Healthcare] |
| FF0X:0:0:0:0:0:0:136 | PHILIPS-HEALTH | [Mike_King][William_Holden] | 2010-02-26 | Change Controller=[Philips_Healthcare] |
| FF0X:0:0:0:0:0:0:137 | Niagara | [Owen_Michael_James] | 2010-09-13 | *(empty)* |
| FF0X:0:0:0:0:0:0:138 | LXI-EVENT | [Tom_Fay] | 2011-01-31 | *(empty)* |
| FF0X:0:0:0:0:0:0:139 | LANCOM Discover | [Martin_Krebs] | 2011-05-09 | *(empty)* |
| FF0X:0:0:0:0:0:0:13A | AllJoyn | [Craig_Dowell] | 2011-11-18 | *(empty)* |
| FF0X:0:0:0:0:0:0:13B | GNUnet | [Christian_Grothoff] | 2011-11-22 | *(empty)* |
| FF0X:0:0:0:0:0:0:13C | fos4Xdevices | [Rolf_Wojtech] | 2011-12-07 | *(empty)* |
| FF0X:0:0:0:0:0:0:13D | USNAMES-NET-MC | [Christopher_Mettin] | 2013-01-24 | *(empty)* |
| FF0X:0:0:0:0:0:0:13E | hp-msm-discover | [John_Flick] | 2013-02-28 | *(empty)* |
| FF0X:0:0:0:0:0:0:13F | SANYO DENKI CO., LTD. | [Yuuki_Hara] | 2014-03-20 | *(empty)* |
| FF0X:0:0:0:0:0:0:140-FF0X:0:0:0:0:0:0:14F | EPSON-disc-set | [Seiko_Epson_Corp] | 2010-02-26 | *(empty)* |
| FF0X:0:0:0:0:0:0:150 | an-adj-disc | [Toerless_Eckert] | 2014-06-04 | *(empty)* |
| FF0X:0:0:0:0:0:0:151 | Canon-Device-control | [Hiroshi_Okubo] | 2014-08-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:152 | TinyMessage | [Josip_Medved] | 2014-12-09 | *(empty)* |
| FF0X:0:0:0:0:0:0:153 | ZigBee NAN DS | [Yusuke_Doi] | 2015-08-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:154 | ZigBee NAN DI | [Yusuke_Doi] | 2015-08-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:155 | jini-announcement | [Jini Discovery and Join Specification][Peter_Grahame_Firmstone] | 2015-08-27 | *(empty)* |
| FF0X:0:0:0:0:0:0:156 | jini-request | [Jini Discovery and Join Specification][Peter_Grahame_Firmstone] | 2015-08-27 | *(empty)* |
| FF0X:0:0:0:0:0:0:157 | hbmdevices | [Stephan_Gatzka] | 2015-10-26 | *(empty)* |
| FF0X:0:0:0:0:0:0:158 | All OCF Nodes | [Stephane_Lejeune] | 2016-07-07 | *(empty)* |
| FF0X:0:0:0:0:0:0:159 | Crestron Autodiscover & Config | [Toine_C._Leerentveld] | 2016-09-27 | *(empty)* |
| FF0X:0:0:0:0:0:0:15A | MAAS | [Mike_Pontillo] | 2017-05-19 | *(empty)* |
| FF0X:0:0:0:0:0:0:15B | SwapAppMulticast | [Applykane] | 2017-05-26 | *(empty)* |
| FF0X:0:0:0:0:0:0:15C | Gluon mesh VXLAN | [Matthias_Schiffer] | 2017-06-27 | *(empty)* |
| FF0X:0:0:0:0:0:0:15D | All-FHCD-Nodes | [Johan_Peeters] | 2018-05-01 | *(empty)* |
| FF0X:0:0:0:0:0:0:15E | CNP-HD-PLC | [Ernst_EDER] | 2018-11-15 | Change Controller=[LonMark_International] |
| FF0X:0:0:0:0:0:0:15F | UFMP | [Shachar_Dor] | 2019-06-25 | Change Controller=[Mellanox] |
| FF0X:0:0:0:0:0:0:160-FF0X:0:0:0:0:0:0:16F | NMEA OneNet | [Steve_Spitzer] | 2015-06-29 | *(empty)* |
| FF0X:0:0:0:0:0:0:170 | Nix Local Binary Caches | [Andreas_Rammhold] | 2019-10-02 | *(empty)* |
| FF0X:0:0:0:0:0:0:171 | GNodes | [Giuseppe_Gori] | 2021-02-12 | *(empty)* |
| FF0X:0:0:0:0:0:0:172 | SentryPeer | [Gavin_Henry] | 2022-01-26 | *(empty)* |
| FF0X:0:0:0:0:0:0:173 | EggShell | [Momar_Mbergan] | 2022-02-17 | Change Controller=[Momar_Mbergan] |
| FF0X:0:0:0:0:0:0:174 | IoT42 | [Stephen_Williams] | 2022-05-06 | Change Controller=[Stephen_Williams] |
| FF0X:0:0:0:0:0:0:175 | all SIP servers | [Rick_van_Rein] | 2015-07-21 | *(empty)* |
| FF0X:0:0:0:0:0:0:176 | HDHomeRun Discovery | [Nick_Kelsey] | 2022-10-04 | Change Controller=[Silicondust_USA_Inc.] |
| FF0X:0:0:0:0:0:0:177 | 3GPP MBMS SACH | [Charles_Lo] | 2022-10-31 | Change Controller=[_3GPP] |
| FF0X:0:0:0:0:0:0:178 | IFD Service | [Amendment TR-03112-6][AusweisApp] | 2025-05-30 | Change Controller=[Federal_Office_for_Information_Security] |
| FF0X:0:0:0:0:0:0:179-FF0X:0:0:0:0:0:0:180 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:181 | PTP-primary | [http://ieee1588.nist.gov/][Kang_Lee] | 2007-02-02 | *(empty)* |
| FF0X:0:0:0:0:0:0:182 | PTP-alternate1 | [http://ieee1588.nist.gov/][Kang_Lee] | 2007-02-02 | *(empty)* |
| FF0X:0:0:0:0:0:0:183 | PTP-alternate2 | [http://ieee1588.nist.gov/][Kang_Lee] | 2007-02-02 | *(empty)* |
| FF0X:0:0:0:0:0:0:184 | PTP-alternate3 | [http://ieee1588.nist.gov/][Kang_Lee] | 2007-02-02 | *(empty)* |
| FF0X:0:0:0:0:0:0:185-FF0X:0:0:0:0:0:0:18B | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:18C | All ACs multicast address | [RFC5415] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:18D-FF0X:0:0:0:0:0:0:200 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:201 | "rwho" Group (BSD) (unofficial) | [Jon_Postel] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:202 | SUN RPC PMAPPROC_CALLIT | [Brendan_Eic] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:204 | All C1222 Nodes | [RFC6142] | 2009-08-28 | *(empty)* |
| FF0X:0:0:0:0:0:0:205 | Hexabus | [Mathias_Dalheimer] | 2013-08-09 | *(empty)* |
| FF0X:0:0:0:0:0:0:206 | multicast chat | [Patrik_Lahti] | 2013-08-13 | *(empty)* |
| FF0X:0:0:0:0:0:0:207-FF0X:0:0:0:0:0:0:2BF | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:2C0-FF0X:0:0:0:0:0:0:2FF | Garmin Marine | [Nathan_Karstens] | 2015-02-19 | *(empty)* |
| FF0X:0:0:0:0:0:0:300 | Mbus/Ipv6 | [RFC3259] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:301-FF0X:0:0:0:0:0:0:3FF | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:400 | Cell Broadcast Encapsulation | [Meridian_Labs_LTD][LIRNEasia] | 2020-10-07 | Change Controller=[Meridian_Labs_LTD]<br>[LIRNEasia] |
| FF0X:0:0:0:0:0:0:401-FF0X:0:0:0:0:0:0:4FF | Civic Telemetry | [Meridian_Labs_LTD][LIRNEasia] | 2020-10-07 | Change Controller=[Meridian_Labs_LTD]<br>[LIRNEasia] |
| FF0X:0:0:0:0:0:0:500-FF0X:0:0:0:0:0:0:3485 | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:3486 | IFSF Heartbeat | [John_Carrier] | 2015-06-15 | *(empty)* |
| FF0X:0:0:0:0:0:0:3487-FF0X:0:0:0:0:0:0:BABF | Unassigned | *(empty)* | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:0:BAC0 | BACnet | [Coleman_Brumley] | 2010-11-22 | *(empty)* |
| FF0X:0:0:0:0:0:0:6496-FF0X:0:0:0:0:0:0:64B5 | ISO 25750 Secured Ship Network | [Yung_Ho_Yu] | 2026-04-07 | Change Controller=[ISO-TC_8_SC26] |
| FF0X:0:0:0:0:0:1:1000/118 | Service Location, Version 2 | [RFC3111] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:2:0000-FF0X:0:0:0:0:0:2:7FFD | Multimedia Conference Calls | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:2:7FFE | SAPv1 Announcements | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:2:7FFF | SAPv0 Announcements (deprecated) | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:2:8000-FF0X:0:0:0:0:0:2:FFFF | SAP Dynamic Assignments | [Steve_Casner] | *(empty)* | *(empty)* |
| FF0X:0:0:0:0:0:3:0-FF0X:0:0:0:0:0:3:FFFF | DALI | [Scott_Wade] | 2021-03-12 | Change Controller=[DALI_Alliance_DiiA] |
| FF0X:0:0:0:0:0:4:0-FF0X:0:0:0:0:0:4:FFFF | KNX IPv6 Multicast Addr. Range | [Joost_Demarest] | 2023-08-21 | Change Controller=[KNX_Association] |
| FF0X:0:0:0:0:0:B:0-FF0X:0:0:0:0:0:B:FFFF | Bitcoin SV Node Groups | [Jake_Jones] | 2023-04-19 | Change Controller=[Bitcoin_Association_for_Bitcoin_SV] |
| FF0X:0:0:0:0:DB8::/96 | Documentation Addresses | [RFC6676] | *(empty)* | *(empty)* |

### 6f. Unicast-based (Including SSM) Multicast Group IDs

CSV: `unicast-multicast-group-ids.csv` — Reference: [RFC4607]. — 3 records.
CSV header verbatim: `Address(es),Description,Reference,Change Controller,Date Registered,Last Reviewed`

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| FF3X:0:0:0:0:0:0:0-FF3X:0:0:0:0:0:3FFF:FFFF | Invalid addresses | [RFC4607] | *(empty)* | *(empty)* |
| FF3X:0:0:0:0:0:4000:0-FF3X:0:0:0:0:0:7FFF:FFFF | Reserved for IANA allocation; see [https://www.iana.org/assignments/perm-mcast-groupids] | [RFC4607] | *(empty)* | *(empty)* |
| FF3X:0:0:0:0:0:8000:0-FF3X:0:0:0:0:0:FFFF:FFFF | This range uses dynamic assignment according to the protocols listed in the [Dynamic Multicast Group IDs] registry | [RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13] | 2026-03-19 | *(empty)* |

The `FF0X:...` entries in 6e are **templates, not addresses**: the literal character `X` stands
for any scope nibble. `FF0X:0:0:0:0:0:0:FB` means "mDNSv6 at every scope", i.e. ff01::fb, ff02::fb,
… ff0f::fb. No IP parser will accept the string as written.

The Node-Local, Link-Local and Site-Local tables (6b/6c/6d) contain rows whose Description is the
literal string `variable scope allocation` with **no Reference, no Change Controller, no dates**.
Those are shadow entries pointing back at the corresponding `FF0X` row in 6e; they are not
independent assignments and carry no RFC of their own.

### 6g. Dynamic Multicast Group IDs

CSV: <https://www.iana.org/assignments/ipv6-multicast-addresses/dynamic-multicast-group-ids.csv>

CSV header verbatim: `Range,Description,Reference` — 6 records.

| Range | Description | Reference |
|---|---|---|
| 0x80000000-0x8FFFFFFF | MADCAP | Defined in [RFC2730], range assigned in [RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13] |
| 0x90000000-0xEFFFFFFF | Unassigned | *(empty)* |
| 0xF0000000-0xFCFFFFFF | Host allocation of SSM group addresses | [RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13] |
| 0xFD000000-0xFDFFFFFF | Reserved for Private Use | [RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13] |
| 0xFE000000-0xFEFFFFFF | Reserved for Experimental Use | [RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13] |
| 0xFF000000-0xFFFFFFFF | Solicited-Node multicast addresses | [RFC4291, Section 2.7.1] |

This sub-registry's first column is a **32-bit group-ID range in `0x`-prefixed hexadecimal**,
not an address and not a prefix. Two of its references are to
`[RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13]` — an **Internet-Draft in the RFC Editor queue,
not an RFC**. Any RFC-number extraction will produce garbage or nothing for those rows. Sub-registry
6f cites the same draft.

### 6h. IPv6 multicast flag bits (`flgs` / `ff1`, and `ff2`)

IANA does **not** maintain a registry of the multicast flag bits; they are defined only in RFCs.
This section is transcribed from the RFCs, not from IANA.

From RFC 4291 §2.7 (`https://www.rfc-editor.org/rfc/rfc4291.txt`), verbatim:

```
   |   8    |  4 |  4 |                  112 bits                   |
   +------ -+----+----+---------------------------------------------+
   |11111111|flgs|scop|                  group ID                   |
   +--------+----+----+---------------------------------------------+

                                    +-+-+-+-+
      flgs is a set of 4 flags:     |0|R|P|T|
                                    +-+-+-+-+
```

| bit (within `flgs`) | name | meaning | defining RFC |
|---|---|---|---|
| high-order (bit 9 of the address) | reserved / `X` | "The high-order flag is reserved, and must be initialized to 0." RFC 3956 later calls it `X` when discussing embedded-RP. | RFC 4291 |
| 2nd | `R` | Rendezvous Point embedded in the address (Embedded-RP). `R=1` implies `P=1` and `T=1`. | RFC 3956 |
| 3rd | `P` | Address is unicast-prefix-based. `P=1` implies `T=1`. | RFC 3306 |
| 4th (low-order) | `T` | `T=0` = permanently-assigned ("well-known") address assigned by IANA; `T=1` = non-permanently-assigned ("transient"/dynamically assigned). | RFC 4291 |

RFC 7371 (`https://www.rfc-editor.org/rfc/rfc7371.txt`) updates RFC 4291, RFC 3306 and RFC 3956:

> Bits 17-20 of a multicast address, where bit 1 is the most significant bit, are defined in
> [RFC3956] and [RFC3306] as reserved bits. This document defines these bits as generic flag bits
> so that they apply to any multicast address. These bits are referred to as "ff2" (flag field 2),
> while the "flgs" bits in [RFC4291] [RFC3956] are renamed to "ff1" (flag field 1).

So after RFC 7371 the correct names are **ff1** (the 4 bits at offset 8, the old `flgs`) and
**ff2** (bits 17–20, previously the "reserved" field of RFC 3306/3956 unicast-prefix-based
addresses, now generic flags on **every** multicast address). RFC 7371 §3 also warns:

> Some implementations and specification documents do not treat the flag bits as separate bits but
> tend to use their combined value as a 4-bit integer. This practice is a hurdle for assigning a
> meaning to the remaining flag bits.

Common `ff1` values seen in the wild:

| `ff1` (binary) | prefix form | meaning | RFC |
|---|---|---|---|
| `0000` | `ff0X::/16` | permanent, well-known, IANA-assigned | RFC 4291 |
| `0001` | `ff1X::/16` | transient / dynamically assigned | RFC 4291 |
| `0011` | `ff3X::/16` | unicast-prefix-based (`P=1`, `T=1`) — includes SSM `ff3X::/32` | RFC 3306 |
| `0111` | `ff7X::/16` | Embedded-RP (`R=1`, `P=1`, `T=1`) | RFC 3956, RFC 7371 §4.2 |

## 7. IANA IPv6 Global Unicast Address Assignments

URL: <https://www.iana.org/assignments/ipv6-unicast-address-assignments/ipv6-unicast-address-assignments.xhtml>
CSV: <https://www.iana.org/assignments/ipv6-unicast-address-assignments/ipv6-unicast-address-assignments.csv>

**51 records.** CSV header verbatim: `Prefix,Designation,Date,WHOIS,RDAP,Status,Note`.

Scope: this registry covers **only `2000::/3`**, per the IPv6 Address Space registry note ("IANA
unicast address assignments are currently limited to the IPv6 unicast address range of 2000::/3").
It is **not a partition of 2000::/3**: 61 distinct sub-ranges inside `2000::/3` appear in no row at
all (the largest being `2000::/16`, `2100::/8`, `2200::/7`, `2500::/8`, `2004::/14`, `2008::/13`,
`2010::/12`, `2020::/11`, `2040::/10`, `2080::/9`, `2420::/11`, `2440::/10`, `2480::/9`).
Absence means unallocated, not "not IPv6".

Dates here are **full ISO dates** (`1999-07-01`), unlike the IPv4 Address Space registry
(`1981-09`, year-month only) and unlike the special-purpose registries (`2010-01`, year-month
only) — with one exception: `3ffe::/16` carries `2008-04`, a year-month value in an otherwise
full-date column.

| prefix | name | RFC(s) | date | notes |
|---|---|---|---|---|
| 2001::/23 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=ALLOCATED; WHOIS=whois.iana.org; Note=This range has been partially allocated. See [IPv6 Special-Purpose Address Space] for details. |
| 2001:200::/23 | APNIC | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2001:400::/23 | ARIN | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2001:600::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:800::/22 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2002-11-02 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/; Note=2001:800::/23 was allocated on 2002-05-02. The more recent allocation (2002-11-02) incorporates the previous allocation. |
| 2001:c00::/23 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2002-05-02 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/; Note=2001:db8::/32 is reserved for Documentation [RFC3849]. See [IPv6 Special-Purpose Address Space] for details. |
| 2001:e00::/23 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2003-01-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2001:1200::/23 | LACNIC | (no RFC column; RFCs appear only inside Note text) | 2002-11-01 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/ |
| 2001:1400::/22 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2003-07-01 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/; Note=2001:1400::/23 was allocated on 2003-02-01. The more recent allocation (2003-07-01) incorporates the previous allocation. |
| 2001:1800::/23 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2003-04-01 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2001:1a00::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-01-01 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:1c00::/22 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-05-04 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:2000::/19 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2019-03-12 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/; Note=2001:2000::/20, 2001:3000::/21, and 2001:3800::/22 were allocated on 2004-05-04. The more recent allocation (2019-03-12) incorporates all these previous allocations. |
| 2001:4000::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-06-11 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:4200::/23 | AFRINIC | (no RFC column; RFCs appear only inside Note text) | 2004-06-01 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 2001:4400::/23 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2004-06-11 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2001:4600::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-08-17 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:4800::/23 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2004-08-24 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2001:4a00::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-10-15 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:4c00::/23 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-12-17 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:5000::/20 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2004-09-10 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2001:8000::/19 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2004-11-30 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2001:a000::/20 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2004-11-30 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2001:b000::/20 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2006-03-08 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2002::/16 | 6to4 | (no RFC column; RFCs appear only inside Note text) | 2001-02-01 | Status=ALLOCATED; Note=See [IPv6 Special-Purpose Address Space] for details. |
| 2003::/18 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2005-01-12 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2400::/12 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2006-10-03 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/; Note=2400::/19 was allocated on 2005-05-20. 2400:2000::/19 was allocated on 2005-07-08. 2400:4000::/21 was<br>allocated on 2005-08-08.  2404::/23 was allocated on 2006-01-19. The more recent allocation (2006-10-03)<br>incorporates all these previous allocations. |
| 2410::/12 | APNIC | (no RFC column; RFCs appear only inside Note text) | 2024-11-01 | Status=ALLOCATED; WHOIS=whois.apnic.net; RDAP=https://rdap.apnic.net/ |
| 2600::/12 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2006-10-03 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry; Note=2600::/22, 2604::/22, 2608::/22 and 260c::/22 were allocated on 2005-04-19. The more<br>recent allocation (2006-10-03) incorporates all these previous allocations. |
| 2610::/23 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2005-11-17 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2620::/23 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2006-09-12 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2630::/12 | ARIN | (no RFC column; RFCs appear only inside Note text) | 2019-11-06 | Status=ALLOCATED; WHOIS=whois.arin.net; RDAP=https://rdap.arin.net/registryhttp://rdap.arin.net/registry |
| 2800::/12 | LACNIC | (no RFC column; RFCs appear only inside Note text) | 2006-10-03 | Status=ALLOCATED; WHOIS=whois.lacnic.net; RDAP=https://rdap.lacnic.net/rdap/; Note=2800::/23 was allocated on 2005-11-17. The more recent allocation (2006-10-03) incorporates the<br>previous allocation. |
| 2a00::/12 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2006-10-03 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/; Note=2a00::/21 was originally allocated on 2005-04-19. 2a01::/23 was allocated on 2005-07-14.<br>2a01::/16 (incorporating the 2a01::/23) was allocated on 2005-12-15. The more recent allocation<br>(2006-10-03) incorporates these previous allocations. |
| 2a10::/12 | RIPE NCC | (no RFC column; RFCs appear only inside Note text) | 2019-06-05 | Status=ALLOCATED; WHOIS=whois.ripe.net; RDAP=https://rdap.db.ripe.net/ |
| 2c00::/12 | AFRINIC | (no RFC column; RFCs appear only inside Note text) | 2006-10-03 | Status=ALLOCATED; WHOIS=whois.afrinic.net; RDAP=https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/ |
| 2d00::/8 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 2e00::/7 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3000::/5 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3800::/6 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3c00::/7 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3e00::/8 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3f00::/9 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3f80::/10 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3fc0::/11 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3fe0::/12 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3ff0::/13 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3ff8::/14 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3ffc::/15 | IANA | (no RFC column; RFCs appear only inside Note text) | 1999-07-01 | Status=RESERVED |
| 3ffe::/16 | IANA | (no RFC column; RFCs appear only inside Note text) | 2008-04 | Status=RESERVED; Note=3ffe:831f::/32 was used for Teredo in some old but widely distributed networking stacks. This usage is deprecated in favor of 2001::/32, which was allocated for the purpose in [RFC4380].<br>3ffe::/16 and 5f00::/8 were used for the 6bone, but returned [RFC5156]. |
| 3fff::/20 | Documentation | (no RFC column; RFCs appear only inside Note text) | 2024-07-23 | Status=RESERVED; Note=See [IPv6 Special-Purpose Address Space] for details. |

## Registry gotchas

Every item below was observed directly in the fetched artefacts on 2026-07-27.

1. **The IPv4 Address Space "Prefix" column is not CIDR.** It is `000/8` … `255/8` with
   zero-padded decimal first octets and no trailing `.0.0.0`. `ipaddress`-style parsers reject it;
   naive string comparison against `10.0.0.0/8` fails. Verified: all 256 rows use this form.

2. **The IPv6 Address Space registry writes `::/8` and `100::/8`, not `0000::/8` / `0100::/8`.**
   Likewise `200::/7`, `400::/6`, `800::/5`, `1000::/4`, `e000::/4`, `f000::/5`, `f800::/6`,
   `fe00::/9`, `fec0::/10`. Both the CSV and the XHTML agree on this compressed spelling. Any
   expectation list written with leading zeros will silently mismatch every one of those rows.

3. **One IPv4 Special-Purpose record packs two prefixes into one field.**
   `"192.0.0.170/32, 192.0.0.171/32"` (NAT64/DNS64 Discovery, `[RFC8880][RFC7050], Section 2.2`)
   is a single CSV record whose Address Block cell is a comma-separated pair, CSV-quoted. Splitting
   the file on commas destroys it; treating the cell as one prefix produces a parse error. It is the
   only such row, and it exists in the HTML too.

4. **Footnote markers live inside the prefix column.** IPv4: `192.0.0.0/24 [2]`. IPv6:
   `2002::/16 [3]`. In both cases the literal cell value has a trailing space + bracketed digit,
   so the cell is not a valid CIDR string and must be stripped before parsing.

5. **Footnote markers also live inside policy values, which are therefore not booleans.**
   `False [1]` appears on all four non-Reserved-by-Protocol policy cells of `127.0.0.0/8` (IPv4)
   and of `2001::/23` (IPv6). `False [4]` on `fc00::/7`'s Globally Reachable cell. A strict
   `== "True"` / `== "False"` test fails on all nine of those cells.

6. **`N/A` is a real third value in the Globally Reachable column.**
   `2001::/32` (TEREDO) is `N/A [2]`; `2002::/16 [3]` (6to4) is `N/A [3]`. Not "unknown", not
   "False" — IANA means the question does not apply. Two rows, both IPv6, both also carrying a
   footnote marker inside the value.

7. **Terminated rows have five *empty* policy cells, not `N/A` and not `False`.**
   `192.88.99.0/24` (Deprecated (6to4 Relay Anycast), terminated `2015-03`) and `2001:10::/28`
   (Deprecated (previously ORCHID), terminated `2014-03`). In the CSV these are five consecutive
   commas; in the HTML they are five empty `<td>`s. Reading them as `False` asserts a policy IANA
   deliberately declined to state.

8. **A live, non-terminated assignment sits inside a terminated block.**
   `192.88.99.0/24` was terminated in 2015-03, but `192.88.99.2/32` (6a44-relay anycast address,
   `[RFC6751]`, allocated 2012-10) has Termination Date `N/A` and full True/True/True/False/False
   policy. Dropping terminated rows and their children loses a live special-purpose address.

9. **The registries are heavily nested and are not sorted for longest-prefix-first matching.**
   `192.0.0.0/24 [2]` (all-False) contains `192.0.0.0/29`, `192.0.0.8/32`, `192.0.0.9/32`,
   `192.0.0.10/32` and the `192.0.0.170/32, 192.0.0.171/32` pair — several of which are
   `True,True,True,True`, the exact opposite of the parent. `0.0.0.0/32` is inside `0.0.0.0/8`.
   `255.255.255.255/32` is inside `240.0.0.0/4` and differs from it in the Destination column.
   `2001::/23` contains eight more IPv6 special-purpose records. `100::/64` and `100:0:0:1::/64`
   are both inside `100::/8`. First-match-wins in file order gives the wrong answer.

10. **The IPv6 Special-Purpose registry is not in numeric order.** `::1/128` is listed *before*
    `::/128`. Any algorithm that assumes file order == address order breaks on row 1 vs row 2.

11. **Records wrap across physical lines inside quoted CSV fields**, with the continuation indented
    by eight spaces. Confirmed occurrences: IPv4 Special `255.255.255.255/32` RFC cell
    (`[RFC8190]\n        [RFC919], Section 7`); IPv6 Special `2001::/32` and `fc00::/7` RFC cells;
    IPv6 Address Space `2000::/3` Notes cell (4 physical lines); IPv6 Global Unicast — 5 Note cells
    (`2001:2000::/19`, `2400::/12`, `2600::/12`, `2800::/12`, `2a00::/12`, `3ffe::/16`); IPv4
    Multicast AD-HOC Block I — 2 Change Controller cells; IPv6 Multicast Variable Scope — 2 Change
    Controller cells. A line-oriented reader (`readLines` + `strsplit`) mis-parses all of them; a
    real CSV reader is mandatory.

12. **The CSV and the HTML disagree on the IPv4 Address Space RDAP column.** The HTML cell is
    `https://rdap.arin.net/registry<br />http://rdap.arin.net/registry` — two URLs separated by a
    line break. The CSV export drops the separator entirely and emits the single unusable token
    `https://rdap.arin.net/registryhttp://rdap.arin.net/registry`. The same corruption affects
    AFRINIC (`https://rdap.afrinic.net/rdap/http://rdap.afrinic.net/rdap/`). It occurs on every ARIN
    and AFRINIC row of `ipv4-address-space.csv` and on the ARIN/AFRINIC rows of
    `ipv6-unicast-address-assignments.csv`. This is a genuine data-loss bug in the CSV rendering.

13. **A footnote marker is embedded in a CSV column *header*.** `ipv4-address-space.csv` header row
    is `Prefix,Designation,Date,WHOIS,RDAP,Status [1],Note` — the Status column is literally named
    `Status [1]`. Code that matches on `"Status"` will not find it.

14. **`multicast-addresses-10.csv` (Source-Specific Multicast Block, 232/8) has the wrong first
    column heading.** It reads `Relative` where every sibling sub-registry reads `Address(es)`.
    The typo is present in the HTML too, so it is not a CSV-generation artefact — but it means a
    schema check keyed on `Address(es)` rejects the SSM block.

15. **The IPv4 Multicast registry has no top-level block table.** The 15 blocks exist only as
    `<h2>` heading strings, which are unparseable as data: they mix CIDR, dotted ranges, and
    legacy `224.0.0/24` prefix notation in one string; three headings carry no range at all
    (GLOP, Unicast-Prefix-based, Scoped Multicast Ranges, Relative Addresses); one packs two
    prefixes into one heading (`AD-HOC Block II (224.3.0.0-224.4.255.255 (224.3/16, 224.4/16))`);
    one has an unbalanced parenthesis (`DIS Transient Groups 224.252.0.0-224.255.255.255
    (224.252/14))`); and **one contains an arithmetic error**: `RESERVED (224.5.0.0-224.251.255.255
    (251 /16s))` spans 247 /16s, not 251.

16. **Nothing in the IPv4 Multicast registry is CIDR.** Every one of its 579 records is either a
    single dotted quad or a `start-end` dotted range, including ranges that are not
    CIDR-expressible (`224.0.0.37-224.0.0.68`, `224.0.0.70-224.0.0.100`,
    `224.3.0.0-224.3.0.63`, `224.4.104.0-224.4.255.255`). Any prefix-trie loader must
    range-to-CIDR-decompose them first.

17. **The IPv6 Multicast registry mixes three incompatible address notations in one column.**
    Fully expanded uppercase (`FF02:0:0:0:0:0:0:1`), CIDR (`FF02:0:0:0:0:1:FF00::/104`,
    `FF0X:0:0:0:0:DB8::/96`), and dashed ranges (`FF01:0:0:0:0:0:0:FC-FF01:0:0:0:0:0:0:FD`).
    None of it is RFC 5952 canonical form, so string equality against `ff02::1` never matches.

18. **`FF0X:...` rows are templates containing a literal `X`.** The whole Variable Scope
    sub-registry (132 records) uses `FF0X` to mean "any scope nibble". These strings are not valid
    IPv6 addresses. Expanding them multiplies each row by the 16 scope values — and the expansion
    then *collides* with the explicitly-listed Node-Local / Link-Local / Site-Local rows, which is
    exactly why those tables carry placeholder rows whose Description is the bare string
    `variable scope allocation` with every other column empty.

19. **A scope registry that contradicts its own defining RFC.** IANA's IPv6 Multicast Address
    Scopes registry (per RFC 7346) assigns scope `3` = `Realm-Local scope` and marks `6-7` and
    `9-D` `Unassigned`. RFC 4291 §2.7 — still the normative addressing architecture — says scope 3
    is `reserved` and that `6,7,9,A,B,C,D` are `(unassigned)` and available for administrators.
    Citing RFC 4291 for scope semantics yields a stale answer.

20. **The scope nibble is not a prefix.** Scope `N` is the *low* nibble of the second octet; the
    high nibble is `ff1`/`flgs`. Scope 2 (Link-Local) therefore covers `ff02::/16`, `ff12::/16`,
    `ff32::/16`, `ff72::/16`, … — sixteen separate /16s, not one CIDR. Mapping "Link-Local scope"
    to `ff02::/16` alone silently misses every transient, unicast-prefix-based and Embedded-RP
    link-local group.

21. **Reference cells contain things that are not RFC numbers.** `[RFC5180][RFC Errata 1752]`
    (IPv6 Special, `2001:2::/48`); `[RFC-ietf-pim-updt-ipv6-dyn-mcast-addr-grp-id-13]` — an
    unpublished Internet-Draft — in two IPv6 Multicast sub-registries; `"[RFC4291, Section 2.7.1]"`
    (comma inside a quoted field); person tags `[Jon_Postel]`, `[Steve_Casner]`; double-bracketed
    names `[[Bill Simpson]]`, `[[Unknown]]`, `[[Guido van Rossum]]`; a placeholder
    `[\<mystery contact>]`; bare URLs `[http://ieee1588.nist.gov/]`; and organisation tags
    `[NIST: IEEE Std 1588]`. A regex of `RFC[0-9]+` over these columns yields both false negatives
    and, for `[RFC Errata 1752]`, near-misses.

22. **RFC citations carry section suffixes outside the brackets.** `[RFC791], Section 3.2`,
    `[RFC1122], Section 3.2.1.3`, `[RFC6890], Section 2.1`, `[RFC1112], Section 4`,
    `[RFC8880][RFC7050], Section 2.2`. The section applies to the *last* RFC in the list, not all
    of them.

23. **Allocation dates routinely predate the cited RFC.** `192.175.48.0/24` is dated `1996-01` but
    cites `[RFC7534]` (2015). `255.255.255.255/32` is dated `1984-10` but cites `[RFC8190]`
    (2017). `0.0.0.0/32` is dated `1981-09` but cites `[RFC1122]` (1989). The date is the date of
    the *reservation*, not of the document; sorting or validating by "RFC year vs allocation year"
    produces spurious errors.

24. **Date granularity is inconsistent across and within registries.** IPv4/IPv6 Address Space and
    both Special-Purpose registries use year-month (`1981-09`, `2010-01`). IPv6 Global Unicast uses
    full ISO dates (`1999-07-01`) — except `3ffe::/16`, which is `2008-04`. IPv4/IPv6 Multicast use
    full ISO dates in `Date Registered` but leave most of them empty. The IPv6 Address Space
    registry has **no date column at all**.

25. **Deprecation is expressed four different ways.** (a) a `Termination Date` column
    (IPv4/IPv6 Special-Purpose); (b) free text in a Notes column with no machine-readable field
    (IPv6 Address Space: `200::/7` "Deprecated as of December 2004 [RFC4048]"; `fec0::/10`
    "Deprecated by [RFC3879] in September 2004"); (c) the word inside the Name/Description
    (`Deprecated (6to4 Relay Anycast)`, `Deprecated (previously ORCHID)`,
    `SAPv0 Announcements (deprecated)`, `FF05:0:0:0:0:0:1:4,Deprecated (2003-03-12)` — where the
    deprecation date is inside the description and every other column is empty); (d) silent
    removal: `::/96`, the former IPv4-compatible IPv6 address prefix, is mentioned only in the
    `::/8` Notes as "deprecated by [RFC4291]" and appears as a row in **no** registry.

26. **The same prefix appears in more than one registry, with different names and sometimes
    different granularity.** Confirmed overlaps:
    `fc00::/7` — IPv6 Address Space (`Unique Local Unicast`) and IPv6 Special-Purpose
    (`Unique-Local`);
    `fe80::/10` — IPv6 Address Space (`Link-Scoped Unicast`) and IPv6 Special-Purpose
    (`Link-Local Unicast`);
    `ff00::/8` — IPv6 Address Space (`Multicast`) and the entire IPv6 Multicast registry;
    `2001::/23` — IPv6 Special-Purpose (`IETF Protocol Assignments`, all-False) and IPv6 Global
    Unicast (`IANA`, ALLOCATED);
    `2002::/16` — IPv6 Special-Purpose (`6to4`) and IPv6 Global Unicast (`6to4`, ALLOCATED);
    `3fff::/20` — IPv6 Special-Purpose (`Documentation`, RFC 9637) and IPv6 Global Unicast
    (`Documentation`, RESERVED);
    `224.0.0.0/4` — IPv4 Address Space rows `224/8`–`239/8` and the whole IPv4 Multicast registry;
    `240.0.0.0/4` — IPv4 Address Space rows `240/8`–`255/8` (`Future use`) and IPv4 Special-Purpose
    (`Reserved`);
    `10.0.0.0/8`, `127.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`,
    `100.64.0.0/10`, `192.0.0.0/24`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`,
    `192.0.2.0/24` — all in IPv4 Special-Purpose *and* referenced from IPv4 Address Space footnotes
    `[2]`–`[13]`.
    The Address Space registries are explicit that the Special-Purpose registry is authoritative
    ("For authoritative registration, see [IPv4 Special-Purpose Address Space]"), so precedence
    must be Special-Purpose > Address Space.

27. **A granularity conflict between two registries about the same block.** The IPv6 Special-Purpose
    registry assigns `5f00::/16` to `Segment Routing (SRv6) SIDs` [RFC9602]. The IPv6 Address Space
    Notes for `4000::/3` and the IPv6 Global Unicast Notes for `3ffe::/16` both refer to
    **`5f00::/8`** as the returned 6bone range. `/8` vs `/16` — the two statements are about
    overlapping but different-sized blocks, and only the `/16` is a registry row.

28. **Cross-registry staleness.** IPv4 Address Space footnote `[10]` still reads "192.88.99.0/24
    reserved for 6to4 Relay Anycast [RFC7526]" with no mention that the IPv4 Special-Purpose
    registry terminated that reservation in 2015-03. Footnote `[11]` cites `[RFC5736]` for
    `192.0.0.0/24`, while the Special-Purpose registry cites `[RFC6890]`, which obsoleted RFC 5736.
    The two registries were last edited a day apart (2025-10-09 / 2025-10-10) and still disagree.

29. **Quote-in-quote values.** The IPv4 Special-Purpose Name column contains `"""This network"""`
    and `"""This host on this network"""` in raw CSV — i.e. the parsed value retains literal
    double-quote characters: `"This network"`. `"rwho" Group (BSD) (unofficial)` in the IPv6
    Multicast Variable Scope registry is the same pattern. Displaying or matching these without
    accounting for the embedded quotes fails.

30. **`(*)` is an unmarked footnote reference inside descriptions.** `224.0.0.254` is
    `RFC3692-style Experiment (*)` and relative address `254` likewise; the `(*)` resolves to a
    page-level Note about RFC 3692 experimental values that has no marker column and no anchor.

31. **Neither Address Space registry is what people assume, but both *are* exact partitions.**
    Verified computationally: the 256 IPv4 `/8` rows collapse to exactly `0.0.0.0/0`, and the 20
    IPv6 rows collapse to exactly `::/0` — no gaps, no overlaps. **The Global Unicast registry is
    not a partition**: 61 sub-ranges of `2000::/3` (including `2000::/16`, `2100::/8`, `2200::/7`,
    `2500::/8`) appear in no row. Absence there means "unallocated", which is a distinct answer
    from "not found".

32. **Sub-registry file names are not derivable from the page.** The IPv6 Address Space CSV is
    `ipv6-address-space-1.csv`; `ipv6-address-space.csv` returns HTTP 404 with an HTML error body
    that is served as a 4216-byte file. The IPv4 and IPv6 Special-Purpose CSVs are likewise
    `-1`-suffixed. A fetch script that does not check the status code will happily vendor an HTML
    "Page not found" document as a registry.

33. **`Last-Modified` is a deploy timestamp, not a content timestamp.** `ipv4-address-space.csv`,
    `iana-ipv4-special-registry-1.csv`, `iana-ipv6-special-registry-1.csv`, `ipv6-scope.csv`,
    `glop.csv`, `unicast-prefix-based.csv` and `multicast-addresses-13.csv` all report the
    identical second `Thu, 09 Oct 2025 21:51:16 GMT` despite belonging to four unrelated
    registries. Meanwhile the IPv4 Multicast page's own `Last Updated` is `2026-06-26`, newer than
    several of its own CSVs' `Last-Modified`. Use the page-level `Last Updated` for editorial
    currency and per-file `Last-Modified` only for cache validation.

34. **Sub-registry ranges overlap the block headings.** GLOP is `233.0.0.0-233.251.255.255` while
    AD-HOC Block III is `233.252.0.0-233.255.255.255`; together they tile `233/8`, but neither
    heading says so, and the GLOP heading carries no range at all. Similarly `Scoped Multicast
    Ranges` silently covers `235.0.0.0-239.255.255.255` — including `239.0.0.0/8`
    Organization-Local Scope, the administratively-scoped block from RFC 2365 that most consumers
    expect to find as a first-class block.

35. **Gaps that are not marked as gaps.** The IPv6 Link-Local Scope sub-registry jumps from
    `FF02:0:0:0:0:0:0:14` to `FF02:0:0:0:0:0:0:16` with no `15` row and no `Unassigned` row for it.
    Per the registry's own note, "IPv6 multicast addresses not listed below are reserved" — so
    absence is meaningful, but it is only stated in prose at the top of the page, not in the data.
    Compare the IPv4 multicast tables, which *do* emit explicit `Unassigned` rows.

36. **`Change Controller` can hold multiple values joined by a newline, not a delimiter.**
    `"[Meridian_Labs_LTD]\n        [LIRNEasia]"` appears in both `multicast-addresses-3.csv` and
    `variable.csv`. The same two entities appear in the adjacent `References` column as
    `[Meridian_Labs_LTD][LIRNEasia]` — concatenated with no separator at all. Two different
    multi-value encodings for the same pair of names, in the same record.

### Explicitly UNVERIFIED

- Nothing in this document is asserted from memory. Every prefix, name, RFC citation, date and
  policy value above was read out of the fetched CSV or XHTML artefact on 2026-07-27.
- The IPv4 Multicast sub-registries `multicast-addresses-2.csv` (Internetwork Control, 192 records)
  and `multicast-addresses-3.csv` (AD-HOC Block I, 244 records) are reproduced in full above, but
  their individual `[Person_Name]` reference tags were **not** resolved against IANA's contact
  page; they are transcribed as literal strings.
- The claim that RFC 3956 requires `flgs = 0111` for Embedded-RP is taken from RFC 7371 §4.2.4
  quoting the updated RFC 3956 text, not from RFC 3956 itself, which was not fetched.
