// ============================================================
// Token 类型定义
// ============================================================

///|
type Span = (Int, Int) // (offset, length)

///|
pub(all) enum Token {
  // 结构标点
  Dot(Span) // .
  Semicolon(Span) // ;
  Comma(Span) // ,

  // 标识符
  Iri(Span) // <...> 或 _:name 或 :name

  // 字符串
  Literal(Span) // "..."

  // 容错
  Unknown(Span) // 其他字符

  // 结束
  EOF(Int) // 文件结束
} derive(Debug)

///|
pub impl Show for Token with fn output(self : Token, logger : &Logger) -> Unit {
  match self {
    Token::Dot(span) => {
      let (offset, length) = span
      logger.write_string("Dot(\{offset},\{length})")
    }
    Token::Semicolon(span) => {
      let (offset, length) = span
      logger.write_string("Semicolon(\{offset},\{length})")
    }
    Token::Comma(span) => {
      let (offset, length) = span
      logger.write_string("Comma(\{offset},\{length})")
    }
    Token::Iri(span) => {
      let (offset, length) = span
      logger.write_string("Iri(\{offset},\{length})")
    }
    Token::Literal(span) => {
      let (offset, length) = span
      logger.write_string("Literal(\{offset},\{length})")
    }
    Token::Unknown(span) => {
      let (offset, length) = span
      logger.write_string("Unknown(\{offset},\{length})")
    }
    Token::EOF(offset) => logger.write_string("EOF(\{offset})")
  }
}

///|
type Void

// ============================================================
// C 端结构体布局（12 字节，4 字节对齐）
// ============================================================

/// C 端 Token 结构布局：
/// - int32_t  type   (4 bytes, offset 0)
/// - int32_t  start  (4 bytes, offset 4)
/// - int32_t  end    (4 bytes, offset 8)
/// 总大小: 12 bytes

///|
/// CToken 占用字节数
// const SIZEOF_CTOKEN : Int = 12

// ============================================================
// 核心 FFI 声明
// ============================================================

///|
/// 创建词法分析器
#borrow(data)
pub extern "C" fn lexer_create(data : FixedArray[Byte], len : Int) -> Ref[Void] = "lexer_create"

///|
/// 销毁词法分析器
#borrow(lexer)
pub extern "C" fn lexer_destroy(lexer : Ref[Void]) -> Unit = "lexer_destroy"

///|
/// 重置词法分析器
#borrow(lexer)
extern "C" fn lexer_reset(lexer : Ref[Void]) -> Unit = "lexer_reset"

///|
/// 获取下一个 Token（写入 Bytes 缓冲区）
#borrow(lexer, token_buf)
pub extern "C" fn lexer_next(
  lexer : Ref[Void],
  token_buf : FixedArray[Byte],
) -> Bool = "lexer_next"

///|
/// 批量获取 Token
// #borrow(lexer, token_bufs)
// extern "C" fn lexer_next_batch(
//   lexer : Ref[Void],
//   token_bufs : FixedArray[Byte],
//   max_count : Int,
// ) -> Int = "lexer_next_batch"

///|
/// 获取当前位置
#borrow(lexer)
extern "C" fn lexer_pos(lexer : Ref[Void]) -> Int = "lexer_pos"

///|
/// 获取剩余字节数
#borrow(lexer)
extern "C" fn lexer_remaining(lexer : Ref[Void]) -> Int = "lexer_remaining"

///|
/// 检查是否到达末尾
#borrow(lexer)
extern "C" fn lexer_is_end(lexer : Ref[Void]) -> Bool = "lexer_is_end"

// ============================================================
// Bytes 工具函数
// ============================================================

