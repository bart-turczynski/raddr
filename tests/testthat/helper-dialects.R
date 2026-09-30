# The six exported parsers, in the order section 3.2 introduces them. Shared,
# because more than one suite quantifies over "every dialect" and a second copy
# would let one file gain a dialect the other never hears about.
all_dialects <- c("strict", "whatwg", "pton", "aton", "getaddrinfo", "curl")

dialect_fn <- function(name) {
  switch(
    name,
    strict = addr_strict,
    whatwg = addr_whatwg,
    pton = addr_pton,
    aton = addr_aton,
    getaddrinfo = addr_getaddrinfo,
    curl = addr_curl,
    stop("unknown dialect: ", name)
  ) # nolint: unreachable_code_linter.
}

# A row-major literal table, so a divergence table in a test reads the way it
# reads in the docs.
rows_table <- function(names, ...) {
  values <- c(...)
  out <- as.data.frame(
    matrix(values, ncol = length(names), byrow = TRUE),
    stringsAsFactors = FALSE
  )
  names(out) <- names
  out
}

# The fixture escapes control characters so it stays plain ASCII and git cannot
# rewrite a test input while normalizing line endings. The IPv6 fixture escapes
# the space as well, because a zone ID can carry a trailing one and the
# trailing-whitespace hook would eat it; the IPv4 fixture has no such column and
# leaves its spaces literal, which this handles either way.
unescape_control <- function(x) {
  x <- gsub("\\s", " ", x, fixed = TRUE)
  x <- gsub("\\t", "\t", x, fixed = TRUE)
  x <- gsub("\\r", "\r", x, fixed = TRUE)
  x <- gsub("\\n", "\n", x, fixed = TRUE)
  x <- gsub("\\v", "\v", x, fixed = TRUE)
  x <- gsub("\\f", "\f", x, fixed = TRUE)
  gsub("\\\\", "\\", x, fixed = TRUE)
}
