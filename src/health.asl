(module asl-intel/health
  :d "Automated Codebase Structural Health Matrix & Invariant Anomaly Detection Engine"
  :x [HealthAnomalyKind
      anomaly-cycle anomaly-blast-radius anomaly-orphan-export anomaly-signature-mismatch anomaly-complexity-hotspot anomaly-layer-leakage
      anomaly-broken-reference anomaly-dangling-pointer anomaly-token-penalty anomaly-uncompensated-saga
      HealthAnomaly HealthMatrix RefEdge MultidimensionalHealthReport
      health-anomaly-kind-to-string
      detect-import-cycles
      detect-blast-radius-hotspots
      detect-orphan-exports
      detect-signature-mismatches
      detect-cyclomatic-hotspots
      module-to-layer
      is-agent-id?
      detect-layer-leakage
      detect-broken-references
      detect-dangling-pointers
      detect-cyclic-references
      audit-reference-integrity
      build-health-matrix
      detect-token-penalties
      detect-uncompensated-sagas
      detect-subword-inefficiencies
      build-multidimensional-report
      intel-health
      format-health-report]
  :i [(graph :a g)
      (xref :a xr)])

(dfe HealthAnomalyKind
  (:c anomaly-cycle [] "Cycle detected in import dependencies")
  (:c anomaly-blast-radius [] "Blast radius hotspot: high fan-in symbol")
  (:c anomaly-orphan-export [] "Orphan export: exported symbol with zero references")
  (:c anomaly-signature-mismatch [] "Signature mismatch across call edge")
  (:c anomaly-complexity-hotspot [] "Complexity hotspot: function exceeding complexity threshold")
  (:c anomaly-layer-leakage [] "Boundary violation: illegal cross-layer dependency from lower to higher layer")
  (:c anomaly-broken-reference [] "Broken reference: reference targets nonexistent symbol, task, ADR or anchor")
  (:c anomaly-dangling-pointer [] "Dangling pointer: perceptual pointer or memory chunk targets missing buffer")
  (:c anomaly-token-penalty [] "Token penalty: dashed identifier exceeding token baseline")
  (:c anomaly-uncompensated-saga [] "Uncompensated saga: side-effect mutation without cleanup handler"))

(dfs HealthAnomaly
  (:f kind HealthAnomalyKind "Category of detected health anomaly")
  (:f symbol Str "Target symbol or node identifier")
  (:f location Str "Source file and line location")
  (:f message Str "Human-readable diagnostic description")
  (:f severity Str "Severity level: blocker, error, warning, info")
  (:f metric I64 "Scalar metric e.g. in-degree, line span, cycle length"))

(dfs HealthMatrix
  (:f scope Str "Workspace scope path or module identifier")
  (:f total-nodes I64 "Total symbol nodes evaluated in graph")
  (:f total-edges I64 "Total graph edges evaluated")
  (:f anomalies (List HealthAnomaly) "List of all detected anomalies")
  (:f has-cycles Bool "True if import cycle detected (blocking condition)")
  (:f healthy Bool "True iff no blocker or error anomalies exist"))

(dfs CycleDfsState
  (:f visited (List Str) "Set of fully explored nodes")
  (:f anomalies (List HealthAnomaly) "Accumulated cycle anomalies"))

(dfs RefEdge
  (:f source Str "Origin entity or symbol identifier")
  (:f target Str "Destination entity or target identifier"))

(dfs XRefCycleState
  (:f visited (List Str) "Set of fully explored nodes")
  (:f in-path (List Str) "Set of nodes on active exploration path")
  (:f anomalies (List HealthAnomaly) "Accumulated cycle anomalies"))

(df health-anomaly-kind-to-string [(k HealthAnomalyKind)] -> Str
  :d "Convert HealthAnomalyKind enum variant to string identifier"
  (mt k
    ((anomaly-cycle) "cycle")
    ((anomaly-blast-radius) "blast-radius")
    ((anomaly-orphan-export) "orphan-export")
    ((anomaly-signature-mismatch) "signature-mismatch")
    ((anomaly-complexity-hotspot) "complexity-hotspot")
    ((anomaly-layer-leakage) "layer-leakage")
    ((anomaly-broken-reference) "broken-reference")
    ((anomaly-dangling-pointer) "dangling-pointer")
    ((anomaly-token-penalty) "token-penalty")
    ((anomaly-uncompensated-saga) "uncompensated-saga")))

