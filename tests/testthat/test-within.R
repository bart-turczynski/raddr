# Containment. See docs/architecture.md section 6.3.
#
# Two things are being tested that the other files do not reach: the prefix
# arithmetic at every length, and the promise that a *block* is validated rather
# than read leniently. The second is the security-relevant half -- a denylist
# entry that silently matches nothing is the failure this function exists to
# avoid -- so the error cases are as thorough as the matching ones.

test_that("an address is inside its own block at every IPv4 length", {
  # The base of the block, the last address in it, and the address one below
  # the base. Walking every length catches an off-by-one in the divisor that a
  # single /24 example would not.
  for (len in 0:32) {
    base <- 3221225984 # 192.0.2.0
    size <- 2^(32 - len)
    masked <- (base %/% size) * size
    block <- paste0(
      addr_format(integer_to_addr(sprintf("%.0f", masked), "v4")), "/", len
    )
    inside <- integer_to_addr(
      sprintf("%.0f", c(masked, masked + size - 1)), "v4"
    )
    expect_true(
      all(addr_within_any(inside, block)),
      info = paste("inside", block)
    )
    if (masked > 0) {
      outside <- integer_to_addr(sprintf("%.0f", masked - 1), "v4")
      expect_false(
        addr_within_any(outside, block),
        info = paste("below", block)
      )
    }
    if (masked + size <= 4294967295) {
      above <- integer_to_addr(sprintf("%.0f", masked + size), "v4")
      expect_false(addr_within_any(above, block), info = paste("above", block))
    }
  }
})

test_that("an address is inside its own block at every IPv6 word boundary", {
  # Masking to `len` and asking whether the original is inside the result must
  # hold for every length, and it exercises the word edges where the plan gains
  # or loses a word. The masking here is byte arithmetic on `addr_to_bytes()`,
  # which shares nothing with the divisor arithmetic under test.
  mask_addr <- function(a, len) {
    o <- as.integer(addr_to_bytes(a)[[1L]])
    width <- length(o)
    keep <- len %/% 8L
    rem <- len %% 8L
    if (keep < width) {
      o[[keep + 1L]] <- if (rem == 0L) {
        0L
      } else {
        (o[[keep + 1L]] %/% 2^(8L - rem)) * 2^(8L - rem)
      }
      if (keep + 2L <= width) {
        o[(keep + 2L):width] <- 0L
      }
    }
    bytes_to_addr(list(as.raw(o)))
  }

  a <- addr_pton("2001:db8:dead:beef:1234:5678:9abc:def0")
  for (len in c(0:2, 31:33, 63:65, 95:97, 126:128)) {
    block <- paste0(addr_format(mask_addr(a, len)), "/", len)
    expect_true(addr_within_any(a, block), info = block)
    # One bit past the prefix is a different block at the same length.
    if (len > 0L) {
      other <- mask_addr(addr_pton("f000::"), len)
      if (other != mask_addr(a, len)) {
        expect_false(
          addr_within_any(a, paste0(addr_format(other), "/", len)),
          info = block
        )
      }
    }
  }
  expect_true(addr_within_any(addr_pton("2001:db8::1"), "2001:db8::/32"))
  expect_true(addr_within_any(
    addr_pton("2001:db8:ffff:ffff:ffff:ffff:ffff:ffff"), "2001:db8::/32"
  ))
  expect_false(addr_within_any(addr_pton("2001:db9::"), "2001:db8::/32"))
  expect_false(addr_within_any(addr_pton("2001:db7:ffff::"), "2001:db8::/32"))
})

test_that("the 0x80000000 word is matched, not read as missing", {
  # The reason this file and R/classify.R contain no bitwAnd. Section 5.1.1
  # stores a word as a raw bit pattern in which NA_integer_ *is* 0x80000000, so
  # a bitwise matcher never matches 2620:4f:8000::/48 -- the AS112
  # direct-delegation prefix, whose second word is exactly that pattern.
  expect_true(addr_within_any(addr_pton("2620:4f:8000::"), "2620:4f:8000::/48"))
  expect_true(
    addr_within_any(addr_pton("2620:4f:8000::1"), "2620:4f:8000::/48")
  )
  expect_false(
    addr_within_any(addr_pton("2620:4f:8001::"), "2620:4f:8000::/48")
  )
  # And a /1, whose mask a bitwise NOT cannot even spell.
  expect_true(addr_within_any(addr_pton("8000::"), "8000::/1"))
  expect_false(addr_within_any(addr_pton("7fff::"), "8000::/1"))
  expect_true(addr_within_any(addr_pton("128.0.0.0"), "128.0.0.0/1"))
  expect_false(addr_within_any(addr_pton("127.255.255.255"), "128.0.0.0/1"))
})

