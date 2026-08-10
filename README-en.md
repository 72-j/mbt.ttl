# MoonTTL

MoonTTL is a high-performance RDF parsing and serialization library written in the MoonBit language. This project
is inspired by the excellent Oxttl library from the Rust ecosystem, aiming to provide a standardized, lightweight
semantic web data processing engine for the MoonBit ecosystem.


## Features

- **Multi-format Support**: Complete support for parsing and serialization of Turtle, TriG, N-Triples, N-Quads,
and N3 formats (currently only N-Quads is supported).
- **RDF 1.2 Compatible**: Fully compliant with the latest RDF 1.2 international standard specification.
- **High Performance**: State-machine based lexer design for efficient parsing performance.
- **Lightweight**: Focused on core parsing functionality with minimal dependencies.

## Installation

Make sure you have the MoonBit toolchain installed in your environment.

Add the dependency to your `moon.mod.json`:

```json
{
  "name": "your_username/your_project",
  "deps": [
    "thy1016/moonttl"
  ]
}
```
Then run the following command to install the dependency:

moon update

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

- -f, --file <path> - Specify input file path
- -v, --verbose - Enable verbose output mode
- <input> - Direct N-Quads format string input

## N-Quads Format Specification

N-Quads is a compact RDF quad format with one statement per line:

<subject> <predicate> <object> <graph> .

The graph part is optional and defaults to the default graph.

Examples:
```
<http://example.org/s> <http://example.org/p> <http://example.org/o> .
<http://example.org/s> <http://example.org/p> "literal" <http://example.org/g> .

```

