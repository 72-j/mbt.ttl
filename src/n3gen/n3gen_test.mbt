// n3gen 测试面：byte 对拍（产物 ≡ 外层停役 IR）+ 强幂等 + 负例门
// 负例一律对真表字符串手术（mdlex 试点口径），本文件零 TOML 夹具
// 运行：cd src/ttl && moon test src/n3gen（G0 写盘 src/n3gen/n3_fsm.toml；CWD=src/ttl）
// golden 钉在仓内（n3_fsm.pinned.toml）：wasm/native 沙箱禁出仓路径；
// pinned ≡ 外层 src/rdf/fsm_out/n3_fsm.toml 的逐字节对拍属显式验证步（ADR v1 步6）

///|
async fn n3_load() -> (String, String, String) raise {
  let b = @fs.read_file("src/n3gen/n3_base.toml").text()
  let t = @fs.read_file("src/n3gen/n3_trans.toml").text()
  let g = @fs.read_file("src/n3gen/n3_fsm.pinned.toml").text()
  (b, t, g)
}

///|
fn n3_neg_check(got : Result[String, String], want : String) -> Bool {
  match got {
    Err(msg) => msg.contains(want)
    Ok(_) => false
  }
}

///|
async test "G0 byte parity + artifact write + strong idempotency" {
  let (base_src, trans_src, golden) = n3_load()
  let dump = match n3gen_compile(base_src, trans_src) {
    Ok(d) => d
    Err(e) => {
      assert_eq("compile should pass", e)
      abort("unreachable")
    }
  }
  // 逐字节对拍外层停役产物（dump 格式 + 表数据双钉）
  assert_eq(dump, golden)
  // 强幂等：重复编译零字节移动（无时间戳前提）
  let dump2 = match n3gen_compile(base_src, trans_src) {
    Ok(d) => d
    Err(e) => abort("recompile should pass: \{e}")
  }
  assert_eq(dump, dump2)
  // 产物落盘（fsm cmd 直读再生 n3.mbt）
  @fs.write_file("src/n3gen/n3_fsm.toml", @utf8.encode(dump))
  let back = @fs.read_file("src/n3gen/n3_fsm.toml").text()
  assert_eq(back, golden)
}

///|
async test "G1 unknown top section and unknown meta key" {
  let (base_src, trans_src, _) = n3_load()
  let bad = base_src + "\n[bogus]\nkey = \"x\"\n"
  assert_eq(
    n3_neg_check(n3gen_compile(bad, trans_src), "未知顶层段"),
    true,
  )
  let bad2 = base_src.replace(
    old="style = \"mutable\"",
    new="style = \"mutable\"\nbogus = \"x\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(bad2, trans_src), "未知键"),
    true,
  )
}

///|
async test "G2 duplicate and initial-count state gates" {
  let (base_src, trans_src, _) = n3_load()
  let dup = base_src + "\n[[events]]\nname = \"Iri\"\n"
  assert_eq(n3_neg_check(n3gen_compile(dup, trans_src), "重名"), true)
  let zero = base_src.replace(old="is_initial = true\n", new="")
  assert_eq(
    n3_neg_check(n3gen_compile(zero, trans_src), "is_initial 恰一个"),
    true,
  )
  let two = base_src + "\n[[states]]\nname = \"Extra\"\nis_initial = true\n"
  assert_eq(
    n3_neg_check(n3gen_compile(two, trans_src), "is_initial 恰一个"),
    true,
  )
}

///|
async test "G3 transition reference gates" {
  let (base_src, trans_src, _) = n3_load()
  let bad_from = trans_src.replace(
    old="from = \"ExpectSubject\"",
    new="from = \"NoSuchState\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, bad_from), "from"),
    true,
  )
  let bad_on = trans_src.replace(
    old="on = \"AnnotStart\"",
    new="on = \"NoSuchEvent\"",
  )
  assert_eq(n3_neg_check(n3gen_compile(base_src, bad_on), "on"), true)
  let bad_eff = trans_src.replace(
    old="effect = \"PopBnp\"",
    new="effect = \"NoSuchEffect\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, bad_eff), "effect"),
    true,
  )
  let tail = "\n[[transitions]]\nfrom = \"ExpectSubject\"\non = \"Iri\"\nto = \"ExpectPredicate\"\n"
  let dup = trans_src + tail
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, dup), "(from,on) 重复"),
    true,
  )
}

///|
async test "G4 guard and assign whitelist gates" {
  let (base_src, trans_src, _) = n3_load()
  let bad_guard = trans_src.replace(
    old="guard_def = \"directive_at\"",
    new="guard_def = \"not_a_field\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, bad_guard), "guard_def"),
    true,
  )
  let bad_assign = trans_src.replace(
    old="assign = \"directive_at=false\"",
    new="assign = \"nope=false\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, bad_assign), "assign 左值"),
    true,
  )
}

///|
async test "G5 actions order and chain reset gates" {
  let (base_src, trans_src, _) = n3_load()
  let unsorted = base_src.replace(
    old="name = \"open_slot\"",
    new="name = \"zz_open_slot\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(unsorted, trans_src), "按名升序"),
    true,
  )
  let bad_reset = base_src.replace(
    old="resets = [\"object\"]",
    new="resets = [\"nope_field\"]",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(bad_reset, trans_src), "不在字段集合"),
    true,
  )
}

///|
async test "G6 free-text quote gate and extras self gate" {
  let (base_src, trans_src, _) = n3_load()
  let quoted = base_src.replace(
    old="doc = \"N3 语句全清口径\"",
    new="doc = \"N3 \\\"x\\\" 口径\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(quoted, trans_src), "禁含引号"),
    true,
  )
  let bad_expr = base_src.replace(
    old="expr = \"self.iri_upcast\"",
    new="expr = \"iri_upcast\"",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(bad_expr, trans_src), "self. 前缀"),
    true,
  )
}

///|
async test "G7 unknown key inside transition row" {
  let (base_src, trans_src, _) = n3_load()
  let bad = trans_src.replace(
    old="on = \"AnnotStart\"\n",
    new="on = \"AnnotStart\"\nbogus = \"x\"\n",
  )
  assert_eq(
    n3_neg_check(n3gen_compile(base_src, bad), "未知键"),
    true,
  )
}
