# Prose spelling, guarding the `Language: en-US` field in DESCRIPTION.
#
# `R CMD check` never inspects prose, so without a guard a British spelling can
# sit in a vignette or an .Rd file indefinitely -- which is what happened before
# `inst/WORDLIST` existed. Domain vocabulary lives in that file; add a word
# there only when it is genuinely a term of art, not to silence a typo.
#
# This file is the guard for anyone running `devtools::check()` or
# `devtools::test()`, which set NOT_CRAN. It is deliberately inert on CRAN,
# where a hunspell or dictionary difference would fail the check for a reason no
# edit here could fix -- and, because `rcmdcheck` does not set NOT_CRAN either,
# it is inert under this project's own verify hook too. That hook therefore
# calls `spelling::spell_check_package()` directly, alongside
# `lintr::lint_package()`. The authoritative guard is the hook; this file is the
# courtesy copy.
if (requireNamespace("spelling", quietly = TRUE)) {
  spelling::spell_check_test(
    vignettes = TRUE,
    error = TRUE,
    skip_on_cran = TRUE
  )
}
