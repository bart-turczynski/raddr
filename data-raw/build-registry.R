#!/usr/bin/env Rscript
# Deterministic build of the vendored IANA special-purpose registries.
# See docs/architecture.md sections 7 and 5.3.
#
# Maintainer-run. Regenerates, from the two IANA CSVs:
#   * inst/extdata/iana-ipv4-special-registry.csv  - exact upstream bytes
#   * inst/extdata/iana-ipv6-special-registry.csv  - exact upstream bytes
#   * inst/NOTICE                                  - bundled-data attribution
#   * R/sysdata.rda                                - the parsed block table
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
  )
)

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

# Keep the top `keep` bits of a 32-bit word, zero the rest. Arithmetic rather
# than bitwShiftL: R integers are signed and shifting past 2^31 returns NA.
word_mask <- function(w, keep) {
  # A word is raw bits -- NA_integer_ is the pattern 0x80000000 (section 5.1.1),
  # so it is widened rather than propagated.
  u <- as.numeric(w)
  u[is.na(w)] <- 2147483648
  u[!is.na(w) & w < 0] <- u[!is.na(w) & w < 0] + 4294967296

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
    sources$v4$path, sources$v6$path, sysdata_path, notice_path
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

  rebuilt <- build_blocks(list(v4 = sources$v4$path, v6 = sources$v6$path))
  committed <- env$raddr_registry_data$blocks

  problems <- character()
  if (!identical(rebuilt, committed)) {
    problems <- c(problems, "R/sysdata.rda disagrees with inst/extdata")
  }
  for (key in c("v4", "v6")) {
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

  message("registry artifacts are in sync (", nrow(committed), " blocks).")
  quit(status = 0L)
}

# --- fetch or read ----------------------------------------------------------

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

last_modified <- list(v4 = NA_character_, v6 = NA_character_)

for (key in c("v4", "v6")) {
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

blocks <- build_blocks(list(v4 = sources$v4$path, v6 = sources$v6$path))

meta <- list(
  v4 = list(
    name = sources$v4$name,
    url = sources$v4$url,
    path = sources$v4$path,
    sha256 = file_sha256(sources$v4$path),
    bytes = as.integer(file.size(sources$v4$path)),
    last_modified = last_modified$v4,
    last_modified_date = http_date_to_iso(last_modified$v4),
    blocks = sum(blocks$space == "v4")
  ),
  v6 = list(
    name = sources$v6$name,
    url = sources$v6$url,
    path = sources$v6$path,
    sha256 = file_sha256(sources$v6$path),
    bytes = as.integer(file.size(sources$v6$path)),
    last_modified = last_modified$v6,
    last_modified_date = http_date_to_iso(last_modified$v6),
    blocks = sum(blocks$space == "v6")
  ),
  retrieved_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  license = "CC0 1.0 Universal"
)

# The snapshot is only as current as its STALEST half, and it is not dated at
# all unless both halves are. An unknown date must degrade to "unknown" and
# never to today (subissue RADD-oknssqfy): a stamp that quietly reads as fresh
# is worse than no stamp, because `addr_registry_outdated()` would believe it.
meta$version <- if (
  is.na(meta$v4$last_modified_date) || is.na(meta$v6$last_modified_date)
) {
  NA_character_
} else {
  min(meta$v4$last_modified_date, meta$v6$last_modified_date)
}

raddr_registry_data <- list(blocks = blocks, meta = meta)

save(
  raddr_registry_data,
  file = sysdata_path,
  version = 3,
  compress = "xz"
)

# --- bundled-data NOTICE ----------------------------------------------------

dir.create("inst", recursive = TRUE, showWarnings = FALSE)

notice <- sprintf(
  paste(
    "raddr bundled data NOTICE",
    "=========================",
    "",
    "The raddr package SOURCE CODE is licensed under the MIT License (see the",
    "top-level LICENSE file and the DESCRIPTION License field).",
    "",
    "This package additionally BUNDLES the two IANA special-purpose address",
    "registries as data:",
    "",
    "  %s",
    "    Source URL: %s",
    "    Checksum:   %s",
    "    Bytes:      %d",
    "",
    "  %s",
    "    Source URL: %s",
    "    Checksum:   %s",
    "    Bytes:      %d",
    "",
    "IANA registry data is dedicated to the public domain under CC0 1.0",
    "Universal <https://creativecommons.org/publicdomain/zero/1.0/>. The",
    "registries and every derived representation bundled here (the block table",
    "in R/sysdata.rda) carry that dedication.",
    "",
    "raddr performs no network access. The registries are vendored, and are",
    "regenerated by a maintainer running data-raw/build-registry.R.",
    sep = "\n"
  ),
  sources$v4$path, sources$v4$url, meta$v4$sha256, meta$v4$bytes,
  sources$v6$path, sources$v6$url, meta$v6$sha256, meta$v6$bytes
)
writeLines(notice, notice_path)

# --- report -----------------------------------------------------------------

message("Registry data regenerated:")
for (key in c("v4", "v6")) {
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
message("  total blocks:    ", nrow(blocks))
message("Review the upstream diff before committing the regenerated artifacts.")
