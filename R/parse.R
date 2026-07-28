# The raddr_parse record. See docs/architecture.md sections 4, 5.2 and 6.1.
#
# The load-bearing decision is that outcomes are *per-dialect*. "4294967296" is
# accepted by `aton` as 0.0.0.0, rejected as an overflow by `whatwg`, and
# rejected as a non-dotted-quad by `strict`, all at once. A scalar status cannot
# say that, and every attempt to make it say that produced one of the errors in
# section 9.

# The four the record stores, in the order every per-dialect display uses.
raddr_primitives <- c("strict", "whatwg", "pton", "aton")

# The two compositions are precedence orderings over the primitives (section
# 3.2), so they are resolved on request rather than stored.
raddr_compositions <- c("getaddrinfo", "curl")

raddr_dialects <- c(raddr_primitives, raddr_compositions)

raddr_outcomes <- c("ok", "rejected", "not_an_address")

raddr_statuses <- c("ok", "divergent", "not_an_address", "malformed")

# The rule sets each primitive is, paired so `addr_parse()` runs the engine four
# times over one input rather than calling four exported functions that would
# each re-cast it.
#
# R/ipv4.R and R/ipv6.R collate before this file, so the rule sets are ordinary
# objects here rather than names to look up later.
primitive_rules <- list(
  strict = list(v4 = rules_strict, v6 = rules_v6_paper),
  whatwg = list(v4 = rules_whatwg, v6 = rules_v6_paper),
  pton = list(v4 = rules_pton, v6 = rules_v6_libc),
  aton = list(v4 = rules_aton, v6 = NULL)
)

#' Read an address literal under every dialect at once
#'
#' `addr_parse()` is raddr's primary answer. It reads each literal under all
#' four dialect primitives and reports every reading, the outcome of each, and
#' the reason codes behind each rejection -- rather than picking one reading and
#' discarding the rest.
#'
#' @section Why the outcome is per-dialect:
#'
#' Because a single one cannot be written down honestly. `"4294967296"` is
#' accepted by `aton` as `0.0.0.0`, rejected by `whatwg` as out of range, and
#' rejected by `strict` as not a dotted quad -- simultaneously, on one machine.
#' A record with one status has to choose which of those three to report, and
#' every choice is a lie about the other two.
#'
#' @section The derived status:
#'
#' [addr_status()] does collapse the four outcomes to one value, as a
#' **convenience and never as truth**:
#'
#' \describe{
#'   \item{`ok`}{Every primitive with a say accepts, and they yield the same
#'     address.}
#'   \item{`divergent`}{They are not unanimous -- on the value, or on whether to
#'     accept at all. `"4294967296"` is `divergent`.}
#'   \item{`not_an_address`}{No primitive treats the input as an attempt at an
#'     address. `"example.com"` is `not_an_address`.}
#'   \item{`malformed`}{At least one primitive treats it as an attempt, and none
#'     accepts.}
#' }
#'
#' "With a say" is doing work in the first of those. `inet_aton` is `AF_INET` by
#' signature, so it has no reading of `"::1"` to withhold and its silence there
#' is not dissent -- otherwise every IPv6 address on earth would be `divergent`.
#' A dialect that *has* the grammar and still declines is a different matter:
#' `"1.2.3.4 junk"` is `divergent`, because `aton` finds an address in it that
#' the other three do not, which is the class where curl reaches a host a
#' browser will not dial.
#'
#' Whenever the answer matters, read the per-dialect outcome instead.
#'
#' @section Printing:
#'
#' The print method is quiet when the dialects agree and loud when they do not:
#' a vector of ordinary addresses prints as a column of addresses, and a
#' divergent row is expanded underneath to show what each dialect made of it.
#' There is no mode to select and nothing to force -- see [dialects] for why the
#' dialect is a function name rather than an argument.
#'
#' @param x A character vector of address literals.
#'
#' @return A `raddr_parse` vector with one element per input, carrying `input`,
#'   the four per-dialect readings, the per-dialect `outcome` and `codes`, and
#'   the derived `status`.
#'
#' @seealso [addr_reading()] to pull one dialect's reading back out,
#'   [addr_codes_registry()] for the reason-code vocabulary, and [dialects] for
#'   the single-dialect shortcuts.
#'
#' @examples
#' # One string, four readings
#' addr_parse("0177.0.0.1")
#'
#' # Accepted by one dialect, rejected by three, for two different reasons
#' p <- addr_parse("4294967296")
#' addr_status(p)
#' addr_codes(p)
#'
#' # Agreement prints quietly
#' addr_parse(c("127.0.0.1", "::1"))
#'
#' @export
addr_parse <- function(x) {
  x <- vec_cast(x, character(), x_arg = "x")
  n <- length(x)

  readings <- lapply(raddr_primitives, function(dialect) {
    rules <- primitive_rules[[dialect]]
    parse_dialect_full(x, rules$v4, rules$v6, codes = TRUE)
  })
  names(readings) <- raddr_primitives

  colon <- grepl(":", x, fixed = TRUE) & !is.na(x)
  has_v6 <- vapply(
    raddr_primitives,
    function(dialect) !is.null(primitive_rules[[dialect]]$v6),
    logical(1L)
  )

  # Two different silences, kept apart. `applicable` is whether the dialect has
  # a grammar for the family the literal is spelled in at all; `attempt` is
  # whether, having one, it reads the literal as an attempt to use it.
  applicable <- lapply(has_v6, function(ipv6) if (ipv6) !logical(n) else !colon)
  attempt <- lapply(has_v6, function(ipv6) ip_attempt(x, colon, ipv6))
  names(applicable) <- raddr_primitives
  names(attempt) <- raddr_primitives

  outcome <- vector("list", length(raddr_primitives))
  codes <- vector("list", length(raddr_primitives))
  accepted_by <- vector("list", length(raddr_primitives))
  names(outcome) <- raddr_primitives
  names(codes) <- raddr_primitives
  names(accepted_by) <- raddr_primitives

  for (dialect in raddr_primitives) {
    accepted <- !is.na(field(readings[[dialect]]$address, "family"))
    accepted_by[[dialect]] <- accepted
    outcome[[dialect]] <- outcome_factor(accepted, attempt[[dialect]], x)
    # A dialect that never treated the input as an address has no objection to
    # it either, so its codes are empty rather than whatever its IPv4 rules
    # happened to make of a hostname.
    mask <- readings[[dialect]]$mask
    mask[accepted | !attempt[[dialect]]] <- 0L
    codes[[dialect]] <- new_list_of(codes_from_mask(mask), ptype = character())
  }

  new_raddr_parse(
    input = x,
    strict = readings$strict$address,
    whatwg = readings$whatwg$address,
    pton = readings$pton$address,
    aton = readings$aton$address,
    outcome = new_data_frame(outcome, n = n),
    codes = new_data_frame(codes, n = n),
    status = derive_status(readings, accepted_by, applicable, attempt, x)
  )
}

