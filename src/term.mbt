///|
pub enum NamedOrBlankNodeRef {
  NamedNodeRef(NamedNodeRef)
  BlankNodeRef(BlankNodeRef)
} derive(Debug, Eq, Hash)

///|
impl Show for NamedOrBlankNodeRef with fn output(
  self : NamedOrBlankNodeRef,
  f : &Logger,
) -> Unit {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(v) => f.write_string(v.iri.to_owned())
    NamedOrBlankNodeRef::BlankNodeRef(v) =>
      match v {
        BlankNodeRef::Named(v) => f.write_string(v.to_owned())
        BlankNodeRef::Anonymous(v) => f.write_string(v.str)
      }
  }
}

///|
pub fn NamedOrBlankNodeRef::is_named_node(self : NamedOrBlankNodeRef) -> Bool {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(_) => true
    NamedOrBlankNodeRef::BlankNodeRef(_) => false
  }
}

///|
pub fn NamedOrBlankNodeRef::is_blank_node(self : NamedOrBlankNodeRef) -> Bool {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(_) => false
    NamedOrBlankNodeRef::BlankNodeRef(_) => true
  }
}

///|
pub fn NamedOrBlankNodeRef::into_owned(
  self : NamedOrBlankNodeRef,
) -> NamedOrBlankNode {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(node) =>
      NamedOrBlankNode::NamedNode(node.into_owned())
    NamedOrBlankNodeRef::BlankNodeRef(node) =>
      NamedOrBlankNode::BlankNode(node.into_owned())
  }
}

///|
pub fn NamedOrBlankNodeRef::into_graph(
  self : NamedOrBlankNodeRef,
) -> GraphNameRef {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(v) => GraphNameRef::NamedNodeRef(v)
    NamedOrBlankNodeRef::BlankNodeRef(v) => GraphNameRef::BlankNodeRef(v)
  }
}

///|
pub fn NamedOrBlankNodeRef::as_term(self : NamedOrBlankNodeRef) -> TermRef {
  match self {
    NamedOrBlankNodeRef::NamedNodeRef(v) => TermRef::NamedNodeRef(v)
    NamedOrBlankNodeRef::BlankNodeRef(v) => TermRef::BlankNodeRef(v)
  }
}

///|
pub(all) enum NamedOrBlankNode {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
} derive(Debug, Eq, Hash, ToJson)

///|
pub fn NamedOrBlankNode::as_ref(self : NamedOrBlankNode) -> NamedOrBlankNodeRef {
  match self {
    NamedOrBlankNode::NamedNode(node) =>
      NamedOrBlankNodeRef::NamedNodeRef(node.as_ref())
    NamedOrBlankNode::BlankNode(node) =>
      NamedOrBlankNodeRef::BlankNodeRef(node.as_ref())
  }
}

///|
pub fn NamedOrBlankNode::is_named_node(self : NamedOrBlankNode) -> Bool {
  self.is_named_node()
}

///|
pub fn NamedOrBlankNode::is_blank_node(self : NamedOrBlankNode) -> Bool {
  self.is_blank_node()
}

///|
pub impl Show for NamedOrBlankNode with fn output(
  self : NamedOrBlankNode,
  f : &Logger,
) -> Unit {
  match self {
    NamedOrBlankNode::NamedNode(v) => f.write_string(v.iri)
    NamedOrBlankNode::BlankNode(v) =>
      match v {
        BlankNode::Named(v) =>
          // f.write("_:")
          f.write(v)
        BlankNode::Anonymous(v) => f.write_string(v.str)
      }
  }
}

///|
pub(all) struct NamedNode {
  iri : String
} derive(Debug, Eq, Hash, Default, ToJson)

///|
impl Show for NamedNode with fn to_string(self : NamedNode) -> String {
  self.iri
}

///|
fn NamedNode::NamedNode(iri : String) -> NamedNode {
  NamedNode::{ iri, }
}

///|
pub fn NamedNode::as_term(self : NamedNode) -> Term {
  Term::NamedNode(self)
}

///|
pub(all) struct NamedNodeRef {
  iri : StringView
} derive(Debug, Eq, Hash)

///|
pub fn NamedNodeRef::as_term(self : NamedNodeRef) -> TermRef {
  TermRef::NamedNodeRef(self)
}

