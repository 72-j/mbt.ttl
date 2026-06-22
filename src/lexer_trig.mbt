///|
pub struct TriGRecognizer {
  mut stack : Array[TriGState]
  cur_subject : Array[NamedOrBlankNodeRef]
  cur_predicate : Array[NamedNodeRef]
  cur_object : Array[TermRef]
  mut cur_graph : GraphNameRef
  cur_reifier : Array[NamedOrBlankNodeRef]
  lenient : Bool
  mut debug_logger : &DebugLogger
  mut in_collection : Bool
}

///|
impl Show for TriGRecognizer with fn output(self, logger : &Logger) -> Unit {
  logger.write("TriGRecognizer:\n")

  // 1. 打印栈状态 (增加分隔符和更全的匹配)
  logger.write("  Stack: [")
  for i = 0; i < self.stack.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.stack[i] {
      TriGState::TriGDoc => logger.write("TriGDoc")
      TriGState::ExpectDot => logger.write("ExpectDot")
      TriGState::BaseExpectIri => logger.write("BaseExpectIri")
      TriGState::PrefixExpectPrefix => logger.write("PrefixExpectPrefix")
      TriGState::PrefixExpectIri(name~) =>
        logger.write("PrefixExpectIri(\{name})")
      TriGState::VersionExpectVersion => logger.write("VersionExpectVersion")
      TriGState::TriplesOrGraph => logger.write("TriplesOrGraph")
      TriGState::WrappedGraph => logger.write("WrappedGraph")
      TriGState::WrappedGraphPossibleEnd =>
        logger.write("WrappedGraphPossibleEnd")
      TriGState::GraphName => logger.write("GraphName")
      TriGState::ExpectAtKeyword => logger.write("ExpectAtKeyword")
      TriGState::PredicateObjectList => logger.write("PredicateObjectList")
      TriGState::PredicateObjectListEnd =>
        logger.write("PredicateObjectListEnd")
      TriGState::ObjectsList => logger.write("ObjectsList")
      TriGState::Object => logger.write("Object")
      TriGState::Verb => logger.write("Verb")
      TriGState::LiteralPossibleSuffix(value~, emit~) =>
        logger.write("LiteralPossibleSuffix(\{value} emit=\{emit})")
      TriGState::SubjectCollectionBeginning =>
        logger.write("SubjectCollectionBeginning")
      TriGState::ObjectCollectionBeginning =>
        logger.write("ObjectCollectionBeginning")
      TriGState::WrappedGraphOrPredicateObjectList(_) =>
        logger.write("WrappedGraphOrPredicateObjectList")
      TriGState::AnnotationBlock(_) => logger.write("AnnotationBlock")
      TriGState::Reifier(_) => logger.write("Reifier")
      TriGState::ReifiedTripleSubject(_) => logger.write("ReifiedTripleSubject")
      TriGState::ReifiedTripleObject(_) => logger.write("ReifiedTripleObject")
      TriGState::ObjectReifiedTripleEnd(_) =>
        logger.write("ObjectReifiedTripleEnd")
      TriGState::SubjectReifiedTripleEnd =>
        logger.write("SubjectReifiedTripleEnd")
      TriGState::EndOfReifiedTripleBeforeReifier =>
        logger.write("EndOfReifiedTripleBeforeReifier")
      TriGState::MaybePredicateObjectList =>
        logger.write("MaybePredicateObjectList")
      TriGState::PredicateObjectListPossibleContinuation =>
        logger.write("PredicateObjectListPossibleContinuation")
      TriGState::ObjectBlankNodePropertyListCurrent =>
        logger.write("ObjectBlankNodePropertyListCurrent")
      TriGState::ObjectBlankNodePropertyListEnd =>
        logger.write("ObjectBlankNodePropertyListEnd")
      TriGState::ObjectCollectionPossibleEnd =>
        logger.write("ObjectCollectionPossibleEnd")
      TriGState::SubjectBlankNodePropertyListEnd =>
        logger.write("SubjectBlankNodePropertyListEnd")
      TriGState::SubjectBlankNodePropertyListAfter =>
        logger.write("SubjectBlankNodePropertyListAfter")
      TriGState::WrappedGraphBlankNodePropertyListCurrent =>
        logger.write("WrappedGraphBlankNodePropertyListCurrent")
      TriGState::Triples => logger.write("Triples")
      TriGState::TriplesBlankNodePropertyListCurrent =>
        logger.write("TriplesBlankNodePropertyListCurrent")
      TriGState::GraphNameAnonEnd => logger.write("GraphNameAnonEnd")
      TriGState::QuotedAnonEnd => logger.write("QuotedAnonEnd")
      TriGState::AnnotationEnd(_) => logger.write("AnnotationEnd")
      TriGState::LiteralExpectDatatype(..) =>
        logger.write("LiteralExpectDatatype")
      TriGState::TripleTermEnd(_) => logger.write("TripleTermEnd")
      TriGState::SubjectCollectionPossibleEnd =>
        logger.write("SubjectCollectionPossibleEnd")
      _ => logger.write("UnknownState")
    }
  }
  logger.write("]\n")

  // 2. 打印 Subject (增加分隔符，处理 BlankNode 显示)
  logger.write("  Subject: [")
  for i = 0; i < self.cur_subject.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_subject[i] {
      NamedOrBlankNodeRef::NamedNodeRef(n) => logger.write(n.to_string())
      NamedOrBlankNodeRef::BlankNodeRef(b) => logger.write("_:b") // 或者 b.to_string() 如果有实现
    }
  }
  logger.write("]\n")

  // 3. 打印 Predicate
  logger.write("  Predicate: [")
  for i = 0; i < self.cur_predicate.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    // 假设 NamedNodeRef 实现了 Show 或者有 to_string
    logger.write(self.cur_predicate[i].to_string())
  }
  logger.write("]\n")

  // 4. 打印 Object
  logger.write("  Object: [")
  for i = 0; i < self.cur_object.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_object[i] {
      TermRef::NamedNodeRef(n) => logger.write(n.to_string())
      TermRef::BlankNodeRef(b) => logger.write("_:b")
      TermRef::LiteralRef(l) => logger.write(l.to_string())
      TermRef::TripleRef(t) => logger.write("<<...>>") // 简化显示，避免递归过深
    }
  }
  logger.write("]\n")

  // 5. 打印 Reifier
  logger.write("  Reifier: [")
  for i = 0; i < self.cur_reifier.length(); i = i + 1 {
    if i > 0 {
      logger.write(", ")
    }
    match self.cur_reifier[i] {
      NamedOrBlankNodeRef::NamedNodeRef(n) => logger.write(n.to_string())
      NamedOrBlankNodeRef::BlankNodeRef(b) => logger.write("_:b")
    }
  }
  logger.write("]\n")

  // 6. 打印当前图
  logger.write("  Graph: ")
  match self.cur_graph {
    GraphNameRef::DefaultGraph => logger.write("DEFAULT")
    GraphNameRef::NamedNodeRef(n) => logger.write(n.to_string())
    GraphNameRef::BlankNodeRef(b) => logger.write("_:b")
  }
  logger.write("\n")
}

///|
pub struct TriGRecognizerContext {
  lexer_options : LexerOptions
  with_graph_name : Bool
  prefixes : Map[String, Iri]
}

