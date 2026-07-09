name = "thy1016/moonttl"

version = "0.1.0"

import {
  "tonyfettes/utf8@0.2.4",
  "moonbitlang/async@0.19.1",
  "brickfrog/tempo@0.8.0",
  "justjavac/itoa@0.2.2",
  "moonbit-community/quickcheck_statemachine@0.0.1",
  "moonbitlang/quickcheck@0.14.0",
}

readme = "README.mbt.md"

repository = "https://www.gitlink.org.cn/thy7/mbt.ttl"

license = "MIT"

keywords = [ "ttl", "rdf" ]

description = "MoonTTL is a high-performance RDF parsing and serialization library for MoonBit, supporting Turtle, TriG, N-Triples, N-Quads and N3 formats."

preferred_target = "native"
// supported_targets = "+wasm+wasm-gc"

source = "src"

options(
  warn: false,
)