(df find-node-by-key [(nodes (List g/GraphNode)) (key Str)] -> (Option g/GraphNode)
  :d "Finds a node in nodes list by matching id or name against key."
  (list-head (filter (fn [(n g/GraphNode)] -> Bool
                       (or (= (.-id n) key) (= (.-name n) key)))
                     nodes)))

(df node-location [(node-opt (Option g/GraphNode)) (fallback Str)] -> Str
  :d "Formats location string from node option or falls back to key string."
  (mt node-opt
    ((some n) (str (.-file n) ":" (string-from-int64 (.-start-line n))))
    ((none) fallback)))

(df node-in-degree [(node g/GraphNode) (edges (List g/GraphEdge))] -> I64
  :d "Calculates the count of incoming edges to the specified node."
  (let [(nid (.-id node))
        (nname (.-name node))]
    (list-length (filter (fn [(e g/GraphEdge)] -> Bool
                           (or (= (.-dst e) nid) (= (.-dst e) nname)))
                         edges))))

(df has-symbol-in-anomalies? [(anoms (List HealthAnomaly)) (sym Str)] -> Bool
  :d "Checks if symbol is already registered in anomaly list."
  (not (list-empty? (filter (fn [(a HealthAnomaly)] -> Bool (= (.-symbol a) sym)) anoms))))

(df get-import-targets [(key Str) (edges (List g/GraphEdge))] -> (List Str)
  :d "Extracts target ids for outgoing import edges originating from key."
  (fold (fn [(acc (List Str)) (e g/GraphEdge)] -> (List Str)
          (if (and (= (g/edge-kind-to-string (.-kind e)) "imports")
                   (= (.-src e) key))
            (if (list-contains? acc (.-dst e))
              acc
              (list-append acc (list (.-dst e))))
            acc))
        (list)
        edges))

(df dfs-import-cycles [(curr Str)
                       (in-path (List Str))
                       (state CycleDfsState)
                       (edges (List g/GraphEdge))
                       (nodes (List g/GraphNode))] -> CycleDfsState
  :d "3-state depth-first search for cycle detection in import graph."
  (if (list-contains? in-path curr)
    (let [(node-opt (find-node-by-key nodes curr))
          (loc (node-location node-opt curr))
          (msg (str "CYCLE_DETECTED: Circular import barrier violation involving '" curr "'"))
          (anom (HealthAnomaly
                  :kind (anomaly-cycle)
                  :symbol curr
                  :location loc
                  :message msg
                  :severity "blocker"
                  :metric (list-length in-path)))
          (cur-anoms (.-anomalies state))]
      (if (has-symbol-in-anomalies? cur-anoms curr)
        state
        (CycleDfsState
          :visited (.-visited state)
          :anomalies (list-append cur-anoms (list anom)))))
    (if (list-contains? (.-visited state) curr)
      state
      (let [(next-path (cons curr in-path))
            (targets (get-import-targets curr edges))
            (after-targets (fold (fn [(st CycleDfsState) (tgt Str)] -> CycleDfsState
                                   (dfs-import-cycles tgt next-path st edges nodes))
                                 state
                                 targets))]
        (CycleDfsState
          :visited (cons curr (.-visited after-targets))
          :anomalies (.-anomalies after-targets))))))

(df detect-import-cycles [(g g/SymbolGraph)] -> (List HealthAnomaly)
  :d "Detects circular dependency cycles across import edges using 3-state DFS traversal."
  (let [(import-edges (filter (fn [(e g/GraphEdge)] -> Bool
                                (= (g/edge-kind-to-string (.-kind e)) "imports"))
                              (.-edges g)))
        (all-nodes (.-nodes g))
        (node-keys (fold (fn [(acc (List Str)) (n g/GraphNode)] -> (List Str)
                           (let [(k (if (not (string-empty? (.-id n))) (.-id n) (.-name n)))]
                             (if (list-contains? acc k) acc (list-append acc (list k)))))
                         (list)
                         all-nodes))
        (all-keys (fold (fn [(acc (List Str)) (e g/GraphEdge)] -> (List Str)
                          (let [(s (.-src e))]
                            (if (list-contains? acc s) acc (list-append acc (list s)))))
                        node-keys
                        import-edges))
        (init-state (CycleDfsState :visited (list) :anomalies (list)))
        (final-state (fold (fn [(st CycleDfsState) (key Str)] -> CycleDfsState
                             (if (list-contains? (.-visited st) key)
                               st
                               (dfs-import-cycles key (list) st import-edges all-nodes)))
                           init-state
                           all-keys))]
    (.-anomalies final-state)))

