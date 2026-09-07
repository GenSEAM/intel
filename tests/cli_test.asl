(module asl-intel/tests/cli-test
  :d "Unit tests for codebase observability, health auditing, and CLI telemetry"
  :x [test-cli-health-matrix-structure
      test-cli-orphans-filter
      test-cli-cycles-3state-dfs
      test-cli-hotspots-threshold
      run-tests]
  :i [(health :a h) (graph :a g)])

(df make-node [(id Str) (name Str) (start I64) (end I64) (sig Str) (exp Bool)] -> g/GraphNode
  :d "Helper creating a GraphNode fixture"
  (g/GraphNode
    :id id
    :name name
    :kind "fn"
    :file (str "src/" id ".asl")
    :start-line start
    :end-line end
    :signature sig
    :exported exp))

(df make-edge [(src Str) (dst Str) (k g/EdgeKind)] -> g/GraphEdge
  :d "Helper creating a GraphEdge fixture"
  (g/GraphEdge
    :src src
    :dst dst
    :kind k
    :file (str "src/" src ".asl")
    :line 10))

(df test-cli-health-matrix-structure [] -> Bool
  :d "Verifies health matrix structure, healthy invariant, and report serialization"
  (let [(clean-m (h/intel-health "clean-scope"))
        (report (h/format-health-report clean-m))]
    (assert (= (.-scope clean-m) "clean-scope") "Scope must match 'clean-scope'")
    (assert (.-healthy clean-m) "Clean matrix must be healthy")
    (assert (not (.-has-cycles clean-m)) "Clean matrix must have no cycles")
    (assert (list-empty? (.-anomalies clean-m)) "Clean matrix must have empty anomalies")
    (assert (string-contains? report "Structural Health Matrix") "Report must contain canonical header")
    true))

(df test-cli-orphans-filter [] -> Bool
  :d "Verifies detection of uncalled exported symbols vs private or referenced symbols"
  (let [(orphan-node (make-node "orphan-fn" "orphan-fn" 1 10 "[]" true))
        (internal-node (make-node "internal-fn" "internal-fn" 1 10 "[]" false))
        (called-node (make-node "called-fn" "called-fn" 1 10 "[]" true))
        (caller-node (make-node "caller-fn" "caller-fn" 1 10 "[]" false))
        (call-edge (make-edge "caller-fn" "called-fn" (g/edge-calls)))
        (graph (g/SymbolGraph
                 :nodes (list orphan-node internal-node called-node caller-node)
                 :edges (list call-edge)))
        (orphans (h/detect-orphan-exports graph))]
    (assert (= (list-length orphans) 1) "Expected exactly 1 orphan export")
    (let [(anom (option-or (list-head orphans)
                           (h/HealthAnomaly :kind (h/anomaly-orphan-export) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-symbol anom) "orphan-fn") "Detected orphan symbol must be 'orphan-fn'"))
    true))

(df test-cli-cycles-3state-dfs [] -> Bool
  :d "Verifies 3-state DFS correctly identifies cycles and allows acyclic DAGs"
  (let [(na (make-node "A" "A" 1 10 "[]" false))
        (nb (make-node "B" "B" 1 10 "[]" false))
        (e-ab (make-edge "A" "B" (g/edge-imports)))
        (e-ba (make-edge "B" "A" (g/edge-imports)))
        (cyclic-graph (g/SymbolGraph :nodes (list na nb) :edges (list e-ab e-ba)))
        (acyclic-graph (g/SymbolGraph :nodes (list na nb) :edges (list e-ab)))
        (cyc-anoms (h/detect-import-cycles cyclic-graph))
        (clean-anoms (h/detect-import-cycles acyclic-graph))]
    (assert (not (list-empty? cyc-anoms)) "Cyclic graph must yield cycle anomalies")
    (assert (list-empty? clean-anoms) "Acyclic graph must yield zero cycle anomalies")
    true))

(df test-cli-hotspots-threshold [] -> Bool
  :d "Verifies fan-in blast radius and cyclomatic span boundary checks"
  (let [(n-small (make-node "small-fn" "small-fn" 1 10 "[]" false))
        (n-large (make-node "large-fn" "large-fn" 1 35 "[]" false))
        (graph (g/SymbolGraph :nodes (list n-small n-large) :edges (list)))
        (span-hotspots (h/detect-cyclomatic-hotspots graph 15))]
    (assert (= (list-length span-hotspots) 1) "Span of 34 lines must trigger cyclomatic hotspot (threshold 15)")
    (let [(anom (option-or (list-head span-hotspots)
                           (h/HealthAnomaly :kind (h/anomaly-complexity-hotspot) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-symbol anom) "large-fn") "Hotspot symbol must be 'large-fn'")
      (assert (= (.-metric anom) 34) "Hotspot metric must be span length 34"))
    true))

(df run-tests [] -> Bool
  :d "Execute full CLI unit test suite"
  (let [(r1 (test-cli-health-matrix-structure))
        (r2 (test-cli-orphans-filter))
        (r3 (test-cli-cycles-3state-dfs))
        (r4 (test-cli-hotspots-threshold))]
    (and r1 (and r2 (and r3 r4)))))
