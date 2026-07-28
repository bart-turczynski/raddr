# Boundary-driven registry tests (RADD-rbmtrpmw). See docs/architecture.md
# section 11.5.
#
# Every block of every table the matcher knows gets six probe addresses: the two
# ends the block contains, the two immediately outside them, one drawn from a
# proper subnet and one drawn from the other half of its supernet. 340 blocks,
# 2040 addresses, and the half that matters is the half no block contains.
#
# What this file is not is another totality test. test-invariants.R already says
# every address matches exactly one registry row and that the address-space
# layer partitions each family's space -- both of which stay true of a block
# that is one address too wide. An edge is where that stops being true.
#
# The probes are built in binary from each block's *text* (`block_probes()` in
# helper-slow.R) rather than from its stored words, because `block_edges()`
# derives an edge with the same divisor `mask_words()` uses to decide
# containment: a wrong step there moves the edge and the block together and both
# sides agree about the wrong block. Section 11.5 has the argument in full.

boundary_tables <- list(
  # `prefix_table()` hands back the parsed form, and for the two hand-written
  # tables that form carries no `block` column at all -- so the text comes from
  # the sources those tables are built from. The text is the point: it is the
  # block's second description, and the one the words can be checked against.
  special = raddr_registry_data$blocks$block,
  space = raddr_registry_data$space$block,
  transition = raddr_transition_prefixes$block,
  codes = classify_code_blocks$block
)

boundary_probes <- lapply(boundary_tables, block_probes)

missing_addr <- function(x) is.na(field(x, "family"))

over_tables <- function(f) {
  Map(f, names(boundary_tables), boundary_tables, boundary_probes)
}

# A failure over 340 blocks has to say *which* block, or the message is "one of
# them". So every sweep below collects the offending blocks and compares the
# collection against nothing.
no_blocks <- lapply(boundary_tables, function(blocks) character())

# --- the edges themselves (section 11.5) -------------------------------------

test_that("block_edges() agrees with the block text read as bits", {
  # `block_edges()` is what test-classify.R's 340-block agreement test stands
  # on, and it shares its divisor with `mask_words()`. Reading the same two
  # addresses off the block text costs one comparison and takes that shared step
  # out from underneath every assertion in this file and that one.
  bad <- over_tables(function(which, blocks, p) {
    n <- length(blocks)
    edges <- block_edges(prefix_table(which))
    blocks[
      !vec_equal(edges[seq_len(n)], p$start, na_equal = TRUE) |
        !vec_equal(edges[n + seq_len(n)], p$end, na_equal = TRUE)
    ]
  })

  expect_identical(bad, no_blocks)
})

test_that("a block contains both its edges and neither of its neighbours", {
  # Two descriptions of one block -- four words and a length, against the text
  # `addr_within()` re-parses -- so a disagreement is either a wrong divisor or
  # a row whose text and words are not the same block.
  #
  # The neighbours are the half of this that is new. An edge lying inside its
  # own block is equally true of a block one address too wide; the address one
  # past that edge lying *outside* it is not.
  bad <- over_tables(function(which, blocks, p) {
    # A missing address is a missing answer and never FALSE (section 6.3.1), so
    # the blocks at the ends of the two spaces are asserted as `NA` here rather
    # than excused from the test.
    outside <- function(x) ifelse(missing_addr(x), NA, FALSE)
    blocks[
      !addr_within(p$start, blocks) |
        !addr_within(p$end, blocks) |
        !vec_equal(addr_within(p$below, blocks), outside(p$below),
                   na_equal = TRUE) |
        !vec_equal(addr_within(p$above, blocks), outside(p$above),
                   na_equal = TRUE)
    ]
  })

  expect_identical(bad, no_blocks)
})

test_that("only the ends of a space have no neighbour", {
  # Pinning these is what stops a wrap-around from reading as a pass. If
  # `slow_bits_step()` carried round instead of answering `NA`, these lists
  # would be empty, every neighbour assertion above would still pass, and it
  # would be passing about the wrong four addresses.
  ends <- over_tables(function(which, blocks, p) {
    list(
      below = blocks[missing_addr(p$below)],
      above = blocks[missing_addr(p$above)]
    )
  })

  expect_identical(ends$special, list(
    below = c("0.0.0.0/8", "0.0.0.0/32", "::/128"),
    above = c("240.0.0.0/4", "255.255.255.255/32")
  ))
  expect_identical(ends$space, list(
    below = c("0.0.0.0/8", "::/8"),
    above = c("255.0.0.0/8", "ff00::/8")
  ))
  expect_identical(ends$transition, list(
    below = "::/96",
    above = character()
  ))
  expect_identical(ends$codes, list(below = character(), above = character()))
})

