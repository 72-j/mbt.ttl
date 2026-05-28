// pub enum NamedOrBlankNode {
//   NamedNode(NamedNode)
//   BlankNode(BlankNode)
// } derive(Eq, Debug, Hash)
// pub fn NamedOrBlankNode::is_named_node(self : NamedOrBlankNode) -> Bool {
//   self.is_named_node()
// }
// pub fn NamedOrBlankNode::is_blank_node(self : NamedOrBlankNode) -> Bool {
//   self.is_blank_node()
// }
// pub fn NamedOrBlankNode::as_ref(self : NamedOrBlankNode) -> NamedOrBlankNodeRef {
//   match self {
//     NamedOrBlankNode::NamedNode(node) => NamedOrBlankNodeRef::NamedNode(node)
//     NamedOrBlankNode::BlankNode(node) => NamedOrBlankNodeRef::BlankNode(node)
//   }
// }

// impl fmt::Show for NamedOrBlankNode with fmt(self : NamedOrBlankNode, f : Formatter) -> Result {
//   self.fmt(f)
// }

// impl From for NamedOrBlankNode with from(self : NamedOrBlankNode, node : NamedNode) -> NamedOrBlankNode {
//   NamedOrBlankNode::NamedNode(node)
// }

// impl From for NamedOrBlankNode with from(self : NamedOrBlankNode, node : NamedNodeRef) -> NamedOrBlankNode {
//   node.into_owned().into()
// }

// impl From for NamedOrBlankNode with from(self : NamedOrBlankNode, node : BlankNode) -> NamedOrBlankNode {
//   NamedOrBlankNode::BlankNode(node)
// }

// impl From for NamedOrBlankNode with from(self : NamedOrBlankNode, node : BlankNodeRef) -> NamedOrBlankNode {
//   node.into_owned().into()
// }

// pub enum NamedOrBlankNodeRef {
//   NamedNode(NamedNodeRef)
//   BlankNode(BlankNodeRef)
// } derive(Eq, Show, Hash)
// pub fn NamedOrBlankNodeRef::is_named_node(self : NamedOrBlankNodeRef) -> Bool {
//   match self {
//     NamedOrBlankNodeRef::NamedNode(_) => true
//     NamedOrBlankNodeRef::BlankNode(_) => false
//   }
// }
// pub fn NamedOrBlankNodeRef::is_blank_node(self : NamedOrBlankNodeRef) -> Bool {
//   match self {
//     NamedOrBlankNodeRef::NamedNode(_) => false
//     NamedOrBlankNodeRef::BlankNode(_) => true
//   }
// }
// pub fn NamedOrBlankNodeRef::into_owned(self : NamedOrBlankNodeRef) -> NamedOrBlankNode {
//   match self {
//     NamedOrBlankNodeRef::NamedNode(node) => NamedOrBlankNode::NamedNode(node.into_owned())
//     NamedOrBlankNodeRef::BlankNode(node) => NamedOrBlankNode::BlankNode(node.into_owned())
//   }
// }

// impl fmt::Show for NamedOrBlankNodeRef with fmt(self : NamedOrBlankNodeRef, f : Formatter) -> Result {
//   match self {
//     NamedOrBlankNodeRef::NamedNode(node) => node.fmt(f)
//     NamedOrBlankNodeRef::BlankNode(node) => node.fmt(f)
//   }
// }

// impl From for NamedOrBlankNodeRef with from(self : NamedOrBlankNodeRef, node : NamedNodeRef) -> NamedOrBlankNodeRef {
//   NamedOrBlankNodeRef::NamedNode(node)
// }

// impl From for NamedOrBlankNodeRef with from(self : NamedOrBlankNodeRef, node : NamedNode) -> NamedOrBlankNodeRef {
//   node.into()
// }

// impl From for NamedOrBlankNodeRef with from(self : NamedOrBlankNodeRef, node : BlankNodeRef) -> NamedOrBlankNodeRef {
//   NamedOrBlankNodeRef::BlankNode(node)
// }

// impl From for NamedOrBlankNodeRef with from(self : NamedOrBlankNodeRef, node : BlankNode) -> NamedOrBlankNodeRef {
//   node.into()
// }

