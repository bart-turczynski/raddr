// Read NUL-delimited literals and report std::net::IpAddr readings.
//
// Output is two NUL-delimited fields per input: the fully normalized address,
// then an empty zone field. Rust's standard parser does not accept zones.

use std::io::{self, Read, Write};
use std::net::{IpAddr, Ipv6Addr};
use std::str::FromStr;

fn expand_v6(address: Ipv6Addr) -> String {
    let segments = address.segments();
    segments
        .iter()
        .map(|segment| format!("{segment:04x}"))
        .collect::<Vec<_>>()
        .join(":")
}

fn reading(literal: &str) -> String {
    match IpAddr::from_str(literal) {
        Ok(IpAddr::V4(address)) => address.to_string(),
        Ok(IpAddr::V6(address)) => expand_v6(address),
        Err(_) => String::new(),
    }
}

fn main() -> io::Result<()> {
    let mut payload = Vec::new();
    io::stdin().read_to_end(&mut payload)?;
    if payload.last() == Some(&0) {
        payload.pop();
    }

    let mut output = Vec::new();
    for raw in payload.split(|byte| *byte == 0) {
        let address = std::str::from_utf8(raw).map(reading).unwrap_or_default();
        output.extend_from_slice(address.as_bytes());
        output.push(0);
        output.push(0);
    }
    io::stdout().write_all(&output)
}
