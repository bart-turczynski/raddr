#!/usr/bin/env Rscript
# Deterministic vendoring of the WPT URL test corpus.
# See docs/architecture.md sections 8, 11.6 and 12.1.
#
# Maintainer-run. Regenerates, from one upstream file:
#   * tests/testthat/fixtures/wpt/urltestdata.json  - exact upstream bytes
#   * tests/testthat/fixtures/wpt-hosts.csv         - the derived host corpus
#   * data-raw/wpt-provenance.dcf                   - the pin, for COPYRIGHTS
#
# Usage (from the package root):
#   Rscript data-raw/vendor-wpt.R              # fetch at the pinned commit
#   Rscript data-raw/vendor-wpt.R --input DIR  # build from local bytes
#   Rscript data-raw/vendor-wpt.R --check      # CI staleness guard
#
# WHY THE CORPUS IS PINNED TO A COMMIT AND NOT TO `master`. urltestdata.json is
# a living file -- it gained rows twice in the month before this landed. A test
# suite that re-fetches head answers a different question every day, and a
# regression would arrive looking like an upstream edit. The pin is a commit
# SHA, and the sha256 of the bytes it serves is recorded beside it, because the
# two fail differently: a moved branch changes the first, a rewritten history or
# a truncated download changes only the second.
#
# WHY A DERIVED CSV EXISTS AT ALL, given that the JSON is right there. Reading
# JSON needs a parser, and raddr's dependency budget is `vctrs` + `rlang`
# (section 12). `jsonlite` in Suggests would work on a developer machine and
# then skip on any check without it, which is the failure mode RADD-oqevkuzo
# names by hand: the WPT corpus must ALWAYS run, and a corpus that skips is not
# a corpus. So the JSON is parsed HERE, in maintainer tooling that may depend on
# anything, and the suite reads a CSV -- the same split as the libc and ada
# oracles in section 11.6. `--check` re-derives the CSV from the vendored bytes
# and fails on drift, so the CSV cannot quietly stop being what the JSON says.
#
# WHY THE EXTRACTION IS CONSERVATIVE. WPT rows are whole URLs, and recovering
# the host token from one means implementing enough of the URL parser to know
# where the authority ends -- percent-encoding, backslashes as separators under
# special schemes, tab and newline removal, userinfo. raddr deliberately has no
# URL layer and no reg-name concept (RADD-cdmoeadr), so re-implementing one here
# to feed its own tests would make the corpus assert raddr's guess about URLs
# rather than WPT's measurement of hosts. Instead the extractor refuses anything
# it cannot read unambiguously, and the count it refused is recorded in the
# provenance. The refusals are then visible and can be argued about; they cannot
# grow silently.

# --- configuration ----------------------------------------------------------

# web-platform-tests/wpt, url/resources/urltestdata.json.
# Commit 181476a, 2026-07-05, "url: test astral code point followed by a
# trailing character in userinfo".
wpt_commit <- "181476aa16e8b28a07698bef3a0275fa53dd22e5"

wpt_url <- paste0(
  "https://raw.githubusercontent.com/web-platform-tests/wpt/",
  wpt_commit, "/url/resources/urltestdata.json"
)

# The upstream basename is kept, and kept alone in its own directory, so an
# upstream re-sync is a file swap and nothing else. The directory boundary is
# also the LICENCE boundary (section 12.1): everything under fixtures/wpt/ is
# BSD-3 material belonging to web-platform-tests contributors, and raddr's own
# additions live outside it in raddr_extra_urltestdata.json under raddr's MIT
# terms. A filename prefix would have left the two mixed in one directory and
# made inst/COPYRIGHTS unable to say which bytes are whose.
json_path <- "tests/testthat/fixtures/wpt/urltestdata.json"
csv_path <- "tests/testthat/fixtures/wpt-hosts.csv"
extra_path <- "tests/testthat/fixtures/raddr_extra_urltestdata.json"
provenance_path <- "data-raw/wpt-provenance.dcf"

