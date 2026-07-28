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

# The expected-failure record: every place raddr and the corpus disagree, with
# the disagreement argued for once (RADD-aitbetjb). The file itself carries the
# grammar and the arguments; this reads it, and the rot check below is what
# stops it from becoming a wish list.
expected_failures <- function() {
  lines <- readLines(test_path("fixtures", "expected_failures.txt"))
  lines <- lines[!grepl("^[[:space:]]*(#|$)", lines)]
  fields <- regmatches(
    lines, regexec("^(\\S+)\\s+(\\S+)\\s+(\\S.*\\S|\\S)$", lines)
  )
  # An unparseable line is a silent exemption if it is skipped, so it stops the
  # suite instead.
  if (any(lengths(fields) != 4L)) {
    stop("unparseable expected_failures.txt line(s):\n  ",
         paste(lines[lengths(fields) != 4L], collapse = "\n  "))
  }
  field <- function(i) vapply(fields, `[`, character(1), i)
  data.frame(
    class = field(2L), subject = field(3L), detail = field(4L),
    stringsAsFactors = FALSE
  )
}

# The corpus is keyed by (source, input): see the file's header for why not by
# index. A single space joins them because `source` is "wpt" or "raddr" and
# neither contains one, so the key stays unambiguous while printing legibly
# when a check fails.
corpus_key <- function(source, input) paste(source, input)

# Rows a class of the record exempts from a given check.
without <- function(d, classes) {
  e <- expected_failures()
  e <- e[e$class %in% classes, , drop = FALSE]
  keys <- corpus_key(d$source, d$input)
  d[!keys %in% corpus_key(e$subject, e$detail), , drop = FALSE]
}

# Rows of the readings named, minus the ones the record excuses. Percent-encoded
# rows are no longer dropped wholesale: a host the URL parser decodes before any
# address parser runs is text raddr never sees, but only two of the six rows
# actually turn on that, and the other four were getting a free pass.
comparable <- function(d, kinds) {
  without(
    d[d$expect %in% kinds, , drop = FALSE],
    c("reads-failed-url", "declines-pct-encoded")
  )
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
  divergent <- corpus_key(d$source, d$input)[rendered != unbracket(d$hostname)]

  # RFC 5952 section 5 says a v4-mapped address SHOULD be written with the
  # dotted quad; the WHATWG host serializer has no such case and prints the
  # hextets. Both are right about their own specification, so raddr reports what
  # RFC 5952 asks for and the record states the difference rather than hiding
  # it. Pinned as an exact set, from the record rather than from a literal here:
  # a NEW divergence is a regression, and it would otherwise arrive looking like
  # this known one.
  e <- expected_failures()
  e <- e[e$class == "format-divergence", , drop = FALSE]
  expect_setequal(divergent, corpus_key(e$subject, e$detail))
  expect_equal(format(addr_whatwg("::ffff:127.0.0.1")), "::ffff:127.0.0.1")

  # And the disagreement really is only about text. The two spellings are the
  # same address, which is why the test above can compare readings and pass.
  expect_equal(addr_whatwg("::ffff:127.0.0.1"), addr_whatwg("::ffff:7f00:1"))
})

