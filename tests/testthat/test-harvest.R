# The test material the research sweep produced (RADD-izeebldt). See
# docs/architecture.md section 7.4, which is the prose half of this file.
#
# Three kinds of claim, and they fail differently:
#
#   - a registry invariant, machine-checkable over every row, which pins the
#     shape the repo chose for the five policy columns;
#   - longest-prefix-match cases that are each *wrong* under first-match-in-
#     file-order, so they fail loudly if the lookup ever regresses to a scan;
#   - boundary facts nobody had asserted either way, where an off-by-one in
#     prefix arithmetic silently swaps one protocol's semantics for another's.
#
# Every claim below was checked against the vendored snapshot before it was
# written down; the two normative ones were checked against the RFCs.

registry_blocks <- function() raddr_registry_data$blocks

class_of <- function(literal) addr_classify(addr_strict(literal))

block_of <- function(literal) field(class_of(literal), "block")

all_dialects <- c("strict", "whatwg", "pton", "aton", "getaddrinfo", "curl")

# --- the one cross-column rule RFC 6890 states -------------------------------

test_that("Destination = False implies no Forwardable, no Global", {
  # RFC 6890 section 2.2.1, and it is the ONLY cross-attribute rule the section
  # states: "If the value of 'Destination' is FALSE, the values of 'Forwardable'
  # and 'Global' must also be false." Lowercase "must" in a descriptive
  # sentence -- RFC 6890 does not invoke RFC 2119 for the attribute definitions,
  # so this is a consistency property of the registry, not a conformance
  # requirement on an implementation. Checked at the source, not from memory.
  blocks <- registry_blocks()
  says_no <- !is.na(blocks$destination) & !blocks$destination

  expect_false(any(says_no & !is.na(blocks$forwardable) & blocks$forwardable))
  expect_false(any(
    says_no & !is.na(blocks$globally_reachable) & blocks$globally_reachable
  ))

  # Not vacuous: rows on both sides of the implication exist.
  expect_gt(sum(says_no), 5L)
  expect_gt(sum(!is.na(blocks$destination) & blocks$destination), 5L)
})

test_that("no column is derivable from another, so none is the answer", {
  # RFC 6890 ties `Source` to nothing at all, and the four remaining columns
  # vary independently within what the one rule above allows. Section 4 of the
  # design record turns that into raddr's shape: five columns reported, no
  # single "is this usable" boolean synthesized from them. These six rows are
  # the evidence that any such boolean would be lossy.
  blocks <- registry_blocks()
  row_for <- function(block) blocks[match(block, blocks$block), ]

  # Source = FALSE with Destination = TRUE. The only row in the registry that
  # is written to but never from -- a broadcast is not a source address.
  broadcast <- row_for("255.255.255.255/32")
  expect_false(broadcast$source)
  expect_true(broadcast$destination)
  expect_identical(sum(!blocks$source & blocks$destination, na.rm = TRUE), 1L)

  # And five rows the other way round: usable as a source, never as a
  # destination. A single boolean cannot express both directions.
  never_a_destination <- c(
    "0.0.0.0/8", "0.0.0.0/32", "::/128", "192.0.0.8/32", "100:0:0:1::/64"
  )
  for (block in never_a_destination) {
    row <- row_for(block)
    expect_true(row$source, label = block)
    expect_false(row$destination, label = block)
  }

  # `reserved_by_protocol` is independent of the rest too: two of those five
  # rows carry it and two do not, on otherwise identical policy.
  reserved <- vapply(
    never_a_destination, function(b) row_for(b)$reserved_by_protocol,
    logical(1)
  )
  expect_true(any(reserved))
  expect_false(all(reserved))
})

test_that("a terminated row reports NA rather than a policy it no longer has", {
  # IANA prints nothing in the policy columns for a withdrawn allocation, and
  # raddr keeps that as NA rather than reading the blank as FALSE (section 7.1).
  # Two rows, and this is the shape the whole "facts, not verdicts" position
  # rests on -- a blank is not a denial.
  blocks <- registry_blocks()
  withdrawn <- blocks[!is.na(blocks$termination_date), ]

  expect_identical(
    sort(withdrawn$block), sort(c("192.88.99.0/24", "2001:10::/28"))
  )
  policy <- c("source", "destination", "forwardable", "globally_reachable")
  for (column in policy) {
    expect_true(all(is.na(withdrawn[[column]])), label = column)
  }
})

# --- longest prefix match, where file order gives a different answer ----------
#
# Every case here is wrong under "first match in file order", which is what a
# naive scan over the registry CSV produces. Section 11.1.6 replaced the walk
# with blocks grouped by prefix length; these are the answers that pin it.

