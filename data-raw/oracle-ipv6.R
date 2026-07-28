# Measure the readings data-raw/oracle-ipv6.py cannot: WHATWG, Go and curl.
#
# adaR wraps ada, the URL parser Node and several browsers ship, so it stands in
# for "what browsers do" (section 3.1). adaR is a data-raw oracle only and never
# a runtime dependency (section 12). Go net/netip is the second implementation
# of the "strict" dialect, and curl is the one dialect raddr composes rather
# than measures -- see data-raw/oracle-tools.R for both. The curl column is what
# open item O13 asked for: the IPv6 half of the curl composition was derived,
# never run.
#
#     Rscript data-raw/oracle-ipv6.R
#
# Recorded with adaR 0.3.5, go1.26.5 and curl 8.20.0 (libcurl/8.20.0) on
# 2026-07-28. Re-run after any upgrade to those three or to libc; the fixture
# is asserted by tests/testthat/test-ipv6.R, so drift fails loudly.

stopifnot(requireNamespace("adaR", quietly = TRUE))

source("tests/testthat/helper-dialects.R")
source("data-raw/oracle-tools.R")

libc <- read.csv(
  "tests/testthat/fixtures/ipv6-libc.csv",
  colClasses = "character", na.strings = NULL
)

# ada serializes a host per RFC 5952, which compresses. The fixture stores the
# fully expanded form so that it says nothing about formatting -- that is Epic
# E's subject -- so ada's answer is expanded back out through expand_v6(), which
# now lives in data-raw/oracle-tools.R because the curl probe needs it too.

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
netip <- netip_readings(literal, 6L)
libc$netip <- netip$addr
libc$netip_zone <- escape_control(netip$zone)
libc$curl <- curl_readings(literal, 6L)

write.csv(
  libc,
  "tests/testthat/fixtures/ipv6-oracle.csv",
  row.names = FALSE,
  na = ""
)

cat("wrote", nrow(libc), "rows to tests/testthat/fixtures/ipv6-oracle.csv\n")
