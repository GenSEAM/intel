(module asl-intel/intel
  :d "GenSEAM ASL-Intel Code Intelligence Engine Entrypoint"
  :i [(extractor :a [SymbolKind SymbolDef SymbolRef FileSymbols])
      (graph :a [EdgeKind GraphNode GraphEdge SymbolGraph])
      (query :a [QueryKind ImpactItem QueryResult])
      (codec :a [encode-symbol-asn encode-edge-asn encode-impact-asn encode-asn-response])
      (health :a [intel-health build-health-matrix format-health-report HealthMatrix])
      (diagram :a [DiagramFormat diagram-format-mermaid diagram-format-asn
                   diagram-format-to-string
                   generate-mermaid-diagram generate-asn-diagram generate-diagram
                   render-mermaid-dag render-asn-dag])]
  :x [intel-version intel-banner
      intel-health build-health-matrix format-health-report
      render-mermaid-dag render-asn-dag
      generate-mermaid-diagram generate-asn-diagram generate-diagram])

(df intel-version [] -> Str
  (:d "Return the ASL-Intel version string")
  "0.1.0")

(df intel-banner [] -> Str
  (:d "Return formatted banner for ASL-Intel CLI")
  "GenSEAM ASL-Intel — Native Multi-Language Code Intelligence Engine (v0.1.0)")
