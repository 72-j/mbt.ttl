///|
pub trait IriComponents {
  fn query(self : Self) -> String?
  fn is_absolute(self : Self) -> Bool
  fn scheme(self : Self) -> String?
  fn authority(self : Self) -> String?
  fn path(self : Self) -> String?
  fn fragment(self : Self) -> String?
}

///|
pub impl IriComponents for Iri with fn query(self : Iri) -> String? {
  if self.state.positions.query_end > self.state.positions.path_end + 1 {
    Some(
      self.base_iri
      .sub(
        start=self.state.positions.path_end + 1,
        end=self.state.positions.query_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn is_absolute(self : Iri) -> Bool {
  self.state.positions.scheme_end > 0
}

///|
pub impl IriComponents for Iri with fn scheme(self : Iri) -> String? {
  if self.state.positions.scheme_end > 0 {
    Some(
      self.base_iri
      .sub(start=0, end=self.state.positions.scheme_end - 1)
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn authority(self : Iri) -> String? {
  if self.state.positions.authority_end > self.state.positions.scheme_end + 2 {
    Some(
      self.base_iri
      .sub(
        start=self.state.positions.scheme_end + 2,
        end=self.state.positions.authority_end,
      )
      .to_owned(),
    )
  } else {
    None
  }
}

///|
pub impl IriComponents for Iri with fn path(self : Iri) -> String? {
  Some(
    self.base_iri
    .sub(
      start=self.state.positions.authority_end,
      end=self.state.positions.path_end,
    )
    .to_owned(),
  )
}

///|
pub impl IriComponents for Iri with fn fragment(self : Iri) -> String? {
  if self.state.positions.query_end + 1 < self.base_iri.length() { // 简单判断是否有 fragment
    if self.state.positions.query_end + 1 > 0 {
      Some(
        self.base_iri
        .sub(
          start=self.state.positions.query_end + 1,
          end=self.base_iri.length(),
        )
        .to_owned(),
      )
    } else {
      None
    }
  } else {
    None
  }
}

///|
trait StringRepr {
  fn as_stringview(self : Self) -> StringView
  fn into_string(self : Self) -> String
}

///|
pub impl StringRepr for Iri with fn as_stringview(self : Iri) -> StringView {
  self.base_iri
}

///|
pub impl StringRepr for Iri with fn into_string(self : Iri) -> String {
  self.base_iri
}

///|
pub impl StringRepr for IriRef with fn as_stringview(self : IriRef) -> StringView {
  self.val.base_iri
}

///|
pub impl StringRepr for IriRef with fn into_string(self : IriRef) -> String {
  self.val.base_iri
}

// pub impl IriComponents  for IriRef with resolve(
//   self : IriRef,
//   relative : String,
// ) -> String? {
//   // 创建结果缓冲区
//   // let target_buffer = StringBuilder::new()

//   // 调用底层解析器，传入当前 IriRef 作为 base
//   let positions = self.val.parse()

// }

///|
pub trait TokenRecognizer {
  fn recognize_next_token(
    Self,
    data : BytesView,
    is_ending : Bool,
    options : LexerOptions?,
  ) -> (Int, Result[TokenOrLineJump[N3Token], TokenRecognizerError])?
}

///|
pub trait RuleRecognizer {
  // asContextEnum(Self) -> Context
  fn error_recovery_state(Self) -> Self
  fn recognize_next(
    Self,
    token : TokenOrLineJump[N3Token],
    context : Context,
    results : Array[LexOutput],
    errors : Array[RuleRecognizerError],
  ) -> Self
  fn recognize_end(
    Self,
    context : Context,
    results : Array[LexOutput],
    errors : Array[RuleRecognizerError],
  ) -> Unit
  fn lexer_options(context : Context) -> LexerOptions?
}

// trait AsRef {
//  fn as_ref(self: Self) -> Ref[Self]
// }
// ///|
// pub trait IriRefInput {
//   fn to_str(self : Self) -> String
//   fn len(self : Self) -> Int
//   fn sub(self : Self, start~ : Int, end~ : Int) -> StringView
// }

// ///|
// impl IriRefInput for StringView with fn to_str(self : StringView) -> String {
//   self.val.to_owned()
// }

// ///|
// impl IriRefInput for StringView with fn len(self : StringView) -> Int {
//   self.val.length()
// }

// ///|
// impl IriRefInput for StringView with fn sub(
//   self : StringView,
//   start~ : Int,
//   end~ : Int,
// ) -> StringView {
//   self[start:end]
// }

// ///|
// impl IriRefInput for String with fn to_str(self : String) -> String {
//   self
// }

// ///|
// impl IriRefInput for String with fn len(self : String) -> Int {
//   self.val.length()
// }

// ///|
// impl IriRefInput for String with fn sub(self : String, start~ : Int, end~ : Int) -> StringView {
//   self[start:end]
// }

// trait Into[T] {
//   into(Self) -> T
// }
