# The vendored IANA registries. See docs/architecture.md sections 7 and 5.3.
#
# These tests pin the SHAPE of the vendored snapshot and the invariants any
# lookup built on it depends on. They deliberately do not pin every row: an
# upstream registry update should change counts and dates, and is reviewed as a
# diff by a maintainer running data-raw/build-registry.R. What must never
# change silently is a policy value's type, a carve-out disappearing, or an
# `NA` becoming a `FALSE`.

test_that("the snapshot is 51 blocks, 26 v4 and 25 v6", {
  reg <- addr_registry()

  expect_s3_class(reg, "data.frame")
  expect_equal(nrow(reg), 51L)
  expect_equal(sum(reg$space == "v4"), 26L)
  expect_equal(sum(reg$space == "v6"), 25L)
  expect_setequal(unique(reg$space), c("v4", "v6"))
})

test_that("one row is one prefix, even when upstream packs two into a record", {
  reg <- addr_registry()

  # Upstream writes "192.0.0.170/32, 192.0.0.171/32" as a single record. Left
  # unsplit, neither prefix would ever match.
  expect_true(all(c("192.0.0.170/32", "192.0.0.171/32") %in% reg$block))
  expect_false(any(grepl(",", reg$block, fixed = TRUE)))

  # And no footnote marker survives into the block text.
  expect_false(any(grepl("[", reg$block, fixed = TRUE)))
  expect_true("192.0.0.0/24" %in% reg$block)
  expect_true("2002::/16" %in% reg$block)

  expect_equal(anyDuplicated(reg$block), 0L)
})

test_that("blocks are well formed and re-parse to their stored bits", {
  reg <- addr_registry()
  blocks <- raddr_registry_data$blocks

  expect_true(all(grepl("/", reg$block, fixed = TRUE)))
  width <- ifelse(reg$space == "v4", 32L, 128L)
  expect_true(all(reg$prefix_len >= 0L & reg$prefix_len <= width))

  # The block text and the stored words are two spellings of one fact, so the
  # text must parse back to the words. This is what stops a hand-edited
  # sysdata.rda from disagreeing with the CSV it claims to come from.
  base <- addr_strict(sub("/.*", "", blocks$block))
  expect_false(anyNA(addr_family(base)))
  for (f in c("w1", "w2", "w3", "w4")) {
    expect_identical(vctrs::field(base, f), blocks[[f]])
  }
})

test_that("0x80000000 survives the vendored data", {
  blocks <- raddr_registry_data$blocks
  as112 <- blocks[blocks$block == "2620:4f:8000::/48", ]

  expect_equal(nrow(as112), 1L)
  # Section 5.1.1: the word is the bit pattern R reserves for NA_integer_, and
  # it occurs in a real IANA block. Storing it as that pattern is correct;
  # losing the block, or coercing it to an out-of-range NA, is not.
  expect_true(is.na(as112$w2))

  round_trip <- raddr_address(as112$w1, as112$w2, as112$w3, as112$w4, "v6")
  expect_equal(addr_format(round_trip), "2620:4f:8000::")
})

test_that("all five policy columns are logical and never collapsed", {
  reg <- addr_registry()
  policy <- c(
    "source", "destination", "forwardable", "globally_reachable",
    "reserved_by_protocol"
  )

  for (column in policy) {
    expect_type(reg[[column]], "logical")
  }
})

test_that("IANA's withheld answers stay NA, and are exactly these four", {
  reg <- addr_registry()
  undeclared <- reg$block[is.na(reg$globally_reachable)]

  # Two deprecated blocks with no policy values at all, and the two transition
  # prefixes IANA marks "N/A" because reachability follows the embedded IPv4
  # address. Reading any of them as FALSE would assert a policy IANA withheld.
  expect_setequal(
    undeclared,
    c("192.88.99.0/24", "2001:10::/28", "2001::/32", "2002::/16")
  )

  deprecated <- reg[!is.na(reg$termination_date), ]
  expect_setequal(deprecated$block, c("192.88.99.0/24", "2001:10::/28"))
  expect_true(all(is.na(deprecated$source)))
})

test_that("the carve-outs that force longest-prefix matching are present", {
  reg <- addr_registry()
  get <- function(block) reg$globally_reachable[reg$block == block]

  # Globally reachable /32s inside a /24 that is not. First-match-wins over
  # this table gives the wrong answer for both (section 7).
  expect_false(get("192.0.0.0/24"))
  expect_true(get("192.0.0.9/32"))
  expect_true(get("192.0.0.10/32"))

  containing <- reg$block[
    reg$space == "v4" & reg$prefix_len < 32L &
      startsWith(reg$block, "192.0.0.")
  ]
  expect_true(length(containing) > 0L)
})

