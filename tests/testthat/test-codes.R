# The reason-code vocabulary. See docs/architecture.md sections 5.2 and 6.4.

# --- The registry ------------------------------------------------------------

test_that("the registry has the documented columns", {
  registry <- addr_codes_registry()
  expect_s3_class(registry, "data.frame")
  expect_named(registry, c("code", "layer", "rfc", "summary", "since"))
  expect_true(nrow(registry) > 0L)
})

test_that("every code is unique, non-empty and snake_case", {
  codes <- addr_codes_registry()$code
  expect_identical(anyDuplicated(codes), 0L)
  expect_true(all(nzchar(codes)))
  expect_true(all(grepl("^[a-z][a-z0-9_]*$", codes)))
})

test_that("every entry carries a layer, a provenance and a version", {
  registry <- addr_codes_registry()
  expect_true(all(registry$layer %in% c("parse", "classify")))
  expect_true(all(nzchar(registry$rfc)))
  expect_true(all(nzchar(registry$summary)))
  expect_true(all(grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", registry$since)))
})

test_that("the valid-value set is derived from the registry, not restated", {
  registry <- addr_codes_registry()
  expect_identical(
    parse_code_levels,
    registry$code[registry$layer == "parse"]
  )
})

# --- The mask that carries codes through the engines -------------------------

test_that("every code has a distinct bit and round-trips through a mask", {
  expect_identical(anyDuplicated(parse_code_bits), 0L)
  expect_identical(
    codes_from_mask(sum(parse_code_bits))[[1L]],
    parse_code_levels
  )
  expect_identical(codes_from_mask(0L)[[1L]], character())
})

test_that("codes_from_mask() is vectorized and order-preserving", {
  mask <- c(0L, code_bit("out_of_range"), 0L, code_bit("empty_part"))
  expect_identical(
    codes_from_mask(mask),
    list(character(), "out_of_range", character(), "empty_part")
  )
})

test_that("first_code() takes the first match and tolerates NA", {
  conditions <- list(
    empty_part = c(TRUE, FALSE, NA),
    not_a_number = c(TRUE, TRUE, FALSE)
  )
  expect_identical(
    first_code(conditions, 3L),
    c(code_bit("empty_part"), code_bit("not_a_number"), 0L)
  )
})

# --- Coverage: no code that nothing can emit (RADD-cwmcjnzy) -----------------
#
# The expected set is derived from the registry rather than written out, so a
# code added without a corpus row that produces it fails the build.

code_corpus <- c(
  "1.2.a.4",           # not_a_number
  "01.2.3.4",          # leading_zero
  ".1.2.3",            # empty_part
  "0x",                # empty_hex        (aton, in the final part)
  "256.1.1.1",         # out_of_range
  "1.2.3",             # wrong_part_count
  "1.2.3.4.",          # trailing_dot
  "fe80::1%lo0",       # zone_not_permitted
  "fe80::1%lo0%en0",   # multiple_zones
  "g::1",              # bad_hextet
  ":1",                # empty_group
  "::1::2",            # bad_elision
  "1:2:3:4:5:6:7",     # wrong_group_count
  "::ffff:1.2.3.999",  # bad_embedded_ipv4
  "1.2.3.4 junk"       # whitespace        (getaddrinfo only)
)

observed_codes <- function(x) {
  p <- addr_parse(x)
  seen <- unlist(
    lapply(raddr_dialects, function(d) unlist(addr_codes(p, d))),
    use.names = FALSE
  )
  sort(unique(seen))
}

test_that("every registered parse code is produced by at least one input", {
  expect_setequal(observed_codes(code_corpus), parse_code_levels)
})

test_that("no code outside the registry ever escapes", {
  expect_true(all(observed_codes(code_corpus) %in% parse_code_levels))
})

# --- Bidirectional docs validation (RADD-srqvttwe) ---------------------------
#
# The design record and the registry must agree in both directions: no
# undocumented code, and no orphan entry left behind by a rename. Skipped in the
# built package, where docs/ is not shipped.

architecture_codes <- function() {
  path <- testthat::test_path("..", "..", "docs", "architecture.md")
  skip_if_not(file.exists(path), "docs/architecture.md is not in the tarball")
  lines <- readLines(path, warn = FALSE)
  rows <- grep("^\\| `[a-z0-9_]+` \\| `(parse|classify)` \\|", lines, value = TRUE)
  skip_if(length(rows) == 0L, "no reason-code table in docs/architecture.md")
  sub("^\\| `([a-z0-9_]+)` .*$", "\\1", rows)
}

test_that("no code is undocumented", {
  expect_true(all(parse_code_levels %in% architecture_codes()))
})

test_that("no documented code is an orphan", {
  expect_true(all(architecture_codes() %in% addr_codes_registry()$code))
})
