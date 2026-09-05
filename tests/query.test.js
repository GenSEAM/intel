import test from "node:test";
import assert from "node:assert/strict";
import { SymbolGraph } from "../bridges/graph_engine.js";

test("SymbolGraph computes multi-hop transitive reachability impact and affected chains", () => {
  const graph = new SymbolGraph("/tmp/query-workspace");

  // Chain: E -> B, A -> B -> C -> D
  // modD defines fn-d
  graph.addFile("src/d.asl", `(df fn-d [] -> I64 100)`);
  // modC calls fn-d
  graph.addFile("src/c.asl", `(df fn-c [] -> I64 (fn-d))`);
  // modB calls fn-c
  graph.addFile("src/b.asl", `(df fn-b [] -> I64 (fn-c))`);
  // modA calls fn-b
  graph.addFile("src/a.asl", `(df fn-a [] -> I64 (fn-b))`);
  // modE calls fn-b
  graph.addFile("src/e.asl", `(df fn-e [] -> I64 (fn-b))`);

  // Changing fn-d: who is impacted?
  // fn-c (depth 1), fn-b (depth 2), fn-a (depth 3), fn-e (depth 3)
  const impactD = graph.getImpact("fn-d");
  assert.equal(impactD.length, 4);

  const impactMap = new Map(impactD.map(x => [x.node.name, x.depth]));
  assert.equal(impactMap.get("fn-c"), 1);
  assert.equal(impactMap.get("fn-b"), 2);
  assert.equal(impactMap.get("fn-a"), 3);
  assert.equal(impactMap.get("fn-e"), 3);

  // What is affected by fn-a?
  // fn-b (depth 1), fn-c (depth 2), fn-d (depth 3)
  const affectedA = graph.getAffected("fn-a");
  assert.equal(affectedA.length, 3);
  const affMap = new Map(affectedA.map(x => [x.node.name, x.depth]));
  assert.equal(affMap.get("fn-b"), 1);
  assert.equal(affMap.get("fn-c"), 2);
  assert.equal(affMap.get("fn-d"), 3);
});

test("SymbolGraph terminates cleanly on recursive or cyclic calls without infinite loops", () => {
  const graph = new SymbolGraph("/tmp/cycle-workspace");

  // Cycle: ping -> pong -> ping
  graph.addFile("src/cycle.asl", `
(df ping [] -> Bool (pong))
(df pong [] -> Bool (ping))
`);

  const impactPing = graph.getImpact("ping");
  assert.equal(impactPing.length, 1);
  assert.equal(impactPing[0].node.name, "pong");

  const affPong = graph.getAffected("pong");
  assert.equal(affPong.length, 1);
  assert.equal(affPong[0].node.name, "ping");
});
