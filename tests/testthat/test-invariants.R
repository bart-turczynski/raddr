# Properties that hold for every address, asserted over a corpus rather than
# over named examples. See docs/architecture.md sections 6.2.1 and 6.5.
#
# Nothing here needs an oracle. Each test states a relationship the package is
# supposed to keep between two surfaces that are implemented separately, so it
# fails when either one drifts -- which is the kind of breakage the per-function
# files cannot see, because each of them is only ever looking at one surface.
#
# Two corpora, and they answer different questions. The address corpus below is
# for properties of addresses; `corpus_literals()` in helper-corpus.R is the
# hostile text, and it is what the totality claims are asserted over -- a parser
# is only interestingly total on input nobody meant it to read.

# `all_dialects` lives in helper-dialects.R, next to `dialect_fn()`.

# Random bytes of both widths, so the corpus reaches parts of the space no
# hand-written literal does, plus the literals that are hazards in their own
# right: both ends of both families, the 4-in-6 forms, and a zoned address.
invariant_corpus <- local({
  set.seed(60221L)
  draw <- function(n, width) {
    lapply(seq_len(n), function(i) as.raw(sample(0:255, width, replace = TRUE)))
  }
  c(
    bytes_to_addr(draw(200L, 4L)),
    bytes_to_addr(draw(200L, 16L)),
    addr_pton(c(
      "0.0.0.0", "255.255.255.255", "128.0.0.0", "0.0.0.1", "10.2.0.52",
      "::", "::1", "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "8000::", "::8000:0", "7fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
      "2001:db8::1", "fe80::1%eth0", "::ffff:192.0.2.1", "::192.0.2.1",
      "64:ff9b::192.0.2.33"
    ))
  )
})

test_that("all four encodings decode to the same address", {
  # The four pairs share `words_to_addr()` and nothing else: the integer pair
  # does base-10^6 arithmetic, the other three read octets. Agreement between
  # them is the strongest statement available without an external oracle.
  a <- invariant_corpus
  from_integer <- integer_to_addr(addr_to_integer(a), addr_family(a))
  from_hex <- hex_to_addr(addr_to_hex(a))
  from_bytes <- bytes_to_addr(addr_to_bytes(a))
  from_binary <- binary_to_addr(addr_to_binary(a))

  expect_true(all(from_integer == a))
  expect_true(all(from_hex == a))
  expect_true(all(from_bytes == a))
  expect_true(all(from_binary == a))

  # And the family survives every one of them, which `==` does not check --
  # section 5.1.2 keeps the zone out of equality but not the family.
  expect_identical(addr_family(from_integer), addr_family(a))
  expect_identical(addr_family(from_hex), addr_family(a))
  expect_identical(addr_family(from_bytes), addr_family(a))
  expect_identical(addr_family(from_binary), addr_family(a))
})

test_that("ordering addresses agrees with ordering their integers", {
  # Two independent implementations of the same claim about the bits:
  # `vec_proxy_compare()` in R/address.R sorts by word, and the integer encoder
  # collapses the words to one number. Comparing across families is not a
  # question this asks -- section 6.5.1 makes the width the family.
  for (fam in c("v4", "v6")) {
    a <- invariant_corpus[addr_family(invariant_corpus) == fam]
    digits <- addr_to_integer(a)
    # Zero padding to a common width makes lexicographic order numeric order,
    # which avoids needing a numeric type wide enough to hold the values.
    padded <- paste0(strrep("0", 39L - nchar(digits)), digits)

    expect_identical(order(a), order(padded))
    expect_identical(addr_to_integer(sort(a)), digits[order(padded)])
  }
})

test_that("an address integer never needs more than 39 digits", {
  # 2^128 - 1 is 39 digits, so this is the ceiling the decoder rejects above.
  digits <- addr_to_integer(invariant_corpus)
  expect_true(all(nchar(digits) <= 39L))
  expect_true(all(grepl("^[0-9]+$", digits)))
  # No leading zeros either: the encoder strips its own chunk padding, and a
  # padded number would break the ordering test above.
  expect_false(any(grepl("^0.", digits)))
})

