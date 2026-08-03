// ============================================================
// Token 类型定义
// ============================================================

///|
pub(all) enum Token {
  Error(Int, Int, Int) // (line, start, end)
  IRI(Int, Int, Int) // (line, start, end)
  Blank(Int, Int, Int) // (line, start, end)
  Literal(Int, Int, Int) // (line, start, end)
  Symbol(Byte, Int, Int, Int) // (char, line, start, end)
  LineJump(Int, Int, Int) // (line, start, end)
  EOF(Int) // position
} derive(Debug)

///|
pub impl Show for Token with fn output(self : Token, logger : &Logger) -> Unit {
  match self {
    Token::IRI(line, start, end) => {
      logger.write_string("IRI")
      logger.write_string("(\{line}:\{start}:\{end})")
    }
    Token::Blank(line, start, end) => {
      logger.write_string("Blank")
      logger.write_string("(\{line}:\{start}:\{end})")
    }
    Token::Literal(line, start, end) => {
      logger.write_string("Literal")
      logger.write_string("(\{line}:\{start}:\{end})")
    }
    Token::Symbol(b, line, start, end) => {
      logger.write_string("Symbol")
      logger.write_string("(\{b}:\{line}:\{start}:\{end})")
    }
    Token::LineJump(line, start, end) => {
      logger.write_string("LineJump")
      logger.write_string("(\{line}:\{start}:\{end})")
    }
    Token::EOF(start) => {
      logger.write_string("EOF")
      logger.write_string("(\{start})")
    }
    Token::Error(line, start, end) => {
      logger.write_string("Error")
      logger.write_string("(\{line}:\{start}:\{end})")
    }
  }
}

///|
type Void

///|
/// Token 类型枚举
pub(all) enum TokenType {
  Error
  IRI
  Blank
  Literal
  Symbol
  LineJump
  End
} derive(Debug)

// ============================================================
// C 端结构体布局（16 字节，4 字节对齐）
// ============================================================

/// C 端 Token 结构布局：
/// - int32_t  type   (4 bytes, offset 0)
/// - int32_t  sym    (4 bytes, offset 4)
/// - int32_t  start  (4 bytes, offset 8)
/// - int32_t  end    (4 bytes, offset 12)
/// 总大小: 16 bytes

///|
/// CToken 占用字节数
const SIZEOF_CTOKEN : Int = 16

// ============================================================
// 核心 FFI 声明
// ============================================================

///|
/// 创建词法分析器
#owned(data)
pub extern "C" fn lexer_create(data : FixedArray[Byte], len : Int) -> Ref[Void] = "lexer_create"

///|
/// 销毁词法分析器
#owned(lexer)
pub extern "C" fn lexer_destroy(lexer : Ref[Void]) -> Unit = "lexer_destroy"

///|
/// 重置词法分析器
#owned(lexer)
extern "C" fn lexer_reset(lexer : Ref[Void]) -> Unit = "lexer_reset"

///|
/// 获取下一个 Token（写入 Bytes 缓冲区）
#owned(lexer, token_buf)
pub extern "C" fn lexer_next(
  lexer : Ref[Void],
  token_buf : FixedArray[Byte],
) -> Bool = "lexer_next"

///|
/// 批量获取 Token
#owned(lexer, token_bufs)
extern "C" fn lexer_next_batch(
  lexer : Ref[Void],
  token_bufs : FixedArray[Byte],
  max_count : Int,
) -> Int = "lexer_next_batch"

///|
/// 获取当前位置
#owned(lexer)
extern "C" fn lexer_pos(lexer : Ref[Void]) -> Int = "lexer_pos"

///|
/// 获取剩余字节数
#owned(lexer)
extern "C" fn lexer_remaining(lexer : Ref[Void]) -> Int = "lexer_remaining"

