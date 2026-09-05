import test from "node:test";
import assert from "node:assert/strict";
import { McpServer } from "../bridges/mcp_server.js";

test("McpServer handles initialize and lists 8 core tools", () => {
  const server = new McpServer("/tmp/test-mcp");

  const initRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {}
  });
  assert.equal(initRes.result.serverInfo.name, "asl-intel");
  assert.equal(initRes.result.serverInfo.version, "0.1.0");

  const listRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 2,
    method: "tools/list",
    params: {}
  });
  assert.equal(listRes.result.tools.length, 8);
  const toolNames = listRes.result.tools.map(t => t.name);
  assert(toolNames.includes("asl_intel_status"));
  assert(toolNames.includes("asl_intel_search"));
  assert(toolNames.includes("asl_intel_context"));
  assert(toolNames.includes("asl_intel_callers"));
  assert(toolNames.includes("asl_intel_callees"));
  assert(toolNames.includes("asl_intel_impact"));
  assert(toolNames.includes("asl_intel_affected"));
  assert(toolNames.includes("asl_intel_files"));
});

test("McpServer executes tools/call returning dense ASN frames", () => {
  const server = new McpServer("/tmp/test-mcp");

  server.graph.addFile("src/engine.asl", `
(:d "Engine" :x [start-engine])
(df helper [] -> Bool true)
(df start-engine [] -> Bool (helper))
`);

  // Call asl_intel_status
  const statusRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 3,
    method: "tools/call",
    params: {
      name: "asl_intel_status",
      arguments: {}
    }
  });
  assert(statusRes.result.content[0].text.includes("@status"));
  assert(statusRes.result.content[0].text.includes(":nodes 2"));

  // Call asl_intel_search
  const searchRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 4,
    method: "tools/call",
    params: {
      name: "asl_intel_search",
      arguments: { query: "start-engine" }
    }
  });
  assert(searchRes.result.content[0].text.includes("@search"));
  assert(searchRes.result.content[0].text.includes("start-engine"));

  // Call asl_intel_impact
  const impactRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 5,
    method: "tools/call",
    params: {
      name: "asl_intel_impact",
      arguments: { symbol: "helper" }
    }
  });
  assert(impactRes.result.content[0].text.includes("@impact"));
  assert(impactRes.result.content[0].text.includes("start-engine"));

  // Call asl_intel_context
  const ctxRes = server.handleRequest({
    jsonrpc: "2.0",
    id: 6,
    method: "tools/call",
    params: {
      name: "asl_intel_context",
      arguments: { file: "src/engine.asl" }
    }
  });
  assert(ctxRes.result.content[0].text.includes("@ctx"));
  assert(ctxRes.result.content[0].text.includes("start-engine"));
});
