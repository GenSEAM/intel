(module asl-intel/tests/boundary-test
  :d "Unit tests for 4-tier layer stratification, downward DAG verification, and boundary leakage detection"
  :x [test-module-to-layer-mapping
      test-boundary-clean-dag
      test-boundary-layer0-clean
      test-boundary-trap-layer0-import-layer1
      test-boundary-trap-agent-id-leakage
      test-boundary-trap-layer0-import-layer3
      test-boundary-trap-layer1-import-layer3
      run-tests]
  :i [(health :a h) (graph :a g)])

(df make-test-node [(id Str) (name Str) (file Str) (sig Str)] -> g/GraphNode
  :d "Helper creating a GraphNode fixture for boundary test"
  (g/GraphNode
    :id id
    :name name
    :kind "fn"
    :file file
    :start-line 1
    :end-line 10
    :signature sig
    :exported true))

(df make-test-edge [(src Str) (dst Str) (file Str)] -> g/GraphEdge
  :d "Helper creating an import GraphEdge fixture for boundary test"
  (g/GraphEdge
    :src src
    :dst dst
    :kind (g/edge-imports)
    :file file
    :line 5))

(df test-module-to-layer-mapping [] -> Bool
  :d "Verifies architectural layer tier mapping for core ecosystem packages"
  (assert (= (h/module-to-layer "asl-parser") 0) "asl-parser must map to Layer 0")
  (assert (= (h/module-to-layer "asl-codec") 0) "asl-codec must map to Layer 0")
  (assert (= (h/module-to-layer "intel/src/health.asl") 0) "intel must map to Layer 0")
  (assert (= (h/module-to-layer "agent-bus") 1) "agent-bus must map to Layer 1")
  (assert (= (h/module-to-layer "harness/src/bench.asl") 1) "harness must map to Layer 1")
  (assert (= (h/module-to-layer "asl-contracts") 1) "asl-contracts must map to Layer 1")
  (assert (= (h/module-to-layer "mem") 2) "mem must map to Layer 2")
  (assert (= (h/module-to-layer "crawler") 2) "crawler must map to Layer 2")
  (assert (= (h/module-to-layer "asl-bridge") 3) "asl-bridge must map to Layer 3")
  (assert (= (h/module-to-layer "asl-plugin") 3) "asl-plugin must map to Layer 3")
  (assert (= (h/module-to-layer "bin/asl") 3) "bin must map to Layer 3")
  true)