(df detect-blast-radius-hotspots [(g g/SymbolGraph) (threshold I64)] -> (List HealthAnomaly)
  :d "Flags symbols whose fan-in (in-degree) meets or exceeds blast radius threshold."
  (let [(thresh (if (<= threshold 0) 10 threshold))
        (edges (.-edges g))]
    (fold (fn [(acc (List HealthAnomaly)) (node g/GraphNode)] -> (List HealthAnomaly)
            (let [(deg (node-in-degree node edges))]
              (if (>= deg thresh)
                (let [(anom (HealthAnomaly
                              :kind (anomaly-blast-radius)
                              :symbol (.-name node)
                              :location (str (.-file node) ":" (string-from-int64 (.-start-line node)))
                              :message (str "BLAST_RADIUS_WARNING: Symbol '" (.-name node)
                                            "' has high fan-in (in-degree=" (string-from-int64 deg)
                                            ", threshold=" (string-from-int64 thresh) ")")
                              :severity "warning"
                              :metric deg))]
                  (list-append acc (list anom)))
                acc)))
          (list)
          (.-nodes g))))

(df detect-orphan-exports [(g g/SymbolGraph)] -> (List HealthAnomaly)
  :d "Detects exported symbols with zero incoming references across the graph."
  (let [(edges (.-edges g))]
    (fold (fn [(acc (List HealthAnomaly)) (node g/GraphNode)] -> (List HealthAnomaly)
            (if (.-exported node)
              (let [(deg (node-in-degree node edges))]
                (if (= deg 0)
                  (let [(anom (HealthAnomaly
                                :kind (anomaly-orphan-export)
                                :symbol (.-name node)
                                :location (str (.-file node) ":" (string-from-int64 (.-start-line node)))
                                :message (str "ORPHAN_EXPORT_WARNING: Exported symbol '" (.-name node)
                                              "' has zero incoming references")
                                :severity "warning"
                                :metric 0))]
                    (list-append acc (list anom)))
                  acc))
              acc))
          (list)
          (.-nodes g))))

(df detect-signature-mismatches [(g g/SymbolGraph)] -> (List HealthAnomaly)
  :d "Checks signature compatibility and unresolved callees across call edges."
  (let [(nodes (.-nodes g))
        (call-edges (filter (fn [(e g/GraphEdge)] -> Bool
                              (= (g/edge-kind-to-string (.-kind e)) "calls"))
                            (.-edges g)))]
    (fold (fn [(acc (List HealthAnomaly)) (edge g/GraphEdge)] -> (List HealthAnomaly)
            (let [(callee-opt (find-node-by-key nodes (.-dst edge)))]
              (mt callee-opt
                ((none)
                 (let [(anom (HealthAnomaly
                               :kind (anomaly-signature-mismatch)
                               :symbol (.-dst edge)
                               :location (str (.-file edge) ":" (string-from-int64 (.-line edge)))
                               :message (str "SIGNATURE_ERROR: Unresolved callee '" (.-dst edge) "' at call site")
                               :severity "error"
                               :metric 0))]
                   (list-append acc (list anom))))
                ((some callee)
                 (let [(sig (string-trim (.-signature callee)))]
                   (if (or (string-empty? sig) (string-contains? sig "mismatch"))
                     (let [(anom (HealthAnomaly
                                   :kind (anomaly-signature-mismatch)
                                   :symbol (.-name callee)
                                   :location (str (.-file edge) ":" (string-from-int64 (.-line edge)))
                                   :message (str "SIGNATURE_ERROR: Callee '" (.-name callee) "' has incompatible or missing signature")
                                   :severity "error"
                                   :metric 0))]
                       (list-append acc (list anom)))
                     acc))))))
          (list)
          call-edges)))

