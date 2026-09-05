import test from "node:test";
import assert from "node:assert/strict";
import { SymbolGraph } from "../bridges/graph_engine.js";

test("SymbolGraph indexes modules and resolves bidirectional callers/callees", () => {
  const graph = new SymbolGraph("/tmp/test-workspace");

  const modA = `
(:d "Module A" :x [foo])
(df helper [(n I64)] -> I64 n)
(df foo [] -> I64 (helper 42))
`;

  const modB = `
(:d "Module B" :x [bar])
(df bar [] -> I64 (foo))
`;

  graph.addFile("src/a.asl", modA);
  graph.addFile("src/b.asl", modB);

  const stats = graph.getStats();
  assert.equal(stats.filesIndexed, 2);
  assert.equal(stats.nodesCount, 3); // helper, foo, bar

  // Test Search
  const searchFoo = graph.search("foo");
  assert.equal(searchFoo.length, 1);
  assert.equal(searchFoo[0].name, "foo");

  // Test Callers of foo (should be bar)
  const fooCallers = graph.getCallers("foo");
  assert.equal(fooCallers.length, 1);
  assert.equal(fooCallers[0].name, "bar");

  // Test Callees of foo (should be helper)
  const fooCallees = graph.getCallees("foo");
  assert.equal(fooCallees.length, 1);
  assert.equal(fooCallees[0].name, "helper");

  // Test Context
  const ctxA = graph.getContext("src/a.asl");
  assert.equal(ctxA.symbols.length, 2);
});