test_that("a pointer name has the label count its tree fixes", {
  # IPv6 is always 32 nibble labels plus `ip6` and `arpa`; IPv4 is always 4
  # octet labels plus `in-addr` and `arpa`. Neither depends on the text form,
  # which is the whole point of building the name from the octets.
  a <- invariant_corpus
  names <- addr_reverse_pointer(a)

  expect_true(all(endsWith(names, ".")))
  # The trailing dot stands for the root label and contributes no field.
  fields <- lengths(strsplit(names, ".", fixed = TRUE))
  want <- ifelse(addr_family(a) == "v4", 6L, 34L)
  expect_identical(fields, as.integer(want))

  expect_true(all(endsWith(names[want == 6L], ".in-addr.arpa.")))
  expect_true(all(endsWith(names[want == 34L], ".ip6.arpa.")))
  # Lowercase throughout: RFC 1035 section 3.1 makes comparison
  # case-insensitive, so this is a choice about emission and worth holding to.
  expect_false(any(grepl("[A-Z]", names)))
  # Every IPv6 label before the suffix is a single hex digit.
  expect_true(all(
    grepl("^([0-9a-f][.]){32}ip6[.]arpa[.]$", names[want == 34L])
  ))
  expect_true(all(
    grepl("^([0-9]{1,3}[.]){4}in-addr[.]arpa[.]$", names[want == 6L])
  ))
})

# --- rendering and reading are inverses (section 5.1.3) ----------------------

test_that("a canonical rendering parses back to the address it rendered", {
  # Section 5.1.3 states `parse(format(x)) == x` including the family, which is
  # what the three-state family exists to protect: `::ffff:7f00:1` and
  # `::ffff:127.0.0.1` are one address, and both render to the mixed form.
  # Checked through `addr_pton()` because it is the one primitive that reads a
  # zone back (section 3.5.2), and the zone is part of what was rendered.
  a <- invariant_corpus
  for (render in list(addr_format, addr_expand)) {
    back <- addr_pton(render(a))
    expect_true(all(back == a))
    expect_identical(addr_family(back), addr_family(a))
    expect_identical(addr_zone(back), addr_zone(a))
  }

  # And over every address the six dialects can produce out of the hostile
  # corpus, not only the drawn ones: whatever raddr renders, raddr reads.
  literals <- corpus_literals()
  for (dialect in all_dialects) {
    read <- dialect_fn(dialect)(literals)
    read <- read[!is.na(addr_family(read))]
    back <- addr_pton(addr_format(read))

    expect_true(all(back == read))
    expect_identical(addr_family(back), addr_family(read))
    expect_identical(addr_zone(back), addr_zone(read))
  }
})

test_that("canonicalization is idempotent", {
  # The fixed-point half of the same claim. `format()` is not injective over
  # text -- many spellings render to one form -- so the property that matters is
  # that applying it twice changes nothing the first application did not.
  a <- invariant_corpus
  for (render in list(addr_format, addr_expand)) {
    once <- render(a)
    expect_identical(render(addr_pton(once)), once)
  }

  # Starting from text rather than from an address, which is the direction a
  # caller actually canonicalizes in.
  literals <- corpus_literals()
  for (dialect in all_dialects) {
    read <- dialect_fn(dialect)(literals)
    once <- addr_format(read)
    twice <- addr_format(dialect_fn(dialect)(once))

    # A rejected literal renders to `NA`, and `NA` is not a spelling any
    # dialect reads -- so the fixed point is only claimed where there is one.
    at <- !is.na(once)
    expect_identical(twice[at], once[at])
  }
})

# --- totality (sections 5.2 and 6.1) -----------------------------------------

primitives <- c("strict", "whatwg", "pton", "aton")

outcome_matrix <- function(p) {
  vapply(
    primitives,
    function(d) as.character(addr_outcome(p, d)),
    character(length(p))
  )
}