///|
// fn TriGRecognizerContext::as_ctx(self : TriGRecognizerContext) -> RdfContext {
//   RdfContext ::TriGRecognizerContext(self)
// }

///|
// pub struct TriGLexerOptions {
//   mut base_iri : Iri?
// } derive(Debug)

///|
// fn TriGLexerOptions::TriGLexerOptions() -> TriGLexerOptions {
//   { base_iri: None }
// }

///|
pub fn TriGRecognizerContext::prefixes(
  self : TriGRecognizerContext,
) -> Map[String, Iri] {
  self.prefixes
}

///|
impl RuleRecognizer for TriGRecognizer with fn error_recovery_state(
  self : TriGRecognizer,
) -> TriGRecognizer {
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_reifier.clear()
  self.cur_graph = GraphNameRef::DefaultGraph
  self
}

///|
impl RuleRecognizer for TriGRecognizer with fn[DL : DebugLogger] debug_logger(
  self : TriGRecognizer,
  debug_logger : DL,
) {
  self.debug_logger = debug_logger
}

///|
impl RuleRecognizer for TriGRecognizer with fn recognize_next(
  self : TriGRecognizer,
  token : TokenOrLineJump[N3Token],
  context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> TriGRecognizer {
  // let token = token
  // debug(" Token: \{token}")
  self.debug_logger.info("Stack Depth: \{self.stack.length()}")
  // debug("Stack content: \{self.stack.to_string()}")
  self.debug_logger.info("Token stack: \{self.stack.to_string()}")
  let context = match context {
    RdfContext::TriGRecognizerContext(c) => c
    _ => abort("Invalid context for TriGRecognizer")
  }
  if self.stack.pop() is Some(rule) {
    match rule {
      TriGState::TriGDoc => {
        self.cur_graph = GraphNameRef::DefaultGraph
        self.stack.push(TriGState::TriGDoc)
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "base",
            ) => {
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "prefix",
            ) => {
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "version",
            ) => {
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="prefix", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="base", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(
            N3Token::LangTag(language="version", direction=None)
          ) => {
            self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "graph",
            ) &&
            context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self.stack.push(TriGState::GraphName)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("{")) if context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
          _ => {
            // 对于普通三元组，我们进入 TriplesOrGraph 状态
            // 注意：不要 push 后递归，而是直接改变栈顶
            // if self.stack.is_empty() {
            self.stack.push(TriGState::TriplesOrGraph)
            // } else {
            //   // 如果栈顶是 TriGDoc，我们可能需要替换它，或者在它上面压入新状态
            //   // 取决于你的设计。通常 TriGDoc 应该始终在栈底。
            //   self.stack.push(TriGState::TriplesOrGraph)
            // }
            self
            // self.stack.push(TriGState::TriplesOrGraph)
            // self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
        }
      }
      TriGState::ExpectDot =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          // 【关键修复】清空栈，只保留 TriGDoc
          let new_stack = []
          new_stack.push(TriGState::TriGDoc)
          self.stack = new_stack

          // 清空缓冲区
          self.cur_subject.clear()
          self.cur_predicate.clear()
          self.cur_object.clear()
          self.cur_reifier.clear()
          self
        } else {
          // 错误处理：期待句号但未得到
          errors.push(RuleRecognizerError::TripleMissingDot)
          // 恢复：重置到 TriGDoc
          let new_stack = []
          new_stack.push(TriGState::TriGDoc)
          self.stack = new_stack
          self.cur_subject.clear()
          self.cur_predicate.clear()
          self.cur_object.clear()
          self
        }
      // TriGState::ExpectDot =>
      //   // let _ = self.cur_subject.pop()
      //   if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) {
      //     // 【核心修复】语句结束，清空状态栈，只保留 TriGDoc
      //     self.stack.clear()
      //     self.stack.push(TriGState::TriGDoc)
      //     self
      //   } else {
      //     errors.push(RuleRecognizerError::TripleMissingDot)
      //     self.recognize_next(
      //       token,
      //       RdfContext ::TriGRecognizerContext(context),
      //       results,
      //       errors,
      //     )
      //   }
      TriGState::BaseExpectIri =>
        if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
          let iri_ref = Iri::new(iri)
          if self.lenient {
            // 宽松模式：直接解析，不检查有效性
            context.lexer_options.base_iri = Some(
              IriRef::parse_unchecked(iri_ref),
            )
          } else {
            // 严格模式：检查解析结果
            match IriRef::parse(iri_ref) {
              Ok(parsed_iri) =>
                context.lexer_options.base_iri = Some(parsed_iri)
              Err(e) =>
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Invalid BASE IRI: \{e.message()}",
                    SourcePosition::default(), // 如果有位置信息，应传入实际位置
                  ),
                )
              // 可以选择保持原状或设为 None，这里选择不更新 base_iri
            }
          }
          // 【修复】解析完 Base IRI 后，必须期待一个句号
          self.stack.push(TriGState::ExpectDot)
          self
        } else {
          self.error(errors, "The BASE keyword should be followed by an IRI")
        }
      TriGState::PrefixExpectPrefix =>
        match token {
          TokenOrLineJump::Token(N3Token::PrefixedName(prefix~, localx~, ..)) if localx.is_empty() => {
            self.stack.push(TriGState::PrefixExpectIri(name=prefix))
            self
          }
          // 情况 2: 某些 Lexer 可能将 p: 解析为 IRI (如果它看起来像相对 IRI)
          // 尝试提取前缀部分 (去掉末尾的 :)
          TokenOrLineJump::Token(N3Token::Iri(iri_str)) if iri_str.has_suffix(
              ":",
            ) => {
            let prefix = iri_str[0:iri_str.length() - 1]
            // 简单检查前缀是否合法 (仅包含字母数字等)
            self.debug_logger.info(
              "PrefixExpectPrefix: Matched Iri as prefix '\{prefix}:'",
            )
            self.stack.push(TriGState::PrefixExpectIri(name=prefix.to_owned()))
            self
          }

          // 情况 3: 兼容处理，如果 Token 是 PlainKeyword 且以 : 结尾 (极少见，但防错)
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if k.has_suffix(":") => {
            let prefix = k[0:k.length() - 1]
            self.debug_logger.info(
              "PrefixExpectPrefix: Matched Keyword as prefix '\{prefix}:'",
            )
            self.stack.push(TriGState::PrefixExpectIri(name=prefix.to_owned()))
            self
          }
          _ =>
            self.error(
              errors, "The PREFIX keyword should be followed by a prefix like 'ex:'",
            )
        }
      TriGState::PrefixExpectIri(name~) =>
        if token is TokenOrLineJump::Token(N3Token::Iri(iri)) {
          let iri = Iri::Iri(iri)
          context.prefixes.set(name, iri)
          self.stack.push(TriGState::ExpectDot)
          self
        } else {
          self.error(
            errors, "The PREFIX declaration should be followed by a prefix and its value as an IRI",
          )
        }
      TriGState::VersionExpectVersion =>
        if token is TokenOrLineJump::Token(N3Token::String(_)) {
          // 【修复】解析完 Version 后，必须期待一个句号
          self.stack.push(TriGState::ExpectDot)
          self
        } else {
          self.error(
            errors, "The VERSION keyword should be followed by a single quoted string like \"1.2\"",
          )
        }
      TriGState::TriplesOrGraph =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_subject.push(NamedNodeRef::new_unchecked(iri).as_enum())
            self.stack.push(
              TriGState::WrappedGraphOrPredicateObjectList(
                term=NamedNodeRef::new_unchecked(iri).as_enum(),
              ),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_subject.push(t.as_enum())

                self.stack.push(
                  TriGState::WrappedGraphOrPredicateObjectList(term=t.as_enum()),
                )
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.stack.push(
              TriGState::WrappedGraphOrPredicateObjectList(
                term=NamedNodeRef::new_unchecked(label).as_enum(),
              ),
            )
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
            // self.stack.push(TriGState::ExpectDot)
            self.stack.push(TriGState::MaybePredicateObjectList)
            self.stack.push(TriGState::SubjectReifiedTripleEnd)
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self
          }
          _ =>
            // println("Unhandled token in TriplesOrGraph: \{token}")
            self.error(errors, "TOKEN is not a valid subject or graph name")
        }
      // TriGState::WrappedGraphOrPredicateObjectList(term~) => {
      //   if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) &&
      //     context.with_graph_name {
      //     self.cur_graph = term.into_graph()

      //     self.stack.push(TriGState::WrappedGraph)
      //   } else {
      //     self.cur_graph = term.into_graph()
      //     self.stack.push(TriGState::ExpectDot)
      //     self.stack.push(TriGState::PredicateObjectList)
      //   }
      //   self
      //   // self.recognize_next(
      //   //   token,
      //   //   RdfContext ::TriGRecognizerContext(context),
      //   //   results,
      //   //   errors,
      //   // )
      // }
      TriGState::WrappedGraphOrPredicateObjectList(term~) => {
        self.debug_logger.info(
          "Entering WrappedGraphOrPredicateObjectList with token: \{token}",
        )
        self.debug_logger.info("=== Stack before: \{self.stack.to_string()}")

        // 1. 检查是否是命名图语法 { ... }
        if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) &&
          context.with_graph_name {
          self.debug_logger.info(
            "WrappedGraphOrPredicateObjectList: Graph branch",
          )
          self.cur_graph = term.into_graph()
          self.stack.push(TriGState::WrappedGraph)
          self.debug_logger.info(
            "Graph branch, stack after: \{self.stack.to_string()}",
          )
          self
        } else {
          self.debug_logger.info(
            "WrappedGraphOrPredicateObjectList: Predicate branch",
          )
          self.cur_graph = term.into_graph()

          // 2. 匹配谓词
          match token {
            TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
              self.debug_logger.info(
                "WrappedGraphOrPredicateObjectList: 'a' predicate",
              )
              self.cur_predicate.push(lwTYPE)
              self.stack.push(TriGState::ObjectsList)
              self.debug_logger.info(
                "After push ObjectsList, stack: \{self.stack.to_string()}",
              )
              self
            }
            TokenOrLineJump::Token(N3Token::Iri(iri)) => {
              self.debug_logger.info(
                "WrappedGraphOrPredicateObjectList: IRI predicate: \{iri}",
              )
              self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
              self.stack.push(TriGState::ObjectsList)
              self.debug_logger.info(
                "After push ObjectsList, stack: \{self.stack.to_string()}",
              )
              self
            }
            TokenOrLineJump::Token(
              N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
            ) =>
              match
                resolve_local_name(
                  prefix,
                  localx,
                  might_be_invalid_iri,
                  context.prefixes,
                ) {
                Ok(t) => {
                  self.cur_predicate.push(t)
                  self.stack.push(TriGState::ObjectsList)
                  self
                }
                Err(e) => self.error(errors, e)
              }

            // 【新增】处理非法谓词 Token（如直接出现的对象字面量）
            // 这通常意味着语法错误，例如 <s> <o> . (缺失谓词) 或 <s> 1 .
            _ => {
              self.debug_logger.info(
                "WrappedGraphOrPredicateObjectList: Invalid predicate token: \{token}",
              )
              // self.error(errors, "Expected a predicate (IRI or 'a') but found: \{token}")

              // 【容错处理】：如果当前 Token 看起来像是一个对象（如整数、字符串等），
              // 我们可以尝试跳过错误的谓词阶段，直接进入 Object 状态，以便解析器能继续消费后续 Token
              // 注意：这是一种激进的容错，标准解析器应直接报错停止
              match token {
                TokenOrLineJump::Token(
                  N3Token::Integer(_)
                  | N3Token::Decimal(_)
                  | N3Token::Double(_)
                  | N3Token::String(_)
                  | N3Token::LongString(_)
                  | N3Token::Punctuation("[" | "(" | "<<")
                ) => {
                  self.stack.push(TriGState::ObjectsList)
                  // 递归调用，让 ObjectsList -> Object 处理当前的 Token
                  self.recognize_next(
                    token,
                    RdfContext::TriGRecognizerContext(context),
                    results,
                    errors,
                  )
                }
                _ => self
              }
            }
          }
        }
      }
      TriGState::WrappedGraphBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(
            TriGState::WrappedGraphOrPredicateObjectList(
              term=BlankNode::default().as_ref().as_enum(),
            ),
          )
          self
        } else {
          self.cur_subject.push(BlankNode::default().as_ref().as_enum())
          self.stack.push(TriGState::ExpectDot)
          self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::SubjectBlankNodePropertyListEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
          self
        } else {
          errors.push(
            RuleRecognizerError::BlankNodePropertyListMissingEndBracket,
          )
          self.stack.push(TriGState::SubjectBlankNodePropertyListAfter)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::SubjectBlankNodePropertyListAfter =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation("." | "}")) {
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        } else {
          self.stack.push(TriGState::PredicateObjectList)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::SubjectCollectionBeginning =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          self.cur_subject.push(lwNIL.as_enum())
          self
        } else {
          let root = NamedOrBlankNodeRef::BlankNodeRef(
            BlankNode::default().as_ref(),
          )
          self.cur_subject.push(root)
          self.cur_subject.push(root)
          self.cur_predicate.push(lwFIRST)
          self.stack.push(TriGState::SubjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::SubjectCollectionPossibleEnd => {
        let old = match self.cur_subject.pop() {
          Some(node) => node
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let _ = self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          let _ = self.cur_predicate.pop()
          results.push(
            RdfStatement::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.into_owned().as_term(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self
        } else {
          let new = BlankNode::default()
          results.push(
            RdfStatement::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      }
      TriGState::WrappedGraph =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("{")) {
          self.stack.push(TriGState::WrappedGraphPossibleEnd)
          self.stack.push(TriGState::Triples)
          self
        } else {
          self.error(
            errors, "The GRAPH keyword should be followed by a graph name and a value in '{'",
          )
        }
      TriGState::WrappedGraphPossibleEnd =>
        // let _ = self.cur_subject.pop()
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("}")) => self
          TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
            self.stack.push(TriGState::WrappedGraphPossibleEnd)
            self.stack.push(TriGState::Triples)
            self
          }
          _ => {
            errors.push(RuleRecognizerError::TripleMissingDot)
            self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
        }
      TriGState::Triples =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("}")) => self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            // self.stack.push(TriGState::TriplesBlankNodePropertyListCurrent)
            self.stack.push(TriGState::PredicateObjectList) // <-- 添加这行
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_subject.push(NamedNodeRef::new_unchecked(iri).as_enum())
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_subject.push(t.as_enum())
                self.stack.push(TriGState::PredicateObjectList)
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(
                BlankNodeRef::new_unchecked(label),
              ),
            )
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
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          _ => self.error(errors, "TOKEN is not a valid RDF subject")
        }
      TriGState::TriplesBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.stack.push(TriGState::PredicateObjectList)
          self
        } else {
          self.stack.push(TriGState::SubjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::GraphName =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_graph = GraphNameRef::NamedNodeRef(
              NamedNodeRef::new_unchecked(iri),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_graph = GraphNameRef::NamedNodeRef(t)
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_graph = GraphNameRef::BlankNodeRef(
              BlankNodeRef::new_unchecked(label),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            // 创建匿名空白节点作为主语
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          _ => self.error(errors, "TOKEN is not a valid graph name")
        }
      TriGState::GraphNameAnonEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.cur_graph = GraphNameRef::BlankNodeRef(
            BlankNode::default().as_ref(),
          )
          self
        } else {
          self.error(
            errors, "Anonymous blank node with a property list are not allowed as graph name",
          )
        }
      TriGState::MaybePredicateObjectList => {
        if token != TokenOrLineJump::Token(N3Token::Punctuation(".")) {
          self.stack.push(TriGState::PredicateObjectList)
        }
        self
        // self.recognize_next(
        //   token,
        //   RdfContext ::TriGRecognizerContext(context),
        //   results,
        //   errors,
        // )
      }
      TriGState::PredicateObjectList => {
        self.stack.push(TriGState::PredicateObjectListEnd)
        self.stack.push(TriGState::Object) // ✅ 改为直接 push Object
        // self.stack.push(TriGState::Verb)
        self
        // self.recognize_next(
        //   token,
        //   RdfContext ::TriGRecognizerContext(context),
        //   results,
        //   errors,
        // )
      }
      TriGState::PredicateObjectListEnd => {
        // let _ = self.cur_predicate.pop()
        debug(
          "PredicateObjectListEnd: token=\{token}, expected_dot=\{TokenOrLineJump::Token(N3Token::Punctuation("."))}",
        )
        debug(
          "Equal? \{token == TokenOrLineJump::Token(N3Token::Punctuation("."))}",
        )
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation(",")) => {
            self.stack.push(TriGState::Object) // 改，直接 push Object
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation(";")) => {
            self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation(".")) => {
            self.stack.clear()
            self.stack.push(TriGState::TriGDoc)
            self.cur_subject.clear()
            self.cur_predicate.clear()
            self.cur_object.clear()
            self
          }
          _ =>
            self.error(
              errors, "Expected ';' or '.' after predicate-object list",
            )
        }
      }
      TriGState::PredicateObjectListPossibleContinuation =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation(";")) {
          self.stack.push(TriGState::PredicateObjectListPossibleContinuation)
          self
        } else if token
          is TokenOrLineJump::Token(
            N3Token::Punctuation("." | "}" | "]" | "|}")
          ) {
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        } else {
          self.stack.push(TriGState::PredicateObjectListEnd)
          self.stack.push(TriGState::Object)
          self.stack.push(TriGState::Verb)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      // self.stack.push(TriGState::AnnotationEnd(with_reifier=false))
      // self.set_state(TriGState::Object) // 替换栈顶
      TriGState::ObjectsList => {
        // self.error(errors, "Unexpected state: ObjectsList")
        // let _ = self.stack.pop()

        self.stack.push(TriGState::Object)
        self.debug_logger.info(
          "ObjectsList: after replace, stack: \{self.stack.to_string()}",
        )
        // self
        self.recognize_next(
          token,
          RdfContext::TriGRecognizerContext(context),
          results,
          errors,
        )
      }
      TriGState::AnnotationBlock(with_reifier~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation(",")) => {
            let _ = self.cur_object.pop()
            if with_reifier {
              let _ = self.cur_reifier.pop()
            }
            self.stack.push(TriGState::AnnotationBlock(with_reifier=false))
            self.stack.push(TriGState::Object)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("~")) => {
            let cur_sub = match self.cur_subject.last() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            let cur_pred = match self.cur_predicate.last() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: predicate stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            let cur_obj = match self.cur_object.last() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: object stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }

            self.stack.push(TriGState::AnnotationBlock(with_reifier=true))
            self.stack.push(
              TriGState::Reifier(
                triple=TripleRef::TripleRef(cur_sub, cur_pred, cur_obj).into_owned(),
              ),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("{|")) => {
            let cur_sub = match self.cur_subject.last() {
              Some(s) => s
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: subject stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            let cur_pred = match self.cur_predicate.last() {
              Some(p) => p
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: predicate stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            let cur_obj = match self.cur_object.last() {
              Some(o) => o
              None => {
                errors.push(
                  RuleRecognizerError::SyntaxError(
                    "Internal error: object stack empty",
                    SourcePosition::default(),
                  ),
                )
                return self
              }
            }
            let reifier = if with_reifier {
              match self.cur_reifier.last() {
                Some(r) => r
                None => {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "Internal error: reifier stack empty",
                      SourcePosition::default(),
                    ),
                  )
                  return self
                }
              }
            } else {
              let reifier = BlankNode::default()
              results.push(
                RdfStatement::Quad(
                  Quad::Quad(
                    reifier.as_enum(),
                    lwREIFIES.into_owned(),
                    TermRef::TripleRef(
                      TripleRef::TripleRef(cur_sub, cur_pred, cur_obj),
                    ).into_owned(),
                    self.cur_graph.into_owned(),
                  ),
                ),
              )
              reifier.as_enum().as_ref()
            }
            self.cur_subject.push(reifier)
            self.stack.push(TriGState::AnnotationBlock(with_reifier~))
            self.stack.push(TriGState::PredicateObjectList)
            self
          }
          _ => {
            let _ = self.cur_object.pop()
            if with_reifier {
              let _ = self.cur_reifier.pop()
            }
            self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
        }
      TriGState::AnnotationEnd(with_reifier~) => {
        let _ = self.cur_subject.pop()
        self.stack.push(TriGState::AnnotationEnd(with_reifier~))
        if token == TokenOrLineJump::Token(N3Token::Punctuation("|}")) {
          self
        } else {
          self
          .error(errors, "Annotations should end with '|}'")
          .recognize_next(
            token,
            RdfContext::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::Verb =>
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword("a")) => {
            self.cur_predicate.push(lwTYPE)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_predicate.push(NamedNodeRef::new_unchecked(iri))
            self.emit_quad(results)
            self.stack.push(TriGState::PredicateObjectListEnd)
            self
            // self.set_state(TriGState::PredicateObjectListEnd)
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_predicate.push(t)
                self
              }
              Err(e) => self.error(errors, e)
            }
          _ => self.error(errors, "TOKEN is not a valid predicate")
        }
      TriGState::Object => {
        self.debug_logger.info("Entering Object state with token: \{token}")
        // let in_collection = self.stack.contains(
        //   TriGState::ObjectCollectionPossibleEnd,
        // )

        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.debug_logger.info("Object: IRI branch, pushing object")

            self.cur_object.push(
              TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(iri)),
            )
            self.emit_quad(results)
            // ✅ 弹出 Object，进入 PredicateObjectListEnd
            // let _ = self.stack.pop() // 弹出 Object
            // self.set_state(TriGState::PredicateObjectListEnd)
            self.stack.push(TriGState::PredicateObjectListEnd)
            self.debug_logger.info(
              "Object: after pop, stack: \{self.stack.to_string()}",
            )

            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.debug_logger.info(
                  "Object: PrefixedName branch, pushing object",
                )
                self.cur_object.push(TermRef::NamedNodeRef(t))

                self.emit_quad(results)
                // let _ = self.stack.pop()

                // self.set_state(TriGState::PredicateObjectListEnd)
                self.stack.push(TriGState::PredicateObjectListEnd)
                self.debug_logger.info(
                  "Object: after pop, stack: \{self.stack.to_string()}",
                )
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_object.push(
              TermRef::NamedNodeRef(NamedNodeRef::new_unchecked(label)),
            )
            self.emit_quad(results)
            // let _ = self.stack.pop()

            // self.set_state(TriGState::PredicateObjectListEnd)
            self.stack.push(TriGState::PredicateObjectListEnd)
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
          TokenOrLineJump::Token(N3Token::String(value))
          | TokenOrLineJump::Token(N3Token::LongString(value)) => {
            self.stack.push(TriGState::LiteralPossibleSuffix(value~, emit=true))
            self
          }
          TokenOrLineJump::Token(N3Token::Integer(v)) => {
            let v = try @string.parse_int(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntVar(value.to_string()),
                    lwINTEGER,
                  ).as_term(),
                )
                self.emit_quad(results)
                if self.in_collection {
                  // ✅ 在集合中：进入 ObjectCollectionPossibleEnd
                  self.stack.push(TriGState::ObjectCollectionPossibleEnd)
                } else {
                  // ✅ 不在集合中：进入 PredicateObjectListEnd
                  self.stack.push(TriGState::PredicateObjectListEnd)
                }
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Decimal(v)) => {
            let v = try @string.parse_double(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::DecimalVar(value.to_string()),
                    lwDECIMAL,
                  ).as_term(),
                )
                self.emit_quad(results)
                // let _ = self.stack.pop()

                self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】修复缺失的状态压入

                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Double(v)) => {
            let v = try @string.parse_double(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::DoubleVar(value.to_string()),
                    lwDOUBLE,
                  ).as_term(),
                )
                self.emit_quad(results)
                // let _ = self.stack.pop()

                self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】修复缺失的状态压入

                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            // let _ = self.stack.pop()

            self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】修复缺失的状态压入

            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::FalseVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            // let _ = self.stack.pop()

            self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】修复缺失的状态压入

            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=true))
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=false))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=false))
            self
          }
          TokenOrLineJump::Token(
            N3Token::Punctuation("." | ";" | "," | "]" | "}" | "|}")
          ) => {
            self.debug_logger.info(
              "Object: Termination token detected: \{token}. Treating as missing object.",
            )

            // errors.push(
            //   RuleRecognizerError::SyntaxError(
            //     "Expected an object but found termination token",
            //     SourcePosition::default(),
            //   ),
            // )

            // 弹出 Object，准备让 PredicateObjectListEnd 处理这个终止符
            // let _ = self.stack.pop() 
            self.stack.push(TriGState::PredicateObjectListEnd)
            self.debug_logger.info(
              "Object: after push PredicateObjectListEnd, stack: \{self.stack.to_string()}",
            )

            // 递归调用，让 PredicateObjectListEnd 处理当前的终止符 token
            self.recognize_next(
              token,
              RdfContext::TriGRecognizerContext(context),
              results,
              errors,
            )
          }
          // TokenOrLineJump::Token(N3Token::Punctuation("-")) => {
          //   self.debug_logger.info("Object: Detected negative sign '-'")
          //   self.stack.push(TriGState::NegativeNumberSign)
          //   self
          // }
          _ => self.error(errors, "TOKEN is not a valid RDF object")
        }
      }
      TriGState::ObjectBlankNodePropertyListCurrent =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self.cur_object.push(
            TermRef::BlankNodeRef(BlankNode::default().as_ref()),
          )
          self.emit_quad(results)
          self
        } else {
          self.cur_subject.push(
            NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
          )
          self.stack.push(TriGState::ObjectBlankNodePropertyListEnd)
          self.stack.push(TriGState::PredicateObjectList)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::ObjectBlankNodePropertyListEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          let subject = match self.cur_subject.pop() {
            Some(s) => s
            None => {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "Internal error: subject stack is empty",
                  SourcePosition::default(),
                ),
              )
              return self
            }
          }

          let blank_ref = match subject {
            NamedOrBlankNodeRef::BlankNodeRef(b) => b
            _ => abort("subject should be a blank node")
          }
          self.cur_object.push(TermRef::BlankNodeRef(blank_ref))
          self.emit_quad(results)
          self
        } else {
          self.error(errors, "blank node property lists should end with a ']'")
        }
      TriGState::ObjectCollectionBeginning =>
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          self.in_collection = false // ✅ 重置

          self.cur_object.push(TermRef::NamedNodeRef(lwNIL))
          self.emit_quad(results)
          // let _ = self.stack.pop()
          self.stack.push(TriGState::PredicateObjectListEnd)

          self
        } else {
          self.debug_logger.info(
            "ObjectCollectionBeginning: non-empty collection, first element: \{token}",
          )
          self.in_collection = true // ✅ 设置

          let root = BlankNode::default()
          self.cur_object.push(TermRef::BlankNodeRef(root.as_ref()))
          self.emit_quad(results)
          self.cur_subject.push(
            NamedOrBlankNodeRef::BlankNodeRef(root.as_ref()),
          )
          self.cur_predicate.push(
            NamedNodeRef::NamedNodeRef(lwFIRST.to_string()),
          )
          let _ = self.stack.pop()

          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::ObjectCollectionPossibleEnd => {

        // if token.is_eof() || token.is_dot() || token.is_rbracket() || token.is_rbrace() || token.is_comma() || token.is_semicolon() || token.is_newline() || token.is_eol() || token.is_eof() {
        let old = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let _ = self.cur_object.pop()
        if token is TokenOrLineJump::Token(N3Token::Punctuation(")")) {
          self.debug_logger.info(
            "ObjectCollectionPossibleEnd: end of collection",
          )
          self.in_collection = false // ✅ 重置

          let _ = self.cur_predicate.pop()
          results.push(
            RdfStatement::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          // ✅ 弹出自己，进入 PredicateObjectListEnd
          let _ = self.stack.pop()
          self.stack.push(TriGState::PredicateObjectListEnd)
          self
        } else {
          self.debug_logger.info("ObjectCollectionPossibleEnd: more elements")
          let new = BlankNode::default()
          results.push(
            RdfStatement::Quad(
              Quad::Quad(
                old.into_owned(),
                lwREST.into_owned(),
                lwNIL.as_term().into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_subject.push(NamedOrBlankNodeRef::BlankNodeRef(new.as_ref()))
          self.stack.push(TriGState::ObjectCollectionPossibleEnd)
          self.stack.push(TriGState::Object)
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
        // }
      }
      TriGState::LiteralPossibleSuffix(value~, emit~) =>
        match token {
          TokenOrLineJump::Token(N3Token::LangTag(language~, direction~)) => {
            self.cur_object.push(
              if direction is Some(direction) {
                let lang_tag = try
                  LanguageTag::from_str(language.to_lower()) |> Ok
                catch {
                  e => Err(e)
                }
                let resolved_lang_tag = match lang_tag {
                  Ok(tag) => tag
                  Err(e) => {
                    errors.push(
                      RuleRecognizerError::SyntaxError(
                        e.to_string(),
                        SourcePosition::default(),
                      ),
                    )
                    return self
                  }
                }
                TermRef::LiteralRef(
                  LiteralRef::new_directional_language_tagged_literal_unchecked(
                    value, resolved_lang_tag, direction,
                  ),
                )
              } else {
                TermRef::LiteralRef(
                  Literal::new_language_tagged_literal_unchecked(
                    value,
                    language.to_lower(),
                  ).as_ref(),
                )
              },
            )
            if emit {
              self.emit_quad(results)
              self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】
            }
            self
          }
          // TokenOrLineJump::Token(N3Token::LangTag(language~,..)) => {
          //   self.cur_object.push(
          //     TermRef::LiteralRef(
          //       LiteralRef::new_language_tagged_literal_unchecked(
          //         value,
          //         language.to_lower(),
          //       ),
          //     ),
          //   )
          //   if emit {
          //     self.emit_quad(results)
          //   }
          //   self
          // }
          TokenOrLineJump::Token(N3Token::Punctuation("^^")) => {
            self.stack.push(TriGState::LiteralPossibleSuffix(value~, emit~))
            self
          }
          _ => {
            self.cur_object.push(
              LiteralRef::new_simple_literal(value).as_term(),
            )
            if emit {
              self.emit_quad(results)
              self.stack.push(TriGState::PredicateObjectListEnd) // ⚠️ 【新增】修复缺失的状态压入
            }
            self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
        }
      TriGState::LiteralExpectDatatype(value~, emit~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(datatype)) => {
            if !self.lenient && datatype == lwLANG_STRING.to_string() {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "The datatype of a literal without a language tag must not be rdf:langString",
                  SourcePosition::default(),
                ),
              )
            }
            if !self.lenient && datatype == lwDIR_LANG_STRING.to_string() {
              errors.push(
                RuleRecognizerError::SyntaxError(
                  "The datatype of a literal without a base direction must not be rdf:dirLangString",
                  SourcePosition::default(),
                ),
              )
            }
            let datatype = NamedNodeRef::new_unchecked(datatype)
            let data_value = datatype.into_datatype(value)
            self.cur_object.push(
              TermRef::LiteralRef(
                LiteralRef::new_typed_literal(data_value, datatype),
              ),
            )
            if emit {
              self.emit_quad(results)
            }
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                if !self.lenient && t == lwLANG_STRING {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a language tag must not be rdf:langString",
                      SourcePosition::default(),
                    ),
                  )
                }
                if !self.lenient && t == lwDIR_LANG_STRING {
                  errors.push(
                    RuleRecognizerError::SyntaxError(
                      "The datatype of a literal without a base direction must not be rdf:dirLangString",
                      SourcePosition::default(),
                    ),
                  )
                }
                // let datatype = t
                let data_value = t.into_datatype(value)
                self.cur_object.push(
                  TermRef::LiteralRef(
                    LiteralRef::new_typed_literal(data_value, t),
                  ),
                )
                if emit {
                  self.emit_quad(results)
                }
                self
              }
              Err(e) => self.error(errors, e)
            }
          _ =>
            self.error(errors, "Expecting a datatype IRI after ^^, found TOKEN")
          // self
          // .recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      TriGState::SubjectReifiedTripleEnd => {
        let reifier = match self.cur_reifier.pop() {
          Some(r) => r
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: reifier stack empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        self.cur_subject.push(reifier)
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self.error(
            errors, "Expecting '>>' to close a reified triple, found TOKEN",
          )
          // .recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      }
      TriGState::ObjectReifiedTripleEnd(emit~) => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack is empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }

        let blank_ref = match subject {
          NamedOrBlankNodeRef::BlankNodeRef(b) => TermRef::BlankNodeRef(b)
          _ => abort("Subject must be a blank node")
        }
        self.cur_object.push(blank_ref)
        if emit {
          self.emit_quad(results)
        }
        if token == TokenOrLineJump::Token(N3Token::Punctuation(">>")) {
          self
        } else {
          self.error(
            errors, "Expecting '>>' to close a reified triple, found TOKEN",
          )
          // .recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      }
      TriGState::TripleTermEnd(emit~) => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack empty in TripleTermEnd",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let predicate = match self.cur_predicate.pop() {
          Some(p) => p
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: predicate stack empty in TripleTermEnd",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let object = match self.cur_object.pop() {
          Some(o) => o
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: object stack empty in TripleTermEnd",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let triple = TripleRef::TripleRef(subject, predicate, object)

        self.cur_object.push(TermRef::TripleRef(triple))
        if emit {
          self.emit_quad(results)
        }
        if token == TokenOrLineJump::Token(N3Token::Punctuation(")>>")) {
          self
        } else {
          self
          .error(errors, "Expecting ')>>' to close a triple term, found TOKEN")
          .recognize_next(
            token,
            RdfContext::TriGRecognizerContext(context),
            results,
            errors,
          )
        }
      }
      TriGState::EndOfReifiedTripleBeforeReifier => {
        let subject = match self.cur_subject.pop() {
          Some(s) => s
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: subject stack empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let predicate = match self.cur_predicate.pop() {
          Some(p) => p
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: predicate stack empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let object = match self.cur_object.pop() {
          Some(o) => o
          None => {
            errors.push(
              RuleRecognizerError::SyntaxError(
                "Internal error: object stack empty",
                SourcePosition::default(),
              ),
            )
            return self
          }
        }
        let triple = TripleRef::TripleRef(subject, predicate, object)

        if token == TokenOrLineJump::Token(N3Token::Punctuation("~")) {
          self.stack.push(TriGState::Reifier(triple=triple.into_owned()))
          self
        } else {
          let reifier = BlankNode::default()
          results.push(
            RdfStatement::Quad(
              Quad::Quad(
                reifier.as_enum(),
                lwREIFIES.into_owned(),
                TermRef::TripleRef(triple).into_owned(),
                self.cur_graph.into_owned(),
              ),
            ),
          )
          self.cur_reifier.push(reifier.as_enum().as_ref())
          self
          // self.recognize_next(
          //   token,
          //   RdfContext ::TriGRecognizerContext(context),
          //   results,
          //   errors,
          // )
        }
      }
      TriGState::Reifier(triple~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            let reifier = NamedNodeRef::new_unchecked(iri)
            results.push(
              RdfStatement::Quad(
                Quad::Quad(
                  reifier.as_enum().into_owned(),
                  lwREIFIES.into_owned(),
                  triple.as_enum(),
                  self.cur_graph.into_owned(),
                ),
              ),
            )
            self.cur_reifier.push(reifier.as_enum())
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(reifier) => {
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum().into_owned(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum())
                self
              }
              Err(e) => {
                let reifier = BlankNode::default()
                results.push(
                  RdfStatement::Quad(
                    Quad::Quad(
                      reifier.as_enum(),
                      lwREIFIES.into_owned(),
                      triple.as_enum(),
                      self.cur_graph.into_owned(),
                    ),
                  ),
                )
                self.cur_reifier.push(reifier.as_enum().as_ref())
                self.error(errors, e)
              }
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(bnode)) => {
            let reifier = BlankNodeRef::new_unchecked(bnode)
            results.push(
              RdfStatement::Quad(
                Quad::Quad(
                  reifier.as_enum().into_owned(),
                  lwREIFIES.into_owned(),
                  triple.as_enum(),
                  self.cur_graph.into_owned(),
                ),
              ),
            )
            self.cur_reifier.push(reifier.as_enum())
            self
          }
          _ => {
            let reifier = BlankNode::default()
            results.push(
              RdfStatement::Quad(
                Quad::Quad(
                  reifier.as_enum(),
                  lwREIFIES.into_owned(),
                  triple.as_enum(),
                  self.cur_graph.into_owned(),
                ),
              ),
            )
            self.cur_reifier.push(reifier.as_enum().as_ref())
            self
            // self.recognize_next(
            //   token,
            //   RdfContext ::TriGRecognizerContext(context),
            //   results,
            //   errors,
            // )
          }
        }
      TriGState::ReifiedTripleSubject(is_reified~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::QuotedAnonEnd)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_subject.push(
              NamedOrBlankNodeRef::NamedNodeRef(
                NamedNodeRef::new_unchecked(iri),
              ),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_subject.push(t.as_enum())
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_subject.push(NamedNodeRef::new_unchecked(label).as_enum())
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) if is_reified => {
            self.stack.push(TriGState::SubjectReifiedTripleEnd)
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self
          }
          _ =>
            self.error(
              errors, "TOKEN is not a valid RDF quoted triple subject: TOKEN",
            )
        }
      TriGState::ReifiedTripleObject(is_reified~) =>
        match token {
          TokenOrLineJump::Token(N3Token::Punctuation("[")) => {
            self.cur_object.push(
              TermRef::BlankNodeRef(BlankNode::default().as_ref()),
            )
            self.stack.push(TriGState::QuotedAnonEnd)
            self
          }
          TokenOrLineJump::Token(N3Token::Iri(iri)) => {
            self.cur_object.push(
              TermRef::BlankNodeRef(BlankNodeRef::new_unchecked(iri)),
            )
            self
          }
          TokenOrLineJump::Token(
            N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~)
          ) =>
            match
              resolve_local_name(
                prefix,
                localx,
                might_be_invalid_iri,
                context.prefixes,
              ) {
              Ok(t) => {
                self.cur_object.push(t.as_term())
                self
              }
              Err(e) => self.error(errors, e)
            }
          TokenOrLineJump::Token(N3Token::BlankNodeLabel(label)) => {
            self.cur_object.push(BlankNodeRef::new_unchecked(label).as_term())
            self
          }
          TokenOrLineJump::Token(N3Token::String(value)) => {
            self.stack.push(
              TriGState::LiteralPossibleSuffix(value~, emit=false),
            )
            self
          }
          TokenOrLineJump::Token(N3Token::Integer(v)) => {
            let v = try @string.parse_int(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::IntVar(value.to_string()),
                    lwINTEGER,
                  ).as_term(),
                )
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Decimal(v)) => {
            let v = try @string.parse_double(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::DecimalVar(value.to_string()),
                    lwDECIMAL,
                  ).as_term(),
                )
                self.emit_quad(results)
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::Double(v)) => {
            let v = try @string.parse_double(v) |> Ok catch {
              e => Err(e)
            }
            match v {
              Ok(value) => {
                self.cur_object.push(
                  LiteralRef::new_typed_literal(
                    VarDataType::DoubleVar(value.to_string()),
                    lwDOUBLE,
                  ).as_term(),
                )
                self.emit_quad(results)
                self
              }
              Err(e) => self.error(errors, e.to_string())
            }
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("true")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::TrueVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword("false")) => {
            self.cur_object.push(
              LiteralRef::new_typed_literal(VarDataType::FalseVar, lwBOOLEAN).as_term(),
            )
            self.emit_quad(results)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<(")) => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=false))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=false))
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("<<")) if is_reified => {
            self.stack.push(TriGState::ObjectReifiedTripleEnd(emit=false))
            self.stack.push(TriGState::EndOfReifiedTripleBeforeReifier)
            self.stack.push(TriGState::ReifiedTripleObject(is_reified=true))
            self.stack.push(TriGState::Verb)
            self.stack.push(TriGState::ReifiedTripleSubject(is_reified=true))
            self
          }
          _ =>
            self.error(errors, "TOKEN is not a valid RDF quoted triple object")
        }
      TriGState::QuotedAnonEnd =>
        if token == TokenOrLineJump::Token(N3Token::Punctuation("]")) {
          self
        } else {
          self.error(
            errors, "Anonymous blank node with a property list are not allowed in quoted triples",
          )
        }
      TriGState::ExpectAtKeyword =>
        match token {
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "base",
            ) => {
            self.stack.push(TriGState::BaseExpectIri)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "prefix",
            ) => {
            self.stack.push(TriGState::PrefixExpectPrefix)
            self
          }
          TokenOrLineJump::Token(N3Token::PlainKeyword(k)) if eq_ignore_ascii_case(
              k, "version",
            ) => {
            self.stack.push(TriGState::VersionExpectVersion)
            self
          }
          TokenOrLineJump::Token(N3Token::Punctuation("{")) if context.with_graph_name => {
            self.stack.push(TriGState::WrappedGraph)
            self

            // self.recognize_next(token, RdfContext ::TriGRecognizerContext(context), results, errors)
          }
          _ =>
            self.error(
              errors, "Expected 'base', 'prefix', or 'version' after '@'",
            )
        }
      // TriGState::NegativeNumberSign =>
      //   self.error(
      //     errors, "Unexpected negative sign in this context. Negative numbers should be lexed as a single numeric literal token.",
      //   )
    }

    //     _ => {
    //   self.stack.push(TriGState::TriplesOrGraph)
    //   self.recognize_next(token, RdfContext ::TriGRecognizerContext(context), results, errors)
    // }
  } else if token == TokenOrLineJump::Token(N3Token::Punctuation(".")) ||
    token == TokenOrLineJump::Token(N3Token::Punctuation("}")) {
    self.stack.push(TriGState::TriGDoc)
    self
  } else {
    self
  }
}

