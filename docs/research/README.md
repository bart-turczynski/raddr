# Research notes

Primary-source research gathered for Epic I, `RADD-hmkrxahr`. These files are
**evidence, not design.** `docs/architecture.md` remains the settled design
record; nothing here is binding until it has been read into that document.

Nine independent agents produced these, none sharing context with the others, so
that agreement between two files is corroboration rather than an echo. That
paid off immediately: two files disagreed about which `/3` contains `5f00::/16`,
and the arithmetic settled it. **Where two files conflict, check rather than
pick.**

| File | Scope |
|---|---|
| `00-local-inventory.md` | What this repository already recorded, before any external research. The baseline the other eight are diffed against |
| `01-iana-registries.md` | All seven IANA address registries, fetched 2026-07-27, at the registries' own granularity |
| `02-ipv4-ranges.md` | IPv4 ranges and their RFCs, including everything outside the special-purpose registry |
| `03-ipv6-ranges.md` | IPv6 ranges, the multicast flags and scope field, and the deprecated blocks |
| `04-transition-embedding.md` | Bit geometry of every IPv4-in-IPv6 form, all six RFC 6052 prefix lengths |
| `05-parser-gotchas.md` | Textual divergence across libc, WHATWG and language runtimes, and the 2021 octal CVE class |
| `06-library-divergence.md` | How other libraries *classify* addresses, and where they disagree with IANA |
| `07-block-semantics.md` | What each special-purpose block is for, and how naive classifiers misread it |
| `08-encoding-reverse.md` | Reverse pointers, numeric encodings, prefix notation, round-trip failures |
| `09-peer-parser-conformance.md` | Executed hard-case parser comparison across raddr, all surveyed R peers, and canonical Python, Go, and Rust libraries |

## How to read these

Every claim was required to carry an RFC section or a URL, and anything the
agent could not substantiate is marked `UNVERIFIED` rather than dropped or
guessed. Treat an `UNVERIFIED` marker as an open question, not as a weak fact.

Dated retrievals are stated in the files. The IANA data was fetched
2026-07-27; the vendored snapshot in `inst/extdata/` is `Last-Modified`
2025-10-09. Those are different things and neither supersedes the other:
`inst/extdata/` is what the package ships and matches against, and
`data-raw/build-registry.R --check` is what keeps it honest.

## The recurring lesson

Four of these files independently concluded the same thing from different
directions: **the IANA registry is the data; the RFC text is not.** RFC 6890's
tables are a stale 2013 snapshot, RFC 2544 §C.2.2.2 contains a literal typo in
the benchmarking range, RFC 5180 §8 prints the wrong benchmarking prefix
(Errata 1752), and IANA's own footnotes still cite obsoleted RFCs. Transcribe
from the registry, and cite the RFC for meaning rather than for values.
