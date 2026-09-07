(module asl-intel/tests/health-test
  :d "Unit tests for Codebase Structural Health Matrix & Invariant Anomaly Detection Engine."
  :x [test-detect-cycles-clean-dag
      test-detect-cycles-diamond-dag
      test-detect-self-cycle
      test-blast-radius-hotspot
      test-orphan-exports
      test-cyclomatic-hotspot
      test-build-health-matrix
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

(df test-detect-cycles-clean-dag [] -> Bool
  :d "Verifies that an acyclic linear DAG (A -> B -> C) triggers zero cycle anomalies."
  (let [(na (make-node "A" "A" 1 10 "[]" false))
        (nb (make-node "B" "B" 1 10 "[]" false))
        (nc (make-node "C" "C" 1 10 "[]" false))
        (e1 (make-edge "A" "B" (g/edge-imports)))
        (e2 (make-edge "B" "C" (g/edge-imports)))
        (graph (g/SymbolGraph
                 :nodes (list na nb nc)
                 :edges (list e1 e2)))
        (anoms (h/detect-import-cycles graph))]
    (assert (list-empty? anoms) "Acyclic linear DAG must have zero cycle anomalies")
    true))

(df test-detect-cycles-diamond-dag [] -> Bool
  :d "Verifies 3-state DFS prevents false-positive cycle detection on Diamond DAG (A->B, A->C, B->D, C->D)."
  (let [(na (make-node "A" "A" 1 10 "[]" false))
        (nb (make-node "B" "B" 1 10 "[]" false))
        (nc (make-node "C" "C" 1 10 "[]" false))
        (nd (make-node "D" "D" 1 10 "[]" false))
        (e1 (make-edge "A" "B" (g/edge-imports)))
        (e2 (make-edge "A" "C" (g/edge-imports)))
        (e3 (make-edge "B" "D" (g/edge-imports)))
        (e4 (make-edge "C" "D" (g/edge-imports)))
        (graph (g/SymbolGraph
                 :nodes (list na nb nc nd)
                 :edges (list e1 e2 e3 e4)))
        (anoms (h/detect-import-cycles graph))]
    (assert (list-empty? anoms) "Diamond DAG must have zero cycle anomalies")
    true))

(df test-detect-self-cycle [] -> Bool
  :d "Verifies that a 1-hop self-referential import (A -> A) triggers a blocker cycle anomaly."
  (let [(na (make-node "A" "A" 1 10 "[]" false))
        (e1 (make-edge "A" "A" (g/edge-imports)))
        (graph (g/SymbolGraph
                 :nodes (list na)
                 :edges (list e1)))
        (anoms (h/detect-import-cycles graph))
        (head-opt (list-head anoms))]
    (assert (mt head-opt
              ((none) false)
              ((some anom)
               (and (= (list-length anoms) 1)
                    (and (= (.-severity anom) "blocker")
                         (string-contains? (.-message anom) "CYCLE_DETECTED"))))) "Self-referential import must trigger blocker CYCLE_DETECTED")
    true))

(df test-blast-radius-hotspot [] -> Bool
  :d "Verifies that a symbol with 10 incoming edges triggers an anomaly-blast-radius warning."
  (let [(hub (make-node "hub" "hub" 1 10 "[]" true))
        (leaf (make-node "leaf" "leaf" 1 10 "[]" false))
        (n1 (make-node "n1" "n1" 1 10 "[]" false))
        (n2 (make-node "n2" "n2" 1 10 "[]" false))
        (n3 (make-node "n3" "n3" 1 10 "[]" false))
        (n4 (make-node "n4" "n4" 1 10 "[]" false))
        (n5 (make-node "n5" "n5" 1 10 "[]" false))
        (n6 (make-node "n6" "n6" 1 10 "[]" false))
        (n7 (make-node "n7" "n7" 1 10 "[]" false))
        (n8 (make-node "n8" "n8" 1 10 "[]" false))
        (n9 (make-node "n9" "n9" 1 10 "[]" false))
        (n10 (make-node "n10" "n10" 1 10 "[]" false))
        (e1 (make-edge "n1" "hub" (g/edge-calls)))
        (e2 (make-edge "n2" "hub" (g/edge-calls)))
        (e3 (make-edge "n3" "hub" (g/edge-calls)))
        (e4 (make-edge "n4" "hub" (g/edge-calls)))
        (e5 (make-edge "n5" "hub" (g/edge-calls)))
        (e6 (make-edge "n6" "hub" (g/edge-calls)))
        (e7 (make-edge "n7" "hub" (g/edge-calls)))
        (e8 (make-edge "n8" "hub" (g/edge-calls)))
        (e9 (make-edge "n9" "hub" (g/edge-calls)))
        (e10 (make-edge "n10" "hub" (g/edge-calls)))
        (e-leaf (make-edge "hub" "leaf" (g/edge-calls)))
        (graph (g/SymbolGraph
                 :nodes (list hub leaf n1 n2 n3 n4 n5 n6 n7 n8 n9 n10)
                 :edges (list e1 e2 e3 e4 e5 e6 e7 e8 e9 e10 e-leaf)))
        (anoms (h/detect-blast-radius-hotspots graph 10))
        (head-opt (list-head anoms))]
    (assert (mt head-opt
              ((none) false)
              ((some anom)
               (and (= (list-length anoms) 1)
                    (and (= (.-symbol anom) "hub")
                         (and (= (.-metric anom) 10)
                              (= (.-severity anom) "warning")))))) "Hub with 10 callers must trigger blast radius warning")
    true))

(df test-orphan-exports [] -> Bool
  :d "Verifies that an exported symbol with zero incoming references is flagged as orphan export."
  (let [(orphan (make-node "orphan-fn" "orphan-fn" 1 10 "[]" true))
        (used (make-node "used-fn" "used-fn" 1 10 "[]" true))
        (internal (make-node "internal-fn" "internal-fn" 1 10 "[]" false))
        (caller (make-node "caller-fn" "caller-fn" 1 10 "[]" false))
        (e-used (make-edge "caller-fn" "used-fn" (g/edge-calls)))
        (graph (g/SymbolGraph
                 :nodes (list orphan used internal caller)
                 :edges (list e-used)))
        (anoms (h/detect-orphan-exports graph))
        (head-opt (list-head anoms))]
    (assert (mt head-opt
              ((none) false)
              ((some anom)
               (and (= (list-length anoms) 1)
                    (and (= (.-symbol anom) "orphan-fn")
                         (= (.-severity anom) "warning"))))) "Unused exported function must trigger orphan export warning")
    true))

(df test-cyclomatic-hotspot [] -> Bool
  :d "Verifies that a function with line-span > 15 is flagged as a complexity hotspot."
  (let [(giant (make-node "giant-fn" "giant-fn" 1 31 "[]" false))
        (normal (make-node "normal-fn" "normal-fn" 1 10 "[]" false))
        (graph (g/SymbolGraph
                 :nodes (list giant normal)
                 :edges (list)))
        (anoms (h/detect-cyclomatic-hotspots graph 15))
        (head-opt (list-head anoms))]
    (assert (mt head-opt
              ((none) false)
              ((some anom)
               (and (= (list-length anoms) 1)
                    (and (= (.-symbol anom) "giant-fn")
                         (and (= (.-metric anom) 30)
                              (= (.-severity anom) "warning")))))) "Function with 30 lines must trigger complexity hotspot warning")
    true))

(df test-build-health-matrix [] -> Bool
  :d "Verifies unified health matrix assembly, blocking evaluation, and report formatting."
  (let [(na (make-node "A" "A" 1 10 "[]" false))
        (nb (make-node "B" "B" 1 10 "[]" false))
        (e-cyc (make-edge "A" "A" (g/edge-imports)))
        (graph (g/SymbolGraph
                 :nodes (list na nb)
                 :edges (list e-cyc)))
        (matrix (h/build-health-matrix graph "test-scope"))
        (report (h/format-health-report matrix))
        (clean-matrix (h/intel-health "clean-scope"))]
    (assert (= (.-scope matrix) "test-scope") "Matrix scope must match")
    (assert (= (.-total-nodes matrix) 2) "Total nodes must be 2")
    (assert (= (.-total-edges matrix) 1) "Total edges must be 1")
    (assert (.-has-cycles matrix) "Cyclic graph must flag has-cycles")
    (assert (not (.-healthy matrix)) "Cyclic graph must not be healthy")
    (assert (string-contains? report "CODEBASE STRUCTURAL HEALTH REPORT") "Report must contain header")
    (assert (.-healthy clean-matrix) "Clean matrix must be healthy")
    (assert (not (.-has-cycles clean-matrix)) "Clean matrix must not have cycles")
    true))

(df run-tests [] -> Bool
  :d "Executes full codebase structural health test suite."
  (let [(_t1 (test-detect-cycles-clean-dag))
        (_t2 (test-detect-cycles-diamond-dag))
        (_t3 (test-detect-self-cycle))
        (_t4 (test-blast-radius-hotspot))
        (_t5 (test-orphan-exports))
        (_t6 (test-cyclomatic-hotspot))
        (_t7 (test-build-health-matrix))]
    true))