test_that("the ends of the IPv4 space resolve to their /32, not their prefix", {
  # 0.0.0.0 sits in both 0.0.0.0/8 and 0.0.0.0/32, and the /32 is listed
  # second. 255.255.255.255 sits in both 240.0.0.0/4 and its own /32, and the
  # two differ in `destination` -- so this is not a cosmetic preference for the
  # longer name, it changes the reported policy.
  expect_identical(block_of("0.0.0.0"), "0.0.0.0/32")
  expect_identical(block_of("0.0.0.1"), "0.0.0.0/8")

  expect_identical(block_of("255.255.255.255"), "255.255.255.255/32")
  expect_identical(block_of("255.255.255.254"), "240.0.0.0/4")

  expect_false(field(class_of("240.0.0.0"), "destination"))
  expect_true(field(class_of("255.255.255.255"), "destination"))
})

test_that("a live /32 does not inherit the terminated /24 around it", {
  # 192.88.99.0/24 was withdrawn in 2015 and its policy columns are blank;
  # 192.88.99.2/32 is a live 6a44 relay anycast address inside it. Under file
  # order the /24 wins and the live row's policy disappears behind a row that
  # has none.
  expect_identical(block_of("192.88.99.2"), "192.88.99.2/32")
  expect_identical(block_of("192.88.99.1"), "192.88.99.0/24")
  expect_identical(block_of("192.88.99.3"), "192.88.99.0/24")

  expect_true(field(class_of("192.88.99.2"), "destination"))
  expect_true(is.na(field(class_of("192.88.99.1"), "destination")))
})

test_that("100::/64 and 100:0:0:1::/64 are a hex digit and a policy apart", {
  # Discard-Only against the Dummy Prefix. They differ in `destination`, and
  # nothing but the fourth hextet distinguishes the two literals.
  expect_identical(block_of("100::1"), "100::/64")
  expect_identical(block_of("100:0:0:1::1"), "100:0:0:1::/64")

  expect_true(field(class_of("100::1"), "destination"))
  expect_false(field(class_of("100:0:0:1::1"), "destination"))
})

test_that("5f00::/16 is found inside the reserved 4000::/3 that contains it", {
  # SRv6 SIDs (RFC 9602) nest inside a block the address-space registry calls
  # "Reserved by IETF". Only a longest-prefix match returns the inner one, and
  # the outer one is in a different registry (section 7.3), so this also pins
  # the layering: special-purpose outranks address-space by IANA's own note.
  expect_identical(block_of("5f00::1"), "5f00::/16")
  expect_true(addr_within(addr_strict("5f00::1"), "4000::/3"))

  expect_identical(
    as.character(field(class_of("5f00::1"), "registry")), "special_purpose"
  )
  expect_identical(block_of("4000::1"), "4000::/3")
  expect_identical(
    as.character(field(class_of("4000::1"), "registry")), "address_space"
  )
})

# --- boundaries, asserted in both directions ---------------------------------

test_that("192.0.0.0/29 is .0 through .7 and nothing else", {
  # Five protocols live immediately above the /29, each with its own row and
  # its own policy. An off-by-one in the prefix arithmetic swaps them silently,
  # because every one of these addresses matches *something* either way.
  for (host in 0:7) {
    expect_identical(block_of(sprintf("192.0.0.%d", host)), "192.0.0.0/29")
  }

  outside <- c(
    "192.0.0.8" = "192.0.0.8/32",
    "192.0.0.9" = "192.0.0.9/32",
    "192.0.0.10" = "192.0.0.10/32",
    "192.0.0.170" = "192.0.0.170/32",
    "192.0.0.171" = "192.0.0.171/32",
    "192.0.0.11" = "192.0.0.0/24"
  )
  for (literal in names(outside)) {
    expect_identical(block_of(literal), outside[[literal]], label = literal)
  }
})

test_that("the /29 widens a permission its own /24 denies", {
  # `forwardable` is FALSE for 192.0.0.0/24 and TRUE for the 192.0.0.0/29
  # inside it. A more-specific block that *grants* what its parent withholds is
  # the reason containment cannot be shortcut to "the shortest match decides".
  expect_false(field(class_of("192.0.0.11"), "forwardable"))
  expect_true(field(class_of("192.0.0.1"), "forwardable"))

  # And neither is globally reachable, so the widening is real but bounded.
  expect_false(field(class_of("192.0.0.11"), "globally_reachable"))
  expect_false(field(class_of("192.0.0.1"), "globally_reachable"))
})