new_raddr_parse <- function(input, strict, whatwg, pton, aton,
                            outcome, codes, status) {
  new_rcrd(
    list(
      input = input,
      strict = strict, whatwg = whatwg, pton = pton, aton = aton,
      outcome = outcome, codes = codes, status = status
    ),
    class = "raddr_parse"
  )
}

#' Test whether an object is a `raddr_parse`
#'
#' @param x An object.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_raddr_parse(addr_parse("127.0.0.1"))
#' is_raddr_parse("127.0.0.1")
#'
#' @export
is_raddr_parse <- function(x) {
  inherits(x, "raddr_parse")
}

check_raddr_parse <- function(x, arg = "x") {
  if (!is_raddr_parse(x)) {
    abort(
      sprintf(
        "`%s` must be a <raddr_parse> vector, not %s.",
        arg,
        class(x)[[1L]]
      ),
      class = "raddr_error_type"
    )
  }
  invisible(x)
}

# --- Outcomes and the derived status -----------------------------------------

# Did this dialect treat the literal as an attempt at an address at all?
#
# `ends_in_a_number()` is the WHATWG test, and it is the right one here for the
# same reason it is right there: a host whose final label is a number has no
# reg-name reading to fall back to, so the dialect must either parse it or
# object to it. "example.com" is neither parsed nor objected to.
ip_attempt <- function(x, colon, ipv6) {
  if (ipv6) {
    return(ends_in_a_number(x) | colon)
  }
  # An AF_INET-only dialect has no reading of a colon literal to withhold, so
  # "::ffff:1.2.3.4" gets the same shrug from `aton` as "::1" does, rather than
  # a rejection that depends on how the tail happens to be spelled.
  ends_in_a_number(x) & !colon
}

outcome_factor <- function(accepted, attempt, input) {
  out <- ifelse(accepted, "ok", ifelse(attempt, "rejected", "not_an_address"))
  out[is.na(input)] <- NA_character_
  factor(out, levels = raddr_outcomes)
}

