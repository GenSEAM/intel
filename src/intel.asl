(:d "GenSEAM ASL-Intel Code Intelligence Engine Entrypoint"
 :i [(extractor :a [SymbolKind SymbolDef SymbolRef FileSymbols])
     (graph :a [EdgeKind GraphNode GraphEdge SymbolGraph])
     (query :a [QueryKind ImpactItem QueryResult])
     (codec :a [encode-symbol-asn encode-edge-asn encode-impact-asn encode-asn-response])]
 :x [intel-version intel-banner])

(df intel-version [] -> Str
  (:d "Return the ASL-Intel version string")
  "0.1.0")

(df intel-banner [] -> Str
  (:d "Return formatted banner for ASL-Intel CLI")
  "GenSEAM ASL-Intel — Native Multi-Language Code Intelligence Engine (v0.1.0)")
