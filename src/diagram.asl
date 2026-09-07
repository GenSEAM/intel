(module asl-intel/diagram
  :d "Dependency DAG Diagram Generator in Mermaid and ASN Notation"
  :x [DiagramFormat
      diagram-format-mermaid
      diagram-format-asn
      diagram-format-to-string
      generate-mermaid-diagram
      generate-asn-diagram
      generate-diagram
      render-mermaid-dag
      render-asn-dag]
  :i [(graph :a g)])

(dfe DiagramFormat
  (:c diagram-format-mermaid [] "Mermaid graph TD notation")
  (:c diagram-format-asn [] "Canonical ASN S-expression DAG representation"))

(df diagram-format-to-string [(fmt DiagramFormat)] -> Str
  :d "Convert DiagramFormat enum to string identifier"
  (mt fmt
    ((diagram-format-mermaid) "mermaid")
    ((diagram-format-asn) "asn")))

(df format-mermaid-node [(n g/GraphNode)] -> Str
  :d "Format a GraphNode as a Mermaid node declaration"
  (let [(label (if (string-empty? (.-name n)) (.-id n) (.-name n)))]
    (str "  " (.-id n) "[\"" label "\"]")))

(df format-mermaid-edge [(e g/GraphEdge)] -> Str
  :d "Format a GraphEdge as a Mermaid dependency link"
  (str "  " (.-src e) " --> " (.-dst e)))

(df generate-mermaid-diagram [(graph g/SymbolGraph)] -> Str
  :d "Generate Mermaid graph TD notation representing package and module dependency DAG"
  (let [(nodes (.-nodes graph))
        (edges (.-edges graph))]
    (if (and (list-empty? nodes) (list-empty? edges))
      "graph TD"
      (if (list-empty? edges)
        (str "graph TD\n" (string-join "\n" (map format-mermaid-node nodes)))
        (str "graph TD\n" (string-join "\n" (map format-mermaid-edge edges)))))))

(df format-asn-node [(n g/GraphNode)] -> Str
  :d "Format a GraphNode as an ASN S-expression"
  (str "(:node :id \"" (.-id n) "\" :name \"" (.-name n) "\" :kind \"" (.-kind n) "\")"))

(df format-asn-edge [(e g/GraphEdge)] -> Str
  :d "Format a GraphEdge as an ASN S-expression"
  (str "(:edge :src \"" (.-src e) "\" :dst \"" (.-dst e) "\" :kind \"" (g/edge-kind-to-string (.-kind e)) "\")"))

(df generate-asn-diagram [(graph g/SymbolGraph)] -> Str
  :d "Generate canonical ASN S-expression representation of dependency DAG"
  (let [(nodes (.-nodes graph))
        (edges (.-edges graph))
        (node-entries (map format-asn-node nodes))
        (edge-entries (map format-asn-edge edges))
        (nodes-block (if (list-empty? nodes) "[]" (str "[\n    " (string-join "\n    " node-entries) "\n  ]")))
        (edges-block (if (list-empty? edges) "[]" (str "[\n    " (string-join "\n    " edge-entries) "\n  ]")))]
    (str "(:dependency-dag\n  :nodes " nodes-block "\n  :edges " edges-block "\n)")))

(df generate-diagram [(fmt DiagramFormat) (graph g/SymbolGraph)] -> Str
  :d "Generate dependency diagram in the specified DiagramFormat"
  (mt fmt
    ((diagram-format-mermaid) (generate-mermaid-diagram graph))
    ((diagram-format-asn) (generate-asn-diagram graph))))

(df render-mermaid-dag [(graph g/SymbolGraph)] -> Str
  :d "Render dependency DAG in Mermaid graph TD format"
  (generate-mermaid-diagram graph))

(df render-asn-dag [(graph g/SymbolGraph)] -> Str
  :d "Render dependency DAG in ASN S-expression format"
  (generate-asn-diagram graph))