test_that("addr_parse() is total over the hostile corpus", {
  # P2. `addr_parse()` is the primary answer, and it is never a bare `NA`: a
  # literal no dialect accepts still comes back as a record that says what each
  # of the four made of it.
  literals <- corpus_literals()
  expect_silent(p <- addr_parse(literals))

  expect_identical(length(p), length(literals))
  # The input is kept verbatim, control characters and all -- it is what the
  # print method shows, and a parser that rewrote its own input would make
  # every divergence report unreadable.
  expect_identical(addr_input(p), literals)

  present <- !is.na(literals)
  status <- addr_status(p)
  expect_false(any(is.na(status[present])))
  # A missing literal is missing, not rejected. That is the one `NA` status,
  # and it is the input's own missingness handed back.
  expect_true(all(is.na(status[!present])))

  # An outcome is stated for every primitive on every non-missing row, which is
  # what "per-dialect" means once it has to be a vector (section 5.2.1).
  outcomes <- outcome_matrix(p)
  expect_false(any(is.na(outcomes[present, ])))
  expect_true(all(is.na(outcomes[!present, ])))

  # The corpus has to reach all four outcomes for the rest of this to say
  # anything.
  expect_true(all(
    c("ok", "rejected", "not_an_address") %in% outcomes[present, ]
  ))
})

test_that("section 5.2.1's two silences are told apart on every row", {
  # `rejected` and `not_an_address` look alike and are not: the first is a
  # dialect that has the grammar and declines to see an address, the second is
  # a dialect with nothing to say about the family the literal is spelled in.
  # Only the first is dissent, and only the first has a reason -- so the codes
  # column is exactly the `rejected` cells, on every row and in both directions.
  literals <- corpus_literals()
  p <- addr_parse(literals)
  outcomes <- outcome_matrix(p)

  for (dialect in primitives) {
    has_codes <- lengths(addr_codes(p, dialect)) > 0L
    expect_identical(
      has_codes,
      !is.na(outcomes[, dialect]) & outcomes[, dialect] == "rejected",
      info = dialect
    )
  }

  # And the record's one derived status is a function of those four cells and
  # nothing else (section 5.2). Divergence is the separate question of whether
  # the accepting dialects agreed, which `addr_is_divergent()` answers.
  accepted <- rowSums(outcomes == "ok", na.rm = TRUE) > 0L
  refused <- rowSums(outcomes == "rejected", na.rm = TRUE) > 0L
  want <- ifelse(
    accepted,
    ifelse(addr_is_divergent(p), "divergent", "ok"),
    ifelse(refused, "malformed", "not_an_address")
  )
  want[is.na(literals)] <- NA_character_

  expect_identical(as.character(addr_status(p)), want)
})

test_that("the record's readings are the standalone parsers' answers", {
  # Two surfaces over one grammar: the record computes four readings at once
  # and resolves the two compositions on request (section 3.2), while the six
  # exported parsers each answer alone. Nothing forces them to agree except
  # this.
  #
  # Compared as addresses rather than with `identical()`, because the two are
  # not required to spell a MISSING address the same way. Section 5.1.1 puts
  # missingness in `family` and makes the words meaningless once it is set, and
  # the two paths differ there: the record blanks all four words when the
  # `getaddrinfo` whitespace rule refuses a literal, while `addr_getaddrinfo()`
  # hands back whatever `pton` left behind. Every public surface -- `==`,
  # `unique()`, `format()`, the four encoders -- reads both as the same missing
  # address, which is the claim worth making here.
  literals <- corpus_literals()
  p <- addr_parse(literals)

  for (dialect in all_dialects) {
    from_record <- addr_reading(p, dialect)
    direct <- dialect_fn(dialect)(literals)

    expect_true(
      all(vctrs::vec_equal(from_record, direct, na_equal = TRUE)),
      info = dialect
    )
    expect_identical(addr_family(from_record), addr_family(direct))
    expect_identical(addr_zone(from_record), addr_zone(direct))
    expect_identical(addr_to_hex(from_record), addr_to_hex(direct))
  }
})

