# The reason-code vocabulary. See docs/architecture.md sections 5.2 and 6.4.

# --- The registry ------------------------------------------------------------

test_that("the registry has the documented columns", {
  registry <- addr_codes_registry()
  expect_s3_class(registry, "data.frame")
  expect_named(
    registry,
    c("code", "layer", "rfc", "summary", "strength", "since")
  )
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
  expect_identical(
    classify_code_levels,
    registry$code[registry$layer == "classify"]
  )
})

# --- The strength scale (RADD-wglsdrmu) --------------------------------------

test_that("every strength is from the scale", {
  strength <- addr_codes_registry()$strength
  expect_true(all(is.na(strength) | strength %in% raddr_code_strengths))
  expect_identical(raddr_code_strengths, c("must", "should", "may",
                                           "unspecified"))
})

test_that("a parse code is never graded and a classify code always is", {
  registry <- addr_codes_registry()
  expect_true(all(is.na(registry$strength[registry$layer == "parse"])))
  expect_true(all(!is.na(registry$strength[registry$layer == "classify"])))
})

# The grading is a claim about the RFCs, so it is pinned rather than left to
# drift. RFC 4291 and RFC 8215 invoke RFC 2119 nowhere -- verified 2026-07-27
# against the RFC texts -- so their two `must`-substance rules are graded on the
# format definition, not on a keyword, and `nat64_local_layout_unspecified` is
# `unspecified` twice over.
test_that("each classify code carries the strength its RFC actually states", {
  registry <- addr_codes_registry()
  strength <- stats::setNames(registry$strength, registry$code)
  expect_identical(
    strength[classify_code_levels],
    c(
      nat64_wk_embedded_not_global = "must",
      sixtofour_embedded_not_global = "must",
      teredo_client_not_global = "must",
      nat64_u_byte_nonzero = "must",
      link_local_outside_fe80_64 = "must",
      link_local_reserved_range = "must",
      ipv4_compatible_low_tail = "may",
      nat64_local_layout_unspecified = "unspecified",
      ula_l_bit_unset = "unspecified"
    )
  )
})

test_that("the classify layer reports strongest first", {
  registry <- addr_codes_registry()
  strength <- registry$strength[registry$layer == "classify"]
  expect_false(is.unsorted(match(strength, raddr_code_strengths)))
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

test_that("the classify vocabulary has its own distinct bits", {
  expect_identical(anyDuplicated(classify_code_bits), 0L)
  expect_identical(
    codes_from_mask(
      sum(classify_code_bits), classify_code_levels, classify_code_bits
    )[[1L]],
    classify_code_levels
  )
})

test_that("add_classify_code() accumulates rather than replacing", {
  mask <- integer(3L)
  mask <- add_classify_code(mask, "ula_l_bit_unset", c(TRUE, TRUE, FALSE))
  mask <- add_classify_code(
    mask, "link_local_reserved_range", c(TRUE, FALSE, NA)
  )
  expect_identical(
    codes_from_mask(mask, classify_code_levels, classify_code_bits),
    list(
      c("link_local_reserved_range", "ula_l_bit_unset"),
      "ula_l_bit_unset",
      character()
    )
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

# --- Coverage: the classify layer, and the gap that has now closed -----------
#
# Same discipline, and it is now unconditional. Three of the eight codes were
# registered ahead of the extractor and could not be emitted at all, which this
# file carried as a written-out pending list so the gap stayed a recorded fact
# rather than a silently thinner corpus. Epic J closed it: every classify code
# has an input below, and the pending list is gone rather than emptied.

classify_corpus <- c(
  "64:ff9b::a9fe:a9fe",                   # nat64_wk_embedded_not_global
  "2002:a00:1::",                         # sixtofour_embedded_not_global
  "2001:0:4136:e378:8000:63bf:f5ff:fffe", # teredo_client_not_global
  "64:ff9b:1:c000:ff02:2100::",           # nat64_u_byte_nonzero
  "febf::1",                              # link_local_outside_fe80_64
  "169.254.255.5",                        # link_local_reserved_range
  "::2",                                  # ipv4_compatible_low_tail
  "64:ff9b:1::c000:201",                  # nat64_local_layout_unspecified
  "fc00::1"                               # ula_l_bit_unset
)

observed_classify_codes <- function(x) {
  codes <- field(addr_classify(addr_pton(x)), "codes")
  sort(unique(unlist(codes, use.names = FALSE)))
}

test_that("every classify code is produced by at least one input", {
  expect_setequal(
    observed_classify_codes(classify_corpus), classify_code_levels
  )
})

test_that("the corpus names one input per code, and they are distinct", {
  # One literal per code, in the registry's order, so a code added without a
  # corpus entry fails here rather than thinning the coverage check above.
  expect_length(classify_corpus, length(classify_code_levels))
  for (i in seq_along(classify_corpus)) {
    expect_true(
      classify_code_levels[[i]] %in%
        observed_classify_codes(classify_corpus[[i]]),
      info = classify_corpus[[i]]
    )
  }
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
  pattern <- "^\\| `[a-z0-9_]+` \\| `(parse|classify)` \\|"
  rows <- grep(pattern, lines, value = TRUE)
  skip_if(length(rows) == 0L, "no reason-code table in docs/architecture.md")
  sub("^\\| `([a-z0-9_]+)` .*$", "\\1", rows)
}

test_that("no code is undocumented", {
  expect_true(all(addr_codes_registry()$code %in% architecture_codes()))
})

test_that("no documented code is an orphan", {
  expect_true(all(architecture_codes() %in% addr_codes_registry()$code))
})
