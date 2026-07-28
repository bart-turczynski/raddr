# The WHATWG URL host corpus (RADD-xdgfyznt). See docs/architecture.md
# section 12.1 for the licence mechanics and data-raw/vendor-wpt.R for how the
# CSV below is derived from the vendored upstream bytes.
#
# What this file is for, stated narrowly, because the corpus invites a broader
# claim than it can support: WPT tests a URL PARSER, and raddr is not one. Every
# row here is a whole URL whose answer covers the scheme, the authority, the
# port and the path at once. Only some of that answer is about the host, and
# only some of the host answer is about addresses.
#
# So the corpus is read through its `expect` column, which records what WPT's
# own output reveals rather than whether the row passed:
#
#   ipv4 / ipv6  the URL parser reached an address parser and serialized an
#                address -- raddr must reach the SAME address
#   regname      the URL parser reached no address parser at all -- raddr must
#                decline, because a reg-name is a valid host and not an address
#   url-failure  the URL failed -- raddr must decline too, except where the
#                failure provably belongs to the port rather than the host
#
# The addresses are compared AS ADDRESSES and not as text. WPT's serializer and
# RFC 5952 disagree about exactly one form, and pinning the corpus to text would
# turn that one disagreement into 17 unrelated failures.

wpt_corpus <- function() {
  d <- read.csv(
    test_path("fixtures", "wpt-hosts.csv"),
    colClasses = "character",
    na.strings = ""
  )
  d$pct_encoded <- d$pct_encoded == "TRUE"
  d
}

# Brackets are URL syntax, not address syntax: they are how a URL authority
# tells a colon in an IPv6 literal from the colon before a port. raddr parses
# the address, so the brackets come off first.
unbracket <- function(x) sub("^\\[(.*)\\]$", "\\1", x)

# Rows whose bytes raddr and WPT do not both see. A percent-encoded host is
# decoded by the URL parser before any address parser runs, so raddr is reading
# different characters; asserting over these would measure a decoder raddr
# deliberately does not have.
comparable <- function(d, kinds) {
  d[d$expect %in% kinds & !d$pct_encoded, , drop = FALSE]
}

test_that("the corpus is present, pinned, and covers both readings", {
  d <- wpt_corpus()

  # A corpus that silently shrank to nothing would make every test below pass.
  expect_gt(nrow(d), 100)
  expect_setequal(unique(d$source), c("wpt", "raddr"))
  expect_setequal(
    unique(d$expect), c("ipv4", "ipv6", "regname", "url-failure")
  )
  # Both address readings are represented from both sources, which is what
  # makes the two assertions below non-vacuous.
  expect_gt(nrow(comparable(d, "ipv4")), 20)
  expect_gt(nrow(comparable(d, "ipv6")), 10)
  for (src in c("wpt", "raddr")) {
    rows <- d[d$source == src, , drop = FALSE]
    expect_true(any(rows$expect == "ipv4"), label = paste(src, "has ipv4"))
    expect_true(any(rows$expect == "ipv6"), label = paste(src, "has ipv6"))
  }

  # The BSD-3 material and raddr's own MIT additions are separable in the data,
  # which is the claim inst/COPYRIGHTS makes about the directory split. If this
  # fails, that file is asserting something no longer true.
  expect_true(file.exists(test_path("fixtures", "wpt", "urltestdata.json")))
  expect_true(
    file.exists(test_path("fixtures", "raddr_extra_urltestdata.json"))
  )
})

test_that("addr_whatwg() reaches WPT's address, on every row that has one", {
  d <- comparable(wpt_corpus(), c("ipv4", "ipv6"))

  # Both sides go through the same parser, and that is deliberate. The
  # comparison is not "does raddr render what WPT rendered" -- it is "does
  # raddr's reading of a hostile spelling equal its reading of the canonical
  # form WPT says that spelling means". The hostile side is where the work is;
  # the canonical side is a plain dotted quad or plain hextets, which no parser
  # gets wrong, so agreement here cannot be vacuous.
  got <- addr_whatwg(unbracket(d$host))
  want <- addr_whatwg(unbracket(d$hostname))

  expect_false(any(is.na(addr_family(want))))
  expect_equal(got, want)
})

test_that("addr_whatwg() declines a reg-name, a host that is not an address", {
  d <- comparable(wpt_corpus(), "regname")

  # `0x7f.0.0.0x7g` ends in something that looks like a number and is not one,
  # so WHATWG's gate lets it through to the IPv4 parser, which rejects it -- and
  # the URL parser then keeps it as a reg-name and succeeds. raddr has no
  # reg-name concept, so NA is the whole of the answer it can give, and it is
  # the right one. Reading this row's success as "raddr must parse it" is the
  # mistake RADD-cdmoeadr found waiting for anyone delegating rurl's host layer.
  expect_true(all(is.na(addr_family(addr_whatwg(unbracket(d$host))))))
})

