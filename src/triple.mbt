///|
pub struct Triple {
  subject : NamedOrBlankNode
  predicate : NamedNode
  object : Term
} derive(Eq, Debug, Hash)

///|
impl Show for Triple with fn output(self : Triple, logger : &Logger) -> Unit {
  // logger.write_fmt(format!("Triple {{ subject: {}, predicate: {}, object: {} }}",
  //   self.subject, self.predicate, self.object));
  logger.write("Triple")
  logger.write(" {")
  logger.write(" subject: ")
  self.subject.output(logger)
  logger.write(", ")
  logger.write(" predicate: ")
  self.predicate.output(logger)
  logger.write(", ")
  logger.write(" object: ")
  self.object.output(logger)
  logger.write(" }")
}

///|
pub fn Triple::Triple(
  subject : NamedOrBlankNode,
  predicate : NamedNode,
  object : Term,
) -> Triple {
  { subject, predicate, object }
}

///|
pub fn Triple::from_terms(
  subject : NamedOrBlankNode,
  predicate : NamedNode,
  object : Term,
) -> Result[Triple, TryFromTermError] {
  Ok({ subject, predicate, object })
}

///|
pub fn Triple::in_graph(self : Triple, graph_name : GraphNameRef) -> Quad {
  {
    subject: self.subject,
    predicate: self.predicate,
    object: self.object,
    graph_name: graph_name.into_owned(),
  }
}

///|
pub fn Triple::as_enum(self : Triple) -> Term {
  Term::Triple(self)
}

///|
pub fn Triple::as_ref(self : Triple) -> TripleRef {
  {
    subject: self.subject.as_ref(),
    predicate: self.predicate.as_ref(),
    object: self.object.as_ref(),
  }
}

///|
pub fn Triple::as_n3term(self : Triple) -> N3Term {
  N3Term::Triple(self)
}

///|
pub fn Triple::as_term(self : Triple) -> Term {
  Term::Triple(self)
}
// impl fmt::Show for Triple with fmt(self : Triple, f : Formatter) -> Result {
//   self.fmt(f)
// }

///|
pub struct TripleRef {
  subject : NamedOrBlankNodeRef
  predicate : NamedNodeRef
  object : TermRef
} derive(Eq, Debug, Hash)

///|
impl Show for TripleRef with fn output(self : TripleRef, logger : &Logger) -> Unit {
  // logger.write_fmt(format!("Triple {{ subject: {}, predicate: {}, object: {} }}",
  //   self.subject, self.predicate, self.object));
  logger.write("Triple")
  logger.write(" {")
  logger.write(" subject: ")
  self.subject.output(logger)
  logger.write(", ")
  logger.write(" predicate: ")
  self.predicate.output(logger)
  logger.write(", ")
  logger.write(" object: ")
  self.object.output(logger)
  logger.write(" }")
}

///|
pub fn TripleRef::TripleRef(
  subject : NamedOrBlankNodeRef,
  predicate : NamedNodeRef,
  object : TermRef,
) -> TripleRef {
  { subject, predicate, object }
}

///|
pub fn TripleRef::in_graph(
  self : TripleRef,
  graph_name : GraphNameRef,
) -> QuadRef {
  {
    subject: self.subject,
    predicate: self.predicate,
    object: self.object,
    graph_name,
  }
}

///|
pub fn TripleRef::into_owned(self : TripleRef) -> Triple {
  {
    subject: self.subject.into_owned(),
    predicate: self.predicate.into_owned(),
    object: self.object.into_owned(),
  }
}
