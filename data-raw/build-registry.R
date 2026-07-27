#!/usr/bin/env Rscript
# Deterministic build of the vendored IANA address registries.
# See docs/architecture.md sections 7 and 5.3.
#
# Maintainer-run. Regenerates, from the four IANA CSVs:
#   * inst/extdata/iana-ipv4-special-registry.csv  - exact upstream bytes
#   * inst/extdata/iana-ipv6-special-registry.csv  - exact upstream bytes
#   * inst/extdata/iana-ipv4-address-space.csv     - exact upstream bytes
#   * inst/extdata/iana-ipv6-address-space.csv     - exact upstream bytes
#   * inst/NOTICE                                  - bundled-data attribution
#   * R/sysdata.rda                                - the parsed block tables
#
# Two registry PAIRS, kept apart on purpose (subissue RADD-pekbpche):
#
#   special-purpose  answers POLICY  - the five IANA logicals, per block
#   address space    answers IDENTITY - what the space is for, and who holds it
#
# The address-space pair is an exact partition of both spaces, so with it in
# hand classification is TOTAL: every address matches some row, and `global`
# becomes a statement backed by a registry row instead of an absence. Deriving
# a table from the special-purpose registry alone is a known CVE-producing
# pattern -- multicast appears in NEITHER special-purpose registry, which is
# why PHP's registry-derived rewrite has no multicast handling and ssrfcheck
# shipped CVE-2025-8267 (architecture.md P9).
#
# IANA states the precedence itself: the address-space registries carry "For
# authoritative registration, see [Special-Purpose Address Space]", so
# special-purpose outranks address space by the source's own instruction. The
# five policy columns do not exist in the address-space registries, and this
# script does not invent them -- a match there yields identity with no policy.
#
# The IPv6 Global Unicast Assignments registry is deliberately NOT vendored: it
# is not a partition (sub-ranges of 2000::/3 appear in no row), so absence there
# would mean "unallocated", a different answer from "not found".
#
# Usage (from the package root):
#   Rscript data-raw/build-registry.R              # fetch from IANA
#   Rscript data-raw/build-registry.R --input DIR  # build from local bytes
#   Rscript data-raw/build-registry.R --check      # CI staleness guard
#
# raddr itself never touches the network -- that is the point of vendoring
# (section 7). This script is not part of the package: it is maintainer tooling,
# and it is the only place a URL appears. `--input` exists so the build is
# reproducible from bytes already on disk, and so the vendored CSVs can be
# rebuilt on a machine with no route to IANA.
#
# `--check` rebuilds the table in memory from the COMMITTED inst/extdata bytes
# and compares it to the committed R/sysdata.rda. It exits non-zero on drift,
# which is what stops a hand-edited generated file from shipping. It compares
# content only: provenance dates are not content, and a rebuild on another day
# must not fail the guard.
#
# A registry update changes classification results, so it lands as a new package
# version with a changelog entry, and the upstream diff is reviewed before the
# regenerated artifacts are committed.

# --- configuration ----------------------------------------------------------

sources <- list(
  v4 = list(
    name = "iana-ipv4-special-registry",
    url = paste0(
      "https://www.iana.org/assignments/iana-ipv4-special-registry/",
      "iana-ipv4-special-registry-1.csv"
    ),
    path = "inst/extdata/iana-ipv4-special-registry.csv"
  ),
  v6 = list(
    name = "iana-ipv6-special-registry",
    url = paste0(
      "https://www.iana.org/assignments/iana-ipv6-special-registry/",
      "iana-ipv6-special-registry-1.csv"
    ),
    path = "inst/extdata/iana-ipv6-special-registry.csv"
  ),
  # The address-space pair. Note the v6 endpoint: `ipv6-address-space.csv`
  # 404s and serves a 4216-byte HTML error body with a 200-shaped filename, so
  # the real export is `-1.csv`. Fetching the wrong one yields a file that
  # read.csv parses without complaint into garbage columns.
  v4_space = list(
    name = "iana-ipv4-address-space",
    url = paste0(
      "https://www.iana.org/assignments/ipv4-address-space/",
      "ipv4-address-space.csv"
    ),
    path = "inst/extdata/iana-ipv4-address-space.csv"
  ),
  v6_space = list(
    name = "iana-ipv6-address-space",
    url = paste0(
      "https://www.iana.org/assignments/ipv6-address-space/",
      "ipv6-address-space-1.csv"
    ),
    path = "inst/extdata/iana-ipv6-address-space.csv"
  )
)