// impl From for NamedOrBlankNodeRef with from(self : NamedOrBlankNodeRef, node : NamedOrBlankNode) -> NamedOrBlankNodeRef {
//   node
// }

// impl From for NamedOrBlankNode with from(self : NamedOrBlankNode, node : NamedOrBlankNodeRef) -> NamedOrBlankNode {
//   node.into_owned()
// }

// pub enum Term {
//   NamedNode(NamedNode)
//   BlankNode(BlankNode)
//   Literal(Literal)
//   Triple(Triple)
// } derive(Eq, Show, Hash)
pub fn Term::is_named_node(self : Term) -> Bool {
  self.is_named_node()
}
pub fn Term::is_blank_node(self : Term) -> Bool {
  self.is_blank_node()
}
pub fn Term::is_literal(self : Term) -> Bool {
  self.is_literal()
}
pub fn Term::is_triple(self : Term) -> Bool {
  self.is_triple()
}
pub fn Term::as_ref(self : Term) -> TermRef {
  match self {
    Term::NamedNode(node) => Term::NamedNode(node.as_ref())
    Term::BlankNode(node) => Term::BlankNode(node.as_ref())
    Term::Literal(literal) => Term::Literal(literal)
    Term::Triple(triple) => Term::Triple(triple)
  }
}

// impl fmt::Show for Term with fmt(self : Term, f : Formatter) -> Result {
//   self.fmt(f)
// }

// impl From for Term with from(self : Term, node : NamedNode) -> Term {
//   Term::NamedNode(node)
// }

// impl From for Term with from(self : Term, node : NamedNodeRef) -> Term {
//   node.into_owned().into()
// }

// impl From for Term with from(self : Term, node : BlankNode) -> Term {
//   Term::BlankNode(node)
// }

// impl From for Term with from(self : Term, node : BlankNodeRef) -> Term {
//   node.into_owned().into()
// }

// impl From for Term with from(self : Term, literal : Literal) -> Term {
//   Term::Literal(literal)
// }

// impl From for Term with from(self : Term, literal : LiteralRef) -> Term {
//   literal.into_owned().into()
// }

// impl From for Term with from(self : Term, triple : Triple) -> Term {
//   Term::Triple(triple)
// }

// impl From for Term with from(self : Term, node : Triple) -> Term {
//   Term::Triple(node)
// }

// impl From for Term with from(self : Term, triple : TripleRef) -> Term {
//   triple.into_owned().into()
// }

// impl From for Term with from(self : Term, node : NamedOrBlankNode) -> Term {
//   match node {
//     NamedOrBlankNode::NamedNode(node) => node.into()
//     NamedOrBlankNode::BlankNode(node) => node.into()
//   }
// }

// impl From for Term with from(self : Term, node : NamedOrBlankNodeRef) -> Term {
//   node.into_owned().into()
// }

// impl TryFrom for NamedNode with try_from(self : NamedNode, term : Term) -> Result[NamedNode, Error] {
//   if term is Term::NamedNode(node) {
//     Ok(node)
//   } else {
//     Err({ term: term, target: "NamedNode" })
//   }
// }

// impl TryFrom for BlankNode with try_from(self : BlankNode, term : Term) -> Result[BlankNode, Error] {
//   if term is Term::BlankNode(node) {
//     Ok(node)
//   } else {
//     Err({ term: term, target: "BlankNode" })
//   }
// }

// impl TryFrom for Literal with try_from(self : Literal, term : Term) -> Result[Literal, Error] {
//   if term is Term::Literal(node) {
//     Ok(node)
//   } else {
//     Err({ term: term, target: "Literal" })
//   }
// }

// impl TryFrom for NamedOrBlankNode with try_from(self : NamedOrBlankNode, term : Term) -> Result[NamedOrBlankNode, Error] {
//   match term {
//     Term::NamedNode(term) => Ok(NamedOrBlankNode::NamedNode(term))
//     Term::BlankNode(term) => Ok(NamedOrBlankNode::BlankNode(term))
//     Term::Literal(_) => Err({ term: term, target: "NamedOrBlankNode" })
//     Term::Triple(_) => Err({ term: term, target: "Triple" })
//   }
// }