///|
impl RuleRecognizer for TriGRecognizer with fn recognize_end(
  self : TriGRecognizer,
  _context : RdfContext,
  results : Array[RdfStatement],
  errors : Array[RuleRecognizerError],
) -> Unit {
  self.debug_logger.info(
    "TriGRecognizer :: recognize_end \{self.stack.to_string()}",
  )
  match self.stack {
    [] | [TriGState::TriGDoc] => {
      debug_assert(() => self.cur_subject.is_empty())
      debug_assert(() => self.cur_predicate.is_empty())
      debug_assert(() => self.cur_object.is_empty())
    }
    [.., TriGState::LiteralPossibleSuffix(value~, emit=true)] => {
      self.cur_object.push(LiteralRef::new_simple_literal(value).as_term())
      self.emit_quad(results)
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Triples should be followed by a dot",
          SourcePosition::default(),
        ),
      )
    }
    _ =>
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Unexpected end",
          SourcePosition::default(),
        ),
      )
  }
}

///|
impl RuleRecognizer for TriGRecognizer with fn lexer_options(
  context : RdfContext,
) -> LexerOptions? {
  let lexer_opts : LexerOptions? = match context {
    RdfContext::TriGRecognizerContext(ctx) => Some(ctx.lexer_options)
    _ => None
  }
  lexer_opts
}

