# Gap Analysis: @genseam/asl-intel vs TokenSave

1. **Token Inefficiency in TokenSave**:
   - TokenSave serializes results as verbose JSON with redundant schema fields, keys (`name`, `kind`, `start_line`, etc.), consuming ~2,000–5,000 tokens for moderate symbol lists.
   - ASL-Intel Solution: Compact ASN S-expressions (`(:sym :name foo :kind fn :loc "a.asl:10" :sig "[I64] -> I64")`) yielding $\ge 60\%$ reduction.
2. **Language Coverage**:
   - TokenSave has hardcoded AST queries for limited languages and is bound to a Python runtime.
   - ASL-Intel Solution: Native ASL AST parser for AgentScript (`.asl`, `.agentscript`) + standard Tree-Sitter grammars for TS, JS, Python, Rust, Go.
3. **Graph Traversal Complexity**:
   - TokenSave uses SQLite joins across `nodes` and `edges` which can incur disk I/O and query latency on deep reachability chains.
   - ASL-Intel Solution: Pure in-memory forward/backward adjacency arrays backed by `@genseam/asl-mem` ($O(1)$ edge access, sub-millisecond BFS closure).
4. **Zero-Python Requirement**:
   - ASL-Intel runs natively on ASL Wasm / Node runtime without virtualenv or pip dependencies.
