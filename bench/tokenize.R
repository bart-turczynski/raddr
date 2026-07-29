# Does base R suffice for ASCII host tokenization? (RADD-sbnlhllz, O4)
#
# Run from the package root:
#   Rscript bench/tokenize.R
#
# Needs stringi, which is not a package dependency and is the thing under
# examination.
#
# --- why the question is not "which is faster" --------------------------------
#
# O4 came from reading rurl, which reaches for `stringi` for its string work.
# The temptation is to benchmark the two and take the winner, and that framing
# is wrong twice over.
#
# First, the two are not equally priced. raddr Imports `rlang` and `vctrs` and
# nothing else; its own DESCRIPTION says it "is pure R, performs no network
# access". `stringi` is 34.7 MB installed, is a C++ package bundling ICU, and
# declares `SystemRequirements: ICU4C (>= 61, optional)`. It has no R package
# dependencies of its own, which is genuinely in its favour -- but a user
# installing raddr from source would compile ICU to parse an address literal.
# So the burden of proof sits on `stringi`: it has to be *needed*, not merely
# ahead.
#
# Second, the usual argument for `stringi` does not apply here. It buys
# locale-independent, encoding-explicit Unicode correctness -- and that is
# worth paying for in a URL parser, which is why rurl pays it. raddr's host
# tokenizer never sees a non-ASCII byte: `R/encoding.R` gates the input and the
# grammars downstream are ASCII by definition (RFC 4291 hextets, dotted-quad
# octets). The correctness case is the strong case for `stringi` and it is
# absent, which leaves only speed.
#
# So: base R is the incumbent, and this file asks whether it is *insufficient*.
#
# --- and why base R is three engines, not one ---------------------------------
#
# `grepl()` and `sub()` dispatch to TRE by default and to PCRE under
# `perl = TRUE`, and the gap between those two is not small -- `R/encoding.R`
# already records 0.99 s against 0.13 s for one scan and picks PCRE on the
# strength of it. Any comparison that pits `stringi` against R's *default*
# engine is really measuring TRE, and would credit `stringi` for a difference
# base R can close for free. Every pattern below is therefore run three ways.

if (!requireNamespace("stringi", quietly = TRUE)) {
  stop("bench/tokenize.R needs stringi")
}
devtools::load_all(".", quiet = TRUE)
si <- asNamespace("stringi")

n <- 1e6
set.seed(1)

timing <- function(expr, times = 5) {
  call <- substitute(expr)
  env <- parent.frame()
  eval(call, env)
  min(replicate(times, system.time(eval(call, env))[["elapsed"]]))
}

report <- function(label, value, unit = "s") {
  cat(sprintf("%-44s %8.3f %s\n", label, value, unit))
}

# --- corpora ------------------------------------------------------------------
#
# Distinct addresses, never `rep()` of a literal. Section 11.2.1 threw away a
# first pass for exactly that reason: R interns strings, so a homogeneous
# corpus makes every downstream hash and regex unrepresentatively cheap and
# would manufacture whatever flatness it was looking for. The same trap would
# hand this file a false tie, since both engines would be reading one cached
# CHARSXP a million times.

hextets <- function(m) sprintf("%x", sample.int(65535L, m, replace = TRUE))
octets <- function(m) sample.int(255L, m, replace = TRUE)

dense_v6 <- paste(
  hextets(n), hextets(n), hextets(n), hextets(n),
  hextets(n), hextets(n), hextets(n), hextets(n),
  sep = ":"
)
elided_v6 <- paste0("2001:db8:", hextets(n), "::", hextets(n))
dotted_v4 <- paste(octets(n), octets(n), octets(n), octets(n), sep = ".")

# The pieces, as the parser actually holds them: one flat character vector of
# 8n hextets, which is what every per-piece stage below is scored on.
pieces_v6 <- unlist(strsplit(dense_v6, ":", fixed = TRUE), use.names = FALSE)
pieces_v4 <- unlist(strsplit(dotted_v4, ".", fixed = TRUE), use.names = FALSE)

cat("\n== 0. the ceiling ============================================\n\n")

# Before comparing anything, bound what a library swap could possibly buy. If
# the replaceable stages are a minority of the call, the contest is decided
# before it starts and the rest of the file is only deciding by how much.
strict_v6 <- timing(addr_strict(dense_v6), times = 3)
strict_v4 <- timing(addr_strict(dotted_v4), times = 3)
report("addr_strict(), IPv6 dense", strict_v6)
report("addr_strict(), IPv4 dotted quad", strict_v4)

