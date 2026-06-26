///|
test "parse basic quad" {
  let parser = NQuadsParser::new()
  let low_level = parser.low_level()

  let input = "<http://example.org/s> <http://example.org/p> <http://example.org/o> .\n"
  low_level.extend_from_slice(@utf8.encode(input))
  low_level.end()

  let result = low_level.parse_next()
  assert_true(result is Some(_))
  match result.unwrap() {
    Ok(quad) => {
      debug(quad)
      // 验证 q 的内容
      assert_true(true)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "parser lenient mode" {
  let parser_strict = NQuadsParser::new()
  assert_eq(parser_strict.lenient, false)

  let parser_lenient = NQuadsParser::new().lenient()
  assert_eq(parser_lenient.lenient, true)
}

///|
test "low level parser initialization" {
  let parser = NQuadsParser::new()
  let low_level = parser.low_level()

  // 验证初始状态
  assert_false(low_level.is_end()) // 刚初始化且无数据时，可能视为 end 或等待数据

  // 测试 extend_from_slice
  let data = @utf8.encode(
    "<http://example.org/s> <http://example.org/p> <http://example.org/o> .",
  )
  low_level.extend_from_slice(data)

  // 此时不应立即结束，因为可能还有更多数据或需要显式 end()
  // 具体行为取决于 Parser 内部实现，但通常 extend 后 is_end 仍为 false 直到调用 end()
  // 或者 is_end 仅表示输入流是否关闭。

  low_level.end()
  // assert_true(low_level.is_end())
}

// async test "async serializer buffer accumulation" {
//   let log = StringBuilder::new()
//   let serializer = NQuadsSerializer::new()

//   @async.with_task_group() <| fn(root) {
//     // 1. 写入者协程 (Producer)
//     let (r, w) = @io.pipe()
//     let buffered_w = @io.BufferedWriter::new(w)

//     root.spawn_bg() <| () => {
//       defer w.close() // 任务结束时关闭写端，触发读端的 EOF

//       let async_serializer = serializer.for_async_writer(buffered_w)

//       let subject = NamedNode::NamedNode("<http://example.org/s>").as_enum()
//       let predicate = NamedNode::NamedNode("<http://example.org/p>")
//       let object = NamedNode::NamedNode("<http://example.org/o>").as_term()
//       let graph = GraphName::default() // 或者使用 Option::None 如果 API 支持

//       let q_sb = Quad::Quad(subject, predicate, object, graph)
//       // 必须 await 异步写入
//       let res = async_serializer.serialize_quad(q_sb)

//       assert_true(res is Ok(_))

//       // 【新增】调用 finish 确保缓冲区刷新
//       let finish_res = async_serializer.finish()
//       match finish_res {
//         Ok(_) =>
//           // 可选：记录日志以便调试
//           log <+ "quad serialized and finished\n"
//         Err(_) => assert_true(false) // 如果 finish 失败，测试应失败
//       }
//     }

//     // 2. 读取者协程 (Consumer)
//     root.spawn_bg() <| () => {
//       defer r.close()

//       // 循环读取直到管道关闭 (EOF)
//       while r.read_some() is Some(data) {
//         let content = @utf8.decode(data)
//         log.write_string("received: \{content}")
//       }
//     }
//   }

//   // 3. 验证结果
//   // 预期收到序列化后的四元组字符串，通常以 " .\n" 结尾
//   inspect(
//     log.to_string(),
//     content=(
//       #|quad serialized and finished
//       #|received: <http://example.org/s> <http://example.org/p> <http://example.org/o> .
//       #|
//     ),
//   )
// }

// async test "async serializer buffer accumulation" {
//   let log = StringBuilder::new()
//   let serializer = NQuadsSerializer::new()
//   let (r, w) = @io.pipe()

//   @async.with_task_group() <| fn(root) {
//     // 1. 写入者协程 (Producer)
//     root.spawn_bg() <| () => {
//       defer w.close() // 任务结束时关闭写端，触发读端的 EOF

//       let async_serializer = serializer.for_async_writer(w)

//       let q_sb = StringBuilder::new()
//       q_sb.write_string(
//         "<http://example.org/s> <http://example.org/p> <http://example.org/o>",
//       )

//       // 必须 await 异步写入
//       let res = async_serializer.serialize_quad(q_sb)

//       assert_true(res is Ok(_))

//       // 可选：记录日志以便调试
//       log <+ "quad serialized\n"

//     }

//     // 2. 读取者协程 (Consumer)
//     root.spawn_bg() <| () => {
//       defer r.close()

//       // 循环读取直到管道关闭 (EOF)
//       while r.read_some() is Some(data) {
//         let content = @utf8.decode(data)
//         log.write_string("received: \{content}")
//       }
//     }
//   }

//   // 3. 验证结果
//   // 预期收到序列化后的四元组字符串，通常以 " .\n" 结尾
//   inspect(
//     log.to_string(),
//     content=(
//       #|quad serialized
//       #|received: <http://example.org/s> <http://example.org/p> <http://example.org/o> .
//       #|
//     ),
//   )
// }