special_keys <- c("v4", "v6")
space_keys <- c("v4_space", "v6_space")
all_keys <- c(special_keys, space_keys)

sysdata_path <- "R/sysdata.rda"
notice_path <- "inst/NOTICE"

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

# --- the parser under test is the parser that validates the data ------------

pkgload::load_all(".", quiet = TRUE)

# --- reading the upstream bytes ---------------------------------------------

# A row's Address Block may carry a footnote marker, and one v4 row names two
# prefixes in a single field. Both are upstream formatting, not data, so they
# are normalized here rather than in the package.
strip_footnotes <- function(x) {
  trimws(gsub("\\[[0-9]+\\]", "", x))
}

footnote_markers <- function(...) {
  found <- unlist(regmatches(c(...), gregexpr("\\[[0-9]+\\]", c(...))))
  paste(unique(found), collapse = " ")
}

# IANA writes True / False, "N/A" where the answer depends on something the
# table cannot express, and leaves the row blank when the block is deprecated.
# The last two are NOT False. Collapsing them would assert, of Teredo and 6to4,
# a reachability answer that IANA explicitly declined to give -- which is the
# very case the transition overlay exists to handle.
parse_flag <- function(x, column) {
  v <- strip_footnotes(x)
  out <- rep(NA, length(v))
  out[v == "True"] <- TRUE
  out[v == "False"] <- FALSE
  unknown <- !(v %in% c("True", "False", "N/A", ""))
  if (any(unknown)) {
    stop(
      "unexpected value in column ", column, ": ",
      paste(unique(v[unknown]), collapse = ", "),
      call. = FALSE
    )
  }
  out
}

# The RFC field wraps across lines for rows citing more than one document.
squish <- function(x) {
  trimws(gsub("[[:space:]]+", " ", x))
}

blank_to_na <- function(x) {
  x[x == "" | x == "N/A"] <- NA_character_
  x
}

