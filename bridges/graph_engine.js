// In-Memory Symbol Knowledge Graph Engine
import fs from "node:fs";
import path from "node:path";
import { extractSymbolsFromSource, detectLanguage } from "./extractor_bridge.js";

export class SymbolGraph {
  constructor(rootPath = process.cwd()) {
    this.rootPath = path.resolve(rootPath);
    this.nodes = new Map();         // id -> Node
    this.nameIndex = new Map();     // name -> Set<id>
    this.fileIndex = new Map();     // file -> Set<id>
    this.forwardAdj = new Map();    // srcId -> Set<dstId> (callees)
    this.backwardAdj = new Map();   // dstId -> Set<srcId> (callers)
    this.edges = [];                // all edges
    this.lastSynced = new Date();
  }

  addFile(relPath, source) {
    const normPath = relPath.startsWith("/") ? path.relative(this.rootPath, relPath) : relPath;
    const { symbols, refs } = extractSymbolsFromSource(normPath, source);

    // Clear existing nodes for this file
    if (this.fileIndex.has(normPath)) {
      for (const id of this.fileIndex.get(normPath)) {
        const node = this.nodes.get(id);
        if (node && this.nameIndex.has(node.name)) {
          this.nameIndex.get(node.name).delete(id);
        }
        this.nodes.delete(id);
        this.forwardAdj.delete(id);
        this.backwardAdj.delete(id);
      }
      this.fileIndex.delete(normPath);
    }

    const fileNodeIds = new Set();
    const localNameToId = new Map();

    for (const sym of symbols) {
      const id = `${normPath}#${sym.name}`;
      const node = {
        id,
        name: sym.name,
        kind: sym.kind,
        file: normPath,
        startLine: sym.startLine,
        endLine: sym.endLine,
        signature: sym.signature,
        exported: sym.exported,
        doc: sym.doc
      };

      this.nodes.set(id, node);
      fileNodeIds.add(id);
      localNameToId.set(sym.name, id);

      if (!this.nameIndex.has(sym.name)) {
        this.nameIndex.set(sym.name, new Set());
      }
      this.nameIndex.get(sym.name).add(id);
    }

    this.fileIndex.set(normPath, fileNodeIds);

    // Wire call edges
    for (const ref of refs) {
      const callerId = localNameToId.get(ref.caller) || `${normPath}#${ref.caller}`;
      // Target could be local or global
      let targetIds = this.nameIndex.get(ref.name);
      if (!targetIds && localNameToId.has(ref.name)) {
        targetIds = new Set([localNameToId.get(ref.name)]);
      }

      if (targetIds) {
        for (const targetId of targetIds) {
          if (callerId !== targetId) {
            this._addEdge(callerId, targetId, "calls", normPath, ref.line);
          }
        }
      }
    }
  }

  _addEdge(srcId, dstId, kind, file, line) {
    if (!this.forwardAdj.has(srcId)) this.forwardAdj.set(srcId, new Set());
    this.forwardAdj.get(srcId).add(dstId);

    if (!this.backwardAdj.has(dstId)) this.backwardAdj.set(dstId, new Set());
    this.backwardAdj.get(dstId).add(srcId);

    this.edges.push({ src: srcId, dst: dstId, kind, file, line });
  }

  indexDirectory(dirPath, { excludes = ["node_modules", ".git", "dist", ".venv", ".tokensave"] } = {}) {
    const fullDir = path.resolve(this.rootPath, dirPath);
    const files = [];

    const walk = (d) => {
      const entries = fs.readdirSync(d, { withFileTypes: true });
      for (const e of entries) {
        if (excludes.includes(e.name)) continue;
        const res = path.join(d, e.name);
        if (e.isDirectory()) {
          walk(res);
        } else if (e.isFile()) {
          if (detectLanguage(res) !== "unknown") {
            files.push(res);
          }
        }
      }
    };

    walk(fullDir);

    for (const f of files) {
      try {
        const src = fs.readFileSync(f, "utf8");
        this.addFile(path.relative(this.rootPath, f), src);
      } catch (err) {
        // Skip unreadable files
      }
    }
    this.lastSynced = new Date();
  }

