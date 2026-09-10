// n3gen 测试面：emit 黄金对拍（产物 ≡ check-in n3.mbt 逐字节）+ 强幂等 + 负例门
// 负例一律对真表字符串手术（mdlex 试点口径），本文件零 TOML 夹具
// 运行：cd src/ttl && moon test src/n3gen（G0 写盘 n3_out.gen 工件；CWD=src/ttl）
// golden = src/gen_n3/n3.mbt（port authority）；ts 钉 check-in 值 → 全字节零差

///|
async fn n3_load() -> (String, String) raise {
  let b = @fs.read_file("src/n3gen/n3_base.toml").text()
  let t = @fs.read_file("src/n3gen/n3_trans.toml").text()
  (b, t)
}

///|
fn n3_neg_check(got : Result[String, String], want : String) -> Bool {
  match got {
    Err(msg) => msg.contains(want)
    Ok(_) => false
  }
}

///|
async test "G0 emit parity + artifact write + strong idempotency" {
  let (base_src, trans_src) = n3_load()
  let out = match n3gen_build(base_src, trans_src, "1788955337965") {
    Ok(s) => s
    Err(e) => {
      assert_eq("build should pass", e)
      abort("unreachable")
    }
  }
  // 逐字节对拍 check-in n3.mbt（含 Generated-at；ts 钉 check-in 现值）
  let golden = @fs.read_file("src/gen_n3/n3.mbt").text()
  assert_eq(out, golden)
  // 工件落盘（表变更交付路径：diff 确认后 cp n3_out.gen -> ../gen_n3/n3.mbt）
  @fs.write_file("src/n3gen/n3_out.gen", @utf8.encode(out))
  let back = @fs.read_file("src/n3gen/n3_out.gen").text()
  assert_eq(back, golden)
  // 强幂等：重复 build 零字节移动
  let out2 = match n3gen_build(base_src, trans_src, "1788955337965") {
    Ok(s) => s
    Err(e) => abort("rebuild should pass: \{e}")
  }
  assert_eq(out, out2)
}

///|

async test "G1 unknown top section and unknown meta key" {
  let (base_src, trans_src) = n3_load()
  let bad = base_src + "\n[bogus]\nkey = \"x\"\n"
  assert_eq(
    n3_neg_check(n3gen_build(bad, trans_src, "0"), "未知顶层段"),
    true,
  )
  let bad2 = base_src.replace(
    old="style = \"mutable\"",
    new="style = \"mutable\"\nbogus = \"x\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(bad2, trans_src, "0"), "未知键"),
    true,
  )
}

///|
async test "G2 duplicate and initial-count state gates" {
  let (base_src, trans_src) = n3_load()
  let dup = base_src + "\n[[events]]\nname = \"Iri\"\n"
  assert_eq(n3_neg_check(n3gen_build(dup, trans_src, "0"), "重名"), true)
  let zero = base_src.replace(old="is_initial = true\n", new="")
  assert_eq(
    n3_neg_check(n3gen_build(zero, trans_src, "0"), "is_initial 恰一个"),
    true,
  )
  let two = base_src + "\n[[states]]\nname = \"Extra\"\nis_initial = true\n"
  assert_eq(
    n3_neg_check(n3gen_build(two, trans_src, "0"), "is_initial 恰一个"),
    true,
  )
}

///|
async test "G3 transition reference gates" {
  let (base_src, trans_src) = n3_load()
  let bad_from = trans_src.replace(
    old="from = \"ExpectSubject\"",
    new="from = \"NoSuchState\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_from, "0"), "from"),
    true,
  )
  let bad_on = trans_src.replace(
    old="on = \"AnnotStart\"",
    new="on = \"NoSuchEvent\"",
  )
  assert_eq(n3_neg_check(n3gen_build(base_src, bad_on, "0"), "on"), true)
  let bad_eff = trans_src.replace(
    old="effect = \"PopBnp\"",
    new="effect = \"NoSuchEffect\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_eff, "0"), "effect"),
    true,
  )
  let tail = "\n[[transitions]]\nfrom = \"ExpectSubject\"\non = \"Iri\"\nto = \"ExpectPredicate\"\n"
  let dup = trans_src + tail
  assert_eq(
    n3_neg_check(n3gen_build(base_src, dup, "0"), "(from,on) 重复"),
    true,
  )
}