(df detect-cyclomatic-hotspots [(g g/SymbolGraph) (threshold I64)] -> (List HealthAnomaly)
  :d "Detects functions whose structural line span exceeds the complexity threshold."
  (let [(thresh (if (<= threshold 0) 15 threshold))]
    (fold (fn [(acc (List HealthAnomaly)) (node g/GraphNode)] -> (List HealthAnomaly)
            (let [(span (- (.-end-line node) (.-start-line node)))]
              (if (> span thresh)
                (let [(anom (HealthAnomaly
                              :kind (anomaly-complexity-hotspot)
                              :symbol (.-name node)
                              :location (str (.-file node) ":" (string-from-int64 (.-start-line node)) "-" (string-from-int64 (.-end-line node)))
                              :message (str "COMPLEXITY_HOTSPOT: Symbol '" (.-name node) "' span ("
                                            (string-from-int64 span) " lines) exceeds threshold "
                                            (string-from-int64 thresh))
                              :severity "warning"
                              :metric span))]
                  (list-append acc (list anom)))
                acc)))
          (list)
          (.-nodes g))))

(df module-to-layer [(name Str)] -> I64
  :d "Maps package or module identifier/path to architectural layer tier (0..3)."
  (let [(n (string-trim name))]
    (if (or (string-contains? n "asl-bridge")
            (or (string-contains? n "asl-plugin")
                (or (string-contains? n "asl-sh")
                    (or (string-contains? n "asl-cli")
                        (or (string-contains? n "asl-gates")
                            (or (string-contains? n "browser-plugin")
                                (or (string-contains? n "bridges/")
                                    (string-contains? n "bin/"))))))))
      3
      (if (or (string-contains? n "crawler")
              (or (string-contains? n "web-api-search")
                  (or (string-contains? n "asl-registry")
                      (or (string-contains? n "voice")
                          (or (string-contains? n "asl-mem")
                              (or (= n "mem")
                                  (or (string-contains? n "mem/")
                                      (string-contains? n "/mem/"))))))))
        2
        (if (or (string-contains? n "agent-bus")
                (or (string-contains? n "agent-core")
                    (or (string-contains? n "harness")
                        (string-contains? n "asl-contracts"))))
          1
          0)))))

(df is-agent-id? [(s Str)] -> Bool
  :d "Identifies agent identity references e.g. scout, coder, reviewer."
  (let [(trimmed (string-trim s))]
    (and (or (string-starts-with? trimmed "@")
             (string-starts-with? trimmed ":agent:"))
         (and (> (string-length trimmed) 1)
              (and (not (string-contains? trimmed "/"))
                   (not (string-starts-with? trimmed "wal"))
                   (not (string-starts-with? trimmed "@wal")))))))

(df detect-layer-leakage [(g g/SymbolGraph)] -> (List HealthAnomaly)
  :d "Traps illegal cross-layer upward dependencies and agent ID references in Layer 0."
  (let [(nodes (.-nodes g))
        (edges (.-edges g))
        (edge-leaks (fold (fn [(acc (List HealthAnomaly)) (edge g/GraphEdge)] -> (List HealthAnomaly)
                            (let [(src-node (find-node-by-key nodes (.-src edge)))
                                  (src-path (mt src-node
                                              ((some sn) (if (not (string-empty? (.-file sn))) (.-file sn) (.-src edge)))
                                              ((none) (if (not (string-empty? (.-file edge))) (.-file edge) (.-src edge)))))
                                  (l-src (module-to-layer src-path))
                                  (dst-node (find-node-by-key nodes (.-dst edge)))
                                  (dst-path (mt dst-node
                                              ((some dn) (if (not (string-empty? (.-file dn))) (.-file dn) (.-dst edge)))
                                              ((none) (.-dst edge))))
                                  (l-dst (module-to-layer dst-path))
                                  (loc (str (.-file edge) ":" (string-from-int64 (.-line edge))))]
                              (if (and (= l-src 0) (is-agent-id? (.-dst edge)))
                                (let [(anom (HealthAnomaly
                                              :kind (anomaly-layer-leakage)
                                              :symbol (.-src edge)
                                              :location loc
                                              :message (str "LAYER_LEAKAGE: Layer 0 component references forbidden agent ID '" (.-dst edge) "'")
                                              :severity "blocker"
                                              :metric 1))]
                                  (list-append acc (list anom)))
                                (if (< l-src l-dst)
                                  (let [(anom (HealthAnomaly
                                                :kind (anomaly-layer-leakage)
                                                :symbol (.-src edge)
                                                :location loc
                                                :message (str "LAYER_LEAKAGE: Illegal upward dependency from Layer "
                                                              (string-from-int64 l-src) " ('" (.-src edge)
                                                              "') to Layer " (string-from-int64 l-dst)
                                                              " ('" (.-dst edge) "')")
                                                :severity "blocker"
                                                :metric (- l-dst l-src)))]
                                    (list-append acc (list anom)))
                                  acc))))
                          (list)
                          edges))
        (node-leaks (fold (fn [(acc (List HealthAnomaly)) (node g/GraphNode)] -> (List HealthAnomaly)
                            (let [(n-path (if (not (string-empty? (.-file node))) (.-file node) (.-name node)))
                                  (l-node (module-to-layer n-path))]
                              (if (and (= l-node 0)
                                       (or (is-agent-id? (.-name node))
                                           (or (is-agent-id? (.-id node))
                                               (is-agent-id? (.-signature node)))))
                                (let [(loc (str (.-file node) ":" (string-from-int64 (.-start-line node))))
                                      (anom (HealthAnomaly
                                              :kind (anomaly-layer-leakage)
                                              :symbol (.-name node)
                                              :location loc
                                              :message (str "LAYER_LEAKAGE: Layer 0 component references forbidden agent ID '" (.-name node) "'")
                                              :severity "blocker"
                                              :metric 1))]
                                  (list-append acc (list anom)))
                                acc)))
                          (list)
                          nodes))]
    (list-append edge-leaks node-leaks)))

