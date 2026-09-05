# Outbound bug-report drafts — measured, drafted, deliberately unfiled

Written 2026-07-30. All five are **complete drafts**, measured against live
libraries, not sketches. Nothing has been submitted, and nothing is queued to
be.

**This work is finished.** Epic O (`RADD-dtdcaphz`) restated the deliverable as
the four things raddr controls — the defect reproduced against the live library
at a named version and platform, the claim narrowed to what the measurement
supports, a duplicate check done against the upstream tracker, and a
submission-ready report in git with its reproducers pasted verbatim — because
raddr does not control `davidchall/ipaddress` or `python/cpython` and never did.
All four hold for all five drafts. The five issues were closed on that basis,
and the epic followed on 2026-08-12. Unfiled is the intended end state rather
than a residual task; if posting these ever becomes both possible and wanted,
that is a new issue about publication, not unfinished business from this one.

These were drafted in `_scratch/outbound-drafts/`, which is gitignored, and moved
here on 2026-07-30 so they survive. They are the evidence behind
`docs/architecture.md`'s O11a / O11b / O15 / O16 / O18 rows, which cite the
findings but not the measurements, and that makes them durable project knowledge
rather than scratch. `.Rbuildignore` carries `^docs$`, so nothing here reaches
`R CMD check`.

Each file has a `## Body` section that is the submission text verbatim, and a
`## Notes to self` section that is **not** part of the submission — it records
what re-measurement changed versus the raddr issue text.

| Draft | Target | raddr issue | Ready? |
|---|---|---|---|
| `ipaddress-01-equality-int-min.md` | davidchall/ipaddress | RADD-ssschhlu | yes |
| `ipaddress-02-nat64.md` | davidchall/ipaddress | RADD-pyinlkit | yes |
| `ipaddress-03-discarded-zone.md` | davidchall/ipaddress | RADD-exojkzzj | yes |
| `cpython-04-exploded-scope-id.md` | python/cpython — **comment on #88178, do not open a new issue** | RADD-vnjcbacv | yes |
| `ipaddress-05-reverse-pointer.md` | davidchall/ipaddress | RADD-gutuomse | yes |

## What posting these would take, if it were ever wanted

Not a queue and not a task list. This heading read "When the suspension lifts"
until 2026-09-05 and carried three imperatives written on the assumption that a
filing was still owed. It is not: the third of them — backfill the filed URLs
into the raddr issues and close them — is void, because those issues were closed
on the measurement rather than on a filing, and there is nothing to backfill.
The account that would have done the posting has been suspended since
2026-07-20, and on 2026-09-05 GitHub was removed from this tree altogether
(`RADD-ithxwzpr`) — the workflow, the remote and the `.Rbuildignore` line are
gone, and `DESCRIPTION` points at GitLab. Nothing here waits on that account.

What survives is ordering knowledge that cost a duplicate check to acquire and
would have to be re-established otherwise. Recorded so it is not re-derived:

1. **The CPython draft belongs as a comment on
   [#88178](https://github.com/python/cpython/issues/88178), not as a new
   issue.** Duplicate check was done 2026-07-30: that issue has been open since
   2021 (bpo-44012), with PR
   [#25824](https://github.com/python/cpython/pull/25824) approved but dormant
   since 2022 (marked stale 2026-04-09). The comment's lead finding is that the
   PR's output format would silently break `.reverse_pointer` — which is what
   made it the most time-sensitive of the five while a filing was still
   contemplated.
2. **The four ipaddress reports are independent** and would go in any order.
   They cross-reference each other, so the sibling links carry no issue numbers
   and would need real ones filled in after the first was posted.

Both readings are as of 2026-07-30 and have not been re-checked since; a
duplicate check that old would be redone, not trusted.

## Measurement environment

macOS 25.4.0, arm64. R 4.6.0, ipaddress 1.0.3, vctrs. CPython 3.9.6
(`/usr/bin/python3`), 3.12.13 and 3.14.6 (homebrew). Every claim in every draft
was produced by running the library, not by reading its docs. IANA field values
came from raddr's vendored `inst/extdata/iana-ipv6-special-registry.csv`.

Line-number citations in the CPython draft are 3.14.6-specific and will drift;
the draft quotes the code so the report survives that.

## What re-measurement changed, in one line each

- **ssschhlu** — blast radius is *narrower* than filed (only `==`/`!=`, not
  comparison generally), which led to a verified one-method fix; the IPv6
  colliding literals are ordinary addresses like `fe80::80`; `ip_network` and
  `ip_interface` also affected.
- **pyinlkit** — found a second, concrete defect: `is_global()` is wrong for
  `64:ff9b:1::/48` per IANA and per Python. Reframed the missing API as the one
  absent member of a family the package already has three times.
- **exojkzzj** — the `inet_pton` claim needed narrowing: Apple's accepts `%lo0`,
  `%`, `%999` and `%nonexistent-if`, rejecting only the multi-`%` forms.
- **gutuomse** — new draft, not a re-measurement. O18 had sat in
  `docs/architecture.md` since 2026-07-28 with no tracking issue and no draft.
  Both defects reproduce exactly as recorded. Added the cause (an
  `ostringstream` declared outside the loop), the measured quadratic scaling, and
  the finding that the **test suite asserts the wrong suffix** — which is why a
  fix needs a new test, not just a corrected expectation.
- **vnjcbacv** — it is a **duplicate** of a 2021 issue, so this became a comment
  rather than a filing. New value: the pending PR's output format would turn
  `.reverse_pointer` from an exception into a malformed DNS name; plus three more
  affected surfaces, with `IPv6Interface` failing *differently* (silently
  dropping the scope instead of raising).

## What the suspension does and does not block

Worth stating plainly, because getting it wrong once nearly cost a duplicate
filing. The suspension 403s **authenticated** GitHub access — `gh api`, push,
fetch. It does **not** block reading a public issue tracker over the web, which
needs none of the account's credentials. So duplicate checks were always
available, and skipping them as "blocked" was a mistake. Every check below was
done on 2026-07-30 by reading the trackers directly, and one of them found a
five-year-old duplicate.

## Duplicate checks — all five done 2026-07-30

| Draft | Result |
|---|---|
| `cpython-04` | **DUPLICATE.** #88178 open since 2021 + dormant PR #25824. Became a comment. |
| `ipaddress-01` (equality) | clear |
| `ipaddress-02` (NAT64) | clear |
| `ipaddress-03` (zone) | clear |
| `ipaddress-05` (reverse pointer) | clear — checked 2026-07-30, incl. **66 PRs, zero open**, so no fix in flight |

`davidchall/ipaddress` has 12 issues total, only #101 open besides release
tickets, and nothing touching equality/`NA` storage, NAT64, or zone IDs. The one
plausible match, #91 "ipv6 to ipv4 is NA" (closed, 2023-04), is unrelated — a
user calling `extract_6to4()` on addresses that are not 6to4, where `NA` is the
correct answer.

**Maintenance expectation:** last commit 2025-08-22 (version bump to
1.0.3.9000), with a gap between 2023-12 and 2025-08. Maintained, but slowly — do
not expect a fast response on any of the four.
