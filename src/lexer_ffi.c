#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// 类型定义
// ============================================================

typedef enum {
  TOKEN_ERROR = 0,
  TOKEN_IRI = 1,
  TOKEN_BLANK = 2,
  TOKEN_LITERAL = 3,
  TOKEN_SYMBOL = 4,
  TOKEN_LINEJUMP = 5,
  TOKEN_EOF = 6
} TokenType;

// Token 结构（16 字节，4 字节对齐）
typedef struct {
  int32_t type;  // offset 0
  int32_t sym;   // offset 4
  int32_t start; // offset 8
  int32_t end;   // offset 12
} Token;

// 词法分析器状态
typedef struct {
  const uint8_t *data;
  int32_t len;
  int32_t pos;
  int32_t line; // 当前行号（从 1 开始）
} Lexer;

// 验证 Token 合法性的辅助函数

// 检查 IRI 是否合法（无空格、无反斜杠、无未转义的控制字符）
// static bool is_valid_iri(const uint8_t *data, int32_t start, int32_t end) {
//   for (int i = start; i < end; i++) {
//     uint8_t c = data[i];
//     // 排除控制字符、空格、反斜杠
//     if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '<' ||
//         c == '>' || c == '"' || c == '{' || c == '}' || c == '|' || c == '^'
//         || c == '`' || c == '\\') {
//       return false;
//     }
//   }
//   return true;
// }

// 检查 Blank Node 是否合法（_:name 或 :name）
// static bool is_valid_blank(const uint8_t *data, int32_t start, int32_t end) {
//   int len = end - start;
//   if (len < 2)
//     return false;

//   // 检查第一个字符
//   if (data[start] == '_') {
//     // _:name 格式
//     if (data[start + 1] != ':')
//       return false;
//     // 不能有多个下划线开头
//     for (int i = start + 2; i < end; i++) {
//       if (data[i] == '_' && (i == start + 2 || data[i - 1] == ':')) {
//         return false; // 连续的 _ 或 _ 在 : 后面
//       }
//     }
//   } else if (data[start] == ':') {
//     // :name 格式
//     // 只能有一个冒号
//     for (int i = start + 1; i < end; i++) {
//       if (data[i] == ':')
//         return false;
//     }
//   } else {
//     return false;
//   }

//   return true;
// }

// 检查 Literal 是否合法（无未转义的控制字符）
// static bool is_valid_literal(const uint8_t *data, int32_t start, int32_t end)
// {
//   for (int i = start; i < end; i++) {
//     uint8_t c = data[i];
//     // 排除换行、 carriage return（在字符串字面量中）
//     if (c == '\n' || c == '\r')
//       return false;
//   }
//   return true;
// }
// ============================================================
// 创建/销毁函数
// ============================================================

Lexer *lexer_create(const uint8_t *data, int32_t len) {
  Lexer *l = (Lexer *)malloc(sizeof(Lexer));
  l->data = data;
  l->len = len;
  l->pos = 0;
  l->line = 1; // 从第 1 行开始
  return l;
}

void lexer_destroy(Lexer *l) { free(l); }

void lexer_reset(Lexer *l) {
  l->pos = 0;
  l->line = 1;
}

// ============================================================
// 辅助函数
// ============================================================

static bool is_whitespace(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\r';
}

static bool is_name_char(uint8_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-';
}

static void skip_whitespace_and_comment(Lexer *l) {
  while (l->pos < l->len) {
    uint8_t c = l->data[l->pos];
    if (c == ' ' || c == '\t' || c == '\r') {
      l->pos++;
    } else if (c == '#') {
      l->pos++;
      while (l->pos < l->len && l->data[l->pos] != '\n')
        l->pos++;
    } else {
      break;
    }
  }
}

// 更新行号的辅助函数
static void update_line(Lexer *l) {
  while (l->pos < l->len && l->data[l->pos] == '\n') {
    l->line++;
    l->pos++;
  }
}
// ============================================================
// 核心词法分析
// ============================================================

