(module asl-intel/tests/diagram-test
  :d "Unit tests for dependency DAG diagram generation module"
  :x [test-diagram-mermaid-format
      test-diagram-asn-format
      test-diagram-diamond-dag
      test-diagram-empty-graph
      test-diagram-format-enum
      run-tests]
  :i [(diagram :a d) (graph :a g)])

(df make-node [(id Str) (name Str)] -> g/GraphNode
  :d "Helper creating a GraphNode fixture"
  (g/GraphNode
    :id id
    :name name
    :kind "fn"
    :file (str "src/" id ".asl")
    :start-line 1
    :end-line 10
    :signature "[]"
    :exported true))

(df make-edge [(src Str) (dst Str)] -> g/GraphEdge
  :d "Helper creating a GraphEdge fixture"
  (g/GraphEdge
    :src src
    :dst dst
    :kind (g/edge-imports)
    :file (str "src/" src ".asl")
    :line 1))

(df test-diagram-mermaid-format [] -> Bool
  :d "Verifies Mermaid format starts with graph TD and contains dependency arrow"
  (let [(na (make-node "pkgA" "ModuleA"))
        (nb (make-node "pkgB" "ModuleB"))
        (e1 (make-edge "pkgA" "pkgB"))
        (graph (g/SymbolGraph :nodes (list na nb) :edges (list e1)))
        (out (d/generate-mermaid-diagram graph))]
    (assert (string-starts-with? out "graph TD") "Output must start with 'graph TD'")
    (assert (string-contains? out "-->") "Output must contain dependency arrow '-->'")
    (assert (string-contains? out "pkgA --> pkgB") "Output must contain 'pkgA --> pkgB'")
    true))

(df test-diagram-asn-format [] -> Bool
  :d "Verifies ASN format contains :dependency-dag with :nodes and :edges blocks"
  (let [(na (make-node "pkgA" "ModuleA"))
        (nb (make-node "pkgB" "ModuleB"))
        (e1 (make-edge "pkgA" "pkgB"))
        (graph (g/SymbolGraph :nodes (list na nb) :edges (list e1)))
        (out (d/generate-asn-diagram graph))]
    (assert (string-contains? out "(:dependency-dag") "Output must contain '(:dependency-dag'")
    (assert (string-contains? out ":nodes") "Output must contain ':nodes'")
    (assert (string-contains? out ":edges") "Output must contain ':edges'")
    (assert (string-contains? out "(:node :id \"pkgA\"") "Output must serialize node pkgA")
    (assert (string-contains? out "(:edge :src \"pkgA\" :dst \"pkgB\"") "Output must serialize edge A->B")
    true))

(df test-diagram-diamond-dag [] -> Bool
  :d "Verifies diamond DAG topology (A->B, A->C, B->D, C->D) is formatted cleanly"
  (let [(na (make-node "A" "NodeA"))
        (nb (make-node "B" "NodeB"))
        (nc (make-node "C" "NodeC"))
        (nd (make-node "D" "NodeD"))
        (e1 (make-edge "A" "B"))
        (e2 (make-edge "A" "C"))
        (e3 (make-edge "B" "D"))
        (e4 (make-edge "C" "D"))
        (graph (g/SymbolGraph :nodes (list na nb nc nd) :edges (list e1 e2 e3 e4)))
        (mermaid-out (d/generate-mermaid-diagram graph))
        (asn-out (d/generate-asn-diagram graph))]
    (assert (string-contains? mermaid-out "A --> B") "Mermaid must contain A --> B")
    (assert (string-contains? mermaid-out "A --> C") "Mermaid must contain A --> C")
    (assert (string-contains? mermaid-out "B --> D") "Mermaid must contain B --> D")
    (assert (string-contains? mermaid-out "C --> D") "Mermaid must contain C --> D")
    (assert (string-contains? asn-out "(:edge :src \"A\" :dst \"B\"") "ASN must contain edge A->B")
    (assert (string-contains? asn-out "(:edge :src \"C\" :dst \"D\"") "ASN must contain edge C->D")
    true))

(df test-diagram-empty-graph [] -> Bool
  :d "Verifies diagram generation handles empty graph edge cases cleanly"
  (let [(graph (g/SymbolGraph :nodes (list) :edges (list)))
        (mermaid-out (d/generate-mermaid-diagram graph))
        (asn-out (d/generate-asn-diagram graph))]
    (assert (string-starts-with? mermaid-out "graph TD") "Empty mermaid diagram must start with 'graph TD'")
    (assert (string-contains? asn-out "(:dependency-dag") "Empty ASN diagram must contain '(:dependency-dag'")
    (assert (string-contains? asn-out ":nodes []") "Empty ASN diagram must contain ':nodes []'")
    (assert (string-contains? asn-out ":edges []") "Empty ASN diagram must contain ':edges []'")
    true))

(df test-diagram-format-enum [] -> Bool
  :d "Verifies DiagramFormat enum mapping, dispatcher and aliases"
  (let [(fmt-m (d/diagram-format-mermaid))
        (fmt-a (d/diagram-format-asn))
        (str-m (d/diagram-format-to-string fmt-m))
        (str-a (d/diagram-format-to-string fmt-a))
        (graph (g/SymbolGraph :nodes (list) :edges (list)))
        (disp-m (d/generate-diagram fmt-m graph))
        (disp-a (d/generate-diagram fmt-a graph))
        (rend-m (d/render-mermaid-dag graph))
        (rend-a (d/render-asn-dag graph))]
    (assert (= str-m "mermaid") "Enum string for mermaid must be 'mermaid'")
    (assert (= str-a "asn") "Enum string for asn must be 'asn'")
    (assert (string-starts-with? disp-m "graph TD") "Dispatcher mermaid must start with 'graph TD'")
    (assert (string-contains? disp-a "(:dependency-dag") "Dispatcher asn must contain '(:dependency-dag'")
    (assert (string-starts-with? rend-m "graph TD") "render-mermaid-dag must match generate-mermaid-diagram")
    (assert (string-contains? rend-a "(:dependency-dag") "render-asn-dag must match generate-asn-diagram")
    true))

(df run-tests [] -> Bool
  :d "Execute all diagram test suites"
  (let [(r1 (test-diagram-mermaid-format))
        (r2 (test-diagram-asn-format))
        (r3 (test-diagram-diamond-dag))
        (r4 (test-diagram-empty-graph))
        (r5 (test-diagram-format-enum))]
    (and r1 (and r2 (and r3 (and r4 r5))))))
