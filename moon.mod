name = "thy1016/moonttl"

version = "0.2.2"

import {
  "moonbitlang/async@0.19.1",
  "brickfrog/tempo@0.8.0",
  "moonbit-community/quickcheck_statemachine@0.0.1",
  "moonbitlang/quickcheck@0.14.0",
  "hnlyxiaobing/toml@0.4.6",
  "minie135/moon-audit@0.2.1",
  "wedarp/moongraph@0.2.2",
  "moonbit-community/graphviz@0.1.3",
}

readme = "README.mbt.md"

repository = "https://www.gitlink.org.cn/thy7/mbt.ttl"

license = "Apache-2.0"

keywords = [ "nquads", "rdf" ]

description = "MoonTTL is a high-performance RDF parsing and serialization library for MoonBit."

preferred_target = "native"

source = "src"

options(
  warn: false,
)