cli_args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check" %in% cli_args
input_dir <- NULL
if ("--input" %in% cli_args) {
  at <- which(cli_args == "--input")[1]
  if (at == length(cli_args)) {
    stop("--input needs a directory", call. = FALSE)
  }
  input_dir <- cli_args[at + 1L]
  if (!dir.exists(input_dir)) {
    stop("no such directory: ", input_dir, call. = FALSE)
  }
}
if (check_only && !is.null(input_dir)) {
  stop("--check and --input are mutually exclusive", call. = FALSE)
}

file_sha256 <- function(path) {
  paste0("sha256:", digest::digest(file = path, algo = "sha256"))
}

# --- the conservative authority extractor ------------------------------------

# Does this host's last label LOOK like a number? Deliberately NOT WHATWG's
# "ends in a number", and not a call into R/ipv4.R either.
#
# Not the gate, because the gate is one of the things under test: a corpus
# selected by `ends_in_a_number()` can never contain a row that `ends_in_a_
# number()` gets wrong, which is precisely the row worth having. Not the
# specification restated, either, because the restatement is subtle enough to
# get wrong -- `foo.09` parses as neither a decimal nor an octal number, so a
# faithful reading of the gate drops it, yet WPT records it as a URL FAILURE and
# it is one of the sharpest rows in the file.
#
# So this errs inclusive on purpose. It selects near-misses the gate rejects,
# which is what makes the corpus able to assert that raddr rejects them too.
# Over-inclusion costs a few reg-name rows the suite must decline to read as
# addresses; under-inclusion would silently delete the evidence.
wpt_last_label_looks_numeric <- function(host) {
  # R's strsplit DISCARDS trailing empty fields, so "foo.09.." and "foo.09"
  # split identically and the trailing-dot rule cannot be applied to the
  # result. A sentinel keeps the final field alive across the split.
  parts <- strsplit(paste0(host, "\r"), ".", fixed = TRUE)[[1]]
  parts[length(parts)] <- sub("\r$", "", parts[length(parts)])
  # One trailing empty label is the trailing dot, which the host grammar drops.
  # A second one is not a trailing dot -- it is an empty label, and an empty
  # label is never a number.
  if (length(parts) > 1L && !nzchar(parts[length(parts)])) {
    parts <- parts[-length(parts)]
  }
  last <- parts[length(parts)]
  # A digit anywhere in front, or the "0x" that announces a radix, is enough to
  # make the label a candidate; whether it is really a number is raddr's answer
  # to give, not this script's.
  grepl("^[0-9]", last) || grepl("^0[xX]", last)
}