///|
/// 从 Bytes 读取 int32（小端序）
fn read_int32(buf : FixedArray[Byte], offset : Int) -> Int {
  let b0 = buf[offset].to_int()
  let b1 = buf[offset + 1].to_int()
  let b2 = buf[offset + 2].to_int()
  let b3 = buf[offset + 3].to_int()
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
/// 从 Bytes 缓冲区读取 CToken
///
/// 解析 C 端写入的 12 字节 Token 数据
fn parse_ctoken(buf : FixedArray[Byte]) -> (Int, Int, Int) {
  let ctype = read_int32(buf, 0)
  let offset = read_int32(buf, 4)
  let length = read_int32(buf, 8)
  (ctype, offset, length)
}

// ============================================================
// MoonBit Lexerc 封装
// ============================================================

///|
/// MoonBit 词法分析器
pub(all) struct Lexerc {
  ptr : Ref[Void] // C 端 Lexerc 指针
  data : FixedArray[Byte] // 原始数据
  mut offset : Int
  token_buf : FixedArray[Byte] // 复用的 16 字节缓冲区          // 全局偏移（用于流式解析）
}

// ============================================================
// 构造与销毁
// ============================================================

///|
/// 创建词法分析器
pub fn Lexerc::new(data : FixedArray[Byte]) -> Lexerc {
  let ptr = lexer_create(data, data.length())
  Lexerc::{ ptr, data, offset: 0, token_buf: FixedArray::make(12, 0) }
}

///|
/// 销毁词法分析器
pub fn Lexerc::destroy(self : Lexerc) -> Unit {
  lexer_destroy(self.ptr)
}

// ============================================================
// 核心解析方法
// ============================================================

///|
/// 重置词法分析器
pub fn Lexerc::reset(self : Lexerc) -> Unit {
  lexer_reset(self.ptr)
  self.offset = 0
}

///|
/// 获取下一个 Token
pub fn Lexerc::next(self : Lexerc) -> Token? {
  let ok = lexer_next(self.ptr, self.token_buf)
  if !ok {
    return None
  }

  let (ctype, offset, length) = parse_ctoken(self.token_buf)
  let global_offset = self.offset + offset
  let span = (global_offset, length)

  match ctype {
    0 => Some(Token::Dot(span))
    1 => Some(Token::Semicolon(span))
    2 => Some(Token::Comma(span))
    3 => Some(Token::Iri(span))
    4 => Some(Token::Literal(span))
    5 => Some(Token::Unknown(span))
    6 => Some(Token::EOF(global_offset))
    _ => Some(Token::Unknown(span))
  }
}

// ============================================================
// 工具方法
// ============================================================

// 提取 IRI（去掉 <> 包裹）

///|
pub fn Lexerc::extract_iri(self : Lexerc, token : Token) -> ArrayView[Byte] {
  match token {
    Token::Iri(span) => {
      let (offset, length) = span
      let end = offset + length
      if length > 2 && self.data[offset] == b'<' && self.data[end - 1] == b'>' {
        self.data[offset + 1:end - 1]
      } else {
        self.data[offset:end]
      }
    }
    _ => []
  }
}

// 提取字面量（去掉引号）

///|
pub fn Lexerc::extract_literal(self : Lexerc, token : Token) -> ArrayView[Byte] {
  match token {
    Token::Literal(span) => {
      let (offset, length) = span
      let end = offset + length
      if length >= 2 && self.data[offset] == b'"' && self.data[end - 1] == b'"' {
        self.data[offset + 1:end - 1]
      } else {
        self.data[offset:end]
      }
    }
    _ => []
  }
}

// 通用提取

///|
pub fn Lexerc::extract(self : Lexerc, span : Span) -> String {
  let (offset, length) = span
  let end = offset + length
  if offset < 0 || end > self.data.length() || offset >= end {
    return ""
  }

  let buf = StringBuilder::new()
  for i in offset..<end {
    buf.write_char(self.data[i].to_char())
  }
  buf.to_string()
}

///|
/// 获取当前位置
pub fn Lexerc::position(self : Lexerc) -> Int {
  self.offset + lexer_pos(self.ptr)
}

///|
/// 获取剩余数据长度
pub fn Lexerc::remaining(self : Lexerc) -> Int {
  lexer_remaining(self.ptr)
}

///|
/// 检查是否到达末尾
pub fn Lexerc::is_end(self : Lexerc) -> Bool {
  lexer_is_end(self.ptr)
}

///|
/// 获取原始数据引用
pub fn Lexerc::data(self : Lexerc) -> FixedArray[Byte] {
  self.data
}
