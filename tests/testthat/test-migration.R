# The migration contract with the in-house guards. See docs/architecture.md
# section 11.10.
#
# sitemapr and robotstxtr each carry a structural SSRF guard whose IPv4/IPv6
# reading raddr is meant to replace. The two guards are ONE implementation --
# 232 identical lines, 11 identical functions, differing only in the entry point
# -- so what is pinned here is pinned for both.
#
# This file does not test the guards. It pins the facts a delegation would rest
# on, so that a change to raddr's vocabulary or grammar cannot silently break a
# migration that has not happened yet. Every claim below was measured against
# the guard on 2026-07-29; the divergences are recorded in section 11.10 and are
# the guard's, not raddr's.
#
# P8 is respected throughout: raddr supplies the CATEGORY, never the verdict.
# "block this" is the consumer's decision and ssrfr's business.

# --- the reason codes the guards derive from a range --------------------------

test_that("raddr's category supplies every range-derived reason code", {
  # The guard's blocked IPv4 matrix, restated as the category raddr answers for
  # a representative address in each block. A delegation reads `addr_category()`
  # and maps it; if this table stops holding, the mapping is wrong.
  want <- rows_table(
    c("address", "category"),
    "127.0.0.1", "loopback",
    "10.0.0.1", "private",
    "172.16.0.1", "private",
    "192.168.1.1", "private",
    "169.254.1.1", "link_local",
    "169.254.169.254", "link_local",
    "0.0.0.1", "this_network",
    # RFC 6598 Shared Address Space. The guard files this under
    # `cloud-metadata`, which is wrong -- see section 11.10.
    "100.64.0.1", "shared"
  )
  got <- as.character(addr_category(addr_strict(want$address)))
  expect_identical(got, want$category)
})

test_that("the IPv6 blocks the guards match on carry the same categories", {
  want <- rows_table(
    c("address", "category"),
    "::1", "loopback",
    "::", "unspecified",
    "fe80::1", "link_local",
    "febf::1", "link_local",
    # The AWS metadata ULA the guard matches as `fd00:ec2::/32`. raddr sees the
    # RFC 4193 block it actually sits in; the metadata meaning is policy.
    "fd00:ec2::254", "private",
    "fc00::1", "private"
  )
  got <- as.character(addr_category(addr_strict(want$address)))
  expect_identical(got, want$category)

  # The guard's own bug-fix, restated structurally: `fd00:ec2::254` and
  # `fd00:0ec2::254` are one address, and a string match on the literal let the
  # second through. raddr compares addresses, so the two are equal by
  # construction rather than by a rule someone remembered to write.
  expect_true(addr_strict("fd00:ec2::254") == addr_strict("fd00:0ec2::254"))
})

# --- the embedding inventory -------------------------------------------------

test_that("raddr decodes every embedding form the guards decode", {
  # The guard's decoder inventory, one literal per form, with the embedded
  # address it must yield. This is the part of the guard that exists because a
  # blocklist cannot express it (three CVEs against pydantic-ai, one per
  # wrapper), so it is the part a migration must not lose.
  want <- rows_table(
    c("literal", "kind", "embedded"),
    "::ffff:192.0.2.1", "ipv4_mapped", "192.0.2.1",
    "::ffff:0:192.0.2.1", "ipv4_translated", "192.0.2.1",
    "::192.0.2.1", "ipv4_compatible", "192.0.2.1",
    "64:ff9b::192.0.2.1", "nat64_wk", "192.0.2.1",
    "2002:c000:201::", "6to4", "192.0.2.1",
    "fe80::5efe:192.0.2.1", "isatap", "192.0.2.1",
    # RFC 5214 section 6.1's second marker, with the u-bit set. The guard
    # accepts both spellings and so does raddr (RADD-mwjduppi).
    "2001:db8::200:5efe:192.0.2.1", "isatap", "192.0.2.1"
  )
  a <- addr_strict(want$literal)
  expect_identical(as.character(addr_embedded_kind(a)), want$kind)

  found <- vapply(addr_embeddings(a), function(e) {
    format(field(e, "address")[[1L]])
  }, character(1))
  expect_identical(found, want$embedded)
})

test_that("teredo yields the complemented client the guard decodes", {
  # The guard reads only the client, and reads it ones-complemented. raddr
  # reports both roles, so the migration has to pick the client row -- pinned
  # here so a change to the role vocabulary is caught.
  e <- addr_embeddings(addr_strict("2001:0:0:0:8000:ffff:3fff:fdfd"))[[1L]]
  client <- field(e, "address")[as.character(field(e, "role")) == "client"]
  expect_identical(format(client), "192.0.2.2")
})

# --- where the guard and raddr disagree, and why ------------------------------

test_that("a trailing colon is malformed under every dialect", {
  # The guard reads `::1:` as `::1` and `1:2:3:4:5:6:7:8:` as the full address,
  # because `strsplit()` drops a trailing empty field -- so its documented
  # fail-closed posture has a hole. No dialect raddr models accepts these, and
  # that is the fact a fix would be argued from.
  strays <- c("::1:", "::ffff:", "1:2:3:4:5:6:7:8:", "1::2:")
  p <- addr_parse(strays)

  expect_identical(
    as.character(addr_status(p)),
    rep("malformed", length(strays))
  )
  for (dialect in all_dialects) {
    expect_true(
      all(is.na(addr_family(addr_reading(p, dialect)))),
      info = dialect
    )
  }
})

test_that("a trailing dot is a divergence, not a defect", {
  # The other direction, and it is not the guard's mistake: `1.2.3.4.` is a
  # hostname carrying the DNS root label, and WHATWG reads it as an address
  # while the other five refuse. raddr reports the disagreement rather than
  # picking a side (P3), which is exactly the fact the guard needs and does not
  # currently have -- it agrees with WHATWG silently.
  p <- addr_parse(c("1.2.3.4.", "127.0.0.1."))
  expect_identical(as.character(addr_status(p)), c("divergent", "divergent"))
  expect_identical(
    format(addr_reading(p, "whatwg")),
    c("1.2.3.4", "127.0.0.1")
  )
  for (dialect in c("strict", "pton", "aton", "getaddrinfo", "curl")) {
    expect_true(
      all(is.na(addr_family(addr_reading(p, dialect)))),
      info = dialect
    )
  }
})

test_that("the obfuscation the guard greps for is a dialect disagreement", {
  # `ssrf_numeric_literal_blocked()` pattern-matches hex, raw-decimal and octal
  # authorities on the pre-normalization host. raddr answers the same question
  # structurally: a literal the lenient dialects read and `strict` refuses IS
  # the obfuscation, and it comes with the address each dialect saw.
  obfuscated <- c("0x7f.1", "2130706433", "0177.0.0.1", "010.0.0.1")
  p <- addr_parse(obfuscated)

  expect_true(all(is.na(addr_family(addr_reading(p, "strict")))))
  expect_false(any(is.na(addr_family(addr_reading(p, "aton")))))
  # And the canonical dotted-quad is NOT obfuscated, so the same rule does not
  # fire on it -- which is what makes the test above a discriminator.
  plain <- addr_parse("127.0.0.1")
  expect_false(is.na(addr_family(addr_reading(plain, "strict"))))
})
