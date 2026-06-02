///|
pub enum NamedOrBlankNodeRef {
  NamedNodeRef(NamedNodeRef)
  BlankNodeRef(BlankNodeRef)
} derive(Debug, Eq, Hash)

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
pub(all) enum NamedOrBlankNode {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
} derive(Debug, Eq, Hash)

// pub fn[T] NamedOrBlankNode::from(node : T) -> NamedOrBlankNode {
//   match node {
//     NamedNode::NamedNode(node) => NamedOrBlankNode::NamedNode(node)
//     BlankNode::BlankNode(node) => NamedOrBlankNode::BlankNode(node)
//   }
// }

///|
pub fn NamedOrBlankNode::into_enum(self : NamedOrBlankNode) -> GraphName {
  match self {
    NamedOrBlankNode::NamedNode(v) => GraphName::NamedNode(v)
    NamedOrBlankNode::BlankNode(v) => GraphName::BlankNode(v)
  }
}

///|
pub fn NamedOrBlankNode::as_ref(
  self : NamedOrBlankNode,
) -> NamedOrBlankNodeRef {
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
        BlankNode::Named(v) => f.write_string(v)
        BlankNode::Anonymous(v) => f.write_string(v.str)
      }
  }
}

///|
pub(all) struct NamedNode {
  iri : String
} derive(Debug, Eq, Hash)

///|
impl Show for NamedNode with fn to_string(self : NamedNode) -> String {
  self.iri
}

///|
fn NamedNode::NamedNode(iri : String) -> NamedNode {
  NamedNode::{ iri, }
}

///|
pub fn NamedNode::new_unchecked(iri : String) -> NamedNode {
  NamedNode::NamedNode(iri)
}

///|
pub(all) struct NamedNodeRef {
  iri : StringView
} derive(Debug, Eq, Hash)

///|
impl Show for NamedNodeRef with fn to_string(self : NamedNodeRef) -> String {
  self.iri.to_owned()
}

///|
// fn NamedNodeRef::NamedNodeRef(iri : StringView) -> NamedNodeRef {
//   NamedNodeRef::{ iri, }
// }

///|
// pub fn NamedNodeRef::new_unchecked(iri : StringView) -> NamedNodeRef {
//   NamedNodeRef::NamedNodeRef(iri)
// }

///|
pub fn NamedNodeRef::into_owned(self : NamedNodeRef) -> NamedNode {
  NamedNode::NamedNode(self.iri.to_owned())
}

///|
pub fn NamedNode::as_ref(self : NamedNode) -> NamedNodeRef {
  NamedNodeRef::{ iri: self.iri }
}

///|
pub fn NamedNode::into_enum(self : NamedNode) -> NamedOrBlankNode {
  NamedOrBlankNode::NamedNode(self)
}

// pub(all) struct BlankNode(BlankNodeContent)

///|
pub(all) enum BlankNodeRef {
  Named(StringView)
  Anonymous(Anonymous)
} derive(Debug, Eq, Hash)

///|
fn BlankNodeRef::into_owned(node : BlankNodeRef) -> BlankNode {
  match node {
    BlankNodeRef::Named(v) => BlankNode::Named(v.to_owned())
    BlankNodeRef::Anonymous(v) => BlankNode::new_from_unique_id(v.id)
  }
}

///|
pub(all) enum BlankNode {
  Named(String)
  Anonymous(Anonymous)
} derive(Debug, Eq, Hash)

///|
pub fn BlankNode::default() -> BlankNode {
  BlankNode::new(BlankNode::Named("_:default"))
}

///|
pub fn BlankNode::new(content : BlankNode) -> BlankNode {
  match content {
    BlankNode::Named(v) => BlankNode::new_unchecked(v)
    BlankNode::Anonymous(anon) => BlankNode::new_from_unique_id(anon.id)
  }
}

///|
pub fn BlankNode::new_unchecked(iri : String) -> BlankNode {
  BlankNode::Named(iri)
}

///|
pub fn BlankNode::as_ref(self : BlankNode) -> BlankNodeRef {
  match self {
    BlankNode::Named(v) => BlankNodeRef::Named(v)
    BlankNode::Anonymous(v) => BlankNodeRef::Anonymous(v)
  }
}

///|
pub fn BlankNode::new_from_unique_id(id : UInt64) -> BlankNode {
  BlankNode::Anonymous(Anonymous::Anonymous(id, id.to_string()))
}

///|
pub(all) struct Anonymous {
  id : UInt64
  str : String
} derive(Debug, Eq, Hash)

///|
pub fn Anonymous::Anonymous(id : UInt64, str : String) -> Anonymous {
  Anonymous(id, str)
}
// type Triple

///|
pub(all) enum GraphName {
  DefaultGraph
  NamedNode(NamedNode)
  BlankNode(BlankNode)
} derive(Debug, Eq, Hash)

///|
pub fn GraphName::into_owned(self : GraphName) -> GraphName {
  self
}

///|
pub fn GraphName::default() -> GraphName {
  DefaultGraph
}

///|
fn GraphName::new_unchecked(iri : String) -> GraphName {
  GraphName::NamedNode(NamedNode::new_unchecked(iri))
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
  self.is_default_graph()
}

///|
pub fn GraphName::as_ref(self : GraphName) -> GraphNameRef {
  match self {
    GraphName::NamedNode(node) =>
      GraphNameRef::NamedNodeRef(node.as_ref())
    GraphName::BlankNode(node) =>
      GraphNameRef::BlankNodeRef(node.as_ref())
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
pub fn QuadRef::new(
  subject : NamedOrBlankNodeRef,
  predicate : NamedNodeRef,
  object : TermRef,
  graph_name : GraphNameRef,
) -> QuadRef {
  { subject, predicate, object, graph_name }
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
pub fn Quad::new(
  subject : NamedOrBlankNode,
  predicate : NamedNode,
  object : Term,
  graph_name : GraphName,
) -> Quad {
  { subject, predicate, object, graph_name }
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
} derive(Debug, Eq, Hash)

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
pub fn TryFromTermError::into_term(self : TryFromTermError) -> Term {
  self.term
}