profile_lines <- function(expr, keep = 12) {
  path <- tempfile()
  on.exit(unlink(path), add = TRUE)
  Rprof(path, line.profiling = TRUE, interval = 0.005)
  force(expr)
  Rprof(NULL)
  by_line <- summaryRprof(path, lines = "show")$by.line
  by_line <- by_line[order(-by_line$self.time), , drop = FALSE]
  head(by_line[, c("self.time", "self.pct")], keep)
}

cat("\nself time by line, IPv6 dense then IPv4:\n")
print(profile_lines({
  invisible(addr_strict(dense_v6))
  invisible(addr_strict(dotted_v4))
}))

cat("\n== 1. the patterns, three engines ============================\n\n")

# Every regex on the tokenizer's hot path, run under TRE, under PCRE, and under
# ICU. Agreement is asserted rather than assumed: an engine that disagrees is
# not a candidate at any speed, and the whole point of section 5 is that the
# tiny edge case is where address parsers go wrong.
trio <- function(label, pattern, x) {
  tre <- grepl(pattern, x)
  pcre <- grepl(pattern, x, perl = TRUE)
  icu <- si$stri_detect_regex(x, pattern)
  stopifnot(identical(tre, pcre), identical(tre, icu))
  cat(sprintf(
    "%-30s TRE %6.3f   PCRE %6.3f   ICU %6.3f   %s\n",
    label,
    timing(grepl(pattern, x)),
    timing(grepl(pattern, x, perl = TRUE)),
    timing(si$stri_detect_regex(x, pattern)),
    "agree"
  ))
}

cat("grepl(), the detection patterns:\n")
trio("ipv6.R#210 (^:|::|:$)", "(^:|::|:$)", dense_v6)
trio("ipv6.R#188 (^:|:$)", "(^:|:$)", dense_v6)
trio("ipv6.R#230 hextet", "^[0-9a-fA-F]{1,4}$", pieces_v6)
trio("ipv4.R#245 ^0[0-9]", "^0[0-9]", pieces_v4)
trio("ipv4.R#118 ^0[0-9]+$", "^0[0-9]+$", pieces_v4)
trio("ipv4.R#112 ^0[xX]", "^0[xX]", pieces_v4)
trio("integer.R#167 ^[0-9]+$", "^[0-9]+$", pieces_v4)

duo_sub <- function(label, pattern, replacement, icu_replacement, x) {
  tre <- sub(pattern, replacement, x)
  pcre <- sub(pattern, replacement, x, perl = TRUE)
  icu <- si$stri_replace_first_regex(x, pattern, icu_replacement)
  stopifnot(identical(tre, pcre), identical(tre, icu))
  cat(sprintf(
    "%-30s TRE %6.3f   PCRE %6.3f   ICU %6.3f   %s\n",
    label,
    timing(sub(pattern, replacement, x)),
    timing(sub(pattern, replacement, x, perl = TRUE)),
    timing(si$stri_replace_first_regex(x, pattern, icu_replacement)),
    "agree"
  ))
}

cat("\nsub(), the rewriting patterns:\n")
duo_sub("ipv6.R#137 ^.*:", "^.*:", "", "", dense_v6)
duo_sub(
  "ipv6.R#239 ^0+(.)", "^0+(.)", "\\1", "$1",
  paste0("000", pieces_v6)
)
duo_sub("ipv4.R#46 ^.*[.]", "^.*\\.", "", "", dotted_v4)

cat("\n== 2. the splits =============================================\n\n")

# The split is the tokenizer proper, and the one place `stringi` offers a
# different *shape* rather than a faster same-shape: `simplify = NA` returns
# the n x 8 character matrix directly, where base R splits to a ragged list and
# then flattens it. A structural advantage would beat a constant factor, so it
# is worth measuring even though the ragged form is what IPv4 needs.
report("base strsplit(), ragged, IPv6", timing(
  strsplit(dense_v6, ":", fixed = TRUE)
))
report("ICU stri_split_fixed(), ragged, IPv6", timing(
  si$stri_split_fixed(dense_v6, ":")
))
report("base unlist(strsplit()), flat, IPv6", timing(
  unlist(strsplit(dense_v6, ":", fixed = TRUE), use.names = FALSE)
))
report("ICU stri_split_fixed(simplify = NA)", timing(
  si$stri_split_fixed(dense_v6, ":", n = 8L, simplify = NA)
))
stopifnot(identical(
  pieces_v6,
  as.vector(t(si$stri_split_fixed(dense_v6, ":", n = 8L, simplify = NA)))
))
cat("\n")
report("base strsplit(), ragged, IPv4", timing(
  strsplit(dotted_v4, ".", fixed = TRUE)
))
report("ICU stri_split_fixed(), ragged, IPv4", timing(
  si$stri_split_fixed(dotted_v4, ".")
))