# The four outcomes collapsed to one value, and only ever a convenience.
#
# Unanimity is over the dialects that had a say, and working out which those are
# is the whole of the difficulty. Two silences look alike and are not:
#
#   "::1"           `aton` is AF_INET by signature and has no IPv6 grammar to
#                   withhold. Counting that as dissent would make *every* IPv6
#                   address divergent and the print method loud about "::1".
#   "1.2.3.4 junk"  `strict` has the grammar and declines to see an address --
#                   but `aton` finds 1.2.3.4 in it, so there is a real
#                   disagreement to report, and this is exactly the class where
#                   curl reaches a host a browser will not dial.
#
# So a dialect has a say when it accepted, or when it is applicable and either
# saw an attempt or *someone else* found an address in the string. An
# acceptance anywhere means the literal is an address, and no applicable dialect
# gets to shrug at it after that.
#
# Section 5.2's table says "all four primitives accept" because its worked
# examples are IPv4, where all four are applicable. This is the same rule
# written out for both families.
derive_status <- function(readings, accepted, applicable, attempt, input) {
  n <- length(input)
  k <- length(accepted)

  accepts <- as_row_matrix(accepted, n)
  any_accept <- .rowSums(accepts, n, k) > 0L
  says <- accepts |
    (as_row_matrix(applicable, n) & (as_row_matrix(attempt, n) | any_accept))

  n_ok <- .rowSums(accepts, n, k)
  n_says <- .rowSums(says, n, k)

  status <- rep("divergent", n)

  # Nothing accepted: either nobody thought it was an address, or somebody did
  # and could not read it.
  status[n_ok == 0L] <- "malformed"
  status[n_says == 0L] <- "not_an_address"

  # Everyone with a say accepted -- which is only agreement if they also agree
  # about the value. `4294967296` would otherwise be hidden behind the one
  # dialect that accepts it.
  unanimous <- n_says > 0L & n_ok == n_says
  if (any(unanimous)) {
    status[unanimous & readings_agree(readings, accepts, n)] <- "ok"
  }

  status[is.na(input)] <- NA_character_
  factor(status, levels = raddr_statuses)
}

as_row_matrix <- function(columns, n) {
  out <- unlist(columns, use.names = FALSE)
  dim(out) <- c(n, length(columns))
  out
}

# Do the accepting dialects agree about the value?
#
# Compared against the first acceptance in each row rather than pairwise, so the
# ragged part -- which dialects accepted, and how many -- stays out of the
# comparison. The equality proxy already leads with the family (section 5.1.1),
# so this compares the families too, and `::ffff:127.0.0.1` does not agree with
# `127.0.0.1`.
readings_agree <- function(readings, accepts, n) {
  first <- vec_slice(readings[[1L]]$address, rep(NA_integer_, n))
  for (i in seq_along(readings)) {
    need <- is.na(field(first, "family")) & accepts[, i]
    if (any(need)) {
      first <- vec_assign(first, need, vec_slice(readings[[i]]$address, need))
    }
  }
  same <- rep(TRUE, n)
  for (i in seq_along(readings)) {
    same <- same &
      (!accepts[, i] | vec_equal(readings[[i]]$address, first, na_equal = TRUE))
  }
  same
}

# --- Accessors ---------------------------------------------------------------

check_dialect <- function(dialect) {
  if (!is_string(dialect) || !dialect %in% raddr_dialects) {
    abort(
      c(
        sprintf(
          "`dialect` must be one of %s.",
          paste0("\"", raddr_dialects, "\"", collapse = ", ")
        ),
        x = sprintf("Got: %s.", deparse(dialect)[[1L]])
      ),
      class = "raddr_error_dialect"
    )
  }
  dialect
}

# getaddrinfo() rejects an input whose *address* carries whitespace before
# either primitive sees it (section 3.2). The gate is the one part of the
# composition that is not resolvable from the two readings alone, so it is
# re-derived here from the stored input.
gai_whitespace <- function(input) {
  grepl("[ \t\r\n\v\f]", sub("%.*$", "", input)) & !is.na(input)
}

blank_address <- function(a, at) {
  if (!any(at)) {
    return(a)
  }
  vec_assign(a, at, vec_slice(a, NA_integer_))
}