// 写入 Token 到字节缓冲区（小端序）
static void write_token(uint8_t *buf, int32_t type, int32_t sym, int32_t start,
                        int32_t end) {
  // type at offset 0
  buf[0] = (type >> 0) & 0xFF;
  buf[1] = (type >> 8) & 0xFF;
  buf[2] = (type >> 16) & 0xFF;
  buf[3] = (type >> 24) & 0xFF;

  // sym at offset 4
  buf[4] = (sym >> 0) & 0xFF;
  buf[5] = (sym >> 8) & 0xFF;
  buf[6] = (sym >> 16) & 0xFF;
  buf[7] = (sym >> 24) & 0xFF;

  // start at offset 8
  buf[8] = (start >> 0) & 0xFF;
  buf[9] = (start >> 8) & 0xFF;
  buf[10] = (start >> 16) & 0xFF;
  buf[11] = (start >> 24) & 0xFF;

  // end at offset 12
  buf[12] = (end >> 0) & 0xFF;
  buf[13] = (end >> 8) & 0xFF;
  buf[14] = (end >> 16) & 0xFF;
  buf[15] = (end >> 24) & 0xFF;
}

// 获取下一个 token
bool lexer_next(Lexer *l, uint8_t *token_buf) {
  skip_whitespace_and_comment(l);

  if (l->pos >= l->len) {
    write_token(token_buf, TOKEN_EOF, 0, l->pos, l->pos);
    return true;
  }

  int32_t start = l->pos;
  uint8_t c = l->data[l->pos];

  switch (c) {
  case '<': {
    l->pos++;
    while (l->pos < l->len && l->data[l->pos] != '>')
      l->pos++;
    int32_t line = l->line; // 记录行号
    if (l->pos < l->len) {
      l->pos++;
      update_line(l);
    }
    write_token(token_buf, TOKEN_IRI, line, start, l->pos);
    return true;
  }

  case '"': {
    l->pos++;
    while (l->pos < l->len && l->data[l->pos] != '"')
      l->pos++;
    int32_t line = l->line;
    if (l->pos < l->len) {
      l->pos++;
      update_line(l);
    }
    write_token(token_buf, TOKEN_LITERAL, line, start, l->pos);
    return true;
  }

  case '_':
  case ':': {
    int32_t prefix_start = start;
    l->pos++;
    if (l->pos < l->len && l->data[l->pos] == ':')
      l->pos++;
    while (l->pos < l->len && is_name_char(l->data[l->pos]))
      l->pos++;
    int32_t line = l->line;
    write_token(token_buf, TOKEN_BLANK, line, prefix_start, l->pos);
    return true;
  }

  case '.':
  case ',':
  case ';':
  case '[':
  case ']':
  case '(':
  case ')':
  case '{':
  case '}':
  case '^': {
    l->pos++;
    int32_t line = l->line;
    write_token(token_buf, TOKEN_SYMBOL, line, start, l->pos);
    return true;
  }

  case '\n': {
    l->pos++;
    int32_t line = l->line;
    l->line++; // 换行，行号 +1
    write_token(token_buf, TOKEN_LINEJUMP, line, start, l->pos);
    return true;
  }

  default: {
    l->pos++;
    int32_t line = l->line;
    write_token(token_buf, TOKEN_ERROR, line, start, l->pos);
    return true;
  }
  }
}