test_that("classification never errors on anything addr_parse produced", {
  # Section 5.3: classification is total, and the input it has to be total over
  # is whatever came out of the parser -- including the rejections, which are
  # `NA` addresses. A missing address classifies to a missing row rather than
  # to a wrong one.
  literals <- corpus_literals()
  p <- addr_parse(literals)

  for (dialect in all_dialects) {
    a <- addr_reading(p, dialect)
    known <- !is.na(addr_family(a))

    expect_silent(cl <- addr_classify(a))
    expect_identical(length(cl), length(a))

    for (name in c("block", "category", "registry", "registry_version")) {
      value <- field(cl, name)
      expect_false(any(is.na(value[known])))
      expect_true(all(is.na(value[!known])))
    }

    # The three accessors take an address as readily as a record (section 6.3),
    # and none of them is allowed to be the one that errors.
    expect_silent(addr_category(a))
    expect_silent(addr_embedded_kind(a))
    expect_silent(addr_embeddings(a))
    # `embeddings` is size-stable by construction: one element per row, however
    # many addresses that element holds (section 5.3.5).
    expect_identical(length(addr_embeddings(a)), length(a))
  }
})

# --- embedded extraction (sections 5.3.5 and 8.1) ----------------------------

# Each wrapper spelled the way the RFC that defines it spells it, from the
# 32-bit value being embedded. Written out here rather than read from
# `raddr_transition_prefixes`: a builder that shared the geometry table with the
# extractor would round-trip through its own mistakes and report agreement.
invariant_wrapper <- function(kind, role, value) {
  octet <- (value %/% c(16777216, 65536, 256, 1)) %% 256
  quad <- paste(octet, collapse = ".")
  hi <- sprintf("%04x", value %/% 65536)
  lo <- sprintf("%04x", value %% 65536)
  # RFC 4380 section 4 stores the client bitwise-complemented, and only it.
  flipped <- 4294967295 - value

  switch(
    kind,
    # RFC 4291 sections 2.5.5.2 and 2.5.5.1. The compatible form is deprecated,
    # and only a tail above 1 is an embedded address at all -- `::` is the
    # unspecified address and `::1` is loopback.
    ipv4_mapped = paste0("::ffff:", quad),
    ipv4_compatible = paste0("::", quad),
    # RFC 2765 section 2.1. No current RFC carries this form forward
    # (section 8.1); it is here because the guards raddr replaces read it.
    ipv4_translated = paste0("::ffff:0:", quad),
    # RFC 3056 section 2: `2002:V4ADDR::/48`, so the address is bits 16-47 and
    # straddles a word boundary.
    `6to4` = sprintf("2002:%s:%s::", hi, lo),
    # RFC 4380 section 4's layout: prefix, server, flags, port, client. The
    # unused role is filled with a value that is not the one under test.
    teredo = if (role == "server") {
      sprintf("2001:0:%s:%s:8000:ffff:ffff:ffff", hi, lo)
    } else {
      sprintf(
        "2001:0:0:0:8000:ffff:%s:%s",
        sprintf("%04x", flipped %/% 65536),
        sprintf("%04x", flipped %% 65536)
      )
    },
    # RFC 6052 section 2.2 at /96, which is the only length the well-known
    # prefix is ever used at (RFC 6052 section 3.1).
    nat64_wk = paste0("64:ff9b::", quad),
    # RFC 8215 puts the local-use prefix at /48, and RFC 6052 section 2.2's /48
    # row straddles the reserved u octet at bits 64-71: two octets at bits
    # 48-63, then the zero u byte, then the other two at bits 72-87. Spelling
    # it as four separate octets is the point -- a contiguous 32-bit field here
    # reads `192.0.2.33` as `192.0.0.2`.
    nat64_local = sprintf(
      "64:ff9b:1:%02x%02x:%02x:%02x00::",
      octet[[1]], octet[[2]], octet[[3]], octet[[4]]
    ),
    # RFC 5214 section 6.1: the interface identifier is `[00]00:5efe` followed
    # by the IPv4 address, so the address is bits 96-127.
    isatap = paste0("::0:5efe:", quad),
    stop("unknown wrapper: ", kind)
  )
}

