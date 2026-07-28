# Measure the readings data-raw/oracle-ipv4.py cannot: WHATWG, Go and curl.
#
# adaR wraps ada, the URL parser Node and several browsers ship, so it stands in
# for "what browsers do" (section 3.1). adaR is a data-raw oracle only and never
# a runtime dependency (section 12). Go net/netip is the second implementation
# of the "strict" dialect, and curl is the one dialect raddr composes rather
# than measures -- see data-raw/oracle-tools.R for both.
#
#     Rscript data-raw/oracle-ipv4.R
#
# Recorded with adaR 0.3.5, go1.26.5 and curl 8.20.0 (libcurl/8.20.0) on
# 2026-07-28. Re-run after any upgrade to those three or to libc; the fixture
# is asserted by tests/testthat/test-ipv4.R, so drift fails loudly.

stopifnot(requireNamespace("adaR", quietly = TRUE))

source("tests/testthat/helper-dialects.R")
source("data-raw/oracle-tools.R")

libc <- read.csv(
  "tests/testthat/fixtures/ipv4-libc.csv",
  colClasses = "character", na.strings = NULL
)

# ada answers about a whole URL, so the literal is asked as a host. A host that
# fails to parse comes back NA; one that parses but is not a dotted quad was
# read as a registrable name rather than as an address, which is a rejection as
# far as the IPv4 dialect is concerned.
# One caveat, and it is why some rows come back "-". ada answers about a URL,
# and the WHATWG *URL* parser strips tabs and newlines and trims leading and
# trailing C0 control characters and spaces before the *host* parser ever runs.
# raddr never sees a URL (section 3.4), so its addr_whatwg() is the host parser
# alone. Asking ada about a whitespace-bearing literal therefore measures the
# URL layer rather than the host layer, and those rows are recorded as not
# measurable rather than as a result raddr should match.
whatwg_one <- function(literal) {
  if (grepl("[[:space:][:cntrl:]]", literal)) {
    return("-")
  }
  parsed <- tryCatch(
    adaR::ada_url_parse(paste0("http://", literal, "/")),
    error = function(e) NULL
  )
  if (is.null(parsed) || is.na(parsed$host)) {
    return("")
  }
  host <- parsed$host
  if (!grepl("^[0-9]+(\\.[0-9]+){3}$", host)) {
    return("")
  }
  host
}

literal <- unescape_control(libc$input)
libc$whatwg <- vapply(literal, whatwg_one, character(1), USE.NAMES = FALSE)
libc$netip <- netip_readings(literal, 4L)$addr
libc$curl <- curl_readings(literal, 4L)

write.csv(
  libc,
  "tests/testthat/fixtures/ipv4-oracle.csv",
  row.names = FALSE,
  na = ""
)

cat("wrote", nrow(libc), "rows to tests/testthat/fixtures/ipv4-oracle.csv\n")
