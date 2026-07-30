# DRAFT — not yet submitted

**DUPLICATE CHECK DONE (2026-07-30).** A report already exists. **Do not open a
new issue.**

- Existing issue: **[python/cpython#88178](https://github.com/python/cpython/issues/88178)**
  — "IPv6Address.exploded does not support interface name (scope id)". Open since
  2021-05-02, originally bpo-44012. Still in "patch review".
- Existing PR: **[#25824](https://github.com/python/cpython/pull/25824)** —
  "bpo-44012: IPv6Address.exploded with scope_id". Open, approved by a
  non-core reviewer, CLA label removed 2022-07-13, marked stale 2026-04-09.
  Dormant ~4 years with no core-dev merge decision.

**Target:** a comment on #88178 (and/or a review comment on PR #25824).
**raddr tracking issue:** RADD-vnjcbacv (O15)
**Blocked on:** GitHub account suspension — commenting needs a logged-in
account. The *research* is done; only posting is blocked.
**Measured:** 2026-07-30, macOS 25.4.0 arm64, CPython 3.9.6, 3.12.13, 3.14.6.

What #88178 and its PR already cover: `IPv6Address.exploded` raising
`AddressValueError` on a scoped address, and a fix that retains the scope in the
output. Everything below is *not* in either thread — and one item is a live
problem with the pending PR.

---

## Comment body

Still reproduces five years on — identically on **3.9.6**, **3.12.13** and
**3.14.6** (macOS, arm64), same message in each:

```python
>>> ipaddress.IPv6Address('fe80::1%lo0').exploded
AddressValueError: Only hex digits permitted in '1%lo0' in 'fe80::1%lo0'
```

Four things that don't appear in this issue or in PR #25824, from measuring the
surrounding surface. The first is a problem with the PR as written.

### 1. PR #25824's output format would silently break `.reverse_pointer`

`_BaseV6._reverse_pointer()` is built on `self.exploded`:

```python
def _reverse_pointer(self):
    reverse_chars = self.exploded[::-1].replace(':', '')
    return '.'.join(reverse_chars) + '.ip6.arpa'
```

PR #25824 makes `.exploded` retain the scope suffix
(`'fe80:0000:0000:0000:0000:0000:0000:0001%eth0'`). Feeding that to the above
reverses the interface name into the label sequence:

```
0.h.t.e.%.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.e.f.ip6.arpa
```

versus the correct

```
1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.e.f.ip6.arpa
```

Today `.reverse_pointer` raises on a scoped address. With the PR it would return
a malformed DNS name instead — trading a loud failure for a silent wrong answer,
which seems worse. A zone identifier has no meaning in `ip6.arpa`, so
`_reverse_pointer()` should use the scope-free expansion regardless of what
`.exploded` decides to render.

Suggestion: if `.exploded` keeps the suffix, give `_reverse_pointer()` a
scope-free source. Formatting the stored integer directly avoids the question
entirely, and is cheaper than the current re-parse:

```python
hex_str = '%032x' % self._ip     # self._ip is already on the object
```

That also removes the root cause — the existing code round-trips through
`str(self)` and re-parses it (`ip_str = str(self)` then
`self._ip_int_from_string(ip_str)`), which is why the `%` reaches the parser at
all. The integer is right there; no parse is needed in a formatting path.

### 2. `IPv6Network` fails the same way

```python
>>> ipaddress.IPv6Network('fe80::%lo0/64').exploded
AddressValueError: Only hex digits permitted in '%lo0' in 'fe80::%lo0'
```

`_explode_shorthand_ip_string()` takes `str(self.network_address)` for the
network branch, which carries the scope just as `str(self)` does. Worth fixing in
the same change.

### 3. `IPv6Interface` doesn't raise — it silently drops the scope

The three scope-carrying classes currently behave three different ways:

| Object | `.compressed` keeps scope | `.exploded` |
|---|---|---|
| `IPv6Address('fe80::1%lo0')` | yes | raises `AddressValueError` |
| `IPv6Network('fe80::%lo0/64')` | yes | raises `AddressValueError` |
| `IPv6Interface('fe80::1%lo0/64')` | yes | **succeeds, scope silently dropped** |

`IPv6Interface` escapes only because the interface branch uses `str(self.ip)`,
and `.ip` has already lost the zone. Whatever is decided about rendering, these
three presumably ought to agree.

### 4. The IPv4-mapped path fails with a different message

```python
>>> ipaddress.IPv6Address('::ffff:1.2.3.4%eth0').exploded
AddressValueError: Only decimal digits permitted in '4%eth0' in '1.2.3.4%eth0' in '::ffff:1.2.3.4%eth0'
```

`IPv6Address._explode_shorthand_ip_string()`'s IPv4-mapped override re-parses
too, so it needs the same treatment. Easy to miss in a test that only covers
`fe80::`-style addresses.

### Unrelated bug found nearby

Not part of this issue — it reproduces with **no scope involved** — but it is the
same "`exploded` is not a safe input to `_reverse_pointer`" shape as item 1:

```python
>>> ipaddress.IPv6Interface('fe80::1/64').reverse_pointer
'4.6./.1.0.0.0.0.…0.8.e.f.ip6.arpa'
```

The `/64` gets reversed into the name. Happy to file separately if useful.

---

## Notes to self (not part of the submission)

- **I was wrong to call the duplicate check blocked.** The suspension 403s
  authenticated GitHub access (`gh api`, push/fetch); it does not stop fetching a
  public tracker over the web, which uses a different path entirely. Checked, and
  #88178 has existed since 2021 — so the original plan to open a new issue would
  have filed a five-year-old duplicate.
- **The deliverable changed:** a comment on #88178 / review note on PR #25824,
  not a new issue. Rewrote accordingly.
- **Item 1 is the real find and it is new.** Neither the issue nor the PR
  mentions `reverse_pointer`. Verified by simulating the PR's documented output
  format and running it through the actual `_reverse_pointer()` logic. The PR
  would convert an exception into a silently malformed DNS name. This is worth
  raising *before* the PR merges, and it may be the thing that gets a dormant
  4-year-old PR looked at again.
- **The open design question from my earlier draft is already answered** — PR
  #25824 retains the scope in `.exploded`. Dropped my "should it render the
  scope?" paragraph and replaced it with the consequence, which is more useful
  than re-asking a settled question.
- Items 2–4 and the `IPv6Interface` asymmetry are absent from both threads
  (checked the issue page and the PR page).
- Kept the independent `IPv6Interface.reverse_pointer` `/64` bug clearly
  separated, but moved it adjacent to item 1 since they share a root cause:
  `.exploded` output is not safe to feed to `_reverse_pointer()`.
- Led with "still reproduces on 3.14.6" because the practical obstacle here is
  dormancy, not doubt — the PR has approval and no merge decision.