///|
async test "G4 guard and assign whitelist gates" {
  let (base_src, trans_src) = n3_load()
  let bad_guard = trans_src.replace(
    old="guard_def = \"directive_at\"",
    new="guard_def = \"not_a_field\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_guard, "0"), "guard_def"),
    true,
  )
  let bad_assign = trans_src.replace(
    old="assign = \"directive_at=false\"",
    new="assign = \"nope=false\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_assign, "0"), "assign 左值"),
    true,
  )
}

///|
async test "G5 actions order and chain reset gates" {
  let (base_src, trans_src) = n3_load()
  let unsorted = base_src.replace(
    old="name = \"open_slot\"",
    new="name = \"zz_open_slot\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(unsorted, trans_src, "0"), "按名升序"),
    true,
  )
  let bad_reset = base_src.replace(
    old="resets = [\"object\"]",
    new="resets = [\"nope_field\"]",
  )
  assert_eq(
    n3_neg_check(n3gen_build(bad_reset, trans_src, "0"), "不在字段集合"),
    true,
  )
}

///|
async test "G6 free-text quote gate and extras self gate" {
  let (base_src, trans_src) = n3_load()
  let quoted = base_src.replace(
    old="doc = \"N3 语句全清口径\"",
    new="doc = \"N3 \\\"x\\\" 口径\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(quoted, trans_src, "0"), "禁含引号"),
    true,
  )
  let bad_expr = base_src.replace(
    old="expr = \"self.iri_upcast\"",
    new="expr = \"iri_upcast\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(bad_expr, trans_src, "0"), "self. 前缀"),
    true,
  )
}

///|
async test "G7 unknown key inside transition row" {
  let (base_src, trans_src) = n3_load()
  let bad = trans_src.replace(
    old="on = \"AnnotStart\"\n",
    new="on = \"AnnotStart\"\nbogus = \"x\"\n",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad, "0"), "未知键"),
    true,
  )
}

///|
async test "G8 action_args closed vocabulary gate" {
  let (base_src, trans_src) = n3_load()
  // ctx.<字段> 未解析
  let bad_ctx = trans_src.replace(
    old="state:ListAfterElem\"]",
    new="state:ListAfterElem\", \"ctx.nope\"]",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_ctx, "0"), "出封闭词表"),
    true,
  )
  // state:<状态> 未解析
  let bad_state = trans_src.replace(
    old="state:ListAfterElem\"]",
    new="state:NoSuchState\"]",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_state, "0"), "出封闭词表"),
    true,
  )
  // 裸词出词表
  let bad_bare = trans_src.replace(
    old="action_args = [\"payload\", \"SlotType::BnodeProp\"",
    new="action_args = [\"payload\", \"foo bar\"",
  )
  assert_eq(
    n3_neg_check(n3gen_build(base_src, bad_bare, "0"), "出封闭词表"),
    true,
  )
}

///|
async test "G9 v2 target parity gate" {
  let base_src = @fs.read_file("src/n3gen/n3v2_base.toml").text()
  let trans_src = @fs.read_file("src/n3gen/n3v2_trans.toml").text()
  let out = match n3gen_build(base_src, trans_src, "1788955337965") {
    Ok(s) => s
    Err(e) => {
      assert_eq("v2 build should pass", e)
      abort("unreachable")
    }
  }
  // 先落件再对拍（役16 教训：assert 先行则失配时永不写盘，再生死锁）；
  // 失配红 = 表对领先黄金件，cp src/n3gen/n3v2_out.gen src/gen_n3v2/n3.mbt 交付
  @fs.write_file("src/n3gen/n3v2_out.gen", @utf8.encode(out))
  let golden = @fs.read_file("src/gen_n3v2/n3.mbt").text()
  assert_eq(out, golden)
}
