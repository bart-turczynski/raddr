# Benchmark the raddr_address record at 1e6 addresses (RADD-dqxdacco).
#
# Targets from docs/architecture.md section 11:
#   memory  <= 30 MB per 1e6 addresses
#   speed   within 3x of ipaddress on every operation
#
# Run from the package root:
#   Rscript bench/record.R
#
# Needs lobstr and ipaddress, neither of which is a package dependency.

devtools::load_all(".", quiet = TRUE)

n <- 1e6
set.seed(1)

word <- function() {
  as.integer(sample.int(.Machine$integer.max, n, replace = TRUE))
}

mb <- function(x) lobstr::obj_size(x) / 1024^2

# Timing takes the best of several runs, because the interesting number is the
# work done rather than whatever else the machine was doing.
timing <- function(expr, times = 7) {
  call <- substitute(expr)
  env <- parent.frame()
  eval(call, env)
  min(replicate(times, system.time(eval(call, env))[["elapsed"]]))
}

report <- function(label, value, unit) {
  cat(sprintf("%-34s %8.3f %s\n", label, value, unit))
}

cat("\n== memory ==\n")

v4 <- raddr_address(0L, 0L, 0L, word(), "v4")
v6 <- raddr_address(word(), word(), word(), word(), "v6")
zoned <- raddr_address(
  word(), word(), word(), word(), "v6",
  zone = sample(c("lo0", "en0"), n, replace = TRUE)
)

report("raddr_address, IPv4", mb(v4), "MB")
report("raddr_address, IPv6", mb(v6), "MB")
report("raddr_address, IPv6 + zone", mb(zoned), "MB")

ip <- NULL
if (requireNamespace("ipaddress", quietly = TRUE)) {
  octet <- function() sample.int(255, n, replace = TRUE)
  ip <- ipaddress::ip_address(
    sprintf("%d.%d.%d.%d", octet(), octet(), octet(), octet())
  )
  # Not like-for-like: ipaddress has no zone field.
  report("ipaddress, IPv4 (no zone field)", mb(ip), "MB")
}

cat("\n== speed ==\n")

other <- v4
ours <- c(
  equality = timing(v4 == other),
  sort = timing(sort(v4)),
  unique = timing(unique(v4))
)
for (op in names(ours)) {
  report(paste("raddr", op), ours[[op]], "s")
}

if (!is.null(ip)) {
  theirs <- c(
    equality = timing(ip == ip),
    sort = timing(sort(ip)),
    unique = timing(unique(ip))
  )
  for (op in names(theirs)) {
    report(paste("ipaddress", op), theirs[[op]], "s")
  }

  cat("\n== ratio, raddr / ipaddress (target <= 3x) ==\n")
  for (op in names(ours)) {
    report(op, ours[[op]] / theirs[[op]], "x")
  }
}

cat("\n== parsing ==\n")

octet <- function() sample.int(255, n, replace = TRUE)
canonical <- sprintf("%d.%d.%d.%d", octet(), octet(), octet(), octet())
# Nothing here can take the plain-decimal fast path.
obfuscated <- rep(
  c("0177.0.0.1", "0x7f.0.0.1", "192.0.048.1", "2130706433"),
  length.out = n
)

parsers <- list(
  strict = addr_strict, whatwg = addr_whatwg, pton = addr_pton,
  aton = addr_aton, getaddrinfo = addr_getaddrinfo, curl = addr_curl
)
for (name in names(parsers)) {
  parser <- parsers[[name]]
  report(paste("addr", name), timing(parser(canonical)), "s")
}
report("addr_whatwg, obfuscated", timing(addr_whatwg(obfuscated)), "s")

if (!is.null(ip)) {
  theirs <- timing(ipaddress::ip_address(canonical))
  report("ipaddress::ip_address", theirs, "s")
  report("ratio, whatwg / ipaddress", timing(addr_whatwg(canonical)) / theirs, "x")
}

cat("\n== parsing, IPv6 ==\n")

hextet <- function() sample.int(65535, n, replace = TRUE)
v6_plain <- sprintf(
  "%x:%x::%x", hextet(), hextet(), hextet()
)
# The dotted-quad tail runs the IPv4 engine on top of the IPv6 one, so it is
# measured separately rather than averaged into the line above.
v6_tail <- sprintf("::ffff:%d.%d.%d.%d", octet(), octet(), octet(), octet())
v6_zoned <- paste0(v6_plain, "%lo0")

report("addr_strict, IPv6", timing(addr_strict(v6_plain)), "s")
report("addr_pton, IPv6", timing(addr_pton(v6_plain)), "s")
report("addr_pton, IPv6 + zone", timing(addr_pton(v6_zoned)), "s")
report("addr_strict, dotted tail", timing(addr_strict(v6_tail)), "s")

if (!is.null(ip)) {
  theirs <- timing(ipaddress::ip_address(v6_plain))
  report("ipaddress::ip_address, IPv6", theirs, "s")
  report("ratio, strict / ipaddress", timing(addr_strict(v6_plain)) / theirs, "x")
}

cat("\n== formatting ==\n")

# `v6` above is random bits, which almost never contain a zero field, so the
# zero-run search is measured on values that actually have runs to find.
formattable <- addr_strict(v6_plain)
mapped <- addr_strict(v6_tail)

report("addr_format, IPv4", timing(addr_format(v4)), "s")
report("addr_format, IPv6", timing(addr_format(formattable)), "s")
report("addr_format, IPv6 dense", timing(addr_format(v6)), "s")
report("addr_format, 4-in-6", timing(addr_format(mapped)), "s")
report("addr_expand, IPv6", timing(addr_expand(formattable)), "s")

if (!is.null(ip)) {
  theirs <- timing(format(ip))
  report("ipaddress format, IPv4", theirs, "s")
  report("ratio, IPv4 / ipaddress", timing(addr_format(v4)) / theirs, "x")

  ip6 <- ipaddress::ip_address(v6_plain)
  theirs6 <- timing(format(ip6))
  report("ipaddress format, IPv6", theirs6, "s")
  report("ratio, IPv6 / ipaddress", timing(addr_format(formattable)) / theirs6, "x")
}

cat("\n== addr_parse ==\n")

# Four engines over one input, plus the code bookkeeping the single-dialect
# parsers do not pay for. The interesting number is the ratio to one dialect:
# anything near 4x means the codes are close to free.
one_v4 <- timing(addr_whatwg(canonical))
one_v6 <- timing(addr_whatwg(v6_plain))
parse_v4 <- timing(addr_parse(canonical))
parse_v6 <- timing(addr_parse(v6_plain))

report("addr_parse, IPv4", parse_v4, "s")
report("addr_parse, IPv6", parse_v6, "s")
report("ratio, parse / one dialect, IPv4", parse_v4 / one_v4, "x")
report("ratio, parse / one dialect, IPv6", parse_v6 / one_v6, "x")

# Every row rejected, so every row allocates a code vector.
bad <- rep(c("1.2.3.4.5", "0177.0.0.1", "example.com", "g::1"), length(canonical) / 4)
report("addr_parse, every row rejected", timing(addr_parse(bad)), "s")

cat("\n")