read_registry <- function(path, space) {
  raw <- utils::read.csv(
    path,
    colClasses = "character",
    check.names = FALSE,
    encoding = "UTF-8"
  )

  expected <- c(
    "Address Block", "Name", "RFC", "Allocation Date", "Termination Date",
    "Source", "Destination", "Forwardable", "Globally Reachable",
    "Reserved-by-Protocol"
  )
  if (!identical(names(raw), expected)) {
    stop(
      "unexpected columns in ", path, ": ",
      paste(names(raw), collapse = ", "),
      call. = FALSE
    )
  }

  rows <- lapply(seq_len(nrow(raw)), function(i) {
    r <- raw[i, ]
    # One registry row, possibly several prefixes: "192.0.0.170/32,
    # 192.0.0.171/32". Split, or longest-prefix match never matches either.
    blocks <- trimws(strsplit(strip_footnotes(r[["Address Block"]]), ",")[[1]])
    blocks <- blocks[nzchar(blocks)]

    data.frame(
      block = blocks,
      space = space,
      name = squish(r[["Name"]]),
      rfc = squish(r[["RFC"]]),
      allocation_date = blank_to_na(r[["Allocation Date"]]),
      termination_date = blank_to_na(r[["Termination Date"]]),
      source = parse_flag(r[["Source"]], "Source"),
      destination = parse_flag(r[["Destination"]], "Destination"),
      forwardable = parse_flag(r[["Forwardable"]], "Forwardable"),
      globally_reachable = parse_flag(
        r[["Globally Reachable"]], "Globally Reachable"
      ),
      reserved_by_protocol = parse_flag(
        r[["Reserved-by-Protocol"]], "Reserved-by-Protocol"
      ),
      # Which caveats the row carries. The footnote TEXT is not in the CSV --
      # it lives on the registry page -- so raddr records that a caveat exists
      # and does not invent its wording.
      footnotes = footnote_markers(
        r[["Address Block"]], r[["Source"]], r[["Destination"]],
        r[["Forwardable"]], r[["Globally Reachable"]],
        r[["Reserved-by-Protocol"]]
      ),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

# --- the address-space pair -------------------------------------------------

# These two registries answer a different question from the special-purpose
# pair, and their columns say so: there are no policy logicals to read. They
# are carried in a SEPARATE table with a separate stamp rather than rbind-ed
# into the block table, because a single table would have to fill five columns
# IANA never wrote (section 5.3.4's rule, applied to data rather than to the
# level map).

# The IPv4 registry writes its prefixes as "000/8" ... "255/8". That is not
# CIDR and must not be handed to a parser as though it were: raddr's strict
# dialect rejects "000" as a leading-zero octet -- correctly, that being the
# ambiguity behind the whole `inet_aton` CVE class -- so the octet is read as a
# number and the block rebuilt in canonical form.
v4_space_blocks <- function(prefix) {
  if (!all(grepl("^[0-9]{3}/8$", prefix))) {
    stop(
      "unexpected IPv4 address-space prefix format: ",
      paste(unique(prefix[!grepl("^[0-9]{3}/8$", prefix)]), collapse = ", "),
      call. = FALSE
    )
  }
  octet <- as.integer(substr(prefix, 1L, 3L))
  if (any(octet > 255L)) {
    stop(
      "IPv4 address-space octet out of range: ",
      paste(unique(octet[octet > 255L]), collapse = ", "),
      call. = FALSE
    )
  }
  sprintf("%d.0.0.0/8", octet)
}

read_address_space_v4 <- function(path) {
  raw <- utils::read.csv(
    path,
    colClasses = "character",
    check.names = FALSE,
    encoding = "UTF-8"
  )

  # The header literally reads "Status [1]" -- the footnote marker is part of
  # the column name upstream, so matching on "Status" silently finds nothing.
  expected <- c(
    "Prefix", "Designation", "Date", "WHOIS", "RDAP", "Status [1]", "Note"
  )
  if (!identical(names(raw), expected)) {
    stop(
      "unexpected columns in ", path, ": ",
      paste(names(raw), collapse = ", "),
      call. = FALSE
    )
  }

  # WHOIS and RDAP are dropped. RDAP is corrupted by the CSV export itself: on
  # every ARIN and AFRINIC row it holds two URLs run together with no
  # separator, the https one immediately followed by the http one. Neither
  # column answers a question raddr is asked, and the vendored bytes keep both
  # verbatim -- only the parsed table omits them. The lesson generalizes: do
  # not assume per-column fidelity from an IANA CSV export.
  out <- data.frame(
    block = v4_space_blocks(raw$Prefix),
    space = "v4",
    name = squish(raw$Designation),
    # This registry has no reference column at all. The RFCs behind its rows
    # live in the numeric footnotes ([14] sources multicast to RFC 5771, [17]
    # sources 240/4 to RFC 1112), and footnote TEXT is not in the CSV -- so
    # `rfc` is honestly unknown here rather than transcribed from memory.
    rfc = NA_character_,
    status = strip_footnotes(raw[["Status [1]"]]),
    date = blank_to_na(raw$Date),
    notes = NA_character_,
    footnotes = vapply(
      raw$Note, footnote_markers, character(1), USE.NAMES = FALSE
    ),
    stringsAsFactors = FALSE
  )

  if (nrow(out) != 256L) {
    stop("expected 256 IPv4 /8 rows, got ", nrow(out), call. = FALSE)
  }
  if (anyDuplicated(out$block)) {
    stop("duplicate IPv4 address-space prefix", call. = FALSE)
  }
  unexpected <- setdiff(out$status, c("ALLOCATED", "LEGACY", "RESERVED"))
  if (length(unexpected)) {
    stop(
      "unexpected IPv4 address-space status: ",
      paste(unexpected, collapse = ", "),
      call. = FALSE
    )
  }
  out
}

read_address_space_v6 <- function(path) {
  raw <- utils::read.csv(
    path,
    colClasses = "character",
    check.names = FALSE,
    encoding = "UTF-8"
  )

  expected <- c("IPv6 Prefix", "Allocation", "Reference", "Notes")
  if (!identical(names(raw), expected)) {
    stop(
      "unexpected columns in ", path, ": ",
      paste(names(raw), collapse = ", "),
      call. = FALSE
    )
  }

  # Upstream spells these compressed -- "::/8", "100::/8", "200::/7",
  # "e000::/4", "fe00::/9" -- never zero-padded. They go to the parser as
  # written; raddr's own strict dialect is what validates them.
  data.frame(
    block = trimws(raw[["IPv6 Prefix"]]),
    space = "v6",
    name = squish(raw$Allocation),
    rfc = squish(raw$Reference),
    # No status column here: this registry states allocation, not lifecycle.
    status = NA_character_,
    date = NA_character_,
    # Free prose, and the only place the deprecations are recorded: 200::/7 is
    # "Deprecated as of December 2004 [RFC4048]" and fec0::/10 is the retired
    # site-local prefix. Dropping it would lose facts nothing else carries.
    notes = squish(raw$Notes),
    footnotes = "",
    stringsAsFactors = FALSE
  )
}

# --- turning the block text into bits ---------------------------------------

# Parsed with raddr's own strict dialect, so the vendored data is validated by
# the engine that will later be asked about it. A registry block that raddr
# cannot parse is a build failure, not a silently dropped row.
parse_blocks <- function(tbl) {
  split_at <- regexpr("/", tbl$block, fixed = TRUE)
  if (any(split_at < 0L)) {
    stop(
      "block with no prefix length: ",
      paste(tbl$block[split_at < 0L], collapse = ", "),
      call. = FALSE
    )
  }
  base_text <- substr(tbl$block, 1L, split_at - 1L)
  prefix_len <- as.integer(substring(tbl$block, split_at + 1L))

  addr <- addr_strict(base_text)
  if (anyNA(addr_family(addr))) {
    stop(
      "unparseable registry block: ",
      paste(tbl$block[is.na(addr_family(addr))], collapse = ", "),
      call. = FALSE
    )
  }

  width <- ifelse(tbl$space == "v4", 32L, 128L)
  if (any(prefix_len < 0L | prefix_len > width)) {
    stop(
      "prefix length out of range: ",
      paste(tbl$block[prefix_len < 0L | prefix_len > width], collapse = ", "),
      call. = FALSE
    )
  }

  words <- lapply(c("w1", "w2", "w3", "w4"), function(f) {
    vctrs::field(addr, f)
  })
  names(words) <- c("w1", "w2", "w3", "w4")

  # The v4 blocks live in w4 alone (section 5.1), so a v4 prefix length counts
  # from bit 0 of w4 while a v6 one counts from bit 0 of w1.
  offset <- ifelse(tbl$space == "v4", 96L, 0L)
  for (k in 1:4) {
    keep <- pmin(pmax(prefix_len + offset - 32L * (k - 1L), 0L), 32L)
    masked <- word_mask(words[[k]], keep)
    if (!identical(masked, words[[k]])) {
      bad <- which(masked != words[[k]] | xor(is.na(masked), is.na(words[[k]])))
      stop(
        "block has bits set below its prefix: ",
        paste(tbl$block[bad], collapse = ", "),
        call. = FALSE
      )
    }
    tbl[[names(words)[k]]] <- words[[k]]
  }

  tbl$prefix_len <- prefix_len
  tbl
}

# A word is raw bits -- NA_integer_ is the pattern 0x80000000 (section 5.1.1),
# so it is widened to an unsigned proxy rather than propagated. Not hypothetical
# in the vendored data: `2620:4f:8000::/48` (AS112 direct delegation) and
# `8000::/3` (IPv6 address space) both have exactly this word.
as_unsigned_word <- function(w) {
  u <- as.numeric(w)
  u[is.na(w)] <- 2147483648
  u[!is.na(w) & w < 0] <- u[!is.na(w) & w < 0] + 4294967296
  u
}

# Keep the top `keep` bits of a 32-bit word, zero the rest. Arithmetic rather
# than bitwShiftL: R integers are signed and shifting past 2^31 returns NA.
word_mask <- function(w, keep) {
  u <- as_unsigned_word(w)

  drop <- 32L - keep
  masked <- (u %/% 2^drop) * 2^drop
  masked[drop >= 32L] <- 0

  # Fold back into raw signed bits. Indexed rather than ifelse()d: ifelse
  # evaluates both branches over the whole vector, and the unused branch
  # overflows to NA with a warning -- noise that would hide a real NA.
  high <- masked >= 2147483648
  masked[high] <- masked[high] - 4294967296

  # 0x80000000 is R's NA_integer_ bit pattern, and section 5.1.1's whole point
  # is that raddr stores it as that pattern rather than losing the address.
  # It is not hypothetical here: `2620:4f:8000::/48`, the AS112 direct
  # delegation prefix, has exactly this word. Assigned rather than coerced,
  # because as.integer(-2147483648) is an out-of-range NA plus a warning.
  out <- rep(NA_integer_, length(masked))
  representable <- masked != -2147483648
  out[representable] <- as.integer(masked[representable])
  out
}

build_blocks <- function(paths) {
  tbl <- rbind(
    parse_blocks(read_registry(paths$v4, "v4")),
    parse_blocks(read_registry(paths$v6, "v6"))
  )
  tbl <- tbl[c(
    "block", "space", "w1", "w2", "w3", "w4", "prefix_len",
    "name", "rfc", "allocation_date", "termination_date",
    "source", "destination", "forwardable", "globally_reachable",
    "reserved_by_protocol", "footnotes"
  )]
  rownames(tbl) <- NULL
  tbl
}

# The whole justification for vendoring these two is that each is an EXACT
# partition of its address space. If that fails, "no special-purpose block
# matched" stops meaning `global` and starts meaning "unknown", so the property
# is asserted at build time rather than believed.
check_v4_partition <- function(tbl) {
  octet <- as.integer(sub("[.].*$", "", tbl$block))
  if (!identical(sort(octet), 0:255) || !all(tbl$prefix_len == 8L)) {
    stop("IPv4 address space is not an exact partition into 256 /8s",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

check_v6_partition <- function(tbl) {
  # Every row is /10 or shorter, so a block is fully determined by its first
  # hextet and the tiling can be checked exactly in 16-bit space -- no 128-bit
  # arithmetic, no floating point near 2^128.
  if (any(tbl$prefix_len > 16L)) {
    stop(
      "IPv6 address-space row longer than /16; generalize the partition check",
      call. = FALSE
    )
  }
  start <- as_unsigned_word(tbl$w1) %/% 65536
  size <- 2^(16L - tbl$prefix_len)

  ord <- order(start)
  start <- start[ord]
  size <- size[ord]

  if (start[1] != 0) {
    stop("IPv6 address space does not start at ::", call. = FALSE)
  }
  ends <- start + size
  if (!identical(ends[-length(ends)], start[-1])) {
    stop("IPv6 address space has a gap or an overlap", call. = FALSE)
  }
  if (ends[length(ends)] != 65536) {
    stop("IPv6 address space does not reach ffff::", call. = FALSE)
  }
  invisible(TRUE)
}

build_space_blocks <- function(paths) {
  v4 <- parse_blocks(read_address_space_v4(paths$v4_space))
  v6 <- parse_blocks(read_address_space_v6(paths$v6_space))
  check_v4_partition(v4)
  check_v6_partition(v6)

  tbl <- rbind(v4, v6)
  tbl <- tbl[c(
    "block", "space", "w1", "w2", "w3", "w4", "prefix_len",
    "name", "rfc", "status", "date", "notes", "footnotes"
  )]
  rownames(tbl) <- NULL
  tbl
}

# "Thu, 09 Oct 2025 21:51:16 GMT" -> "2025-10-09". Done here, once, with an
# explicit month map rather than strptime's %b, so the stored stamp does not
# depend on the locale of the machine that built it -- and so the package needs
# no date parsing at all beyond as.Date() on an ISO string.
http_date_to_iso <- function(x) {
  if (is.na(x)) {
    return(NA_character_)
  }
  months <- c(
    Jan = "01", Feb = "02", Mar = "03", Apr = "04", May = "05", Jun = "06",
    Jul = "07", Aug = "08", Sep = "09", Oct = "10", Nov = "11", Dec = "12"
  )
  m <- regmatches(
    x, regexec("([0-9]{2}) ([A-Za-z]{3}) ([0-9]{4})", x)
  )[[1]]
  if (length(m) != 4L || is.na(months[m[3]])) {
    warning("unrecognized HTTP date, recording unknown: ", x, call. = FALSE)
    return(NA_character_)
  }
  paste(m[4], months[[m[3]]], m[2], sep = "-")
}

file_sha256 <- function(path) {
  paste0("sha256:", digest::digest(file = path, algo = "sha256"))
}

# --- --check: the committed artifacts must agree ----------------------------

if (check_only) {
  missing <- Filter(Negate(file.exists), c(
    vapply(sources, function(s) s$path, character(1)),
    sysdata_path, notice_path
  ))
  if (length(missing)) {
    stop(
      "missing generated artifact(s): ", paste(missing, collapse = ", "),
      "\nrun: Rscript data-raw/build-registry.R",
      call. = FALSE
    )
  }

  env <- new.env(parent = emptyenv())
  load(sysdata_path, envir = env)
  if (is.null(env$raddr_registry_data)) {
    stop(
      "'", sysdata_path, "' contains no `raddr_registry_data` object",
      call. = FALSE
    )
  }

  paths <- lapply(sources, function(s) s$path)
  committed <- env$raddr_registry_data$blocks

  problems <- character()
  if (!identical(build_blocks(paths), committed)) {
    problems <- c(problems, "R/sysdata.rda blocks disagree with inst/extdata")
  }
  if (!identical(build_space_blocks(paths), env$raddr_registry_data$space)) {
    problems <- c(
      problems, "R/sysdata.rda address space disagrees with inst/extdata"
    )
  }
  for (key in all_keys) {
    want <- file_sha256(sources[[key]]$path)
    got <- env$raddr_registry_data$meta[[key]]$sha256
    if (!identical(want, got)) {
      problems <- c(problems, sprintf(
        "%s: recorded %s, on disk %s", sources[[key]]$path, got, want
      ))
    }
  }

  if (length(problems)) {
    message("registry artifacts are STALE:")
    for (p in problems) message("  ", p)
    message("run: Rscript data-raw/build-registry.R")
    quit(status = 1L)
  }

  message(
    "registry artifacts are in sync (", nrow(committed), " special-purpose ",
    "blocks, ", nrow(env$raddr_registry_data$space), " address-space rows)."
  )
  quit(status = 0L)
}

# --- fetch or read ----------------------------------------------------------

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

last_modified <- stats::setNames(
  as.list(rep(NA_character_, length(all_keys))), all_keys
)

for (key in all_keys) {
  src <- sources[[key]]
  if (is.null(input_dir)) {
    utils::download.file(src$url, src$path, mode = "wb", quiet = TRUE)
    # Upstream's own idea of when the registry last changed. Recorded when it
    # is offered and left unknown when it is not -- never guessed, and never
    # defaulted to today (subissue RADD-oknssqfy).
    lm <- tryCatch(
      {
        h <- curlGetHeaders(src$url)
        val <- grep("^[Ll]ast-[Mm]odified:", h, value = TRUE)
        if (length(val)) trimws(sub("^[^:]+:", "", val[1])) else NA_character_
      },
      error = function(e) NA_character_
    )
    last_modified[[key]] <- lm
  } else {
    from <- file.path(input_dir, basename(src$path))
    if (!file.exists(from)) {
      stop("no such file: ", from, call. = FALSE)
    }
    file.copy(from, src$path, overwrite = TRUE)
    # A sidecar lets an offline build carry the same provenance a fetch would.
    sidecar <- paste0(from, ".last-modified")
    if (file.exists(sidecar)) {
      last_modified[[key]] <- trimws(readLines(sidecar, warn = FALSE)[1])
    }
  }
}

# --- build ------------------------------------------------------------------

paths <- lapply(sources, function(s) s$path)
blocks <- build_blocks(paths)
space <- build_space_blocks(paths)

row_counts <- c(
  v4 = sum(blocks$space == "v4"),
  v6 = sum(blocks$space == "v6"),
  v4_space = sum(space$space == "v4"),
  v6_space = sum(space$space == "v6")
)

meta <- lapply(all_keys, function(key) {
  src <- sources[[key]]
  list(
    name = src$name,
    url = src$url,
    path = src$path,
    sha256 = file_sha256(src$path),
    bytes = as.integer(file.size(src$path)),
    last_modified = last_modified[[key]],
    last_modified_date = http_date_to_iso(last_modified[[key]]),
    blocks = as.integer(row_counts[[key]])
  )
})
names(meta) <- all_keys
meta$retrieved_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
meta$license <- "CC0 1.0 Universal"

# A snapshot is only as current as its STALEST half, and it is not dated at all
# unless both halves are. An unknown date must degrade to "unknown" and never to
# today (subissue RADD-oknssqfy): a stamp that quietly reads as fresh is worse
# than no stamp, because `addr_registry_outdated()` would believe it.
stamp <- function(keys) {
  dates <- vapply(keys, function(k) meta[[k]]$last_modified_date, character(1))
  if (anyNA(dates)) NA_character_ else min(dates)
}

# TWO stamps, not one. The pairs are vendored from different registries whose
# provenance behaves differently -- the special-purpose pair's served
# `Last-Modified` happens to match its editorial `Last Updated`, and the
# address-space pair's does not (RADD-lfgkjvfv). One date across both would
# make each half assert something about a table it says nothing about, which is
# the same reason the transition overlay is stamped separately (section 7.2).
meta$version <- stamp(special_keys)
meta$space_version <- stamp(space_keys)

raddr_registry_data <- list(blocks = blocks, space = space, meta = meta)

save(
  raddr_registry_data,
  file = sysdata_path,
  version = 3,
  compress = "xz"
)

# --- bundled-data NOTICE ----------------------------------------------------

dir.create("inst", recursive = TRUE, showWarnings = FALSE)

notice_entry <- function(key) {
  m <- meta[[key]]
  sprintf(
    "  %s\n    Source URL: %s\n    Checksum:   %s\n    Bytes:      %d",
    m$path, m$url, m$sha256, m$bytes
  )
}

notice <- paste(
  c(
    "raddr bundled data NOTICE",
    "=========================",
    "",
    "The raddr package SOURCE CODE is licensed under the MIT License (see the",
    "top-level LICENSE file and the DESCRIPTION License field).",
    "",
    "This package additionally BUNDLES four IANA address registries as data.",
    "",
    "The two special-purpose registries, which answer policy:",
    "",
    vapply(special_keys, notice_entry, character(1)),
    "",
    "The two address-space registries, which answer identity and are exact",
    "partitions of their spaces:",
    "",
    vapply(space_keys, notice_entry, character(1)),
    "",
    "IANA registry data is dedicated to the public domain under CC0 1.0",
    "Universal <https://creativecommons.org/publicdomain/zero/1.0/>. The",
    "registries and every derived representation bundled here (the block and",
    "address-space tables in R/sysdata.rda) carry that dedication.",
    "",
    "raddr performs no network access. The registries are vendored, and are",
    "regenerated by a maintainer running data-raw/build-registry.R."
  ),
  collapse = "\n"
)
writeLines(notice, notice_path)

# --- report -----------------------------------------------------------------

message("Registry data regenerated:")
for (key in all_keys) {
  m <- meta[[key]]
  message("  ", m$path)
  message("    checksum:      ", m$sha256)
  message("    bytes:         ", m$bytes)
  message("    blocks:        ", m$blocks)
  message(
    "    last-modified: ",
    if (is.na(m$last_modified)) "unknown" else m$last_modified
  )
}
message("  special-purpose blocks: ", nrow(blocks))
message("  address-space rows:     ", nrow(space))
message("Review the upstream diff before committing the regenerated artifacts.")
