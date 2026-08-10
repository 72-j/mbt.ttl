// src/main.rs
use oxigraph::io::RdfFormat;
use oxigraph::store::Store;
use std::fs::File;
use std::time::Instant;

fn test_oxigraph(filename: &str) {
    println!("\n=== Oxigraph 解析 {} ===", filename);

    let store = Store::new().expect("Store creation failed");

    let start = Instant::now();
    let file = File::open(filename).expect("File open failed");
    store
        .bulk_loader()
        .load_from_reader(RdfFormat::NQuads, file)  // 使用 load_from_reader
        .expect("Load error");
    let elapsed = start.elapsed().as_millis() as u64;

    // count 是 Result, 需要 unwrap 或 expect
    let count = store.len().expect("Failed to get triple count");
    println!("解析时间: {} ms", elapsed);
    println!("三元组数量: {}", count);
    println!("每秒解析: {}", count as u64 * 1000 / elapsed);
    println!("每三元组: {:.4} ms", elapsed as f64 / count as f64);
}

fn main() {
    for f in ["../test_1000.nq", "../test_10000.nq", "../test_100000.nq"] {
        test_oxigraph(f);
    }
}