(df test-boundary-clean-dag [] -> Bool
  :d "Verifies that a clean downward DAG (Layer 3 -> Layer 2 -> Layer 1 -> Layer 0) yields zero anomalies"
  (let [(nl3 (make-test-node "asl-bridge" "bridge-call" "asl/packages/asl-bridge/src/bridge.asl" "[]"))
        (nl2 (make-test-node "mem" "mem-query" "mem/src/vector.asl" "[]"))
        (nl1 (make-test-node "agent-bus" "bus-publish" "agent-bus/src/bus.asl" "[]"))
        (nl0 (make-test-node "asl-parser" "parse-expr" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (e32 (make-test-edge "asl-bridge" "mem" "asl/packages/asl-bridge/src/bridge.asl"))
        (e21 (make-test-edge "mem" "agent-bus" "mem/src/vector.asl"))
        (e10 (make-test-edge "agent-bus" "asl-parser" "agent-bus/src/bus.asl"))
        (e30 (make-test-edge "asl-bridge" "asl-parser" "asl/packages/asl-bridge/src/bridge.asl"))
        (graph (g/SymbolGraph
                 :nodes (list nl3 nl2 nl1 nl0)
                 :edges (list e32 e21 e10 e30)))
        (anoms (h/detect-layer-leakage graph))
        (matrix (h/build-health-matrix graph "clean-stratification"))]
    (assert (list-empty? anoms) "Clean downward DAG must have zero layer leakage anomalies")
    (assert (.-healthy matrix) "Clean stratified matrix must report healthy true")
    true))

(df test-boundary-layer0-clean [] -> Bool
  :d "Verifies that Layer 0 modules referencing only Layer 0 components yield zero anomalies"
  (let [(n-parser (make-test-node "asl-parser" "parse" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (n-codec (make-test-node "asl-codec" "decode" "asl/packages/asl-codec/src/codec.asl" "[]"))
        (e0 (make-test-edge "asl-parser" "asl-codec" "asl/packages/asl-parser/src/parser.asl"))
        (graph (g/SymbolGraph :nodes (list n-parser n-codec) :edges (list e0)))
        (anoms (h/detect-layer-leakage graph))]
    (assert (list-empty? anoms) "Layer 0 to Layer 0 dependency must produce 0 leakage anomalies")
    (assert (= (list-length anoms) 0) "Layer 0 anomaly count must be 0")
    true))

(df test-boundary-trap-layer0-import-layer1 [] -> Bool
  :d "Verifies that Layer 0 importing Layer 1 triggers anomaly-layer-leakage with blocker severity"
  (let [(n0 (make-test-node "asl-parser" "parse" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (n1 (make-test-node "agent-bus" "bus" "agent-bus/src/bus.asl" "[]"))
        (e-leak (make-test-edge "asl-parser" "agent-bus" "asl/packages/asl-parser/src/parser.asl"))
        (graph (g/SymbolGraph :nodes (list n0 n1) :edges (list e-leak)))
        (anoms (h/detect-layer-leakage graph))]
    (assert (= (list-length anoms) 1) "Layer 0 importing Layer 1 must produce exactly 1 anomaly")
    (let [(a (option-or (list-head anoms)
                        (h/HealthAnomaly :kind (h/anomaly-layer-leakage) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-severity a) "blocker") "Layer 0 importing Layer 1 must be blocker severity")
      (assert (string-contains? (.-message a) "Illegal upward dependency") "Message must flag illegal upward dependency"))
    true))

(df test-boundary-trap-agent-id-leakage [] -> Bool
  :d "Verifies that Layer 0 referencing agent ID triggers anomaly-layer-leakage"
  (let [(n-agent (make-test-node ":agent:scout" ":agent:scout" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (n-caller (make-test-node "parser-scan" "parser-scan" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (e-leak (make-test-edge "parser-scan" ":agent:scout" "asl/packages/asl-parser/src/parser.asl"))
        (graph (g/SymbolGraph :nodes (list n-caller n-agent) :edges (list e-leak)))
        (anoms (h/detect-layer-leakage graph))]
    (assert (not (list-empty? anoms)) "Agent ID reference in Layer 0 must trigger layer leakage anomaly")
    (let [(a (option-or (list-head anoms)
                        (h/HealthAnomaly :kind (h/anomaly-layer-leakage) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-severity a) "blocker") "Agent ID leakage must be blocker severity")
      (assert (string-contains? (.-message a) "forbidden agent ID") "Message must flag forbidden agent ID"))
    true))

(df test-boundary-trap-layer0-import-layer3 [] -> Bool
  :d "Verifies that Layer 0 importing Layer 3 triggers anomaly-layer-leakage with layer distance metric 3"
  (let [(n0 (make-test-node "asl-parser" "parse" "asl/packages/asl-parser/src/parser.asl" "[]"))
        (n3 (make-test-node "asl-bridge" "ffi-call" "asl/packages/asl-bridge/src/bridge.asl" "[]"))
        (e-leak (make-test-edge "asl-parser" "asl-bridge" "asl/packages/asl-parser/src/parser.asl"))
        (graph (g/SymbolGraph :nodes (list n0 n3) :edges (list e-leak)))
        (anoms (h/detect-layer-leakage graph))]
    (assert (= (list-length anoms) 1) "Layer 0 importing Layer 3 must produce exactly 1 anomaly")
    (let [(a (option-or (list-head anoms)
                        (h/HealthAnomaly :kind (h/anomaly-layer-leakage) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-severity a) "blocker") "Layer 0 importing Layer 3 must be blocker severity")
      (assert (= (.-metric a) 3) "Layer distance metric must be 3"))
    true))

(df test-boundary-trap-layer1-import-layer3 [] -> Bool
  :d "Verifies that Layer 1 importing Layer 3 triggers anomaly-layer-leakage with layer distance metric 2"
  (let [(n1 (make-test-node "agent-bus" "bus" "agent-bus/src/bus.asl" "[]"))
        (n3 (make-test-node "asl-bridge" "ffi" "asl/packages/asl-bridge/src/bridge.asl" "[]"))
        (e-leak (make-test-edge "agent-bus" "asl-bridge" "agent-bus/src/bus.asl"))
        (graph (g/SymbolGraph :nodes (list n1 n3) :edges (list e-leak)))
        (anoms (h/detect-layer-leakage graph))]
    (assert (= (list-length anoms) 1) "Layer 1 importing Layer 3 must produce exactly 1 anomaly")
    (let [(a (option-or (list-head anoms)
                        (h/HealthAnomaly :kind (h/anomaly-layer-leakage) :symbol "" :location "" :message "" :severity "" :metric 0)))]
      (assert (= (.-severity a) "blocker") "Layer 1 importing Layer 3 must be blocker severity")
      (assert (= (.-metric a) 2) "Layer distance metric must be 2"))
    true))

(df run-tests [] -> Bool
  :d "Executes full boundary and layer stratification test suite"
  (let [(r1 (test-module-to-layer-mapping))
        (r2 (test-boundary-clean-dag))
        (r3 (test-boundary-layer0-clean))
        (r4 (test-boundary-trap-layer0-import-layer1))
        (r5 (test-boundary-trap-agent-id-leakage))
        (r6 (test-boundary-trap-layer0-import-layer3))
        (r7 (test-boundary-trap-layer1-import-layer3))]
    (and r1 (and r2 (and r3 (and r4 (and r5 (and r6 r7))))))))