// pub enum TermRef {
//   NamedNode(NamedNodeRef)
//   BlankNode(BlankNodeRef)
//   Literal(LiteralRef)
//   Triple(Triple)
// } derive(Eq, Show, Hash)
// pub fn TermRef::is_named_node(self : TermRef) -> Bool {
//   self is TermRef :: NamedNodeRef (_)
// }
// pub fn TermRef::is_blank_node(self : TermRef) -> Bool {
//   self is TermRef :: BlankNodeRef (_)
// }
// pub fn TermRef::is_literal(self : TermRef) -> Bool {
//   self is TermRef :: LiteralRef (_)
// }
// pub fn TermRef::is_triple(self : TermRef) -> Bool {
//   self is TermRef :: TripleRef (_)
// }
// pub fn TermRef::into_owned(self : TermRef) -> Term {
//   match self {
//     TermRef::NamedNode(node) => Term::NamedNode(node.into_owned())
//     TermRef::BlankNode(node) => Term::BlankNode(node.into_owned())
//     TermRef::Literal(literal) => Term::Literal(literal.into_owned())
//     TermRef::Triple(triple) => Term::Triple(triple)
//   }
// }

// impl fmt::Show for TermRef with fmt(self : TermRef, f : Formatter) -> Result {
//   match self {
//     TermRef::NamedNode(node) => node.fmt(f)
//     TermRef::BlankNode(node) => node.fmt(f)
//     TermRef::Literal(literal) => literal.fmt(f)
//     TermRef::Triple(triple) =>     write(f , "<<( {triple} )>>")
//   }
// }

// impl From for TermRef with from(self : TermRef, node : NamedNodeRef) -> TermRef {
//   TermRef::NamedNode(node)
// }

// impl From for TermRef with from(self : TermRef, node : NamedNode) -> TermRef {
//   node.into()
// }

// impl From for TermRef with from(self : TermRef, node : BlankNodeRef) -> TermRef {
//   TermRef::BlankNode(node)
// }

// impl From for TermRef with from(self : TermRef, node : BlankNode) -> TermRef {
//   node.into()
// }

// impl From for TermRef with from(self : TermRef, literal : LiteralRef) -> TermRef {
//   TermRef::Literal(literal)
// }

// impl From for TermRef with from(self : TermRef, literal : Literal) -> TermRef {
//   literal.into()
// }

// impl From for TermRef with from(self : TermRef, node : Triple) -> TermRef {
//   TermRef::Triple(node)
// }

// impl From for TermRef with from(self : TermRef, node : NamedOrBlankNodeRef) -> TermRef {
//   match node {
//     NamedOrBlankNodeRef::NamedNode(node) => node.into()
//     NamedOrBlankNodeRef::BlankNode(node) => node.into()
//   }
// }

// impl From for TermRef with from(self : TermRef, node : NamedOrBlankNode) -> TermRef {
//   node.into()
// }

// impl From for TermRef with from(self : TermRef, node : Term) -> TermRef {
//   node
// }

// impl From for Term with from(self : Term, node : TermRef) -> Term {
//   node.into_owned()
// }

pub struct Triple {
  subject : NamedOrBlankNode
  predicate : NamedNode
  object : Term
} derive(Eq, Debug, Hash)
pub fn Triple::new(subject : NamedOrBlankNodeRef, predicate : NamedNodeRef, object : TermRef) -> Triple {
  { subject: subject, predicate: predicate, object: object }
}
pub fn Triple::from_terms(subject : NamedOrBlankNodeRef, predicate : NamedNodeRef, object : TermRef) -> Result[Triple, TryFromTermError] {
  Ok({ subject: subject, predicate: predicate, object: object })
}
pub fn Triple::in_graph(self : Triple, graph_name : GraphNameRef) -> Quad {
  { subject: self.subject, predicate: self.predicate, object: self.object, graph_name: graph_name }
}
pub fn Triple::as_ref(self : Triple) -> TripleRef {
  { subject: self.subject, predicate: self.predicate, object: self.object.as_ref(), }
}

// impl fmt::Show for Triple with fmt(self : Triple, f : Formatter) -> Result {
//   self.fmt(f)
// }