test_that("2001:db8::/32 is not inside 2001::/23", {
  # The /23 spans 2001:0000:: through 2001:01ff:ffff:..., which stops well short
  # of 2001:0db8::. Reading the /23 as "everything under 2001:" is the mistake,
  # and it would fold the documentation prefix into IETF protocol assignments.
  expect_false(addr_within(addr_strict("2001:db8::1"), "2001::/23"))
  expect_identical(block_of("2001:db8::1"), "2001:db8::/32")

  # Both edges of the /23, from the inside and from the outside.
  expect_true(addr_within(addr_strict("2001::"), "2001::/23"))
  expect_true(addr_within(
    addr_strict("2001:1ff:ffff:ffff:ffff:ffff:ffff:ffff"), "2001::/23"
  ))
  expect_false(addr_within(addr_strict("2001:200::"), "2001::/23"))
})

test_that("the benchmarking prefix is 2001:2::/48 and not 2001:200::/48", {
  # RFC 5180 section 8 as printed names 2001:0200::/48; Errata ID 1752
  # (Verified, 2009-04-27) corrects it to 2001:0002::/48, because the printed
  # prefix was never in the RFC 4773 pool. 2001:200::/48 is real, allocated,
  # globally routed APNIC space, so matching it would be worse than a typo.
  expect_identical(block_of("2001:2::1"), "2001:2::/48")
  expect_identical(
    as.character(field(class_of("2001:2::1"), "category")), "benchmarking"
  )

  expect_identical(block_of("2001:200::1"), "2000::/3")
  expect_identical(
    as.character(field(class_of("2001:200::1"), "category")), "global"
  )
})

# --- corpus literals the fixtures do not carry -------------------------------
#
# From docs/research/delta-c-parsers.md. Each is a real divergence, a real CVE,
# or a real bypass, and none of them had a row anywhere until now.

test_that("the RFC 6874 percent-encoded zone spelling is not decoded", {
  # `fe80::a%25en1` is how RFC 6874 spelled a zone inside a URI, and RFC 9844
  # obsoleted that. raddr is not a URI parser, so it never percent-decodes: the
  # zone here is the literal text "25en1", not "en1". Two dialects, so the
  # claim is about the zone grammar and not about one parser.
  for (literal in c("fe80::a%25en1", "fe80::1%25lo0")) {
    parsed <- addr_pton(literal)
    expect_identical(addr_zone(parsed), sub("^[^%]*%", "", literal))
    expect_false(is.na(addr_family(parsed)))
  }
  expect_identical(addr_zone(addr_pton("fe80::a%25en1")), "25en1")

  # The paper dialects have no zone at all, whatever it is spelled like.
  expect_true(is.na(addr_strict("fe80::a%25en1")))
  expect_true(is.na(addr_whatwg("fe80::a%25en1")))
})

test_that("the zone runs to the end of the string, delimiters included", {
  # The NCC and OpenJDK zone-boundary case: implementations that truncate the
  # zone at `]`, whitespace or a quote read a different host from ones that do
  # not. Apple's inet_pton takes everything after the first "%" (section 5.1),
  # so raddr does too, and the address is `::1` regardless.
  literal <- "::1%1]foo.bar baz'\""
  parsed <- addr_pton(literal)

  expect_identical(addr_zone(parsed), "1]foo.bar baz'\"")
  expect_true(addr_pton("::1") == parsed)
  expect_identical(
    as.character(field(addr_classify(parsed), "category")), "loopback"
  )

  # getaddrinfo's whitespace gate covers the address, not the zone, so a space
  # after the "%" does not reject the literal (section 3.2).
  expect_false(is.na(addr_getaddrinfo(literal)))
  expect_true(is.na(addr_getaddrinfo("::1 %lo0")))
})

test_that("one literal may mix radixes across its parts", {
  # `0x8.0X8.010.8` is hex, hex, octal and decimal in one address: nothing says
  # the parts share a radix, because each is read by a separate base-0 strtoul.
  # All four spellings are 8, so the address is 8.8.8.8 under the dialects that
  # take radix prefixes at all.
  expect_identical(format(addr_whatwg("0x8.0X8.010.8")), "8.8.8.8")
  expect_identical(format(addr_aton("0x8.0X8.010.8")), "8.8.8.8")
  expect_identical(format(addr_curl("0x8.0X8.010.8")), "8.8.8.8")

  # And the decimal-only dialects reject it outright rather than reading 0x8 as
  # a zero followed by junk.
  expect_true(is.na(addr_strict("0x8.0X8.010.8")))
  expect_true(is.na(addr_pton("0x8.0X8.010.8")))
})

