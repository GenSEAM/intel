import test from "node:test";
import assert from "node:assert/strict";
import { encodeSearchResultsAsn, encodeImpactResultsAsn } from "../bridges/asn_encoder.js";

function approxTokens(str) {
  // Conservative BPE token estimate: ~3.7 chars per token for structured code/json
  return Math.ceil(str.length / 3.7);
}

test("ASN S-expression framing delivers >= 60% token reduction over verbose TokenSave JSON", () => {
  const sampleNodes = [];
  for (let i = 0; i < 25; i++) {
    sampleNodes.push({
      id: `packages/asl-mem/src/store.asl#vector-slab-query-${i}`,
      name: `vector-slab-query-${i}`,
      kind: "fn",
      file: "packages/asl-mem/src/store.asl",
      startLine: 100 + i * 15,
      endLine: 112 + i * 15,
      signature: `[(slab VectorSlab) (vec (List F64)) (k I64)] -> (List ScoredIndex)`,
      exported: true,
      doc: "Perform cosine similarity top-k search over contiguous memory vector slab"
    });
  }

  // Verbose JSON Schema representation (similar to TokenSave MCP responses)
  const jsonPayload = JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    result: {
      query: "vector-slab",
      total_matches: sampleNodes.length,
      nodes: sampleNodes.map(s => ({
        symbol_id: s.id,
        name: s.name,
        symbol_kind: s.kind,
        file_path: s.file,
        range: {
          start_line: s.startLine,
          end_line: s.endLine
        },
        type_signature: s.signature,
        is_exported: s.exported,
        documentation: s.doc
      }))
    }
  }, null, 2);

  // Dense ASN S-expression representation
  const asnPayload = encodeSearchResultsAsn("vector-slab", sampleNodes);

  const jsonBytes = Buffer.byteLength(jsonPayload, "utf8");
  const asnBytes = Buffer.byteLength(asnPayload, "utf8");

  const jsonTokens = approxTokens(jsonPayload);
  const asnTokens = approxTokens(asnPayload);

  const reductionPct = ((jsonBytes - asnBytes) / jsonBytes) * 100;

  console.log(`\n=== Token & Byte Economy Benchmark ===`);
  console.log(`TokenSave JSON : ${jsonBytes} bytes | ~${jsonTokens} tokens`);
  console.log(`ASL-Intel ASN  : ${asnBytes} bytes | ~${asnTokens} tokens`);
  console.log(`Savings        : ${reductionPct.toFixed(2)}% reduction`);

  assert(reductionPct >= 60.0, `Expected >= 60% reduction, got ${reductionPct.toFixed(2)}%`);
});
