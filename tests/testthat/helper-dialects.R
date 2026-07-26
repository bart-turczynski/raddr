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
  )
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
# rewrite a test input while normalizing line endings.
unescape_control <- function(x) {
  x <- gsub("\\\\t", "\t", x)
  x <- gsub("\\\\r", "\r", x)
  x <- gsub("\\\\n", "\n", x)
  x <- gsub("\\\\v", "\v", x)
  x <- gsub("\\\\f", "\f", x)
  gsub("\\\\\\\\", "\\\\", x)
}