# --- what the matcher answers at an edge (sections 5.3 and 7.4) --------------

test_that("the longest match at an edge is the block or one nested inside it", {
  # Longest-prefix-match's contract stated per block rather than in aggregate.
  # An edge of a block is in that block, so whatever the matcher answers has to
  # contain the edge and be at least as long -- and two blocks that both contain
  # one address are nested, so "at least as long" makes the answer a block
  # inside this one. Checked as containment between the two block texts, not by
  # comparing prefix lengths a second time.
  bad <- over_tables(function(which, blocks, p) {
    table <- prefix_table(which)
    astray <- function(x) {
      row <- prefix_match(x, which)
      out <- rep(TRUE, length(row))
      hit <- !is.na(row)
      found <- blocks[row[hit]]
      out[hit] <- table$prefix_len[row[hit]] < p$len[hit] |
        !addr_within(addr_strict(sub("/.*$", "", found)), blocks[hit])
      out
    }
    blocks[astray(p$start) | astray(p$end)]
  })

  expect_identical(bad, no_blocks)
})

test_that("no neighbour or sibling resolves to the block it sits beside", {
  # The off-by-one detector. Every one of these addresses matches *something* in
  # a table that covers its space, which is what makes a slip in the prefix
  # arithmetic silent -- the answer stays well formed and names a block one
  # address away. The question that is not silent is whether the block named is
  # the one the address is next to rather than inside.
  bad <- over_tables(function(which, blocks, p) {
    beside <- function(x) {
      row <- prefix_match(x, which)
      !is.na(row) & row == seq_along(blocks)
    }
    blocks[beside(p$below) | beside(p$above) | beside(p$sibling)]
  })

  expect_identical(bad, no_blocks)
})

test_that("a neighbour may still be in the registry, because blocks abut", {
  # The escape hatch. "The address past the end of a block is outside the
  # registry" is the natural expectation and it is false for 20 of the 51
  # special-purpose blocks, ten of which are followed *immediately* by another
  # block: `192.0.0.8/32` begins exactly where `192.0.0.0/29` ends.
  #
  # So contiguity is computed from the table instead of hard-coded as a list of
  # exceptions, and the pairs are pinned, because which blocks abut is a fact
  # about the vendored snapshot and not about the code reading it.
  abutting <- over_tables(function(which, blocks, p) {
    next_block <- vapply(seq_along(blocks), function(i) {
      if (missing_addr(p$above)[[i]]) {
        return(NA_character_)
      }
      at <- which(vec_equal(p$start, p$above[i], na_equal = TRUE))
      if (length(at)) blocks[[at[[1L]]]] else NA_character_
    }, character(1))
    found <- !is.na(next_block)
    stats::setNames(next_block[found], blocks[found])
  })

  expect_identical(abutting$special, c(
    "192.0.0.0/29" = "192.0.0.8/32",
    "192.0.0.8/32" = "192.0.0.9/32",
    "192.0.0.9/32" = "192.0.0.10/32",
    "192.0.0.170/32" = "192.0.0.171/32",
    "::/128" = "::1/128",
    "100::/64" = "100:0:0:1::/64",
    "2001:1::1/128" = "2001:1::2/128",
    "2001:1::2/128" = "2001:1::3/128",
    "2001:10::/28" = "2001:20::/28",
    "2001:20::/28" = "2001:30::/28"
  ))

  # The overlay and the classify blocks are islands: nothing there touches
  # anything else, so for those two the naive expectation happens to hold.
  no_pairs <- stats::setNames(character(), character())
  expect_identical(abutting$transition, no_pairs)
  expect_identical(abutting$codes, no_pairs)

  # And the address-space pair is a partition, so it is the opposite case
  # entirely: every block that has a successor at all is followed immediately by
  # another one. Gaplessness, read off the boundary rather than off the tiling
  # arithmetic test-registry.R does it with.
  space <- boundary_probes$space
  expect_length(abutting$space, sum(!missing_addr(space$above)))
  expect_identical(
    unname(abutting$space),
    boundary_tables$space[c(2:256, 258:276)]
  )
})

# --- the subnet and the supernet (section 11.5) ------------------------------

