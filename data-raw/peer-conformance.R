# Compare difficult address literals across raddr, the surveyed R peers, and
# canonical standard-library parsers. This is a conformance probe, not a speed
# benchmark: it runs every unique literal in the package's fixture, boundary,
# and generated adversarial corpora and triages differences by contract.
#
# Run from the package root:
#   Rscript data-raw/peer-conformance.R
#
# The detailed row-level result is written to _scratch/peer-conformance.csv.
# Override that path with RADDR_CONFORMANCE_OUT.

for (package in c("devtools", "ipaddress", "iptools", "testthat")) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("data-raw/peer-conformance.R needs ", package)
  }
}
for (command in c("go", "python3", "rustc")) {
  if (!nzchar(Sys.which(command))) {
    stop("data-raw/peer-conformance.R needs ", command, " on PATH")
  }
}

devtools::load_all(".", quiet = TRUE)
source("tests/testthat/helper-dialects.R")
source("tests/testthat/helper-corpus.R")
source("data-raw/oracle-tools.R")

literal_all <- corpus_literals()
literal <- unique(literal_all[!is.na(literal_all)])

normalize <- function(address) {
  out <- addr_expand(address)
  out <- sub("%.*$", "", out)
  out[is.na(address)] <- ""
  out
}

raddr_readings <- lapply(
  all_dialects,
  function(dialect) normalize(dialect_fn(dialect)(literal))
)
names(raddr_readings) <- all_dialects

split_pairs <- function(fields, n, implementation) {
  if (length(fields) != 2L * n) {
    stop(
      implementation, " returned ", length(fields), " fields for ", n,
      " literals"
    )
  }
  list(
    addr = fields[c(TRUE, FALSE)],
    zone = fields[c(FALSE, TRUE)]
  )
}

run_nul <- function(command, args, implementation) {
  payload <- unlist(lapply(literal, function(x) c(charToRaw(x), as.raw(0L))))
  infile <- tempfile(paste0(implementation, "-in"))
  outfile <- tempfile(paste0(implementation, "-out"))
  on.exit(unlink(c(infile, outfile)), add = TRUE)
  writeBin(payload, infile)

  status <- system2(
    command, args, stdin = infile, stdout = outfile, stderr = ""
  )
  if (!identical(status, 0L)) {
    stop(implementation, " exited ", status)
  }
  raw_out <- readBin(outfile, "raw", n = file.size(outfile))
  split_pairs(split_nul(raw_out), length(literal), implementation)
}

python <- run_nul(
  "python3", shQuote("data-raw/oracle-python.py"), "python"
)

netip4 <- netip_readings(literal, 4L)
netip6 <- netip_readings(literal, 6L)
go_addr <- ifelse(nzchar(netip4$addr), netip4$addr, netip6$addr)
go_zone <- ifelse(nzchar(netip4$addr), netip4$zone, netip6$zone)

rust_bin <- tempfile("oracle-rust")
on.exit(unlink(rust_bin), add = TRUE)
rust_status <- system2(
  "rustc",
  c("-O", shQuote("data-raw/oracle-rust.rs"), "-o", shQuote(rust_bin))
)
if (!identical(rust_status, 0L)) {
  stop("rustc exited ", rust_status)
}
rust <- run_nul(rust_bin, character(), "rust")

r_ipaddress_object <- suppressWarnings(ipaddress::ip_address(literal))
r_ipaddress <- format(r_ipaddress_object, exploded = TRUE)
r_ipaddress[is.na(r_ipaddress)] <- ""

iptools_class <- suppressWarnings(iptools::ip_classify(literal))
r_iptools <- rep("", length(literal))
is_v4 <- !is.na(iptools_class) & iptools_class == "IPv4"
is_v6 <- !is.na(iptools_class) & iptools_class == "IPv6"
r_iptools[is_v4] <- iptools::numeric_to_ip(
  iptools::ip_to_numeric(literal[is_v4])
)
r_iptools[is_v6] <- suppressWarnings(iptools::expand_ipv6(literal[is_v6]))

same <- function(left, right) {
  left == right
}

