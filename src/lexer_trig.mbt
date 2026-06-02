pub struct TriGRecognizer {
  stack : Array[TriGState]
  cur_subject : Array[NamedOrBlankNodeRef]
  cur_predicate : Array[NamedNodeRef]
  cur_object : Array[TermRef]
  mut cur_graph : GraphNameRef
  cur_reifier : Array[NamedOrBlankNodeRef]
  lenient : Bool
}
pub struct TriGRecognizerContext {
 lexer_options : TriGLexerOptions
 with_graph_name : Bool
  prefixes : Map[String, Iri]
}

pub struct TriGLexerOptions{
  mut  base_iri : Iri?

}
fn TriGLexerOptions::TriGLexerOptions() -> TriGLexerOptions {
  { base_iri: None }
}

pub fn TriGRecognizerContext::prefixes(self : TriGRecognizerContext) ->Map[String, Iri] {
  self.prefixes
}

impl RuleRecognizer for TriGRecognizer with error_recovery_state(self : TriGRecognizer) -> TriGRecognizer {
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_reifier.clear()
  self.cur_graph = GraphNameRef::DefaultGraph
  self
}
impl RuleRecognizer for TriGRecognizer with recognize_next(self : TriGRecognizer, token : TokenOrLineJump[N3Token], context : Context, results : Array[LexOutput], errors : Array[RuleRecognizerError]) -> TriGRecognizer {
  // let token = token
    let context = match context {
    Context::TriGRecognizerContext(c) => c
    _ => panic()
  }
  if self.stack.pop() is Some(rule) {
    match rule {
      TriGState::TriGDoc => {
        self.cur_graph = GraphNameRef::DefaultGraph
        self.stack.push(TriGState::TriGDoc)
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(k,"base") => {
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(k,"prefix") => {
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(k,"version") => {
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(N3Token::LangTag(language="prefix", direction=None)) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(N3Token::LangTag(language="base", direction=None)) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(N3Token::LangTag(language="version", direction=None)) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(k,"graph") && context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self.stack.push(TriGState::GraphName)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("{")) if context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
          }
          _ => {
            self.stack.push(TriGState::TriplesOrGraph)
            self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
          }
        }
      }
      TriGState::ExpectDot => {
        let _ = self.cur_subject.pop()
        if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          self
        } else {
          errors.push(RuleRecognizerError::TripleMissingDot)
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::BaseExpectIri =>       if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
        let iri= Iri::Iri(iri)
        let iri=IriRef::new(iri)
        context.lexer_options.base_iri = Some(IriRef::parse(iri).unwrap())
        self
      } else {
        self.error(errors, "The BASE keyword should be followed by an IRI")
      }
      TriGState::PrefixExpectPrefix => match token {
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, ..)) if localx.is_empty() => {
          self.stack.push(TriGState::PrefixExpectIri(name= prefix ))
          self
        }
        _ => self.error(errors, "The PREFIX keyword should be followed by a prefix like 'ex:'")
      }
      TriGState::PrefixExpectIri(name~) =>       if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
                let iri= Iri::Iri(iri)
        let iri=IriRef::new(iri)
        context.prefixes.set(name, iri.to_owned())
        self
      } else {
        self.error(errors, "The PREFIX declaration should be followed by a prefix and its value as an IRI")
      }
      TriGState::VersionExpectVersion =>       if token is TokenOrLineJump::Token(N3Token::String(_)) {
        self
      } else {
        self.error(errors, "The VERSION keyword should be followed by a single quoted string like \"1.2\"")
      }
      TriGState::TriplesOrGraph => match token {
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.stack.push(TriGState::WrappedGraphOrPredicateObjectList(term=NamedOrBlankNode::NamedNode(NamedNode::new_unchecked(iri))))
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.stack.push(TriGState::WrappedGraphOrPredicateObjectList(term=NamedOrBlankNode::NamedNode(t)))
            self
          }
          Err(e) => self.error(errors, e)
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.stack.push(TriGState::WrappedGraphOrPredicateObjectList(term=NamedOrBlankNode::NamedNode(NamedNode::new_unchecked(label))))
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.stack.push(TriGState::WrappedGraphBlankNodePropertyListCurrent)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
          self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::PredicateObjectList)
          self.stack.push(TriGState::SubjectCollectionBeginning)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
          self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::MaybePredicateObjectList)
          self.stack.push(TriGState::SubjectReifiedTripleEnd)
          self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= true))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= true ))
          self
        }
        _ => self.error(errors, "TOKEN is not a valid subject or graph name")
      }
      TriGState::WrappedGraphOrPredicateObjectList(term~) => {
        if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) && context.with_graph_name {
        match term {
          NamedOrBlankNode::NamedNode(named_node) => {
             // 如果 GraphNameRef::NamedNodeRef 期望 NamedNodeRef
             // 且 named_node 是 NamedNode
             // 可能需要: NamedNodeRef::new(named_node) 或类似转换
             // 这里假设可以直接使用 named_node 或者它已经是 Ref 类型
             self.cur_graph = GraphNameRef::NamedNodeRef(named_node.as_ref())
          }
          NamedOrBlankNode::BlankNode(blank_node) => {
             // 处理错误或 BlankNode 情况
              self.cur_graph = GraphNameRef::BlankNodeRef(blank_node.as_ref())
          }
        }
        self.stack.push(TriGState::WrappedGraph)
        } else {
        match term {
          NamedOrBlankNode::NamedNode(named_node) => {
             // 如果 GraphNameRef::NamedNodeRef 期望 NamedNodeRef
             // 且 named_node 是 NamedNode
             // 可能需要: NamedNodeRef::new(named_node) 或类似转换
             // 这里假设可以直接使用 named_node 或者它已经是 Ref 类型
             self.cur_graph = GraphNameRef::NamedNodeRef(named_node.as_ref())
          }
          NamedOrBlankNode::BlankNode(blank_node) => {
             // 处理错误或 BlankNode 情况
              self.cur_graph = GraphNameRef::BlankNodeRef(blank_node.as_ref())
          }
        }
        self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::PredicateObjectList)
        }
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::WrappedGraphBlankNodePropertyListCurrent =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
        self.stack.push(TriGState::WrappedGraphOrPredicateObjectList( term= NamedOrBlankNode::BlankNode(BlankNode::default())))
        self
      } else {
        self.cur_subject.push( NamedOrBlankNode::BlankNode(BlankNode::default()).as_ref())
        self.stack.push(TriGState::ExpectDot)
        self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
        self.stack.push(TriGState::PredicateObjectList)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::SubjectBlankNodePropertyListEnd =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
        self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
        self
      } else {
        errors.push(RuleRecognizerError::BlankNodePropertyListMissingEndBracket)
        self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::SubjectBlankNodePropertyListAfter =>       if token is TokenOrLineJump::Token(N3Token :: Punctuation ("." | "}")) {
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      } else {
        self.stack.push(TriGState::PredicateObjectList)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::SubjectCollectionBeginning =>       if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
        self.cur_subject.push(NamedOrBlankNodeRef::NamedNodeRef(lwNIL.as_ref()))
        self
      } else {
        let root =NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()) 
        self.cur_subject.push(root)
        self.cur_subject.push(root)
        self.cur_predicate.push(lwFIRST.as_ref())
        self.stack.push(TriGState::SubjectCollectionPossibleEnd)
        self.stack.push(TriGState::Object)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::SubjectCollectionPossibleEnd => {
        let old = self.cur_subject.pop().unwrap()
        let _=self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
let _ = self.cur_predicate.pop();
          results.push(LexOutput::Quad(QuadRef::new(old, lwREST.as_ref(), TermRef::NamedNodeRef(lwNIL.as_ref()), self.cur_graph).into_owned()))
          self
        } else {
          let new = BlankNode::default()
          results.push(LexOutput::Quad(QuadRef::new(old, lwREST.as_ref(), TermRef::BlankNodeRef(new.as_ref()), self.cur_graph).into_owned()))
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::WrappedGraph =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) {
        self.stack.push(TriGState::WrappedGraphPossibleEnd)
        self.stack.push(TriGState::Triples)
        self
      } else {
        self.error(errors, "The GRAPH keyword should be followed by a graph name and a value in '{'")
      }
      TriGState::WrappedGraphPossibleEnd => {
        let _=self.cur_subject.pop()
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("}")) => self
          TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
            self.stack.push(TriGState::WrappedGraphPossibleEnd)
            self.stack.push(TriGState::Triples)
            self
          }
          _ => {
            errors.push(RuleRecognizerError::TripleMissingDot)
            self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
          }
        }
      }
      TriGState::Triples => match token {
        TokenOrLineJump::Token(N3Token::Punctuation("}")) =>         self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()))
          self.stack.push(TriGState::TriplesBlankNodePropertyListCurrent)
          self
        }
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_subject.push(NamedOrBlankNodeRef::NamedNodeRef(NamedNode::new_unchecked(iri).as_ref()))
          self.stack.push(TriGState::PredicateObjectList)
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_subject.push(NamedOrBlankNodeRef::NamedNodeRef(t.as_ref()))
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          Err(e) => self.error(errors, e)
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(BlankNode::new_unchecked(label).as_ref()))
          self.stack.push(TriGState::PredicateObjectList)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
          self.stack.push(TriGState::PredicateObjectList)
          self.stack.push(TriGState::SubjectCollectionBeginning)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
          self.stack.push(TriGState::MaybePredicateObjectList)
          self.stack.push(TriGState::SubjectReifiedTripleEnd)
          self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
          self.stack.push(TriGState::ReifiedTripleSubject( is_reified= true ))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleObject( is_reified= true ))
          self
        }
        _ => self.error(errors, "TOKEN is not a valid RDF subject")
      }
      TriGState::TriplesBlankNodePropertyListCurrent =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
        self.stack.push(TriGState::PredicateObjectList)
        self
      } else {
        self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
        self.stack.push(TriGState::PredicateObjectList)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::GraphName => match token {
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_graph = GraphNameRef::NamedNodeRef(NamedNode::new_unchecked(iri).as_ref())
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_graph = GraphNameRef::NamedNodeRef(t.as_ref())
            self
          }
          Err(e) => self.error(errors, e)
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
          self.cur_graph = GraphNameRef::BlankNodeRef(BlankNode::new_unchecked(label).as_ref())
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.stack.push(TriGState::GraphNameAnonEnd)
          self
        }
        _ => self.error(errors, "TOKEN is not a valid graph name")
      }
      TriGState::GraphNameAnonEnd =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
        self.cur_graph = GraphNameRef::BlankNodeRef(BlankNode::default().as_ref())
        self
      } else {
        self.error(errors, "Anonymous blank node with a property list are not allowed as graph name")
      }
      TriGState::MaybePredicateObjectList => {
        if token != TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          self.stack.push(TriGState::PredicateObjectList)
        }
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::PredicateObjectList => {
        self.stack.push(TriGState::PredicateObjectListEnd)
        self.stack.push(TriGState::ObjectsList)
        self.stack.push(TriGState::Verb)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::PredicateObjectListEnd => {
       let _= self.cur_predicate.pop()
        if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
          self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
          self
        } else {
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::PredicateObjectListPossibleContinuation =>       if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
        self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
        self
      } else {
        if token is TokenOrLineJump::Token(N3Token :: Punctuation ("." | "}" | "]" | "|}")) {
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        } else {
          self.stack.push(TriGState::PredicateObjectListEnd)
          self.stack.push(TriGState::ObjectsList)
          self.stack.push(TriGState::Verb)
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::ObjectsList => {
        self.stack.push(TriGState::AnnotationEnd(with_reifier= false))
        self.stack.push(TriGState::Object)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::AnnotationBlock(with_reifier~) => match token {
        TokenOrLineJump::Token(N3Token::Punctuation(",")) => {
         let _= self.cur_object.pop()
          if with_reifier {
          let _=  self.cur_reifier.pop()
          }
          self.stack.push(TriGState::AnnotationBlock(with_reifier= false))
          self.stack.push(TriGState::Object)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("~")) => {
          self.stack.push(TriGState::AnnotationBlock(with_reifier= true))
          self.stack.push(TriGState::Reifier(triple= TripleRef::new(self.cur_subject.last().unwrap(), self.cur_predicate.last().unwrap(), self.cur_object.last().unwrap()).into_owned()))
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("{|")) => {
          let reifier = if with_reifier {
            self.cur_reifier.last().unwrap()
          } else {
            let reifier = BlankNode::default()
            results.push(LexOutput::Quad(Quad::new(NamedOrBlankNode::BlankNode(reifier), lwREIFIES, TermRef::TripleRef(TripleRef::new(self.cur_subject.last().unwrap(), self.cur_predicate.last().unwrap(), self.cur_object.last().unwrap())).into_owned(), self.cur_graph.into_owned())))
            NamedOrBlankNodeRef::BlankNodeRef(reifier.as_ref())
          }
          self.cur_subject.push(reifier)
          self.stack.push(TriGState::AnnotationBlock(with_reifier= with_reifier))
          self.stack.push(TriGState::PredicateObjectList)
          self
        }
        _ => {
          let _=self.cur_object.pop()
          if with_reifier {
           let _= self.cur_reifier.pop()
          }
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::AnnotationEnd(with_reifier~) => {
       let _= self.cur_subject.pop()
        self.stack.push(TriGState::AnnotationEnd(with_reifier= with_reifier))
        if token == TokenOrLineJump::Token(N3Token::Punctuation("|}")) {
          self
        } else {
          self.error(errors, "Annotations should end with '|}'").recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::Verb => match token {
        TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
          self.cur_predicate.push(lwTYPE.as_ref())
          self
        }
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_predicate.push(NamedNode::new_unchecked(iri).as_ref())
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_predicate.push(t.as_ref())
            self
          }
          Err(e) => self.error(errors, e)
        }
        _ => self.error(errors, "TOKEN is not a valid predicate")
      }
      TriGState::Object => match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_object.push(TermRef::NamedNodeRef(NamedNode::new_unchecked(iri).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_object.push(TermRef::NamedNodeRef(t.as_ref()))
            self.emit_quad(results)
            self
          }
          Err(e) => self.error(errors, e)
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
          self.cur_object.push(TermRef::NamedNodeRef(NamedNode::new_unchecked(label).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.stack.push(TriGState::ObjectBlankNodePropertyListCurrent)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("(")) => {
          self.stack.push(TriGState::ObjectCollectionBeginning)
          self
        }
        TokenOrLineJump::Token(N3Token::String(value)) | TokenOrLineJump::Token(N3Token::LongString(value)) => {
          self.stack.push(TriGState::LiteralPossibleSuffix( value= value, emit= true ))
          self
        }
        TokenOrLineJump::Token(N3Token::Integer(v)) => {
          self.cur_object.push(TermRef::LiteralRef(Literal::new_typed_literal(VarDataType::from_str(v), lwINTEGER).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::Decimal(v)) => {
          self.cur_object.push(TermRef::LiteralRef(Literal::new_typed_literal(VarDataType::from_str(v), lwDECIMAL).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::Double(v)) => {
          self.cur_object.push(TermRef::LiteralRef(Literal::new_typed_literal(VarDataType::from_str(v), lwDOUBLE).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
          self.cur_object.push(TermRef::LiteralRef(Literal::new_typed_literal(VarDataType::from_str("true"), lwBOOLEAN).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
          self.cur_object.push(TermRef::LiteralRef(Literal::new_typed_literal(VarDataType::from_str("false"), lwBOOLEAN).as_ref()))
          self.emit_quad(results)
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
          self.stack.push(TriGState::ObjectReifiedTripleEnd( emit= true ))
          self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= true   ) )
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= true   ) )
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
          self.stack.push(TriGState::ObjectReifiedTripleEnd(emit= true))
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= false))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= false))
          self
        }
        _ => self.error(errors, "TOKEN is not a valid RDF object")
      }
      TriGState::ObjectBlankNodePropertyListCurrent =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
        self.cur_object.push(TermRef::BlankNodeRef(BlankNode::default().as_ref()))
        self.emit_quad(results)
        self
      } else {
        self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()))
        self.stack.push(TriGState::ObjectBlankNodePropertyListEnd)
        self.stack.push(TriGState::PredicateObjectList)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::ObjectBlankNodePropertyListEnd =>       if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
               let subject = self.cur_subject.pop().unwrap()

        let blank_ref = match subject {
          NamedOrBlankNodeRef::BlankNodeRef(b) => b
          _ => panic()
        }
        self.cur_object.push(TermRef::BlankNodeRef(blank_ref))   
             self.emit_quad(results)
        self
      } else {
        self.error(errors, "blank node property lists should end with a ']'")
      }
      TriGState::ObjectCollectionBeginning =>       if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
        self.cur_object.push(TermRef::NamedNodeRef(lwNIL.as_ref()))
        self.emit_quad(results)
        self
      } else {
        let root = BlankNode::default()
        self.cur_object.push(TermRef::BlankNodeRef(root.as_ref()))
        self.emit_quad(results)
        self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(root.as_ref()))
        self.cur_predicate.push(NamedNode::NamedNode(lwFIRST.to_string()).as_ref())
        self.stack.push(TriGState::ObjectCollectionPossibleEnd)
        self.stack.push(TriGState::Object)
        self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::ObjectCollectionPossibleEnd => {
      // if token.is_eof() || token.is_dot() || token.is_rbracket() || token.is_rbrace() || token.is_comma() || token.is_semicolon() || token.is_newline() || token.is_eol() || token.is_eof() {
        let old = self.cur_subject.pop().unwrap()
       let _= self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          let _=self.cur_predicate.pop()
          results.push(LexOutput::Quad(Quad::new(old.into_owned(), lwREST, Term::NamedNode(lwNIL), self.cur_graph.into_owned())))
          self
        } else {
          let new = BlankNode::default()
          results.push(LexOutput::Quad(Quad::new(old.into_owned(), lwREST, Term::NamedNode(lwNIL), self.cur_graph.into_owned())))
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      // }
      }

      TriGState::LiteralPossibleSuffix(value~, emit~) => match token {
        TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) => {
          self.cur_object.push(if direction is Some(direction) {
                      // let lang_tag = try? LanguageTag::from_str(language.to_lower())

            TermRef::LiteralRef(LiteralRef::new_directional_language_tagged_literal_unchecked(value, language.to_lower(), direction))
          } else {
            TermRef::LiteralRef(LiteralRef::new_language_tagged_literal_unchecked(value, language.to_lower()))
          })
          if emit {
            self.emit_quad(results)
          }
          self
        }
        TokenOrLineJump::Token(N3Token::LangTag(language~,..)) => {
          self.cur_object.push(TermRef::LiteralRef(LiteralRef::new_language_tagged_literal_unchecked(value, language.to_lower())))
          if emit {
            self.emit_quad(results)
          }
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
          self.stack.push(TriGState::LiteralPossibleSuffix(value= value, emit= emit))
          self
        }
        _ => {
          self.cur_object.push(TermRef::LiteralRef(LiteralRef::new_simple_literal(value)))
          if emit {
            self.emit_quad(results)
          }
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::LiteralExpectDatatype(value~, emit~) => match token {
        TokenOrLineJump::Token(N3Token::Iri(datatype)) => {
          if !(self.lenient) && datatype == lwLANG_STRING.to_string() {
            errors.push(RuleRecognizerError::SyntaxError("The datatype of a literal without a language tag must not be rdf:langString",TextPosition::default()))
          }
          if !(self.lenient) && datatype == lwDIR_LANG_STRING.to_string() {
            errors.push(RuleRecognizerError::SyntaxError("The datatype of a literal without a base direction must not be rdf:dirLangString",TextPosition::default()))
          }
          self.cur_object.push(TermRef::LiteralRef(LiteralRef::new_typed_literal(VarDataType::from_str(value), NamedNode::new_unchecked(datatype).as_ref())))
          if emit {
            self.emit_quad(results)
          }
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            if !(self.lenient) && t == lwLANG_STRING {
              errors.push(RuleRecognizerError::SyntaxError("The datatype of a literal without a language tag must not be rdf:langString", TextPosition::default()))
            }
            if !(self.lenient) && t == lwDIR_LANG_STRING {
              errors.push(RuleRecognizerError::SyntaxError("The datatype of a literal without a base direction must not be rdf:dirLangString",TextPosition::default()))
            }
            self.cur_object.push(TermRef::LiteralRef(LiteralRef::new_typed_literal(VarDataType::from_str(value), NamedNode::NamedNode(t.to_string()).as_ref())))
            if emit {
              self.emit_quad(results)
            }
            self
          }
          Err(e) => self.error(errors, e)
        }
        _ => self.error(errors, "Expecting a datatype IRI after ^^, found TOKEN").recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
      }
      TriGState::SubjectReifiedTripleEnd => {
        self.cur_subject.push(self.cur_reifier.pop().unwrap())
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self.error(errors, "Expecting '>>' to close a reified triple, found TOKEN").recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::ObjectReifiedTripleEnd(emit~) => {
        self.cur_object.push(self.cur_reifier.pop().unwrap().into())
        if emit {
          self.emit_quad(results)
        }
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self.error(errors, "Expecting '>>' to close a reified triple, found TOKEN").recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::TripleTermEnd(emit~) => {
        let triple = Triple::new(self.cur_subject.pop().unwrap(), self.cur_predicate.pop().unwrap(), self.cur_object.pop().unwrap())
        self.cur_object.push(triple.into())
        if emit {
          self.emit_quad(results)
        }
        if token == TokenOrLineJump::Token(N3Token::Punctuation(")>>")) {
          self
        } else {
          self.error(errors, "Expecting ')>>' to close a triple term, found TOKEN").recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::EndOfReifiedTripleBeforeReifier => {
        let triple = Triple::new(self.cur_subject.pop().unwrap(), self.cur_predicate.pop().unwrap(), self.cur_object.pop().unwrap())
        if token == TokenOrLineJump::Token(N3Token::Punctuation("~")) {
          self.stack.push(TriGState::Reifier(triple= triple))
          self
        } else {
          let reifier = BlankNode::default()
          results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
          self.cur_reifier.push(reifier.into())
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::Reifier(triple~) => match token {
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          let reifier = NamedNode::new_unchecked(iri)
          results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
          self.cur_reifier.push(reifier.into())
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(reifier) => {
            results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
            self.cur_reifier.push(reifier.into())
            self
          }
          Err(e) => {
            let reifier = BlankNode::default()
            results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
            self.cur_reifier.push(reifier.into())
            self.error(errors, e)
          }
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(bnode)) => {
          let reifier = BlankNode::new_unchecked(bnode)
          results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
          self.cur_reifier.push(reifier.into())
          self
        }
        _ => {
          let reifier = BlankNode::default()
          results.push(Quad::new(reifier, lwREIFIES, triple, self.cur_graph))
          self.cur_reifier.push(reifier.into())
          self.recognize_next(token, Context::TriGRecognizerContext(context), results, errors)
        }
      }
      TriGState::ReifiedTripleSubject(is_reified~) => match token {
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.cur_subject.push(BlankNode::default().into())
          self.stack.push(TriGState::QuotedAnonEnd)
          self
        }
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_subject.push(NamedNode::new_unchecked(iri).into())
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_subject.push(t.into())
            self
          }
          Err(e) => self.error(errors, e)
        }
        N3Token::BlankNodeLabel(label) => {
          self.cur_subject.push(BlankNode::new_unchecked(label).into())
          self
        }
        N3Token::Punctuation("<<") if is_reified => {
          self.stack.push(TriGState::SubjectReifiedTripleEnd)
          self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= true))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= true))
          self
        }
        _ => self.error(errors, "TOKEN is not a valid RDF quoted triple subject: TOKEN")
      }
      TriGState::ReifiedTripleObject(is_reified~) => match token {
        TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
          self.cur_object.push(BlankNode::default().into())
          self.stack.push(TriGState::QuotedAnonEnd)
          self
        }
        TokenOrLineJump::Token(N3Token::Iri(iri)) => {
          self.cur_object.push(NamedNode::new_unchecked(iri).into())
          self
        }
        TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)) => match resolve_local_name(prefix, localx, might_be_invalid_iri, context.prefixes) {
          Ok(t) => {
            self.cur_object.push(t.into())
            self
          }
          Err(e) => self.error(errors, e)
        }
        TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
          self.cur_object.push(BlankNode::new_unchecked(label).into())
          self
        }
        TokenOrLineJump::Token(N3Token::String(value)) => {
          self.stack.push(TriGState::LiteralPossibleSuffix(value= value, emit= false))
          self
        }
        TokenOrLineJump::Token(N3Token::Integer(v)) => {
          self.cur_object.push(Literal::new_typed_literal(v, lwINTEGER).into())
          self
        }
        TokenOrLineJump::Token(N3Token::Decimal(v)) => {
          self.cur_object.push(Literal::new_typed_literal(v, lwDECIMAL).into())
          self
        }
        TokenOrLineJump::Token(N3Token::Double(v)) => {
          self.cur_object.push(Literal::new_typed_literal(v, lwDOUBLE).into())
          self
        }
        TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
          self.cur_object.push(Literal::new_typed_literal("true", lwBOOLEAN).into())
          self
        }
        TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
          self.cur_object.push(Literal::new_typed_literal("false", lwBOOLEAN).into())
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
          self.stack.push(TriGState::ObjectReifiedTripleEnd(emit= false))
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= false))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= false))
          self
        }
        TokenOrLineJump::Token(N3Token::Punctuation("<<")) if is_reified => {
          self.stack.push(TriGState::ObjectReifiedTripleEnd(emit= false))
          self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
          self.stack.push(TriGState::ReifiedTripleObject(is_reified= true))
          self.stack.push(TriGState::Verb)
          self.stack.push(TriGState::ReifiedTripleSubject(is_reified= true))
          self
        }
        _ => self.error(errors, "TOKEN is not a valid RDF quoted triple object")
      }
      TriGState::QuotedAnonEnd =>       if token == N3Token::Punctuation("]") {
        self
      } else {
        self.error(errors, "Anonymous blank node with a property list are not allowed in quoted triples")
      }
    }
  } else {
    if token == N3Token::Punctuation(".") || token == N3Token::Punctuation("}") {
      self.stack.push(TriGState::TriGDoc)
      self
    } else {
      self
    }
  }
}
impl RuleRecognizer for TriGRecognizer with recognize_end(self : TriGRecognizer, _context : TriGRecognizerContext, results : Array[Output], errors : Array[RuleRecognizerError]) -> Unit {
  match self.stack {
    [] | [TriGState::TriGDoc] => {
      debug_assert(self.cur_subject.is_empty(), "The cur_subject stack must be empty if the state stack is empty")
      debug_assert(self.cur_predicate.is_empty(), "The cur_predicate stack must be empty if the state stack is empty")
      debug_assert(self.cur_object.is_empty(), "The cur_object stack must be empty if the state stack is empty")
    }
    [.., TriGState::LiteralPossibleSuffix(value~, emit=true)] => {
      self.cur_object.push(Literal::new_simple_literal(value).into())
      self.emit_quad(results)
      errors.push("Triples should be followed by a dot".into())
    }
    _ => errors.push("Unexpected end".into())
  }
}
impl RuleRecognizer for TriGRecognizer with lexer_options(self : TriGRecognizer, context : TriGRecognizerContext) -> N3LexerOptions {
  context.lexer_options
}