///|
/// 检查是否到达末尾
#owned(lexer)
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
/// 解析 C 端写入的 16 字节 Token 数据
fn parse_ctoken(buf : FixedArray[Byte]) -> (Int, Int, Int, Int) {
  let ctype = read_int32(buf, 0)
  let sym = read_int32(buf, 4)
  let start = read_int32(buf, 8)
  let end = read_int32(buf, 12)
  (ctype, sym, start, end)
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
  Lexerc::{
    ptr,
    data,
    offset: 0,
    token_buf: FixedArray::make(SIZEOF_CTOKEN, 0),
  }
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

  let (ctype, sym, start, end) = parse_ctoken(self.token_buf)

  // 转换为全局偏移量
  let global_start = self.offset + start
  let global_end = self.offset + end
  let line = sym // sym 存储行号
  match ctype {
    1 => Some(Token::IRI(line, global_start, global_end))
    2 => Some(Token::Blank(line, global_start, global_end))
    3 => Some(Token::Literal(line, global_start, global_end))
    4 => Some(Token::Symbol(sym.to_byte(), line, global_start, global_end))
    5 => Some(Token::LineJump(line, global_start, global_end))
    6 => Some(Token::EOF(global_end))
    _ => Some(Token::Error(line, global_start, global_end))
  }
}

///|
/// 批量获取 Token
pub fn Lexerc::next_batch(self : Lexerc, max_count : Int) -> Array[Token] {
  // 分配连续内存: max_count * 16 字节
  let total_size = max_count * SIZEOF_CTOKEN
  let buf : FixedArray[Byte] = FixedArray::make(total_size, 0)

  let count = lexer_next_batch(self.ptr, buf, max_count)

  let result : Array[Token] = []
  for i in 0..<count {
    let offset = i * SIZEOF_CTOKEN
    let (ctype, sym, start, end) = parse_ctoken_at(buf, offset)
    let global_start = self.offset + start
    let global_end = self.offset + end
    let line = sym // sym 存储行号
    let token = match ctype {
      1 => Token::IRI(line, global_start, global_end)
      2 => Token::Blank(line, global_start, global_end)
      3 => Token::Literal(line, global_start, global_end)
      4 => Token::Symbol(sym.to_byte(), line, global_start, global_end)
      5 => Token::LineJump(line, global_start, global_end)
      6 => Token::EOF(global_end)
      _ => Token::Error(line, global_start, global_end) // 错误 token   
    }
    result.push(token)
  }

  result
}

///|
/// 从连续缓冲区中读取指定偏移的 Token
fn parse_ctoken_at(
  buf : FixedArray[Byte],
  offset : Int,
) -> (Int, Int, Int, Int) {
  let ctype = read_int32(buf, offset + 0)
  let sym = read_int32(buf, offset + 4)
  let start = read_int32(buf, offset + 8)
  let end = read_int32(buf, offset + 12)
  (ctype, sym, start, end)
}

// ============================================================
// 工具方法
// ============================================================

///|
/// 从原始数据提取字符串
pub fn Lexerc::extract(self : Lexerc, start : Int, end : Int) -> String {
  if start < 0 || end > self.data.length() || start >= end {
    return ""
  }

  let buf = StringBuilder::new()
  for i in start..<end {
    buf.write_char(self.data[i].to_char())
  }
  buf.to_string()
}

///|
/// 提取 IRI（去掉 <> 包裹）
pub fn Lexerc::extract_iri(
  self : Lexerc,
  data : FixedArray[Byte],
  token : Token,
) -> ArrayView[Byte] {
  match token {
    Token::IRI(_, start, end) =>
      if end > start + 1 &&
        self.data[start] == b'<' &&
        self.data[end - 1] == b'>' {
        data[start + 1:end - 1]
      } else {
        data[start:end]
      }
    Token::Literal(_, start, end) => data[start:end]
    _ => []
  }
}

///|
/// 提取字面量（去掉 "" 包裹）
// pub fn Lexerc::extract_literal(self : Lexerc, token : Token) -> String {
//   match token {
//     Token::Literal(start, end) =>
//       if end > start + 1 &&
//         self.data[start] == b'"' &&
//         self.data[end - 1] == b'"' {
//         self.extract(start + 1, end - 1)
//       } else {
//         self.extract(start, end)
//       }
//     _ => ""
//   }
// }

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
