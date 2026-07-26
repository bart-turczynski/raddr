# Tests for the raddr_address type. See docs/architecture.md sections 5.1,
# 5.1.1 and 5.1.2.

# Turn an unsigned 32-bit value into the signed pattern the words store. The
# tests deliberately go through this rather than through the constructor's
# integers, so that the literal in each test reads as an address.
signed_word <- function(u) {
  if (u >= 2^31) {
    u <- u - 2^32
  }
  if (u == -2^31) NA_integer_ else as.integer(u)
}

v4 <- function(a, b, c, d, zone = NA_character_) {
  word <- signed_word(a * 2^24 + b * 2^16 + c * 256 + d)
  raddr_address(0L, 0L, 0L, word, "v4", zone)
}

test_that("the constructor keeps its fields", {
  a <- raddr_address(0L, 0L, 0L, 2130706433L, "v4")

  expect_true(is_raddr_address(a))
  expect_equal(vctrs::vec_size(a), 1L)
  expect_equal(as.character(addr_family(a)), "v4")
  expect_true(is.na(addr_zone(a)))
})

test_that("the constructor recycles and validates", {
  a <- raddr_address(0L, 0L, 0L, c(1L, 2L, 3L), "v4")
  expect_equal(vctrs::vec_size(a), 3L)

  expect_error(
    raddr_address(0L, 0L, 0L, 1L, "v5"),
    class = "raddr_error_family"
  )
})

test_that("accessors reject anything that is not an address", {
  expect_error(addr_family("127.0.0.1"), class = "raddr_error_type")
  expect_error(addr_zone(1L), class = "raddr_error_type")
})

# --- Section 5.1.1: the 0x80000000 regression --------------------------------
#
# R reserves the bit pattern 0x80000000 as NA_integer_. If the comparison proxy
# is not widened, every address with that pattern in a word stops comparing
# equal to itself -- and it fails to NA rather than FALSE, so `if (addr ==
# blocked)` is skipped rather than taken. ipaddress 1.0.3 ships exactly this.
#
# raddr stores words big-endian, so the IPv4 address that carries the pattern is
# 128.0.0.0, not the 0.0.0.128 that triggers it in a little-endian layout.
# Anyone who "simplifies" widen_word() or addr_proxy() away must see this go
# red.

test_that("128.0.0.0 equals itself (the 0x80000000 IPv4 address)", {
  a <- raddr_address(0L, 0L, 0L, NA_integer_, "v4")
  b <- raddr_address(0L, 0L, 0L, NA_integer_, "v4")

  expect_identical(a == b, TRUE)
  expect_false(is.na(a == b))
  expect_identical(vctrs::vec_compare(a, b), 0L)
})

test_that("the 0x80000000 pattern equals itself in every IPv6 word", {
  for (position in 1:4) {
    words <- list(0L, 0L, 0L, 0L)
    words[[position]] <- NA_integer_

    a <- raddr_address(words[[1]], words[[2]], words[[3]], words[[4]], "v6")
    b <- raddr_address(words[[1]], words[[2]], words[[3]], words[[4]], "v6")

    expect_identical(a == b, TRUE)
    expect_identical(vctrs::vec_compare(a, b), 0L)
  }
})

test_that("a word reading NA_integer_ is a pattern, not a missing address", {
  a <- raddr_address(0L, 0L, 0L, NA_integer_, "v4")

  expect_false(is.na(a))
  expect_false(is.na(addr_family(a)))
})

test_that("missingness lives in family and nowhere else", {
  missing <- raddr_address(0L, 0L, 0L, 1L, NA_character_)

  expect_true(is.na(missing))
  expect_true(is.na(missing == missing))
  expect_true(is.na(format(missing)))
})

test_that("0x80000000 sorts where its unsigned value belongs", {
  # 127.255.255.255 < 128.0.0.0 < 128.0.0.1: the pattern is 2^31 unsigned, so it
  # must not sort as the most negative signed integer.
  below <- v4(127, 255, 255, 255)
  pattern <- raddr_address(0L, 0L, 0L, NA_integer_, "v4")
  above <- v4(128, 0, 0, 1)

  expect_identical(vctrs::vec_compare(below, pattern), -1L)
  expect_identical(vctrs::vec_compare(pattern, above), -1L)
})