(df get-xref-targets [(curr Str) (edges (List RefEdge))] -> (List Str)
  :d "Finds outgoing target nodes from curr in edge list"
  (fold (fn [(acc (List Str)) (e RefEdge)] -> (List Str)
          (if (= (.-source e) curr)
              (let [(tgt (.-target e))]
                (if (list-contains? acc tgt)
                    acc
                    (list-append acc (list tgt))))
              acc))
        (list)
        edges))

(df dfs-xref-cycle [(curr Str)
                    (state XRefCycleState)
                    (edges (List RefEdge))] -> XRefCycleState
  :d "3-state depth-first search for cycle detection in cross-reference graph"
  (if (list-contains? (.-in-path state) curr)
      (let [(msg (str "CYCLIC_REFERENCE: Circular dependency chain detected involving '" curr "'"))
            (anom (HealthAnomaly
                    :kind (anomaly-cycle)
                    :symbol curr
                    :location "cross-reference"
                    :message msg
                    :severity "blocker"
                    :metric (list-length (.-in-path state))))
            (cur-anoms (.-anomalies state))]
        (if (has-symbol-in-anomalies? cur-anoms curr)
            state
            (XRefCycleState
              :visited (.-visited state)
              :in-path (.-in-path state)
              :anomalies (list-append cur-anoms (list anom)))))
      (if (list-contains? (.-visited state) curr)
          state
          (let [(next-path (cons curr (.-in-path state)))
                (targets (get-xref-targets curr edges))
                (st1 (XRefCycleState
                       :visited (.-visited state)
                       :in-path next-path
                       :anomalies (.-anomalies state)))
                (after-targets (fold (fn [(st XRefCycleState) (tgt Str)] -> XRefCycleState
                                       (dfs-xref-cycle tgt st edges))
                                     st1
                                     targets))]
            (XRefCycleState
              :visited (cons curr (.-visited after-targets))
              :in-path (.-in-path state)
              :anomalies (.-anomalies after-targets))))))

(df detect-cyclic-references [(edges (List RefEdge))] -> (List HealthAnomaly)
  :d "Detects circular dependency cycles across cross-reference edges"
  (let [(all-nodes (fold (fn [(acc (List Str)) (e RefEdge)] -> (List Str)
                           (let [(s (.-source e))
                                 (t (.-target e))
                                 (acc1 (if (list-contains? acc s) acc (list-append acc (list s))))]
                             (if (list-contains? acc1 t) acc1 (list-append acc1 (list t)))))
                         (list)
                         edges))
        (init-state (XRefCycleState :visited (list) :in-path (list) :anomalies (list)))
        (final-state (fold (fn [(st XRefCycleState) (node Str)] -> XRefCycleState
                             (if (list-contains? (.-visited st) node)
                                 st
                                 (dfs-xref-cycle node st edges)))
                           init-state
                           all-nodes))]
    (.-anomalies final-state)))