composed_reading <- function(x, dialect) {
  gated <- gai_whitespace(field(x, "input"))
  gai <- gai_extract_scope(compose_dialects(
    blank_address(field(x, "pton"), gated),
    blank_address(field(x, "aton"), gated)
  ))
  if (dialect == "curl") {
    # curl falls back to the `getaddrinfo` entry point, not to bare `pton`
    # (section 3.2), so the scope lift rides along. `aton` runs first, so
    # neither the whitespace gate nor the inner `aton` fallback is reachable
    # from here.
    return(compose_dialects(field(x, "aton"), gai))
  }
  gai
}

#' Pull one dialect's reading, outcome or reason codes back out
#'
#' Accessors on a [addr_parse()] result. All of them admit the two compositions
#' as well as the four primitives: the record stores only the primitives, and
#' `getaddrinfo` and `curl` are resolved from those on request (section 3.2).
#'
#' `dialect` is a **view selector on output, not a leniency knob on input**. The
#' parsing already happened, under every dialect, and choosing one here only
#' chooses which of the finished readings to look at. That is why there is a
#' dialect argument on these and not on [addr_parse()].
#'
#' @param x A `raddr_parse` vector.
#' @param dialect One of `"strict"`, `"whatwg"`, `"pton"`, `"aton"`,
#'   `"getaddrinfo"` or `"curl"`. For `addr_codes()`, `NULL` unions every
#'   dialect's codes.
#'
#' @return
#'   `addr_reading()` a `raddr_address`; `addr_outcome()` a factor with levels
#'   `"ok"`, `"rejected"` and `"not_an_address"`; `addr_codes()` a list of
#'   character vectors; `addr_status()` a factor with levels `"ok"`,
#'   `"divergent"`, `"not_an_address"` and `"malformed"`;
#'   `addr_is_divergent()` a logical vector.
#'
#' @examples
#' p <- addr_parse(c("0177.0.0.1", "127.0.0.1", "example.com"))
#'
#' addr_reading(p, "whatwg")
#' addr_reading(p, "curl")
#' addr_outcome(p, "strict")
#' addr_codes(p, "strict")
#' addr_status(p)
#' addr_is_divergent(p)
#'
#' @name parse-accessors
NULL

#' @rdname parse-accessors
#' @export
addr_reading <- function(x, dialect) {
  check_raddr_parse(x)
  dialect <- check_dialect(dialect)
  if (dialect %in% raddr_primitives) {
    return(field(x, dialect))
  }
  composed_reading(x, dialect)
}

#' @rdname parse-accessors
#' @export
addr_outcome <- function(x, dialect) {
  check_raddr_parse(x)
  dialect <- check_dialect(dialect)
  if (dialect %in% raddr_primitives) {
    return(field(x, "outcome")[[dialect]])
  }

  parts <- composition_parts(dialect)
  outcome <- field(x, "outcome")
  accepted <- !is.na(field(addr_reading(x, dialect), "family"))
  # A composition treats the literal as an address if either of its primitives
  # does; the whitespace gate is a rejection, not a shrug.
  silent <- !is.na(outcome[[parts[[1L]]]]) &
    outcome[[parts[[1L]]]] == "not_an_address" &
    outcome[[parts[[2L]]]] == "not_an_address"
  if (dialect == "getaddrinfo") {
    silent <- silent & !gai_whitespace(field(x, "input"))
  }
  outcome_factor(accepted, !silent, field(x, "input"))
}

# The *outcome* surface resolves over the two primitives even though curl's
# reading falls back to the whole `getaddrinfo` entry point, and that is not a
# leftover: `getaddrinfo` accepts what `pton` accepts plus what `aton` accepts,
# and `aton` has already answered by then. Its scope lift moves bits, never
# acceptance. So curl's acceptance set is still `aton` union `pton`, which is
# what tests/testthat/test-parse.R pins.
composition_parts <- function(dialect) {
  switch(
    dialect,
    getaddrinfo = c("pton", "aton"),
    curl = c("aton", "pton")
  )
}

#' @rdname parse-accessors
#' @export
addr_codes <- function(x, dialect = NULL) {
  check_raddr_parse(x)
  if (is.null(dialect)) {
    return(union_codes(as.list(field(x, "codes")), rep(TRUE, vec_size(x))))
  }
  dialect <- check_dialect(dialect)
  stored <- field(x, "codes")
  if (dialect %in% raddr_primitives) {
    return(as.list(stored[[dialect]]))
  }

  parts <- composition_parts(dialect)
  rejected <- !is.na(addr_outcome(x, dialect)) &
    addr_outcome(x, dialect) == "rejected"
  out <- union_codes(
    list(stored[[parts[[1L]]]], stored[[parts[[2L]]]]),
    rejected
  )
  if (dialect == "getaddrinfo") {
    gated <- which(gai_whitespace(field(x, "input")) & rejected)
    for (i in gated) {
      out[[i]] <- union(out[[i]], "whitespace")
    }
  }
  lapply(out, order_codes)
}

