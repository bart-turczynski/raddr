# Benchmark `addr_classify()` at 1e6 addresses (RADD-jyeuyxqs, O1).
#
# O1's target list is parse v4, parse v6, classify, within_any and format v6,
# all within 3x of `ipaddress`. Four of the five were measured by
# `bench/record.R` (sections 11.1.1, 11.1.2, 11.1.5) and section 11.2.
# Classification was not, and this file is the missing one.
#
# Run from the package root:
#   Rscript bench/classify.R
#
# Needs ipaddress, which is not a package dependency.
#
# --- what the baseline can and cannot be --------------------------------------
#
# `ipaddress` has no `classify()`. It has eleven boolean predicates, each of
# which answers one question about one block set in C++. `addr_classify()`
# answers all eleven at once and then keeps going: which block, its name, RFC,
# footnotes, category, the five IANA policy columns, the termination date, the
# registry it came from and that registry's version, plus the embedded address
# extracted out of the transition formats. There is no way to make that
# like-for-like, so the file reports both ends of the honest range instead of
# picking one:
#
#   - against the **bundle** of all eleven predicates, which is the closest any
#     sequence of `ipaddress` calls comes to the same question; and
#   - against a **single** predicate, which is the harshest reading available
#     and the one to quote if only one number is wanted.
#
# Neither is a like-for-like ratio. Both are reported so the spread is visible.

devtools::load_all(".", quiet = TRUE)

if (!requireNamespace("ipaddress", quietly = TRUE)) {
  stop("bench/classify.R needs ipaddress")
}

n <- 1e6
set.seed(1)

timing <- function(expr, times = 5) {
  call <- substitute(expr)
  env <- parent.frame()
  eval(call, env)
  min(replicate(times, system.time(eval(call, env))[["elapsed"]]))
}

report <- function(label, value, unit) {
  cat(sprintf("%-42s %8.3f %s\n", label, value, unit))
}

# --- corpora ------------------------------------------------------------------

# `bench/record.R` and `bench/prefix.R` draw words with
# `sample.int(.Machine$integer.max)`, which never sets the top bit. That is
# harmless when the operation does not care which bits it moves, and it is not
# harmless here: an IPv4 address with a clear top bit can never be multicast
# (224.0.0.0/4), broadcast, or in 192.168.0.0/16, so half the interesting
# registry rows would be unreachable by construction. So this file draws the
# full 2^32 range as widened doubles and lets `words_to_addr()` narrow them,
# which also puts the 0x80000000 pattern (section 5.1.1) into the corpus rather
# than out of it.
full_word <- function(m = n) floor(stats::runif(m) * 2^32)

random_v4 <- words_to_addr(
  list(rep(0, n), rep(0, n), rep(0, n), full_word()),
  rep(32L, n)
)
random_v6 <- words_to_addr(
  list(full_word(), full_word(), full_word(), full_word()),
  rep(128L, n)
)

# Uniform random addresses land in the special-purpose registry a fraction of a
# percent of the time, so on the random corpora the special layer answers almost
# nothing and the embedding extractor never fires. The hit-heavy case is a
# different measurement, not a worse one, and it is the one that exercises the
# transition formats -- so both are run. Same masking as `bench/prefix.R`'s
# `draw_inside()`.
draw_inside <- function(table, rows) {
  m <- length(rows)
  words <- lapply(
    list(table$w1, table$w2, table$w3, table$w4),
    function(w) widen_word(w)[rows]
  )
  len <- table$prefix_len[rows]
  is_v4 <- table$space[rows] == "v4"

  out <- vector("list", 4L)
  for (k in seq_len(4L)) {
    bits <- pmin(pmax(len - 32L * (k - 1L), 0L), 32L)
    bits[is_v4] <- if (k == 4L) pmin(pmax(len[is_v4], 0L), 32L) else 32L
    out[[k]] <- words[[k]] + floor(stats::runif(m) * 2^(32 - bits))
  }
  words_to_addr(out, ifelse(is_v4, 32L, 128L))
}

special <- prefix_table("special")
inside_v4 <- draw_inside(special, sample(which(special$space == "v4"), n, TRUE))
inside_v6 <- draw_inside(special, sample(which(special$space == "v6"), n, TRUE))