(df detect-broken-references [(refs (List xr/CrossReference)) (valid-targets (List Str))] -> (List HealthAnomaly)
  :d "Detects broken cross-references targeting nonexistent symbols, tasks, ADRs, or files"
  (fold (fn [(acc (List HealthAnomaly)) (ref xr/CrossReference)] -> (List HealthAnomaly)
          (let [(tgt (.-target ref))
                (k (.-kind tgt))
                (id (.-id tgt))
                (formatted (xr/format-ref-uri tgt))
                (is-valid (or (list-contains? valid-targets formatted)
                              (or (list-contains? valid-targets id)
                                  (list-contains? valid-targets (str k ":" id)))))]
            (if is-valid
                acc
                (let [(anom (HealthAnomaly
                              :kind (anomaly-broken-reference)
                              :symbol formatted
                              :location (.-source ref)
                              :message (str "BROKEN_REFERENCE: Target '" formatted "' in '" (.-source ref) "' not found in valid registry")
                              :severity "error"
                              :metric 1))]
                  (list-append acc (list anom))))))
        (list)
        refs))

(df detect-dangling-pointers [(pointers (List Str)) (valid-buffers (List Str))] -> (List HealthAnomaly)
  :d "Detects perceptual pointers or memory chunks referencing vanished target buffers"
  (fold (fn [(acc (List HealthAnomaly)) (ptr Str)] -> (List HealthAnomaly)
          (if (list-contains? valid-buffers ptr)
              acc
              (let [(anom (HealthAnomaly
                            :kind (anomaly-dangling-pointer)
                            :symbol ptr
                            :location "mem/pointers"
                            :message (str "DANGLING_POINTER: Target memory buffer for pointer '" ptr "' has vanished")
                            :severity "error"
                            :metric 1))]
                (list-append acc (list anom)))))
        (list)
        pointers))

(df audit-reference-integrity [(refs (List xr/CrossReference)) (valid-targets (List Str))] -> (List HealthAnomaly)
  :d "Audits cross-references for broken target anchors, dangling pointers, and cyclic dependency chains"
  (let [(broken (detect-broken-references refs valid-targets))
        (edges (map (fn [(r xr/CrossReference)] -> RefEdge
                      (RefEdge :source (.-source r) :target (xr/format-ref-uri (.-target r))))
                    refs))
        (cycles (detect-cyclic-references edges))]
    (list-append broken cycles)))

(df build-health-matrix [(g g/SymbolGraph) (scope Str)] -> HealthMatrix
  :d "Constructs unified structural health diagnostic matrix from SymbolGraph."
  (let [(cycles (detect-import-cycles g))
        (layer-leaks (detect-layer-leakage g))
        (blast-hotspots (detect-blast-radius-hotspots g 10))
        (orphans (detect-orphan-exports g))
        (sig-mismatches (detect-signature-mismatches g))
        (complexity-hotspots (detect-cyclomatic-hotspots g 15))
        (anomalies (list-append
                     (list-append (list-append cycles layer-leaks) sig-mismatches)
                     (list-append
                       (list-append blast-hotspots orphans)
                       complexity-hotspots)))
        (has-cycles (not (list-empty? cycles)))
        (has-blockers (or (or has-cycles (not (list-empty? layer-leaks)))
                          (not (list-empty? sig-mismatches))))
        (healthy (not has-blockers))
        (total-n (g/graph-node-count g))
        (total-e (g/graph-edge-count g))]
    (HealthMatrix
      :scope scope
      :total-nodes total-n
      :total-edges total-e
      :anomalies anomalies
      :has-cycles has-cycles
      :healthy healthy)))

(df intel-health [(scope Str)] -> HealthMatrix
  :d "Diagnostic entrypoint constructing a health matrix for scope."
  (build-health-matrix (g/graph-create) scope))

(df format-health-report [(matrix HealthMatrix)] -> Str
  :d "Formats HealthMatrix into human-readable diagnostic report."
  (let [(status-str (if (.-healthy matrix) "HEALTHY (CLEAN)" "UNHEALTHY (ANOMALIES DETECTED)"))
        (cycle-str (if (.-has-cycles matrix) "BLOCKED (CYCLES DETECTED)" "NONE (CLEAN)"))
        (header (str "=== Structural Health Matrix ===\n"
                     "=== CODEBASE STRUCTURAL HEALTH REPORT ===\n"
                     "Scope:        " (.-scope matrix) "\n"
                     "Status:       " status-str "\n"
                     "Total Nodes:  " (string-from-int64 (.-total-nodes matrix)) "\n"
                     "Total Edges:  " (string-from-int64 (.-total-edges matrix)) "\n"
                     "Import Cycle: " cycle-str "\n"
                     "Anomalies:    " (string-from-int64 (list-length (.-anomalies matrix))) "\n"))]
    (if (list-empty? (.-anomalies matrix))
      (str header "\nNo anomalies detected. Codebase structure is clean.")
      (let [(anom-lines (map (fn [(a HealthAnomaly)] -> Str
                               (str "  [" (.-severity a) "] " (.-symbol a)
                                   " at " (.-location a) " (metric: "
                                   (string-from-int64 (.-metric a)) "): "
                                   (.-message a)))
                             (.-anomalies matrix)))]
        (str header "\nDetected Anomalies:\n" (string-join "\n" anom-lines))))))

