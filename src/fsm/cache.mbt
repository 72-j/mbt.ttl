///|
/// 缓存结构
pub struct Cache {
  input_hash : String?
  config_hash : String?
  generated_at : UInt64 // 时间戳
}

///|
// pub struct CacheOptions {
//   cache_file : String
//   config : CodegenConfig
// }

///|
/// 创建缓存
pub fn Cache::new(input_hash : String?, config : CodegenConfig) -> Cache {
  Cache::{
    input_hash,
    config_hash: Some(hash_config(config)),
    generated_at: @env.now(),
  }
}

///|
/// 计算配置的哈希值
fn hash_config(config : CodegenConfig) -> String {
  let buf = StringBuilder::new()
  buf.write(if config.debug { "1" } else { "0" })
  buf.write("|")
  buf.write(config.output_module)
  simple_hash(buf.to_string())
}

///|
/// 简单哈希函数
fn simple_hash(content : String) -> String {
  let mut hash : UInt64 = 5381
  for c in content {
    hash = (hash << 5) + hash + c.to_uint().to_uint64()
  }

  // 转换为 16 进制
  let hex_chars = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let mut result = ""
  for i = 0; i < 16; i = i + 1 {
    let idx = (hash & 0xf).to_int()
    let hex_char = hex_chars[idx]
    result = "\{hex_char}" + result
    hash = hash >> 4
  }

  result
}

///|
/// 检查是否需要重新生成
pub async fn needs_regenerate(
  content : String,
  config : CodegenConfig,
  cache_path : String,
) -> Bool {
  let current_hash = simple_hash(content)
  let current_config_hash = hash_config(config)

  match load_cache(cache_path) {
    None => true // 没有缓存，需要生成
    Some(cache) =>
      // 对比哈希
      if cache.input_hash.unwrap() != current_hash {
        true // 输入文件变了
      } else if cache.config_hash.unwrap() != current_config_hash {
        true // 配置变了
      } else {
        false // 无需重新生成
      }
  }
}

///|
/// 从文件加载缓存
pub async fn load_cache(path : String) -> Cache? {
  let content = @fs.read_file(path).text() catch { _ => return None }

  parse_cache_json(content)
}

///|
/// 解析缓存 JSON
pub fn parse_cache_json(content : String) -> Cache? {
  let json = @json.parse(content) catch { _ => return None }

  // 使用 .as_object() 方法获取 Map
  let map = if json is Object(map) { Some(map) } else { None }
  match map {
    None => return None
    Some(map) => {
      // 获取 input_hash
      let input_hash = match map.get("input_hash") {
        Some(s) => if s is String(s) { Some(s) } else { None }
        None => return None
      }

      // 获取 config_hash
      let config_hash = match map.get("config_hash") {
        Some(s) => if s is String(s) { Some(s) } else { None }
        None => return None
      }

      // 获取 generated_at
      let generated_at = match map.get("generated_at") {
        Some(n) => if n is Number(s, ..) { s.to_uint64() } else { 0UL }
        None => 0UL
      }

      Some(Cache::{ input_hash, config_hash, generated_at })
    }
  }
}

///|
/// 保存缓存到文件
pub async fn save_cache(cache : Cache, path : String) -> Unit {
  let json = build_cache_json(cache)
  if !@fs.exists(path) {
    // 删除旧缓存文件
    let _ = @fs.create(path)
  }
  @fs.write_file(path, @utf8.encode(json))
}

///|
/// 构建缓存 JSON
fn build_cache_json(cache : Cache) -> String {
  let input_hash_str = match cache.input_hash {
    Some(h) => "\"\{h}\""
    None => "null"
  }

  let config_hash_str = match cache.config_hash {
    Some(h) => "\"\{h}\""
    None => "null"
  }

  let str =
    $|{
    $|  "input_hash": \{input_hash_str},
    $|  "config_hash": \{config_hash_str},
    $|  "generated_at": \{cache.generated_at}
    $|}
  str
}

///|
/// 获取缓存信息
pub fn Cache::info(self : Cache) -> String {
  let buf = StringBuilder::new()
  buf.write("Cache {\n")
  buf.write("  input_hash: ")
  buf.write(self.input_hash)
  buf.write("\n")
  buf.write("  config_hash: ")
  buf.write(self.config_hash)
  buf.write("\n")
  buf.write("  generated_at: ")
  buf.write(self.generated_at.to_string())
  buf.write("\n")
  buf.write("}")
  buf.to_string()
}