# Returns the host token, or NA when the authority cannot be read without
# guessing. Every refusal below is a case where getting the answer right needs
# the URL parser proper; none of them is a case the extractor merely finds hard.
wpt_host_token <- function(input) {
  # Two removals happen BEFORE parsing: C0-or-space is stripped from both ends,
  # and tab/LF/CR are deleted everywhere. Rows exercising either are about the
  # removal rather than about hosts, and reproducing it here is the first step
  # down the URL-parser road. Note this refuses only what the pre-parse steps
  # touch -- an ordinary space further along, in a path or even inside the
  # authority, is left alone, because a space in a host is a host-parse failure
  # and therefore exactly the kind of row worth keeping.
  if (grepl("^[[:cntrl:] ]|[[:cntrl:] ]$|[\t\r\n]", input)) {
    return(NA_character_)
  }
  m <- regmatches(
    input, regexec("^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)", input)
  )[[1]]
  if (length(m) != 3L) {
    return(NA_character_)
  }
  authority <- m[3]
  # A backslash terminates the authority under a special scheme and does not
  # under any other, so its presence makes the token scheme-dependent.
  if (grepl("\\\\", authority)) {
    return(NA_character_)
  }
  # Userinfo is delimited by the LAST "@", but percent-encoding can spell an "@"
  # that is not a delimiter, so an authority carrying BOTH is ambiguous to a
  # regex. Only both: a "%" with no "@" in sight delimits nothing, and refusing
  # it as well would throw away every zone-id row -- "%25eth0" is percent-
  # encoded by construction -- which are the rows this corpus most wants.
  if (grepl("@", authority, fixed = TRUE) &&
        grepl("%", authority, fixed = TRUE)) {
    return(NA_character_)
  }
  host_port <- sub("^.*@", "", authority)
  if (startsWith(host_port, "[")) {
    close_at <- regexpr("]", host_port, fixed = TRUE)
    if (close_at < 0L) {
      # An unclosed bracket IS a host-parse failure and is worth keeping; the
      # whole remainder is the token, since there is no port to split off.
      return(host_port)
    }
    return(substr(host_port, 1L, close_at))
  }
  # Outside brackets a colon delimits the port and appears at most once. Two of
  # them is a malformed authority whose split is a parser decision, not a
  # lexical one.
  if (lengths(regmatches(host_port, gregexpr(":", host_port, fixed = TRUE))) >
        1L) {
    return(NA_character_)
  }
  sub(":[^:]*$", "", host_port)
}

# --- build the derived corpus ------------------------------------------------

build_corpus <- function(path, source) {
  entries <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  objects <- Filter(is.list, entries)

  index <- seq_along(objects)
  input <- vapply(objects, function(o) {
    if (is.null(o$input)) NA_character_ else as.character(o$input)
  }, character(1))
  base <- vapply(objects, function(o) {
    if (is.null(o$base)) NA_character_ else as.character(o$base)
  }, character(1))
  failure <- vapply(objects, function(o) isTRUE(o$failure), logical(1))
  hostname <- vapply(objects, function(o) {
    if (is.null(o$hostname)) NA_character_ else as.character(o$hostname)
  }, character(1))

  host <- vapply(input, function(x) {
    if (is.na(x)) NA_character_ else wpt_host_token(x)
  }, character(1), USE.NAMES = FALSE)

  # A row earns its place if the host token it carries is one raddr has an
  # opinion about: bracketed, which is the IPv6 literal syntax, or ending in a
  # number, which is the gate into the IPv4 reading. Everything else is a
  # reg-name, and reg-names are the URL layer's business, not raddr's.
  bracketed <- !is.na(host) & startsWith(host, "[")
  numeric <- !is.na(host) & !bracketed &
    vapply(host, function(h) {
      if (is.na(h)) FALSE else wpt_last_label_looks_numeric(h)
    }, logical(1), USE.NAMES = FALSE)
  keep <- bracketed | numeric

  # WHAT WPT'S ANSWER IS ACTUALLY ABOUT, which is not the same question as
  # whether the row passed. A row's `failure` flag is about the whole URL: WPT
  # marks `http://[1::2]:3:4` a failure because ":3:4" is not a port, and its
  # host is perfectly well formed. Reading `failure` as a host verdict would
  # require raddr to reject `1::2`, which would be wrong.
  #
  # The successes say more than the failures do, because the serialized
  # `hostname` reveals WHICH parser the URL parser reached: a dotted quad means
  # the IPv4 reading fired, brackets mean the IPv6 one did, and anything else
  # means the host is a REG-NAME and no address parser ran at all. raddr has no
  # reg-name concept, so "regname" is the class where the right answer from
  # raddr is to decline -- `0x7f.0.0.0x7g` is a valid host and not an address.
  #
  # The failures are left unclassified on purpose. Separating a host failure
  # from a port or scheme failure needs the expected-failure bookkeeping of
  # RADD-aitbetjb, and guessing here would bake the guess into the corpus.
  serialized <- ifelse(is.na(hostname), "", hostname)
  expect <- ifelse(
    failure, "url-failure",
    ifelse(
      startsWith(serialized, "["), "ipv6",
      ifelse(
        grepl("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", serialized),
        "ipv4", "regname"
      )
    )
  )

  # A percent-encoded host is text the URL parser DECODES before any address
  # parser sees it, so raddr is looking at different bytes than WPT is. Flagged
  # rather than dropped: the row is a true fact about the URL layer, and the
  # flag is what stops the suite from reading it as a fact about raddr.
  pct <- !is.na(host) & grepl("%", host, fixed = TRUE)

  out <- data.frame(
    # The licence boundary, carried into the data. A row's terms are not a
    # property anyone should have to recover by remembering which file it came
    # from -- inst/COPYRIGHTS says fixtures/wpt/ is BSD-3 and the extras are
    # raddr's MIT, and this column is what makes that statement checkable.
    source = rep(source, sum(keep)),
    index = index[keep],
    input = input[keep],
    base = base[keep],
    host = host[keep],
    kind = ifelse(bracketed[keep], "bracketed", "numeric"),
    failure = failure[keep],
    hostname = hostname[keep],
    expect = expect[keep],
    pct_encoded = pct[keep],
    stringsAsFactors = FALSE
  )
  # A stable order, so a re-derivation diffs as content and never as ordering.
  out <- out[order(out$index), , drop = FALSE]
  rownames(out) <- NULL

  attr(out, "wpt_stats") <- c(
    entries = length(entries),
    objects = length(objects),
    failures = sum(failure),
    successes = sum(!failure),
    unreadable = sum(is.na(host)),
    bracketed = sum(bracketed),
    numeric = sum(numeric)
  )
  out
}

