///|
async test {
  // 测试基本解析
  let toml_content = @fs.read_file("./src/fsm/test.toml").text()
  let result = parse_toml(toml_content)
  guard result is Ok(ir) else { fail("Failed to parse TOML") }

  // 验证版本
  assert_eq(ir.version, 1)

  // 验证事件数量
  assert_eq(ir.events.length(), 4)

  // 验证状态数量
  assert_eq(ir.states.length(), 3)

  // 验证转移数量
  assert_eq(ir.transitions.length(), 4)

  // 验证事件名称
  let event_names = ir.events.map(fn(e) { e.name })
  assert_true(event_names.contains("start"))
  assert_true(event_names.contains("stop"))
  assert_true(event_names.contains("pause"))
  assert_true(event_names.contains("resume"))

  // 验证事件名称
  let event_names = ir.events.map(fn(e) { e.name })
  assert_true(event_names.contains("start"))
  assert_true(event_names.contains("stop"))
  assert_true(event_names.contains("pause"))
  assert_true(event_names.contains("resume"))

  // 验证状态名称和初始状态
  let idle_states = ir.states.filter(fn(s) { s.name == "idle" })
  guard not(idle_states.is_empty()) else { fail("idle state not found") }
  let idle_state = idle_states[0]
  assert_true(idle_state.is_initial)

  let running_states = ir.states.filter(fn(s) { s.name == "running" })
  guard not(running_states.is_empty()) else { fail("running state not found") }
  let running_state = running_states[0]
  assert_false(running_state.is_initial)

  // 验证转移
  // idle (id=0) -> running (id=1) on start (id=0)
  let trans1 = ir.transitions.filter(fn(t) {
    t.from_state == 0 && t.on_event == 0
  })
  guard not(trans1.is_empty()) else {
    fail("transition idle->running not found")
  }
  assert_eq(trans1[0].to_state, 1)

  // running (id=1) -> idle (id=0) on stop (id=1)
  let trans2 = ir.transitions.filter(fn(t) {
    t.from_state == 1 && t.on_event == 1
  })
  guard not(trans2.is_empty()) else {
    fail("transition running->idle not found")
  }
  assert_eq(trans2[0].to_state, 0)
}

///|
test {
  // 测试错误处理：无效 TOML
  let result = parse_toml("invalid = [unclosed")
  guard result is Err(_) else { fail("Should fail on invalid TOML") }
}

///|
test {
  // 测试错误处理：缺少必需字段
  let result = parse_toml("version = 1")
  guard result is Ok(_) else { fail("Should accept minimal TOML") }
}

///|
test {
  // 测试错误处理：缺少必需字段（空 TOML）
  let result = parse_toml("")
  // 空 TOML 应该被解析为一个空表
  guard result is Ok(_) else { fail("Should accept empty TOML") }
}