pub struct TripleRef {
  subject : NamedOrBlankNodeRef
  predicate : NamedNodeRef
  object : TermRef
} derive(Eq, Debug, Hash)
pub fn TripleRef::new(subject : NamedOrBlankNodeRef, predicate : NamedNodeRef, object : TermRef) -> TripleRef {
  { subject: subject, predicate: predicate, object: object }
}
pub fn TripleRef::in_graph(self : TripleRef, graph_name : GraphNameRef) -> QuadRef {
  { subject: self.subject, predicate: self.predicate, object: self.object, graph_name: graph_name }
}
pub fn TripleRef::into_owned(self : TripleRef) -> Triple {
  { subject: self.subject, predicate: self.predicate, object: self.object }
}

// impl fmt::Show for TripleRef with fmt(self : TripleRef, f : Formatter) -> Result {
//   write(f , "{} {} {}" , self . subject , self . predicate , self . object)
// }

// impl From for TripleRef with from(self : TripleRef, triple : Triple) -> TripleRef {
//   triple
// }

// impl From for Triple with from(self : Triple, triple : TripleRef) -> Triple {
//   triple.into_owned()
// }

// pub enum GraphName {
//   NamedNode(NamedNode)
//   BlankNode(BlankNode)
//   DefaultGraph
// } derive(Eq, Show, Hash, Default)
pub fn GraphName::is_named_node(self : GraphName) -> Bool {
  self.is_named_node()
}
pub fn GraphName::is_blank_node(self : GraphName) -> Bool {
  self.is_blank_node()
}
pub fn GraphName::is_default_graph(self : GraphName) -> Bool {
  self.is_default_graph()
}
pub fn GraphName::as_ref(self : GraphName) -> GraphNameRef {
  match self {
    GraphName::NamedNode(node) => GraphNameRef::NamedNode(node)
    GraphName::BlankNode(node) => GraphNameRef::BlankNode(node)
    GraphName::DefaultGraph => GraphNameRef::DefaultGraph
  }
}

// impl fmt::Show for GraphName with fmt(self : GraphName, f : Formatter) -> Result {
//   self.fmt(f)
// }

// impl From for GraphName with from(self : GraphName, node : NamedNode) -> GraphName {
//   GraphName::NamedNode(node)
// }

// impl From for GraphName with from(self : GraphName, node : NamedNodeRef) -> GraphName {
//   node.into_owned().into()
// }

// impl From for GraphName with from(self : GraphName, node : BlankNode) -> GraphName {
//   GraphName::BlankNode(node)
// }

// impl From for GraphName with from(self : GraphName, node : BlankNodeRef) -> GraphName {
//   node.into_owned().into()
// }

// impl From for GraphName with from(self : GraphName, node : NamedOrBlankNode) -> GraphName {
//   match node {
//     NamedOrBlankNode::NamedNode(node) => node.into()
//     NamedOrBlankNode::BlankNode(node) => node.into()
//   }
// }

// impl From for GraphName with from(self : GraphName, node : NamedOrBlankNodeRef) -> GraphName {
//   node.into_owned().into()
// }

// pub enum GraphNameRef {
//   NamedNode(NamedNodeRef)
//   BlankNode(BlankNodeRef)
//   DefaultGraph
// } derive(Eq, Show, Hash, Default)
// pub fn GraphNameRef::is_named_node(self : GraphNameRef) -> Bool {
//   self is Self :: NamedNode (_)
// }
// pub fn GraphNameRef::is_blank_node(self : GraphNameRef) -> Bool {
//   self is Self :: BlankNode (_)
// }
// pub fn GraphNameRef::is_default_graph(self : GraphNameRef) -> Bool {
//   self is Self :: DefaultGraph
// }
// pub fn GraphNameRef::into_owned(self : GraphNameRef) -> GraphName {
//   match self {
//     GraphNameRef::NamedNode(node) => GraphName::NamedNode(node.into_owned())
//     GraphNameRef::BlankNode(node) => GraphName::BlankNode(node)
//     GraphNameRef::DefaultGraph => GraphName::DefaultGraph
//   }
// }

