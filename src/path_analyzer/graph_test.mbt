///|
test {
  let graph : @moongraph.Graph[String, Int] = @moongraph.Graph::new(
    directed=true,
  )
  let parse = graph.add_node("parse")
  let typecheck = graph.add_node("typecheck")
  let codegen = graph.add_node("codegen")
  let package_node = graph.add_node("package")
  let _ = graph.add_edge(parse, typecheck, 2)
  let _ = graph.add_edge(typecheck, codegen, 4)
  let _ = graph.add_edge(parse, package_node, 5)

  println("MoonGraph demo")
  println("nodes: \{graph.node_count()}, edges: \{graph.edge_count()}")
  println("BFS from parse visits: \{graph.bfs(parse).length()} nodes")
  let distances = graph.dijkstra(parse)
  println("Dijkstra distance to codegen: \{distances[codegen.value()]}")
  println(
    "topological order length: \{graph.topological_sort().unwrap().length()}",
  )
  println(graph.to_dot(fn(node) { node }, fn(weight) { weight.to_string() }))
  ignore(codegen)
  ignore(package_node)
}
