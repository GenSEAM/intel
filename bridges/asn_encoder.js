// Token-Dense ASN S-Expression Frame Encoder

export function encodeSymbolAsn(node) {
  const expTag = node.exported ? " :x" : "";
  const sig = node.signature ? ` :sig "${node.signature.replace(/"/g, '\\"')}"` : "";
  return `(:s "${node.name}" :${node.kind} @${node.file}:${node.startLine}${expTag}${sig})`;
}

export function encodeImpactAsn(item) {
  return `(:i "${item.node.name}" :${item.node.kind} @${item.node.file}:${item.node.startLine} :d ${item.depth})`;
}

export function encodeContextAsn(context) {
  const lines = [`(@ctx @${context.file}`];
  for (const s of context.symbols) {
    lines.push(`  ${encodeSymbolAsn(s)}`);
  }
  lines.push(")");
  return lines.join("\n");
}

export function encodeSearchResultsAsn(query, results) {
  const lines = [`(@search "${query}" :total ${results.length}`];
  for (const s of results) {
    lines.push(`  ${encodeSymbolAsn(s)}`);
  }
  lines.push(")");
  return lines.join("\n");
}

export function encodeCallersAsn(target, callers) {
  const lines = [`(@callers "${target}" :total ${callers.length}`];
  for (const c of callers) {
    lines.push(`  ${encodeSymbolAsn(c)}`);
  }
  lines.push(")");
  return lines.join("\n");
}

export function encodeCalleesAsn(source, callees) {
  const lines = [`(@callees "${source}" :total ${callees.length}`];
  for (const c of callees) {
    lines.push(`  ${encodeSymbolAsn(c)}`);
  }
  lines.push(")");
  return lines.join("\n");
}

export function encodeImpactResultsAsn(target, impactList) {
  const lines = [`(@impact "${target}" :total ${impactList.length}`];
  for (const item of impactList) {
    lines.push(`  ${encodeImpactAsn(item)}`);
  }
  lines.push(")");
  return lines.join("\n");
}