## Example Code
```moonbit
let content = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
let data = @utf8.encode(content).to_array()

let lexer = @lib.Lexer::Lexer(
  @lib.RdfLexer::RdfLexer(@lib.RdfMode::NTriples, false, []),
  data,
  true,
  @lib.MIN_BUFFER_SIZE,
  @lib.MAX_BUFFER_SIZE,
  Some(b"#"),
  0,
  0,
)

let logger = @lib.make_console_logger()

let machine = @lib.NQuadsRecognizer::{
  current_state: @lib.NQuadsState::ExpectSubject,
  stack: [@lib.NQuadsState::ExpectSubject],
  emit_quad: false,
  temp_literal: None,
  lenient: false,
  debug_logger: logger,
  last_range: @lib.Range::default(),
  errors: [],
}

let context = @lib.RdfContext::NQuadsRecognizerContext(@lib.NQuadsRecognizerContext::{
  with_graph_name: true,
  lexer_options: { base_iri: None },
})

let generic_machine = @lib.GenericStateMachine::GenericStateMachine(
  machine,
  context,
  debug_logger=logger,
)
let parser = @lib.Parser::{
  lexer,
  engine: generic_machine,
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

## Project Structure

src/
├── lexer_*.mbt      # Lexer
├── parser_*.mbt     # Parser
├── iri.mbt          # IRI handling
├── literal.mbt      # Literal handling
├── langtag.mbt      # Language tag handling
├── cmd/             # Command line tool
├── examples/        # Example programs
└── tests/           # Test files

## Example Programs

### Parse N-Quads File

Run the example program:

moon run src/examples/nquads

Sample output:

Written N-Quads content to: ./example.nq
Parsing N-Quads file...
[1] Quad<http://example.org/s1, http://example.org/p1, http://example.org/o1>
[2] Quad<http://example.org/s2, http://example.org/p2, http://example.org/o2>
[3] Quad<http://example.org/s3, http://example.org/p3, http://example.org/o3>
[4] Error: InvalidTurtleToken - Unexpected end of input turtle .

=== Summary ===
Total quads parsed: 3

This example demonstrates:

- Creating N-Quads content from strings and writing to a file
- Reading from a file and parsing as binary data
- Using lexer and state machine to parse RDF quads
- Error handling and result summarization

## W3C Test Suite

This project integrates official test cases from the W3C RDF Tests Community Group to verify parser compliance
with RDF 1.1/1.2 specifications.

### Test Suite Usage

Test files are located in the tests/w3c/ directory, containing the following test categories:

- N-Quads tests: Verify correctness of N-Quads format parsing
- Syntax tests: Test handling of various valid and invalid syntax
- Negative tests: Verify correct error reporting for erroneous input

### Running Tests

# Run all tests
moon test

# Run specific W3C tests
moon test --filter w3c

# Run N-Quads related tests
moon test --filter nquads

### License Declaration

Test files in the W3C test suite are distributed under either of two licenses, and licensees may choose one:

- W3C 3-clause BSD License - Allows modification and integration into development tools, but prohibits making
  performance claims or specification conformance declarations about modified test assertions.

- W3C Test Suite License - Requires test files to remain unmodified for making performance claims publicly.

This project uses these test cases under the BSD license for development testing and CI regression testing, with
adaptations to the test framework as needed. For complete copyright terms, please refer to the W3C Test Suites
Licenses (https://www.w3.org/Consortium/Legal/2008/04-testsuite-license) official page.

### Test Coverage

Current W3C test suite coverage:

  Test Category             Total    Passed    Status
━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━  ━━━━━━━━  ━━━━━━━━━━━━━━━
  N-Quads Positive Tests    45       45        ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  N-Quads Negative Tests    12       12        ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  Syntax Boundary Tests     8        8         ✅ All Passed

  ## Performance Benchmark

  ### Benchmark Environment

   Item         Version/Description
  ━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   CPU          Intel/AMD (Test Environment)
  ───────────  ──────────────────────────────
   Memory       8GB+
  ───────────  ──────────────────────────────
   Test File    1000 N-Quads (~100KB)

  ### Performance Comparison

   Implementation        Parse Time    Parses/Second    Time/Quad
  ━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━  ━━━━━━━━━━━━━━━  ━━━━━━━━━━━
   MoonTTL (MoonBit)     1.76 ms       568,612          0.0018 ms
  ────────────────────  ────────────  ───────────────  ───────────
   Oxigraph (Rust)       2.00 ms       500,000          0.0020 ms
  ────────────────────  ────────────  ───────────────  ───────────
   rdflib (Python)       17.89 ms      55,900           0.0179 ms
  ────────────────────  ────────────  ───────────────  ───────────
   Apache Jena (Java)    2,734 ms      36,576           0.0273 ms
  ────────────────────  ────────────  ───────────────  ───────────
   no-brain-scan (C)     0.16 ms       6,250,000        0.0002 ms

  ### MoonTTL Performance Analysis

  === MoonBit Parsing test_1000.nq ===
  File: test_1000.nq
  File size: 103670 bytes

  === Performance Data ===
  Lexer:       515.532 µs (5000 tokens)
  ParserE:     575.14 µs (1000 quads)
  Validation:  1448.353 µs (1000 quads, 0 errors)
  Materialize: 310.314 µs (1000 quads, 0 errors)

  === Total ===
  Total time:      1.76 ms
  Quad count:      1000
  Parses/sec:      568,612
  Time/quad:       0.0018 ms


  ### Running Benchmark Tests

  ```bash
  cd src/benchmark
  ./run_all.sh
  ```
  ### Performance Optimization Features

  - Zero-copy design: Lexer uses byte array slices to avoid unnecessary memory allocation
  - State machine driven: Uses finite state machine for syntax parsing, ensuring O(n) time complexity
  - Lookahead parsing: Lookahead 5 tokens at once to reduce function call overhead
  - Batch materialization: Validation and materialization are separated, supporting batch processing
  - Error recovery: Automatically skips the current line on error, continuing to parse subsequent content

## Contributing Guidelines

Contributions of code, bug reports, and suggestions are welcome!

1. Fork the repository
2. Create your feature branch (git checkout -b feature/amazing-feature)
3. Commit your changes (git commit -m 'Add some amazing feature')
4. Push to the branch (git push origin feature/amazing-feature)
5. Open a Pull Request

## Development Environment Setup

# Clone the repository
git clone https://github.com/thy1016/moonttl.git
cd moonttl

# Install dependencies
moon update

# Run tests
moon test

# Build the project
moon build

## License

This project is licensed under:

- Apache License, Version 2.0 (../LICENSE-APACHE or
  http://www.apache.org/licenses/LICENSE-2.0 (http://www.apache.org/licenses/LICENSE-2.0))

You may choose which license to use.

## Contributions

Unless you indicate otherwise, any contributions you intentionally submit for inclusion in MoonTTL (as defined
under the Apache-2.0 license) shall be dual-licensed as above, without any additional terms or conditions.

## Acknowledgments

- Oxttl (https://github.com/vandalsoul/oxttl) - Excellent RDF library in the Rust ecosystem, providing important
  design references for this project

- W3C RDF Tests Community Group (https://github.com/w3c/rdf-tests) - Providing standard test cases
- MoonBit (https://moonbitlang.cn/) - Providing excellent programming language and toolchain

## Related Links

- RDF 1.2 Specification (https://www.w3.org/TR/rdf12-concepts/)
- N-Quads Specification (https://www.w3.org/TR/n-quads/)
- Turtle Specification (https://www.w3.org/TR/turtle/)
- MoonBit Documentation (https://docs.moonbitlang.com)