write_corpus <- function(corpus, path) {
  utils::write.csv(corpus, path, row.names = FALSE, na = "")
}

# Upstream first, then raddr's own, each keeping its own numbering. The two are
# never interleaved: a re-sync that adds rows upstream must not renumber, move
# or otherwise disturb a single raddr row, which is the point of the split.
combined_corpus <- function() {
  wpt_rows <- build_corpus(json_path, "wpt")
  extra_rows <- build_corpus(extra_path, "raddr")
  out <- rbind(wpt_rows, extra_rows)
  rownames(out) <- NULL
  attr(out, "wpt_stats") <- attr(wpt_rows, "wpt_stats")
  attr(out, "extra_stats") <- attr(extra_rows, "wpt_stats")
  out
}

# The comparison surface is the CSV's own text, on both sides. Comparing the
# data frames instead would compare R's idea of the columns -- which is where
# `failure` becomes logical and `base` becomes NA -- and would pass on a file
# that no longer round-trips through read.csv().
corpus_text <- function(corpus) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  write_corpus(corpus, tmp)
  readLines(tmp, warn = FALSE)
}

# --- --check: the committed artifacts must agree ----------------------------

if (check_only) {
  wanted <- c(json_path, extra_path, csv_path, provenance_path)
  missing <- Filter(Negate(file.exists), wanted)
  if (length(missing)) {
    stop(
      "missing vendored artifact(s): ", paste(missing, collapse = ", "),
      "\nrun: Rscript data-raw/vendor-wpt.R",
      call. = FALSE
    )
  }

  recorded <- read.dcf(provenance_path)[1, ]
  problems <- character()

  want <- file_sha256(json_path)
  if (!identical(want, unname(recorded[["Checksum"]]))) {
    problems <- c(problems, sprintf(
      "%s: recorded %s, on disk %s", json_path,
      recorded[["Checksum"]], want
    ))
  }
  if (!identical(
    as.character(file.size(json_path)), unname(recorded[["Bytes"]])
  )) {
    problems <- c(problems, sprintf(
      "%s: recorded %s bytes, on disk %d", json_path,
      recorded[["Bytes"]], file.size(json_path)
    ))
  }
  if (!identical(wpt_commit, unname(recorded[["Commit"]]))) {
    problems <- c(problems, sprintf(
      "pin drift: script says %s, provenance says %s",
      wpt_commit, recorded[["Commit"]]
    ))
  }

  rebuilt <- combined_corpus()
  if (!identical(corpus_text(rebuilt), readLines(csv_path, warn = FALSE))) {
    problems <- c(problems, sprintf(
      "%s disagrees with %s", csv_path, json_path
    ))
  }

  if (length(problems)) {
    message("WPT corpus artifacts are STALE:")
    for (p in problems) message("  ", p)
    message("run: Rscript data-raw/vendor-wpt.R")
    quit(status = 1L)
  }

  message(sprintf(
    "URL host corpus is in sync (%d rows: %d wpt %s, %d raddr).",
    nrow(rebuilt), sum(rebuilt$source == "wpt"),
    substr(wpt_commit, 1L, 7L), sum(rebuilt$source == "raddr")
  ))
  quit(status = 0L)
}