test_that("the whole unsigned 32-bit range round-trips through comparison", {
  # 255.255.255.255 is the signed -1L; it must be the largest IPv4 address.
  expect_identical(
    vctrs::vec_compare(v4(255, 255, 255, 255), v4(0, 0, 0, 0)),
    1L
  )
  expect_identical(
    vctrs::vec_compare(v4(255, 255, 255, 255), v4(128, 0, 0, 0)),
    1L
  )
})

# --- Section 5.1.2: equality and ordering ------------------------------------

test_that("zone does not participate in equality (O2)", {
  lo0 <- raddr_address(-25165824L, 0L, 0L, 1L, "v6", "lo0")
  en0 <- raddr_address(-25165824L, 0L, 0L, 1L, "v6", "en0")

  expect_true(lo0 == en0)
  expect_identical(vctrs::vec_compare(lo0, en0), 0L)
  expect_false(addr_zone(lo0) == addr_zone(en0))
})

test_that("family participates in equality, so 0.0.0.0 is not ::", {
  expect_false(
    raddr_address(0L, 0L, 0L, 0L, "v4") == raddr_address(0L, 0L, 0L, 0L, "v6")
  )
})

test_that("::ffff:127.0.0.1 does not equal 127.0.0.1", {
  mapped <- raddr_address(0L, 0L, 65535L, 2130706433L, "v6_4in6")
  plain <- raddr_address(0L, 0L, 0L, 2130706433L, "v4")

  expect_false(mapped == plain)
})

test_that("ordering is total with IPv4 before IPv6 (O3)", {
  addrs <- c(
    raddr_address(0L, 0L, 0L, 0L, "v6"),
    v4(255, 255, 255, 255),
    raddr_address(0L, 0L, 65535L, 2130706433L, "v6_4in6"),
    v4(0, 0, 0, 0)
  )

  ranks <- as.character(addr_family(sort(addrs)))
  expect_identical(ranks, c("v4", "v4", "v6", "v6_4in6"))
  expect_false(anyNA(vctrs::vec_compare(addrs, addrs[[1]])))
})

test_that("v6_4in6 ranks with IPv6, not with its embedded IPv4", {
  mapped <- raddr_address(0L, 0L, 65535L, 2130706433L, "v6_4in6")

  # The embedded address is 127.0.0.1, which is below 255.255.255.255. Were the
  # 4-in-6 form interleaved with IPv4 by embedded value it would sort first;
  # the family rank decides instead.
  expect_identical(vctrs::vec_compare(mapped, v4(255, 255, 255, 255)), 1L)

  # And among IPv6 addresses it sorts by its full 128 bits: ::ffff:127.0.0.1
  # is above ::1 because of the ffff in w3.
  expect_identical(
    vctrs::vec_compare(mapped, raddr_address(0L, 0L, 0L, 1L, "v6")),
    1L
  )
})

test_that("equality and ordering agree", {
  addrs <- c(
    v4(127, 0, 0, 1),
    v4(128, 0, 0, 0),
    raddr_address(0L, 0L, 0L, 0L, "v6"),
    raddr_address(0L, 0L, 65535L, 2130706433L, "v6_4in6")
  )

  for (i in seq_along(addrs)) {
    for (j in seq_along(addrs)) {
      expect_identical(
        addrs[[i]] == addrs[[j]],
        vctrs::vec_compare(addrs[[i]], addrs[[j]]) == 0L
      )
    }
  }
})

test_that("sort() puts missing last and unique() collapses duplicates", {
  addrs <- c(
    v4(1, 1, 1, 1),
    raddr_address(0L, 0L, 0L, 1L, NA_character_),
    v4(1, 1, 1, 1)
  )

  expect_equal(vctrs::vec_size(unique(addrs)), 2L)
  expect_true(is.na(sort(addrs, na.last = TRUE)[[3]]))
})

# --- Formatting --------------------------------------------------------------
#
# The renderers themselves are test-format.R's business. What is asserted here
# is only that the type's `format()` is wired to the canonical one.

test_that("format is the canonical rendering and appends the zone", {
  expect_identical(format(v4(192, 0, 2, 1)), "192.0.2.1")
  expect_identical(format(v4(128, 0, 0, 0)), "128.0.0.0")
  expect_identical(
    format(raddr_address(-25165824L, 0L, 0L, 1L, "v6", "lo0")),
    "fe80::1%lo0"
  )
  expect_identical(
    addr_expand(raddr_address(-25165824L, 0L, 0L, 1L, "v6", "lo0")),
    "fe80:0000:0000:0000:0000:0000:0000:0001%lo0"
  )
})
