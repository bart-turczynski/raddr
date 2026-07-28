# Shared oracle probes for data-raw/oracle-ipv4.R and data-raw/oracle-ipv6.R.
#
# Two implementations that the other oracles do not cover:
#
#   netip_readings()  Go net/netip, the second implementation of the "strict"
#                     dialect section 3.1 claims Python, Go and Rust share.
#   curl_readings()   real curl, against which section 3.2's composition claim
#                     (curl = aton falling back to pton) has never been run.
#
# Both are maintainer-run, ahead of time. Nothing here is a runtime dependency
# and nothing here runs during tests -- the tests read the committed CSV.

# --- shared formatting -------------------------------------------------------

# The inverse of tests/testthat/helper-dialects.R's unescape_control(), and the
# same map data-raw/oracle-ipv6.py's ESCAPES applies. A zone ID can carry a
# trailing space, and the trailing-whitespace pre-commit hook would eat it, so
# anything written into the fixture goes through here first. The backslash is
# replaced first, which is what makes the mapping per-character.
escape_control <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub(" ", "\\s", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\v", "\\v", x, fixed = TRUE)
  gsub("\f", "\\f", x, fixed = TRUE)
}

# The IPv6 fixtures store the fully expanded form, so a recorded answer says
# nothing about formatting -- that is Epic E's subject. Anything that reports a
# compressed host (ada, curl) is expanded back out through here.
#
# curl serializes a 4-in-6 address with a dotted tail -- "[::ffff:1.2.3.4]"
# [verified 2026-07-28] -- where ada writes "::ffff:102:304". The tail is two
# 16-bit groups written base 10, so it is folded back to hex before the group
# arithmetic runs; otherwise it counts as one group and everything shifts.
expand_v6 <- function(host) {
  quad <- regmatches(host, regexpr("[0-9]+(\\.[0-9]+){3}$", host))
  if (length(quad) == 1L) {
    octets <- as.integer(strsplit(quad, ".", fixed = TRUE)[[1L]])
    host <- sub(
      "[0-9]+(\\.[0-9]+){3}$",
      sprintf(
        "%x:%x",
        octets[[1L]] * 256L + octets[[2L]],
        octets[[3L]] * 256L + octets[[4L]]
      ),
      host
    )
  }
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

# --- Go net/netip ------------------------------------------------------------

# Every field is NUL-terminated, so the count of terminators is the count of
# fields. R cannot hold a NUL inside a string, which is the whole reason this
# splits the raw vector rather than rawToChar()ing it first.
split_nul <- function(r) {
  stops <- which(r == as.raw(0L))
  starts <- c(1L, stops + 1L)[seq_along(stops)]
  vapply(
    seq_along(stops),
    function(i) {
      if (stops[[i]] <= starts[[i]]) {
        ""
      } else {
        rawToChar(r[starts[[i]]:(stops[[i]] - 1L)])
      }
    },
    character(1)
  )
}

# One `go run` for the whole vector, because compiling per literal is the
# slowest possible way to ask. NUL delimits, so no escaping grammar has to be
# agreed between R and Go; see the note in data-raw/oracle-netip.go.
netip_readings <- function(literal, family) {
  stopifnot(family %in% c(4L, 6L))
  if (nzchar(Sys.which("go")) == FALSE) {
    stop("oracle-netip needs a Go toolchain on PATH")
  }

  payload <- unlist(lapply(literal, function(x) c(charToRaw(x), as.raw(0L))))

  infile <- tempfile("netip-in")
  outfile <- tempfile("netip-out")
  on.exit(unlink(c(infile, outfile)), add = TRUE)
  writeBin(payload, infile)

  status <- system2(
    "go",
    c("run", shQuote("data-raw/oracle-netip.go"), "-family", family),
    stdin = infile, stdout = outfile, stderr = ""
  )
  if (!identical(status, 0L)) {
    stop("oracle-netip exited ", status)
  }

  raw_out <- readBin(outfile, "raw", n = file.size(outfile))
  fields <- split_nul(raw_out)
  if (length(fields) != 2L * length(literal)) {
    stop(
      "oracle-netip returned ", length(fields), " fields for ",
      length(literal), " literals"
    )
  }

  list(
    addr = fields[c(TRUE, FALSE)],
    zone = fields[c(FALSE, TRUE)]
  )
}

# --- real curl ---------------------------------------------------------------

# Which literals curl can be asked about at all.
#
# curl takes a URL, and raddr's addr_curl() models curl's RESOLVER, not its URL
# parser -- the two are different layers and comparing the wrong one measures
# the wrong thing. So any literal whose text would be consumed by the URL layer
# before the resolver sees it is recorded as not measurable ("-") rather than as
# a result raddr should match:
#
#   whitespace and C0 controls  the URL parser strips or rejects them
#   % zones                     a URL needs %25, so asking measures unescaping
#   [ ]                         the brackets are ours to add, for v6
#   / ? # @                     they end the authority
#   :                           a port, for v4; fine inside brackets for v6
#
# This is the same caveat the adaR probes carry, for the same reason.
# Tested one character at a time rather than through a character class: "]" has
# to lead a class to be literal, so the obvious sprintf("[%s]", "[]/?#@%")
# silently compiles to something else entirely and lets every "%" through.
curl_measurable <- function(literal, family) {
  structural <- c("[", "]", "/", "?", "#", "@", "%")
  if (family == 4L) {
    structural <- c(structural, ":")
  }
  hits <- lapply(structural, function(ch) grepl(ch, literal, fixed = TRUE))
  !grepl("[[:space:][:cntrl:]]", literal) & !Reduce(`|`, hits)
}

# A resolver that answers for names that do not exist would turn every
# rejection into a fabricated address, silently. RFC 2606 reserves .invalid
# precisely so this can be asked, and a random label keeps a cached answer from
# a previous run out of it.
#
# This guard exists because of how curl actually works, which is worth stating:
# curl's leniency IS getaddrinfo. Blocking DNS with --doh-url looks like the
# careful thing to do and is not -- it removes getaddrinfo and with it every
# aton-style reading, so curl appears to reject 4294967296, 0X7F000001, 0x.1
# and 040000000000, and section 3.2's composition appears to fail on 11 rows.
# That was measured on 2026-07-28 and it was the instrument, not curl: with the
# system resolver reachable, all four come back exactly as the composition
# predicts. There is no verbose output that separates "read numerically" from
# "resolved as a name" either, because in curl they are one getaddrinfo call.
# So the probe lets DNS work and checks the resolver is honest instead.
curl_resolver_is_honest <- function() {
  label <- paste0(
    "raddr-oracle-canary-",
    paste(sample(c(letters, 0:9), 16L, replace = TRUE), collapse = "")
  )
  out <- suppressWarnings(system2(
    "curl",
    c(
      "-s", "-v", "-o", "/dev/null", "--connect-timeout", "1",
      "--max-time", "5", shQuote(paste0("http://", label, ".invalid:9/"))
    ),
    stdout = NULL, stderr = TRUE
  ))
  length(grep("^\\*\\s+Trying ", out)) == 0L
}

# curl prints "* Trying <addr>:<port>..." after it has resolved the host and
# before the connection completes, which is the resolver's answer read straight
# off the wire.
#
# --interface pins the source to loopback so a literal that parses to a routable
# address cannot actually send a packet anywhere; the Trying line is printed
# before the connection is attempted, so the reading survives the failure.
#
# This does perform DNS lookups, for exactly those literals curl declines to
# read as an address. That is authoring-time only -- the package itself makes no
# network access, and data-raw/build-registry.R already fetches from IANA.
curl_readings <- function(literal, family) {
  stopifnot(family %in% c(4L, 6L))
  if (nzchar(Sys.which("curl")) == FALSE) {
    stop("the curl oracle needs curl on PATH")
  }
  if (!curl_resolver_is_honest()) {
    stop(
      "this resolver answers for names that do not exist, so a curl rejection ",
      "cannot be told from a parse; re-run on a resolver that returns NXDOMAIN"
    )
  }

  iface <- if (family == 4L) "127.0.0.1" else "::1"
  measurable <- curl_measurable(literal, family)

  one <- function(lit) {
    url <- if (family == 4L) {
      paste0("http://", lit, ":9/")
    } else {
      paste0("http://[", lit, "]:9/")
    }
    out <- suppressWarnings(system2(
      "curl",
      c(
        "-s", "-v", "-o", "/dev/null",
        "--interface", iface,
        "--connect-timeout", "0.3",
        "--max-time", "5",
        shQuote(url)
      ),
      stdout = NULL, stderr = TRUE
    ))
    hit <- grep("^\\*\\s+Trying ", out, value = TRUE)
    if (length(hit) == 0L) {
      return("")
    }
    # Happy eyeballs can print more than one; the first is what curl read.
    addr <- sub("^\\*\\s+Trying (.*):9\\.\\.\\..*$", "\\1", hit[[1L]])
    if (identical(addr, hit[[1L]])) {
      return("")
    }
    if (family == 4L) {
      if (!grepl("^[0-9]+(\\.[0-9]+){3}$", addr)) {
        return("")
      }
      return(addr)
    }
    if (!startsWith(addr, "[") || !endsWith(addr, "]")) {
      return("")
    }
    expand_v6(substr(addr, 2L, nchar(addr) - 1L))
  }

  out <- rep("-", length(literal))
  out[measurable] <- vapply(literal[measurable], one, character(1),
    USE.NAMES = FALSE
  )
  out
}
