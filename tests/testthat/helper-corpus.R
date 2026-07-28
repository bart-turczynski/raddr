# The literal corpus, shared by every file that needs one. See
# docs/architecture.md section 11.3.
#
# Three sources, because they fail differently. The fixtures are what libc,
# `ipaddress` and ada actually answered; the literals are the boundaries an
# argument is about, several of which a random draw never lands on; the
# generated rows are the spellings nobody thought to write down.
#
# It lives in a helper rather than in the file that first needed it because two
# suites now run over it and ask different questions of it: test-slow.R asks
# whether two implementations agree, and test-invariants.R asks whether
# `addr_parse()` is total over it. A second corpus would have made the weaker of
# those two answers quietly weaker still.

corpus_fixture_literals <- function() {
  read_input <- function(file) {
    read.csv(
      test_path("fixtures", file),
      colClasses = "character",
      na.strings = NULL
    )$input
  }
  unescape_control(
    c(read_input("ipv4-oracle.csv"), read_input("ipv6-oracle.csv"))
  )
}

# Both sides of every bound in the two grammars, plus the quirks section 3
# names. A bound is only checked by the two values that straddle it.
corpus_boundary_literals <- c(
  # The per-part bound at each arity, from both sides (section 3.1).
  "1.2.3.255", "1.2.3.256", "1.2.65535", "1.2.65536",
  "1.16777215", "1.16777216", "4294967295", "4294967296",
  "255.255.255.255", "256.0.0.0", "1.2.3.0x100", "0x100.1.1.1",
  # Radix, leading zeros, and the digitless "0x" in each position.
  "0177.0.0.1", "010.0.0.1", "09.0.0.1", "0x0a.0.0.1", "0X0A.0.0.1",
  "0x.1.2.3", "1.2.3.0x", "0x", "00", "0", "000000000000000000001.2.3.4",
  # Overflow far past 2^32, where the wrapped value is the whole question.
  "99999999999999999999999999", "18446744073709551616", "4294967297",
  # Trailing dots, whitespace, and empty parts.
  "1.2.3.", "1.2.3..", ".", "..", "", "1.2.3.4 junk", " 1.2.3.4",
  "1.2.3.4\t5", "1.2.3.4 :5", "1..2.3", "1.2.3.4.5",
  # The elision, at every position and in every illegal quantity.
  "::", ":::", "::1", "1::", "1::2", "1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7:8::",
  "::1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7::", "1::2::3", "::1::", ":1", "1:",
  "1:2:3:4:5:6:7", "1:2:3:4:5:6:7:8:9", ":", "1:::2",
  # Hextet width, significant and insignificant (section 3.5).
  "00001::", "0000000000001::", "12345::", "01234::", "ffff::", "fffff::",
  "0000:0000:0000:0000:0000:0000:0000:0001", "g::", "0x1::",
  # The dotted-quad tail, and the dots that are not one.
  "::1.2.3.4", "::ffff:1.2.3.4", "::1.2.3.04", "::1.2.3.256", "::1.2.3",
  "::1.2.3.4:5", "1.2.3.4::", "::ffff:0:0", "::ffff:255.255.255.255",
  "64:ff9b::192.0.2.33", "::ffff:1.2.3.4%eth0",
  # The zone, which never enters the bits (section 5.1).
  "fe80::1%lo0", "fe80::1%", "fe80::1%lo0%x", "%eth0", "1.2.3.4%eth0",
  # fe80::/10 at both ends, which is the getaddrinfo scope lift (section 3.2).
  "fe80::1", "fe80:1::1", "fe7f:1::1", "fe80:abcd::1", "febf:abcd::1",
  "fec0:abcd::1", "fe80:0:abcd::1",
  # Forms `corpus_generated_literals` structurally cannot spell, worked
  # through by hand against RFC 4291 section 2.2 rather than sampled: an
  # elision standing for exactly one group in the middle, a dotted tail with no
  # elision at all, a dotted tail at every wrong arity, and uppercase hextets,
  # which `as.hexmode()` never renders.
  "1:2:3:4:5:6:1.2.3.4", "1::2:3:4:5:6:7", "1::2:3:4:5:6:7:8",
  "::0:0:0:0:0:0:0", "::0:0:0:0:0:0:0:0", "1:2:3:4:5:6:7:8:",
  ":1:2:3:4:5:6:7:8", "1::1.2.3.4", "::ffff:0:1.2.3.4",
  "1:2:3:4:5:1.2.3.4", "1:2:3:4:5:6:7:1.2.3.4", "::1:2:3:4:5:6:1.2.3.4",
  "::1.2.3.4.5", "::1.2.3.", "::0x1.2.3.4", "::01.2.3.4",
  "FE80::1", "::FFFF:1.2.3.4", "0:0:0:0:0:0:0:ABCD",
  # A zone carrying the delimiters of the address grammar itself, which is only
  # safe because the zone is split off before anything counts a dot or a colon.
  "fe80::1%eth.0", "fe80::1%eth:0", "fe80::1%%",
  # The digitless "0x" away from the ends, where `empty_hex_final` decides, and
  # whitespace mid-literal, where `stop_at_space` truncates to a shorter arity.
  "0x.1", "1.0x", "0x.1.2", "1.0x.2", "1.2.0x", "1.0x.2.3", "1.2.0x.3",
  "1 .2.3.4", "1.2 .3.4", "1.2.3 .4", "1.2.3. 4", "1.\t2.3.4", "1.2.3.4\v",
  # And the missing address, which is not a rejection.
  NA_character_
)