///|
/// 删除缓存文件
pub async fn delete_cache(path : String) -> Bool {
  @fs.remove(path) catch {
    _ => return false
  }
  true
}

///|
/// 检查缓存是否存在
pub async fn cache_exists(path : String) -> Bool {
  // 尝试读取文件
  @fs.can_read(path)
}

///|
/// 清理过期缓存（超过指定秒数）
pub async fn clean_expired_cache(
  path : String,
  max_age_seconds : UInt64,
) -> Bool {
  match load_cache(path) {
    None => false // 无缓存
    Some(cache) => {
      let now = @env.now()
      let age = now - cache.generated_at
      if age > max_age_seconds {
        delete_cache(path)
      } else {
        false
      }
    }
  }
}

///|
test {
  // 测试 Cache 创建
  let config = CodegenConfig::{
    trait_name: "Actions",
    debug: false,
    output_module: "test_fsm",
    name_prefix: "",
    actions: None,
    effects: None,
    context: None,
  }

  let cache = Cache::new(Some("abc123"), config)

  match cache.input_hash {
    Some(h) => assert_eq(h, "abc123")
    None => fail("input_hash should be Some")
  }

  match cache.config_hash {
    Some(h) => assert_true(h.length() > 0)
    None => fail("config_hash should be Some")
  }

  assert_true(cache.generated_at > 0)
}

///|
test {
  let hash = simple_hash("hello")

  // 验证长度为 16
  assert_eq(hash.length(), 16)

  // 验证是有效的十六进制
  let valid_chars = "0123456789abcdef"
  for c in hash {
    assert_true(valid_chars.contains("\{c}"))
  }
}

///|
test {
  // 测试 simple_hash 函数
  let hash1 = simple_hash("hello")
  let hash2 = simple_hash("hello")

  // 相同输入产生相同哈希
  assert_eq(hash1, hash2)

  // 不同输入产生不同哈希
  let hash3 = simple_hash("world")
  assert_true(hash1 != hash3)

  // 哈希长度应该是 16
  assert_eq(hash1.length(), 16)

  // 空字符串也有哈希
  let empty_hash = simple_hash("")
  assert_true(empty_hash.length() == 16)
}

///|
test {
  // 测试 hash_config 函数
  let config1 = CodegenConfig::{
    trait_name: "Actions",
    debug: false,
    output_module: "test",
    name_prefix: "",
    actions: None,
    effects: None,
    context: None,
  }
  let config2 = CodegenConfig::{
    trait_name: "Actions",
    debug: true,
    output_module: "test",
    name_prefix: "",
    actions: None,
    effects: None,
    context: None,
  }

  let hash1 = hash_config(config1)
  let hash2 = hash_config(config2)

  // debug 不同，哈希应该不同
  assert_true(hash1 != hash2)

  // 相同配置产生相同哈希
  let hash3 = hash_config(config1)
  assert_eq(hash1, hash3)
}

///|
test {
  // 测试 parse_cache_json 函数
  let json =
    #|{
    #|  "input_hash": "abc123def456",
    #|  "config_hash": "xyz789",
    #|  "generated_at": 1234567890
    #|}

  let cache = parse_cache_json(json)
  guard cache is Some(c) else { fail("Failed to parse JSON") }

  match c.input_hash {
    Some(h) => assert_eq(h, "abc123def456")
    None => fail("input_hash missing")
  }

  match c.config_hash {
    Some(h) => assert_eq(h, "xyz789")
    None => fail("config_hash missing")
  }

  assert_eq(c.generated_at, 1234567890UL)
}

///|
test {
  // 测试 parse_cache_json 错误处理
  // 无效 JSON
  let result = parse_cache_json("invalid json")
  assert_true(result.is_none())

  // 缺少字段
  let result2 = parse_cache_json("{\"input_hash\": \"test\"}")
  assert_true(result2.is_none())

  // 空对象
  let result3 = parse_cache_json("{}")
  assert_true(result3.is_none())
}

///|
test {
  // 测试 build_cache_json 函数
  let cache = Cache::{
    input_hash: Some("my_hash"),
    config_hash: Some("config_hash"),
    generated_at: 9999999999UL,
  }

  let json = build_cache_json(cache)

  assert_true(json.contains("\"input_hash\": \"my_hash\""))
  assert_true(json.contains("\"config_hash\": \"config_hash\""))
  assert_true(json.contains("\"generated_at\": 9999999999"))
}