test_that("a proper subnet is inside the block and does not contain it", {
  # The block's upper half. Its first address is inside the block, so a block
  # that lost its top half fails here; and the block's *own* first address is
  # outside the half, so a subnet that quietly widened back to its parent fails
  # too. A host route has no subnet and drops out by having none, rather than by
  # being named as an exception.
  bad <- over_tables(function(which, blocks, p) {
    has <- !missing_addr(p$middle)
    wrong <- rep(FALSE, length(blocks))
    wrong[has] <-
      !addr_within(p$middle[has], blocks[has]) |
      !addr_within(p$middle[has], p$subnet[has]) |
      !addr_within(p$end[has], p$subnet[has]) |
      addr_within(p$start[has], p$subnet[has])
    blocks[wrong]
  })

  expect_identical(bad, no_blocks)

  # The blocks with no subnet are exactly the host routes, which is the same
  # statement as "a /32 and a /128 hold one address" made over the tables.
  hosts <- over_tables(function(which, blocks, p) {
    identical(missing_addr(p$middle), p$len == p$width)
  })
  expect_true(all(unlist(hosts)))
})

test_that("a supernet holds the block and its sibling, and only one of them", {
  # The other half of the block one bit shorter. Both halves are inside it and
  # the sibling is outside the block, which is the difference a prefix length
  # off by one cannot see: widen a block by a bit and it swallows its sibling
  # while every address it already held stays held.
  expect_false(any(vapply(
    boundary_probes, function(p) anyNA(p$supernet), logical(1)
  )))

  bad <- over_tables(function(which, blocks, p) {
    blocks[
      !addr_within(p$start, p$supernet) |
        !addr_within(p$end, p$supernet) |
        !addr_within(p$sibling, p$supernet) |
        addr_within(p$sibling, blocks)
    ]
  })

  expect_identical(bad, no_blocks)
})

# --- the two independent matchers, over the new addresses --------------------

test_that("the matcher agrees with a string matcher at every probe", {
  # test-classify.R runs this over the 680 block ends. These are the 1360
  # addresses beside and within them, where the expected answer is not "the
  # block you started from" and a shared mistake has somewhere left to hide.
  agreed <- over_tables(function(which, blocks, p) {
    probes <- vctrs::vec_c(p$below, p$above, p$middle, p$sibling)
    list(
      fast = prefix_match(probes, which),
      slow = slow_prefix_match(probes, prefix_table(which))
    )
  })

  expect_identical(
    lapply(agreed, `[[`, "fast"),
    lapply(agreed, `[[`, "slow")
  )
})

test_that("addr_within_any() answers the weaker question at every probe", {
  # The denylist surface. `addr_within_any()` groups blocks by length and asks
  # a hash whether anything matched; `slow_prefix_match()` walks bit strings and
  # answers which row. Over the same 2040 boundary addresses the two have to
  # agree about whether there was a row at all -- including at the four that do
  # not exist, where the answer is `NA` and not `FALSE`.
  answers <- over_tables(function(which, blocks, p) {
    probes <- vctrs::vec_c(
      p$start, p$end, p$below, p$above, p$middle, p$sibling
    )
    row <- slow_prefix_match(probes, prefix_table(which))
    list(
      any = addr_within_any(probes, blocks),
      matched = ifelse(missing_addr(probes), NA, !is.na(row))
    )
  })

  expect_identical(
    lapply(answers, `[[`, "any"),
    lapply(answers, `[[`, "matched")
  )
})

# --- the record a caller actually reads (sections 5.3 and 7.4) ---------------

test_that("the special-purpose record never leaks across a block boundary", {
  # Section 7.4's argument, taken off its five hand-picked addresses and run
  # over all 51 blocks. `192.0.0.0/29` is `.0` through `.7` and `.8`, `.9`,
  # `.10`, `.170` and `.171` each carry their own policy, so an off-by-one in
  # the prefix arithmetic swaps five protocols' semantics -- and every one of
  # those addresses still classifies to something well formed, which is what
  # makes it silent. Asking whether the block *named* is the right one is not.
  blocks <- boundary_tables$special
  p <- boundary_probes$special

  for (edge in list(p$start, p$end)) {
    cl <- addr_classify(edge)
    # An edge of a special-purpose block is in a special-purpose block, so the
    # address-space row underneath it never answers (section 7.3's precedence).
    expect_identical(
      as.character(field(cl, "registry")),
      rep("special_purpose", length(blocks))
    )
    named <- field(cl, "block")
    expect_true(
      all(addr_within(addr_strict(sub("/.*$", "", named)), blocks))
    )
  }

  # Outside, the claim is *not* "no block matches" -- 20 of the 51 neighbours
  # are still in the special-purpose registry, and the sibling of a nested block
  # is usually its parent. The claim is that the block named is never this one.
  leaked <- lapply(
    stats::setNames(nm = c("below", "above", "sibling")),
    function(nm) {
      x <- p[[nm]]
      here <- !missing_addr(x)
      named <- field(addr_classify(x[here]), "block")
      blocks[here][named == blocks[here]]
    }
  )

  expect_identical(leaked, list(
    below = character(), above = character(), sibling = character()
  ))
})
