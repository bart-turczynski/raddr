# The raddr_embedding type. See docs/architecture.md section 5.3.5.
#
# `embeddings` is PLURAL BY CONSTRUCTION, and Teredo is why. RFC 4380 section 4
# puts two IPv4 addresses in one Teredo address -- the server in the clear at
# bits 32-63, and the client bitwise-complemented at bits 96-127 -- and both are
# destinations, not one address plus metadata. Section 5.2.6 directs a host to
# extract the SERVER address from a peer's address and send a UDP bubble to it.
#
# A scalar field cannot say that. `embedded_scope` was removed for exactly this
# reason: reducing two embedded addresses to one IS the Teredo decision, and
# raddr does not make it (P8). The same objection killed the field twice --
# first in a name (`effective_scope` asserts one of three true fields is the
# real one), then in a cardinality.
#
# EXTRACTION IS EPIC J. This file defines the type and its empty value; nothing
# here reads bits out of an address yet, so every element `addr_classify()`
# builds today has zero rows. The type is settled now so that the record does
# not have to be re-versioned when the extractor lands.

# `embedded` for the forms that carry one address; `server` and `client` for
# Teredo, in RFC 4380 section 4's order. Not a ranking -- raddr reports both and
# says which field each came from, which is the fact the RFC states.
raddr_embedding_roles <- c("embedded", "server", "client")

new_raddr_embedding <- function(kind = factor(levels = raddr_embedded_kinds),
                                role = factor(levels = raddr_embedding_roles),
                                address = raddr_address(),
                                category = factor(
                                  levels = raddr_category_levels
                                )) {
  new_rcrd(
    list(kind = kind, role = role, address = address, category = category),
    class = "raddr_embedding"
  )
}

# The empty value, and the `list_of` prototype every `embeddings` column is
# built against. One ptype across the whole vector is what keeps the outer
# record `vctrs` size-stable (section 5.3.5): rows multiply only when a caller
# explicitly unnests.
empty_raddr_embedding <- function() {
  new_raddr_embedding()
}

#' Test whether an object is a `raddr_embedding`
#'
#' The elements of the `embeddings` column of a [addr_classify()] result. There
#' is no public constructor: these are produced by classification, not built by
#' hand.
#'
#' @param x An object.
#'
#' @return A single `TRUE` or `FALSE`.
#'
#' @examples
#' is_raddr_embedding(addr_embeddings(addr_pton("64:ff9b::a9fe:a9fe"))[[1]])
#' is_raddr_embedding("169.254.169.254")
#'
#' @export
is_raddr_embedding <- function(x) {
  inherits(x, "raddr_embedding")
}

# `kind/role`, then the address, then what that address classifies as. The kind
# repeats the outer record's `embedded_kind`, and it is here anyway because
# Teredo's two rows share a kind and differ only in role -- reading a row on its
# own should not need the record it came out of.
#' @export
format.raddr_embedding <- function(x, ...) {
  n <- vec_size(x)
  if (n == 0L) {
    return(character())
  }
  sprintf(
    "%s/%s %s %s",
    as.character(field(x, "kind")),
    as.character(field(x, "role")),
    addr_format(field(x, "address")),
    as.character(field(x, "category"))
  )
}

#' @export
obj_print_data.raddr_embedding <- function(x, ...) {
  if (vec_size(x) == 0L) {
    return(invisible(x))
  }
  print(format(x), quote = FALSE)
  invisible(x)
}

#' @export
as.character.raddr_embedding <- function(x, ...) {
  format(x, ...)
}

#' @export
vec_ptype_abbr.raddr_embedding <- function(x, ...) {
  "embed"
}

#' @export
vec_ptype_full.raddr_embedding <- function(x, ...) {
  "raddr_embedding"
}
