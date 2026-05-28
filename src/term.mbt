///|
// pub enum NamedOrBlankNodeRef {
//   NamedNodeRef(NamedNodeRef)
//   BlankNodeRef(BlankNodeRef)
// }

///|
// pub fn NamedOrBlankNodeRef::is_named_node(self : NamedOrBlankNodeRef) -> Bool {
//   match self {
//     NamedOrBlankNodeRef::NamedNodeRef(_) => true
//     NamedOrBlankNodeRef::BlankNodeRef(_) => false
//   }
// }

///|
// pub fn NamedOrBlankNodeRef::is_blank_node(self : NamedOrBlankNodeRef) -> Bool {
//   match self {
//     NamedOrBlankNodeRef::NamedNodeRef(_) => false
//     NamedOrBlankNodeRef::BlankNodeRef(_) => true
//   }
// }

///|
pub fn NamedOrBlankNodeRef::into_owned(
  self : NamedOrBlankNodeRef,
) -> NamedOrBlankNode {
  match self {
    NamedOrBlankNodeRef::NamedNode(node) =>
      NamedOrBlankNode::NamedNode(node.into_owned())
    NamedOrBlankNodeRef::BlankNode(node) => NamedOrBlankNode::BlankNode(node)
  }
}

///|
pub(all) enum NamedOrBlankNode {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
} derive(Debug,Eq,Hash)

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
pub fn NamedOrBlankNode::as_ref(self : NamedOrBlankNode) -> NamedOrBlankNodeRef {
  match self {
    NamedOrBlankNode::NamedNode(node) =>
      NamedOrBlankNode::NamedNode(node.as_ref())
    NamedOrBlankNode::BlankNode(node) =>
      NamedOrBlankNode::BlankNode(node.as_ref())
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
// pub(all) struct NamedNodeRef {
//   iri : StringView
// } derive(Debug, Eq, Hash)

// impl Show for NamedNodeRef with to_string(self : NamedNodeRef) -> String {
//   self.iri.to_owned()
// }

///|
// fn NamedNodeRef::NamedNodeRef(iri : StringView) -> NamedNodeRef {
//   NamedNodeRef::{ iri, }
// }

///|
pub fn NamedNodeRef::new_unchecked(iri : StringView) -> NamedNodeRef {
  NamedNode::NamedNode(iri.to_owned())
}

///|
pub fn NamedNode::NamedNode(iri : String) -> NamedNode {
  NamedNode::{ iri, }
}
// pub fn NamedNode::new_unchecked(iri : String) -> NamedNode {
// NamedNode::NamedNode(iri)
// }

///|
pub fn NamedNodeRef::into_owned(self : NamedNodeRef) -> NamedNode {
  NamedNode::NamedNode(self.iri)
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
pub(all) enum BlankNode {
  Named(String)
  Anonymous(Anonymous)
} derive(Debug,Eq,Hash)

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
} derive(Debug,Eq,Hash)

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
} derive(Debug,Eq,Hash)

///|
pub fn GraphName::into_owned(self : GraphName) -> GraphName {
  self
}
pub fn GraphName::new_unchecked(value : String) -> GraphName {
  DefaultGraph
}
///|

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
// pub struct QuadRef {
//   subject : NamedOrBlankNodeRef
//   predicate : NamedNodeRef
//   object : TermRef
//   graph_name : GraphNameRef
// }

///|
// pub fn QuadRef::new(
//   subject : NamedOrBlankNodeRef,
//   predicate : NamedNodeRef,
//   object : TermRef,
//   graph_name : GraphNameRef,
// ) -> QuadRef {
//   { subject, predicate, object, graph_name }
// }

///|
pub fn QuadRef::into_owned(self : QuadRef) -> Quad {
  {
    subject: self.subject,
    predicate: self.predicate.into_owned(),
    object: self.object,
    graph_name: self.graph_name.into_owned(),
  }
}

///|
pub(all) enum Term {
  NamedNode(NamedNode)
  BlankNode(BlankNode)
  Literal(Literal)
  Triple(Triple)
} derive(Debug,Eq,Hash)

///|
// pub(all) enum TermRef {
//   NamedNodeRef(NamedNodeRef)
//   BlankNodeRef(BlankNodeRef)
//   LiteralRef(LiteralRef)
//   TripleRef(TripleRef)
// } derive(Debug,Eq,Hash)

///|
// pub fn TermRef::into_owned(self : TermRef) -> Term {
//   match self {
//     TermRef::NamedNodeRef(v) => Term::NamedNode(v)
//     TermRef::BlankNodeRef(v) => Term::BlankNode(v)
//     TermRef::LiteralRef(v) => Term::Literal(v.into_owned())
//     TermRef::Triple(v) => Term::Triple(v)
//   }
// }

// type LiteralRef = Literal
// pub struct Literal {
//   value : String
// }derive(Debug)
// pub fn Literal::Literal(value : String) -> Literal {
//   Literal::{value}
// }
