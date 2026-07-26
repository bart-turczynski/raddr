# Measure the WHATWG reading of the same inputs data-raw/oracle-ipv6.py covers.
#
# adaR wraps ada, the URL parser Node and several browsers ship, so it stands in
# for "what browsers do" (section 3.1). adaR is a data-raw oracle only and never
# a runtime dependency (section 12).
#
#     Rscript data-raw/oracle-ipv6.R
#
# Recorded with adaR 0.3.5 on 2026-07-26.

stopifnot(requireNamespace("adaR", quietly = TRUE))

source("tests/testthat/helper-dialects.R")

libc <- read.csv(
  "tests/testthat/fixtures/ipv6-libc.csv",
  colClasses = "character", na.strings = NULL
)

# ada serializes a host per RFC 5952, which compresses. The fixture stores the
# fully expanded form so that it says nothing about formatting -- that is Epic
# E's subject -- so ada's answer is expanded back out here.
expand_v6 <- function(host) {
  halves <- strsplit(host, "::", fixed = TRUE)[[1L]]
  head_parts <- if (length(halves) >= 1L && nzchar(halves[[1L]])) {
    strsplit(halves[[1L]], ":", fixed = TRUE)[[1L]]
  } else {
    character()
  }
  tail_parts <- if (length(halves) >= 2L && nzchar(halves[[2L]])) {
    strsplit(halves[[2L]], ":", fixed = TRUE)[[1L]]
  } else {
    character()
  }
  if (!grepl("::", host, fixed = TRUE)) {
    head_parts <- strsplit(host, ":", fixed = TRUE)[[1L]]
    tail_parts <- character()
  }
  gap <- 8L - length(head_parts) - length(tail_parts)
  parts <- c(head_parts, rep("0", gap), tail_parts)
  paste(sprintf("%04x", strtoi(parts, 16L)), collapse = ":")
}

# ada answers about a whole URL, so the literal is asked as a bracketed host.
# The brackets belong to the URL layer rather than the address layer: the
# WHATWG host parser is handed the text *between* them, and libc rejects them
# outright, as the fixture records. So they are added unconditionally, and a
# literal that already carries a pair is asked as "[[::1]]" and rejected --
# which is the right answer for a host parser, and the reason raddr's
# addr_whatwg() rejects "[::1]" too.
#
# The same caveat as the IPv4 oracle applies and is why some rows come back
# "-": the WHATWG *URL* parser strips tabs and newlines and trims C0 controls
# and spaces before the *host* parser ever runs, and raddr never sees a URL
# (section 3.4). Those rows measure the URL layer, not the host layer.
whatwg_one <- function(literal) {
  if (grepl("[[:space:][:cntrl:]]", literal)) {
    return("-")
  }
  parsed <- tryCatch(
    adaR::ada_url_parse(paste0("http://[", literal, "]/")),
    error = function(e) NULL
  )
  if (is.null(parsed) || is.na(parsed$host)) {
    return("")
  }
  host <- parsed$host
  if (!startsWith(host, "[") || !endsWith(host, "]")) {
    return("")
  }
  expand_v6(substr(host, 2L, nchar(host) - 1L))
}

literal <- unescape_control(libc$input)
libc$whatwg <- vapply(literal, whatwg_one, character(1), USE.NAMES = FALSE)

write.csv(
  libc,
  "tests/testthat/fixtures/ipv6-oracle.csv",
  row.names = FALSE,
  na = ""
)

cat("wrote", nrow(libc), "rows to tests/testthat/fixtures/ipv6-oracle.csv\n")
