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

cat("\n")
