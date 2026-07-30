# Benchmark raddr against the two R peers in the library-divergence survey
# (RADD-jlfhnbgu).
#
# The comparisons below use public, string-facing APIs and include parsing in
# every timing. That is the only common input model: iptools does not expose an
# address vector type. Each result is checked before it is timed.
#
# Run from the package root:
#   Rscript bench/peers.R
#
# For a quick smoke run:
#   RADDR_BENCH_N=1000 RADDR_BENCH_TIMES=1 Rscript bench/peers.R
#
# Needs ipaddress and the archived iptools 0.7.2, neither of which is a package
# dependency. iptools was archived by CRAN and is no longer in the active index.
# Archived source directory:
# https://cran.r-project.org/src/contrib/Archive/iptools/ # nolint: line_length_linter.
# File: iptools_0.7.2.tar.gz

for (package in c("devtools", "ipaddress", "iptools")) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("bench/peers.R needs ", package)
  }
}

devtools::load_all(".", quiet = TRUE)

n <- as.integer(Sys.getenv("RADDR_BENCH_N", "1000000"))
times <- as.integer(Sys.getenv("RADDR_BENCH_TIMES", "5"))
if (is.na(n) || n < 1L || is.na(times) || times < 1L) {
  stop("RADDR_BENCH_N and RADDR_BENCH_TIMES must be positive integers")
}

set.seed(20260731)

octet <- function() sample.int(256L, n, replace = TRUE) - 1L
hextet <- function() sample.int(65536L, n, replace = TRUE) - 1L

v4 <- sprintf("%d.%d.%d.%d", octet(), octet(), octet(), octet())
v6 <- sprintf("%x:%x::%x:%x", hextet(), hextet(), hextet(), hextet())

# Force positive and negative multicast rows into both corpora. Uniform random
# IPv6 would otherwise produce too few ff00::/8 hits for a useful agreement
# check at smoke-test sizes.
multicast4 <- v4
multicast4[seq.int(1L, n, by = 4L)] <- sprintf(
  "239.%d.%d.%d", octet(), octet(), octet()
)[seq.int(1L, n, by = 4L)]
multicast6 <- v6
multicast6[seq.int(1L, n, by = 4L)] <- sprintf(
  "ff02::%x", hextet()
)[seq.int(1L, n, by = 4L)]

blocks4 <- c(
  "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
  "172.16.0.0/12", "192.0.2.0/24", "192.168.0.0/16",
  "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "224.0.0.0/4"
)

identity_result <- function(x) x
as_plain_list <- function(x) as.list(x)
as_decimal_character <- function(x) as.character(x)
as_numeric_character <- function(x) sprintf("%.0f", x)

implementation <- function(run, normalize = identity_result) {
  list(run = run, normalize = normalize)
}

operations <- list(
  v4_roundtrip = list(
    raddr = implementation(function() addr_format(addr_strict(v4))),
    ipaddress = implementation(function() format(ipaddress::ip_address(v4))),
    iptools = implementation(
      function() iptools::numeric_to_ip(iptools::ip_to_numeric(v4))
    )
  ),
  v4_to_integer = list(
    raddr = implementation(
      function() addr_to_integer(addr_strict(v4)),
      as_decimal_character
    ),
    ipaddress = implementation(
      function() ipaddress::ip_to_integer(ipaddress::ip_address(v4)),
      as_decimal_character
    ),
    iptools = implementation(
      function() iptools::ip_to_numeric(v4),
      as_numeric_character
    )
  ),
  v6_to_bytes = list(
    raddr = implementation(
      function() addr_to_bytes(addr_strict(v6)),
      as_plain_list
    ),
    ipaddress = implementation(
      function() ipaddress::ip_to_bytes(ipaddress::ip_address(v6)),
      as_plain_list
    ),
    iptools = implementation(
      function() iptools::ipv6_to_bytes(v6),
      as_plain_list
    )
  ),
  v4_within_any = list(
    raddr = implementation(
      function() addr_within_any(addr_strict(v4), blocks4)
    ),
    ipaddress = implementation(
      function() {
        ipaddress::is_within_any(
          ipaddress::ip_address(v4), ipaddress::ip_network(blocks4)
        )
      }
    ),
    iptools = implementation(function() iptools::ip_in_any(v4, blocks4))
  ),
  v4_multicast = list(
    raddr = implementation(
      function() addr_within_any(addr_strict(multicast4), "224.0.0.0/4")
    ),
    ipaddress = implementation(
      function() ipaddress::is_multicast(ipaddress::ip_address(multicast4))
    ),
    iptools = implementation(function() iptools::is_multicast(multicast4))
  ),
  v6_multicast = list(
    raddr = implementation(
      function() addr_within_any(addr_strict(multicast6), "ff00::/8")
    ),
    ipaddress = implementation(
      function() ipaddress::is_multicast(ipaddress::ip_address(multicast6))
    ),
    iptools = implementation(function() iptools::is_multicast(multicast6))
  )
)

best_elapsed <- function(fn) {
  fn()
  min(replicate(times, system.time(fn())[["elapsed"]]))
}

cat(sprintf(
  "R %s | raddr %s | ipaddress %s | iptools %s\n",
  getRversion(), utils::packageVersion("raddr"),
  utils::packageVersion("ipaddress"), utils::packageVersion("iptools")
))
cat(sprintf("n=%d | best of %d | seed=20260731\n\n", n, times))
cat(sprintf(
  "%-18s %-11s %10s %14s %10s\n",
  "operation", "library", "seconds", "rows/second", "vs fastest"
))

for (operation in names(operations)) {
  implementations <- operations[[operation]]
  answers <- lapply(
    implementations,
    function(one) one$normalize(one$run())
  )
  reference <- answers[[1L]]
  disagreements <- vapply(
    answers[-1L],
    function(answer) {
      if (is.list(reference)) {
        sum(!mapply(identical, reference, answer))
      } else {
        sum(reference != answer, na.rm = TRUE)
      }
    },
    integer(1L)
  )
  if (any(disagreements != 0L) ||
        any(vapply(answers, anyNA, logical(1L)))) {
    stop(
      operation, " failed agreement: ",
      paste(names(disagreements), disagreements, sep = "=", collapse = ", ")
    )
  }

  elapsed <- vapply(
    implementations,
    function(one) best_elapsed(one$run),
    numeric(1L)
  )
  fastest <- min(elapsed)
  for (library in names(elapsed)) {
    cat(sprintf(
      "%-18s %-11s %10.3f %14.0f %10.2fx\n",
      operation, library, elapsed[[library]], n / elapsed[[library]],
      elapsed[[library]] / fastest
    ))
  }
  cat(sprintf("%-18s %-11s %10d\n\n", operation, "disagreements", 0L))
}