test_that("a zero-length prefix covers its own space and no other", {
  a <- addr_pton(c("0.0.0.0", "255.255.255.255", "::", "::1", "2001:db8::"))
  expect_identical(
    addr_within_any(a, "0.0.0.0/0"),
    c(TRUE, TRUE, FALSE, FALSE, FALSE)
  )
  expect_identical(
    addr_within_any(a, "::/0"),
    c(FALSE, FALSE, TRUE, TRUE, TRUE)
  )
})

test_that("a host route matches exactly one address", {
  a <- addr_pton(c("192.0.2.0", "192.0.2.1", "192.0.2.2"))
  expect_identical(addr_within_any(a, "192.0.2.1/32"), c(FALSE, TRUE, FALSE))
  b <- addr_pton(c("2001:db8::", "2001:db8::1", "2001:db8::2"))
  expect_identical(addr_within_any(b, "2001:db8::1/128"), c(FALSE, TRUE, FALSE))
})

test_that("the family decides the space and a mismatch is FALSE", {
  # Not an error: a denylist holding both families is an ordinary thing.
  expect_false(addr_within_any(addr_pton("10.0.0.1"), "2001:db8::/32"))
  expect_false(addr_within_any(addr_pton("2001:db8::1"), "10.0.0.0/8"))
  expect_identical(
    addr_within_any(
      addr_pton(c("10.0.0.1", "2001:db8::1")),
      c("10.0.0.0/8", "2001:db8::/32")
    ),
    c(TRUE, TRUE)
  )
})

test_that("a 4-in-6 address searches the IPv6 space", {
  # Section 6.5.1's width rule in its containment form: `::ffff:10.0.0.1` is a
  # 128-bit address that embeds an IPv4 one, and the embedding is a separate
  # fact reported by addr_embeddings(). Answering TRUE for 10.0.0.0/8 would
  # collapse the two facts raddr exists to keep apart.
  a <- addr_pton("::ffff:10.0.0.1")
  expect_identical(as.character(addr_family(a)), "v6_4in6")
  expect_false(addr_within_any(a, "10.0.0.0/8"))
  expect_true(addr_within_any(a, "::ffff:0:0/96"))
  expect_true(addr_within_any(a, "::/0"))
  expect_false(addr_within_any(a, "0.0.0.0/0"))
})

test_that("a missing address is a missing answer, never FALSE", {
  a <- addr_pton(c("10.0.0.1", "not an address", "10.0.0.2"))
  expect_identical(addr_within_any(a, "10.0.0.0/8"), c(TRUE, NA, TRUE))
  expect_identical(addr_within(a, "10.0.0.0/8"), c(TRUE, NA, TRUE))
  # Including when nothing in the list could have matched anyway.
  expect_identical(addr_within_any(a, "2001:db8::/32"), c(FALSE, NA, FALSE))
})

test_that("within_any is order-independent and duplicate-tolerant", {
  a <- addr_pton(c("10.1.2.3", "192.0.2.1", "8.8.8.8"))
  blocks <- c("192.0.2.0/24", "10.0.0.0/8", "0.0.0.0/8")
  expect_identical(
    addr_within_any(a, blocks),
    addr_within_any(a, rev(blocks))
  )
  expect_identical(
    addr_within_any(a, blocks),
    addr_within_any(a, c(blocks, blocks))
  )
})

test_that("within recycles a block against many addresses and back", {
  a <- addr_pton(c("10.0.0.1", "192.0.2.1", "172.16.0.1"))
  expect_identical(addr_within(a, "10.0.0.0/8"), c(TRUE, FALSE, FALSE))
  expect_identical(
    addr_within(a, c("10.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12")),
    c(TRUE, FALSE, TRUE)
  )
  # One address against many blocks recycles the other way.
  expect_identical(
    addr_within(addr_pton("10.0.0.1"), c("10.0.0.0/8", "192.0.2.0/24")),
    c(TRUE, FALSE)
  )
  expect_error(
    addr_within(a, c("10.0.0.0/8", "192.0.2.0/24")),
    class = "vctrs_error_incompatible_size"
  )
})

