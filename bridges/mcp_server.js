#!/usr/bin/env node
// GenSEAM ASL-Intel: Model Context Protocol (MCP) Server & CLI
import readline from "node:readline";
import path from "node:path";
import process from "node:process";
import { SymbolGraph } from "./graph_engine.js";
import {
  encodeContextAsn,
  encodeSearchResultsAsn,
  encodeCallersAsn,
  encodeCalleesAsn,
  encodeImpactResultsAsn
} from "./asn_encoder.js";

const TOOLS = [
  {
    name: "asl_intel_status",
    description: "Check freshness and index status of the ASL-Intel code knowledge graph.",
    inputSchema: {
      type: "object",
      properties: {}
    }
  },
  {
    name: "asl_intel_context",
    description: "Retrieve dense ASN structural outline of a file or module without reading raw files.",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string", description: "Path to file or module relative to repository root" }
      },
      required: ["file"]
    }
  },
  {
    name: "asl_intel_search",
    description: "Search for symbols (functions, types, records, classes) across the codebase.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Symbol name or substring" },
        exact: { type: "boolean", description: "Require exact match (default: false)" },
        limit: { type: "number", description: "Maximum results (default: 20)" }
      },
      required: ["query"]
    }
  },
  {
    name: "asl_intel_callers",
    description: "Find all functions or methods that call the specified symbol.",
    inputSchema: {
      type: "object",
      properties: {
        symbol: { type: "string", description: "Name of the target function or symbol" }
      },
      required: ["symbol"]
    }
  },
  {
    name: "asl_intel_callees",
    description: "Find all functions or methods called by the specified symbol.",
    inputSchema: {
      type: "object",
      properties: {
        symbol: { type: "string", description: "Name of the caller function or symbol" }
      },
      required: ["symbol"]
    }
  },
  {
    name: "asl_intel_impact",
    description: "Compute forward transitive reachability DAG: what components break or are impacted if this symbol changes?",
    inputSchema: {
      type: "object",
      properties: {
        symbol: { type: "string", description: "Target symbol name" },
        max_depth: { type: "number", description: "Maximum traversal depth (default: 5)" }
      },
      required: ["symbol"]
    }
  },
  {
    name: "asl_intel_affected",
    description: "Compute backward dependency reachability DAG: what upstream components lead into this symbol?",
    inputSchema: {
      type: "object",
      properties: {
        symbol: { type: "string", description: "Target symbol name" },
        max_depth: { type: "number", description: "Maximum traversal depth (default: 5)" }
      },
      required: ["symbol"]
    }
  },
  {
    name: "asl_intel_files",
    description: "List all indexed files across the workspace.",
    inputSchema: {
      type: "object",
      properties: {}
    }
  }
];

export class McpServer {
  constructor(workspaceRoot = process.cwd()) {
    this.graph = new SymbolGraph(workspaceRoot);
    this.graph.indexDirectory(".");
  }

  handleRequest(req) {
    const { id, method, params } = req;

    if (method === "initialize") {
      return {
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: "2024-11-05",
          serverInfo: {
            name: "asl-intel",
            version: "0.1.0"
          },
          capabilities: {
            tools: {}
          }
        }
      };
    }

    if (method === "tools/list") {
      return {
        jsonrpc: "2.0",
        id,
        result: {
          tools: TOOLS
        }
      };
    }

    if (method === "tools/call") {
      const { name, arguments: args } = params;
      const text = this.executeTool(name, args || {});
      return {
        jsonrpc: "2.0",
        id,
        result: {
          content: [
            {
              type: "text",
              text
            }
          ]
        }
      };
    }

    return {
      jsonrpc: "2.0",
      id,
      error: {
        code: -32601,
        message: `Method not found: ${method}`
      }
    };
  }

  executeTool(name, args) {
    switch (name) {
      case "asl_intel_status": {
        const stats = this.graph.getStats();
        return `(@status :files ${stats.filesIndexed} :nodes ${stats.nodesCount} :edges ${stats.edgesCount} :synced "${stats.lastSynced}")`;
      }
      case "asl_intel_context": {
        const ctx = this.graph.getContext(args.file);
        return encodeContextAsn(ctx);
      }
      case "asl_intel_search": {
        const results = this.graph.search(args.query, {
          exact: !!args.exact,
          limit: args.limit || 20
        });
        return encodeSearchResultsAsn(args.query, results);
      }
      case "asl_intel_callers": {
        const callers = this.graph.getCallers(args.symbol);
        return encodeCallersAsn(args.symbol, callers);
      }
      case "asl_intel_callees": {
        const callees = this.graph.getCallees(args.symbol);
        return encodeCalleesAsn(args.symbol, callees);
      }
      case "asl_intel_impact": {
        const impact = this.graph.getImpact(args.symbol, args.max_depth || 5);
        return encodeImpactResultsAsn(args.symbol, impact);
      }
      case "asl_intel_affected": {
        const affected = this.graph.getAffected(args.symbol, args.max_depth || 5);
        return encodeImpactResultsAsn(args.symbol, affected);
      }
      case "asl_intel_files": {
        const files = Array.from(this.graph.fileIndex.keys());
        return `(@files :total ${files.length}\n  ${files.map(f => `"${f}"`).join("\n  ")}\n)`;
      }
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  }

  startStdio() {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: false
    });

    rl.on("line", (line) => {
      if (!line.trim()) return;
      try {
        const req = JSON.parse(line);
        const res = this.handleRequest(req);
        process.stdout.write(JSON.stringify(res) + "\n");
      } catch (err) {
        process.stdout.write(JSON.stringify({
          jsonrpc: "2.0",
          id: null,
          error: { code: -32700, message: `Parse error: ${err.message}` }
        }) + "\n");
      }
    });
  }
}

// CLI / Stdio Entrypoint
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const server = new McpServer(process.cwd());

  if (args.includes("--status")) {
    console.log(server.executeTool("asl_intel_status", {}));
  } else if (args.includes("--search")) {
    const qIdx = args.indexOf("--search") + 1;
    console.log(server.executeTool("asl_intel_search", { query: args[qIdx] || "" }));
  } else {
    // Default to stdio MCP server mode
    server.startStdio();
  }
}
