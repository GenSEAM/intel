// Multi-language Symbol & Call Extractor Bridge
import fs from "node:fs";
import path from "node:path";

export function detectLanguage(filepath) {
  const ext = path.extname(filepath).toLowerCase();
  switch (ext) {
    case ".asl":
    case ".agentscript":
      return "asl";
    case ".ts":
    case ".tsx":
      return "typescript";
    case ".js":
    case ".jsx":
    case ".mjs":
      return "javascript";
    case ".py":
      return "python";
    case ".rs":
      return "rust";
    case ".go":
      return "go";
    default:
      return "unknown";
  }
}

export function extractSymbolsFromSource(filepath, source) {
  const lang = detectLanguage(filepath);
  const lines = source.split("\n");
  const symbols = [];
  const refs = [];

  if (lang === "asl") {
    extractAsl(filepath, lines, symbols, refs);
  } else if (lang === "typescript" || lang === "javascript") {
    extractTsJs(filepath, lines, symbols, refs);
  } else if (lang === "python") {
    extractPython(filepath, lines, symbols, refs);
  } else if (lang === "rust") {
    extractRust(filepath, lines, symbols, refs);
  } else if (lang === "go") {
    extractGo(filepath, lines, symbols, refs);
  }

  return {
    file: filepath,
    language: lang,
    symbols,
    refs
  };
}