///|
pub fn TriGRecognizer::new_parser(
  data : Array[Byte],
  is_ending : Bool,
  with_graph_name : Bool,
  lenient : Bool,
  base_iri : Iri?,
  prefixes : Map[String, Iri],
  debug_logger? : &DebugLogger = make_mute_logger(),
) -> Parser[RdfLexer, TriGRecognizer] {
  Parser::Parser(
    Lexer::Lexer(
      RdfLexer::RdfLexer(RdfLexerMode::Turtle, lenient),
      data,
      is_ending,
      MIN_BUFFER_SIZE,
      MAX_BUFFER_SIZE,
      Some(b"#"),
      0,
      0,
    ),
    {
      stack: [TriGState::TriGDoc],
      cur_subject: [],
      cur_predicate: [],
      cur_object: [],
      cur_graph: GraphName::DefaultGraph.as_ref(),
      cur_reifier: [],
      lenient,
      debug_logger, // <-- 添加这一行，具体值需根据 TriGRecognizer 定义调整，可能是 None 或 DebugLogger::default()
      in_collection: false,
    },
    RdfContext::TriGRecognizerContext({
      with_graph_name,
      prefixes,
      lexer_options: { base_iri, },
    }),
  )
}

///|
fn TriGRecognizer::error(
  self : TriGRecognizer,
  errors : Array[RuleRecognizerError],
  msg : String,
) -> TriGRecognizer {
  errors.push(RuleRecognizerError::SyntaxError(msg, SourcePosition::default()))
  self.stack.clear()
  self.cur_subject.clear()
  self.cur_predicate.clear()
  self.cur_object.clear()
  self.cur_graph = GraphName::DefaultGraph.as_ref()
  self
}