pub fn TriGRecognizer::new_parser(data : B, is_ending : Bool, with_graph_name : Bool, lenient : Bool, base_iri : Option[Iri[String]], prefixes : Map[String, Iri[String]]) -> Parser[B, TriGRecognizer] {
  Parser::new(Lexer::new(N3Lexer::new(N3LexerMode::Turtle, lenient), data, is_ending, MIN_BUFFER_SIZE, MAX_BUFFER_SIZE, Some(b"#")), { stack: [TriGState::TriGDoc], cur_subject: [], cur_predicate: [], cur_object: [], cur_graph: GraphName::DefaultGraph, cur_reifier: [], lenient: lenient }, { with_graph_name: with_graph_name, prefixes: prefixes, lexer_options: { base_iri: base_iri } })
}
fn TriGRecognizer::error(self : TriGRecognizer, errors : Array[RuleRecognizerError], msg : Into) -> TriGRecognizer {
  errors.push(msg.into())
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_graph = GraphName::DefaultGraph.as_ref()
  self
}
fn TriGRecognizer::emit_quad(self : TriGRecognizer, results : Array[LexOutput]) -> Unit {
  results.push(LexOutput::Quad(Quad::new(self.cur_subject.last().unwrap().into_owned(), self.cur_predicate.last().unwrap().into_owned(), self.cur_object.last().unwrap().into_owned(), self.cur_graph.into_owned())))
}