(dfs MultidimensionalHealthReport
  (:f scope Str "Workspace or module scope evaluated")
  (:f tokenScore F64 "Token efficiency ratio")
  (:f dashedCount I64 "Number of dashed symbols")
  (:f anomalies (List HealthAnomaly) "List of all anomalies across 5 dimensions")
  (:f healthy Bool "True iff zero blocker or error anomalies exist"))

(df detect-token-penalties [(symbols (List Str))] -> (List HealthAnomaly)
  :d "Audits list of symbols and flags dashed identifiers as token penalty anomalies"
  (fold (fn [(acc (List HealthAnomaly)) (sym Str)] -> (List HealthAnomaly)
          (if (and (string-contains? sym "-") (> (string-length sym) 15))
              (list-append acc (list (HealthAnomaly
                                       :kind (anomaly-token-penalty)
                                       :symbol sym
                                       :location "grammar"
                                       :message "TOKEN_PENALTY: Symbol should be migrated to camelCase"
                                       :severity "warning"
                                       :metric 1)))
              acc))
        (list)
        symbols))

(df detect-uncompensated-sagas [(actions (List Str))] -> (List HealthAnomaly)
  :d "Flags mutations with external side effects lacking explicit rollback handlers"
  (fold (fn [(acc (List HealthAnomaly)) (act Str)] -> (List HealthAnomaly)
          (if (and (string-contains? act "procSpawn") (or (string-contains? act "no-cleanup") (not (string-contains? act ":cleanup"))))
              (list-append acc (list (HealthAnomaly
                                       :kind (anomaly-uncompensated-saga)
                                       :symbol act
                                       :location "runtime"
                                       :message "UNCOMPENSATED_SAGA: Mutation missing registered cleanup handler"
                                       :severity "error"
                                       :metric 1)))
              acc))
        (list)
        actions))

(df build-multidimensional-report [(matrix HealthMatrix) (symbols (List Str)) (actions (List Str))] -> MultidimensionalHealthReport
  :d "Builds comprehensive 5D codebase health report combining structural, token, and saga telemetry"
  (let [(token-anoms (detect-token-penalties symbols))
        (saga-anoms (detect-uncompensated-sagas actions))
        (all-anoms (list-append (.-anomalies matrix) (list-append token-anoms saga-anoms)))
        (dashed-n (list-length token-anoms))
        (score (if (= (list-length symbols) 0) 1.0 (- 1.0 (/ (* 1.0 dashed-n) (* 1.0 (list-length symbols))))))
        (healthy (and (.-healthy matrix) (list-empty? saga-anoms)))]
    (MultidimensionalHealthReport
      :scope (.-scope matrix)
      :tokenScore score
      :dashedCount dashed-n
      :anomalies all-anoms
      :healthy healthy)))

(df detect-subword-inefficiencies [(identifiers (List Str))] -> (List HealthAnomaly)
  :d "Audits task identifiers and flags uninformative numeric dash suffixes that violate Pillar V"
  (fold (fn [(acc (List HealthAnomaly)) (id Str)] -> (List HealthAnomaly)
          (if (and (string-contains? id "-")
                   (or (string-ends-with? id "-1")
                       (or (string-ends-with? id "-2")
                           (or (string-ends-with? id "-3")
                               (or (string-ends-with? id "-4")
                                   (string-ends-with? id "-5"))))))
              (list-append acc (list (HealthAnomaly
                                       :kind (anomaly-token-penalty)
                                       :symbol id
                                       :location "tasks"
                                       :message "SUBWORD_PUNCTUATION_INEFFICIENCY: Use semantic subword instead of numeric dash"
                                       :severity "warning"
                                       :metric 1)))
              acc))
        (list)
        identifiers))
