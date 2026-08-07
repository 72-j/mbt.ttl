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
  TOKEN_DOT = 0,
  TOKEN_SEMICOLON = 1,
  TOKEN_COMMA = 2,
  TOKEN_IRI = 3,
  TOKEN_LITERAL = 4,
  TOKEN_UNKNOWN = 5,
  TOKEN_EOF = 6
} TokenType;

// Lexer 结构
typedef struct {
  const uint8_t *data;
  int32_t len;
  int32_t pos;
} Lexer;

// ============================================================
// 辅助函数
// ============================================================

static bool is_whitespace(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

static bool is_separator(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '.' ||
         c == ';' || c == ',';
}

static bool is_name_char(uint8_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.';
}

static bool is_alpha(uint8_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static void skip_whitespace_and_comment(Lexer *l) {
  while (l->pos < l->len) {
    uint8_t c = l->data[l->pos];
    if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
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

// ============================================================
// 创建/销毁函数
// ============================================================

Lexer *lexer_create(const uint8_t *data, int32_t len) {
  Lexer *l = (Lexer *)malloc(sizeof(Lexer));
  l->data = data;
  l->len = len;
  l->pos = 0;
  return l;
}

void lexer_destroy(Lexer *l) { free(l); }

void lexer_reset(Lexer *l) { l->pos = 0; }

// ============================================================
// 核心词法分析
// ============================================================

// 写入 Token 到字节缓冲区（小端序）
static void write_token(uint8_t *buf, int32_t type, int32_t offset,
                        int32_t length) {
  // type (offset 0-3)
  buf[0] = type & 0xFF;
  buf[1] = (type >> 8) & 0xFF;
  buf[2] = (type >> 16) & 0xFF;
  buf[3] = (type >> 24) & 0xFF;

  // offset (offset 4-7)
  buf[4] = offset & 0xFF;
  buf[5] = (offset >> 8) & 0xFF;
  buf[6] = (offset >> 16) & 0xFF;
  buf[7] = (offset >> 24) & 0xFF;

  // length (offset 8-11)
  buf[8] = length & 0xFF;
  buf[9] = (length >> 8) & 0xFF;
  buf[10] = (length >> 16) & 0xFF;
  buf[11] = (length >> 24) & 0xFF;
}

// 获取下一个 token

bool lexer_next(Lexer *l, uint8_t *token_buf) {
  // 清零（必要）
  for (int i = 0; i < 12; i++)
    token_buf[i] = 0;

  // NULL 检查（生产环境可保留，安全）
  if (l == NULL || l->data == NULL || token_buf == NULL) {
    return false;
  }
  while (l->pos < l->len) {
    uint8_t c = l->data[l->pos];

    // 1. 空白符跳过
    if (is_whitespace(c)) {
      l->pos++;
      continue;
    }

    int32_t start = l->pos;

    // 2. 三引号长字符串（修正版）
    if ((c == '"' || c == '\'') && l->pos + 2 < l->len &&
        l->data[l->pos + 1] == c && l->data[l->pos + 2] == c) {
      uint8_t lock_quote = c;
      int32_t start = l->pos;
      l->pos += 3;
      while (l->pos + 2 < l->len) {
        if (l->data[l->pos] == lock_quote &&
            l->data[l->pos + 1] == lock_quote &&
            l->data[l->pos + 2] == lock_quote && l->data[l->pos - 1] != '\\') {
          l->pos += 3;
          break;
        }
        l->pos++;
      }
      // ✅ 关键修正：扫描完结尾引号后，继续扫描 @ 或 ^^
      while (l->pos < l->len && !is_whitespace(l->data[l->pos]) &&
             l->data[l->pos] != '.' && l->data[l->pos] != ';' &&
             l->data[l->pos] != ',') {
        l->pos++;
      }
      write_token(token_buf, TOKEN_LITERAL, start, l->pos - start);
      return true;
    }

    // 3. 普通字符串
  if (c == '"' || c == '\'') {
    uint8_t quote = c;
    l->pos++;
    while (l->pos < l->len && l->data[l->pos] != quote) {
      if (l->data[l->pos] == '\\' && l->pos + 1 < l->len) {
        l->pos += 2;
      } else {
        l->pos++;
      }
    }
    if (l->pos < l->len)
      l->pos++; // 跳过结尾引号
    // 继续扫描 ^^ 或 @ 直到空白符或分隔符
    while (l->pos < l->len && !is_whitespace(l->data[l->pos]) &&
           l->data[l->pos] != '.' && l->data[l->pos] != ';' &&
           l->data[l->pos] != ',') {
      l->pos++;
    }
    write_token(token_buf, TOKEN_LITERAL, start, l->pos - start);
    return true;
  }

    // 4. IRI
    if (c == '<') {
      if (l->pos + 1 < l->len && l->data[l->pos + 1] == '<') {
        write_token(token_buf, TOKEN_UNKNOWN, l->pos, 1);
        l->pos++;
        return true;
      }
      l->pos++;
      while (l->pos < l->len && l->data[l->pos] != '>')
        l->pos++;
      if (l->pos < l->len)
        l->pos++; // 跳过 '>'
      write_token(token_buf, TOKEN_IRI, start, l->pos - start);
      return true;
    }

    // 5. >>
    if (c == '>') {
      write_token(token_buf, TOKEN_UNKNOWN, l->pos, 1);
      l->pos++;
      return true;
    }

    // 6. 字母、冒号或下划线开头 -> UNKNOWN（无脑扫）
    if (is_alpha(c) || c == ':' || c == '_') {
      l->pos++;
      while (l->pos < l->len) {
        // fprintf(stderr, "DEBUG: alpha token, start=%d, end=%d, length=%d\n",
                // start, l->pos, l->pos - start);
        uint8_t ch = l->data[l->pos];
        if (is_separator(ch))
          break;
        if (ch == ':' || is_name_char(ch)) {
          l->pos++;
        } else {
          break;
        }
      }
      write_token(token_buf, TOKEN_IRI, start, l->pos - start);
      return true;
    }
    // 7 数字开头 -> UNKNOWN（整型、浮点型、科学计数）
    if (c >= '0' && c <= '9') {
      l->pos++;
      while (l->pos < l->len &&
             (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
        l->pos++;
      }
      // 处理小数点
      if (l->pos < l->len && l->data[l->pos] == '.') {
        l->pos++;
        while (l->pos < l->len &&
               (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
          l->pos++;
        }
      }
      // 处理科学计数法
      if (l->pos < l->len &&
          (l->data[l->pos] == 'e' || l->data[l->pos] == 'E')) {
        l->pos++;
        if (l->pos < l->len &&
            (l->data[l->pos] == '+' || l->data[l->pos] == '-')) {
          l->pos++;
        }
        while (l->pos < l->len &&
               (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
          l->pos++;
        }
      }
      write_token(token_buf, TOKEN_UNKNOWN, start, l->pos - start);
      return true;
    }

    // 8. 结构标点
    if (c == '.') {
      write_token(token_buf, TOKEN_DOT, l->pos, 1);
      l->pos++;
      return true;
    }
    if (c == ';') {
      write_token(token_buf, TOKEN_SEMICOLON, l->pos, 1);
      l->pos++;
      return true;
    }
    if (c == ',') {
      write_token(token_buf, TOKEN_COMMA, l->pos, 1);
      l->pos++;
      return true;
    }

    // 9. 其他字符 -> UNKNOWN
    write_token(token_buf, TOKEN_UNKNOWN, l->pos, 1);
    l->pos++;
    return true;
  }

  // 10. EOF
  write_token(token_buf, TOKEN_EOF, l->len, 0);
  return true;
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

#ifdef __cplusplus
}
#endif
