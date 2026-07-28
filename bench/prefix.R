# Longest-prefix-match over the registry tables: four ways of reading the same
# blocks (O5, RADD-rivkgsza). See docs/architecture.md sections 7.1 and 11.1.6,
# which is what this file measured.
#
# `prefix_match()` used to walk the blocks in descending prefix-length order and
# keep the first hit, which is one pass over the address vector per block.
# RADD-ehyllbox found that for the *containment* question the walk is avoidable
# -- group the blocks by prefix length and each group costs one hash lookup --
# but left open whether the same regrouping answers longest-prefix match, which
# has to report *which* block matched rather than whether one did.
#
# It does, and it now ships. `linear` below is the walk it replaced, kept here
# in full: a benchmark that measured the shipped function against itself would
# report 1.00x forever, and the number the design record quotes has to stay
# reproducible.
#
# Four candidates, all returning the identical answer:
#
#   linear   the walk this replaced, one pass per block
#   grouped  one pass per distinct (space, prefix length), `vec_match()` for the
#            row, groups visited longest-first so the first hit is still the
#            longest one -- what R/classify.R now does
#   sorted   the same grouping, binary search over lexicographically sorted keys
#            instead of a hash -- the "sorted masked vector" of O5
#   trie     `triebeard`, keys are the binary prefix strings
#
# Every candidate is checked against the shipped `prefix_match()` before
# anything is timed, `grouped` included: it is a copy, and a copy that has
# drifted is worth catching.
#
# Run from the package root:
#   Rscript bench/prefix.R
#
# Needs triebeard, which is not a package dependency.

devtools::load_all(".", quiet = TRUE)

n <- 1e6
set.seed(1)

has_trie <- requireNamespace("triebeard", quietly = TRUE)

# Same best-of-seven as bench/record.R, and for the same reason: a ratio divided
# by a sub-second baseline needs it.
timing <- function(expr, times = 7) {
  call <- substitute(expr)
  env <- parent.frame()
  eval(call, env)
  min(replicate(times, system.time(eval(call, env))[["elapsed"]]))
}

report <- function(label, value, unit) {
  cat(sprintf("%-40s %9.3f %s\n", label, value, unit))
}

# The index builds are sub-millisecond, which is below what `system.time()` can
# resolve -- one build times as either 0 or 1 ms and neither is the answer. So
# the build is repeated inside the timed region and the total divided back.
build_ms <- function(expr, reps = 200L) {
  call <- substitute(expr)
  env <- parent.frame()
  loop <- function() for (i in seq_len(reps)) eval(call, env)
  loop()
  min(replicate(5L, system.time(loop())[["elapsed"]])) / reps * 1000
}

report_ms <- function(label, value) {
  cat(sprintf("%-40s %9.4f ms\n", label, value))
}

# --- the tables ---------------------------------------------------------------

# `prefix_table()` is R/classify.R's, which is why it is named there rather than
# inlined into `prefix_index()`.

# The addresses reduced once to what every candidate reads: the space each
# searches and its four words as unsigned doubles. Shared so that no candidate
# is charged for work another one also does.
addr_view <- function(x) {
  family <- field(x, "family")
  known <- !is.na(family)
  is_v4 <- known & family == "v4"
  list(
    n = length(family),
    # v6 and v6_4in6 both search the IPv6 half, exactly as in `prefix_match()`.
    in_space = list(v4 = is_v4, v6 = known & !is_v4),
    words = lapply(
      c("w1", "w2", "w3", "w4"),
      function(nm) widen_word(field(x, nm))
    )
  )
}

# --- linear: the walk this replaced, one pass per block -----------------------

# Verbatim `build_prefix_index()` and `prefix_match()` as of 25188dc, before the
# regrouping landed. Sorted by DESCENDING prefix length, so walking in order and
# keeping the first hit is longest-prefix-match.
linear_index <- function(table) {
  ord <- order(table$prefix_len, decreasing = TRUE)
  words <- lapply(
    list(table$w1, table$w2, table$w3, table$w4),
    function(w) widen_word(w[ord])
  )
  prefix_len <- table$prefix_len[ord]
  space <- table$space[ord]

  checks <- lapply(seq_along(ord), function(i) {
    plan <- prefix_word_plan(prefix_len[[i]], space[[i]])
    lapply(plan, function(step) {
      step$target <- words[[step$word]][[i]] %/% step$divisor
      step
    })
  })

  list(row = ord, space = space, checks = checks)
}