///|
pub fn NamedNodeRef::as_enum(self : NamedNodeRef) -> NamedOrBlankNodeRef {
  NamedOrBlankNodeRef::NamedNodeRef(self)
}

///|
pub impl Show for NamedNodeRef with fn to_string(self : NamedNodeRef) -> String {
  self.iri.to_owned()
}

///|
pub fn NamedNodeRef::NamedNodeRef(iri : StringView) -> NamedNodeRef {
  NamedNodeRef::{ iri, }
}

///|
pub fn NamedNodeRef::new_unchecked(iri : StringView) -> NamedNodeRef {
  NamedNodeRef::NamedNodeRef(iri)
}

///|
pub fn NamedNodeRef::into_owned(self : NamedNodeRef) -> NamedNode {
  NamedNode::NamedNode(self.iri.to_owned())
}

///|
pub fn NamedNode::as_ref(self : NamedNode) -> NamedNodeRef {
  NamedNodeRef::{ iri: self.iri }
}

///|
pub fn NamedNodeRef::into_datatype(
  self : NamedNodeRef,
  value : String,
) -> VarDataType {
  if self == lwINT {
    let parsed = try @string.parse_int(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => IntVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwINTEGER {
    let parsed = try @string.parse_int64(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => IntegerVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwFLOAT {
    let parsed = try @string.parse_double(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => DoubleVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwDECIMAL {
    let parsed = try @string.parse_double(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => DecimalVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwDATE {
    let parsed = parse_xsd_date(value)
    match parsed {
      Ok(v) => DateVar(v)
      Err(_) => StringVar("NAN")
    }
  } else if self == lwTIME {
    let parsed = try @tempo.Time::parse(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => TimeVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwDATE_TIME {
    let parsed = try @tempo.DateTime::parse(value) |> Ok catch {
      e => Err(e)
    }
    match parsed {
      Ok(v) => DateTimeVar(v.to_string())
      Err(_) => StringVar("NAN")
    }
  } else if self == lwDURATION {
    match parse_duration(value) {
      Ok(v) => DurationVar(v)
      Err(_) => StringVar("NAN")
    }
  } else {
    StringVar(value)
  }
}

///|
pub fn NamedNode::as_enum(self : NamedNode) -> NamedOrBlankNode {
  NamedOrBlankNode::NamedNode(self)
}

// pub(all) struct BlankNode(BlankNodeContent)

///|
pub(all) enum BlankNodeRef {
  Named(StringView)
  Anonymous(Anonymous)
} derive(Debug, Eq, Hash)

///|
impl Show for BlankNodeRef with fn to_string(self : BlankNodeRef) -> String {
  match self {
    BlankNodeRef::Named(v) => v.to_owned()
    BlankNodeRef::Anonymous(v) => v.str
  }
}

///|
pub fn BlankNodeRef::default() -> BlankNodeRef {
  BlankNodeRef::Named("_:default")
}

///|
pub fn BlankNodeRef::as_enum(self : BlankNodeRef) -> NamedOrBlankNodeRef {
  NamedOrBlankNodeRef::BlankNodeRef(self)
}

///|
pub fn BlankNodeRef::as_term(self : BlankNodeRef) -> TermRef {
  TermRef::BlankNodeRef(self)
}

///|
fn BlankNodeRef::into_owned(node : BlankNodeRef) -> BlankNode {
  match node {
    BlankNodeRef::Named(v) => BlankNode::Named(v.to_owned())
    BlankNodeRef::Anonymous(v) => BlankNode::new_from_unique_id(v.id)
  }
}

///|
pub fn BlankNodeRef::new_unchecked(iri : String) -> BlankNodeRef {
  BlankNodeRef::Named(iri)
}

///|
pub(all) enum BlankNode {
  Named(String)
  Anonymous(Anonymous)
} derive(Debug, Eq, Hash, ToJson)

///|
impl Show for BlankNode with fn to_string(self : BlankNode) -> String {
  match self {
    BlankNode::Named(v) => "_:\{v}"
    BlankNode::Anonymous(v) => v.str
  }
}

///|
pub fn BlankNode::default() -> BlankNode {
  BlankNode::Named("_:default")
}

///|
pub fn BlankNode::new(content : BlankNode) -> BlankNode {
  match content {
    BlankNode::Named(v) => BlankNode::Named(v)
    BlankNode::Anonymous(anon) => BlankNode::new_from_unique_id(anon.id)
  }
}

///|
pub fn BlankNode::as_ref(self : BlankNode) -> BlankNodeRef {
  match self {
    BlankNode::Named(v) => BlankNodeRef::Named(v)
    BlankNode::Anonymous(v) => BlankNodeRef::Anonymous(v)
  }
}

///|
pub fn BlankNode::as_enum(self : BlankNode) -> NamedOrBlankNode {
  NamedOrBlankNode::BlankNode(self)
}

///|
pub fn BlankNode::new_from_unique_id(id : UInt64) -> BlankNode {
  BlankNode::Anonymous(Anonymous::Anonymous(id, id.to_string()))
}

///|
pub(all) struct Anonymous {
  id : UInt64
  str : String
} derive(Debug, Eq, Hash, ToJson)

///|
pub fn Anonymous::default() -> Anonymous {
  Anonymous(0, "_:default".to_string())
}

///|
pub fn Anonymous::Anonymous(id : UInt64, str : String) -> Anonymous {
  Anonymous(id, str)
}

///|
pub(all) enum GraphName {
  DefaultGraph
  NamedNode(NamedNode)
  BlankNode(BlankNode)
} derive(Debug, Eq, Hash, ToJson)

///|
impl Show for GraphName with fn to_string(self : GraphName) -> String {
  match self {
    GraphName::DefaultGraph => "".to_string()
    GraphName::NamedNode(v) => v.to_string()
    GraphName::BlankNode(v) => v.to_string()
  }
}

///|
pub fn GraphName::into_owned(self : GraphName) -> GraphName {
  self
}

///|
pub fn GraphName::default() -> GraphName {
  DefaultGraph
}

///|
pub fn GraphName::is_named_node(self : GraphName) -> Bool {
  self.is_named_node()
}

///|
pub fn GraphName::is_blank_node(self : GraphName) -> Bool {
  self.is_blank_node()
}

///|
pub fn GraphName::is_default_graph(self : GraphName) -> Bool {
  match self {
    GraphName::BlankNode(_) => true
    GraphName::DefaultGraph => true
    _ => false
  }
}

///|
pub fn GraphName::as_ref(self : GraphName) -> GraphNameRef {
  match self {
    GraphName::NamedNode(node) => GraphNameRef::NamedNodeRef(node.as_ref())
    GraphName::BlankNode(node) => GraphNameRef::BlankNodeRef(node.as_ref())
    GraphName::DefaultGraph => GraphNameRef::DefaultGraph
  }
}

///|
pub(all) enum GraphNameRef {
  DefaultGraph
  NamedNodeRef(NamedNodeRef)
  BlankNodeRef(BlankNodeRef)
} derive(Debug, Eq, Hash)

///|
impl Show for GraphNameRef with fn to_string(self : GraphNameRef) -> String {
  match self {
    GraphNameRef::DefaultGraph => "".to_string()
    GraphNameRef::NamedNodeRef(v) => v.to_string()
    GraphNameRef::BlankNodeRef(v) => v.to_string()
  }
}

///|
fn GraphNameRef::new_unchecked(iri : String) -> GraphNameRef {
  GraphNameRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri))
}

///|
fn GraphNameRef::into_owned(graph_name : GraphNameRef) -> GraphName {
  match graph_name {
    GraphNameRef::DefaultGraph => GraphName::DefaultGraph
    GraphNameRef::NamedNodeRef(v) => GraphName::NamedNode(v.into_owned())
    GraphNameRef::BlankNodeRef(v) => GraphName::BlankNode(v.into_owned())
  }
}

///|
pub struct Quad {
  subject : NamedOrBlankNode
  predicate : NamedNode
  object : Term
  graph_name : GraphName
} derive(Debug, Hash, Eq, ToJson)

///|
impl Show for Quad with fn output(self : Quad, logger : &Logger) -> Unit {
  // logger.write(@debug.to_string(self))
  logger.write("Quad")
  logger.write(" {")
  logger.write(" subject: ")
  logger.write(self.subject)
  logger.write(", ")
  logger.write(" predicate: ")
  logger.write(self.predicate)
  logger.write(", ")
  logger.write(" object: ")
  logger.write(self.object)
  if !self.graph_name.is_default_graph() {
    logger.write(", ")
    logger.write(" graph_name: ")
    logger.write(self.graph_name.to_string())
  }
  logger.write(" }")
}

///|
pub fn Quad::Quad(
  subject : NamedOrBlankNode,
  predicate : NamedNode,
  object : Term,
  graph_name : GraphName,
) -> Quad {
  { subject, predicate, object, graph_name }
}

///|
pub struct QuadRef {
  subject : NamedOrBlankNodeRef
  predicate : NamedNodeRef
  object : TermRef
  graph_name : GraphNameRef
}

///|
pub fn QuadRef::into_owned(self : QuadRef) -> Quad {
  {
    subject: self.subject.into_owned(),
    predicate: self.predicate.into_owned(),
    object: self.object.into_owned(),
    graph_name: self.graph_name.into_owned(),
  }
}

///|
pub fn Quad::as_ref(self : Quad) -> QuadRef {
  {
    subject: self.subject.as_ref(),
    predicate: self.predicate.as_ref(),
    object: self.object.as_ref(),
    graph_name: self.graph_name.as_ref(),
  }
}

///|
pub(all) enum Term {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
  Literal(Literal)
  Triple(Triple)
} derive(Debug, Eq, Hash, ToJson)

///|
impl Show for Term with fn output(self : Term, logger : &Logger) -> Unit {
  match self {
    Term::NamedNode(n) => logger.write(n)
    Term::BlankNode(b) =>
      match b {
        BlankNode::Named(v) =>
          // logger.write("_:")
          logger.write(v)
        BlankNode::Anonymous(v) => logger.write(v.str)
      }
    Term::Literal(l) => l.output(logger)
    Term::Triple(t) => t.output(logger)
  }
}

///|
pub fn Term::is_named_node(self : Term) -> Bool {
  self.is_named_node()
}

///|
pub fn Term::is_blank_node(self : Term) -> Bool {
  self.is_blank_node()
}

///|
pub fn Term::is_literal(self : Term) -> Bool {
  self.is_literal()
}

///|
pub fn Term::is_triple(self : Term) -> Bool {
  self.is_triple()
}

///|
pub fn Term::as_ref(self : Term) -> TermRef {
  match self {
    Term::NamedNode(node) => TermRef::NamedNodeRef(node.as_ref())
    Term::BlankNode(node) => TermRef::BlankNodeRef(node.as_ref())
    Term::Literal(literal) => TermRef::LiteralRef(literal.as_ref())
    Term::Triple(triple) => TermRef::TripleRef(triple.as_ref())
  }
}

///|
pub(all) enum TermRef {
  NamedNodeRef(NamedNodeRef)
  BlankNodeRef(BlankNodeRef)
  LiteralRef(LiteralRef)
  TripleRef(TripleRef)
} derive(Debug, Eq, Hash)

///|
impl Show for TermRef with fn output(self : TermRef, logger : &Logger) -> Unit {
  match self {
    TermRef::NamedNodeRef(v) => logger.write(v.to_string())
    TermRef::BlankNodeRef(b) =>
      match b {
        BlankNodeRef::Named(v) =>
          // logger.write("_:")
          logger.write(v)
        BlankNodeRef::Anonymous(v) => logger.write(v.str)
      }
    TermRef::LiteralRef(v) => logger.write(v.to_string())
    TermRef::TripleRef(v) => logger.write(v)
  }
}

///|
pub fn TermRef::into_owned(self : TermRef) -> Term {
  match self {
    TermRef::NamedNodeRef(v) => Term::NamedNode(v.into_owned())
    TermRef::BlankNodeRef(v) => Term::BlankNode(v.into_owned())
    TermRef::LiteralRef(v) => Term::Literal(v.into_owned())
    TermRef::TripleRef(v) => Term::Triple(v.into_owned())
  }
}

///|
pub struct TryFromTermError {
  term : Term
  target : String
} derive(Debug)

///|
pub fn TryFromTermError::TryFromTermError(
  term : Term,
  target : String,
) -> TryFromTermError {
  TryFromTermError::{ term, target }
}

///|
pub fn TryFromTermError::as_term(self : TryFromTermError) -> Term {
  self.term
}