test_that("raddr declines every URL failure the record does not excuse", {
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
  # `http://[1::2]:3:4` on the port ":3:4" while its host is well formed. So the
  # exceptions live in expected_failures.txt, each with its reason, and this
  # test asserts over what is left: no exceptions at all.
  read <- !is.na(addr_family(addr_whatwg(unbracket(failures$host))))
  expect_equal(failures$input[read], character())

  # And the one exception is an exception for the stated reason: the host really
  # is well formed, so declining it would be the bug.
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

# --- the expected-failure record ---------------------------------------------

test_that("every entry in the record names a row the corpus still has", {
  d <- wpt_corpus()
  e <- expected_failures()

  # A closed vocabulary, so a typo in a class name cannot invent an exemption
  # nothing checks. `without()` matches on the class, and a misspelt class
  # matches nothing and therefore excuses nothing -- which would be silent were
  # it not for this.
  #
  # One direction only. Requiring every known class to still be POPULATED would
  # mean that fixing the last divergence in a class turns the suite red until
  # someone re-adds an entry, which is the exact opposite of what this file is
  # for: an empty class is the good outcome.
  known <- c("reads-failed-url", "declines-pct-encoded", "format-divergence",
             "extractor-refusal")
  expect_equal(setdiff(unique(e$class), known), character())

  # (source, input) has to be a key, or "the row this entry names" is not a
  # question with one answer.
  keys <- corpus_key(d$source, d$input)
  expect_equal(anyDuplicated(keys), 0L)

  # LEFTOVERS. An entry naming a row the corpus no longer has stops exempting
  # anything the moment the row leaves, and nothing else notices: the suite goes
  # on passing, and the entry sits there looking like live coverage. This is the
  # direction an upstream re-sync breaks, and the reason the key is the input
  # rather than the index -- a renumbering must not read as 128 departures.
  rows <- e[e$class != "extractor-refusal", , drop = FALSE]
  listed <- corpus_key(rows$subject, rows$detail)
  expect_equal(listed[!listed %in% keys], character())
})

test_that("the record is exact in both directions on every reading", {
  d <- wpt_corpus()
  rows <- expected_failures()
  rows <- rows[rows$class != "extractor-refusal", , drop = FALSE]
  keys <- corpus_key(d$source, d$input)

  # The naive expectation, over the WHOLE corpus and with nothing excluded:
  # raddr reaches an address exactly where WPT's output shows one. Every
  # departure from that has to be written down, and only the departures.
  read <- !is.na(addr_family(addr_whatwg(unbracket(d$host))))
  want_read <- d$expect %in% c("ipv4", "ipv6")

  # Each class names a direction, and the direction is checked too: filing a row
  # under the wrong class would otherwise buy the same exemption for free.
  observed <- list(
    "reads-failed-url" = keys[read & !want_read],
    "declines-pct-encoded" = keys[!read & want_read]
  )

  # The class is pasted onto the reported rows so a failure says which claim
  # broke without the reader going to the line numbers. paste() recycles a
  # zero-length vector up to length one, which would turn every clean run into a
  # failure, hence the guard.
  tagged <- function(cls, x) {
    if (length(x)) paste0(cls, ": ", x) else character()
  }

  for (cls in names(observed)) {
    stated <- corpus_key(rows$subject, rows$detail)[rows$class == cls]
    # A REGRESSION: raddr disagrees with WPT on a row nobody argued for.
    expect_equal(tagged(cls, setdiff(observed[[cls]], stated)), character())
    # An UNEXPECTED SUCCESS: raddr agrees now, so the entry is stale. Reported
    # apart from the regression because it calls for the opposite action --
    # delete the entry, do not fix the parser.
    expect_equal(tagged(cls, setdiff(stated, observed[[cls]])), character())
  }

  # Non-vacuity: there have to be rows with an address in them for the check to
  # be a check at all, and this file's whole subject is a record that quietly
  # stopped meaning anything.
  expect_gt(sum(want_read), 30)
})

test_that("every extractor refusal is accounted for, by rule and by count", {
  stated <- expected_failures()
  stated <- stated[stated$class == "extractor-refusal", , drop = FALSE]

  # The suite cannot re-derive these: they are a fact about the JSON, and
  # reading JSON needs a parser raddr does not depend on (section 11.7). What it
  # can do is hold the hand-written account against the GENERATED one.
  # vendor-wpt.R counts each refusal under the rule that caused it, and
  # `vendor-wpt.R --check` re-derives that table from the vendored bytes and
  # fails on drift. So the chain closes: the bytes fix the CSV, and this fixes
  # the account against the CSV.
  derived <- read.csv(
    test_path("fixtures", "wpt-refusals.csv"),
    colClasses = c("character", "integer")
  )
  expect_gt(nrow(derived), 0L)
  expect_true(all(derived$count > 0L))

  # Both directions again. A rule stated here that no longer fires is a
  # leftover; a rule that fires without an entry here is a refusal nobody
  # argued for, and the refusals are what the corpus does not cover.
  expect_setequal(stated$subject, derived$rule)
  expect_equal(
    as.integer(stated$detail[order(stated$subject)]),
    derived$count[order(derived$rule)]
  )
})
