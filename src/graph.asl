(module asl-intel/graph
  :d "High-Performance In-Memory Symbol Knowledge Graph for Code Intelligence"
  :x [EdgeKind
      edge-calls edge-defines edge-imports edge-implements edge-subtypes
      GraphNode GraphEdge SymbolGraph
      edge-kind-to-string
      graph-create graph-add-node graph-add-edge
      graph-node-count graph-edge-count])

(dfe EdgeKind
  (:c edge-calls [] "Calls edge")
  (:c edge-defines [] "Defines edge")
  (:c edge-imports [] "Imports edge")
  (:c edge-implements [] "Implements edge")
  (:c edge-subtypes [] "Subtypes edge"))

(dfs GraphNode
  (:f id Str "Node identifier")
  (:f name Str "Symbol name")
  (:f kind Str "Symbol category")
  (:f file Str "File path")
  (:f start-line I64 "Start line")
  (:f end-line I64 "End line")
  (:f signature Str "Type signature")
  (:f exported Bool "True if exported"))

(dfs GraphEdge
  (:f src Str "Source node id")
  (:f dst Str "Destination node id")
  (:f kind EdgeKind "Edge category")
  (:f file Str "File path")
  (:f line I64 "Reference line"))

(dfs SymbolGraph
  (:f nodes (List GraphNode) "Graph nodes")
  (:f edges (List GraphEdge) "Graph edges"))

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
  (SymbolGraph
    :nodes (list)
    :edges (list)))

(df graph-add-node [(g SymbolGraph) (node GraphNode)] -> SymbolGraph
  (:d "Add a GraphNode to the SymbolGraph")
  (SymbolGraph
    :nodes (cons node (.-nodes g))
    :edges (.-edges g)))

(df graph-add-edge [(g SymbolGraph) (edge GraphEdge)] -> SymbolGraph
  (:d "Add a GraphEdge to the SymbolGraph")
  (SymbolGraph
    :nodes (.-nodes g)
    :edges (cons edge (.-edges g))))

(df graph-node-count [(g SymbolGraph)] -> I64
  (:d "Return count of nodes in the graph")
  (list-length (.-nodes g)))

(df graph-edge-count [(g SymbolGraph)] -> I64
  (:d "Return count of edges in the graph")
  (list-length (.-edges g)))
