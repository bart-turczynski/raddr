# DRAFT — not yet submitted

**Target:** https://github.com/davidchall/ipaddress/issues (new issue)
**raddr tracking issue:** RADD-ssschhlu (O11b)
**Blocked on:** GitHub account suspension. Submit verbatim once lifted.
**Measured:** 2026-07-30, macOS 25.4.0 arm64, R 4.6.0, ipaddress 1.0.3, vctrs loaded.

---

## Title

`==` returns `NA` for addresses whose 32-bit word is `0x80000000` (no `vec_proxy_equal` method, so equality falls through to the `NA_integer_` sentinel)

## Body

### Summary

`ip_address` stores address words as R `integer`. R reserves the bit pattern
`0x80000000` (`INT_MIN`) as `NA_integer_`, so an address whose stored word hits
that pattern holds `NA` in that field. The package defines
`vec_proxy_compare.ip_address()`, which is `NA`-free — but defines **no**
`vec_proxy_equal.ip_address()`. Equality therefore falls back to the raw record
fields, `vec_equal()` propagates the missingness, and `==` returns `NA`.

The address is otherwise completely healthy: it formats correctly, `is.na()`
reports `FALSE`, ordering works, and `match()`/`%in%`/`unique()` work. Only
`==` and `!=` break, and they break to `NA` rather than `FALSE`.

### Reproducer

```r
library(ipaddress)

a <- ip_address("0.0.0.128")

a == a
#> [1] NA            # expected TRUE

is.na(a)
#> [1] FALSE         # not reported as missing
as.character(a)
#> [1] "0.0.0.128"   # formats correctly
unclass(a)$address1
#> [1] NA            # but the stored word is NA_integer_
```

`ip_address` stores words little-endian (`1.0.0.0` → word `1`; `0.0.0.1` → word
`16777216`), so the colliding IPv4 literal is `0.0.0.128` — final octet `128`
in the high byte, giving `0x80000000`. For contrast, `128.0.0.0` is fine:

```r
ip_address("128.0.0.0") == ip_address("128.0.0.0")
#> [1] TRUE
unclass(ip_address("128.0.0.0"))$address1
#> [1] 128
```

### The IPv6 cases are ordinary addresses, not exotic ones

For IPv6 the collision fires when any 32-bit-aligned group equals `0x00000080`
— in text, a group written `0:80`, which is what every address ending in `::80`
has. All of these return `NA` from `==`:

```r
for (s in c("::80", "fe80::80", "2001:db8::80", "64:ff9b::80",
            "::ffff:0.0.0.128", "::80:0:0", "0:0:0:80::")) {
  cat(sprintf("%-20s %s\n", s, ip_address(s) == ip_address(s)))
}
#> ::80                 NA
#> fe80::80             NA
#> 2001:db8::80         NA
#> 64:ff9b::80          NA
#> ::ffff:0.0.0.128     NA
#> ::80:0:0             NA
#> 0:0:0:80::           NA
```

`fe80::80` is an unremarkable link-local address and `2001:db8::80` is in the
documentation range. This is not a corner only fuzzers reach.

Counting: exactly **one** IPv4 address, and for IPv6 every address with
`0x00000080` in any of the four words — about `4 × 2^96` addresses (precisely
`4·2^96 − 6·2^64 + 4·2^32 − 1` by inclusion–exclusion).

### `ip_network` and `ip_interface` inherit it

```r
ip_network("0.0.0.128/32")   == ip_network("0.0.0.128/32")     #> NA
ip_interface("0.0.0.128/32") == ip_interface("0.0.0.128/32")   #> NA
```

### What is *not* affected

Worth stating precisely, because it bounds the severity and points at the fix.
Everything below is correct on `ip_address("0.0.0.128")`:

| Operation | Result |
|---|---|
| `<` `>` `<=` `>=` `sort()` `min()` `max()` | correct |
| `match()` `%in%` `unique()` `duplicated()` | correct |
| `is_within()` (and network containment) | correct |
| `is.na()` | correct (`FALSE`) |
| `as.character()` / printing | correct |
| `+` `-` arithmetic | correct |
| **`==` `!=`** | **`NA`** |

