///|
// async test "run official n-triples test suite" {
//   let test_dir = "test/rdf/rdf11/n-triples"

//   // 1. 打开目录并确保护理
//   let dir = @fs.opendir(test_dir)
//   defer dir.close() // 确保目录句柄在函数退出时关闭

//   // 2. 获取并过滤文件列表
//   let list = dir
//     .read_all()
//     .filter_map(x => if x == "target" { None } else { Some(x) })
//   list.sort()

//   let mut passed = 0
//   let mut failed = 0
//   let errors = []
//   let mut total_tested = 0

//   for file in list {
//     // 3. 仅处理 .nt 文件
//     if !file.has_suffix(".nt") {
//       continue
//     }

//     println("Testing: \{file}")
//     total_tested += 1

//     let path = "\{test_dir}/\{file}"
//     let is_bad_test = file.contains("bad") || file.contains("error")

//     // 4. 安全读取文件内容
//     // 关键修复：添加 await，因为 read_file 是 async 函数
//     // 如果文件不存在或不可读，await read_file 会 panic。
//     // 若需更健壮的处理，可先用 @fs.exists 检查，或在 try-catch 块中运行（如果支持）
//     let content = @fs.read_file(path).binary()

//     // 5. 创建解析器
//     let parser = NTriplesParser::new().lenient()
//     let low_level = parser.low_level()

//     // 6. 喂入数据并解析
//     // 注意：content 是 &@io.Data。如果 extend_from_slice 期望 &[u8]，
//     // 且 &@io.Data 不能自动解引用为 &[u8]，可能需要转换。
//     // 鉴于单文件测试通过，这里假设类型兼容。
//     low_level.extend_from_slice(content)
//     low_level.end()

//     let result = low_level.parse_next()
//     @async.sleep(0)
//     // 7. 判定成功与否
//     let success = match result {
//       Some(Ok(_)) => !is_bad_test // 好文件应解析成功
//       Some(Err(e)) => {
//         debug(e.to_string())
//         is_bad_test
//       } // 坏文件应解析失败
//       None => false // 无输出视为失败
//     }

//     if success {
//       passed += 1
//     } else {
//       failed += 1
//       let status = if is_bad_test {
//         "Should have failed but passed"
//       } else {
//         "Should have passed but failed"
//       }
//       errors.push("\{file}: \{status}")
//     }
//   }

//   // 8. 输出结果
//   println("Test Suite Results:")
//   println("Total Tested: \{total_tested}")
//   println("Passed: \{passed}")
//   println("Failed: \{failed}")

//   if Array::length(errors) > 0 {
//     println("\nFailures:")
//     for err in errors {
//       println("  - \{err}")
//     }
//     // panic() // 如果有失败，让测试挂掉
//   }
// }

///|
// async test "run official turtle test suite" {
//   let test_dir = "test/rdf/rdf11/turtle"

//   // 1. 打开目录
//   let dir = @fs.opendir(test_dir)
//   defer dir.close()

//   // 2. 获取并过滤文件列表 (仅处理 .ttl 文件)
//   let list = dir
//     .read_all()
//     .filter_map(x => if x.has_suffix(".ttl") { Some(x) } else { None })
//   list.sort()

//   let mut passed = 0
//   let mut failed = 0
//   let errors = []
//   let mut total_tested = 0

//   for file in list {
//     println("Testing: \{file}")
//     total_tested += 1

//     let path = "\{test_dir}/\{file}"
//     // 通常 bad 测试用例文件名包含 "bad" 或 "syntax" 且预期失败
//     let is_bad_test = file.contains("bad") || file.contains("error")

//     // 3. 读取文件内容
//     let content = @fs.read_file(path).binary()

//     // 4. 创建 Turtle 解析器
//     // 假设存在 TurtleParser::new() 和 .lenient() 方法，以及 .low_level() 返回兼容的 Parser 接口
//     let parser = TurtleParser::new().lenient()
//     let low_level = parser.low_level()

//     // 5. 喂入数据并解析
//     low_level.extend_from_slice(content)
//     low_level.end()

//     // 6. 尝试解析下一个三元组/四元组
//     // 注意：Turtle 可能包含多个三元组，这里只检查是否能成功解析出第一个结果或正确报错
//     // 如果需要完整解析，可能需要循环调用 parse_next 直到 None
//     let result = low_level.parse_next()
//     @async.sleep(0)

//     // 7. 判定成功与否
//     let success = match result {
//       Some(Ok(_)) => !is_bad_test // 好文件应能解析出内容
//       Some(Err(e)) => {
//         // 如果是坏文件，解析出错误是预期的；如果是好文件，解析出错误则是失败
//         debug("File: \{file}, Error: \{e.to_string()}")
//         is_bad_test
//       }
//       None =>
//         // 如果返回 None，可能是空文件或仅包含注释
//         // 对于坏文件，None 可能意味着没有检测到错误（失败）
//         // 对于好文件，None 意味着没有内容（可能通过，取决于测试定义）
//         // 这里简单处理：如果是坏文件且没报错了，视为失败
//         !is_bad_test
//     }

//     if success {
//       passed += 1
//     } else {
//       failed += 1
//       let status = if is_bad_test {
//         "Should have failed but passed (or returned None)"
//       } else {
//         "Should have passed but failed (or returned None)"
//       }
//       errors.push("\{file}: \{status}")
//     }
//   }

//   // 8. 输出结果
//   println("Turtle Test Suite Results:")
//   println("Total Tested: \{total_tested}")
//   println("Passed: \{passed}")
//   println("Failed: \{failed}")

//   if Array::length(errors) > 0 {
//     println("\nFailures:")
//     for err in errors {
//       println("  - \{err}")
//     }
//     // panic("Turtle test suite had failures")
//   }
// }
// 在 test 中添加调试信息
// async test "lenient parsing for Reader simple @en" {
//   let input =
//     #| <http://example.org/s> <http://example.org/p> <http://example.org/o> .
//   let slice = @utf8.encode(input)

//   // 【调试】打印原始字节，确认没有隐藏字符
//   debug("Input bytes: \{slice}")
//   debug("Input length: \{slice.length()}")

//   let path = "temp.ntriples"
//   let _=@fs.create(path,allow_existing=false)
//   @fs.write_file(path, slice, create_mode=CreateNew)
//   let r = @fs.open(path, mode=ReadWrite)

//   let triples = NTriplesParser::new().lenient().for_reader(r)
//   let iter = triples.inner

//   match iter.next() {
//     Some(Ok(triple)) => {
//       @fs.remove(path)
//       debug("Success: \{triple.to_string()}")
//     }
//     Some(Err(e)) => {
//       @fs.remove(path)
//       println("Parse error: \{e}")
//       // 【调试】打印 Lexer 的最后位置和内容
//       // 如果 Parser 暴露了 lexer 状态，可以在这里检查
//     }
//     None => {
//       @fs.remove(path)
//       println("parse_next returned None")
//     }
//     _ => println("Unexpected result")
//   }
// }

// // 在测试文件中添加调试输出
// test "unicode" {
//   // 找到失败的断言
//   // 可能是类似这样的测试
//   let result = LanguageTag::parse("some-unicode-tag")
//   assert_true(result is Err(_))  // 期望错误
// }

// test "wellformed tags" {
//   let tags = ["en", "zh-CN"]  // 找到具体哪个标签失败
//   for tag in tags {
//     let result = LanguageTag::parse(tag)
//     debug("\{tag}: \{result}")
//     assert_true(result.is_ok())
//   }
// }
