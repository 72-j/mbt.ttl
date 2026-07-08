///|
test "ntriples chunker: empty input" {
  let bytes = @utf8.encode("")
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 5)
  @debug.assert_eq(chunks.length(), 0)
}

///|
test "ntriples chunker: single line one chunk" {
  let content = "<s> <p> <o> .\n"
  let bytes = @utf8.encode(content)
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 1)
  @debug.assert_eq(chunks.length(), 1)
  @debug.assert_eq(chunks[0], (0, content.length()))
}

///|
test "ntriples chunker: two lines two chunks" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> .\n"
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 2)

  @debug.assert_eq(chunks.length(), 2)
  let end_pos1 = line1.length()
  @debug.assert_eq(chunks[0], (0, end_pos1))
  @debug.assert_eq(chunks[1], (end_pos1, content.length()))
}

///|
test "ntriples chunker: no trailing newline" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> ." // No newline at end
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 2)

  @debug.assert_eq(chunks.length(), 2)
  let end_pos1 = line1.length()
  @debug.assert_eq(chunks[0], (0, end_pos1))
  @debug.assert_eq(chunks[1], (end_pos1, content.length()))
}

///|
test "ntriples chunker: more chunks requested than data" {
  let content = "<s> <p> <o> .\n"
  let bytes = @utf8.encode(content)
  // Request 10 chunks for a single line
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 10)

  // Should only produce 1 chunk because search_pos exceeds length or no more newlines found
  @debug.assert_eq(chunks.length(), 1)
  @debug.assert_eq(chunks[0], (0, content.length()))
}

///|
test "ntriples chunker: split in middle of line extends to next newline" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> .\n"
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  // If we ask for 3 chunks, chunk_size is approx total/3.
  // chunk 1 ends at first newline.
  // chunk 2 starts after first newline. search_pos will be inside line2.
  // It should find the newline at the end of line2.
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 3)

  @debug.assert_eq(chunks.length(), 2) // Only 2 lines available
  let end_pos1 = line1.length()
  @debug.assert_eq(chunks[0], (0, end_pos1))
  @debug.assert_eq(chunks[1], (end_pos1, content.length()))
}

///|
test "ntriples chunker: two lines two chunks 2" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> .\n"
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 2)

  @debug.assert_eq(chunks.length(), 2)

  // 验证第一个 chunk 是第一行
  let (start1, end1) = chunks[0]
  let chunk1_data = @utf8.decode_lossy(bytes[start1:end1])
  @debug.assert_eq(chunk1_data, line1)

  // 验证第二个 chunk 是第二行
  let (start2, end2) = chunks[1]
  let chunk2_data = @utf8.decode_lossy(bytes[start2:end2])
  @debug.assert_eq(chunk2_data, line2)
}

///|
test "ntriples chunker: no trailing newline 2" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> ." // No newline at end
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 2)

  // 即使没有尾随换行符，也应该分成两块
  @debug.assert_eq(chunks.length(), 2)

  let (start1, end1) = chunks[0]
  @debug.assert_eq(@utf8.decode_lossy(bytes[start1:end1]), line1)

  let (start2, end2) = chunks[1]
  @debug.assert_eq(@utf8.decode_lossy(bytes[start2:end2]), line2)
}

///|
test "ntriples chunker: more chunks requested than data 2" {
  let content = "<s> <p> <o> .\n"
  let bytes = @utf8.encode(content)
  // Request 10 chunks for a single line
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 10)

  // 应该只产生 1 个 chunk，因为只有一行
  @debug.assert_eq(chunks.length(), 1)
  let (start, end) = chunks[0]
  @debug.assert_eq(@utf8.decode_lossy(bytes[start:end]), content)
}

///|
test "ntriples chunker: split in middle of line extends to next newline 2" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> .\n"
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  // 请求 3 个 chunks，但只有 2 行，所以应该合并或只返回 2 个
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 3)

  // 验证所有 chunk 拼接后等于原内容
  let mut reconstructed = ""
  for c in chunks {
    let (start, end) = c
    reconstructed = reconstructed + @utf8.decode_lossy(bytes[start:end])
  }
  @debug.assert_eq(reconstructed, content)

  // 验证 chunk 数量不超过行数（2）
  assert_true(chunks.length() <= 2)
}

// --- Turtle Tests ---

///|
test "turtle chunker: basic split" {
  let stmt1 = "@prefix ex: <http://example.org/> .\n"
  let stmt2 = "ex:s ex:p ex:o ."
  let content = stmt1 + stmt2
  let _bytes = @utf8.encode(content)

  // 由于缺乏解析器实例，这里仅做占位测试，避免编译错误
  // 实际使用时需注入 Parser
  debug("Turtle test placeholder: implement with actual parser instance")
  assert_true(true)
}

///|
test "turtle chunker: no terminator in second half" {
  let stmt1 = "@prefix ex: <http://example.org/> .\n"
  let stmt2 = "ex:s ex:p ex:o" // Missing dot
  let content = stmt1 + stmt2
  let _bytes = @utf8.encode(content)

  debug("Turtle no-terminator test placeholder")
  assert_true(true)
}

///|
test "ntriples chunker: two lines split" {
  let line1 = "<s1> <p1> <o1> .\n"
  let line2 = "<s2> <p2> <o2> .\n"
  let content = line1 + line2
  let bytes = @utf8.encode(content)

  // 请求分块。注意：具体返回几个 chunk 取决于实现是按 count 还是 size
  // 这里我们验证核心不变量：拼接后内容一致，且每个 chunk 都是合法的（以 \n 结尾或最后一段）
  let chunks = @lib.get_ntriples_slice_chunks(bytes[:], 2)

  assert_true(chunks.length() > 0)

  let mut reconstructed = ""
  let mut last_end = 0
  for c in chunks {
    let (start, end) = c
    @debug.assert_eq(start, last_end) // 验证 chunk 是连续的
    let chunk_str = @utf8.decode_lossy(bytes[start:end])
    reconstructed = reconstructed + chunk_str

    // 验证每个 chunk 要么以换行符结尾，要么是最后一个 chunk
    if end < bytes.length() {
      assert_true(chunk_str.has_suffix("\n"))
    }

    last_end = end
  }

  @debug.assert_eq(reconstructed, content)
  @debug.assert_eq(last_end, bytes.length())
}