///|
test {
  // 测试 Cache::info 函数
  let cache = Cache::{
    input_hash: Some("info_hash"),
    config_hash: Some("info_config"),
    generated_at: 1111111111UL,
  }

  let info = cache.info()

  assert_true(info.contains("info_hash"))
  assert_true(info.contains("info_config"))
  assert_true(info.contains("1111111111"))
}

///|
async test {
  // 测试 save_cache 和 load_cache
  let cache = Cache::{
    input_hash: Some("save_test_hash"),
    config_hash: Some("save_test_config"),
    generated_at: 5555555555UL,
  }

  let path = "./test_save_cache.json"

  // 保存缓存
  save_cache(cache, path)

  // 加载缓存
  let loaded = load_cache(path)
  match loaded {
    Some(c) => {
      match c.input_hash {
        Some(h) => assert_eq(h, "save_test_hash")
        None => fail("input_hash missing")
      }
      match c.config_hash {
        Some(h) => assert_eq(h, "save_test_config")
        None => fail("config_hash missing")
      }
      assert_eq(c.generated_at, 5555555555UL)
    }
    None => fail("Failed to load saved cache")
  }

  // 清理
  let _ = delete_cache(path)
}

///|
async test {
  // 测试 cache_exists 函数
  let path = "./test_exists_cache.json"

  // 文件不存在
  let exists_before = cache_exists(path)
  assert_false(exists_before)

  // 创建文件
  let cache = Cache::{
    input_hash: Some("exists_test"),
    config_hash: Some("exists_config"),
    generated_at: 6666666666UL,
  }
  save_cache(cache, path)

  // 文件存在
  let exists_after = cache_exists(path)
  assert_true(exists_after)

  // 清理
  let _ = delete_cache(path)

  // 删除后不存在
  let exists_removed = cache_exists(path)
  assert_false(exists_removed)
}

///|
async test {
  // 测试 delete_cache 函数
  let path = "./test_delete_cache.json"

  // 创建文件
  let cache = Cache::{
    input_hash: Some("delete_test"),
    config_hash: Some("delete_config"),
    generated_at: 7777777777UL,
  }
  save_cache(cache, path)

  // 确认存在
  assert_true(cache_exists(path))

  // 删除
  let deleted = delete_cache(path)
  assert_true(deleted)

  // 确认已删除
  assert_false(cache_exists(path))
}

///|
async test {
  // 测试 clean_expired_cache 函数
  let path = "./test_expired_cache.json"

  // 创建旧缓存（时间戳为 0）
  let old_cache = Cache::{
    input_hash: Some("old_cache"),
    config_hash: Some("old_config"),
    generated_at: 0UL, // 很旧的时间
  }
  save_cache(old_cache, path)

  // 清理超过 1 秒的缓存
  let cleaned = clean_expired_cache(path, 1UL)
  assert_true(cleaned)

  // 确认已删除
  assert_false(cache_exists(path))
}

///|
async test {
  // 测试 needs_regenerate 函数
  let path = "./test_needs_regenerate.json"

  // 无缓存时需要重新生成
  let result1 = needs_regenerate(
    "content",
    CodegenConfig::{
      trait_name: "Actions",
      debug: false,
      output_module: "test",
      name_prefix: "",
      actions: None,
      effects: None,
      context: None,
    },
    path,
  )
  assert_true(result1)

  // 创建缓存
  let cache = Cache::{
    input_hash: Some(simple_hash("content")),
    config_hash: Some(
      hash_config(CodegenConfig::{
        trait_name: "Actions",
        debug: false,
        output_module: "test",
        name_prefix: "",
        actions: None,
        effects: None,
        context: None,
      }),
    ),
    generated_at: @env.now(),
  }
  save_cache(cache, path)

  // 相同内容，相同配置，不需要重新生成
  let result2 = needs_regenerate(
    "content",
    CodegenConfig::{
      trait_name: "Actions",
      debug: false,
      output_module: "test",
      name_prefix: "",
      actions: None,
      effects: None,
      context: None,
    },
    path,
  )
  assert_false(result2)

  // 内容改变，需要重新生成
  let result3 = needs_regenerate(
    "new_content",
    CodegenConfig::{
      trait_name: "Actions",
      debug: false,
      output_module: "test",
      name_prefix: "",
      actions: None,
      effects: None,
      context: None,
    },
    path,
  )
  assert_true(result3)

  // 清理
  let _ = delete_cache(path)
}