  search(query, { exact = false, limit = 20 } = {}) {
    const q = query.toLowerCase();
    const results = [];

    for (const [name, ids] of this.nameIndex.entries()) {
      const match = exact ? (name.toLowerCase() === q) : (name.toLowerCase().includes(q));
      if (match) {
        for (const id of ids) {
          const node = this.nodes.get(id);
          if (node) results.push(node);
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  getCallers(symbolName) {
    const callers = [];
    const targetIds = this.nameIndex.get(symbolName);
    if (!targetIds) return callers;

    for (const targetId of targetIds) {
      const incoming = this.backwardAdj.get(targetId);
      if (incoming) {
        for (const callerId of incoming) {
          const node = this.nodes.get(callerId);
          if (node) callers.push(node);
        }
      }
    }
    return callers;
  }

  getCallees(symbolName) {
    const callees = [];
    const srcIds = this.nameIndex.get(symbolName);
    if (!srcIds) return callees;

    for (const srcId of srcIds) {
      const outgoing = this.forwardAdj.get(srcId);
      if (outgoing) {
        for (const calleeId of outgoing) {
          const node = this.nodes.get(calleeId);
          if (node) callees.push(node);
        }
      }
    }
    return callees;
  }

  getImpact(symbolName, maxDepth = 5) {
    // Forward reachability: what breaks if symbolName changes?
    const impacted = new Map(); // id -> depth
    const startIds = this.nameIndex.get(symbolName) || new Set();
    const queue = [...startIds].map(id => ({ id, depth: 0 }));

    while (queue.length > 0) {
      const { id, depth } = queue.shift();
      if (depth >= maxDepth) continue;

      const callers = this.backwardAdj.get(id);
      if (callers) {
        for (const callerId of callers) {
          if (!impacted.has(callerId) && !startIds.has(callerId)) {
            impacted.set(callerId, depth + 1);
            queue.push({ id: callerId, depth: depth + 1 });
          }
        }
      }
    }

    return Array.from(impacted.entries()).map(([id, depth]) => ({
      node: this.nodes.get(id),
      depth
    })).filter(x => x.node != null);
  }

  getAffected(symbolName, maxDepth = 5) {
    // Backward reachability: what upstream code feeds into symbolName?
    const affected = new Map();
    const startIds = this.nameIndex.get(symbolName) || new Set();
    const queue = [...startIds].map(id => ({ id, depth: 0 }));

    while (queue.length > 0) {
      const { id, depth } = queue.shift();
      if (depth >= maxDepth) continue;

      const callees = this.forwardAdj.get(id);
      if (callees) {
        for (const calleeId of callees) {
          if (!affected.has(calleeId) && !startIds.has(calleeId)) {
            affected.set(calleeId, depth + 1);
            queue.push({ id: calleeId, depth: depth + 1 });
          }
        }
      }
    }

    return Array.from(affected.entries()).map(([id, depth]) => ({
      node: this.nodes.get(id),
      depth
    })).filter(x => x.node != null);
  }

  getContext(filepath) {
    const norm = filepath.startsWith("/") ? path.relative(this.rootPath, filepath) : filepath;
    const nodeIds = this.fileIndex.get(norm);
    if (!nodeIds) return { file: norm, symbols: [] };
    const symbols = Array.from(nodeIds).map(id => this.nodes.get(id)).filter(Boolean);
    return { file: norm, symbols };
  }

  getStats() {
    return {
      filesIndexed: this.fileIndex.size,
      nodesCount: this.nodes.size,
      edgesCount: this.edges.length,
      lastSynced: this.lastSynced.toISOString()
    };
  }
}