# Random spellings of both grammars: every radix, leading zeros of every width,
# an elision at every position, a dotted tail, a zone, and junk at either end.
corpus_generated_literals <- local({
  set.seed(4291L)

  spell_v4 <- function(v) {
    switch(
      sample.int(6L, 1L),
      as.character(v),
      paste0("0", v),
      paste0("000", v),
      format(as.hexmode(v)),
      paste0("0x", format(as.hexmode(v))),
      paste0("0X", toupper(format(as.hexmode(v))))
    )
  }
  values_v4 <- c(0:12, 250:258, 65535, 65536, 16777215, 16777216, 2147483647)
  junk_v4 <- c(rep("", 6L), ".", "..", " x", "\t", "0x", "09", "%z", ":5")

  literal_v4 <- function() {
    k <- sample.int(5L, 1L)
    paste0(
      paste(
        vapply(sample(values_v4, k, replace = TRUE), spell_v4, character(1)),
        collapse = "."
      ),
      sample(junk_v4, 1L)
    )
  }

  values_v6 <- c(0, 0, 0, 1, 8, 255, 65535, 43981, 65152, 65215, 4096)
  literal_v6 <- function() {
    pieces <- vapply(
      sample(values_v6, 8L, replace = TRUE),
      function(v) paste0(strrep("0", sample(0:6, 1L)), format(as.hexmode(v))),
      character(1)
    )
    if (sample.int(3L, 1L) == 1L) {
      from <- sample.int(8L, 1L)
      to <- min(8L, from + sample.int(4L, 1L) - 1L)
      pieces <- c(
        if (from > 1L) pieces[seq_len(from - 1L)],
        "",
        if (to < 8L) pieces[seq.int(to + 1L, 8L)]
      )
    }
    out <- paste(pieces, collapse = ":")
    if (sample.int(4L, 1L) == 1L) {
      quad <- paste(sample(0:300, 4L, replace = TRUE), collapse = ".")
      out <- sub(":[^:]*:[^:]*$", paste0(":", quad), out)
    }
    if (sample.int(5L, 1L) == 1L) {
      out <- paste0(out, "%", sample(c("", "eth0", "1", "lo0%x"), 1L))
    }
    if (sample.int(6L, 1L) == 1L) {
      out <- paste0(out, sample(c(":", "::", ":::", "g", " "), 1L))
    }
    if (sample.int(6L, 1L) == 1L) {
      out <- paste0(sample(c(":", "::", ":::", " "), 1L), out)
    }
    out
  }

  # Adversarial spellings reject under most dialects, and a corpus of nothing
  # but rejections would agree vacuously, so half of the generated rows are
  # valid by construction: a plain quad and eight plain hextets, built from
  # numbers rather than rendered by the package.
  literal_v4_plain <- function() {
    paste(sample(0:255, 4L, replace = TRUE), collapse = ".")
  }
  literal_v6_plain <- function() {
    paste(
      vapply(
        sample(0:65535, 8L, replace = TRUE),
        function(v) format(as.hexmode(v)),
        character(1)
      ),
      collapse = ":"
    )
  }

  c(
    vapply(seq_len(600L), function(i) literal_v4(), character(1)),
    vapply(seq_len(600L), function(i) literal_v6(), character(1)),
    vapply(seq_len(300L), function(i) literal_v4_plain(), character(1)),
    vapply(seq_len(300L), function(i) literal_v6_plain(), character(1))
  )
})

corpus_literals <- function() {
  c(
    corpus_fixture_literals(),
    corpus_boundary_literals,
    corpus_generated_literals
  )
}