test_that("every wrapper gives back the address it was built around", {
  # The CVE-2024-24790 invariant one layer down (section 5.3.5). The named
  # examples in test-embedding.R pin the geometry against the RFCs' own tables;
  # this quantifies over the *value*, which is where the two patterns that
  # break bit-twiddling live: `0x80000000` is `NA_integer_` in a word
  # (section 5.1.1), and `0xffffffff` is the one Teredo complements to zero.
  set.seed(6052L)
  values <- c(
    0, 1, 2, 255, 256, 65535, 65536, 2147483647, 2147483648, 2147483649,
    4294967295, 4294967294,
    sample.int(4294967295, 60L) - 1
  )

  roles <- rbind(
    data.frame(kind = "teredo", role = c("server", "client")),
    data.frame(
      kind = setdiff(raddr_embedded_kinds, "teredo"),
      role = "embedded"
    )
  )

  for (i in seq_len(nrow(roles))) {
    kind <- roles$kind[[i]]
    role <- roles$role[[i]]
    # The deprecated compatible form carves out `::` and `::1`, so those two
    # values are not embeddings there. That carve-out is asserted below.
    at <- if (kind == "ipv4_compatible") values > 1 else values > -1

    wrapped <- addr_pton(vapply(
      values[at],
      function(v) invariant_wrapper(kind, role, v),
      character(1)
    ))
    want <- integer_to_addr(format(values[at], scientific = FALSE), "v4")

    expect_identical(
      as.character(addr_embedded_kind(wrapped)),
      rep(kind, length(wrapped)),
      info = paste(kind, role)
    )

    got <- addr_embeddings(wrapped)
    found <- lapply(got, function(e) {
      field(e, "address")[as.character(field(e, "role")) == role]
    })
    expect_identical(lengths(found), rep(1L, length(wrapped)), info = kind)
    expect_true(all(vctrs::vec_c(!!!found) == want), info = paste(kind, role))
  }
})

test_that("the deprecated compatible form carves out :: and ::1", {
  # The other half of the rule above, and the reason the carve-out exists: read
  # as an embedding, `::` and `::1` would classify as `0.0.0.0` and `0.0.0.1`
  # rather than as the unspecified and loopback addresses they are.
  edge <- addr_pton(c("::", "::1", "::0.0.0.2"))
  expect_identical(
    as.character(addr_embedded_kind(edge)),
    c(NA, NA, "ipv4_compatible")
  )
  expect_identical(lengths(addr_embeddings(edge)), c(0L, 0L, 1L))
})

# --- the registry lookup (section 5.3) ---------------------------------------

test_that("every address matches exactly one registry row", {
  # Classification is total across two layers, and `registry` says which one
  # answered (section 5.3). Restated as three claims a caller can rely on:
  # there is always a row, the row's block actually contains the address, and
  # the row is the one the layering rule picks.
  #
  # Checked with `addr_within()`, which decides containment from a masked
  # comparison per block, against `prefix_match()`, which decides it from keys
  # grouped by prefix length. Two implementations, one question.
  a <- c(
    invariant_corpus,
    # One address from every special-purpose block, so all 51 rows are reached
    # rather than only the ones a random draw lands in.
    addr_strict(sub("/.*", "", addr_registry()$block))
  )
  cl <- addr_classify(a)
  block <- field(cl, "block")
  registry <- as.character(field(cl, "registry"))

  expect_false(any(is.na(block)))
  expect_false(any(is.na(registry)))
  expect_true(all(addr_within(a, block)))

  contains <- function(blocks) {
    out <- vapply(blocks, function(b) addr_within(a, b), logical(length(a)))
    matrix(out, nrow = length(a), dimnames = list(NULL, blocks))
  }
  special <- addr_registry()
  space <- addr_address_space()
  in_special <- contains(special$block)
  in_space <- contains(space$block)

  # The address-space pair is an exact partition of each family's space -- that
  # is what makes the two-layer lookup total, and it is a property of the
  # vendored data rather than of the code reading it.
  expect_identical(rowSums(in_space), rep(1, length(a)))

  # Special-purpose first, on IANA's own instruction, and the longest of them
  # when several nest.
  hit <- rowSums(in_special) > 0L
  expect_true(any(hit))
  expect_true(any(!hit))
  expect_identical(
    registry,
    ifelse(hit, "special_purpose", "address_space")
  )

  longest <- function(row, table, membership) {
    at <- which(membership[row, ])
    table$block[[at[[which.max(table$prefix_len[at])]]]]
  }
  expect_identical(
    block[hit],
    vapply(which(hit), longest, character(1), special, in_special)
  )
  expect_identical(
    block[!hit],
    vapply(which(!hit), longest, character(1), space, in_space)
  )
})