# --- fetch or read -----------------------------------------------------------

dir.create(dirname(json_path), recursive = TRUE, showWarnings = FALSE)

if (is.null(input_dir)) {
  utils::download.file(wpt_url, json_path, mode = "wb", quiet = TRUE)
} else {
  from <- file.path(input_dir, basename(json_path))
  if (!file.exists(from)) {
    stop("no such file: ", from, call. = FALSE)
  }
  invisible(file.copy(from, json_path, overwrite = TRUE))
}

corpus <- combined_corpus()
stats <- attr(corpus, "wpt_stats")
extra_stats <- attr(corpus, "extra_stats")
write_corpus(corpus, csv_path)

# --- provenance --------------------------------------------------------------

# DCF because inst/COPYRIGHTS is composed by build-registry.R, which must read
# these numbers without re-parsing the JSON -- and because a licence-relevant
# pin should be readable by a human opening the file, not only by a parser.
provenance <- c(
  Package = "web-platform-tests",
  Component = "url/resources/urltestdata.json",
  Path = json_path,
  Repository = "https://github.com/web-platform-tests/wpt",
  Commit = wpt_commit,
  Source = wpt_url,
  Checksum = file_sha256(json_path),
  Bytes = as.character(file.size(json_path)),
  Entries = as.character(stats[["entries"]]),
  Objects = as.character(stats[["objects"]]),
  Successes = as.character(stats[["successes"]]),
  Failures = as.character(stats[["failures"]]),
  HostRows = as.character(sum(corpus$source == "wpt")),
  Bracketed = as.character(stats[["bracketed"]]),
  Numeric = as.character(stats[["numeric"]]),
  Unreadable = as.character(stats[["unreadable"]]),
  ExtraRows = as.character(sum(corpus$source == "raddr")),
  License = "BSD-3-Clause",
  Copyright = "web-platform-tests contributors"
)
write.dcf(t(as.matrix(provenance)), provenance_path)

# --- report ------------------------------------------------------------------

message("WPT corpus vendored:")
message("  ", json_path)
message("    commit:    ", wpt_commit)
message("    checksum:  ", file_sha256(json_path))
message("    bytes:     ", file.size(json_path))
message("    entries:   ", stats[["entries"]], " (", stats[["objects"]],
        " objects, ", stats[["successes"]], " success / ",
        stats[["failures"]], " failure)")
message("  ", csv_path)
message("    wpt rows:   ", sum(corpus$source == "wpt"), " (",
        stats[["bracketed"]], " bracketed, ", stats[["numeric"]], " numeric)")
message("    raddr rows: ", sum(corpus$source == "raddr"), " (",
        extra_stats[["bracketed"]], " bracketed, ",
        extra_stats[["numeric"]], " numeric)")
message("    unreadable authorities skipped: ", stats[["unreadable"]])
message("  ", provenance_path)
message("Run build-registry.R afterwards: inst/COPYRIGHTS reads this pin.")
