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
  TOKEN_BLANK_NODE = 5,
  TOKEN_PREF_NAME = 6,
  TOKEN_UNKNOWN = 7,
  TOKEN_EOF = 8,
  TOKEN_TRIPLE_TERM = 9
} TokenType;

// Lexer 结构
typedef struct {
  const uint8_t *data;
  uint8_t *owned; // C 侧拷贝缓冲（创建时一次性 memcpy，GC 堆不可达）
  int32_t len;
  int32_t pos;
} Lexer;

// ============================================================
// 辅助函数
// ============================================================

static bool is_whitespace(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

static bool is_whitespace_and_comment(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '#';
}

static bool is_name_char(uint8_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.';
}

static bool is_alpha(uint8_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

// 十六进制位（%HH 百分号对判定用）
static bool is_hex(uint8_t c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
         (c >= 'A' && c <= 'F');
}

// UTF-8 码点解码（字节级零分配）：返回码点，消耗字节数写入 *n_out；
// 非法形态返回 -1（*n_out = 0）。拒收：裸续字节 / C0-C1 过长前导 / F5-FF 越界
// 前导 / 断尾 / E0-F0-F4 下的过短编码 / 代理区（ED A0+）/ >U+10FFFF（F4 90+）
// （与 Lexermoon::utf8_cp_at 一一对应）
static int32_t utf8_cp_at(const uint8_t *v, int32_t pos, int32_t l,
                          int32_t *n_out) {
  *n_out = 0;
  if (pos >= l)
    return -1;
  uint8_t c = v[pos];
  if (c < 0x80) {
    *n_out = 1;
    return c;
  }
  if (c < 0xC2)
    return -1;
  if (c < 0xE0) {
    if (pos + 1 >= l || v[pos + 1] < 0x80 || v[pos + 1] > 0xBF)
      return -1;
    *n_out = 2;
    return ((c & 0x1F) << 6) | (v[pos + 1] & 0x3F);
  }
  if (c < 0xF0) {
    if (pos + 2 >= l)
      return -1;
    uint8_t c1 = v[pos + 1], c2 = v[pos + 2];
    if (c1 < 0x80 || c1 > 0xBF || c2 < 0x80 || c2 > 0xBF)
      return -1;
    if (c == 0xE0 && c1 < 0xA0)
      return -1; // 过短编码
    if (c == 0xED && c1 >= 0xA0)
      return -1; // 代理区
    *n_out = 3;
    return ((c & 0x0F) << 12) | ((c1 & 0x3F) << 6) | (c2 & 0x3F);
  }
  if (c < 0xF5) {
    if (pos + 3 >= l)
      return -1;
    uint8_t c1 = v[pos + 1], c2 = v[pos + 2], c3 = v[pos + 3];
    if (c1 < 0x80 || c1 > 0xBF || c3 < 0x80 || c3 > 0xBF)
      return -1;
    if (c == 0xF0 && c1 < 0x90)
      return -1; // 过短编码
    if (c == 0xF4 && c1 >= 0x90)
      return -1; // > U+10FFFF
    *n_out = 4;
    return ((c & 0x07) << 18) | ((c1 & 0x3F) << 12) | ((c2 & 0x3F) << 6) |
           (c3 & 0x3F);
  }
  return -1;
}

// 多字节名字字符（Turtle PN_CHARS 非 ASCII 全集：PN_CHARS_BASE ∪ 组合记号
// U+0300-036F ∪ U+203F-2040 ∪ ZWJ/ZWNJ U+200C-200D ∪ 中点 U+00B7）：
// 返回消耗字节数（0 = 非名字字符）。与 Lexermoon::utf8_name_advance 同表
static int32_t utf8_name_advance(const uint8_t *v, int32_t pos, int32_t l) {
  int32_t n = 0;
  int32_t cp = utf8_cp_at(v, pos, l, &n);
  if (n <= 0)
    return 0;
  if (cp == 0x00B7)
    return n;
  if ((cp >= 0x00C0 && cp <= 0x00D6) || (cp >= 0x00D8 && cp <= 0x00F6) ||
      (cp >= 0x00F8 && cp <= 0x02FF) || (cp >= 0x0300 && cp <= 0x036F) ||
      (cp >= 0x0370 && cp <= 0x037D) || (cp >= 0x037F && cp <= 0x1FFF) ||
      (cp >= 0x200C && cp <= 0x200D) || (cp >= 0x203F && cp <= 0x2040) ||
      (cp >= 0x2070 && cp <= 0x218F) || (cp >= 0x2C00 && cp <= 0x2FEF) ||
      (cp >= 0x3001 && cp <= 0xD7FF) || (cp >= 0xF900 && cp <= 0xFDCF) ||
      (cp >= 0xFDF0 && cp <= 0xFFFD) || (cp >= 0x10000 && cp <= 0xEFFFF))
    return n;
  return 0;
}

// 字面量后缀（无脑扫）：^^datatype / @lang 一并扫入，只认空白收束。
// 尾部被吞的语句点等结构问题交引擎/校验层判定，词法器不做语法判断
static void scan_literal_suffix(Lexer *l) {
  while (l->pos < l->len && !is_whitespace(l->data[l->pos])) {
    l->pos++;
  }
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
  // MoonBit FixedArray 跨 FFI 是调用期借用，指针不得长期持有；
  // 在边界处一次性拷贝进 C 自持内存，之后与 GC 堆零关联
  l->owned = (uint8_t *)malloc(len);
  memcpy(l->owned, data, len);
  l->data = l->owned;
  l->len = len;
  l->pos = 0;
  return l;
}

void lexer_destroy(Lexer *l) {
  if (l == NULL) {
    return;
  }
  free(l->owned); // 先释放拷贝缓冲
  free(l);        // 再释放结构体
}

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
  // for (int i = 0; i < 12; i++)
  //   token_buf[i] = 0;
  memset(token_buf, 0, 12);

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
        uint8_t ch = l->data[l->pos];
        if (ch == '\\' && l->pos + 1 < l->len) {
          l->pos += 2; // 转义对整对消费：`\\` 是字面反斜杠，其后闭壳照常
        } else if (ch == lock_quote && l->data[l->pos + 1] == lock_quote &&
                   l->data[l->pos + 2] == lock_quote) {
          // 闭壳 = 引号连跑末尾 quote_run 个（`""""` = 内容引号 + 闭三连）
          while (l->pos < l->len && l->data[l->pos] == lock_quote)
            l->pos++;
          break;
        } else {
          l->pos++;
        }
      }
      // 扫描完结尾引号后，类型感知收束 ^^ / @ 后缀
      scan_literal_suffix(l);
      write_token(token_buf, TOKEN_LITERAL, start, l->pos - start);
      return true;
    }

    // 3. 普通字符串：包含 ^^ 和 @，整体切出
    if (c == '"' || c == '\'') {
      uint8_t quote = c;
      int32_t start = l->pos;
      l->pos++;

      // 扫描字面量内容
      while (l->pos < l->len && l->data[l->pos] != quote) {
        if (l->data[l->pos] == '\\' && l->pos + 1 < l->len) {
          l->pos += 2; // 跳过转义字符
        } else {
          l->pos++;
        }
      }

      // 跳过结尾引号
      if (l->pos < l->len) {
        l->pos++;
      }

      // 类型感知收束 ^^ / @ 后缀
      scan_literal_suffix(l);

      // 整个作为一个 LITERAL token
      write_token(token_buf, TOKEN_LITERAL, start, l->pos - start);
      return true;
    }
    // 4. Blank Node _:xxx（名字含 .；多字节标签字符加宽同 PrefName 口径）
    if (c == '_' && l->pos + 1 < l->len && l->data[l->pos + 1] == ':') {
      l->pos += 2; // 跳过 _:
      while (l->pos < l->len) {
        if (is_name_char(l->data[l->pos])) {
          l->pos++;
        } else {
          int adv = utf8_name_advance(l->data, l->pos, l->len);
          if (adv == 0)
            break;
          l->pos += adv;
        }
      }
      write_token(token_buf, TOKEN_BLANK_NODE, start, l->pos - start);
      return true;
    }
    // 5. IRI
    if (c == '<') {
      // 5a. <<( ... )>> 三元组词项（RDF 1.2）：平衡深度扫描，与 Lexermoon 同机械。
      // 字符串是物理单元（引号内内容不参与配对）；词项内容不认识，语法归验证层
      if (l->pos + 2 < l->len && l->data[l->pos + 1] == '<' &&
          l->data[l->pos + 2] == '(') {
        l->pos += 3;
        int depth = 1;
        while (l->pos + 2 < l->len && depth > 0) {
          char d = l->data[l->pos];
          if (d == '"' || d == '\'') {
            l->pos++;
            while (l->pos < l->len && l->data[l->pos] != d) {
              if (l->data[l->pos] == '\\' && l->pos + 1 < l->len) {
                l->pos += 2;
              } else {
                l->pos++;
              }
            }
            if (l->pos < l->len) {
              l->pos++; // 消费闭引号
            }
          } else if (d == '<' && l->data[l->pos + 1] == '<' &&
                     l->data[l->pos + 2] == '(') {
            depth++;
            l->pos += 3;
          } else if (d == ')' && l->data[l->pos + 1] == '>' &&
                     l->data[l->pos + 2] == '>') {
            depth--;
            l->pos += 3;
          } else {
            l->pos++;
          }
        }
        write_token(token_buf, TOKEN_TRIPLE_TERM, start, l->pos - start);
        return true;
      }
      if (l->pos + 1 < l->len && l->data[l->pos + 1] == '<') {
        // RDF 1.2 引用三元组壳：<< s p o >>（可嵌套，与 Lexermoon 同机械）。
        // `<<(` 括号壳已在上分支；裸 `<<` 深度计数到配对 `>>`，字符串物理单元，
        // 未闭合宽容出词
        l->pos += 2;
        int depth = 1;
        while (l->pos < l->len && depth > 0) {
          char d = l->data[l->pos];
          if (d == '"' || d == '\'') {
            l->pos++;
            while (l->pos < l->len && l->data[l->pos] != d) {
              if (l->data[l->pos] == '\\' && l->pos + 1 < l->len) {
                l->pos += 2;
              } else {
                l->pos++;
              }
            }
            if (l->pos < l->len) {
              l->pos++; // 消费闭引号
            }
          } else if (d == '<' && l->pos + 1 < l->len &&
                     l->data[l->pos + 1] == '<') {
            depth++;
            l->pos += 2;
          } else if (d == '>' && l->pos + 1 < l->len &&
                     l->data[l->pos + 1] == '>') {
            depth--;
            l->pos += 2;
          } else {
            l->pos++;
          }
        }
        write_token(token_buf, TOKEN_TRIPLE_TERM, start, l->pos - start);
        return true;
      }
      if (l->pos + 1 < l->len && l->data[l->pos + 1] == '=') {
        // N3 预埋：<= 整词 UNKNOWN(2)（{|/|} 同机械，适配层按双字节分类）
        l->pos += 2;
        write_token(token_buf, TOKEN_UNKNOWN, start, 2);
        return true;
      }
      l->pos++;
      // 找到 > 或 EOF
      while (l->pos < l->len && l->data[l->pos] != '>') {
        // 如果遇到空白符，说明 IRI 不完整
        if (is_whitespace(l->data[l->pos])) {
          break;
        }
        l->pos++;
      }

      // 检查是否有结束 >
      if (l->pos < l->len && l->data[l->pos] == '>') {
        l->pos++; // 跳过 '>'
      }

      write_token(token_buf, TOKEN_IRI, start, l->pos - start);
      return true;
    }

    // 6. > → UNKNOWN(1)（>> 收尾等）；>= 不存在（N3 只有 => 与 <=）
    if (c == '>') {
      write_token(token_buf, TOKEN_UNKNOWN, l->pos, 1);
      l->pos++;
      return true;
    }

    // 6b. N3 预埋：=> 整词 UNKNOWN(2)（裸 = 仍是 UNKNOWN(1)）
    if (c == '=' && l->pos + 1 < l->len && l->data[l->pos + 1] == '>') {
      l->pos += 2;
      write_token(token_buf, TOKEN_UNKNOWN, start, 2);
      return true;
    }

    // 7. 字母/:起头（或多字节 PN_CHARS_BASE 字母）-> TOKEN_PREF_NAME。
    // PN_LOCAL 加宽口径（与 Lexermoon 同机械）：名字内允许 : 与名字字符（含内部
    // '.'、\X 转义对、%HH 百分号对、多字节 UTF-8）；语法对错（转义字符集/首字符
    // 限制）归验证层。尾部裸 '.' 回退留给语句终结符（\X 转义的 '.' 是字面点，不回退）
    {
      int lead = utf8_name_advance(l->data, l->pos, l->len);
      if (lead > 0 || is_alpha(c) || c == ':') {
        l->pos += (lead > 0 ? lead : 1);
        while (l->pos < l->len) {
          uint8_t ch = l->data[l->pos];
          if (ch == '\\' && l->pos + 1 < l->len) {
            l->pos += 2; // 转义对整段并入（PN_LOCAL_ESC 字符集校验在验证层）
          } else if (ch == '%' && l->pos + 2 < l->len &&
                     is_hex(l->data[l->pos + 1]) &&
                     is_hex(l->data[l->pos + 2])) {
            l->pos += 3; // %HH 百分号对整段并入（不足两 hex 位时 '%' 到 break）
          } else if (ch == ':' || is_name_char(ch)) {
            l->pos++;
          } else {
            int adv = utf8_name_advance(l->data, l->pos, l->len);
            if (adv == 0)
              break;
            l->pos += adv;
          }
        }
        // 尾部裸 '.' 回退（PN_LOCAL/PN_PREFIX 不得以裸点收尾）；转义点不回退
        while (l->pos > start + 1 && l->data[l->pos - 1] == '.' &&
               l->data[l->pos - 2] != '\\') {
          l->pos--;
        }
        write_token(token_buf, TOKEN_PREF_NAME, start, l->pos - start);
        return true;
      }
    }

    // 8 数字（可带±符号、可前导点）-> UNKNOWN（Turtle 数值口径，与 Lexermoon 同机械）：
    //   INTEGER/DECIMAL/DOUBLE；'.' 仅在后随数字或指数前导时并入（`123.E+1`、`-.2e3` 整词出，
    //   `1.` = INTEGER + 语句点不吞）
    if ((c == '+' || c == '-') && l->pos + 1 < l->len &&
        ((l->data[l->pos + 1] >= '0' && l->data[l->pos + 1] <= '9') ||
         (l->data[l->pos + 1] == '.' && l->pos + 2 < l->len &&
          l->data[l->pos + 2] >= '0' && l->data[l->pos + 2] <= '9'))) {
      l->pos++;
    }
    int is_number =
        (l->data[l->pos] >= '0' && l->data[l->pos] <= '9') ||
        (l->data[l->pos] == '.' && l->pos + 1 < l->len &&
         l->data[l->pos + 1] >= '0' && l->data[l->pos + 1] <= '9');
    if (is_number) {
      if (l->data[l->pos] == '.') {
        // 前导点形态 '.5'
        l->pos++;
        while (l->pos < l->len &&
               (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
          l->pos++;
        }
      } else {
        // 整数部
        while (l->pos < l->len &&
               (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
          l->pos++;
        }
        // 小数部：'.' 后随数字吞整段；'.' 后随指数前导只吞点（`123.E+1`）
        if (l->pos + 1 < l->len && l->data[l->pos] == '.') {
          char d = l->data[l->pos + 1];
          int exp_ahead =
              (d == 'e' || d == 'E') && l->pos + 2 < l->len &&
              ((l->data[l->pos + 2] >= '0' && l->data[l->pos + 2] <= '9') ||
               l->data[l->pos + 2] == '+' || l->data[l->pos + 2] == '-');
          if (d >= '0' && d <= '9') {
            l->pos++;
            while (l->pos < l->len &&
                   (l->data[l->pos] >= '0' && l->data[l->pos] <= '9')) {
              l->pos++;
            }
          } else if (exp_ahead) {
            l->pos++;
          }
        }
      }
      // 指数部：[eE] 后随数字或带符号数字才并入
      if (l->pos + 1 < l->len &&
          (l->data[l->pos] == 'e' || l->data[l->pos] == 'E')) {
        char d = l->data[l->pos + 1];
        int has_exp = (d >= '0' && d <= '9') ||
                      ((d == '+' || d == '-') && l->pos + 2 < l->len &&
                       l->data[l->pos + 2] >= '0' &&
                       l->data[l->pos + 2] <= '9');
        if (has_exp) {
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
      }
      write_token(token_buf, TOKEN_UNKNOWN, start, l->pos - start);
      return true;
    }

    // 9. 结构标点
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
    // RDF 1.2 注解定界符：{| 与 |} 整词出（与 Lexermoon 同机械）
    if (c == '{' && l->pos + 1 < l->len && l->data[l->pos + 1] == '|') {
      l->pos += 2;
      write_token(token_buf, TOKEN_UNKNOWN, start, 2);
      return true;
    }
    if (c == '|' && l->pos + 1 < l->len && l->data[l->pos + 1] == '}') {
      l->pos += 2;
      write_token(token_buf, TOKEN_UNKNOWN, start, 2);
      return true;
    }
    if (c == '#') {
      l->pos++;
      while (l->pos < l->len && l->data[l->pos] != '\n') {
        l->pos++;
      }
      continue; // 跳过注释行，继续循环
    }
    // 10. 其他字符 -> UNKNOWN
    write_token(token_buf, TOKEN_UNKNOWN, l->pos, 1);
    l->pos++;
    return true;
  }

  // 11. EOF
  write_token(token_buf, TOKEN_EOF, l->len, 0);
  return false;
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