linear_match <- function(view, index) {
  out <- rep(NA_integer_, view$n)
  if (view$n == 0L) {
    return(out)
  }
  for (i in seq_along(index$row)) {
    hit <- view$in_space[[index$space[[i]]]] & is.na(out)
    if (!any(hit)) {
      next
    }
    for (step in index$checks[[i]]) {
      hit[hit] <- (view$words[[step$word]][hit] %/% step$divisor) == step$target
      if (!any(hit)) {
        break
      }
    }
    out[hit] <- index$row[[i]]
  }
  out
}

# --- grouped: one pass per distinct (space, prefix length) --------------------

# `split()` keeps each group's rows in ascending table order, which is what
# makes the tie-break match the shipped walk: `order(decreasing = TRUE)` is
# stable, so two blocks with the same length and the same key resolve to the
# earlier row on both sides.
grouped_index <- function(table) {
  words <- lapply(list(table$w1, table$w2, table$w3, table$w4), widen_word)
  len <- table$prefix_len
  groups <- split(seq_along(len), paste(table$space, len))

  lens <- vapply(groups, function(rows) len[[rows[[1L]]]], integer(1L))
  groups <- unname(groups[order(lens, decreasing = TRUE)])

  lapply(groups, function(rows) {
    space <- table$space[[rows[[1L]]]]
    plan <- prefix_word_plan(table$prefix_len[[rows[[1L]]]], space)
    list(
      space = space,
      plan = plan,
      rows = rows,
      targets = lapply(plan, function(step) {
        words[[step$word]][rows] %/% step$divisor
      })
    )
  })
}

group_keys <- function(words, plan, sel) {
  lapply(plan, function(step) words[[step$word]][sel] %/% step$divisor)
}

# Which target row each key row equals, or NA. One column is the common case --
# every IPv4 plan has exactly one word whatever the prefix length -- so it skips
# the data frame, as `keys_in_targets()` does in R/within.R.
keys_match <- function(keys, targets) {
  if (!length(keys)) {
    # A /0 covers its whole space; no table here has one.
    return(rep(1L, 0L))
  }
  if (length(keys) == 1L) {
    return(match(keys[[1L]], targets[[1L]]))
  }
  names(keys) <- paste0("k", seq_along(keys))
  names(targets) <- paste0("k", seq_along(targets))
  vctrs::vec_match(new_data_frame(keys), new_data_frame(targets))
}

grouped_match <- function(view, index) {
  out <- rep(NA_integer_, view$n)
  if (view$n == 0L) {
    return(out)
  }
  for (g in index) {
    # Longest-first, so an address already matched is done: whatever it matches
    # later is shorter by construction.
    sel <- view$in_space[[g$space]] & is.na(out)
    if (!any(sel)) {
      next
    }
    idx <- keys_match(group_keys(view$words, g$plan, sel), g$targets)
    found <- !is.na(idx)
    if (!any(found)) {
      next
    }
    out[which(sel)[found]] <- g$rows[idx[found]]
  }
  out
}

# --- sorted: the same grouping, binary search instead of a hash ---------------

sorted_index <- function(table) {
  lapply(grouped_index(table), function(g) {
    if (!length(g$plan)) {
      return(g)
    }
    ord <- do.call(order, unname(g$targets))
    g$targets <- lapply(g$targets, function(t) t[ord])
    g$rows <- g$rows[ord]
    g
  })
}

# Vectorized lower-bound search over lexicographically sorted key columns. The
# multi-column compare is why this is not `findInterval()`: an IPv6 key above a
# /32 spans up to four words and no single double holds 128 bits.
sorted_lookup <- function(keys, targets) {
  m <- length(targets[[1L]])
  n <- length(keys[[1L]])
  lo <- rep(1L, n)
  hi <- rep(m, n)

  repeat {
    active <- lo < hi
    if (!any(active)) {
      break
    }
    mid <- lo + (hi - lo) %/% 2L
    # key <= target[mid], decided word by word.
    less <- rep(FALSE, n)
    undecided <- rep(TRUE, n)
    for (k in seq_along(keys)) {
      t <- targets[[k]][mid]
      less <- less | (undecided & keys[[k]] < t)
      undecided <- undecided & keys[[k]] == t
    }
    le <- less | undecided
    lo <- ifelse(active & !le, mid + 1L, lo)
    hi <- ifelse(active & le, mid, hi)
  }

  # `lo` can land at m + 1 when every key is smaller, so the equality check is
  # guarded rather than assumed.
  ok <- lo <= m
  at <- ifelse(ok, lo, 1L)
  for (k in seq_along(keys)) {
    ok <- ok & keys[[k]] == targets[[k]][at]
  }
  ifelse(ok, lo, NA_integer_)
}