enum TriGState {
  TriGDoc
  ExpectDot
  BaseExpectIri
  PrefixExpectPrefix
  PrefixExpectIri(name~ : String)
  VersionExpectVersion
  TriplesOrGraph
  WrappedGraphBlankNodePropertyListCurrent
  SubjectBlankNodePropertyListEnd
  SubjectBlankNodePropertyListAfter
  SubjectCollectionBeginning
  SubjectCollectionPossibleEnd
  WrappedGraphOrPredicateObjectList(term~ : NamedOrBlankNode)
  WrappedGraph
  WrappedGraphPossibleEnd
  GraphName
  GraphNameAnonEnd
  Triples
  TriplesBlankNodePropertyListCurrent
  MaybePredicateObjectList
  PredicateObjectList
  PredicateObjectListEnd
  PredicateObjectListPossibleContinuation
  ObjectsList
  AnnotationBlock(with_reifier~ : Bool)
  AnnotationEnd(with_reifier~ : Bool)
  Verb
  Object
  ObjectBlankNodePropertyListCurrent
  ObjectBlankNodePropertyListEnd
  ObjectCollectionBeginning
  ObjectCollectionPossibleEnd
  LiteralPossibleSuffix(value~ : String, emit~ : Bool)
  LiteralExpectDatatype(value~ : String, emit~ : Bool)
  SubjectReifiedTripleEnd
  ObjectReifiedTripleEnd(emit~ : Bool)
  TripleTermEnd(emit~ : Bool)
  EndOfReifiedTripleBeforeReifier
  Reifier(triple~ : Triple)
  ReifiedTripleSubject(is_reified~ : Bool)
  ReifiedTripleObject(is_reified~ : Bool)
  QuotedAnonEnd
} derive(Show)