test_that("footnote markers are recorded without inventing their text", {
  reg <- addr_registry()

  expect_type(reg$footnotes, "character")
  expect_false(anyNA(reg$footnotes))
  expect_true(all(grepl("^(\\[[0-9]+\\]( \\[[0-9]+\\])*)?$", reg$footnotes)))

  expect_equal(reg$footnotes[reg$block == "127.0.0.0/8"], "[1]")
  expect_equal(reg$footnotes[reg$block == "fc00::/7"], "[4]")
  expect_equal(reg$footnotes[reg$block == "10.0.0.0/8"], "")
})

test_that("the multi-line RFC citations are squished, not truncated", {
  reg <- addr_registry()

  # Three upstream records wrap across lines. A newline must not survive into
  # the data, and neither may half the citation.
  expect_false(any(grepl("\n", reg$rfc, fixed = TRUE)))
  expect_equal(reg$rfc[reg$block == "255.255.255.255/32"],
               "[RFC8190] [RFC919], Section 7")
  expect_equal(reg$rfc[reg$block == "fc00::/7"], "[RFC4193] [RFC8190]")
  expect_true(all(nzchar(reg$rfc)))
})

test_that("the exported table hides the matcher's storage", {
  reg <- addr_registry()

  expect_false(any(c("w1", "w2", "w3", "w4") %in% names(reg)))
  expect_true(all(c("block", "prefix_len", "name", "rfc") %in% names(reg)))
})

test_that("the vendored CSVs ship, and match the recorded provenance", {
  for (key in c("v4", "v6")) {
    meta <- raddr_registry_data$meta[[key]]
    path <- system.file(
      "extdata", basename(meta$path),
      package = "raddr", mustWork = FALSE
    )
    skip_if(identical(path, ""), "installed package has no extdata")

    expect_equal(as.integer(file.size(path)), meta$bytes)
    expect_match(meta$sha256, "^sha256:[0-9a-f]{64}$")
    expect_match(meta$url, "^https://www\\.iana\\.org/")
  }

  expect_equal(raddr_registry_data$meta$license, "CC0 1.0 Universal")
})

test_that("the version stamp is a date, or honestly unknown", {
  version <- addr_registry_version()

  expect_type(version, "character")
  expect_length(version, 1L)
  if (!is.na(version)) {
    expect_match(version, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    expect_false(is.na(as.Date(version)))
    # The snapshot is only as current as its stalest half.
    expect_equal(
      version,
      min(
        raddr_registry_data$meta$v4$last_modified_date,
        raddr_registry_data$meta$v6$last_modified_date
      )
    )
  }
})

test_that("an undated snapshot is reported outdated, never assumed fresh", {
  expect_type(addr_registry_outdated(), "logical")
  expect_length(addr_registry_outdated(), 1L)

  # Any snapshot is older than zero days' tolerance unless it was stamped today.
  expect_true(addr_registry_outdated(max_age = 0))
  expect_false(addr_registry_outdated(max_age = 1e6))

  # The undated case is the one that matters: no evidence must not read as
  # evidence of freshness.
  local_mocked_bindings(addr_registry_version = function() NA_character_)
  expect_true(addr_registry_outdated(max_age = 1e6))
})

test_that("addr_registry_outdated() rejects a nonsense max_age", {
  expect_error(addr_registry_outdated("365"), "max_age")
  expect_error(addr_registry_outdated(c(1, 2)), "max_age")
  expect_error(addr_registry_outdated(NA), "max_age")
  expect_error(addr_registry_outdated(-1), "max_age")
})

test_that("raddr still reaches no network", {
  # Section 7 is a claim about the code, not about a default argument. The
  # vendored registry is the reason it holds, so the absence of a fetch path is
  # part of the data layer's contract.
  expect_false(exists("addr_registry_refresh", asNamespace("raddr")))

  sources <- list.files("../../R", pattern = "[.]R$", full.names = TRUE)
  skip_if(length(sources) == 0L, "package sources not available")
  code <- unlist(lapply(sources, readLines, warn = FALSE))
  code <- grep("^\\s*#", code, value = TRUE, invert = TRUE)
  expect_false(any(grepl(
    "download\\.file|url\\(|curlGetHeaders|httr|curl::", code
  )))
})
