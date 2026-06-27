///|
fn N3Recognizer::handle_term_token(
  self : N3Recognizer,
  token : LocatedTokenOrLineJump,
  context : RdfContext,
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  match token {
    LocatedTokenOrLineJump::LocatedN3Token(located) =>
      match located {
        LocatedN3Token(N3Token::Iri(iri), _) => {
          self.terms.push(NamedNodeRef::new_unchecked(iri).as_n3term())
          self
        }
        LocatedN3Token(
          N3Token::PrefixedName(prefix~, localx~, might_be_invalid_iri~),
          _
        ) =>
          match context {
            RdfContext::N3RecognizerContext(ctx) =>
              match
                resolve_local_name(
                  prefix,
                  localx,
                  might_be_invalid_iri,
                  ctx.prefixes,
                ) {
                Ok(t) => {
                  self.terms.push(t.as_n3term())
                  self
                }
                Err(e) => self.error(errors, e)
              }
            _ => self.error(errors, "Invalid context for N3Term")
          }
        LocatedN3Token(N3Token::BlankNodeLabel(bnode), _) => {
          self.terms.push(BlankNodeRef::new_unchecked(bnode).as_n3term())
          self
        }
        LocatedN3Token(N3Token::Variable(name), _) => {
          self.terms.push(N3Term::Variable(name))
          self
        }
        LocatedN3Token(N3Token::String(value), _)
        | LocatedN3Token(N3Token::LongString(value), _) => {
          self.stack.push(N3State::LiteralPossibleSuffix(value~))
          self
        }
        LocatedN3Token(N3Token::Integer(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwINTEGER).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::Decimal(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwDECIMAL).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::Double(v), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(VarDataType::IntegerVar(v), lwDOUBLE).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::PlainKeyword("true"), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(
              VarDataType::IntegerVar("true"),
              lwBOOLEAN,
            ).as_n3term(),
          )
          self
        }
        LocatedN3Token(N3Token::PlainKeyword("false"), _) => {
          self.terms.push(
            LiteralRef::new_typed_literal(
              VarDataType::IntegerVar("false"),
              lwBOOLEAN,
            ).as_n3term(),
          )
          self
        }
        _ => self.error(errors, "TOKEN is not a valid RDF value")
      }
    _ => self.error(errors, "TOKEN is not a valid RDF value")
  }
}

// 辅助函数：统一处理公式结束逻辑

///|
fn N3Recognizer::finish_formula(
  self : N3Recognizer,
  errors : Array[RuleRecognizerError],
) -> N3Recognizer {
  let ctx = match self.contexts.pop() {
    Some(c) => c
    None => {
      errors.push(
        RuleRecognizerError::SyntaxError(
          "Internal error: contexts stack empty in finish_formula",
          Range::default(),
        ),
      )
      return self
    }
  }

  // 将公式对应的 BlankNode 作为 Term 压入
  self.terms.push(ctx.as_n3term())

  // 关键修复：清理状态栈
  // 1. 弹出 PathFollowUp (如果存在)
  if self.stack.last() == Some(N3State::PathFollowUp) {
    let _ = self.stack.pop()
  }

  // 2. 弹出 FormulaContentExpectDot (如果存在，防止残留)
  if self.stack.last() == Some(N3State::FormulaContentExpectDot) {
    let _ = self.stack.pop()
  }

  // 3. 重要：公式结束后，我们实际上完成了一个 PathItem。
  // 如果栈顶现在是 TriplesMiddle 或 ObjectsListEnd 等，它们应该能处理后续 token。
  // 但如果栈顶是 PathFollowUp 的上一层（例如 Path），我们需要确保不会再次进入 PathFollowUp 的错误逻辑。

  // 调试建议：打印此时的栈状态
  // self.debug_logger.info("Stack after finish_formula: \{self.stack.to_string()}")

  self
}