test_that("a missing address classifies to a missing row, never a wrong one", {
  cl <- addr_classify(addr_pton(c("1.2.3.4", NA, "::1")))
  row <- as.data.frame(cl)

  expect_false(any(is.na(unlist(row[c(1L, 3L), c("block", "category")]))))

  # Every scalar column is `NA`. The two list columns are EMPTY instead, and
  # that is not the same silence: `codes` and `embeddings` hold zero-length
  # vectors for an address that has none, so a missing address gets the same
  # empty they do rather than a list holding one `NA` (section 5.3.5).
  listish <- c("codes", "embeddings")
  scalars <- setdiff(names(row), listish)
  expect_true(all(vapply(row[2L, scalars], is.na, logical(1))))
  expect_identical(lengths(row[[listish[[1L]]]][2L]), 0L)
  expect_identical(lengths(row[[listish[[2L]]]][2L]), 0L)
})

# --- ordering (section 5.1.2) ------------------------------------------------

test_that("comparison is antisymmetric and total", {
  # Section 5.1.2 makes the order total so `sort()` on a mixed vector works, so
  # `vec_compare()` may never answer `NA` between two present addresses -- and
  # antisymmetry is what says the family rank is a rank and not a special case.
  a <- invariant_corpus
  set.seed(5952L)
  b <- a[sample.int(length(a))]

  forward <- vctrs::vec_compare(a, b)
  expect_false(any(is.na(forward)))
  expect_identical(forward, -vctrs::vec_compare(b, a))
  expect_identical(vctrs::vec_compare(a, a), rep(0L, length(a)))

  # Zero and equality are the same relation, which is what keeps `sort()` and
  # `unique()` consistent with each other.
  expect_identical(forward == 0L, a == b)

  # IPv4 before IPv6, for every pair across the two spaces (section 5.1.2's
  # rank table). `v6_4in6` ranks with `v6`, so it is on the IPv6 side.
  v4 <- a[addr_family(a) == "v4"]
  v6 <- a[addr_family(a) != "v4"]
  n <- min(length(v4), length(v6))
  expect_true(all(vctrs::vec_compare(v4[seq_len(n)], v6[seq_len(n)]) == -1L))
})

test_that("the zone stays out of equality and out of the order", {
  # O2, and the reason for it: Apple's `inet_pton` folds the interface index
  # into the address, which makes one host look like two to a byte-comparing
  # filter. Admitting the zone into `==` reintroduces that at the R level.
  a <- invariant_corpus[addr_family(invariant_corpus) != "v4"]
  bare <- addr_pton(sub("%.*", "", addr_format(a)))
  zoned <- addr_pton(paste0(addr_format(bare), "%eth0"))

  expect_identical(addr_zone(zoned), rep("eth0", length(zoned)))
  expect_true(all(zoned == bare))
  expect_identical(vctrs::vec_compare(zoned, bare), rep(0L, length(bare)))
  expect_identical(order(zoned), order(bare))
  # And `unique()` does not partition by interface, which is the failure O2
  # names.
  expect_identical(length(unique(c(bare[1L], zoned[1L]))), 1L)
})
