(module asl-intel/graph
  :d "High-Performance In-Memory Symbol Knowledge Graph for Code Intelligence"
  :x [EdgeKind
      edge-calls edge-defines edge-imports edge-implements edge-subtypes
      GraphNode GraphEdge SymbolGraph
      edge-kind-to-string
      graph-create graph-add-node graph-add-edge
      graph-node-count graph-edge-count])

(ty EdgeKind
  (enum
    (edge-calls)
    (edge-defines)
    (edge-imports)
    (edge-implements)
    (edge-subtypes)))

(ty GraphNode
  (record
    (:id Str)
    (:name Str)
    (:kind Str)
    (:file Str)
    (:start-line I64)
    (:end-line I64)
    (:signature Str)
    (:exported Bool)))

(ty GraphEdge
  (record
    (:src Str)
    (:dst Str)
    (:kind EdgeKind)
    (:file Str)
    (:line I64)))

(ty SymbolGraph
  (record
    (:nodes (List GraphNode))
    (:edges (List GraphEdge))))

(df edge-kind-to-string [(k EdgeKind)] -> Str
  (:d "Convert EdgeKind enum to string")
  (mt k
    ((edge-calls) "calls")
    ((edge-defines) "defines")
    ((edge-imports) "imports")
    ((edge-implements) "implements")
    ((edge-subtypes) "subtypes")))

(df graph-create [] -> SymbolGraph
  (:d "Initialize an empty SymbolGraph")
  (:SymbolGraph
    :nodes (list)
    :edges (list)))

(df graph-add-node [(g SymbolGraph) (node GraphNode)] -> SymbolGraph
  (:d "Add a GraphNode to the SymbolGraph")
  (:SymbolGraph
    :nodes (cons node (.-nodes g))
    :edges (.-edges g)))

(df graph-add-edge [(g SymbolGraph) (edge GraphEdge)] -> SymbolGraph
  (:d "Add a GraphEdge to the SymbolGraph")
  (:SymbolGraph
    :nodes (.-nodes g)
    :edges (cons edge (.-edges g))))

(df graph-node-count [(g SymbolGraph)] -> I64
  (:d "Return count of nodes in the graph")
  (list-length (.-nodes g)))

(df graph-edge-count [(g SymbolGraph)] -> I64
  (:d "Return count of edges in the graph")
  (list-length (.-edges g)))