function extractAsl(filepath, lines, symbols, refs) {
  let exportsList = new Set();

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Export clause (:x [foo bar baz])
    const expMatch = trimmed.match(/:x\s*\[(.*?)\]/);
    if (expMatch) {
      const names = expMatch[1].trim().split(/\s+/);
      for (const n of names) if (n) exportsList.add(n);
    }

    // Function: (df name [(args)] -> RetType
    const fnMatch = trimmed.match(/^\((df|dfs|dfe)\s+([a-zA-Z0-9_\-]+)\s*\[(.*?)\]\s*(?:->\s*([a-zA-Z0-9_\-\(\)\s]+))?/);
    if (fnMatch) {
      const isEff = fnMatch[1] === "dfe";
      const isSyn = fnMatch[1] === "dfs";
      const name = fnMatch[2];
      const args = fnMatch[3].trim();
      const ret = fnMatch[4] ? fnMatch[4].trim() : "Any";
      symbols.push({
        name,
        kind: isEff ? "effect" : "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `[${args}] -> ${ret}`,
        exported: exportsList.has(name) || isSyn,
        doc: ""
      });
      continue;
    }

    // Type: (ty Name (record ...)) or (ty Name (enum ...))
    const tyMatch = trimmed.match(/^\(ty\s+([a-zA-Z0-9_\-]+)/);
    if (tyMatch) {
      const name = tyMatch[1];
      const kind = (lines[i + 1] && lines[i + 1].includes('enum')) ? 'enum' : 'record';
      symbols.push({
        name,
        kind,
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `${kind} ${name}`,
        exported: exportsList.has(name),
        doc: ''
      });
      continue;
    }

    // Call references: (callee-name ...
    const callMatches = line.matchAll(/\(([a-zA-Z0-9_\-]+)\b/g);
    for (const cm of callMatches) {
      const callee = cm[1];
      if (!["df", "dfs", "dfe", "ty", "mt", "let", "cond", "if", "list", "record", "enum", ":x", ":d"].includes(callee)) {
        refs.push({
          name: callee,
          caller: symbols.length > 0 ? symbols[symbols.length - 1].name : "toplevel",
          file: filepath,
          line: i + 1
        });
      }
    }
  }
}

function extractTsJs(filepath, lines, symbols, refs) {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // Export keyword
    const isExport = trimmed.startsWith("export ");
    const clean = isExport ? trimmed.replace(/^export\s+(?:default\s+)?/, "") : trimmed;

    // function name(...)
    const fnMatch = clean.match(/^(?:async\s+)?function\s+([a-zA-Z0-9_$]+)\s*\((.*?)\)/);
    if (fnMatch) {
      symbols.push({
        name: fnMatch[1],
        kind: "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `(${fnMatch[2]})`,
        exported: isExport,
        doc: ""
      });
      continue;
    }

    // const/let name = (...) =>
    const arrowMatch = clean.match(/^(?:const|let)\s+([a-zA-Z0-9_$]+)\s*=\s*(?:async\s*)?\((.*?)\)\s*=>/);
    if (arrowMatch) {
      symbols.push({
        name: arrowMatch[1],
        kind: "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `(${arrowMatch[2]})`,
        exported: isExport,
        doc: ""
      });
      continue;
    }

    // class/interface/type
    const classMatch = clean.match(/^(class|interface|type)\s+([a-zA-Z0-9_$]+)/);
    if (classMatch) {
      symbols.push({
        name: classMatch[2],
        kind: classMatch[1],
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `${classMatch[1]} ${classMatch[2]}`,
        exported: isExport,
        doc: ""
      });
      continue;
    }

    // Function calls
    const callMatches = line.matchAll(/\b([a-zA-Z0-9_$]+)\s*\(/g);
    for (const cm of callMatches) {
      const callee = cm[1];
      if (!["if", "for", "while", "switch", "catch", "function"].includes(callee)) {
        refs.push({
          name: callee,
          caller: symbols.length > 0 ? symbols[symbols.length - 1].name : "toplevel",
          file: filepath,
          line: i + 1
        });
      }
    }
  }
}

function extractPython(filepath, lines, symbols, refs) {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // def name(args):
    const fnMatch = trimmed.match(/^(?:async\s+)?def\s+([a-zA-Z0-9_]+)\s*\((.*?)\)/);
    if (fnMatch) {
      const name = fnMatch[1];
      symbols.push({
        name,
        kind: "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `(${fnMatch[2]})`,
        exported: !name.startsWith("_"),
        doc: ""
      });
      continue;
    }

    // class Name:
    const classMatch = trimmed.match(/^class\s+([a-zA-Z0-9_]+)/);
    if (classMatch) {
      symbols.push({
        name: classMatch[1],
        kind: "class",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `class ${classMatch[1]}`,
        exported: !classMatch[1].startsWith("_"),
        doc: ""
      });
      continue;
    }

    // Calls: name(...)
    const callMatches = line.matchAll(/\b([a-zA-Z0-9_]+)\s*\(/g);
    for (const cm of callMatches) {
      const callee = cm[1];
      if (!["def", "class", "if", "for", "while", "with", "return"].includes(callee)) {
        refs.push({
          name: callee,
          caller: symbols.length > 0 ? symbols[symbols.length - 1].name : "toplevel",
          file: filepath,
          line: i + 1
        });
      }
    }
  }
}

function extractRust(filepath, lines, symbols, refs) {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    const isPub = trimmed.startsWith("pub ");
    const clean = isPub ? trimmed.replace(/^pub(?:\(.*?\))?\s+/, "") : trimmed;

    // fn name(...)
    const fnMatch = clean.match(/^(?:async\s+)?fn\s+([a-zA-Z0-9_]+)\s*\((.*?)\)/);
    if (fnMatch) {
      symbols.push({
        name: fnMatch[1],
        kind: "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `(${fnMatch[2]})`,
        exported: isPub,
        doc: ""
      });
      continue;
    }

    // struct/enum/trait
    const tyMatch = clean.match(/^(struct|enum|trait)\s+([a-zA-Z0-9_]+)/);
    if (tyMatch) {
      symbols.push({
        name: tyMatch[2],
        kind: tyMatch[1],
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `${tyMatch[1]} ${tyMatch[2]}`,
        exported: isPub,
        doc: ""
      });
      continue;
    }
  }
}

function extractGo(filepath, lines, symbols, refs) {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // func Name(...)
    const fnMatch = trimmed.match(/^func\s+(?:\(.*?\)\s+)?([a-zA-Z0-9_]+)\s*\((.*?)\)/);
    if (fnMatch) {
      const name = fnMatch[1];
      const isExported = name[0] === name[0].toUpperCase() && name[0] !== '_';
      symbols.push({
        name,
        kind: "fn",
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `(${fnMatch[2]})`,
        exported: isExported,
        doc: ""
      });
      continue;
    }

    // type Name struct/interface
    const tyMatch = trimmed.match(/^type\s+([a-zA-Z0-9_]+)\s+(struct|interface)/);
    if (tyMatch) {
      const name = tyMatch[1];
      const isExported = name[0] === name[0].toUpperCase() && name[0] !== '_';
      symbols.push({
        name,
        kind: tyMatch[2],
        file: filepath,
        startLine: i + 1,
        endLine: i + 1,
        signature: `type ${name} ${tyMatch[2]}`,
        exported: isExported,
        doc: ""
      });
      continue;
    }
  }
}
