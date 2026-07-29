# What the reality dialects look like on a libc that is not Apple's.
# Open items O6 and O6b, settled 2026-07-29; docs/architecture.md sections 3.1,
# 3.3 and 3.5.3.
#
# raddr models Apple libc and always will, because it is pure and offline: a
# dialect that varied with the host would make `addr_pton()` a different
# function on a different machine. So nothing here asserts raddr against glibc
# or musl. What it asserts is the *divergence set* -- which rows Apple and Linux
# disagree about, and why -- because those rows are the evidence behind the
# "platform-varying" label in section 3.1, and a label is worth no more than the
# measurement under it.
#
# Regenerate the fixtures with `sh data-raw/oracle-libc-linux.sh`, which needs
# Docker. The tests need only the committed files.

libc_fixture <- function(file) {
  d <- read.csv(
    test_path("fixtures", file),
    colClasses = "character", na.strings = NULL
  )
  d$literal <- unescape_control(d$input)
  d
}

apple_v4 <- function() libc_fixture("ipv4-libc.csv")
apple_v6 <- function() libc_fixture("ipv6-libc.csv")

# --- IPv4: the pton primitive ------------------------------------------------

test_that("glibc and musl inet_pton reject the zeros Apple reads as decimal", {
  # This is the O6 question, and the answer is the wider of the two it could
  # have been. Apple does not merely read `0177.0.0.1` as decimal 177 where the
  # standards reject it -- it *accepts* text glibc and musl refuse outright.
  # So the pton column of section 3.3 is not one dialect with a
  # platform-varying value; on Linux several rows are not a value at all.
  apple <- apple_v4()
  for (libc in c("glibc", "musl")) {
    linux <- libc_fixture(sprintf("ipv4-libc-%s.csv", libc))
    expect_identical(linux$input, apple$input, label = libc)
    diverged <- apple$input[apple$pton != linux$pton]
    expect_identical(
      diverged,
      c(
        "0177.0.0.1", "192.0.010.1", "192.0.048.1", "10.048.1.1",
        "00000000177.0.0.1", "0000000000000000001.0.0.1",
        "010.010.010.010", "0.0.0.010", "0177.0.0.01"
      ),
      label = libc
    )
    # Every one of them is a rejection there, not a different reading.
    gap <- apple$pton != linux$pton
    expect_true(all(!nzchar(linux$pton[gap])), label = libc)
  }
})

# --- IPv4: the aton primitive ------------------------------------------------

test_that("glibc and musl inet_aton refuse the overflow Apple wraps", {
  # Section 3.3 headlines `4294967296` as one of the two rows carrying most of
  # the package's value: aton wraps it to 0.0.0.0 where the standards reject it.
  # That wrap is Apple's. Linux rejects, which makes the row a three-way split
  # rather than a two-way one.
  apple <- apple_v4()
  wrapped <- c(
    "4294967296", "0x100000000", "0x.1", "0x.0x.0", "040000000000",
    "4294967297", "18446744073709551615", "18446744073709551616",
    "99999999999999999999999999", "0xffffffffffffffffff"
  )
  for (libc in c("glibc", "musl")) {
    linux <- libc_fixture(sprintf("ipv4-libc-%s.csv", libc))
    keep <- apple$input %in% wrapped
    expect_true(all(nzchar(apple$aton[keep])), label = libc)
    expect_true(all(!nzchar(linux$aton[keep])), label = libc)
  }
})

test_that("glibc inet_aton matches Apple on garbage; musl is the outlier", {
  # This test exists because the architecture document asserted the opposite,
  # unmeasured: that glibc "ignores trailing garbage outright" so `1.2.3.4x`
  # succeeds there, and that "Apple and musl reject it". Measured 2026-07-29,
  # both halves are wrong. glibc rejects glued garbage exactly as Apple does,
  # accepts whitespace-then-garbage exactly as Apple does, and it is *musl* that
  # is strict -- it rejects even a bare trailing space.
  apple <- apple_v4()
  glibc <- libc_fixture("ipv4-libc-glibc.csv")
  musl <- libc_fixture("ipv4-libc-musl.csv")

  # Whitespace truncates and the remainder is ignored -- on Apple and glibc.
  lenient <- c("1.2.3.4 ", "1.2.3.4  ", "1.2.3.4 x", "127.0.0.1 junk")
  keep <- apple$literal %in% lenient
  expect_identical(sum(keep), length(lenient))
  expect_identical(glibc$aton[keep], apple$aton[keep])
  expect_true(all(nzchar(apple$aton[keep])))
  expect_true(all(!nzchar(musl$aton[keep])))

  # Glued garbage is a rejection everywhere. No libc ignores it.
  glued <- apple$literal == "1.2.3.4x"
  expect_identical(sum(glued), 1L)
  expect_true(all(!nzchar(
    c(apple$aton[glued], glibc$aton[glued], musl$aton[glued])
  )))
})