test_that("WPT's serializer and RFC 5952 disagree only on the v4-mapped form", {
  d <- comparable(wpt_corpus(), c("ipv4", "ipv6"))

  rendered <- format(addr_whatwg(unbracket(d$host)))
  divergent <- d$host[rendered != unbracket(d$hostname)]

  # RFC 5952 section 5 says a v4-mapped address SHOULD be written with the
  # dotted quad; the WHATWG host serializer has no such case and prints the
  # hextets. Both are right about their own specification, so raddr reports what
  # RFC 5952 asks for and this test states the difference rather than hiding it.
  # Pinned as an exact set: a NEW divergence is a regression, and it would
  # otherwise arrive looking like this known one.
  expect_equal(divergent, "[::ffff:127.0.0.1]")
  expect_equal(format(addr_whatwg("::ffff:127.0.0.1")), "::ffff:127.0.0.1")

  # And the disagreement really is only about text. The two spellings are the
  # same address, which is why the test above can compare readings and pass.
  expect_equal(addr_whatwg("::ffff:127.0.0.1"), addr_whatwg("::ffff:7f00:1"))
})

test_that("raddr declines the URL failures, bar the one with a bad port", {
  d <- wpt_corpus()
  failures <- comparable(d, "url-failure")
  expect_gt(nrow(failures), 50)

  # THIS is where the corpus earns its keep, and it took a mutation run to
  # notice. The success rows compare raddr's reading of a hostile spelling
  # against its reading of the canonical form, so a parser that is too
  # PERMISSIVE sails through them: widening the last part's bound past 255, or
  # the hex width past 8 digits, changes no success row, because every one is an
  # address under both the correct and the widened rule. Both mutations were run
  # and both survived every other test in this file. The rows that catch them
  # are the ones that must NOT parse.
  #
  # A URL failure is not by itself a host verdict -- WPT fails
  # `http://[1::2]:3:4` on the port ":3:4" while its host is well formed -- so
  # the exceptions are pinned as an exact set rather than waved at. Exact in
  # both directions: a row LEAVING the set means raddr started rejecting a good
  # host, and a row entering it means raddr started accepting a bad one. That
  # is RADD-aitbetjb's bidirectional rot check in miniature, over one class; the
  # general version, over the whole 267-row expected-failure set and with
  # unmatched-entry detection, is that ticket's job.
  port_at_fault <- "http://[1::2]:3:4"

  read <- !is.na(addr_family(addr_whatwg(unbracket(failures$host))))
  expect_equal(failures$input[read], port_at_fault)

  # And the exception is an exception for the stated reason: the host really is
  # well formed, so declining it would be the bug.
  expect_equal(format(addr_whatwg("1::2")), "1::2")

  # Over the whole class, percent-encoded rows included: raddr never errors.
  # Totality is the invariant suite's property (P2), restated here because a
  # corpus of URL failures is the input most likely to break it.
  all_failures <- d[d$expect == "url-failure", , drop = FALSE]
  expect_no_error(addr_whatwg(unbracket(all_failures$host)))
  expect_no_error(addr_parse(unbracket(all_failures$host)))
})

test_that("raddr's own additions carry the readings WPT has no row for", {
  d <- wpt_corpus()
  extra <- d[d$source == "raddr", , drop = FALSE]

  # These are the gaps measured in the vendored file, not imagined ones: at wpt
  # 181476a no input contains 2147483648, 0x80000000, fe80, ::ffff:, 64:ff9b or
  # 2002:. If an upstream re-sync starts covering them, this test still passes
  # -- the rows are raddr's either way -- but the justification in
  # raddr_extra_urltestdata.json should then be re-measured.
  expect_true(all(c("2147483648", "0x80000000") %in% extra$host))

  # The sign bit, which is NA_integer_ in an R word and the reason this package
  # carries a regression test at all (RADD-jrfprxyv).
  expect_equal(format(addr_whatwg("0x80000000")), "128.0.0.0")
  expect_equal(addr_whatwg("0x80000000"), addr_whatwg("2147483648"))

  # A zone is legal in a getaddrinfo literal and is NOT legal in a URL host, in
  # either spelling. Measured against Node v26.3.1 (ada), which fails both.
  zoned <- extra[grepl("%", extra$host, fixed = TRUE), , drop = FALSE]
  expect_equal(nrow(zoned), 2L)
  expect_true(all(zoned$expect == "url-failure"))
  expect_true(all(is.na(addr_family(addr_whatwg(unbracket(zoned$host))))))

  # The same zone, through the dialect that does admit one, keeps it beside the
  # bits rather than in them (O2, section 5.1). It survives on the record and
  # stays out of `==`, which is the surface the invariant is about -- comparing
  # the records themselves would compare the zone field too and assert the
  # opposite of what O2 says.
  expect_equal(addr_zone(addr_pton("fe80::1%eth0")), "eth0")
  expect_true(addr_pton("fe80::1%eth0") == addr_pton("fe80::1"))
})
