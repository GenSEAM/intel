(module asl-intel/health
  :d "Automated Codebase Structural Health Matrix & Invariant Anomaly Detection Engine"
  :x [HealthAnomalyKind
      anomaly-cycle anomaly-blast-radius anomaly-orphan-export anomaly-signature-mismatch anomaly-complexity-hotspot
      HealthAnomaly HealthMatrix
      health-anomaly-kind-to-string
      detect-import-cycles
      detect-blast-radius-hotspots
      detect-orphan-exports
      detect-signature-mismatches
      detect-cyclomatic-hotspots
      build-health-matrix
      intel-health
      format-health-report]
  :i [(graph :a g)])

(dfe HealthAnomalyKind
  (:c anomaly-cycle [] "Cycle detected in import dependencies")
  (:c anomaly-blast-radius [] "Blast radius hotspot: high fan-in symbol")
  (:c anomaly-orphan-export [] "Orphan export: exported symbol with zero references")
  (:c anomaly-signature-mismatch [] "Signature mismatch across call edge")
  (:c anomaly-complexity-hotspot [] "Complexity hotspot: function exceeding complexity threshold"))

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

(df health-anomaly-kind-to-string [(k HealthAnomalyKind)] -> Str
  :d "Convert HealthAnomalyKind enum variant to string identifier"
  (mt k
    ((anomaly-cycle) "cycle")
    ((anomaly-blast-radius) "blast-radius")
    ((anomaly-orphan-export) "orphan-export")
    ((anomaly-signature-mismatch) "signature-mismatch")
    ((anomaly-complexity-hotspot) "complexity-hotspot")))

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
    ;; In-path check: node is already on active call chain -> CYCLE DETECTED!
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
      ;; Already visited and verified acyclic in a finished branch (e.g. Diamond DAG join node)
      state
      ;; Fresh unvisited node
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
        ;; Collect all potential start keys: node ids, names, and edge sources
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
                 ;; Unresolved callee
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
                     ;; Missing signature or explicitly incompatible signature
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

(df build-health-matrix [(g g/SymbolGraph) (scope Str)] -> HealthMatrix
  :d "Constructs unified structural health diagnostic matrix from SymbolGraph."
  (let [(cycles (detect-import-cycles g))
        (blast-hotspots (detect-blast-radius-hotspots g 10))
        (orphans (detect-orphan-exports g))
        (sig-mismatches (detect-signature-mismatches g))
        (complexity-hotspots (detect-cyclomatic-hotspots g 15))
        ;; Deterministic anomaly ordering: blockers first, then errors, then warnings
        (anomalies (list-append
                     (list-append cycles sig-mismatches)
                     (list-append
                       (list-append blast-hotspots orphans)
                       complexity-hotspots)))
        (has-cycles (not (list-empty? cycles)))
        (has-blockers (or has-cycles (not (list-empty? sig-mismatches))))
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
        (header (str "=== CODEBASE STRUCTURAL HEALTH MATRIX ===\n"
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
                                    " @" (.-location a) " (metric: "
                                    (string-from-int64 (.-metric a)) "): "
                                    (.-message a)))
                             (.-anomalies matrix)))]
        (str header "\nDetected Anomalies:\n" (string-join "\n" anom-lines))))))