test_that("the empty vector is answered on both sides", {
  expect_identical(
    addr_within_any(addr_pton(character()), "10.0.0.0/8"),
    logical()
  )
  expect_identical(addr_within(addr_pton(character()), character()), logical())
  # No blocks contain nothing, which is FALSE rather than an error.
  expect_identical(addr_within_any(addr_pton("10.0.0.1"), character()), FALSE)
})

# --- a block is the question, so a bad block is loud -------------------------

test_that("a block without a prefix length is refused", {
  a <- addr_pton("10.0.0.1")
  expect_error(addr_within_any(a, "10.0.0.0"), class = "raddr_error_block")
  expect_error(addr_within_any(a, "2001:db8::"), class = "raddr_error_block")
  # The message names the fix, because a host route is what was probably meant.
  expect_error(addr_within_any(a, "10.0.0.0"), regexp = "/32")
})

test_that("a block with host bits set is refused rather than masked", {
  # Equally likely to be a typo for the network or a host that wanted /32, and
  # guessing is the silent reinterpretation section 6.5.2 refuses elsewhere.
  a <- addr_pton("192.168.1.5")
  expect_error(
    addr_within_any(a, "192.168.1.1/24"),
    class = "raddr_error_block"
  )
  expect_error(
    addr_within_any(a, "2001:db8::1/32"),
    class = "raddr_error_block"
  )
  # The masked form the caller probably meant is named in the message.
  expect_error(
    addr_within_any(a, "192.168.1.1/24"),
    regexp = "192\\.168\\.1\\.0/24"
  )
  # The masked form is accepted, and so is a host route on the same address.
  expect_true(addr_within_any(a, "192.168.1.0/24"))
  expect_true(addr_within_any(addr_pton("192.168.1.1"), "192.168.1.1/32"))
})

test_that("a prefix length outside its space is refused", {
  a <- addr_pton("10.0.0.1")
  for (bad in c("10.0.0.0/33", "10.0.0.0/-1", "10.0.0.0/", "10.0.0.0/x",
                "10.0.0.0/8.5", "10.0.0.0/08a", "2001:db8::/129")) {
    expect_error(
      addr_within_any(a, bad),
      class = "raddr_error_block", info = bad
    )
  }
  # 32 and 128 are the last legal ones, not the first illegal ones.
  expect_false(addr_within_any(a, "10.0.0.0/32"))
  expect_true(addr_within_any(addr_pton("2001:db8::"), "2001:db8::/128"))
})

test_that("blocks are read by the RFC grammar, not by a platform's pton", {
  # `addr_pton()` models Apple libc, which strips leading zeros, so it reads
  # "010.0.0.0" as 10.0.0.0 where glibc rejects the same text. A block that
  # means different things on different machines is refused instead.
  a <- addr_pton("10.0.0.1")
  expect_error(addr_within_any(a, "010.0.0.0/8"), class = "raddr_error_block")
  expect_error(addr_within_any(a, "0x0a.0.0.0/8"), class = "raddr_error_block")
  expect_error(addr_within_any(a, "10.0.0/8"), class = "raddr_error_block")
  expect_error(
    addr_within_any(a, "not an address/8"),
    class = "raddr_error_block"
  )
  expect_true(addr_within_any(a, "10.0.0.0/8"))
})

test_that("a missing or wrongly typed block is refused", {
  a <- addr_pton("10.0.0.1")
  expect_error(addr_within_any(a, NA_character_), class = "raddr_error_block")
  expect_error(
    addr_within_any(a, c("10.0.0.0/8", NA)),
    class = "raddr_error_block"
  )
  expect_error(addr_within_any(a, 10), class = "raddr_error_type")
  expect_error(
    addr_within_any(a, list("10.0.0.0/8")),
    class = "raddr_error_type"
  )
  # A factor is read, matching integer_to_addr()'s treatment of one.
  expect_true(addr_within_any(a, factor("10.0.0.0/8")))
})

test_that("the address argument is checked like every other one", {
  expect_error(
    addr_within_any("10.0.0.1", "10.0.0.0/8"),
    class = "raddr_error_type"
  )
  expect_error(
    addr_within("10.0.0.1", "10.0.0.0/8"),
    class = "raddr_error_type"
  )
})

test_that("surrounding whitespace in a block is trimmed", {
  # Denylists arrive from files, one block per line.
  a <- addr_pton("10.0.0.1")
  expect_true(addr_within_any(a, " 10.0.0.0/8 "))
  expect_true(addr_within_any(a, "\t10.0.0.0/8\n"))
})