test_that("0129.0.0.1 divides the dialects the way CVE-2021-29418 did", {
  # An invalid octal digit in the FIRST part. `9` is not an octal digit, so a
  # parser that reads the leading zero as a radix marker must reject; one that
  # ignores leading zeros reads 129. netmask read it as 0.0.0.1 and lost the
  # first part entirely, which is the CVE.
  expect_true(is.na(addr_whatwg("0129.0.0.1")))
  expect_true(is.na(addr_aton("0129.0.0.1")))
  expect_true(is.na(addr_strict("0129.0.0.1")))

  expect_identical(format(addr_pton("0129.0.0.1")), "129.0.0.1")
  expect_identical(format(addr_curl("0129.0.0.1")), "129.0.0.1")

  # Whatever the reading, it is never 0.0.0.1 and never 127.0.0.1.
  readings <- vapply(
    all_dialects, function(d) format(dialect_fn(d)("0129.0.0.1")), character(1)
  )
  expect_false(any(readings %in% c("0.0.0.1", "127.0.0.1"), na.rm = TRUE))
})

test_that("an embedded address is reported beside the block, not for it", {
  # Three mechanisms, three exploit strings, and in every one the outer block
  # and the inner address disagree about how dangerous the address is. Section
  # 8.1's whole position is that raddr reports both rather than collapsing them.
  cases <- list(
    # 6to4 carrying 127.0.0.1 -- the Symfony CVE-2026-48736 string.
    list(literal = "2002:7f00:1::", block = "2002::/16", kind = "6to4",
         inner = "127.0.0.1", category = "loopback"),
    # The NAT64 well-known prefix carrying 10.0.0.1: the prefix is globally
    # reachable and the payload is private, simultaneously.
    list(literal = "64:ff9b::a00:1", block = "64:ff9b::/96", kind = "nat64_wk",
         inner = "10.0.0.1", category = "private"),
    # IPv4-mapped link-local -- the cloud metadata bypass every surveyed guard
    # misses, because it looks like an IPv6 address and behaves like 169.254.
    list(literal = "::ffff:169.254.169.254", block = "::ffff:0:0/96",
         kind = "ipv4_mapped", inner = "169.254.169.254",
         category = "link_local")
  )

  for (case in cases) {
    parsed <- addr_pton(case$literal)
    classified <- addr_classify(parsed)

    expect_identical(
      field(classified, "block"), case$block, label = case$literal
    )
    expect_identical(
      as.character(field(classified, "embedded_kind")), case$kind,
      label = case$literal
    )

    embedding <- addr_embeddings(parsed)[[1L]]
    expect_identical(
      addr_format(field(embedding, "address")), case$inner, label = case$literal
    )
    expect_identical(
      as.character(field(embedding, "category")), case$category,
      label = case$literal
    )
  }
})

test_that("100.100.100.200 is shared address space and nothing narrower", {
  # Alibaba's metadata endpoint sits inside CGNAT, outside every link-local
  # rule a guard written against 169.254.0.0/16 would apply. raddr has no
  # opinion about metadata endpoints (section 1.1) -- what it must not do is
  # report the address as global.
  classified <- class_of("100.100.100.200")

  expect_identical(field(classified, "block"), "100.64.0.0/10")
  expect_identical(as.character(field(classified, "category")), "shared")
  expect_false(field(classified, "globally_reachable"))
  expect_true(field(classified, "forwardable"))
})

test_that("a bracketed literal is not an address", {
  # `[::]` is URL authority syntax, and stripping the brackets is the URL
  # layer's job. raddr parses address literals (section 1.1), so every dialect
  # rejects it -- including the WHATWG one, whose host parser sees the brackets
  # removed before the IPv6 parser runs.
  for (dialect in all_dialects) {
    expect_true(is.na(dialect_fn(dialect)("[::]")), label = dialect)
    expect_true(is.na(dialect_fn(dialect)("[::1]")), label = dialect)
  }
  expect_false(is.na(addr_strict("::")))
})

test_that("trailing junk is rejected by every dialect raddr models", {
  # `1.2.3.4junk` is the one row in this harvest raddr cannot settle: glibc
  # accepts it and Apple and musl reject it, and the fixture records Apple
  # only. So this asserts what raddr's model actually claims -- rejection
  # everywhere -- rather than a divergence it has not measured. RADD-xrgomyhx
  # is the Docker run that would give the fixture a per-libc column; until it
  # lands, a passing test here is a statement about Apple and nothing else.
  for (dialect in all_dialects) {
    expect_true(is.na(dialect_fn(dialect)("1.2.3.4junk")), label = dialect)
  }
  # `inet_aton` stops at whitespace, though, so the space form is an address to
  # it and to curl -- the same string one character apart.
  expect_identical(format(addr_aton("1.2.3.4 junk")), "1.2.3.4")
  expect_true(is.na(addr_getaddrinfo("1.2.3.4 junk")))
})
