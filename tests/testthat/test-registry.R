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
  for (key in c("v4", "v6", "v4_space", "v6_space")) {
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
        raddr_registry_data$meta$v4$last_updated,
        raddr_registry_data$meta$v6$last_updated
      )
    )
  }
})

test_that("the stamp is IANA's editorial date, not the served header", {
  # The distinction is invisible on this pair -- both registries were genuinely
  # edited on the day their exports were deployed -- so it is pinned on the
  # FIELD the stamp is built from rather than on its value. See the
  # address-space pair below for the case where the two numbers differ.
  for (key in c("v4", "v6", "v4_space", "v6_space")) {
    meta <- raddr_registry_data$meta[[key]]

    expect_match(meta$last_updated, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    # The editorial date comes from the registry page, and the page is named so
    # the claim is auditable rather than merely asserted.
    expect_match(meta$page_url, "^https://www\\.iana\\.org/.*\\.xhtml$")
    # Evidence for it, not just the maintainer's word: these bytes were read.
    expect_identical(meta$last_updated_from, "page")
    expect_match(meta$page_sha256, "^sha256:[0-9a-f]{64}$")

    # The served header is still recorded. It is a fact about the fetch, and
    # deleting it would delete the evidence for why the stamp moved.
    expect_match(meta$last_modified, "GMT$")
  }

  expect_equal(
    addr_registry_version(),
    min(
      raddr_registry_data$meta$v4$last_updated,
      raddr_registry_data$meta$v6$last_updated
    )
  )
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

test_that("the snapshot id is a sha256 over the documented manifest", {
  id <- addr_registry_snapshot()

  expect_type(id, "character")
  expect_length(id, 1L)
  expect_match(id, "^sha256:[0-9a-f]{64}$")

  # The manifest is stored beside the id so the hash is auditable here rather
  # than trusted. Its exact bytes are the definition: one "<key> <sha256>" line
  # per source, LF-terminated, in this fixed order.
  manifest <- raddr_registry_data$meta$snapshot_manifest
  expect_type(manifest, "character")

  keys <- c("v4", "v6", "v4_space", "v6_space")
  expect_equal(
    manifest,
    paste0(
      vapply(
        keys,
        function(k) {
          sprintf("%s %s\n", k, raddr_registry_data$meta[[k]]$sha256)
        },
        character(1)
      ),
      collapse = ""
    )
  )

  # Order is part of the definition, not presentation: a manifest built in a
  # different order would hash differently and identify the same bytes as a
  # different snapshot.
  expect_equal(
    vapply(strsplit(trimws(strsplit(manifest, "\n")[[1]]), " "), `[`, "", 1L),
    keys
  )
})

test_that("the snapshot id follows from its manifest, recomputed", {
  # The claim the accessor makes is that the id IS the hash of the manifest.
  # Recomputed rather than assumed, so a hand-edited R/sysdata.rda fails here
  # and not only in the maintainer-side --check guard.
  skip_if_not_installed("digest")

  expect_equal(
    addr_registry_snapshot(),
    paste0(
      "sha256:",
      digest::digest(
        raddr_registry_data$meta$snapshot_manifest,
        algo = "sha256",
        serialize = FALSE
      )
    )
  )
})

test_that("the snapshot id tracks content, and only content", {
  skip_if_not_installed("digest")

  manifest <- raddr_registry_data$meta$snapshot_manifest
  id_of <- function(x) {
    paste0("sha256:", digest::digest(x, algo = "sha256", serialize = FALSE))
  }

  # A corpus that can disagree: flipping one hex digit of one checksum must
  # move the id. Without this, the equality above would also pass for a
  # constant.
  mutated <- sub("sha256:e", "sha256:f", manifest, fixed = TRUE)
  expect_false(identical(mutated, manifest))
  expect_false(identical(id_of(mutated), addr_registry_snapshot()))

  # Reordering the same four lines is also a different snapshot, which is what
  # makes the fixed order part of the definition rather than a formatting
  # choice.
  lines <- strsplit(manifest, "\n")[[1]]
  reordered <- paste0(paste0(rev(lines), "\n"), collapse = "")
  expect_false(identical(id_of(reordered), addr_registry_snapshot()))
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

# --- the address-space fallback layer ---------------------------------------
#
# These tests pin the one property the whole fallback rests on: each registry
# is an EXACT partition of its space. Everything else about this layer is a
# convenience; that property is what turns "no special-purpose block matched"
# from an absence into an answer.

test_that("the address-space snapshot is 276 rows, 256 v4 and 20 v6", {
  space <- addr_address_space()

  expect_s3_class(space, "data.frame")
  expect_equal(nrow(space), 276L)
  expect_equal(sum(space$space == "v4"), 256L)
  expect_equal(sum(space$space == "v6"), 20L)
  expect_equal(anyDuplicated(space$block), 0L)
  expect_false(any(c("w1", "w2", "w3", "w4") %in% names(space)))
})

test_that("the IPv4 address space is an exact partition into 256 /8s", {
  space <- addr_address_space()
  v4 <- space[space$space == "v4", ]

  expect_true(all(v4$prefix_len == 8L))
  octets <- as.integer(sub("[.].*$", "", v4$block))
  expect_equal(sort(octets), 0:255)

  # Upstream writes "000/8", not CIDR. The leading zeros must be gone: raddr's
  # own strict dialect rejects "000" as an octet, which is the ambiguity behind
  # the inet_aton CVE class.
  expect_false(any(grepl("/8$", v4$block) & grepl("^0[0-9]", v4$block)))
  expect_true("0.0.0.0/8" %in% v4$block)
  expect_true("255.0.0.0/8" %in% v4$block)
})

test_that("the IPv6 address space tiles ::/0 with no gap and no overlap", {
  blocks <- raddr_registry_data$space
  v6 <- blocks[blocks$space == "v6", ]

  expect_equal(nrow(v6), 20L)
  expect_true(all(v6$prefix_len <= 16L))

  # Every row is /10 or shorter, so the tiling is exact in 16-bit space. The
  # widening matters: 8000::/3 stores w1 as R's NA_integer_ bit pattern.
  w1 <- as.numeric(v6$w1)
  w1[is.na(v6$w1)] <- 2147483648
  w1[!is.na(v6$w1) & v6$w1 < 0] <- w1[!is.na(v6$w1) & v6$w1 < 0] + 4294967296
  start <- w1 %/% 65536
  size <- 2^(16L - v6$prefix_len)

  ord <- order(start)
  start <- start[ord]
  size <- size[ord]

  expect_equal(start[1], 0)
  expect_equal(sum(size), 65536)
  expect_equal(start[-1], (start + size)[-length(start)])
})

test_that("0x80000000 appears a second time, and survives", {
  # Section 5.1.1 is load-bearing for the vendored data. It was already true of
  # 2620:4f:8000::/48 in the special-purpose registry; 8000::/3 is a second
  # instance covering an eighth of the IPv6 address space, so a table built on
  # "words are numbers" now loses far more than one AS112 prefix.
  blocks <- raddr_registry_data$space
  row <- blocks[blocks$block == "8000::/3", ]

  expect_equal(nrow(row), 1L)
  expect_true(is.na(row$w1))
  expect_equal(row$w2, 0L)
  expect_equal(row$name, "Reserved by IETF")
})

test_that("multicast exists here and in no special-purpose registry", {
  # This is the CVE-2025-8267 shape: a classifier derived from the
  # special-purpose registries alone has no multicast handling at all.
  reg <- addr_registry()
  space <- addr_address_space()

  expect_false(any(grepl("^224[.]|^ff00::", reg$block)))
  expect_true("ff00::/8" %in% space$block)
  expect_equal(sum(space$name == "Multicast", na.rm = TRUE), 17L)
})

test_that("the address-space layer states identity and invents no policy", {
  space <- addr_address_space()

  # The five policy logicals do not exist upstream here, so they must not exist
  # here either. Absence is the honest answer, not FALSE.
  expect_false(any(
    c(
      "source", "destination", "forwardable", "globally_reachable",
      "reserved_by_protocol"
    ) %in% names(space)
  ))

  v4 <- space[space$space == "v4", ]
  v6 <- space[space$space == "v6", ]

  # IPv4 carries status and date, and has no reference column at all upstream.
  expect_setequal(unique(v4$status), c("ALLOCATED", "LEGACY", "RESERVED"))
  expect_true(all(is.na(v4$rfc)))
  expect_true(all(is.na(v4$notes)))

  # IPv6 carries a reference and prose, and has no status column upstream.
  expect_true(all(is.na(v6$status)))
  expect_true(all(nzchar(v6$rfc)))
  expect_match(
    v6$notes[v6$block == "200::/7"], "Deprecated as of December 2004"
  )
})

test_that("the two layers are stamped separately", {
  # Different files from different registries: one date across both would make
  # each half assert something about a table it says nothing about.
  version <- addr_address_space_version()

  expect_type(version, "character")
  expect_length(version, 1L)
  if (!is.na(version)) {
    expect_match(version, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
    expect_equal(
      version,
      min(
        raddr_registry_data$meta$v4_space$last_updated,
        raddr_registry_data$meta$v6_space$last_updated
      )
    )
  }

  # And the halves genuinely differ here, unlike the special-purpose pair, so
  # the "older of the two" rule is doing real work.
  expect_false(identical(
    raddr_registry_data$meta$v4_space$last_updated,
    raddr_registry_data$meta$v6_space$last_updated
  ))
})

test_that("this pair is the one where editorial and served dates disagree", {
  # The reason the stamp is scraped from IANA's page rather than taken from the
  # HTTP header. On the special-purpose pair the two agree by coincidence; here
  # they do not, so the header approach reported a date IANA does not claim.
  #
  # Pinned on both sources so a future rebuild that silently reverted to the
  # header would fail here rather than ship a plausible wrong number.
  v4 <- raddr_registry_data$meta$v4_space
  v6 <- raddr_registry_data$meta$v6_space

  expect_equal(v4$last_updated, "2025-10-10")
  expect_equal(v4$last_modified_date, "2025-10-09")
  expect_equal(v6$last_updated, "2025-10-23")
  expect_equal(v6$last_modified_date, "2025-10-11")

  # Both halves disagree with their header, in the same direction: IANA edited
  # the registry after the export was deployed.
  expect_gt(v4$last_updated, v4$last_modified_date)
  expect_gt(v6$last_updated, v6$last_modified_date)

  # And the stamp follows the editorial dates, so it is a day later than the
  # header rule produced.
  expect_equal(addr_address_space_version(), "2025-10-10")
})

test_that("special-purpose outranks address space where both match", {
  # IANA states the precedence itself; these five prefixes appear in both pairs
  # identically, and the special-purpose row is the authoritative one.
  reg <- addr_registry()
  space <- addr_address_space()

  both <- intersect(reg$block, space$block)
  expect_setequal(
    both,
    c("0.0.0.0/8", "10.0.0.0/8", "127.0.0.0/8", "fc00::/7", "fe80::/10")
  )
})