So the earlier framing "any base/dplyr filter silently drops the row" is too
broad: `filter(addr %in% blocklist)` is fine. What breaks is `==` specifically —
`filter(addr == target)`, `if (addr == blocked)`, and anything built on them.
That is still the most common way people write an address check, and failing to
`NA` means `if` errors out on a missing value while `filter()` drops the row,
neither of which reads as "this address matched".

### Mechanism

```r
library(vctrs)
a <- ip_address("0.0.0.128")

vec_proxy_compare(a)   # 8 × 16-bit fields, NA-free:  0 128 0 0 0 0 0 0
vec_proxy_equal(a)     # raw record fields:  address1 = NA

vec_equal(a, a)                    #> NA     <- what `==` uses
vec_equal(a, a, na_equal = TRUE)   #> TRUE
vec_match(a, a)                    #> 1      <- why match()/%in% are fine
vec_compare(a, a)                  #> 0      <- why < > sort() are fine
```

The package ships `vec_proxy_compare.ip_address`, `.ip_network` and
`.ip_interface` (splitting into 16-bit halves, so no field can reach `INT_MIN`)
but no `vec_proxy_equal` methods. Ordering was given an `NA`-free proxy;
equality was not.

`match()`/`unique()` are correct rather than accidentally correct: a genuinely
missing address has *all four* words `NA` **and** `is_ipv6 = NA`, so its proxy is
distinguishable from `0.0.0.128`'s. Verified — a real address does not match a
missing one:

```r
a %in% ip_address(NA)          #> FALSE
length(unique(c(a, ip_address(NA))))   #> 2
```

### Suggested fix

One method per class, reusing the `NA`-free proxy the package already computes:

```r
vec_proxy_equal.ip_address <- function(x, ...) vec_proxy_compare(x)
# likewise for ip_network and ip_interface
```

Verified against 1.0.3 by registering that method in a live session:

```r
a == a                              #> TRUE     (was NA)
a != a                              #> FALSE    (was NA)
a == ip_address("1.2.3.4")          #> FALSE
ip_address(NA) == ip_address(NA)    #> NA       (genuine missingness preserved)
match(a, a)                         #> 1        (unchanged)
a %in% ip_address(NA)               #> FALSE    (unchanged)
```

This is cheaper than the alternatives (widening the proxy to `double` and
mapping the sentinel back to `2^31`, or carrying missingness in a separate
field) and it keeps one source of truth for "how do these bits compare".

### This is not an R bug

R documents the integer range as ±2147483647 (`?integer`,
`.Machine$integer.max`), warns on `as.integer(-2147483648)` with "NAs introduced
by coercion to integer range", and `?bitwAnd` states that "pairwise operations
can result in integer NA". The in-band `NA` sentinel is a deliberate, documented
choice inherited from S. The issue is storing unsigned 32-bit data in a signed
type with a reserved value and not accounting for the collision in the equality
path.

### Context

Found while building [raddr](https://gitlab.com/bart-turczynski/raddr), an
offline IP parsing/classification package, during a cross-implementation
comparison. raddr stores big-endian, so the same class of defect would surface
there on `128.0.0.0` instead; it carries missingness in a separate field to
avoid the collision. Filing because the behaviour is silent and affects
ordinary addresses.

---

## Notes to self (not part of the submission)

- **Blast radius is much narrower than RADD-ssschhlu claimed.** The issue said
  comparison broadly fails and "any dplyr/base filter silently drops the row".
  Measured: only `==`/`!=`. Ordering, matching, uniqueness, containment and
  arithmetic are all correct. Corrected in the draft, and the narrowing is what
  led to the one-method fix.
- **The IPv6 literals were missing and non-obvious.** The issue asserted
  "roughly 4 × 2^96 addresses, including ordinary-looking ones" without naming
  any. The pattern is a 32-bit group of `0x00000080` (not `0x80000000` in text
  form — the storage is byte-reversed), i.e. addresses ending `::80`. `fe80::80`
  and `2001:db8::80` are the persuasive examples.
- **Scope widened:** `ip_network` and `ip_interface` inherit the bug; the issue
  mentioned only `ip_address`.
- **Fix improved.** The issue proposed widening to `double` or a separate
  missingness field. Measured a one-line-per-class `vec_proxy_equal` that reuses
  the existing `NA`-free compare proxy, and verified it in a live session.
- Deliberately did **not** claim `match()`/`unique()` are "accidentally" right —
  checked the missing-address proxy and confirmed no conflation is possible.
