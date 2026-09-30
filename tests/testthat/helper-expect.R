# Address equality is raddr's own `==`, which ignores what does not identify
# the address (a zone ID, the letter case or grouping of a decoded string), so
# these comparisons cannot be expect_identical(). Like expect_true(a == b), it
# passes only on a single TRUE: FALSE and NA both fail.
expect_same_address <- function(object, expected) {
  act <- quasi_label(rlang::enquo(object), arg = "object")
  exp <- quasi_label(rlang::enquo(expected), arg = "expected")
  expect(
    isTRUE(act$val == exp$val),
    sprintf("%s is not the same address as %s.", act$lab, exp$lab)
  )
  invisible(act$val)
}