cat("\n== 3. the rest of the surface ================================\n\n")

report("base nchar()", timing(nchar(pieces_v6)))
report("ICU stri_length()", timing(si$stri_length(pieces_v6)))
gaps <- sample.int(7L, n, replace = TRUE)
report("base strrep()", timing(strrep("0:", gaps)))
report("ICU stri_dup()", timing(si$stri_dup("0:", gaps)))
report("base paste0(), three ways", timing(
  paste0(dense_v6, ":", dense_v6)
))
report("ICU stri_join(), three ways", timing(
  si$stri_join(dense_v6, ":", dense_v6)
))

# The stage with no ICU counterpart at all. `stringi` has no base-N integer
# parser, so whatever else moved, this does not.
cat("\n")
report("base strtoi(base 16) -- no ICU analogue", timing(
  strtoi(pieces_v6, 16L)
))

cat("\n== 4. stringi's own fast path, and a base R answer to it =====\n\n")

# `stri_detect_charclass()` is not a regex engine call -- it is a character-set
# scan, and it is the one thing here `stringi` does that base R has no direct
# spelling for. It is also the only stage in this file where ICU wins, so it is
# the whole case for the dependency and deserves its best shot.
#
# The base R answer is to stop asking a regex for the width. The current
# `^[0-9a-fA-F]{1,4}$` makes one engine answer two questions; splitting it into
# a negated character scan plus `nchar()` gives PCRE a pattern with no anchors,
# no counted repetition and an early exit on the first bad byte.
hextet_pattern <- "^[0-9a-fA-F]{1,4}$"
baseline <- grepl(hextet_pattern, pieces_v6, perl = TRUE)
split_base <- !grepl("[^0-9a-fA-F]", pieces_v6, perl = TRUE) &
  nchar(pieces_v6) <= 4L
split_icu <- !si$stri_detect_charclass(pieces_v6, "[^0-9a-fA-F]") &
  si$stri_length(pieces_v6) <= 4L
stopifnot(identical(baseline, split_base), identical(baseline, split_icu))

report("PCRE, one anchored pattern (today)", timing(
  grepl(hextet_pattern, pieces_v6, perl = TRUE)
))
report("PCRE, negated scan + nchar()", timing(
  !grepl("[^0-9a-fA-F]", pieces_v6, perl = TRUE) & nchar(pieces_v6) <= 4L
))
report("ICU, charclass + stri_length()", timing(
  !si$stri_detect_charclass(pieces_v6, "[^0-9a-fA-F]") &
    si$stri_length(pieces_v6) <= 4L
))

cat("\n== 5. does ICU pay for the encoding it offers? ===============\n\n")

# `stringi` converts to UTF-8 internally, so the suspicion is that it carries a
# conversion base R skips on ASCII. If the two forms cost the same, the gap
# measured above is engine speed and not marshalling, which is the more
# interesting reading -- ICU is not losing on a technicality.
tagged <- pieces_v6
Encoding(tagged) <- "UTF-8"
report("ICU, native encoding", timing(
  si$stri_detect_regex(pieces_v6, hextet_pattern)
))
report("ICU, tagged UTF-8", timing(
  si$stri_detect_regex(tagged, hextet_pattern)
))
report("PCRE, native encoding", timing(
  grepl(hextet_pattern, pieces_v6, perl = TRUE)
))
report("PCRE, tagged UTF-8", timing(
  grepl(hextet_pattern, tagged, perl = TRUE)
))

cat("\n== verdict ===================================================\n\n")
cat(
  "Base R suffices. PCRE is ahead of ICU on every pattern the tokenizer\n",
  "runs, the splits are a wash, and the one stage ICU wins is one base R\n",
  "can restructure. What the file does find is that base R is not being\n",
  "used to its own limit: the TRE call sites above are paying for the\n",
  "default engine, not for the language. See section 11.2.2.\n",
  sep = ""
)