// 批量获取 token
int32_t lexer_next_batch(Lexer *l, uint8_t *buf, int32_t max_count) {
  int32_t count = 0;

  for (int i = 0; i < max_count && l->pos < l->len; i++) {
    uint8_t *token_buf = buf + i * 16;

    // 内联 skip_whitespace_and_comment
    while (l->pos < l->len) {
      uint8_t c = l->data[l->pos];
      if (c == ' ' || c == '\t' || c == '\r') {
        l->pos++;
      } else if (c == '#') {
        l->pos++;
        while (l->pos < l->len && l->data[l->pos] != '\n')
          l->pos++;
      } else {
        break;
      }
    }

    if (l->pos >= l->len) {
      write_token(token_buf, TOKEN_EOF, 0, l->pos, l->pos);
      count++;
      break;
    }

    int32_t start = l->pos;
    uint8_t c = l->data[l->pos];

    switch (c) {
    case '<': {
      l->pos++;
      while (l->pos < l->len && l->data[l->pos] != '>')
        l->pos++;
      int32_t line = l->line; // 记录行号
      if (l->pos < l->len) {
        l->pos++;
        update_line(l);
      }
      write_token(token_buf, TOKEN_IRI, line, start, l->pos);
      return true;
    }

    case '"': {
      l->pos++;
      while (l->pos < l->len && l->data[l->pos] != '"')
        l->pos++;
      int32_t line = l->line;
      if (l->pos < l->len) {
        l->pos++;
        update_line(l);
      }
      write_token(token_buf, TOKEN_LITERAL, line, start, l->pos);
      return true;
    }

    case '_':
    case ':': {
      int32_t prefix_start = start;
      l->pos++;
      if (l->pos < l->len && l->data[l->pos] == ':')
        l->pos++;
      while (l->pos < l->len && is_name_char(l->data[l->pos]))
        l->pos++;
      int32_t line = l->line;
      write_token(token_buf, TOKEN_BLANK, line, prefix_start, l->pos);
      return true;
    }

    case '.':
    case ',':
    case ';':
    case '[':
    case ']':
    case '(':
    case ')':
    case '{':
    case '}':
    case '^': {
      l->pos++;
      int32_t line = l->line;
      write_token(token_buf, TOKEN_SYMBOL, line, start, l->pos);
      return true;
    }

    case '\n': {
      l->pos++;
      int32_t line = l->line;
      l->line++; // 换行，行号 +1
      write_token(token_buf, TOKEN_LINEJUMP, line, start, l->pos);
      return true;
    }

    default: {
      l->pos++;
      int32_t line = l->line;
      write_token(token_buf, TOKEN_ERROR, line, start, l->pos);
      return true;
    }
    }

    count++;

    // 检查是否是 EOF
    if (token_buf[0] == TOKEN_EOF)
      break;
  }

  return count;
}
// ============================================================
// 状态查询
// ============================================================

int32_t lexer_pos(Lexer *l) { return l->pos; }

int32_t lexer_remaining(Lexer *l) { return l->len - l->pos; }

bool lexer_is_end(Lexer *l) {
  int32_t saved_pos = l->pos;
  skip_whitespace_and_comment(l);
  bool end = (l->pos >= l->len);
  l->pos = saved_pos; // 恢复位置
  return end;
}

// const char* token_name(int t) {
//   switch(t) {
//     case 0: return "ERROR";
//     case 1: return "IRI";
//     case 2: return "BLANK";
//     case 3: return "LITERAL";
//     case 4: return "SYMBOL";
//     case 5: return "LINEJUMP";
//     case 6: return "EOF";
//     default: return "UNKNOWN";
//   }
// }

// int main() {
//   const uint8_t data[] = "<http://example.org/item1>
//   <http://example.org/name> \"Test Item\" ."; int len = strlen((const
//   char*)data);

//   Lexer* l = lexer_create(data, len);

//   printf("Input: %s\n\n", data);

//   while (1) {
//     uint8_t buf[16] = {0};
//     bool ok = lexer_next(l, buf);

//     int type = buf[0];
//     int sym = buf[4];
//     int start = buf[8] | (buf[9]<<8) | (buf[10]<<16) | (buf[11]<<24);
//     int end = buf[12] | (buf[13]<<8) | (buf[14]<<16) | (buf[15]<<24);

//     printf("Token: type=%s(%d), sym=%d, start=%d, end=%d",
//            token_name(type), type, sym, start, end);

//     if (type == 1 || type == 3) {  // IRI or LITERAL
//       printf(", text=\"%.*s\"", end - start, data + start);
//     }
//     printf("\n");

//     if (type == 6) break;  // EOF
//   }

//   lexer_destroy(l);
//   return 0;
// }
#ifdef __cplusplus
}
#endif