///|

///|
fn TriGRecognizer::emit_quad(
  self : TriGRecognizer,
  results : Array[RdfStatement],
) -> Unit {
  let subject = match self.cur_subject.last() {
    Some(s) => s
    None => return // 或者报错，例如: abort("Internal error: subject stack empty in emit_quad")
  }
  let predicate = match self.cur_predicate.last() {
    Some(p) => p
    None => return
  }
  let object = match self.cur_object.last() {
    Some(o) => o
    None => return
  }

  results.push(
    RdfStatement::Quad(
      Quad::Quad(
        subject.into_owned(),
        predicate.into_owned(),
        object.into_owned(),
        self.cur_graph.into_owned(),
      ),
    ),
  )
}

///|
enum TriGState {
  ExpectAtKeyword
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
  WrappedGraphOrPredicateObjectList(term~ : NamedOrBlankNodeRef)
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
  // NegativeNumberSign
} derive(Debug, Eq)

///|
impl Show for TriGState with fn output(self, logger : &Logger) -> Unit {
  match self {
    TriGState::TriGDoc => logger.write("TriGDoc")
    TriGState::Object => logger.write("Object")
    TriGState::PredicateObjectList => logger.write("PredicateObjectList")
    TriGState::PredicateObjectListEnd => logger.write("PredicateObjectListEnd")
    TriGState::ObjectsList => logger.write("ObjectsList")
    TriGState::Verb => logger.write("Verb")
    TriGState::TriplesOrGraph => logger.write("TriplesOrGraph")
    TriGState::ExpectDot => logger.write("ExpectDot")
    TriGState::BaseExpectIri => logger.write("BaseExpectIri")
    TriGState::PrefixExpectPrefix => logger.write("PrefixExpectPrefix")
    TriGState::PrefixExpectIri(name~) =>
      logger.write("PrefixExpectIri(\{name})")
    TriGState::VersionExpectVersion => logger.write("VersionExpectVersion")
    TriGState::WrappedGraph => logger.write("WrappedGraph")
    TriGState::GraphName => logger.write("GraphName")
    TriGState::ExpectAtKeyword => logger.write("ExpectAtKeyword")
    TriGState::LiteralPossibleSuffix(..) =>
      logger.write("LiteralPossibleSuffix")
    TriGState::SubjectCollectionBeginning =>
      logger.write("SubjectCollectionBeginning")
    TriGState::ObjectCollectionBeginning =>
      logger.write("ObjectCollectionBeginning")
    TriGState::WrappedGraphOrPredicateObjectList(_) =>
      logger.write("WrappedGraphOrPredicateObjectList")
    TriGState::AnnotationBlock(_) => logger.write("AnnotationBlock")
    TriGState::Reifier(_) => logger.write("Reifier")
    TriGState::ReifiedTripleSubject(_) => logger.write("ReifiedTripleSubject")
    TriGState::ReifiedTripleObject(_) => logger.write("ReifiedTripleObject")
    TriGState::ObjectReifiedTripleEnd(_) =>
      logger.write("ObjectReifiedTripleEnd")
    TriGState::SubjectReifiedTripleEnd =>
      logger.write("SubjectReifiedTripleEnd")
    TriGState::EndOfReifiedTripleBeforeReifier =>
      logger.write("EndOfReifiedTripleBeforeReifier")
    TriGState::MaybePredicateObjectList =>
      logger.write("MaybePredicateObjectList")
    TriGState::PredicateObjectListPossibleContinuation =>
      logger.write("PredicateObjectListPossibleContinuation")
    TriGState::ObjectBlankNodePropertyListCurrent =>
      logger.write("ObjectBlankNodePropertyListCurrent")
    TriGState::ObjectBlankNodePropertyListEnd =>
      logger.write("ObjectBlankNodePropertyListEnd")
    TriGState::ObjectCollectionPossibleEnd =>
      logger.write("ObjectCollectionPossibleEnd")
    TriGState::SubjectBlankNodePropertyListEnd =>
      logger.write("SubjectBlankNodePropertyListEnd")
    TriGState::SubjectBlankNodePropertyListAfter =>
      logger.write("SubjectBlankNodePropertyListAfter")
    TriGState::WrappedGraphBlankNodePropertyListCurrent =>
      logger.write("WrappedGraphBlankNodePropertyListCurrent")
    TriGState::Triples => logger.write("Triples")
    TriGState::TriplesBlankNodePropertyListCurrent =>
      logger.write("TriplesBlankNodePropertyListCurrent")
    TriGState::GraphNameAnonEnd => logger.write("GraphNameAnonEnd")
    TriGState::QuotedAnonEnd => logger.write("QuotedAnonEnd")
    TriGState::AnnotationEnd(_) => logger.write("AnnotationEnd")
    TriGState::LiteralExpectDatatype(..) =>
      logger.write("LiteralExpectDatatype")
    TriGState::TripleTermEnd(_) => logger.write("TripleTermEnd")
    TriGState::SubjectCollectionPossibleEnd =>
      logger.write("SubjectCollectionPossibleEnd")
    TriGState::WrappedGraphPossibleEnd =>
      logger.write("WrappedGraphPossibleEnd")
    // TriGState::NegativeNumberSign => logger.write("NegativeNumberSign")
  }
}

///|
fn TriGRecognizer::replace_top(
  stack : Array[TriGState],
  new_state : TriGState,
) -> Array[TriGState] {
  let _ = stack.pop()
  stack.push(new_state)
  stack
}

///|
fn TriGRecognizer::set_state(
  self : TriGRecognizer,
  new_state : TriGState,
) -> TriGRecognizer {
  // let _ = self.stack.pop() // 弹出当前状态
  self.stack.push(new_state) // 压入新状态
  self
}
// impl Show for TriGState with fn output(self, logger : &Logger) -> Unit {
//   logger.write("TriGState: ")
//   logger.write_object(self)

// }
