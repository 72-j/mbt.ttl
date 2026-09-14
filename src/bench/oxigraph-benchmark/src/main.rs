// src/main.rs
// 两档口径（与 MoonBit 侧对齐用）：
//   ① 解析 + 建图：bulk_loader → Store（历史口径）
//   ② 只解析不建图：RdfParser 迭代器逐条取出即计数（对应 MoonBit 的"不物化"）
use oxigraph::io::{RdfFormat, RdfParser};
use oxigraph::store::Store;
use std::fs::File;
use std::time::Instant;

fn test_with_store(filename: &str) {
    println!("\n=== Oxigraph 解析+建图 {} ===", filename);

    let store = Store::new().expect("Store creation failed");

    let start = Instant::now();
    let file = File::open(filename).expect("File open failed");
    store
        .bulk_loader()
        .load_from_reader(RdfFormat::NQuads, file)
        .expect("Load error");
    let us = start.elapsed().as_micros();

    let count = store.len().expect("Failed to get triple count");
    let ms = us as f64 / 1000.0;
    println!("解析时间: {:.3} ms", ms);
    println!("三元组数量: {}", count);
    println!("每秒解析: {:.0}", count as f64 / (ms / 1000.0));
    println!("每三元组: {:.6} ms", ms / count as f64);
}

fn test_parse_only(filename: &str) {
    println!("\n=== Oxigraph 只解析不建图 {} ===", filename);

    let file = File::open(filename).expect("File open failed");
    let start = Instant::now();
    let mut count = 0u64;
    for quad in RdfParser::from_format(RdfFormat::NQuads).for_reader(file) {
        assert!(quad.is_ok(), "parse error");
        count += 1;
    }
    let us = start.elapsed().as_micros();
    let ms = us as f64 / 1000.0;
    println!("解析时间: {:.3} ms", ms);
    println!("三元组数量: {}", count);
    println!("每秒解析: {:.0}", count as f64 / (ms / 1000.0));
    println!("每三元组: {:.6} ms", ms / count as f64);
}

fn main() {
    for f in ["../test_1000.nq", "../test_10000.nq"] {
        test_with_store(f);
        test_parse_only(f);
    }
}