// impl fmt::Show for GraphNameRef with fmt(self : GraphNameRef, f : Formatter) -> Result {
//   match self {
//     GraphNameRef::NamedNode(node) => node.fmt(f)
//     GraphNameRef::BlankNode(node) => node.fmt(f)
//     GraphNameRef::DefaultGraph => f.write_str("DEFAULT")
//   }
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : NamedNodeRef) -> GraphNameRef {
//   GraphNameRef::NamedNode(node)
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : NamedNode) -> GraphNameRef {
//   node.into()
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : BlankNodeRef) -> GraphNameRef {
//   GraphNameRef::BlankNode(node)
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : BlankNode) -> GraphNameRef {
//   node.into()
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : NamedOrBlankNodeRef) -> GraphNameRef {
//   match node {
//     NamedOrBlankNodeRef::NamedNode(node) => node.into()
//     NamedOrBlankNodeRef::BlankNode(node) => node.into()
//   }
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : NamedOrBlankNode) -> GraphNameRef {
//   node.into()
// }

// impl From for GraphNameRef with from(self : GraphNameRef, node : GraphName) -> GraphNameRef {
//   node
// }

// impl From for GraphName with from(self : GraphName, node : GraphNameRef) -> GraphName {
//   node.into_owned()
// }

// pub struct Quad {
//   subject : NamedOrBlankNode
//   predicate : NamedNode
//   object : Term
//   graph_name : GraphName
// } derive(Eq, Debug, Hash)
pub fn Quad::new(subject : NamedOrBlankNodeRef, predicate : NamedNodeRef, object : TermRef, graph_name : GraphNameRef) -> Quad {
  { subject: subject, predicate: predicate, object: object, graph_name: graph_name }
}
pub fn Quad::as_ref(self : Quad) -> QuadRef {
  { subject: self.subject, predicate: self.predicate, object: self.object, graph_name: self.graph_name }
}

// impl fmt::Show for Quad with fmt(self : Quad, f : Formatter) -> Result {
//   self.fmt(f)
// }

// impl From for Triple with from(self : Triple, quad : Quad) -> Triple {
//   { subject: quad.subject, predicate: quad.predicate, object: quad.object }
// }

// pub struct QuadRef {
//   subject : NamedOrBlankNodeRef
//   predicate : NamedNodeRef
//   object : TermRef
//   graph_name : GraphNameRef
// } derive(Eq, Show, Hash)
// pub fn QuadRef::new(subject : Into, predicate : Into, object : Into, graph_name : Into) -> QuadRef {
//   { subject: subject.into(), predicate: predicate.into(), object: object.into(), graph_name: graph_name.into() }
// }
// pub fn QuadRef::into_owned(self : QuadRef) -> Quad {
//   { subject: self.subject.into_owned(), predicate: self.predicate.into_owned(), object: self.object, graph_name: self.graph_name.into_owned() }
// }

// impl fmt::Show for QuadRef with fmt(self : QuadRef, f : Formatter) -> Result {
//   if self.graph_name.is_default_graph() {
//     write(f , "{} {} {}" , self . subject , self . predicate , self . object)
//   } else {
//     write(f , "{} {} {} {}" , self . subject , self . predicate , self . object , self . graph_name)
//   }
// }

// impl From for TripleRef with from(self : TripleRef, quad : QuadRef) -> TripleRef {
//   { subject: quad.subject, predicate: quad.predicate, object: quad.object }
// }

// impl From for QuadRef with from(self : QuadRef, quad : Quad) -> QuadRef {
//   quad
// }

// impl From for Quad with from(self : Quad, quad : QuadRef) -> Quad {
//   quad.into_owned()
// }

pub struct TryFromTermError {
  term : Term
  target : String
} derive(Debug)
pub fn TryFromTermError::into_term(self : TryFromTermError) -> Term {
  self.term
}

// fn[S] serialize_predicate(node : NamedNode, serializer : S) -> Result[Unit, Error] {
//     struct Value {
//     value : String
//   }
//   { value: node }.serialize(serializer)
// }


// test "triple from terms" {
//   assert_eq(Triple::from_terms(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"))!, Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o")))
//   assert_eq(Triple::from_terms(Literal::new_simple_literal("foo"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o")).unwrap_err().into_term(), Term::from(Literal::new_simple_literal("foo")))
//   assert_eq(Triple::from_terms(NamedNode::new_unchecked("http://example.com/s"), Literal::new_simple_literal("foo"), NamedNode::new_unchecked("http://example.com/o")).unwrap_err().into_term(), Term::from(Literal::new_simple_literal("foo")))
//   Ok(())
// }
// test "serde" {
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"))
//   let jsn = serde_json::to_string(triple)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"}}")
//   let deserialized : Triple = serde_json::from_str(jsn)!
//   assert_eq(deserialized, triple)
//   let triple = Triple::new(BlankNode::new_unchecked("s"), NamedNode::new_unchecked("http://example.com/p"), Literal::new_simple_literal("foo"))
//   let jsn = serde_json::to_string(triple)!
//   assert_eq(jsn, "{"subject":{"type":"bnode","value":"s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"literal","value":"foo"}}")
//   let deserialized : Triple = serde_json::from_str(jsn)!
//   assert_eq(deserialized, triple)
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), BlankNode::new_unchecked("foo"))
//   let jsn = serde_json::to_string(triple)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"bnode","value":"foo"}}")
//   let deserialized : Triple = serde_json::from_str(jsn)!
//   assert_eq(deserialized, triple)
//   Ok(())
// }
// test "serde from reader" {
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"))
//   let jsn = serde_json::to_string(triple)!
//   let deserialized : Triple = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, triple)
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), Literal::new_simple_literal("foo"))
//   let jsn = serde_json::to_string(triple)!
//   let deserialized : Triple = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, triple)
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), BlankNode::new_unchecked("foo"))
//   let jsn = serde_json::to_string(triple)!
//   let deserialized : Triple = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, triple)
//   Ok(())
// }
// test "serde star" {
//   let triple = Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), Term::Triple(Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"))))
//   let jsn = serde_json::to_string(triple)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"triple","subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"}}}")
//   let deserialized : Triple = serde_json::from_str(jsn)!
//   assert_eq(deserialized, triple)
//   Ok(())
// }
// test "serde quad" {
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"},"graph":{"type":"uri","value":"http://example.com/g"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), Literal::new_simple_literal("foo"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"literal","value":"foo"},"graph":{"type":"uri","value":"http://example.com/g"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), BlankNode::new_unchecked("foo"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"bnode","value":"foo"},"graph":{"type":"uri","value":"http://example.com/g"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), BlankNode::new_unchecked("foo"))
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"},"graph":{"type":"bnode","value":"foo"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), GraphName::DefaultGraph)
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"},"graph":{"type":"default"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   Ok(())
// }
// test "serde quad from reader" {
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   let deserialized : Quad = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), Literal::new_simple_literal("foo"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   let deserialized : Quad = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), BlankNode::new_unchecked("foo"), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   let deserialized : Quad = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), BlankNode::new_unchecked("foo"))
//   let jsn = serde_json::to_string(quad)!
//   let deserialized : Quad = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, quad)
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"), GraphName::DefaultGraph)
//   let jsn = serde_json::to_string(quad)!
//   let deserialized : Quad = serde_json::from_reader(jsn.to_bytes())!
//   assert_eq(deserialized, quad)
//   Ok(())
// }
// test "serde quad star" {
//   let quad = Quad::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), Term::Triple(Triple::new(NamedNode::new_unchecked("http://example.com/s"), NamedNode::new_unchecked("http://example.com/p"), NamedNode::new_unchecked("http://example.com/o"))), NamedNode::new_unchecked("http://example.com/g"))
//   let jsn = serde_json::to_string(quad)!
//   assert_eq(jsn, "{"subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"triple","subject":{"type":"uri","value":"http://example.com/s"},"predicate":{"type":"uri","value":"http://example.com/p"},"object":{"type":"uri","value":"http://example.com/o"}},"graph":{"type":"uri","value":"http://example.com/g"}}")
//   let deserialized : Quad = serde_json::from_str(jsn)!
//   assert_eq(deserialized, quad)
//   Ok(())
// }
// test "deserialize owned" {
//     fn[T : DeserializeOwned] assert_deserialize_owned() -> Unit {

//   }
//   assert_deserialize_owned()
//   assert_deserialize_owned()
//   assert_deserialize_owned()
// }

