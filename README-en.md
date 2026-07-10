# MoonTTL

MoonTTL is a high-performance RDF parsing and serialization library written in MoonBit. This project is ported from the excellent Rust library Oxttl, aiming to provide a standardized, lightweight semantic web data processing engine for the MoonBit ecosystem.

## Features

- **Multi-format Support**: Full support for Turtle, TriG, N-Triples, N-Quads and N3 parsing and serialization.
- **RDF 1.2 Compatible**: Fully compatible with the latest RDF 1.2 international standard specification (except N3).
- **High Performance**: Based on MoonBit's high-performance compilation backend, providing low-memory streaming parsing capabilities.
- **Pure MoonBit Implementation**: Utilizes MoonBit's native type system and garbage collection mechanism for a clean API experience.

## Installation

Make sure you have the MoonBit toolchain installed.

Add the dependency to your `moon.mod.json`:

```json
{
  "name": "your_username/your_project",
  "deps": [
    "thy1016/moonttl"
  ]
}
```

## Command Line Tool

### Parse from String

```bash
moon run src/cmd/main -- "<http://example.org/s> <http://example.org/p> <http://example.org/o> ."
```

### Parse from File

```bash
echo '<http://example.org/s> <http://example.org/p> <http://example.org/o> .' > test.nq
moon run src/cmd/main -- -f test.nq
```

### Verbose Output Mode

```bash
moon run src/cmd/main -- -v -f test.nq
```

## Command Line Options

- `-f, --file <path>` - Specify input file path
- `-v, --verbose` - Enable verbose output mode
- `<input>` - Direct N-Quads format string input

## N-Quads Format

N-Quads is a simple line-based RDF quad format:

```
<subject> <predicate> <object> <graph> .
```

The graph part is optional, defaulting to the default graph.

Example:
```
<http://example.org/s> <http://example.org/p> <http://example.org/o> .
```

## Example Code

```moonbit
let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
let data = @utf8.encode(content)

let lexer = @lib.Lexer::Lexer(
  @lib.RdfLexer::RdfLexer(@lib.RdfLexerMode::NTriples, false),
  data.to_array(),
  true,
  @lib.MIN_BUFFER_SIZE,
  @lib.MAX_BUFFER_SIZE,
  Some(b"#"),
  0,
  0,
)

let machine = @lib.NQuadsRecognizer::{
  stack: [@lib.NQuadsState::ExpectSubject],
  subjects: [],
  predicates: [],
  objects: [],
  lenient: false,
  debug_logger: @lib.make_mute_logger(),
  last_range: @lib.Range::default(),
  errors: [],
}

let context = @lib.RdfContext::NQuadsRecognizerContext(
  @lib.NQuadsRecognizerContext::{
    with_graph_name: false,
    lexer_options: { base_iri: None },
  },
)

let parser = @lib.ParserM::{
  lexer,
  engine: @lib.GenericStateMachine::{ machine, context, outputs: [] },
  context,
  errors: [],
}

for ;; {
  match parser.parse_next() {
    Some(Ok(quad)) => println("Parsed: \{quad}")
    Some(Err(e)) => println("Error: \{e}")
    None => break
  }
}
```

## Examples

### Parse N-Quads File

Run the example program:

```bash
moon run src/examples/nquads
```

Output example:

```
Written N-Quads content to: ./example.nq
Parsing N-Quads file...
[1] Quad<http://example.org/s1, http://example.org/p1, http://example.org/o1>
[2] Quad<http://example.org/s2, http://example.org/p2, http://example.org/o2>
[3] Quad<http://example.org/s3, http://example.org/p3, http://example.org/o3>
[4] Error: InvalidTurtleToken - Unexpected end of input turtle .

=== Summary ===
Total quads parsed: 3
```

This example demonstrates:
- Creating N-Quads content from strings and writing to file
- Reading from file and parsing as binary data
- Using lexer and state machine to parse RDF quads
- Error handling and result summary

## Project Structure

```
src/
├── lexer_*.mbt      # Lexer
├── parser*.mbt      # Parser
├── nquads_*.mbt     # N-Quads format support
├── turtle_*.mbt     # Turtle format support
├── trig_*.mbt       # TriG format support
├── n3_*.mbt         # N3 format support
├── iri.mbt          # IRI handling
├── literal.mbt      # Literal handling
├── langtag.mbt      # Language tag handling
└── tests/           # Test files
```

## License

This project is licensed under either of:

* Apache License, Version 2.0, ([LICENSE-APACHE](../LICENSE-APACHE) or
  `<http://www.apache.org/licenses/LICENSE-2.0>`)
* MIT license ([LICENSE-MIT](../LICENSE-MIT) or
  `<http://opensource.org/licenses/MIT>`)

at your option.

## Contributing

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in MoonTTL shall be dual licensed as above, without any additional terms or conditions.
