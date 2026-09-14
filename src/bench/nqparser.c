#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_LINE 4096

// 简单的状态机解析一行 N-Quads
// 格式: <subject> <predicate> <object> <graph> .
// 或:   <subject> <predicate> <object> .
// 或:   _:blank <predicate> <object> <graph> .

typedef struct {
    char *s, *p, *o, *g;
    int has_graph;
} Quad;

// 跳过空白字符
static char *skip_space(char *p) {
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    return p;
}

// 读取一个 term: IRI <...> 或 blank node _:... 或 literal "..."
static char *read_term(char *p, char **term, int *is_literal) {
    *is_literal = 0;
    p = skip_space(p);
    
    if (*p == '<') {
        // IRI: <...>
        *term = p;
        p++;
        while (*p && *p != '>') p++;
        if (*p == '>') p++;
    } else if (*p == '_') {
        // Blank node: _:...
        *term = p;
        p += 2; // skip _:
        while (*p && *p != ' ' && *p != '\t' && *p != '.' && *p != '\n') p++;
    } else if (*p == '"') {
        // Literal: "..." or """..."""
        *is_literal = 1;
        *term = p;
        p++;
        if (*p == '"' && *(p+1) == '"') {
            // Triple quote
            p += 2;
            while (*p) {
                if (*p == '"' && *(p+1) == '"' && *(p+2) == '"') {
                    p += 3;
                    break;
                }
                p++;
            }
        } else {
            // Single quote
            while (*p && *p != '"') {
                if (*p == '\\' && *(p+1)) p += 2;
                else p++;
            }
            if (*p == '"') p++;
            // Skip ^^<type> or @lang
            p = skip_space(p);
            if (*p == '^' && *(p+1) == '^') {
                p += 2;
                if (*p == '<') {
                    p++;
                    while (*p && *p != '>') p++;
                    if (*p == '>') p++;
                }
            } else if (*p == '@') {
                p++;
                while (*p && *p != ' ' && *p != '\t' && *p != '.' && *p != '\n') p++;
            }
        }
    } else {
        *term = NULL;
    }
    return p;
}

// 解析一行，返回 1 成功，0 失败
int parse_line(char *line, Quad *q) {
    char *p = line;
    int is_lit;
    
    // Subject
    p = read_term(p, &q->s, &is_lit);
    if (!q->s) return 0;
    
    // Predicate
    p = read_term(p, &q->p, &is_lit);
    if (!q->p) return 0;
    
    // Object
    p = read_term(p, &q->o, &is_lit);
    if (!q->o) return 0;
    
    // Check for graph or dot
    p = skip_space(p);
    
    if (*p == '<' || *p == '_') {
        // Has graph
        p = read_term(p, &q->g, &is_lit);
        if (!q->g) return 0;
        q->has_graph = 1;
        p = skip_space(p);
    } else {
        q->has_graph = 0;
        q->g = NULL;
    }
    
    // Expect dot
    if (*p == '.') p++;
    
    return 1;
}

// 快速计数，不存储
long parse_file_fast(const char *filename) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        perror("fopen");
        return -1;
    }
    
    char line[MAX_LINE];
    long count = 0;
    long line_num = 0;
    
    while (fgets(line, sizeof(line), fp)) {
        line_num++;
        
        // 跳过空行和注释
        char *p = skip_space(line);
        if (*p == '\0' || *p == '#') continue;
        
        // 最简单的检查：数尖括号和点
        // 至少 3 个 < 或 _: 和一个 .
        int has_terms = 0;
        int has_dot = 0;
        
        char *tmp = p;
        while (*tmp) {
            if (*tmp == '<' || (*tmp == '_' && *(tmp+1) == ':')) has_terms++;
            if (*tmp == '.') has_dot++;
            tmp++;
        }
        
        if (has_terms >= 3 && has_dot >= 1) {
            count++;
        }
    }
    
    fclose(fp);
    printf("快速统计: %ld 行 (扫描 %ld 行)\n", count, line_num);
    return count;
}

// 完整解析并验证结构
long parse_file_full(const char *filename) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        perror("fopen");
        return -1;
    }
    
    char line[MAX_LINE];
    long count = 0;
    long errors = 0;
    
    while (fgets(line, sizeof(line), fp)) {
        // 移除换行
        char *end = line + strlen(line) - 1;
        while (end > line && (*end == '\n' || *end == '\r')) *end-- = '\0';
        
        // 跳过空行和注释
        char *p = skip_space(line);
        if (*p == '\0' || *p == '#') continue;
        
        Quad q = {0};
        if (parse_line(line, &q)) {
            count++;
        } else {
            errors++;
            // fprintf(stderr, "Parse error: %.50s...\n", line);
        }
    }
    
    fclose(fp);
    printf("完整解析: %ld 成功, %ld 失败\n", count, errors);
    return count;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s <nquads-file> [fast|full]\n", argv[0]);
        printf("  fast: 快速计数（默认）\n");
        printf("  full: 完整解析\n");
        return 1;
    }
    
    const char *filename = argv[1];
    int mode = (argc > 2 && strcmp(argv[2], "full") == 0) ? 1 : 0;
    
    printf("文件: %s\n", filename);
    printf("模式: %s\n", mode ? "完整解析" : "快速计数");
    
    clock_t start = clock();
    long count;
    
    if (mode == 0) {
        count = parse_file_fast(filename);
    } else {
        count = parse_file_full(filename);
    }
    
    clock_t end = clock();
    double ms = (double)(end - start) * 1000.0 / CLOCKS_PER_SEC;
    
    printf("\n结果:\n");
    printf("  解析时间: %.2f ms\n", ms);
    printf("  三元组数: %ld\n", count);
    if (ms > 0 && count > 0) {
        printf("  每秒处理: %.0f\n", count / ms * 1000.0);
        printf("  每个耗时: %.4f ms\n", ms / count);
    }
    
    return 0;
}