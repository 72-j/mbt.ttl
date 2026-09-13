# MoonTTL

MoonTTL is a high-performance RDF parsing and serialization library written in the MoonBit language. This project
is inspired by the excellent Oxttl library from the Rust ecosystem, aiming to provide a standardized, lightweight
semantic web data processing engine for the MoonBit ecosystem.


## Features

- **Multi-format Support**: Complete support for parsing and serialization of Turtle, TriG, N-Triples, N-Quads
and N3. Three dialects are shipped today: **N-Quads/N-Triples** (`gen_nquads`), **TriG/Turtle**
(`gen_trig`, Turtle enforced by a runtime dialect switch) and **N3** (`gen_n3v2`: formulas, rules,
operator predicates, collections, property lists).
- **RDF 1.2 Compatible**: Fully compliant with the latest RDF 1.2 international standard specification;
each dialect carries a syntax-version switch (`rdf12`: scalar-only escapes + directional language tags
`--ltr/--rtl`; the 1.1 side is opted out explicitly).
- **High Performance**: State-machine based lexer design. Dual lexers (MoonBit `Lexermoon` / C FFI `Lexerc`)
share one token alphabet and are pinned token-by-token (parity batteries); layered benchmarks cover
lexing / conversion / state machine / full engine.
- **Generator discipline**: all three dialects are generated from table/TOML data (the generated contract is
Trait / enum / Context wired through Actions / EffectHandler / Supervisor); generated `*.mbt` files are
never hand-edited and are protected by byte-for-byte golden gates.
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

```
src/
├── gen_nquads/       # N-Quads / N-Triples parser (generated contract + user layer; lexers, materializer, serializer, suites)
├── gen_trig/         # TriG / Turtle parser (same layout; TriG superset + Turtle dialect switch)
├── gen_n3v2/         # N3 parser (same layout; formulas, rules, quantification, paths, @keywords)
├── cmd/main/         # Command line tool (`moon run src/cmd/main -- <file>`)
├── examples/         # Runnable examples for the three dialects: nquads / trig / n3
├── benchmark/        # Benchmark programs
└── quick_machine/    # Quick machine (table-driven model-execution cross-check)
```

Each dialect package carries the same five-volume documentation set (`const.md` red lines /
`spec.md` structural facts / `adr.md` decisions / `todo.md` roadmap / `ctx.md` working context;
`gen_n3v2` additionally ships a one-page `ARCHITECTURE.md`). The generation surface lives in the
outer repository under `src/rdf` and `src/fsm`.

## Example Programs

### Parse N-Quads File

Run the example program:

moon run src/examples/nquads

Sample output:

```text
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

- Creating N-Quads content from strings and writing to a file
- Reading from a file and parsing as binary data
- Using lexer and state machine to parse RDF quads
- Error handling and result summarization

### Parse TriG Files (graph blocks / GRAPH / Turtle dialect)

```bash
moon run src/examples/trig
```

Eight cases cover: default graph basics, `@prefix` / `@base`, named graphs and the `GRAPH` keyword,
collections with nesting, relative IRIs resolved against the base, the **Turtle dialect** (graph
blocks rejected), serializer knobs (Strict / Drop) and `@`-style directives. Pipeline:
`TrigEngine::from_bytes` → `TrigSliceParser` → `TrigMaterializer` → `TrigSerializer`.

### Parse N3 Files (formulas / rules / operators / `@keywords`)

```bash
moon run src/examples/n3
```

Six cases cover: plain triples, `@prefix` + `@base`, **formulas `{ ... }` with rules `=>`**,
**collections `( ... )` and property lists `[ ... ]`** (fresh `_:genid*` nodes),
**operator predicates `=>` / `<=` / `=`**, and `@keywords a .` with `a` → `rdf:type`. Pipeline:
`N3Engine::from_bytes` → `N3SliceParser` → `N3Materializer` → `N3Serializer`.

### Tests and Verification

```bash
moon test                     # whole module: 330/330
moon test src/gen_nquads      # 124/124 (W3C N-Quads 89/89, rdf12-nt 29/29, rdf12-nq 27/27, ntriples 72/72)
moon test src/gen_trig        # 80/80 (rdf-trig 357/357, rdf-turtle 316/316, rdf12 36/36 + 75/75)
moon test src/gen_n3v2        # 117/117 (turtle 316/316, rdf12 75/75, N3Tests neg 23ok/0miss + pos+eval 205 clean)
```

Every dialect's **generated artifact** (`nquads.mbt` / `trig.mbt` / `n3.mbt`) is protected by a golden
gate: the banner timestamp is pinned, the regenerated code is formatted with the toolchain `moon fmt`
and must match the checked-in artifact **byte for byte**, repeatedly (`n3.mbt` is guarded by the G9
gate of `src/rdf/n3gen`).

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
  N-Quads (sections)        89       89        ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  N-Triples (file loop)     72       72        ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  rdf12-nt / rdf12-nq       29 / 27  29 / 27   ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  TriG / Turtle             357/316  357/316   ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  rdf12-trig / -turtle      36 / 75  36 / 75   ✅ All Passed
────────────────────────  ───────  ────────  ───────────────
  N3Tests (neg / pos+eval)  23ok / 205clean  23ok / 205clean  ✅ All Passed

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
  - Lookahead parsing: reduce function call overhead
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