# Union the code lists of several dialects, row by row but only over the rows
# that have any. `where` is FALSE for every accepted row, which in a real vector
# is nearly all of them, so this never walks the whole thing.
union_codes <- function(columns, where) {
  n <- length(where)
  out <- rep(list(character()), n)
  at <- which(where & Reduce(`|`, lapply(columns, function(col) {
    lengths(col) > 0L
  })))
  for (i in at) {
    out[[i]] <- order_codes(unique(unlist(
      lapply(columns, function(col) col[[i]]),
      use.names = FALSE
    )))
  }
  out
}

# Registry order, so a code vector reads the same whatever produced it.
order_codes <- function(codes) {
  if (length(codes) < 2L) {
    return(codes)
  }
  codes[order(match(codes, parse_code_levels))]
}

#' @rdname parse-accessors
#' @export
addr_status <- function(x) {
  check_raddr_parse(x)
  field(x, "status")
}

#' @rdname parse-accessors
#' @export
addr_is_divergent <- function(x) {
  status <- addr_status(x)
  !is.na(status) & status == "divergent"
}

#' @rdname parse-accessors
#' @export
addr_input <- function(x) {
  check_raddr_parse(x)
  field(x, "input")
}

# --- Printing (section 4) -----------------------------------------------------

# Where R structurally forces one value out of four readings, the default is
# `whatwg`: a fixed, versioned standard rather than an implementation, so the
# answer does not depend on the machine raddr happens to be running on.
#' @export
format.raddr_parse <- function(x, ...) {
  addr_format(field(x, "whatwg"))
}

#' @export
as.character.raddr_parse <- function(x, ...) {
  format(x, ...)
}

#' @export
obj_print_data.raddr_parse <- function(x, ...) {
  if (vec_size(x) == 0L) {
    return(invisible(x))
  }
  print(format(x), quote = FALSE)
  invisible(x)
}

# The quiet-or-loud rule of section 4 lives here. A vector whose dialects all
# agree prints as a column of addresses and says nothing else; one that diverges
# gets the divergence spelled out underneath.
#
# The report is capped, and it is *one* report for the whole vector however long
# it is. Ten thousand bad rows produce one diagnostic, not ten thousand -- which
# is the thing section 9 says to refuse from `ipaddress`.
divergence_cap <- 5L

#' @export
obj_print_footer.raddr_parse <- function(x, ...) {
  n <- vec_size(x)
  if (n == 0L) {
    return(invisible(x))
  }
  status <- addr_status(x)
  quiet <- !is.na(status) & status == "ok"
  if (all(quiet)) {
    return(invisible(x))
  }

  tally <- table(status, useNA = "no")
  tally <- tally[tally > 0L]
  cat(sprintf(
    "Status: %s\n",
    paste(sprintf("%s %d", names(tally), as.integer(tally)), collapse = ", ")
  ))

  at <- which(addr_is_divergent(x))
  if (!length(at)) {
    return(invisible(x))
  }
  shown <- at[seq_len(min(length(at), divergence_cap))]
  input <- field(x, "input")
  for (i in shown) {
    cat(sprintf("\n[%d] \"%s\"\n", i, input[[i]]))
    for (dialect in raddr_primitives) {
      cat(sprintf(
        "  %-7s %s\n",
        dialect,
        describe_reading(x, dialect, i)
      ))
    }
  }
  if (length(at) > length(shown)) {
    cat(sprintf("\n... and %d more divergent\n", length(at) - length(shown)))
  }
  invisible(x)
}

describe_reading <- function(x, dialect, i) {
  outcome <- as.character(field(x, "outcome")[[dialect]][[i]])
  if (identical(outcome, "ok")) {
    return(addr_format(vec_slice(field(x, dialect), i)))
  }
  codes <- field(x, "codes")[[dialect]][[i]]
  if (!length(codes)) {
    return(sprintf("<%s>", outcome))
  }
  sprintf("<%s: %s>", outcome, paste(codes, collapse = ", "))
}

#' @export
vec_ptype_abbr.raddr_parse <- function(x, ...) {
  "parse"
}

#' @export
vec_ptype_full.raddr_parse <- function(x, ...) {
  "raddr_parse"
}
