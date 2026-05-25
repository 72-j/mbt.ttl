# MoonTTL

MoonTTL 是一个使用 MoonBit 语言编写的高性能 RDF 解析与序列化库。本项目移植自 Rust 生态中的优秀库 Oxttl，旨在为 MoonBit 生态提供一套标准化、轻量级的语义网数据处理引擎。

##  特性

- **多格式支持**：完整支持 Turtle, TriG, N-Triples, N-Quads 和 N3 格式的解析与序列化。
- **RDF 1.2 兼容**：除 N3 外，全面支持最新的 RDF 1.2 国际标准规范。
- **高性能**：基于 MoonBit 的高性能编译后端，提供低内存占用的流式解析能力。
- **纯 MoonBit 实现**：利用 MoonBit 的原生类型系统和 GC 机制，提供简洁的 API 体验。

##  安装

确保你的环境中已经安装了 MoonBit 工具链。

在你的 `moon.mod.json` 中添加依赖：

```json
{
  "name": "your_username/your_project",
  "deps": [
    "thy7/moonttl"
  ]
}
```

## License

This project is licensed under either of

* Apache License, Version 2.0, ([LICENSE-APACHE](../LICENSE-APACHE) or
  `<http://www.apache.org/licenses/LICENSE-2.0>`)
* MIT license ([LICENSE-MIT](../LICENSE-MIT) or
  `<http://opensource.org/licenses/MIT>`)

at your option.


### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in Oxigraph by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
