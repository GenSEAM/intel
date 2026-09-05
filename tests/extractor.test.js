import test from "node:test";
import assert from "node:assert/strict";
import { detectLanguage, extractSymbolsFromSource } from "../bridges/extractor_bridge.js";

test("detectLanguage recognizes multi-language file extensions", () => {
  assert.equal(detectLanguage("math.asl"), "asl");
  assert.equal(detectLanguage("core.agentscript"), "asl");
  assert.equal(detectLanguage("index.ts"), "typescript");
  assert.equal(detectLanguage("app.jsx"), "javascript");
  assert.equal(detectLanguage("engine.py"), "python");
  assert.equal(detectLanguage("main.rs"), "rust");
  assert.equal(detectLanguage("server.go"), "go");
});

test("extractSymbolsFromSource parses ASL functions, types, and calls", () => {
  const aslSource = `
(:d "Example module" :x [run-task TaskConfig])

(ty TaskConfig
  (record
    (:id Str)
    (:retries I64)))

(df helper [(x I64)] -> I64
  (+ x 1))

(df run-task [(cfg TaskConfig)] -> Bool
  (let [(v (helper 10))]
    (print v)
    true))
`;
  const res = extractSymbolsFromSource("task.asl", aslSource);
  assert.equal(res.language, "asl");
  assert.equal(res.symbols.length, 3);

  const symMap = new Map(res.symbols.map(s => [s.name, s]));
  assert(symMap.has("TaskConfig"));
  assert.equal(symMap.get("TaskConfig").kind, "record");
  assert.equal(symMap.get("TaskConfig").exported, true);

  assert(symMap.has("helper"));
  assert.equal(symMap.get("helper").kind, "fn");
  assert.equal(symMap.get("helper").exported, false);

  assert(symMap.has("run-task"));
  assert.equal(symMap.get("run-task").kind, "fn");
  assert.equal(symMap.get("run-task").exported, true);

  // References
  const refNames = res.refs.map(r => r.name);
  assert(refNames.includes("helper"));
});

test("extractSymbolsFromSource parses TypeScript / JavaScript", () => {
  const tsSource = `
export interface User {
  id: string;
}

export function fetchUser(id: string): User {
  return validate(id);
}

const formatUser = (u: User) => {
  return u.id;
};
`;
  const res = extractSymbolsFromSource("api.ts", tsSource);
  assert.equal(res.language, "typescript");
  assert.equal(res.symbols.length, 3);
  assert.equal(res.symbols[0].name, "User");
  assert.equal(res.symbols[0].kind, "interface");
  assert.equal(res.symbols[1].name, "fetchUser");
  assert.equal(res.symbols[1].exported, true);
  assert.equal(res.symbols[2].name, "formatUser");
});

test("extractSymbolsFromSource parses Python and Rust", () => {
  const pySource = `
class Agent:
    def execute(self, task):
        pass

def _internal():
    pass
`;
  const pyRes = extractSymbolsFromSource("agent.py", pySource);
  assert.equal(pyRes.symbols.length, 3);
  assert.equal(pyRes.symbols[0].name, "Agent");
  assert.equal(pyRes.symbols[0].exported, true);
  assert.equal(pyRes.symbols[2].name, "_internal");
  assert.equal(pyRes.symbols[2].exported, false);

  const rsSource = `
pub struct MemoryBlock;

pub fn alloc(size: usize) -> MemoryBlock {
    MemoryBlock
}

fn internal_init() {}
`;
  const rsRes = extractSymbolsFromSource("mem.rs", rsSource);
  assert.equal(rsRes.symbols.length, 3);
  assert.equal(rsRes.symbols[0].name, "MemoryBlock");
  assert.equal(rsRes.symbols[0].exported, true);
  assert.equal(rsRes.symbols[1].name, "alloc");
  assert.equal(rsRes.symbols[1].exported, true);
  assert.equal(rsRes.symbols[2].name, "internal_init");
  assert.equal(rsRes.symbols[2].exported, false);
});