test_that("the whitespace rows are the whole of the glibc-musl difference", {
  glibc <- libc_fixture("ipv4-libc-glibc.csv")
  musl <- libc_fixture("ipv4-libc-musl.csv")
  differs <- glibc$input[
    glibc$pton != musl$pton |
      glibc$aton != musl$aton |
      glibc$getaddrinfo != musl$getaddrinfo
  ]
  expect_true(all(grepl("[[:space:]]", unescape_control(differs))))
})

# --- IPv4: the composition, which is the part that does NOT vary -------------

test_that("getaddrinfo is pton-then-aton behind the gate on every libc", {
  # The positive result, and the one worth the most. Section 3.2 models
  # getaddrinfo as a precedence ordering over the two primitives, with the
  # whitespace refusal as a pre-step in front of it. Every primitive under that
  # algebra turned out to vary by platform -- and the algebra did not. The same
  # ten rows are the pre-step's on Apple and on glibc, and they are invisible on
  # musl only because musl's own aton has already rejected them.
  gated <- c(
    "1.2.3.4 ", "1.2.3.4\t", "1.2.3.4\r\n", "1.2.3.4  ", "1.2.3.4 x",
    "1.2 .3.4", "1 ", "127.0.0.1 junk", "1.2.3.4\v", "1.2.3.4\f"
  )
  fixtures <- c(
    apple = "ipv4-libc.csv",
    glibc = "ipv4-libc-glibc.csv",
    musl = "ipv4-libc-musl.csv"
  )
  for (libc in names(fixtures)) {
    d <- libc_fixture(fixtures[[libc]])
    derived <- ifelse(nzchar(d$pton), d$pton, d$aton)
    expect_identical(
      sort(d$literal[derived != d$getaddrinfo]),
      if (libc == "musl") character() else sort(gated),
      label = libc
    )
    # And the gate is a refusal, never a different answer.
    expect_true(all(!nzchar(d$getaddrinfo[d$literal %in% gated])), label = libc)
  }
})

# --- IPv6 --------------------------------------------------------------------

test_that("glibc and musl agree on every IPv6 row", {
  # Recorded because it is not obvious and it halves the surface: the two Linux
  # libcs split on IPv4 trailing whitespace and nowhere in IPv6.
  expect_identical(
    libc_fixture("ipv6-libc-glibc.csv"),
    libc_fixture("ipv6-libc-musl.csv")
  )
})

test_that("glibc and musl inet_pton reject leading zeros in IPv6 too", {
  # Section 3.5's "Apple inet_pton puts no width limit on leading zeros in a
  # hextet" is Apple's rule, in the hextets and in the dotted-quad tail alike.
  apple <- apple_v6()
  linux <- libc_fixture("ipv6-libc-glibc.csv")
  zeros <- c(
    "00001::", "1::00001", "1:2:3:4:5:6:7:00008", "01234::", "0abcd::",
    "0000000000001::", "::1.2.3.04", "::1.2.3.004", "::01.2.3.4",
    "::1.2.3.0000004", "::00000000001.2.3.4", "::1.02.3.4"
  )
  keep <- apple$input %in% zeros
  expect_identical(sum(keep), length(zeros))
  expect_true(all(nzchar(apple$pton[keep])))
  expect_true(all(!nzchar(linux$pton[keep])))
})

# --- The zone, the fold and the lift -----------------------------------------
#
# These four use zone-native-*.csv rather than the IPv6 corpus, and the reason
# is the whole point of that fixture: the corpus spells its zones `%lo0` and
# `%en0`, which are Apple interface names, so on Linux those rows measure the
# container's interface table and not glibc. The native probe substitutes each
# host's own loopback name, so both sides are asked about a name they have.

zone_native <- function(libc) {
  d <- read.csv(
    test_path("fixtures", sprintf("zone-native-%s.csv", libc)),
    colClasses = "character", na.strings = NULL
  )
  rownames(d) <- d$template
  d
}

test_that("glibc and musl inet_pton take no zone ID at all", {
  # Apple's accepts one and folds a resolvable interface index into the second
  # hextet (section 5.1). On Linux the fold cannot arise, because the syntax is
  # refused first. raddr reproduces neither, and section 3.5.3's reason for that
  # -- the fold reads the host's interface table, so it is not a function of the
  # input -- now has a second argument under it: it is not portable either.
  apple <- zone_native("apple")
  for (libc in c("glibc", "musl")) {
    d <- zone_native(libc)
    zoned <- grepl("%", d$input, fixed = TRUE)
    expect_true(all(!nzchar(d$pton[zoned])), label = libc)
    expect_true(all(nzchar(apple$pton[zoned])), label = libc)
  }
})