corpora <- list(
  list(label = "IPv4 random", x = random_v4),
  list(label = "IPv6 random", x = random_v6),
  list(label = "IPv4 inside special blocks", x = inside_v4),
  list(label = "IPv6 inside special blocks", x = inside_v6)
)

# The eleven predicates, in the order the section 11 table reports them. All
# eleven accept both families -- the v6-only ones return FALSE on IPv4 rather
# than erroring -- so the bundle is the same eleven calls on every corpus and
# the columns stay comparable across rows.
predicates <- c(
  "is_private", "is_global", "is_reserved", "is_multicast", "is_loopback",
  "is_link_local", "is_site_local", "is_unspecified", "is_6to4", "is_teredo",
  "is_ipv4_mapped"
)

# --- the run ------------------------------------------------------------------

for (corpus in corpora) {
  cat(sprintf("\n== %s ==\n", corpus$label))
  x <- corpus$x

  ours <- timing(addr_classify(x))
  report("addr_classify", ours, "s")

  # Decomposed, so the ratios below can be read as a statement about a layer
  # rather than about the whole call. The two lookups and the embedding pass are
  # timed as themselves; the remainder is what the record costs to assemble.
  t_special <- timing(prefix_match(x, "special"))
  t_space <- timing(prefix_match(x, "space"))
  kind <- embedded_kind_of(x)
  t_kind <- timing(embedded_kind_of(x))
  t_embed <- timing(extract_embeddings(x, kind))
  report("  prefix_match, special", t_special, "s")
  report("  prefix_match, space", t_space, "s")
  report("  embedded_kind_of", t_kind, "s")
  report("  extract_embeddings", t_embed, "s")
  report(
    "  record assembly (remainder)",
    ours - t_special - t_space - t_kind - t_embed, "s"
  )

  theirs_addr <- ipaddress::ip_address(addr_format(x))
  each <- vapply(predicates, function(f) {
    fn <- getExportedValue("ipaddress", f)
    timing(fn(theirs_addr))
  }, numeric(1L))
  for (f in predicates) {
    report(sprintf("  ipaddress::%s", f), each[[f]], "s")
  }

  bundle <- sum(each)
  report("ipaddress, all 11 predicates", bundle, "s")
  report("ratio, classify / bundle", ours / bundle, "x")
  report("ratio, classify / one predicate", ours / max(each), "x")
  report("  (the cheapest predicate)", ours / min(each), "x")
}

# --- agreement ----------------------------------------------------------------

# A ratio between two functions that answer differently is not a measurement of
# anything, which is why `bench/record.R` gates its containment timings on a
# disagreement count. Most of `addr_classify()` cannot be gated that way: it is
# registry-derived (P4) where `ipaddress`'s predicates are hardcoded per RFC, so
# the two are entitled to differ and a zero here would be the wrong thing to
# require -- see section 7.3, and O11a (RADD-pyinlkit) for a divergence already
# filed upstream.
#
# `embedded_kind` is the exception and the reason it is the anchor: 6to4,
# Teredo and IPv4-mapped are single fixed prefixes named in RFC 3056 section 2,
# RFC 4380 section 2.6 and RFC 4291 section 2.5.5.2 respectively, so the
# expected answer is derivable from the specs without reading either
# implementation, and both sides are answering the same question. Counts, not a
# gate, for everything else.

cat("\n== agreement, embedded_kind vs the three transition predicates ==\n")

for (corpus in corpora[c(2L, 4L)]) {
  x <- corpus$x
  kind <- as.character(embedded_kind_of(x))
  theirs_addr <- ipaddress::ip_address(addr_format(x))
  pairs <- list(
    c("6to4", "is_6to4"),
    c("teredo", "is_teredo"),
    c("ipv4_mapped", "is_ipv4_mapped")
  )
  for (pair in pairs) {
    mine <- !is.na(kind) & kind == pair[[1L]]
    theirs <- getExportedValue("ipaddress", pair[[2L]])(theirs_addr)
    report(
      sprintf("%s, %s", corpus$label, pair[[1L]]),
      sum(mine != theirs, na.rm = TRUE), "rows"
    )
    report(sprintf("  rows raddr calls %s", pair[[1L]]), sum(mine), "rows")
  }
}

cat("\n")