sorted_match <- function(view, index) {
  out <- rep(NA_integer_, view$n)
  if (view$n == 0L) {
    return(out)
  }
  for (g in index) {
    sel <- view$in_space[[g$space]] & is.na(out)
    if (!any(sel)) {
      next
    }
    idx <- sorted_lookup(group_keys(view$words, g$plan, sel), g$targets)
    found <- !is.na(idx)
    if (!any(found)) {
      next
    }
    out[which(sel)[found]] <- g$rows[idx[found]]
  }
  out
}

# --- trie: triebeard over the binary prefix strings ---------------------------

# One trie per space, because a v4 key and a v6 key of the same bits are
# different blocks and a single trie has one namespace.
trie_index <- function(table) {
  words <- lapply(list(table$w1, table$w2, table$w3, table$w4), widen_word)
  lapply(c(v4 = "v4", v6 = "v6"), function(space) {
    rows <- which(table$space == space)
    if (!length(rows)) {
      return(NULL)
    }
    base <- words_to_addr(
      lapply(words, function(w) w[rows]),
      rep(if (space == "v4") 32L else 128L, length(rows))
    )
    triebeard::trie(
      keys = substr(addr_to_binary(base), 1L, table$prefix_len[rows]),
      values = rows
    )
  })
}

# The encoding is inside the timed region on purpose: a trie cannot read the
# words, so every call pays to turn 1e6 addresses into 1e6 bit strings.
trie_match <- function(x, view, index) {
  out <- rep(NA_integer_, view$n)
  if (view$n == 0L) {
    return(out)
  }
  for (space in c("v4", "v6")) {
    tr <- index[[space]]
    sel <- view$in_space[[space]]
    if (is.null(tr) || !any(sel)) {
      next
    }
    out[sel] <- triebeard::longest_match(tr, addr_to_binary(x[sel]))
  }
  out
}

# --- inputs -------------------------------------------------------------------

word <- function(m = n) {
  as.integer(sample.int(.Machine$integer.max, m, replace = TRUE))
}

# Addresses drawn from inside the table's own blocks, masking the same way
# `mask_words()` does. Uniform random addresses miss almost every
# special-purpose block, and a walk that never matches never shortens -- so the
# hit-heavy case is measured separately rather than left to the reader.
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

# The first and last address of every block in a table. Random draws exercise
# the common path and say nothing about the edges, and an off-by-one in a
# divisor is exactly the bug that would survive 6e6 random rows and break on the
# broadcast address of one /31. Two rows per block, every block, every table.
boundary_corpus <- function(table) {
  words <- lapply(
    list(table$w1, table$w2, table$w3, table$w4),
    function(w) widen_word(w)
  )
  len <- table$prefix_len
  is_v4 <- table$space == "v4"

  lo <- hi <- vector("list", 4L)
  for (k in seq_len(4L)) {
    bits <- pmin(pmax(len - 32L * (k - 1L), 0L), 32L)
    bits[is_v4] <- if (k == 4L) pmin(pmax(len[is_v4], 0L), 32L) else 32L
    lo[[k]] <- words[[k]]
    hi[[k]] <- words[[k]] + (2^(32 - bits) - 1)
  }
  width <- ifelse(is_v4, 32L, 128L)
  c(words_to_addr(lo, width), words_to_addr(hi, width))
}

v4 <- raddr_address(0L, 0L, 0L, word(), "v4")
v6 <- raddr_address(word(), word(), word(), word(), "v6")

edges <- do.call(c, lapply(
  c("special", "space", "transition", "codes"),
  function(which) boundary_corpus(prefix_table(which))
))

special <- prefix_table("special")
draw_rows <- function(space) {
  sample(which(special$space == space), n, replace = TRUE)
}
inside4 <- draw_inside(special, draw_rows("v4"))
inside6 <- draw_inside(special, draw_rows("v6"))

# --- the run ------------------------------------------------------------------

