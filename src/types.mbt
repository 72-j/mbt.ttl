///|
type CharMatch = Array[Char]

///|
type CharMatchRule = (Char, Char?)

///|
type IriRef = Iri[String]

///|
pub trait IriInput {
  to_str(self : Self) -> String
  len(self : Self) -> Int
  sub(self : Self, start~ : Int, end~ : Int) -> StringView
}

///|
impl IriInput for StringView with to_str(self : StringView) -> String {
  self.to_owned()
}

///|
impl IriInput for StringView with len(self : StringView) -> Int {
  self.length()
}

///|
impl IriInput for StringView with sub(
  self : StringView,
  start~ : Int,
  end~ : Int,
) -> StringView {
  self[start:end]
}

///|
impl IriInput for String with to_str(self : String) -> String {
  self
}

///|
impl IriInput for String with len(self : String) -> Int {
  self.length()
}

///|
impl IriInput for String with sub(self : String, start~ : Int, end~ : Int) -> StringView {
  self[start:end]
}