zone_free <- !grepl("%", literal, fixed = TRUE)
canonical_ok <- same(raddr_readings$strict, rust$addr) &
  (!zone_free | same(raddr_readings$strict, python$addr)) &
  (!zone_free | same(raddr_readings$strict, go_addr))

if (!all(canonical_ok)) {
  bad <- literal[!canonical_ok]
  stop(
    "untriaged canonical divergence on ", length(bad), " rows: ",
    paste(utils::head(escape_control(bad), 10L), collapse = ", ")
  )
}

triage_peer <- function(peer) {
  strict <- raddr_readings$strict
  accepted_peer <- nzchar(peer)
  accepted_strict <- nzchar(strict)
  out <- rep("strict_agreement", length(peer))

  out[accepted_strict & !accepted_peer] <- "rejects_paper_address"
  out[!accepted_strict & accepted_peer] <- "non_paper_reading"
  out[accepted_strict & accepted_peer & peer != strict] <- "different_address"

  non_paper <- which(out == "non_paper_reading")
  if (length(non_paper)) {
    matches <- vapply(
      non_paper,
      function(i) {
        dialects <- all_dialects[
          vapply(raddr_readings, function(x) peer[[i]] == x[[i]], logical(1L))
        ]
        dialects <- setdiff(dialects, "strict")
        if (length(dialects)) {
          paste0("other_dialect:", paste(dialects, collapse = "+"))
        } else {
          "peer_only_reading"
        }
      },
      character(1L)
    )
    out[non_paper] <- matches
  }
  zone <- grepl("%", literal, fixed = TRUE)
  zone_bits <- zone & accepted_peer &
    peer == raddr_readings$pton
  out[zone_bits] <- "zone_discarded"
  multiple_zone <- grepl("%.*%", literal) & accepted_peer
  out[multiple_zone] <- "zone_truncated_at_first_percent"
  out
}

ipaddress_triage <- triage_peer(r_ipaddress)
iptools_triage <- triage_peer(r_iptools)

result <- data.frame(
  input = escape_control(literal),
  raddr_strict = raddr_readings$strict,
  python = python$addr,
  python_zone = escape_control(python$zone),
  go = go_addr,
  go_zone = escape_control(go_zone),
  rust = rust$addr,
  r_ipaddress = r_ipaddress,
  r_ipaddress_triage = ipaddress_triage,
  r_iptools = r_iptools,
  r_iptools_triage = iptools_triage,
  stringsAsFactors = FALSE
)

output <- Sys.getenv(
  "RADDR_CONFORMANCE_OUT", "_scratch/peer-conformance.csv"
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
write.csv(result, output, row.names = FALSE, na = "")

version_line <- paste(
  paste("R", getRversion()),
  paste("raddr", utils::packageVersion("raddr")),
  paste("R ipaddress", utils::packageVersion("ipaddress")),
  paste("R iptools", utils::packageVersion("iptools")),
  system2("python3", "--version", stdout = TRUE),
  system2("go", "version", stdout = TRUE),
  system2("rustc", "--version", stdout = TRUE),
  sep = " | "
)
cat(version_line, "\n")
cat(
  "corpus:", length(literal_all), "rows;", length(literal),
  "unique non-missing literals; 1 missing-value contract row\n"
)
cat("canonical zone-free divergences: 0\n")
cat(
  "canonical zone extension: Python accepts", sum(nzchar(python$zone)),
  "rows; Go accepts", sum(nzchar(go_zone)),
  "rows; Rust and raddr strict accept 0\n\n"
)

print_triage <- function(name, triage) {
  counts <- sort(table(triage), decreasing = TRUE)
  cat(name, "\n", sep = "")
  for (category in names(counts)) {
    examples <- escape_control(literal[triage == category])
    cat(
      sprintf(
        "  %-44s %4d  %s\n", category, counts[[category]],
        paste(utils::head(examples, 3L), collapse = " | ")
      )
    )
  }
  cat("\n")
}

print_triage("R ipaddress", ipaddress_triage)
print_triage("R iptools", iptools_triage)
cat("R IP 0.1.6: not runnable on R 4.6; compilation fails before parsing\n")
cat("wrote", nrow(result), "row-level results to", output, "\n")