cat("\n== tables ==\n")
for (which in c("special", "space", "transition", "codes")) {
  table <- prefix_table(which)
  report(
    sprintf("%s: blocks / distinct lengths", which),
    length(table$prefix_len), "blocks"
  )
  report(
    sprintf("%s: groups it collapses to", which),
    length(unique(paste(table$space, table$prefix_len))), "groups"
  )
}

cases <- list(
  list(label = "special, IPv4 random", which = "special", x = v4),
  list(label = "special, IPv6 random", which = "special", x = v6),
  list(label = "special, IPv4 inside blocks", which = "special", x = inside4),
  list(label = "special, IPv6 inside blocks", which = "special", x = inside6),
  list(label = "space, IPv4 random", which = "space", x = v4),
  list(label = "space, IPv6 random", which = "space", x = v6)
)

tables <- c("special", "space", "transition", "codes")

# The edge corpus runs against all four tables, the timed cases against the two
# big ones. A ratio between two functions that answer differently measures
# nothing, so this gate stops the script rather than annotating the output.
checks <- c(
  lapply(tables, function(which) {
    list(label = sprintf("%s, block edges", which), which = which, x = edges)
  }),
  cases
)

cat(sprintf(
  "\n== agreement, %d edge rows + 1e6 rows per timed case ==\n", length(edges)
))

indexes <- list()
for (which in tables) {
  indexes[[which]] <- list(
    linear = linear_index(prefix_table(which)),
    grouped = grouped_index(prefix_table(which)),
    sorted = sorted_index(prefix_table(which)),
    trie = if (has_trie) trie_index(prefix_table(which))
  )
}

disagreements <- 0L
for (case in checks) {
  view <- addr_view(case$x)
  idx <- indexes[[case$which]]
  want <- prefix_match(case$x, case$which)

  got <- list(
    linear = linear_match(view, idx$linear),
    grouped = grouped_match(view, idx$grouped),
    sorted = sorted_match(view, idx$sorted)
  )
  if (has_trie) {
    got$trie <- trie_match(case$x, view, idx$trie)
  }
  for (name in names(got)) {
    a <- got[[name]]
    same <- (is.na(a) & is.na(want)) | (!is.na(a) & !is.na(want) & a == want)
    bad <- sum(!same)
    disagreements <- disagreements + bad
    report(sprintf("%s vs %s", name, case$label), bad, "rows")
  }
}

if (disagreements > 0L) {
  stop("candidates disagree with prefix_match(); the timings mean nothing")
}

cat("\n== index build, once per table ==\n")
for (which in tables) {
  table <- prefix_table(which)
  report_ms(sprintf("linear index, %s", which), build_ms(linear_index(table)))
  report_ms(sprintf("grouped index, %s", which), build_ms(grouped_index(table)))
  report_ms(sprintf("sorted index, %s", which), build_ms(sorted_index(table)))
  if (has_trie) {
    report_ms(sprintf("trie index, %s", which), build_ms(trie_index(table)))
  }
}

cat("\n== lookup, 1e6 addresses ==\n")
for (case in cases) {
  view <- addr_view(case$x)
  idx <- indexes[[case$which]]
  x <- case$x
  which <- case$which

  linear <- timing(linear_match(view, idx$linear), times = 5)
  grouped <- timing(grouped_match(view, idx$grouped), times = 5)
  sorted <- timing(sorted_match(view, idx$sorted), times = 5)

  # `shipped` reads the memoized index and its own words rather than the shared
  # view, so it is the same algorithm as `grouped` plus the per-call setup every
  # caller pays. The gap between the two rows is that setup and nothing else.
  shipped <- timing(prefix_match(x, which), times = 5)

  cat(sprintf("\n-- %s\n", case$label))
  report("linear (replaced)", linear, "s")
  report("grouped", grouped, "s")
  report("sorted", sorted, "s")
  if (has_trie) {
    trie <- timing(trie_match(x, view, idx$trie), times = 3)
    report("trie", trie, "s")
  }

  report("prefix_match() (shipped)", shipped, "s")

  report("ratio, grouped / linear", grouped / linear, "x")
  report("ratio, sorted / linear", sorted / linear, "x")
  if (has_trie) {
    report("ratio, trie / linear", trie / linear, "x")
  }
  report("ratio, shipped / linear", shipped / linear, "x")
}

cat("\n")