test_that("glibc and musl getaddrinfo do not lift an embedded scope", {
  # O6b's question, and its stated worst case. Apple's getaddrinfo takes the
  # second hextet of an fe80::/10 address as the scope ID and clears it from the
  # bytes, zone ID or no zone ID; raddr models that as a post-step, and
  # addr_curl() inherits it through the section 3.2 composition. Linux does no
  # such thing: fe80:abcd::1 stays fe80:abcd::1, at scope 0.
  #
  # So the lift is not a detail of the fe80::/10 boundary. It is the whole of
  # fe80::/10, and addr_getaddrinfo() and addr_curl() are Apple readings there.
  for (libc in c("glibc", "musl")) {
    d <- zone_native(libc)
    expect_identical(
      d["fe80:abcd::1", c("getaddrinfo", "gai_scope")],
      data.frame(
        getaddrinfo = "fe80:abcd:0000:0000:0000:0000:0000:0001",
        gai_scope = "0",
        row.names = "fe80:abcd::1"
      ),
      label = libc
    )
    # An explicit zone sets the scope and still leaves the hextet standing.
    expect_identical(d["fe80:abcd::1%{lo}", "gai_scope"], "1", label = libc)
    expect_identical(
      d["fe80:abcd::1%{lo}", "getaddrinfo"],
      "fe80:abcd:0000:0000:0000:0000:0000:0001",
      label = libc
    )
  }

  # Apple, for contrast: the hextet is consumed either way.
  apple <- zone_native("apple")
  expect_identical(apple["fe80:abcd::1", "gai_scope"], "43981") # 0xabcd
  expect_identical(
    apple["fe80:abcd::1", "getaddrinfo"],
    "fe80:0000:0000:0000:0000:0000:0000:0001"
  )
})

test_that("raddr's getaddrinfo is Apple's, diverging from Linux by the lift", {
  # Pins the consequence rather than restating the cause: this is the set of
  # readings a Linux user gets a different answer for from their own resolver.
  # It is named here so that widening or narrowing it is a visible diff.
  # The lifted hextet comes back as the zone rather than being dropped, so the
  # reading is lossless: 0xabcd is 43981, which is the scope Apple reports.
  lifted <- "fe80:0000:0000:0000:0000:0000:0000:0001%43981"
  expect_identical(addr_expand(addr_getaddrinfo("fe80:abcd::1")), lifted)
  expect_identical(addr_expand(addr_curl("fe80:abcd::1")), lifted)
  # Outside fe80::/10 the two platforms agree, so the divergence really is
  # bounded by the block and not by the dialect.
  outside_block <- c(
    "fe7f:abcd::1", "fec0:abcd::1", "ff02:abcd::1", "2001:abcd::1"
  )
  for (outside in outside_block) {
    expect_identical(
      addr_expand(addr_getaddrinfo(outside)),
      addr_expand(addr_strict(outside)),
      label = outside
    )
  }
})

test_that("Linux getaddrinfo zones only a scoped address, and a real name", {
  # Two more restrictions Apple does not have, recorded because they bound how
  # far the Linux reading of a zoned literal can be read across.
  for (libc in c("glibc", "musl")) {
    d <- zone_native(libc)
    # Link-local and multicast carry a zone; global, loopback and a full-arity
    # unicast address do not.
    expect_identical(d["fe80::1%{lo}", "gai_scope"], "1", label = libc)
    expect_identical(d["ff02::1%{lo}", "gai_scope"], "1", label = libc)
    unscoped_all <- c("2001:db8::1%{lo}", "::1%{lo}", "1:2:3:4:5:6:7:8%{lo}")
    for (unscoped in unscoped_all) {
      expect_false(
        nzchar(d[unscoped, "getaddrinfo"]),
        label = paste(libc, unscoped)
      )
    }
    # A name resolving nowhere is a rejection, wrong-case or outright.
    expect_false(nzchar(d["fe80::1%{LO}", "getaddrinfo"]), label = libc)
    expect_false(nzchar(d["fe80::1%bogus0", "getaddrinfo"]), label = libc)
  }

  # Apple accepts all five, which is what makes them a divergence rather than a
  # shared rule: an unresolvable name simply reports scope 0 there.
  apple <- zone_native("apple")
  for (accepted in c("2001:db8::1%{lo}", "::1%{lo}", "1:2:3:4:5:6:7:8%{lo}",
                     "fe80::1%{LO}", "fe80::1%bogus0")) {
    expect_true(nzchar(apple[accepted, "getaddrinfo"]), label = accepted)
  }
})
